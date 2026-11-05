#import "BDDevicesController.h"
#import "BDBluetooth.h"
#import "BDDeviceCell.h"
#import "BDDeviceDetailController.h"
#import "BDScanController.h"

typedef NS_ENUM(NSInteger, BDListSection) {
	BDListSectionPower,
	BDListSectionConnected,
	BDListSectionOther,
	BDListSectionAdd,
};

void BDPresentRename(UIViewController *host, id deviceObj) {
	BluetoothDevice *device = deviceObj;
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đổi tên thiết bị"
		message:@"Tên mới được lưu trong hệ thống, hiện ở cả Cài đặt và Trung tâm điều khiển." preferredStyle:UIAlertControllerStyleAlert];
	[alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
		field.text = device.name;
		field.clearButtonMode = UITextFieldViewModeWhileEditing;
		field.autocapitalizationType = UITextAutocapitalizationTypeWords;
	}];
	[alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Lưu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
		if (!name.length) return;
		if (![BDBluetooth.shared rename:device to:name]) {
			UIAlertController *fail = [UIAlertController alertControllerWithTitle:@"Không đổi được tên" message:@"bluetoothd từ chối yêu cầu." preferredStyle:UIAlertControllerStyleAlert];
			[fail addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
			[host presentViewController:fail animated:YES completion:nil];
		}
	}]];
	[host presentViewController:alert animated:YES completion:nil];
}

void BDPresentForget(UIViewController *host, id deviceObj, void (^done)(void)) {
	BluetoothDevice *device = deviceObj;
	UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Quên “%@”?", device.name]
		message:@"Thiết bị sẽ bị xoá khỏi danh sách ghép đôi. Muốn dùng lại phải ghép đôi từ đầu." preferredStyle:UIAlertControllerStyleActionSheet];
	[sheet addAction:[UIAlertAction actionWithTitle:@"Quên thiết bị" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
		[BDBluetooth.shared forget:device];
		if (done) done();
	}]];
	[sheet addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
	sheet.popoverPresentationController.sourceView = host.view;
	sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(host.view.bounds), CGRectGetMidY(host.view.bounds), 1, 1);
	[host presentViewController:sheet animated:YES completion:nil];
}

@interface BDDevicesController ()
@property (nonatomic, copy) NSArray<BluetoothDevice *> *connected;
@property (nonatomic, copy) NSArray<BluetoothDevice *> *others;
@property (nonatomic, strong) UISwitch *powerSwitch;
@end

@implementation BDDevicesController

- (instancetype)init {
	if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
		self.title = @"Bluetooth";
		self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Thiết bị" image:[UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"] tag:0];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.rowHeight = UITableViewAutomaticDimension;
	self.tableView.estimatedRowHeight = 68;
	[self.tableView registerClass:BDDeviceCell.class forCellReuseIdentifier:@"device"];
	self.powerSwitch = [UISwitch new];
	[self.powerSwitch addTarget:self action:@selector(powerChanged:) forControlEvents:UIControlEventValueChanged];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:BDBluetoothDidChangeNotification object:nil];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[BDBluetooth.shared refreshRoutes];
	[self reload];
}

- (void)reload {
	NSMutableArray *connected = [NSMutableArray array], *others = [NSMutableArray array];
	for (BluetoothDevice *device in BDBluetooth.shared.pairedDevices) {
		[(device.connected ? connected : others) addObject:device];
	}
	self.connected = connected;
	self.others = others;
	self.powerSwitch.on = BDBluetooth.shared.powered;
	[self.tableView reloadData];
}

- (void)powerChanged:(UISwitch *)sender {
	[BDBluetooth.shared setPowered:sender.on];
}

- (BOOL)showsDevices {
	return BDBluetooth.shared.available && BDBluetooth.shared.powered;
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.showsDevices ? 4 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case BDListSectionPower: return 1;
		case BDListSectionConnected: return MAX(self.connected.count, (NSUInteger)1);
		case BDListSectionOther: return MAX(self.others.count, (NSUInteger)1);
		default: return 1;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case BDListSectionConnected: return @"Đang kết nối";
		case BDListSectionOther: return @"Thiết bị của tôi";
		default: return nil;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == BDListSectionPower) {
		if (!BDBluetooth.shared.available) return @"Đang kết nối tới dịch vụ Bluetooth của iOS…";
		NSString *address = BDBluetooth.shared.localAddress;
		return address ? [NSString stringWithFormat:@"Địa chỉ iPhone: %@", address] : nil;
	}
	if (section == BDListSectionOther && self.others.count) return @"Vuốt sang trái để đổi tên hoặc quên thiết bị.";
	return nil;
}

- (BluetoothDevice *)deviceAt:(NSIndexPath *)indexPath {
	if (indexPath.section == BDListSectionConnected && indexPath.row < (NSInteger)self.connected.count) return self.connected[indexPath.row];
	if (indexPath.section == BDListSectionOther && indexPath.row < (NSInteger)self.others.count) return self.others[indexPath.row];
	return nil;
}

- (UITableViewCell *)plainCell:(NSString *)text color:(UIColor *)color {
	UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"plain"]
		?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"plain"];
	cell.textLabel.text = text;
	cell.textLabel.textColor = color;
	cell.imageView.image = nil;
	cell.accessoryView = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == BDListSectionPower) {
		UITableViewCell *cell = [self plainCell:@"Bluetooth" color:UIColor.labelColor];
		cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
		cell.imageView.image = [UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"];
		cell.imageView.tintColor = UIColor.systemBlueColor;
		cell.accessoryView = self.powerSwitch;
		self.powerSwitch.enabled = BDBluetooth.shared.available;
		return cell;
	}
	if (indexPath.section == BDListSectionAdd) {
		UITableViewCell *cell = [self plainCell:@"Thêm thiết bị mới" color:self.view.tintColor];
		cell.imageView.image = [UIImage systemImageNamed:@"plus.circle.fill"];
		cell.selectionStyle = UITableViewCellSelectionStyleDefault;
		return cell;
	}
	BluetoothDevice *device = [self deviceAt:indexPath];
	if (!device) {
		NSString *text = indexPath.section == BDListSectionConnected ? @"Chưa có thiết bị nào đang kết nối" : @"Không có thiết bị nào khác";
		return [self plainCell:text color:UIColor.secondaryLabelColor];
	}
	BDDeviceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"device" forIndexPath:indexPath];
	[cell configureWithDevice:device mode:BDDeviceCellModePaired];
	__weak BluetoothDevice *weakDevice = device;
	cell.onAction = ^{
		BluetoothDevice *d = weakDevice;
		if (!d) return;
		if (d.connected) [BDBluetooth.shared disconnect:d];
		else [BDBluetooth.shared connect:d];
	};
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == BDListSectionAdd) {
		[self.navigationController pushViewController:[BDScanController new] animated:YES];
		return;
	}
	BluetoothDevice *device = [self deviceAt:indexPath];
	if (device) [self.navigationController pushViewController:[[BDDeviceDetailController alloc] initWithAddress:device.address] animated:YES];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
	BluetoothDevice *device = [self deviceAt:indexPath];
	if (!device) return nil;
	UIContextualAction *forget = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Quên"
		handler:^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) {
			BDPresentForget(self, device, nil);
			completion(YES);
		}];
	UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Đổi tên"
		handler:^(UIContextualAction *action, UIView *view, void (^completion)(BOOL)) {
			BDPresentRename(self, device);
			completion(YES);
		}];
	rename.backgroundColor = UIColor.systemBlueColor;
	return [UISwipeActionsConfiguration configurationWithActions:@[forget, rename]];
}

@end
