#import "BDDiagController.h"
#import "BDDump.h"
#import "BDExports.h"
#import "BDLog.h"
#import "BDPrivate.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <sys/utsname.h>

#define kBDVersion @"0.1.2"

static NSArray<NSString *> *BDManagerGetters(void) {
	return @[@"available", @"enabled", @"powered", @"powerState", @"bluetoothState", @"localAddress",
		@"connected", @"audioConnected", @"connectable", @"isDiscoverable", @"devicePairingEnabled",
		@"deviceScanningEnabled", @"deviceScanningInProgress", @"isAnyoneScanning", @"isAnyoneAdvertising"];
}

static NSArray<NSString *> *BDDeviceGetters(void) {
	return @[@"name", @"productName", @"address", @"type", @"majorClass", @"minorClass", @"vendorId", @"productId",
		@"paired", @"cloudPaired", @"magicPaired", @"isTemporaryPaired", @"connected", @"connectedServices",
		@"connectedServicesCount", @"getConnectingServiceMask", @"supportsBatteryLevel", @"batteryLevel",
		@"isAppleAudioDevice", @"isAccessory", @"supportsHS", @"isProController", @"accessoryInfo",
		@"getAACPCapabilityBits", @"accessorySettingFeatureBitMask", @"getSpatialAudioPlatformSupport",
		@"listeningMode", @"listeningModeConfigs", @"micMode", @"inEarDetectEnabled", @"smartRouteMode",
		@"singleClickMode", @"doubleClickMode", @"doubleTapAction", @"doubleTapCapability",
		@"crownRotationDirection", @"autoAnswerMode", @"getLowSecurityStatus", @"getBehaviorForHIDDevice",
		@"getUserSelectedDeviceType", @"pairedDeviceNameUpdated", @"syncGroups", @"aclUID", @"scoUID",
		@"description"];
}

static NSArray<NSString *> *BDInspectedClasses(void) {
	return @[@"BluetoothManager", @"BluetoothDevice", @"BCBatteryDeviceController", @"BCBatteryDevice",
		@"MPAVRoutingController", @"MPAVRoute", @"MPAVBatteryLevel", @"MPAVOutputDeviceRoute",
		@"MRAVOutputDevice", @"MRAVConcreteOutputDevice"];
}

@interface BDDiagController () <CBCentralManagerDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *frameworkLines;
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *discovered;
@property (nonatomic, strong) CBCentralManager *central;
@property (nonatomic, strong) MPAVRoutingController *routing;
@property (nonatomic, copy) NSArray *routes;
@property (nonatomic, copy) NSArray *batteryDevices;
@property (nonatomic, copy) NSArray<NSString *> *cSymbols;
@property (nonatomic, copy) NSString *cSymbolsError;
@property (nonatomic, assign) BOOL scanning;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, copy) NSString *unfinishedStep;
@property (nonatomic, strong) id batteryController;
@end

@implementation BDDiagController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = @"Chẩn đoán";
	self.events = [NSMutableArray array];
	self.discovered = [NSMutableDictionary dictionary];

	UIBarButtonItem *share = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareReport:)];
	UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshAll)];
	self.navigationItem.rightBarButtonItems = @[share, refresh];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Sao chép" style:UIBarButtonItemStylePlain target:self action:@selector(copyReport)];

	self.unfinishedStep = BDLogUnfinishedStep();
	[self showIntro];
}

- (void)showIntro {
	BDSection *s = [BDSection title:@"Bluedeck " kBDVersion];
	BDRow *start = [s add:@"Bắt đầu chẩn đoán" value:@"Chạy lần lượt từng bước; mỗi bước được ghi vào /var/mobile/Documents/Bluedeck/progress.log"];
	__weak typeof(self) weakSelf = self;
	start.action = ^{ [weakSelf startDiagnostics]; };
	if (self.unfinishedStep) {
		[s add:@"⚠︎ Lần chạy trước dừng ở" value:self.unfinishedStep];
	}
	self.sections = @[s];
}

- (void)startDiagnostics {
	if (self.started) return;
	self.started = YES;
	BDLogReset();
	BDInstallExceptionLogger();
	BDLog(@"Bluedeck %@ · iOS %@", kBDVersion, UIDevice.currentDevice.systemVersion);

	BDStep(@"dlopen frameworks", ^{ [self loadFrameworks]; });
	BDStep(@"đăng ký notification", ^{
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(anyNotification:) name:nil object:nil];
	});
	BDStep(@"BluetoothManager sharedInstance", ^{ [self bluetoothManager]; });
	BDStep(@"BCBatteryDeviceController", ^{
		id battery = [self batteryController];
		BDLog(@"   battery controller = %@", battery);
		if ([battery respondsToSelector:@selector(addBatteryDeviceObserver:queue:)]) {
			[battery addBatteryDeviceObserver:self queue:dispatch_get_main_queue()];
		}
	});
	BDStep(@"CBCentralManager", ^{
		self.central = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()
			options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
	});

	[self refreshAll];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self rebuild];
		BDLog(@"%@ (lần dựng đầu)", BDLogDoneMarker);
	});
}

- (id)bluetoothManager {
	Class cls = NSClassFromString(@"BluetoothManager");
	return [cls respondsToSelector:@selector(sharedInstance)] ? [cls sharedInstance] : nil;
}

// iOS 15 dropped +[BCBatteryDeviceController sharedInstance]; fall back to our own instance.
- (id)batteryController {
	if (_batteryController) return _batteryController;
	Class cls = NSClassFromString(@"BCBatteryDeviceController");
	if (!cls) return nil;
	if ([cls respondsToSelector:@selector(sharedInstance)]) _batteryController = [cls sharedInstance];
	else _batteryController = [[cls alloc] init];
	return _batteryController;
}

- (void)loadFrameworks {
	self.frameworkLines = [NSMutableArray array];
	NSArray *paths = @[
		@"/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager",
		@"/System/Library/PrivateFrameworks/MobileBluetooth.framework/MobileBluetooth",
		@"/System/Library/PrivateFrameworks/BatteryCenter.framework/BatteryCenter",
		@"/System/Library/Frameworks/MediaPlayer.framework/MediaPlayer",
		@"/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
	];
	for (NSString *path in paths) {
		void *handle = dlopen(path.fileSystemRepresentation, RTLD_NOW);
		const char *err = handle ? NULL : dlerror();
		[self.frameworkLines addObject:[NSString stringWithFormat:@"%@: %@", path.lastPathComponent,
			handle ? @"OK" : [NSString stringWithFormat:@"LỖI %s", err ?: "?"]]];
	}
}

#pragma mark - Data sources

- (void)refreshAll {
	if (!self.started) return;
	BDStep(@"MPAVRoutingController", ^{
		Class routingClass = NSClassFromString(@"MPAVRoutingController");
		if (routingClass && !self.routing) {
			self.routing = [(MPAVRoutingController *)[routingClass alloc] initWithName:@"Bluedeck"];
			if ([self.routing respondsToSelector:@selector(setDiscoveryMode:)]) [self.routing setDiscoveryMode:3];
		}
		if ([self.routing respondsToSelector:@selector(fetchAvailableRoutesWithCompletionHandler:)]) {
			[self.routing fetchAvailableRoutesWithCompletionHandler:^(NSArray *routes) {
				dispatch_async(dispatch_get_main_queue(), ^{
					BDLog(@"   nhận %lu route", (unsigned long)routes.count);
					self.routes = [routes isKindOfClass:NSArray.class] ? routes : nil;
					[self rebuild];
				});
			}];
		}
	});
	BDStep(@"BatteryCenter connectedDevices", ^{
		id battery = [self batteryController];
		if ([battery respondsToSelector:@selector(connectedDevices)]) self.batteryDevices = [battery connectedDevices];
	});
	[self rebuild];
}

// BCBatteryDeviceObserving
- (void)connectedDevicesDidChange:(NSArray *)devices {
	self.batteryDevices = devices;
	[self scheduleRebuild];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
	[self scheduleRebuild];
}

- (void)anyNotification:(NSNotification *)note {
	NSString *name = note.name;
	if ([name hasPrefix:@"BD"] || (![name hasPrefix:@"BT"] && ![name containsString:@"Bluetooth"])) return;
	dispatch_async(dispatch_get_main_queue(), ^{
		NSString *objectInfo = @"";
		id obj = note.object;
		if ([obj respondsToSelector:@selector(name)] && [obj respondsToSelector:@selector(address)]) {
			BluetoothDevice *device = obj;
			objectInfo = [NSString stringWithFormat:@" — %@ (%@)", device.name, device.address];
			if ([name containsString:@"Discovered"] && device.address) self.discovered[device.address] = device;
		} else if (obj) {
			objectInfo = [NSString stringWithFormat:@" — <%@>", NSStringFromClass([obj class])];
		}
		NSDateFormatter *fmt = [NSDateFormatter new];
		fmt.dateFormat = @"HH:mm:ss";
		[self.events insertObject:[NSString stringWithFormat:@"%@ %@%@", [fmt stringFromDate:NSDate.date], name, objectInfo] atIndex:0];
		if (self.events.count > 300) [self.events removeLastObject];
		// Route list is a snapshot; re-fetch it whenever something connects or disconnects.
		if ([name containsString:@"Connect"]) {
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshAll) object:nil];
			[self performSelector:@selector(refreshAll) withObject:nil afterDelay:1.0];
		}
		[self scheduleRebuild];
	});
}

- (void)scheduleRebuild {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(rebuild) object:nil];
	[self performSelector:@selector(rebuild) withObject:nil afterDelay:0.3];
}

#pragma mark - Sections

- (void)rebuild {
	if (!self.started) return;
	NSMutableArray *sections = [NSMutableArray array];
	NSArray *builders = @[@"overviewSection", @"deviceSections", @"batterySection", @"routesSection",
		@"audioSessionSection", @"bleSection", @"methodsSection", @"cSymbolsSection", @"eventsSection"];
	for (NSString *builder in builders) {
		__block id result = nil;
		NSException *e = BDStep([@"dựng " stringByAppendingString:builder], ^{
			result = ((id (*)(id, SEL))objc_msgSend)(self, NSSelectorFromString(builder));
		});
		if (e) {
			BDSection *error = [BDSection title:[NSString stringWithFormat:@"⚠︎ %@ lỗi", builder]];
			[error add:e.name value:e.reason];
			[sections addObject:error];
		} else if ([result isKindOfClass:NSArray.class]) {
			[sections addObjectsFromArray:result];
		} else if (result) {
			[sections addObject:result];
		}
	}
	self.sections = sections;
}

- (BDSection *)overviewSection {
	BDSection *s = [BDSection title:@"Tổng quan"];
	struct utsname u;
	uname(&u);
	[s add:@"Bluedeck" value:kBDVersion];
	[s add:@"Thiết bị" value:[NSString stringWithFormat:@"%s · iOS %@", u.machine, UIDevice.currentDevice.systemVersion]];
	for (NSString *line in self.frameworkLines) [s add:line value:nil];

	Class managerClass = NSClassFromString(@"BluetoothManager");
	if (!managerClass) {
		[s add:@"BluetoothManager" value:@"KHÔNG có class"];
		return s;
	}
	[s add:@"lastInitError" value:BDCallGetter(managerClass, @"lastInitError")];
	id manager = [self bluetoothManager];
	for (NSString *getter in BDManagerGetters()) {
		[s add:getter value:BDCallGetter(manager, getter) ?: @"(không có trên iOS này)"];
	}
	return s;
}

- (NSArray<BDSection *> *)detailForDevice:(BluetoothDevice *)device {
	BDSection *info = [BDSection title:@"Getter"];
	for (NSString *getter in BDDeviceGetters()) {
		[info add:getter value:BDCallGetter(device, getter) ?: @"(không có trên iOS này)"];
	}

	BDSection *services = [BDSection title:@"isServiceSupported: (bit đúng)"];
	if ([device respondsToSelector:@selector(isServiceSupported:)]) {
		for (unsigned int bit = 0; bit < 32; bit++) {
			unsigned int mask = 1u << bit;
			if ([device isServiceSupported:mask]) [services add:[NSString stringWithFormat:@"bit %u", bit] value:[NSString stringWithFormat:@"0x%x", mask]];
		}
	}
	if (!services.rows.count) [services add:@"(không bit nào)" value:nil];

	BDSection *extra = [BDSection title:@"Hàm có tham số"];
	@try {
		if ([device respondsToSelector:@selector(inEarStatusPrimary:secondary:)]) {
			int primary = -1, secondary = -1;
			BOOL ok = [device inEarStatusPrimary:&primary secondary:&secondary];
			[extra add:@"inEarStatusPrimary:secondary:" value:[NSString stringWithFormat:@"ret %d · primary %d · secondary %d", ok, primary, secondary]];
		}
		if ([device respondsToSelector:@selector(clickHoldMode:rightAction:)]) {
			int left = -1, right = -1;
			unsigned int ret = [device clickHoldMode:&left rightAction:&right];
			[extra add:@"clickHoldMode:rightAction:" value:[NSString stringWithFormat:@"ret %u · left %d · right %d", ret, left, right]];
		}
		if ([device respondsToSelector:@selector(doubleTapActionEx:rightAction:)]) {
			unsigned int left = 0, right = 0;
			unsigned int ret = [device doubleTapActionEx:&left rightAction:&right];
			[extra add:@"doubleTapActionEx:rightAction:" value:[NSString stringWithFormat:@"ret %u · left %u · right %u", ret, left, right]];
		}
	} @catch (NSException *e) {
		[extra add:@"⚠︎ exception" value:e.reason];
	}
	return @[info, services, extra];
}

- (NSString *)summaryForDevice:(BluetoothDevice *)device {
	NSMutableArray *parts = [NSMutableArray array];
	[parts addObject:device.connected ? @"● đang kết nối" : @"○ chưa kết nối"];
	if ([device respondsToSelector:@selector(batteryLevel)] && device.batteryLevel > 0) [parts addObject:[NSString stringWithFormat:@"pin %d%%", device.batteryLevel]];
	if (device.address) [parts addObject:device.address];
	return [parts componentsJoinedByString:@" · "];
}

- (NSArray<BDSection *> *)deviceSections {
	BluetoothManager *manager = [self bluetoothManager];
	BDSection *paired = [BDSection title:@"Thiết bị đã ghép đôi"];
	BDSection *connected = [BDSection title:@"Đang kết nối / đang nối"];
	if (!manager) return @[paired];

	NSArray *pairedDevices = [manager respondsToSelector:@selector(pairedDevices)] ? manager.pairedDevices : nil;
	paired.title = [NSString stringWithFormat:@"Thiết bị đã ghép đôi (%lu)", (unsigned long)pairedDevices.count];
	for (BluetoothDevice *device in pairedDevices) {
		BDRow *row = [paired add:device.name ?: @"(không tên)" value:[self summaryForDevice:device]];
		row.detail = [self detailForDevice:device];
	}
	if (!pairedDevices.count) [paired add:@"(trống — có thể BluetoothManager chưa sẵn sàng hoặc thiếu quyền)" value:nil];

	for (NSString *getter in @[@"connectedDevices", @"connectingDevices"]) {
		NSArray *list = [manager respondsToSelector:NSSelectorFromString(getter)] ? [manager valueForKey:getter] : nil;
		NSMutableArray *names = [NSMutableArray array];
		for (BluetoothDevice *device in list) [names addObject:device.name ?: @"?"];
		[connected add:getter value:names.count ? [names componentsJoinedByString:@", "] : @"(trống)"];
	}

	BDSection *discovery = [BDSection title:[NSString stringWithFormat:@"Quét xung quanh (%lu)", (unsigned long)self.discovered.count]];
	BDRow *scan = [discovery add:self.scanning ? @"Đang quét… (bấm để dừng)" : @"Quét thiết bị xung quanh (15 giây)" value:nil];
	__weak typeof(self) weakSelf = self;
	scan.action = ^{ [weakSelf toggleScan]; };
	for (BluetoothDevice *device in self.discovered.allValues) {
		BDRow *row = [discovery add:device.name ?: @"(không tên)" value:[self summaryForDevice:device]];
		row.detail = [self detailForDevice:device];
	}
	return @[paired, connected, discovery];
}

- (void)toggleScan {
	id manager = [self bluetoothManager];
	SEL sel = NSSelectorFromString(@"setDeviceScanningEnabled:");
	if (![manager respondsToSelector:sel]) return;
	self.scanning = !self.scanning;
	((void (*)(id, SEL, BOOL))[manager methodForSelector:sel])(manager, sel, self.scanning);
	if (self.scanning) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if (self.scanning) [self toggleScan];
		});
	}
	[self rebuild];
}

- (BDSection *)batterySection {
	BDSection *s = [BDSection title:[NSString stringWithFormat:@"Pin — BatteryCenter (%lu)", (unsigned long)self.batteryDevices.count]];
	if (!NSClassFromString(@"BCBatteryDeviceController")) [s add:@"KHÔNG có BCBatteryDeviceController" value:nil];
	for (id device in self.batteryDevices) {
		NSString *name = BDCallGetter(device, @"name") ?: @"?";
		NSString *percent = BDCallGetter(device, @"percentCharge") ?: @"?";
		BDRow *row = [s add:name value:[NSString stringWithFormat:@"%@%% · parts %@", percent, BDCallGetter(device, @"parts") ?: @"?"]];
		BDSection *props = [BDSection title:NSStringFromClass([device class])];
		for (NSArray *pair in BDDumpProperties(device)) [props add:pair[0] value:pair[1]];
		row.detail = @[props];
	}
	if (!self.batteryDevices.count) [s add:@"(chưa có thiết bị nào)" value:nil];
	return s;
}

- (BDSection *)routesSection {
	BDSection *s = [BDSection title:[NSString stringWithFormat:@"Ngõ ra âm thanh — MPAVRoutingController (%lu)", (unsigned long)self.routes.count]];
	if (!self.routing) [s add:@"KHÔNG tạo được MPAVRoutingController" value:nil];
	for (id route in self.routes) {
		NSString *name = BDCallGetter(route, @"routeName") ?: BDCallGetter(route, @"name") ?: @"?";
		NSString *picked = BDCallGetter(route, @"isPicked") ?: @"?";
		BDRow *row = [s add:name value:[NSString stringWithFormat:@"picked %@ · type %@ · subtype %@", picked,
			BDCallGetter(route, @"routeType") ?: @"?", BDCallGetter(route, @"routeSubtype") ?: @"?"]];
		NSMutableArray *detail = [NSMutableArray array];
		BDSection *props = [BDSection title:NSStringFromClass([route class])];
		for (NSArray *pair in BDDumpProperties(route)) [props add:pair[0] value:pair[1]];
		[detail addObject:props];
		id battery = nil;
		@try {
			battery = [route respondsToSelector:@selector(batteryLevel)] ? [route valueForKey:@"batteryLevel"] : nil;
		} @catch (NSException *e) {}
		if (battery) {
			BDSection *bat = [BDSection title:[NSString stringWithFormat:@"batteryLevel <%@>", NSStringFromClass([battery class])]];
			for (NSArray *pair in BDDumpProperties(battery)) [bat add:pair[0] value:pair[1]];
			[detail addObject:bat];
		}
		row.detail = detail;
	}
	if (self.routing && !self.routes.count) [s add:@"(chưa có — bấm nút làm mới)" value:nil];
	return s;
}

- (BDSection *)audioSessionSection {
	AVAudioSession *session = AVAudioSession.sharedInstance;
	BDSection *s = [BDSection title:@"AVAudioSession (luồng đang phát)"];
	[s add:@"category / mode" value:[NSString stringWithFormat:@"%@ / %@", session.category, session.mode]];
	[s add:@"sampleRate" value:[NSString stringWithFormat:@"%.0f Hz", session.sampleRate]];
	[s add:@"outputNumberOfChannels" value:@(session.outputNumberOfChannels).stringValue];
	[s add:@"outputLatency / IOBufferDuration" value:[NSString stringWithFormat:@"%.1f ms / %.1f ms", session.outputLatency * 1000, session.IOBufferDuration * 1000]];
	[s add:@"otherAudioPlaying" value:session.isOtherAudioPlaying ? @"YES" : @"NO"];
	for (AVAudioSessionPortDescription *port in session.currentRoute.outputs) {
		BDRow *row = [s add:[NSString stringWithFormat:@"Output: %@", port.portName] value:port.portType];
		BDSection *detail = [BDSection title:@"Port"];
		[detail add:@"portType" value:port.portType];
		[detail add:@"UID" value:port.UID];
		[detail add:@"channels" value:@(port.channels.count).stringValue];
		for (AVAudioSessionChannelDescription *ch in port.channels) [detail add:ch.channelName value:[NSString stringWithFormat:@"label %u · number %lu", ch.channelLabel, (unsigned long)ch.channelNumber]];
		[detail add:@"dataSources" value:BDDescribe(port.dataSources)];
		[detail add:@"hasHardwareVoiceCallProcessing" value:port.hasHardwareVoiceCallProcessing ? @"YES" : @"NO"];
		for (NSArray *pair in BDDumpProperties(port)) [detail add:[@"prop " stringByAppendingString:pair[0]] value:pair[1]];
		row.detail = @[detail];
	}
	for (AVAudioSessionPortDescription *port in session.currentRoute.inputs) {
		[s add:[NSString stringWithFormat:@"Input: %@", port.portName] value:port.portType];
	}
	return s;
}

- (BDSection *)bleSection {
	BDSection *s = [BDSection title:@"BLE — CoreBluetooth"];
	NSArray *states = @[@"unknown", @"resetting", @"unsupported", @"unauthorized", @"poweredOff", @"poweredOn"];
	CBManagerState state = self.central.state;
	[s add:@"state" value:state < (NSInteger)states.count ? states[state] : @(state).stringValue];
	if (state != CBManagerStatePoweredOn) return s;
	NSArray *uuids = @[@"180F", @"180A", @"1812", @"180D", @"1800"];
	NSMutableArray *services = [NSMutableArray array];
	for (NSString *u in uuids) [services addObject:[CBUUID UUIDWithString:u]];
	NSArray<CBPeripheral *> *peripherals = [self.central retrieveConnectedPeripheralsWithServices:services];
	for (CBPeripheral *p in peripherals) [s add:p.name ?: @"(không tên)" value:p.identifier.UUIDString];
	if (!peripherals.count) [s add:@"(không có thiết bị BLE nào đang nối với dịch vụ 180F/180A/1812/180D/1800)" value:nil];
	return s;
}

- (BDSection *)methodsSection {
	BDSection *s = [BDSection title:@"Danh sách method (iOS thật)"];
	for (NSString *name in BDInspectedClasses()) {
		Class cls = NSClassFromString(name);
		NSArray *methods = BDMethodList(cls);
		BDRow *row = [s add:name value:cls ? [NSString stringWithFormat:@"%lu method", (unsigned long)methods.count] : @"không có"];
		if (cls) {
			BDSection *list = [BDSection title:name];
			for (NSString *m in methods) [list add:m value:nil];
			row.detail = @[list];
		}
	}
	return s;
}

- (BDSection *)cSymbolsSection {
	BDSection *s = [BDSection title:@"Hàm C — MobileBluetooth (_BT*)"];
	if (!self.cSymbols && !self.cSymbolsError) {
		BDRow *row = [s add:@"Quét export trie (thử nghiệm)" value:nil];
		__weak typeof(self) weakSelf = self;
		row.action = ^{
			NSString *error = nil;
			weakSelf.cSymbols = BDExportedSymbols(@"/MobileBluetooth", @"_BT", &error);
			weakSelf.cSymbolsError = error;
			[weakSelf rebuild];
		};
		return s;
	}
	if (self.cSymbolsError) {
		[s add:@"Lỗi" value:self.cSymbolsError];
		return s;
	}
	BDRow *row = [s add:@"Số hàm" value:@(self.cSymbols.count).stringValue];
	BDSection *list = [BDSection title:@"_BT*"];
	for (NSString *sym in self.cSymbols) [list add:sym value:nil];
	row.detail = @[list];
	return s;
}

- (BDSection *)eventsSection {
	BDSection *s = [BDSection title:[NSString stringWithFormat:@"Sự kiện Bluetooth (%lu)", (unsigned long)self.events.count]];
	for (NSString *event in self.events) [s add:event value:nil];
	if (!self.events.count) [s add:@"(chưa có — thử bật/tắt hoặc kết nối một thiết bị)" value:nil];
	return s;
}

#pragma mark - Report

- (NSString *)reportText {
	NSDateFormatter *fmt = [NSDateFormatter new];
	fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
	NSMutableString *text = [NSMutableString stringWithFormat:@"# Bluedeck %@ — báo cáo chẩn đoán %@\n\n", kBDVersion, [fmt stringFromDate:NSDate.date]];
	[text appendString:BDRenderSections(self.sections, @"")];
	return text;
}

- (void)copyReport {
	UIPasteboard.generalPasteboard.string = [self reportText];
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã sao chép" message:@"Báo cáo đã nằm trong bộ nhớ tạm." preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)shareReport:(UIBarButtonItem *)sender {
	NSString *text = [self reportText];
	NSDateFormatter *fmt = [NSDateFormatter new];
	fmt.dateFormat = @"yyyyMMdd-HHmmss";
	NSString *dir = @"/var/mobile/Documents/Bluedeck";
	[NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	NSString *path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"diag-%@.txt", [fmt stringFromDate:NSDate.date]]];
	BOOL written = [text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
	NSArray *items = written ? @[[NSURL fileURLWithPath:path]] : @[text];
	UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
	activity.popoverPresentationController.barButtonItem = sender;
	[self presentViewController:activity animated:YES completion:nil];
}

@end
