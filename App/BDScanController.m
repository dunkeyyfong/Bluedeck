#import "BDScanController.h"
#import "BDBluetooth.h"
#import "BDDeviceCell.h"
#import "BDEntitlements.h"

@interface BDScanController ()
@property (nonatomic, copy) NSArray<BluetoothDevice *> *devices;
@property (nonatomic, strong) NSMutableSet<NSString *> *pairing;
@end

@implementation BDScanController

- (instancetype)init {
	if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
		self.title = @"Thêm thiết bị";
		self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
		_pairing = [NSMutableSet set];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.rowHeight = UITableViewAutomaticDimension;
	self.tableView.estimatedRowHeight = 68;
	[self.tableView registerClass:BDDeviceCell.class forCellReuseIdentifier:@"device"];
	UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
	[spinner startAnimating];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:spinner];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:BDBluetoothDidChangeNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	[BDBluetooth.shared startScan];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[BDBluetooth.shared stopScan];
}

- (void)reload {
	self.devices = BDBluetooth.shared.discoveredDevices;
	// Once a device shows up as paired it leaves this list; pop back so the user sees it in "Thiết bị của tôi".
	for (BluetoothDevice *device in BDBluetooth.shared.pairedDevices) {
		if ([self.pairing containsObject:device.address] && self.navigationController.topViewController == self) {
			[self.navigationController popViewControllerAnimated:YES];
			return;
		}
	}
	[self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return section == 0 ? MAX(self.devices.count, (NSUInteger)1) : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return section == 0 ? @"Thiết bị xung quanh" : nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 1) return @"iOS hiện chỉ cho Cài đặt quét và ghép đôi thiết bị mới.";
	BDBluetooth *bt = BDBluetooth.shared;
	NSMutableString *text = [NSMutableString stringWithString:
		@"Bật chế độ ghép đôi trên thiết bị (thường là giữ nút Bluetooth hoặc nút nguồn đến khi đèn nháy). "
		@"Tai nghe/loa đời cũ có thể hỏi mã PIN — thường là 0000."];
	[text appendFormat:@"\n\nĐã nhận %ld tín hiệu phát hiện.", (long)bt.discoveryHits];
	NSArray *events = bt.recentEventLines;
	if (events.count) {
		[text appendString:@"\nSự kiện gần nhất:"];
		for (NSString *line in [events subarrayWithRange:NSMakeRange(0, MIN(events.count, (NSUInteger)6))]) {
			[text appendFormat:@"\n%@", line];
		}
	}
	return text;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"settings"]
			?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"settings"];
		cell.textLabel.text = @"Ghép đôi bằng Cài đặt › Bluetooth";
		cell.textLabel.textColor = self.view.tintColor;
		cell.imageView.image = [UIImage systemImageNamed:@"gear"];
		return cell;
	}
	if (!self.devices.count) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"empty"]
			?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"empty"];
		cell.textLabel.text = @"Đang tìm…";
		cell.textLabel.textColor = UIColor.secondaryLabelColor;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
	BluetoothDevice *device = self.devices[indexPath.row];
	BDDeviceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"device" forIndexPath:indexPath];
	[cell configureWithDevice:device mode:BDDeviceCellModeDiscovered];
	__weak typeof(self) weakSelf = self;
	__weak BluetoothDevice *weakDevice = device;
	cell.onAction = ^{ [weakSelf pair:weakDevice]; };
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 1) BDOpenBluetoothSettings();
	else if (indexPath.row < (NSInteger)self.devices.count) [self pair:self.devices[indexPath.row]];
}

- (void)pair:(BluetoothDevice *)device {
	if (!device.address) return;
	if (device.paired) {
		[BDBluetooth.shared connect:device];
		return;
	}
	[self.pairing addObject:device.address];
	[BDBluetooth.shared pair:device];
}

@end
