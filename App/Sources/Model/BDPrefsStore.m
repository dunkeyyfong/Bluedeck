#import "BDPrefsStore.h"
#import <notify.h>

@interface BDPrefsStore ()
@property (nonatomic, strong) NSMutableDictionary *values;
@end

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
	}
	return self;
}

- (void)save {
	[self.values writeToFile:kBDPrefsPath atomically:YES];
	notify_post(kBDPrefsChanged);
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
