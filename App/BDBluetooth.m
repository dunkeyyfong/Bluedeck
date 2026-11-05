#import "BDBluetooth.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>

NSString *const BDBluetoothDidChangeNotification = @"BDBluetoothDidChangeNotification";
NSString *const BDBluetoothPairingRequestNotification = @"BDBluetoothPairingRequestNotification";

@interface BDBluetooth ()
@property (nonatomic, strong) BluetoothManager *manager;
@property (nonatomic, strong) MPAVRoutingController *routing;
@property (nonatomic, readwrite, copy) NSArray<MPAVRoute *> *routes;
@property (nonatomic, strong) NSMutableDictionary<NSString *, BluetoothDevice *> *discovered;
@property (nonatomic, readwrite) BOOL scanning;
@property (nonatomic, copy) NSString *pendingPlayAddress;
@property (nonatomic, strong) NSDate *pendingPlayDeadline;
@end

@implementation BDBluetooth

+ (instancetype)shared {
	static BDBluetooth *shared;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ shared = [self new]; });
	return shared;
}

- (instancetype)init {
	if ((self = [super init])) {
		dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_NOW);
		dlopen("/System/Library/Frameworks/MediaPlayer.framework/MediaPlayer", RTLD_NOW);
		_discovered = [NSMutableDictionary dictionary];
		Class managerClass = NSClassFromString(@"BluetoothManager");
		if ([managerClass respondsToSelector:@selector(sharedInstance)]) _manager = [managerClass sharedInstance];

		Class routingClass = NSClassFromString(@"MPAVRoutingController");
		if (routingClass) {
			_routing = [(MPAVRoutingController *)[routingClass alloc] initWithName:@"Bluedeck"];
			if ([_routing respondsToSelector:@selector(setDiscoveryMode:)]) [_routing setDiscoveryMode:3];
			if ([_routing respondsToSelector:@selector(setDelegate:)]) [_routing setDelegate:self];
		}
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(bluetoothNotification:) name:nil object:nil];
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(audioRouteChanged:) name:@"AVAudioSessionRouteChangeNotification" object:nil];
		[self refreshRoutes];
	}
	return self;
}

#pragma mark - Change tracking

- (void)bluetoothNotification:(NSNotification *)note {
	NSString *name = note.name;
	if (![name hasPrefix:@"Bluetooth"]) return;
	dispatch_async(dispatch_get_main_queue(), ^{
		id obj = note.object;
		if ([name containsString:@"Discovered"] && [obj respondsToSelector:@selector(address)]) {
			BluetoothDevice *device = obj;
			if (device.address && !device.paired) self.discovered[device.address] = device;
		}
		if ([name containsString:@"Pairing"] && ([name containsString:@"Request"] || [name containsString:@"Comparision"]
				|| [name containsString:@"Comparison"] || [name containsString:@"Confirmation"] || [name containsString:@"Passkey"])) {
			NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:name forKey:@"name"];
			BluetoothDevice *device = [self deviceInObject:obj];
			if (device) info[@"device"] = device;
			info[@"info"] = [NSString stringWithFormat:@"%@", obj ?: note.userInfo ?: @""];
			[NSNotificationCenter.defaultCenter postNotificationName:BDBluetoothPairingRequestNotification object:self userInfo:info];
		}
		if ([name containsString:@"Connect"] || [name containsString:@"Paired"] || [name containsString:@"Power"]
				|| [name containsString:@"Availability"]) {
			[self refreshRoutes];
		}
		[self scheduleChange];
	});
}

- (BluetoothDevice *)deviceInObject:(id)obj {
	if ([obj respondsToSelector:@selector(address)] && [obj respondsToSelector:@selector(connect)]) return obj;
	if ([obj isKindOfClass:NSDictionary.class]) {
		for (id value in [obj allValues]) {
			BluetoothDevice *device = [self deviceInObject:value];
			if (device) return device;
		}
	}
	if ([obj isKindOfClass:NSArray.class]) {
		for (id value in obj) {
			BluetoothDevice *device = [self deviceInObject:value];
			if (device) return device;
		}
	}
	return nil;
}

- (void)audioRouteChanged:(NSNotification *)note {
	dispatch_async(dispatch_get_main_queue(), ^{ [self refreshRoutes]; });
}

// MPAVRoutingControllerDelegate (informal)
- (void)routingControllerAvailableRoutesDidChange:(id)controller {
	dispatch_async(dispatch_get_main_queue(), ^{ [self refreshRoutes]; });
}

- (void)routingController:(id)controller pickedRouteDidChange:(id)route {
	dispatch_async(dispatch_get_main_queue(), ^{ [self refreshRoutes]; });
}

- (void)routingController:(id)controller pickedRoutesDidChange:(id)routes {
	dispatch_async(dispatch_get_main_queue(), ^{ [self refreshRoutes]; });
}

- (void)scheduleChange {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(postChange) object:nil];
	[self performSelector:@selector(postChange) withObject:nil afterDelay:0.25];
}

- (void)postChange {
	[NSNotificationCenter.defaultCenter postNotificationName:BDBluetoothDidChangeNotification object:self];
}

#pragma mark - State

- (BOOL)available {
	return [self.manager respondsToSelector:@selector(available)] && [self.manager available];
}

- (BOOL)powered {
	return [self.manager respondsToSelector:@selector(powered)] && [self.manager powered];
}

- (NSString *)localAddress {
	return [self.manager respondsToSelector:@selector(localAddress)] ? [self.manager localAddress] : nil;
}

- (NSArray<BluetoothDevice *> *)pairedDevices {
	NSArray *devices = [self.manager respondsToSelector:@selector(pairedDevices)] ? [self.manager pairedDevices] : @[];
	return [devices sortedArrayUsingComparator:^NSComparisonResult(BluetoothDevice *a, BluetoothDevice *b) {
		if (a.connected != b.connected) return a.connected ? NSOrderedAscending : NSOrderedDescending;
		return [a.name ?: @"" localizedCaseInsensitiveCompare:b.name ?: @""];
	}];
}

- (NSArray<BluetoothDevice *> *)discoveredDevices {
	NSMutableArray *list = [NSMutableArray array];
	for (BluetoothDevice *device in self.discovered.allValues) {
		if (!device.paired) [list addObject:device];
	}
	return [list sortedArrayUsingComparator:^NSComparisonResult(BluetoothDevice *a, BluetoothDevice *b) {
		return [a.name ?: @"" localizedCaseInsensitiveCompare:b.name ?: @""];
	}];
}

- (void)setPowered:(BOOL)powered {
	if ([self.manager respondsToSelector:@selector(setEnabled:)]) [self.manager setEnabled:powered];
	if ([self.manager respondsToSelector:@selector(setPowered:)]) [self.manager setPowered:powered];
	[self scheduleChange];
}

- (BOOL)isConnecting:(BluetoothDevice *)device {
	NSArray *connecting = [self.manager respondsToSelector:@selector(connectingDevices)] ? [self.manager connectingDevices] : nil;
	for (BluetoothDevice *d in connecting) {
		if ([d.address isEqualToString:device.address]) return YES;
	}
	return NO;
}

#pragma mark - Actions

- (void)connect:(BluetoothDevice *)device {
	if ([self.manager respondsToSelector:@selector(connectDevice:)]) [self.manager connectDevice:device];
	else [device connect];
	[self scheduleChange];
}

- (void)disconnect:(BluetoothDevice *)device {
	if ([self.pendingPlayAddress isEqualToString:device.address]) self.pendingPlayAddress = nil;
	if ([device respondsToSelector:@selector(disconnect)]) [device disconnect];
	else [self.manager disconnectDevice:device];
	[self scheduleChange];
}

- (void)forget:(BluetoothDevice *)device {
	if ([self.manager respondsToSelector:@selector(unpairDevice:)]) [self.manager unpairDevice:device];
	else [device unpair];
	[self scheduleChange];
}

- (BOOL)rename:(BluetoothDevice *)device to:(NSString *)name {
	BOOL ok = [device respondsToSelector:@selector(setUserName:)] && [device setUserName:name];
	[self scheduleChange];
	return ok;
}

- (void)startScan {
	[self.discovered removeAllObjects];
	if ([self.manager respondsToSelector:@selector(setDevicePairingEnabled:)]) [self.manager setDevicePairingEnabled:YES];
	if ([self.manager respondsToSelector:@selector(setDeviceScanningEnabled:)]) [self.manager setDeviceScanningEnabled:YES];
	self.scanning = YES;
	[self scheduleChange];
}

- (void)stopScan {
	if ([self.manager respondsToSelector:@selector(setDeviceScanningEnabled:)]) [self.manager setDeviceScanningEnabled:NO];
	if ([self.manager respondsToSelector:@selector(setDevicePairingEnabled:)]) [self.manager setDevicePairingEnabled:NO];
	self.scanning = NO;
	[self scheduleChange];
}

- (void)pair:(BluetoothDevice *)device {
	[self connect:device];
}

- (void)acceptPairingForDevice:(BluetoothDevice *)device {
	if (device && [self.manager respondsToSelector:@selector(acceptSSP:forDevice:)]) [self.manager acceptSSP:0 forDevice:device];
	else if ([device respondsToSelector:@selector(acceptSSP:)]) [device acceptSSP:0];
}

- (void)sendPIN:(NSString *)pin forDevice:(BluetoothDevice *)device {
	if (device && [self.manager respondsToSelector:@selector(setPincode:forDevice:)]) [self.manager setPincode:pin forDevice:device];
	else if ([device respondsToSelector:@selector(setPIN:)]) [device setPIN:pin];
}

- (void)cancelPairing {
	if ([self.manager respondsToSelector:@selector(cancelPairing)]) [self.manager cancelPairing];
}

#pragma mark - Audio routes

- (void)refreshRoutes {
	if (![self.routing respondsToSelector:@selector(fetchAvailableRoutesWithCompletionHandler:)]) return;
	[self.routing fetchAvailableRoutesWithCompletionHandler:^(NSArray *routes) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self.routes = [routes isKindOfClass:NSArray.class] ? routes : @[];
			[self resolvePendingPlay];
			[self scheduleChange];
		});
	}];
}

- (MPAVRoute *)pickedRoute {
	for (MPAVRoute *route in self.routes) {
		if ([route respondsToSelector:@selector(isPicked)] && route.isPicked) return route;
	}
	return nil;
}

- (MPAVRoute *)routeForDevice:(BluetoothDevice *)device {
	NSString *acl = [device respondsToSelector:@selector(aclUID)] ? device.aclUID : nil;
	for (MPAVRoute *route in self.routes) {
		NSString *uid = [route respondsToSelector:@selector(routeUID)] ? route.routeUID : nil;
		if (!uid) continue;
		if ((acl && [uid isEqualToString:acl]) || (device.address && [uid hasPrefix:device.address])) return route;
	}
	return nil;
}

- (BOOL)isPlayingOn:(BluetoothDevice *)device {
	MPAVRoute *route = [self routeForDevice:device];
	return route && route.isPicked;
}

- (void)pickRoute:(MPAVRoute *)route {
	if (!route || ![self.routing respondsToSelector:@selector(pickRoute:)]) return;
	[self.routing pickRoute:route];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self refreshRoutes];
	});
}

- (void)playOn:(BluetoothDevice *)device {
	MPAVRoute *route = [self routeForDevice:device];
	if (route) {
		self.pendingPlayAddress = nil;
		[self pickRoute:route];
		return;
	}
	self.pendingPlayAddress = device.address;
	self.pendingPlayDeadline = [NSDate dateWithTimeIntervalSinceNow:20];
	if (!device.connected) [self connect:device];
	// Routes are refreshed on every connect notification; also poll a few times as a fallback.
	for (int i = 1; i <= 6; i++) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if (self.pendingPlayAddress) [self refreshRoutes];
		});
	}
	[self scheduleChange];
}

- (BOOL)isWaitingToPlayOn:(BluetoothDevice *)device {
	return self.pendingPlayAddress && [self.pendingPlayAddress isEqualToString:device.address];
}

- (void)resolvePendingPlay {
	if (!self.pendingPlayAddress) return;
	if ([self.pendingPlayDeadline timeIntervalSinceNow] < 0) {
		self.pendingPlayAddress = nil;
		return;
	}
	for (BluetoothDevice *device in self.pairedDevices) {
		if (![device.address isEqualToString:self.pendingPlayAddress]) continue;
		MPAVRoute *route = [self routeForDevice:device];
		if (!route) return;
		self.pendingPlayAddress = nil;
		if (!route.isPicked) [self pickRoute:route];
		return;
	}
}

@end

#pragma mark - Helpers

BOOL BDDeviceSupports(BluetoothDevice *device, BDService service) {
	return [device respondsToSelector:@selector(isServiceSupported:)] && [device isServiceSupported:service];
}

NSArray<NSString *> *BDServiceNames(unsigned long long mask) {
	NSArray *known = @[
		@[@(BDServiceA2DP), @"Nhạc (A2DP)"],
		@[@(BDServiceAVRCP), @"Điều khiển (AVRCP)"],
		@[@(BDServiceHandsfree), @"Gọi điện (HFP)"],
		@[@(BDServicePhonebook), @"Danh bạ (PBAP)"],
		@[@(BDServiceHID), @"Bàn phím/chuột (HID)"],
		@[@(BDServiceDeviceID), @"Thông tin thiết bị (DID)"],
	];
	NSMutableArray *names = [NSMutableArray array];
	unsigned long long rest = mask;
	for (NSArray *pair in known) {
		unsigned long long bit = [pair[0] unsignedLongLongValue];
		if (mask & bit) {
			[names addObject:pair[1]];
			rest &= ~bit;
		}
	}
	for (int i = 0; i < 64; i++) {
		if (rest & (1ull << i)) [names addObject:[NSString stringWithFormat:@"Dịch vụ 0x%llx", 1ull << i]];
	}
	return names;
}

NSArray<NSString *> *BDSupportedServiceNames(BluetoothDevice *device) {
	unsigned long long mask = 0;
	for (unsigned int bit = 0; bit < 32; bit++) {
		if (BDDeviceSupports(device, 1u << bit)) mask |= 1ull << bit;
	}
	return BDServiceNames(mask);
}

NSInteger BDBatteryPercent(BluetoothDevice *device) {
	if ([device respondsToSelector:@selector(supportsBatteryLevel)] && device.supportsBatteryLevel && device.batteryLevel >= 0) {
		return device.batteryLevel;
	}
	MPAVRoute *route = [BDBluetooth.shared routeForDevice:device];
	MPAVBatteryLevel *level = [route respondsToSelector:@selector(batteryLevel)] ? route.batteryLevel : nil;
	for (NSString *key in @[@"singlePercentage", @"leftPercentage", @"rightPercentage"]) {
		if (![level respondsToSelector:NSSelectorFromString(key)]) continue;
		id value = [level valueForKey:key];
		if ([value isKindOfClass:NSNumber.class]) {
			double v = [value doubleValue];
			return (NSInteger)lround(v <= 1.0 ? v * 100 : v);
		}
	}
	return -1;
}
