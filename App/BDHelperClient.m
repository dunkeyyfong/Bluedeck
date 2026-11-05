#import "BDHelperClient.h"
#import <notify.h>
#import <signal.h>

static NSString *const kBDSettingsBundle = @"com.apple.Preferences";

NSString *BDHelperStatusText(BDHelperStatus status) {
	switch (status) {
		case BDHelperStatusOK: return @"OK";
		case BDHelperStatusNotFound: return @"Cài đặt không tìm thấy thiết bị";
		case BDHelperStatusFailed: return @"iOS từ chối yêu cầu";
		case BDHelperStatusUnavailable: return @"Bluetooth trong Cài đặt chưa sẵn sàng";
		case BDHelperStatusNoHelper: return @"Cài đặt không phản hồi — tweak BluedeckHelper chưa chạy?";
		case BDHelperStatusTimeout: return @"Hết thời gian chờ Cài đặt";
	}
	return @"?";
}

@interface BDHelperClient ()
@property (nonatomic, assign) uint8_t seq;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, void (^)(BDHelperStatus)> *pending;
@property (nonatomic, strong) NSMutableArray<void (^)(void)> *pongWaiters;
@end

@implementation BDHelperClient

+ (instancetype)shared {
	static BDHelperClient *shared;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ shared = [self new]; });
	return shared;
}

- (instancetype)init {
	if ((self = [super init])) {
		_pending = [NSMutableDictionary dictionary];
		_pongWaiters = [NSMutableArray array];
		_seq = (uint8_t)(arc4random_uniform(200) + 1);
		int token = 0;
		__weak typeof(self) weakSelf = self;
		notify_register_dispatch(kBDHelperPong, &token, dispatch_get_main_queue(), ^(int t) {
			NSArray *waiters = [weakSelf.pongWaiters copy];
			[weakSelf.pongWaiters removeAllObjects];
			for (void (^waiter)(void) in waiters) waiter();
		});
		notify_register_dispatch(kBDHelperResult, &token, dispatch_get_main_queue(), ^(int t) {
			uint64_t state = 0;
			notify_get_state(t, &state);
			[weakSelf finish:(uint8_t)(state >> 56) status:(BDHelperStatus)(state & 0xffff)];
		});
		notify_register_dispatch(kBDHelperDiscovered, &token, dispatch_get_main_queue(), ^(int t) {
			NSArray *devices = [NSArray arrayWithContentsOfFile:kBDHelperDiscoveredPath] ?: @[];
			if (weakSelf.onDiscovered) weakSelf.onDiscovered(devices);
		});
	}
	return self;
}

- (void)finish:(uint8_t)seq status:(BDHelperStatus)status {
	void (^completion)(BDHelperStatus) = self.pending[@(seq)];
	if (!completion) return;
	[self.pending removeObjectForKey:@(seq)];
	completion(status);
}

#pragma mark - Liveness

// Calls back YES if Settings answers a ping within `timeout`.
- (void)ping:(NSTimeInterval)timeout completion:(void (^)(BOOL alive))completion {
	__block BOOL done = NO;
	void (^waiter)(void) = ^{
		if (done) return;
		done = YES;
		completion(YES);
	};
	[self.pongWaiters addObject:waiter];
	notify_post(kBDHelperPing);
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (done) return;
		done = YES;
		[self.pongWaiters removeObject:waiter];
		completion(NO);
	});
}

- (id)systemService {
	Class cls = NSClassFromString(@"FBSSystemService");
	SEL shared = NSSelectorFromString(@"sharedService");
	return [cls respondsToSelector:shared] ? ((id (*)(Class, SEL))[cls methodForSelector:shared])(cls, shared) : nil;
}

// A suspended Settings can't run the helper, so restart it in the background.
- (void)launchSettingsInBackground {
	id service = [self systemService];
	SEL pidSel = NSSelectorFromString(@"pidForApplication:");
	if ([service respondsToSelector:pidSel]) {
		pid_t pid = ((pid_t (*)(id, SEL, NSString *))[service methodForSelector:pidSel])(service, pidSel, kBDSettingsBundle);
		if (pid > 0) kill(pid, SIGKILL);
	}
	NSDictionary *options = @{@"__ActivateSuspended": @YES, @"__UnlockDevice": @NO};
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		SEL open = NSSelectorFromString(@"openApplication:options:withResult:");
		SEL openPort = NSSelectorFromString(@"openApplication:options:clientPort:withResult:");
		void (^result)(NSError *) = ^(NSError *error) {};
		if ([service respondsToSelector:open]) {
			((void (*)(id, SEL, NSString *, NSDictionary *, id))[service methodForSelector:open])(service, open, kBDSettingsBundle, options, result);
		} else if ([service respondsToSelector:openPort]) {
			SEL createPort = NSSelectorFromString(@"createClientPort");
			mach_port_t port = [service respondsToSelector:createPort] ? ((mach_port_t (*)(id, SEL))[service methodForSelector:createPort])(service, createPort) : MACH_PORT_NULL;
			((void (*)(id, SEL, NSString *, NSDictionary *, mach_port_t, id))[service methodForSelector:openPort])(service, openPort, kBDSettingsBundle, options, port, result);
		}
	});
}

// Pings, wakes Settings if needed, and pings again for up to ~6 s.
- (void)ensureHelper:(BOOL)wake completion:(void (^)(BOOL alive))completion {
	[self ping:0.6 completion:^(BOOL alive) {
		if (alive || !wake) {
			completion(alive);
			return;
		}
		[self launchSettingsInBackground];
		[self waitForHelper:12 completion:completion];
	}];
}

- (void)waitForHelper:(int)tries completion:(void (^)(BOOL alive))completion {
	[self ping:0.5 completion:^(BOOL alive) {
		if (alive || tries <= 0) completion(alive);
		else [self waitForHelper:tries - 1 completion:completion];
	}];
}

- (void)checkAlive:(void (^)(BOOL alive))completion {
	[self ensureHelper:NO completion:completion];
}

#pragma mark - Requests

static void BDSetState(const char *name, uint64_t state) {
	int token = 0;
	if (notify_register_check(name, &token) != NOTIFY_STATUS_OK) return;
	notify_set_state(token, state);
	notify_cancel(token);
}

- (void)send:(BDHelperOp)op address:(NSString *)address wake:(BOOL)wake completion:(void (^)(BDHelperStatus status))completion {
	void (^done)(BDHelperStatus) = completion ?: ^(BDHelperStatus s) {};
	[self ensureHelper:wake completion:^(BOOL alive) {
		if (!alive) {
			done(BDHelperStatusNoHelper);
			return;
		}
		self.seq = self.seq == 255 ? 1 : self.seq + 1;
		uint8_t seq = self.seq;
		self.pending[@(seq)] = done;
		uint64_t mac = address.length ? BDHelperMACValue(address) : 0;
		BDSetState(kBDHelperRequest, ((uint64_t)seq << 56) | ((uint64_t)op << 48) | mac);
		notify_post(kBDHelperRequest);
		NSTimeInterval timeout = op == BDHelperOpPair ? 40 : 20;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self finish:seq status:BDHelperStatusTimeout];
		});
	}];
}

@end
