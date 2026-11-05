#import "BDScanController.h"
#import "BDBluetooth.h"
#import "BDDeviceStyle.h"
#import "BDEntitlements.h"

// Row for a device Settings found while scanning (only address / name / class are known).
@interface BDFoundCell : UITableViewCell
@property (nonatomic, strong) BDDeviceIconView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, copy) void (^onAction)(void);
@end

@implementation BDFoundCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
		_iconView = [[BDDeviceIconView alloc] initWithFrame:CGRectZero];
		_titleLabel = [UILabel new];
		_titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
		_statusLabel = [UILabel new];
		_statusLabel.font = [UIFont systemFontOfSize:13];
		_statusLabel.textColor = UIColor.secondaryLabelColor;
		UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
		config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
		config.buttonSize = UIButtonConfigurationSizeSmall;
		_actionButton = [UIButton buttonWithConfiguration:config primaryAction:nil];
		[_actionButton addTarget:self action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
		[_actionButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
		[_actionButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

		UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _statusLabel]];
		text.axis = UILayoutConstraintAxisVertical;
		text.spacing = 2;
		UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView, text, _actionButton]];
		row.alignment = UIStackViewAlignmentCenter;
		row.spacing = 12;
		row.translatesAutoresizingMaskIntoConstraints = NO;
		[self.contentView addSubview:row];
		UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
		[NSLayoutConstraint activateConstraints:@[
			[_iconView.widthAnchor constraintEqualToConstant:44],
			[_iconView.heightAnchor constraintEqualToConstant:44],
			[row.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
			[row.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
			[row.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
			[row.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
		]];
	}
	return self;
}

- (void)tapped {
	if (self.onAction) self.onAction();
}

@end

@interface BDScanController ()
@property (nonatomic, copy) NSArray<NSDictionary *> *devices;
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
	self.tableView.estimatedRowHeight = 64;
	[self.tableView registerClass:BDFoundCell.class forCellReuseIdentifier:@"found"];
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

- (BOOL)isPaired:(NSString *)address {
	for (BluetoothDevice *device in BDBluetooth.shared.pairedDevices) {
		if ([device.address caseInsensitiveCompare:address] == NSOrderedSame) return YES;
	}
	return NO;
}

- (void)reload {
	self.devices = BDBluetooth.shared.discoveredDevices;
	// A device we asked to pair now shows up as paired: go back so it's visible in the list.
	for (NSString *address in self.pairing) {
		if ([self isPaired:address] && self.navigationController.topViewController == self) {
			[self.navigationController popViewControllerAnimated:YES];
			return;
		}
	}
	[self.tableView reloadData];
}

#pragma mark - Table

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
	if (section == 1) return @"Mở trang Bluetooth của Cài đặt nếu thiết bị cần nhập mã hoặc không hiện ở trên.";
	BDBluetooth *bt = BDBluetooth.shared;
	NSMutableString *text = [NSMutableString stringWithString:
		@"Bật chế độ ghép đôi trên thiết bị (thường là giữ nút Bluetooth hoặc nút nguồn đến khi đèn nháy). "
		@"Việc quét chạy ngầm trong Cài đặt qua BluedeckHelper."];
	[text appendFormat:@"\n\nĐã tìm thấy %ld thiết bị.", (long)bt.discoveryHits];
	if (bt.scanError) [text appendFormat:@"\n⚠︎ %@", bt.scanError];
	return text;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"settings"]
			?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"settings"];
		cell.textLabel.text = @"Mở Cài đặt › Bluetooth";
		cell.textLabel.textColor = self.view.tintColor;
		cell.imageView.image = [UIImage systemImageNamed:@"gear"];
		return cell;
	}
	if (!self.devices.count) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"empty"]
			?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"empty"];
		cell.textLabel.text = BDBluetooth.shared.scanError ? @"Không quét được" : @"Đang tìm…";
		cell.textLabel.textColor = UIColor.secondaryLabelColor;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		return cell;
	}
	NSDictionary *info = self.devices[indexPath.row];
	NSString *address = info[@"address"];
	BOOL paired = [self isPaired:address];
	BOOL busy = [BDBluetooth.shared.pairingAddress isEqualToString:address];
	BDDeviceKind *kind = [BDDeviceKind kindForMajor:[info[@"major"] unsignedIntValue] minor:[info[@"minor"] unsignedIntValue]];

	BDFoundCell *cell = [tableView dequeueReusableCellWithIdentifier:@"found" forIndexPath:indexPath];
	[cell.iconView configureWithKind:kind];
	NSString *name = info[@"name"];
	cell.titleLabel.text = name.length ? name : address;
	cell.statusLabel.text = [NSString stringWithFormat:@"%@ · %@%@", kind.name, address, paired ? @" · đã ghép đôi" : @""];
	UIButtonConfiguration *config = cell.actionButton.configuration;
	config.title = busy ? nil : paired ? @"Kết nối" : @"Ghép đôi";
	config.showsActivityIndicator = busy;
	cell.actionButton.configuration = config;
	cell.actionButton.enabled = !busy;
	__weak typeof(self) weakSelf = self;
	cell.onAction = ^{ [weakSelf choose:info]; };
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 1) BDOpenBluetoothSettings();
	else if (indexPath.row < (NSInteger)self.devices.count) [self choose:self.devices[indexPath.row]];
}

- (void)choose:(NSDictionary *)info {
	NSString *address = info[@"address"];
	if (!address.length || BDBluetooth.shared.pairingAddress) return;
	if ([self isPaired:address]) {
		[BDBluetooth.shared connectAddress:address];
		return;
	}
	[self.pairing addObject:address];
	[BDBluetooth.shared pairAddress:address];
}

@end
