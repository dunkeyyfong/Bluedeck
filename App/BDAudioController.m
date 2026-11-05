#import "BDAudioController.h"
#import "BDBluetooth.h"
#import "BDDeviceCell.h"
#import "BDDeviceStyle.h"
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, BDAudioSection) {
	BDAudioSectionRoutes,
	BDAudioSectionOffline,
	BDAudioSectionStream,
};

@interface BDAudioController ()
@property (nonatomic, copy) NSArray<MPAVRoute *> *routes;
@property (nonatomic, copy) NSArray<BluetoothDevice *> *offline;
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *stream;
@end

@implementation BDAudioController

- (instancetype)init {
	if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
		self.title = @"Âm thanh";
		self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Âm thanh" image:[UIImage systemImageNamed:@"hifispeaker.2"] tag:1];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.rowHeight = UITableViewAutomaticDimension;
	self.tableView.estimatedRowHeight = 60;
	[self.tableView registerClass:BDDeviceCell.class forCellReuseIdentifier:@"device"];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:BDBluetoothDidChangeNotification object:nil];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[BDBluetooth.shared refreshRoutes];
	[self reload];
}

- (void)reload {
	BDBluetooth *bt = BDBluetooth.shared;
	self.routes = bt.routes;
	NSMutableArray *offline = [NSMutableArray array];
	for (BluetoothDevice *device in bt.pairedDevices) {
		if (BDDeviceSupports(device, BDServiceA2DP) && ![bt routeForDevice:device]) [offline addObject:device];
	}
	self.offline = offline;

	AVAudioSession *session = AVAudioSession.sharedInstance;
	AVAudioSessionPortDescription *port = session.currentRoute.outputs.firstObject;
	NSMutableArray *stream = [NSMutableArray array];
	if (port) [stream addObject:@[@"Ngõ ra", port.portName ?: @"?"]];
	[stream addObject:@[@"Tần số lấy mẫu", [NSString stringWithFormat:@"%.1f kHz", session.sampleRate / 1000.0]]];
	[stream addObject:@[@"Kênh", @((NSInteger)port.channels.count ?: session.outputNumberOfChannels).stringValue]];
	[stream addObject:@[@"Độ trễ ra loa", [NSString stringWithFormat:@"%.0f ms", session.outputLatency * 1000]]];
	self.stream = stream;
	[self.tableView reloadData];
}

- (BluetoothDevice *)deviceForRoute:(MPAVRoute *)route {
	for (BluetoothDevice *device in BDBluetooth.shared.pairedDevices) {
		if ([BDBluetooth.shared routeForDevice:device] == route) return device;
	}
	return nil;
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case BDAudioSectionRoutes: return MAX(self.routes.count, (NSUInteger)1);
		case BDAudioSectionOffline: return self.offline.count;
		default: return self.stream.count;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case BDAudioSectionRoutes: return @"Phát ra";
		case BDAudioSectionOffline: return self.offline.count ? @"Loa / tai nghe chưa kết nối" : nil;
		default: return @"Luồng âm thanh";
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	switch (section) {
		case BDAudioSectionRoutes: return @"Chạm để chuyển. iPhone chỉ phát ra một thiết bị Bluetooth tại một thời điểm.";
		case BDAudioSectionOffline: return self.offline.count ? @"“Phát ra đây” sẽ kết nối rồi tự chuyển âm thanh sang thiết bị đó." : nil;
		default: return @"iPhone chỉ có codec SBC và AAC — không có LDAC/aptX.";
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == BDAudioSectionOffline) {
		BluetoothDevice *device = self.offline[indexPath.row];
		BDDeviceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"device" forIndexPath:indexPath];
		[cell configureWithDevice:device mode:BDDeviceCellModePlayHere];
		__weak BluetoothDevice *weakDevice = device;
		cell.onAction = ^{ if (weakDevice) [BDBluetooth.shared playOn:weakDevice]; };
		return cell;
	}

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"route"]
		?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"route"];
	cell.imageView.image = nil;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.textLabel.textColor = UIColor.labelColor;
	cell.detailTextLabel.text = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;

	if (indexPath.section == BDAudioSectionStream) {
		NSArray *pair = self.stream[indexPath.row];
		cell.textLabel.text = pair[0];
		cell.detailTextLabel.text = pair[1];
		return cell;
	}
	if (!self.routes.count) {
		cell.textLabel.text = @"Đang lấy danh sách…";
		cell.textLabel.textColor = UIColor.secondaryLabelColor;
		return cell;
	}
	MPAVRoute *route = self.routes[indexPath.row];
	BluetoothDevice *device = [self deviceForRoute:route];
	NSString *symbol = route.isDeviceSpeakerRoute ? @"iphone" : device ? [BDDeviceKind kindForDevice:device].symbol : @"speaker.wave.2.fill";
	cell.imageView.image = BDSymbol(symbol, 20, UIFontWeightRegular);
	cell.imageView.tintColor = route.isPicked ? self.view.tintColor : UIColor.secondaryLabelColor;
	cell.textLabel.text = route.routeName;
	NSInteger battery = device ? BDBatteryPercent(device) : -1;
	if (battery >= 0) cell.detailTextLabel.text = [NSString stringWithFormat:@"pin %ld%%", (long)battery];
	cell.accessoryType = route.isPicked ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == BDAudioSectionRoutes && indexPath.row < (NSInteger)self.routes.count) {
		MPAVRoute *route = self.routes[indexPath.row];
		if (!route.isPicked) [BDBluetooth.shared pickRoute:route];
	} else if (indexPath.section == BDAudioSectionOffline) {
		[BDBluetooth.shared playOn:self.offline[indexPath.row]];
	}
}

@end
