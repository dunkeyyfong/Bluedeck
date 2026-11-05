// SpringBoard role: (1) republish the mix settings as notify state (apps are sandboxed and
// can't read our plist), (2) keep each device on the profiles the user chose whenever it
// (re)connects, even while Bluedeck is closed.
#import "BDSystem.h"
#import "BDPrefs.h"
#import <dlfcn.h>
#import <notify.h>

@interface BluetoothDevice : NSObject
- (NSString *)address;
- (BOOL)connected;
- (unsigned long long)connectedServices;
- (BOOL)isServiceSupported:(unsigned int)service;
- (void *)device;
@end

@interface BluetoothManager : NSObject
+ (id)sharedInstance;
- (void)connectDevice:(BluetoothDevice *)device withServices:(unsigned int)services;
@end

typedef int (*BDDisconnectServicesFn)(void *device, uint32_t services);

static NSSet<NSString *> *gPublishedApps;

static NSDictionary *BDSPrefs(void) {
	return [NSDictionary dictionaryWithContentsOfFile:kBDPrefsPath] ?: @{};
}

static void BDSPublish(void) {
	NSDictionary *prefs = BDSPrefs();
	BDNotifySetState(kBDMixEnabledState, [prefs[kBDPrefMixEnabled] boolValue] ? 1 : 0);
	NSSet *apps = [NSSet setWithArray:prefs[kBDPrefMixApps] ?: @[]];
	for (NSString *bundleID in apps) {
		BDNotifySetState(BDMixAppStateName(bundleID).UTF8String, 1);
		// Hold the status name too, so what the app reports survives after it quits.
		BDNotifyHoldToken(BDMixStatusStateName(bundleID).UTF8String);
	}
	for (NSString *bundleID in gPublishedApps) {
		if (![apps containsObject:bundleID]) BDNotifySetState(BDMixAppStateName(bundleID).UTF8String, 0);
	}
	gPublishedApps = apps;
}

static void BDSEnforce(BluetoothDevice *device) {
	NSDictionary *prefs = BDSPrefs();
	if (![prefs[kBDPrefProfilesVerified] boolValue] || !device.connected || !device.address) return;
	BDProfile profile = (BDProfile)[prefs[kBDPrefProfiles][device.address] integerValue];
	if (profile == BDProfileBoth) return;
	uint32_t unwanted = profile == BDProfileMusic ? kBDServiceHandsfree : kBDServiceMusic;
	if (!(device.connectedServices & unwanted)) return;
	BDDisconnectServicesFn disconnectServices = (BDDisconnectServicesFn)dlsym(RTLD_DEFAULT, "BTDeviceDisconnectServices");
	void *handle = [device respondsToSelector:@selector(device)] ? [device device] : NULL;
	if (disconnectServices && handle) disconnectServices(handle, unwanted);
}

void BDSpringBoardStart(void) {
	BDNotifySetState(kBDSystemAliveState, 1);
	BDSPublish();
	int token = 0;
	notify_register_dispatch(kBDPrefsChanged, &token, dispatch_get_main_queue(), ^(int t) {
		BDSPublish();
	});

	[NSNotificationCenter.defaultCenter addObserverForName:@"BluetoothDeviceConnectSuccessNotification" object:nil
		queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
			BluetoothDevice *device = note.object;
			if (![device respondsToSelector:@selector(connectedServices)]) return;
			// Give the remaining profiles a moment to come up before trimming them.
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				BDSEnforce(device);
			});
		}];

	// Make sure SpringBoard has a BluetoothManager session so the notifications above arrive.
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_NOW);
		[NSClassFromString(@"BluetoothManager") sharedInstance];
	});
}
