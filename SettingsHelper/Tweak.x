// BluedeckHelper — runs inside Settings (Preferences) and performs the Bluetooth operations
// bluetoothd refuses to do for Bluedeck: forget, discovery, pairing, power. See BDHelperProtocol.h.
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <notify.h>
#import "BDHelperProtocol.h"

@interface BluetoothDevice : NSObject
- (NSString *)name;
- (NSString *)address;
- (BOOL)connected;
- (BOOL)paired;
- (unsigned int)majorClass;
- (unsigned int)minorClass;
- (void)disconnect;
@end

@interface BluetoothManager : NSObject
+ (id)sharedInstance;
- (BOOL)available;
- (NSArray *)pairedDevices;
- (void)unpairDevice:(BluetoothDevice *)device;
- (void)connectDevice:(BluetoothDevice *)device;
- (id)deviceFromAddressString:(NSString *)address;
- (void)setDevicePairingEnabled:(BOOL)enabled;
- (void)setDeviceScanningEnabled:(BOOL)enabled;
- (BOOL)setPowered:(BOOL)powered;
- (BOOL)setEnabled:(BOOL)enabled;
@end

static BluetoothManager *gManager;
static BOOL gHasSeq;
static uint8_t gLastSeq;
static UIBackgroundTaskIdentifier gTask = UIBackgroundTaskInvalid;
static NSInteger gTaskGeneration;
static NSMutableDictionary<NSString *, BluetoothDevice *> *gFound;
static BOOL gScanning;
static NSDate *gScanUntil;

#pragma mark - Plumbing

static void BDHSetState(const char *name, uint64_t state) {
	int token = 0;
	if (notify_register_check(name, &token) != NOTIFY_STATUS_OK) return;
	notify_set_state(token, state);
	notify_cancel(token);
}

static uint64_t BDHGetState(const char *name) {
	int token = 0;
	uint64_t state = 0;
	if (notify_register_check(name, &token) != NOTIFY_STATUS_OK) return 0;
	notify_get_state(token, &state);
	notify_cancel(token);
	return state;
}

static void BDHReply(uint8_t seq, uint8_t op, BDHelperStatus status) {
	BDHSetState(kBDHelperResult, ((uint64_t)seq << 56) | ((uint64_t)op << 48) | status);
	notify_post(kBDHelperResult);
}

// Settings is usually launched suspended by Bluedeck; hold a background task while working.
static void BDHKeepAlive(NSTimeInterval seconds) {
	UIApplication *app = UIApplication.sharedApplication;
	if (!app) return;
	if (gTask == UIBackgroundTaskInvalid) {
		gTask = [app beginBackgroundTaskWithName:@"Bluedeck" expirationHandler:^{
			[app endBackgroundTask:gTask];
			gTask = UIBackgroundTaskInvalid;
		}];
	}
	NSInteger generation = ++gTaskGeneration;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (generation != gTaskGeneration || gTask == UIBackgroundTaskInvalid) return;
		[app endBackgroundTask:gTask];
		gTask = UIBackgroundTaskInvalid;
	});
}

static void BDHWhenReady(int tries, void (^block)(BluetoothManager *manager)) {
	if (!gManager) {
		dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_NOW);
		gManager = [NSClassFromString(@"BluetoothManager") sharedInstance];
	}
	if ([gManager respondsToSelector:@selector(available)] && gManager.available) {
		block(gManager);
		return;
	}
	if (tries <= 0) {
		block(nil);
		return;
	}
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		BDHWhenReady(tries - 1, block);
	});
}

static BluetoothDevice *BDHPaired(BluetoothManager *m, NSString *address) {
	for (BluetoothDevice *d in m.pairedDevices) {
		if ([d.address caseInsensitiveCompare:address] == NSOrderedSame) return d;
	}
	return nil;
}

static BluetoothDevice *BDHAnyDevice(BluetoothManager *m, NSString *address) {
	BluetoothDevice *d = BDHPaired(m, address) ?: gFound[address.uppercaseString];
	if (!d && [m respondsToSelector:@selector(deviceFromAddressString:)]) d = [m deviceFromAddressString:address];
	return d;
}

#pragma mark - Discovery relay

static void BDHWriteDiscovered(void) {
	NSMutableArray *list = [NSMutableArray array];
	for (BluetoothDevice *d in gFound.allValues) {
		[list addObject:@{
			@"address": d.address ?: @"",
			@"name": d.name ?: @"",
			@"major": @(d.majorClass),
			@"minor": @(d.minorClass),
			@"paired": @(d.paired),
		}];
	}
	[NSFileManager.defaultManager createDirectoryAtPath:kBDHelperDiscoveredPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
	[list writeToFile:kBDHelperDiscoveredPath atomically:YES];
	notify_post(kBDHelperDiscovered);
}

static void BDHStartScan(BluetoothManager *m) {
	[m setDevicePairingEnabled:YES];
	[m setDeviceScanningEnabled:YES];
}

#pragma mark - Requests

static void BDHPerform(uint8_t seq, BDHelperOp op, NSString *address) {
	BDHKeepAlive(op == BDHelperOpPair || op == BDHelperOpScanStart ? 30 : 15);
	BDHWhenReady(40, ^(BluetoothManager *m) {
		if (!m) {
			BDHReply(seq, op, BDHelperStatusUnavailable);
			return;
		}
		switch (op) {
			case BDHelperOpForget: {
				BluetoothDevice *device = BDHPaired(m, address);
				if (!device) {
					BDHReply(seq, op, BDHelperStatusNotFound);
					return;
				}
				BOOL wasConnected = device.connected;
				if (wasConnected) [device disconnect];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((wasConnected ? 1.2 : 0.1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					[m unpairDevice:device];
					dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
						BDHReply(seq, op, BDHPaired(m, address) ? BDHelperStatusFailed : BDHelperStatusOK);
					});
				});
				break;
			}
			case BDHelperOpScanStart:
				// Bluedeck renews the scan every ~20 s; only a fresh scan starts from an empty list.
				if (!gScanning) {
					[gFound removeAllObjects];
					[[NSFileManager defaultManager] removeItemAtPath:kBDHelperDiscoveredPath error:nil];
				}
				gScanning = YES;
				gScanUntil = [NSDate dateWithTimeIntervalSinceNow:25];
				BDHStartScan(m);
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(25.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					if (gScanning && [gScanUntil timeIntervalSinceNow] <= 0) {
						gScanning = NO;
						[m setDeviceScanningEnabled:NO];
					}
				});
				BDHReply(seq, op, BDHelperStatusOK);
				break;
			case BDHelperOpScanStop:
				gScanning = NO;
				[m setDeviceScanningEnabled:NO];
				BDHReply(seq, op, BDHelperStatusOK);
				break;
			case BDHelperOpPair: {
				BluetoothDevice *device = BDHAnyDevice(m, address);
				if (!device) {
					BDHReply(seq, op, BDHelperStatusNotFound);
					return;
				}
				[m setDevicePairingEnabled:YES];
				[m connectDevice:device];
				__block int polls = 25;
				__block void (^poll)(void);
				void (^check)(void) = ^{
					if (BDHPaired(m, address)) {
						BDHReply(seq, op, BDHelperStatusOK);
					} else if (--polls <= 0) {
						BDHReply(seq, op, BDHelperStatusFailed);
					} else {
						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), poll);
					}
				};
				poll = check;
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), poll);
				break;
			}
			case BDHelperOpPowerOn:
				if ([m respondsToSelector:@selector(setEnabled:)]) [m setEnabled:YES];
				[m setPowered:YES];
				BDHReply(seq, op, BDHelperStatusOK);
				break;
			case BDHelperOpPowerOff:
				[m setPowered:NO];
				BDHReply(seq, op, BDHelperStatusOK);
				break;
		}
	});
}

static void BDHHandleRequest(void) {
	uint64_t state = BDHGetState(kBDHelperRequest);
	uint8_t seq = state >> 56;
	if (!seq || (gHasSeq && seq == gLastSeq)) return;
	gHasSeq = YES;
	gLastSeq = seq;
	BDHPerform(seq, (BDHelperOp)((state >> 48) & 0xff), BDHelperMACString(state & 0xffffffffffffull));
}

%ctor {
	gFound = [NSMutableDictionary dictionary];
	// Bluedeck pings first and only posts its request after our pong, so whatever request is
	// already stored belongs to an earlier run — mark it as handled.
	uint64_t previous = BDHGetState(kBDHelperRequest);
	gHasSeq = YES;
	gLastSeq = previous >> 56;
	int token = 0;
	notify_register_dispatch(kBDHelperPing, &token, dispatch_get_main_queue(), ^(int t) {
		notify_post(kBDHelperPong);
	});
	notify_register_dispatch(kBDHelperRequest, &token, dispatch_get_main_queue(), ^(int t) {
		BDHHandleRequest();
	});

	NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
	[center addObserverForName:@"BluetoothDeviceDiscoveredNotification" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
		BluetoothDevice *device = note.object;
		if (![device respondsToSelector:@selector(address)] || !device.address) return;
		gFound[device.address.uppercaseString] = device;
		BDHWriteDiscovered();
	}];
	[center addObserverForName:@"BluetoothDiscoveryStoppedNotification" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
		if (gScanning && [gScanUntil timeIntervalSinceNow] > 0 && gManager) BDHStartScan(gManager);
	}];
	notify_post(kBDHelperPong);
}
