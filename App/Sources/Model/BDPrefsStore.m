#import "BDPrefsStore.h"
#import <notify.h>

@interface BDPrefsStore ()
@property (nonatomic, strong) NSMutableDictionary *values;
@property (nonatomic, copy) NSSet<NSString *> *publishedApps;
@end

static void BDSetState(const char *name, uint64_t state) {
	int token = 0;
	if (notify_register_check(name, &token) != NOTIFY_STATUS_OK) return;
	notify_set_state(token, state);
	notify_cancel(token);
}

uint64_t BDGetState(const char *name) {
	int token = 0;
	uint64_t state = 0;
	if (notify_register_check(name, &token) != NOTIFY_STATUS_OK) return 0;
	notify_get_state(token, &state);
	notify_cancel(token);
	return state;
}

@implementation BDPrefsStore

+ (instancetype)shared {
	static BDPrefsStore *shared;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ shared = [self new]; });
	return shared;
}

- (instancetype)init {
	if ((self = [super init])) {
		_values = [[NSDictionary dictionaryWithContentsOfFile:kBDPrefsPath] mutableCopy] ?: [NSMutableDictionary dictionary];
		[self publishMixState];
	}
	return self;
}

- (void)save {
	[self.values writeToFile:kBDPrefsPath atomically:YES];
	[self publishMixState];
	notify_post(kBDPrefsChanged);
}

// Bluedeck publishes the mix flags itself (SpringBoard does the same, and again after a
// reboot) so picked apps see them at launch even if the SpringBoard side isn't running.
- (void)publishMixState {
	BDSetState(kBDMixEnabledState, self.mixEnabled ? 1 : 0);
	NSSet *apps = [NSSet setWithArray:self.mixApps];
	for (NSString *bundleID in apps) BDSetState(BDMixAppStateName(bundleID).UTF8String, 1);
	for (NSString *bundleID in self.publishedApps) {
		if (![apps containsObject:bundleID]) BDSetState(BDMixAppStateName(bundleID).UTF8String, 0);
	}
	self.publishedApps = apps;
}

- (BOOL)mixEnabled {
	return [self.values[kBDPrefMixEnabled] boolValue];
}

- (void)setMixEnabled:(BOOL)mixEnabled {
	self.values[kBDPrefMixEnabled] = @(mixEnabled);
	[self save];
}

- (NSArray<NSString *> *)mixApps {
	return self.values[kBDPrefMixApps] ?: @[];
}

- (void)setMixApps:(NSArray<NSString *> *)mixApps {
	self.values[kBDPrefMixApps] = [mixApps copy] ?: @[];
	[self save];
}

- (BOOL)profilesVerified {
	return [self.values[kBDPrefProfilesVerified] boolValue];
}

- (void)setProfilesVerified:(BOOL)profilesVerified {
	self.values[kBDPrefProfilesVerified] = @(profilesVerified);
	[self save];
}

- (BDProfile)profileForAddress:(NSString *)address {
	if (!address) return BDProfileBoth;
	return (BDProfile)[self.values[kBDPrefProfiles][address] integerValue];
}

- (void)setProfile:(BDProfile)profile forAddress:(NSString *)address {
	if (!address) return;
	NSMutableDictionary *profiles = [self.values[kBDPrefProfiles] mutableCopy] ?: [NSMutableDictionary dictionary];
	if (profile == BDProfileBoth) [profiles removeObjectForKey:address];
	else profiles[address] = @(profile);
	self.values[kBDPrefProfiles] = profiles;
	[self save];
}

@end
