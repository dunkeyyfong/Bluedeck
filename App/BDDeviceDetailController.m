#import "BDDeviceDetailController.h"
#import "BDBluetooth.h"
#import "BDDeviceStyle.h"
#import "BDDevicesController.h"
#import <AVFoundation/AVFoundation.h>
#import <PhotosUI/PhotosUI.h>

@interface BDDetailRow : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, strong) UIColor *tint;     // non-nil = action row
@property (nonatomic, copy) void (^action)(void);
@property (nonatomic, assign) BOOL checked;
@end

@implementation BDDetailRow
@end

@interface BDDetailSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, strong) NSMutableArray<BDDetailRow *> *rows;
@end

@implementation BDDetailSection
@end

@interface BDDeviceDetailController () <PHPickerViewControllerDelegate>
@property (nonatomic, copy) NSString *address;
@property (nonatomic, strong) BluetoothDevice *device;
@property (nonatomic, copy) NSArray<BDDetailSection *> *sections;
@property (nonatomic, strong) BDDeviceIconView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *kindLabel;
@end

@implementation BDDeviceDetailController

- (instancetype)initWithAddress:(NSString *)address {
	if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
		_address = [address copy];
		self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.rowHeight = UITableViewAutomaticDimension;
	self.tableView.estimatedRowHeight = 50;
	[self buildHeader];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:BDBluetoothDidChangeNotification object:nil];
	[self reload];
}

- (void)buildHeader {
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 190)];
	self.iconView = [[BDDeviceIconView alloc] initWithFrame:CGRectZero];
	self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
	self.iconView.userInteractionEnabled = YES;
	[self.iconView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(changePhoto)]];

	UIImageView *badge = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"camera.circle.fill"]];
	badge.translatesAutoresizingMaskIntoConstraints = NO;
	badge.tintColor = UIColor.systemBlueColor;
	badge.backgroundColor = UIColor.systemBackgroundColor;
	badge.layer.cornerRadius = 14;
	badge.clipsToBounds = YES;

	self.nameLabel = [UILabel new];
	self.nameLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
	self.nameLabel.textAlignment = NSTextAlignmentCenter;
	self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
	self.kindLabel = [UILabel new];
	self.kindLabel.font = [UIFont systemFontOfSize:15];
	self.kindLabel.textColor = UIColor.secondaryLabelColor;
	self.kindLabel.textAlignment = NSTextAlignmentCenter;
	self.kindLabel.translatesAutoresizingMaskIntoConstraints = NO;

	[header addSubview:self.iconView];
	[header addSubview:badge];
	[header addSubview:self.nameLabel];
	[header addSubview:self.kindLabel];
	[NSLayoutConstraint activateConstraints:@[
		[self.iconView.topAnchor constraintEqualToAnchor:header.topAnchor constant:12],
		[self.iconView.centerXAnchor constraintEqualToAnchor:header.centerXAnchor],
		[self.iconView.widthAnchor constraintEqualToConstant:100],
		[self.iconView.heightAnchor constraintEqualToConstant:100],
		[badge.trailingAnchor constraintEqualToAnchor:self.iconView.trailingAnchor constant:2],
		[badge.bottomAnchor constraintEqualToAnchor:self.iconView.bottomAnchor constant:2],
		[badge.widthAnchor constraintEqualToConstant:28],
		[badge.heightAnchor constraintEqualToConstant:28],
		[self.nameLabel.topAnchor constraintEqualToAnchor:self.iconView.bottomAnchor constant:12],
		[self.nameLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
		[self.nameLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
		[self.kindLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:2],
		[self.kindLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
		[self.kindLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
	]];
	self.tableView.tableHeaderView = header;
}

- (BluetoothDevice *)currentDevice {
	for (BluetoothDevice *device in BDBluetooth.shared.pairedDevices) {
		if ([device.address isEqualToString:self.address]) return device;
	}
	return nil;
}

#pragma mark - Content

- (BDDetailSection *)section:(NSString *)title {
	BDDetailSection *s = [BDDetailSection new];
	s.title = title;
	s.rows = [NSMutableArray array];
	return s;
}

- (BDDetailRow *)add:(BDDetailSection *)s title:(NSString *)title value:(NSString *)value {
	BDDetailRow *row = [BDDetailRow new];
	row.title = title;
	row.value = value;
	[s.rows addObject:row];
	return row;
}

- (BDDetailRow *)add:(BDDetailSection *)s action:(NSString *)title tint:(UIColor *)tint block:(void (^)(void))block {
	BDDetailRow *row = [self add:s title:title value:nil];
	row.tint = tint;
	row.action = block;
	return row;
}

- (void)reload {
	self.device = [self currentDevice];
	BluetoothDevice *device = self.device;
	if (!device) {
		// Forgotten or gone — nothing left to show.
		if (self.navigationController.topViewController == self) [self.navigationController popViewControllerAnimated:YES];
		return;
	}
	BDBluetooth *bt = BDBluetooth.shared;
	BDDeviceKind *kind = [BDDeviceKind kindForDevice:device];
	self.title = device.name;
	[self.iconView configureWithDevice:device];
	self.nameLabel.text = device.name;
	BOOL busy = [bt isConnecting:device] || [bt isWaitingToPlayOn:device];
	NSString *state = busy ? @"Đang kết nối…" : device.connected ? ([bt isPlayingOn:device] ? @"Đang phát" : @"Đã kết nối") : @"Chưa kết nối";
	self.kindLabel.text = [NSString stringWithFormat:@"%@ · %@", kind.name, state];

	NSMutableArray *sections = [NSMutableArray array];
	__weak typeof(self) weakSelf = self;

	BDDetailSection *actions = [self section:nil];
	if (device.connected) {
		[self add:actions action:@"Ngắt kết nối" tint:UIColor.systemRedColor block:^{ [bt disconnect:weakSelf.device]; }];
	} else {
		[self add:actions action:busy ? @"Đang kết nối…" : @"Kết nối" tint:self.view.tintColor block:^{ [bt connect:weakSelf.device]; }];
	}
	if (BDDeviceSupports(device, BDServiceA2DP)) {
		BOOL playing = [bt isPlayingOn:device];
		BDDetailRow *play = [self add:actions action:playing ? @"Đang phát âm thanh ra thiết bị này" : @"Phát âm thanh ra thiết bị này"
			tint:playing ? UIColor.secondaryLabelColor : self.view.tintColor block:^{ [bt playOn:weakSelf.device]; }];
		play.checked = playing;
	}
	[sections addObject:actions];

	BDDetailSection *info = [self section:@"Thông số"];
	[self add:info title:@"Tên" value:device.name];
	if (device.productName.length && ![device.productName isEqualToString:device.name]) [self add:info title:@"Tên gốc" value:device.productName];
	[self add:info title:@"Loại" value:BDClassDescription(device)];
	[self add:info title:@"Địa chỉ" value:device.address];
	if (device.vendorId || device.productId) {
		[self add:info title:@"Nhà SX / sản phẩm" value:[NSString stringWithFormat:@"0x%04X / 0x%04X", device.vendorId, device.productId]];
	}
	NSInteger battery = BDBatteryPercent(device);
	[self add:info title:@"Pin" value:battery >= 0 ? [NSString stringWithFormat:@"%ld%%", (long)battery] : @"Thiết bị không báo pin"];
	[self add:info title:@"Hỗ trợ" value:[BDSupportedServiceNames(device) componentsJoinedByString:@"\n"]];
	if (device.connected) [self add:info title:@"Đang dùng" value:[BDServiceNames(device.connectedServices) componentsJoinedByString:@"\n"]];
	if (device.isAppleAudioDevice) [self add:info title:@"Thiết bị Apple" value:@"Có"];
	info.footer = @"Giữ một dòng để sao chép.";
	[sections addObject:info];

	AVAudioSessionPortDescription *port = [self outputPortForDevice:device];
	if (port) {
		AVAudioSession *session = AVAudioSession.sharedInstance;
		BDDetailSection *audio = [self section:@"Âm thanh đang phát"];
		[self add:audio title:@"Tần số lấy mẫu" value:[NSString stringWithFormat:@"%.1f kHz", session.sampleRate / 1000.0]];
		[self add:audio title:@"Kênh" value:port.channels.count == 2 ? @"Stereo (2)" : @(port.channels.count).stringValue];
		[self add:audio title:@"Độ trễ ra loa" value:[NSString stringWithFormat:@"%.0f ms", session.outputLatency * 1000]];
		[self add:audio title:@"Codec" value:@"AAC hoặc SBC"];
		audio.footer = @"iPhone chỉ có codec SBC và AAC; iOS không cho biết đang dùng loại nào.";
		[sections addObject:audio];
	}

	BDDetailSection *manage = [self section:@"Quản lý"];
	[self add:manage action:@"Đổi tên" tint:self.view.tintColor block:^{ BDPresentRename(weakSelf, weakSelf.device); }];
	[self add:manage action:BDDevicePhoto(device.address) ? @"Đổi ảnh thiết bị" : @"Chọn ảnh cho thiết bị" tint:self.view.tintColor block:^{ [weakSelf changePhoto]; }];
	[self add:manage action:@"Quên thiết bị này" tint:UIColor.systemRedColor block:^{
		BDPresentForget(weakSelf, weakSelf.device, ^{ [weakSelf.navigationController popViewControllerAnimated:YES]; });
	}];
	[sections addObject:manage];

	self.sections = sections;
	[self.tableView reloadData];
}

- (AVAudioSessionPortDescription *)outputPortForDevice:(BluetoothDevice *)device {
	for (AVAudioSessionPortDescription *port in AVAudioSession.sharedInstance.currentRoute.outputs) {
		if ((device.aclUID && [port.UID isEqualToString:device.aclUID]) || (device.address && [port.UID hasPrefix:device.address])) return port;
	}
	return nil;
}

#pragma mark - Photo

- (void)changePhoto {
	UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Ảnh thiết bị" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
	[sheet addAction:[UIAlertAction actionWithTitle:@"Chọn từ thư viện ảnh" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		PHPickerConfiguration *config = [PHPickerConfiguration new];
		config.filter = [PHPickerFilter imagesFilter];
		config.selectionLimit = 1;
		PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
		picker.delegate = self;
		[self presentViewController:picker animated:YES completion:nil];
	}]];
	if (BDDevicePhoto(self.address)) {
		[sheet addAction:[UIAlertAction actionWithTitle:@"Dùng icon mặc định" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
			BDRemoveDevicePhoto(self.address);
			[self reload];
		}]];
	}
	[sheet addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
	sheet.popoverPresentationController.sourceView = self.iconView;
	sheet.popoverPresentationController.sourceRect = self.iconView.bounds;
	[self presentViewController:sheet animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
	[picker dismissViewControllerAnimated:YES completion:nil];
	NSItemProvider *provider = results.firstObject.itemProvider;
	if (![provider canLoadObjectOfClass:UIImage.class]) return;
	NSString *address = self.address;
	[provider loadObjectOfClass:UIImage.class completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
		if (![(id)object isKindOfClass:UIImage.class]) return;
		BDSaveDevicePhoto((UIImage *)object, address);
		dispatch_async(dispatch_get_main_queue(), ^{
			[self reload];
			[NSNotificationCenter.defaultCenter postNotificationName:BDBluetoothDidChangeNotification object:nil];
		});
	}];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.sections[section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return self.sections[section].title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	return self.sections[section].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	BDDetailRow *row = self.sections[indexPath.section].rows[indexPath.row];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"]
		?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"row"];
	// List content configurations self-size, so multi-line values (services) get their own height.
	UIListContentConfiguration *content = row.tint ? [UIListContentConfiguration cellConfiguration] : [UIListContentConfiguration valueCellConfiguration];
	content.text = row.title;
	content.secondaryText = row.value;
	content.textProperties.color = row.tint ?: UIColor.labelColor;
	content.secondaryTextProperties.numberOfLines = 0;
	content.prefersSideBySideTextAndSecondaryText = YES;
	cell.contentConfiguration = content;
	cell.accessoryType = row.checked ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
	cell.selectionStyle = row.action ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	BDDetailRow *row = self.sections[indexPath.section].rows[indexPath.row];
	if (row.action && !row.checked) row.action();
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
	BDDetailRow *row = self.sections[indexPath.section].rows[indexPath.row];
	if (row.action || !row.value.length) return nil;
	NSString *text = row.value;
	return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray *suggested) {
		UIAction *copy = [UIAction actionWithTitle:@"Sao chép" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(UIAction *action) {
			UIPasteboard.generalPasteboard.string = text;
		}];
		return [UIMenu menuWithTitle:row.title children:@[copy]];
	}];
}

@end
