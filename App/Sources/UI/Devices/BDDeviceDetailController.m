#import "BDDeviceDetailController.h"
#import "BDBluetooth.h"
#import "BDCards.h"
#import "BDDeviceStyle.h"
#import "BDDevicesController.h"
#import <AVFoundation/AVFoundation.h>

static UIColor *BDDetailShade(UIColor *color, CGFloat brightness, CGFloat saturation) {
	CGFloat h = 0, s = 0, b = 0, a = 1;
	if (![color getHue:&h saturation:&s brightness:&b alpha:&a]) return color;
	return [UIColor colorWithHue:h saturation:MIN(1, s * saturation) brightness:MIN(1, b * brightness) alpha:a];
}

@interface BDGradientView : UIView
@property (nonatomic, readonly) CAGradientLayer *gradientLayer;
@end

@implementation BDGradientView
+ (Class)layerClass {
	return CAGradientLayer.class;
}
- (CAGradientLayer *)gradientLayer {
	CAGradientLayer *layer = (CAGradientLayer *)self.layer;
	layer.startPoint = CGPointMake(0, 0);
	layer.endPoint = CGPointMake(1, 1);
	return layer;
}
@end

// Label with horizontal padding, used as the status pill.
@interface BDPillLabel : UILabel
@end

@implementation BDPillLabel
- (CGSize)intrinsicContentSize {
	CGSize size = [super intrinsicContentSize];
	return CGSizeMake(size.width + 24, size.height);
}
- (void)drawTextInRect:(CGRect)rect {
	[super drawTextInRect:UIEdgeInsetsInsetRect(rect, UIEdgeInsetsMake(0, 12, 0, 12))];
}
@end

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

@interface BDDeviceDetailController ()
@property (nonatomic, copy) NSString *address;
@property (nonatomic, strong) BluetoothDevice *device;
@property (nonatomic, copy) NSArray<BDDetailSection *> *sections;
@property (nonatomic, strong) BDGradientView *card;
@property (nonatomic, strong) BDDeviceIconView *iconView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) BDPillLabel *kindLabel;
@property (nonatomic, strong) BDRoundAction *connectAction;
@property (nonatomic, strong) BDRoundAction *playAction;
@property (nonatomic, strong) BDRoundAction *forgetAction;
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

// Gradient card on top (avatar, name, status pill) and a row of round actions under it.
- (void)buildHeader {
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 340)];

	self.card = [BDGradientView new];
	self.card.layer.cornerRadius = 26;
	self.card.layer.cornerCurve = kCACornerCurveContinuous;
	self.card.clipsToBounds = YES;
	self.iconView = [[BDDeviceIconView alloc] initWithFrame:CGRectZero];
	self.iconView.layer.borderWidth = 3;
	self.iconView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.55].CGColor;
	self.nameLabel = [UILabel new];
	self.nameLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
	self.nameLabel.textColor = UIColor.whiteColor;
	self.nameLabel.textAlignment = NSTextAlignmentCenter;
	self.nameLabel.adjustsFontSizeToFitWidth = YES;
	self.kindLabel = [BDPillLabel new];
	self.kindLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
	self.kindLabel.textAlignment = NSTextAlignmentCenter;
	self.kindLabel.textColor = UIColor.whiteColor;
	self.kindLabel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.22];
	self.kindLabel.layer.cornerRadius = 13;
	self.kindLabel.clipsToBounds = YES;

	self.connectAction = [BDRoundAction new];
	self.playAction = [BDRoundAction new];
	self.forgetAction = [BDRoundAction new];
	[self.connectAction addTarget:self action:@selector(toggleConnection) forControlEvents:UIControlEventTouchUpInside];
	[self.playAction addTarget:self action:@selector(playHere) forControlEvents:UIControlEventTouchUpInside];
	[self.forgetAction addTarget:self action:@selector(forget) forControlEvents:UIControlEventTouchUpInside];
	UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[self.connectAction, self.playAction, self.forgetAction]];
	actions.distribution = UIStackViewDistributionFillEqually;

	for (UIView *view in @[self.card, actions]) {
		view.translatesAutoresizingMaskIntoConstraints = NO;
		[header addSubview:view];
	}
	for (UIView *view in @[self.iconView, self.nameLabel, self.kindLabel]) {
		view.translatesAutoresizingMaskIntoConstraints = NO;
		[self.card addSubview:view];
	}
	[NSLayoutConstraint activateConstraints:@[
		[self.card.topAnchor constraintEqualToAnchor:header.topAnchor constant:8],
		[self.card.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
		[self.card.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
		[self.card.heightAnchor constraintEqualToConstant:216],
		[self.iconView.topAnchor constraintEqualToAnchor:self.card.topAnchor constant:24],
		[self.iconView.centerXAnchor constraintEqualToAnchor:self.card.centerXAnchor],
		[self.iconView.widthAnchor constraintEqualToConstant:92],
		[self.iconView.heightAnchor constraintEqualToConstant:92],
		[self.nameLabel.topAnchor constraintEqualToAnchor:self.iconView.bottomAnchor constant:12],
		[self.nameLabel.leadingAnchor constraintEqualToAnchor:self.card.leadingAnchor constant:20],
		[self.nameLabel.trailingAnchor constraintEqualToAnchor:self.card.trailingAnchor constant:-20],
		[self.kindLabel.topAnchor constraintEqualToAnchor:self.nameLabel.bottomAnchor constant:8],
		[self.kindLabel.centerXAnchor constraintEqualToAnchor:self.card.centerXAnchor],
		[self.kindLabel.heightAnchor constraintEqualToConstant:26],
		[actions.topAnchor constraintEqualToAnchor:self.card.bottomAnchor constant:18],
		[actions.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:28],
		[actions.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-28],
	]];
	self.tableView.tableHeaderView = header;
}

- (void)toggleConnection {
	BluetoothDevice *device = self.device;
	if (!device) return;
	if (device.connected) [BDBluetooth.shared disconnect:device];
	else [BDBluetooth.shared connect:device];
}

- (void)playHere {
	if (self.device && ![BDBluetooth.shared isPlayingOn:self.device]) [BDBluetooth.shared playOn:self.device];
}

- (void)forget {
	__weak typeof(self) weakSelf = self;
	if (self.device) BDPresentForget(self, self.device, ^{ [weakSelf.navigationController popViewControllerAnimated:YES]; });
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
	self.card.gradientLayer.colors = @[(id)BDDetailShade(kind.color, 1.08, 0.85).CGColor, (id)BDDetailShade(kind.color, 0.62, 1.15).CGColor];
	[self.iconView configureWithKind:kind];
	self.nameLabel.text = device.name;
	BOOL connecting = [bt isConnecting:device];
	BOOL waiting = [bt isWaitingToPlayOn:device];
	BOOL playing = [bt isPlayingOn:device];
	NSString *state = connecting || waiting ? @"Đang kết nối…" : device.connected ? (playing ? @"Đang phát" : @"Đã kết nối") : @"Chưa kết nối";
	self.kindLabel.text = [NSString stringWithFormat:@"%@ · %@", kind.name, state];

	if (device.connected) [self.connectAction configureWithSymbol:@"xmark" title:@"Ngắt" tint:UIColor.systemRedColor busy:NO];
	else [self.connectAction configureWithSymbol:@"link" title:@"Kết nối" tint:UIColor.systemBlueColor busy:connecting];
	self.playAction.hidden = !BDDeviceSupports(device, BDServiceA2DP);
	if (playing) [self.playAction configureWithSymbol:@"checkmark" title:@"Đang phát" tint:UIColor.systemGreenColor busy:NO];
	else [self.playAction configureWithSymbol:@"hifispeaker.2.fill" title:@"Phát ra đây" tint:UIColor.systemBlueColor busy:waiting];
	[self.forgetAction configureWithSymbol:@"trash" title:@"Quên" tint:UIColor.systemRedColor busy:[bt isForgetting:device]];

	NSMutableArray *sections = [NSMutableArray array];

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


	self.sections = sections;
	[self.tableView reloadData];
}

- (AVAudioSessionPortDescription *)outputPortForDevice:(BluetoothDevice *)device {
	for (AVAudioSessionPortDescription *port in AVAudioSession.sharedInstance.currentRoute.outputs) {
		if ((device.aclUID && [port.UID isEqualToString:device.aclUID]) || (device.address && [port.UID hasPrefix:device.address])) return port;
	}
	return nil;
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
