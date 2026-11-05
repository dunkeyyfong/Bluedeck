#import "BDDeviceCell.h"
#import "BDBluetooth.h"
#import "BDDeviceStyle.h"

@interface BDDeviceCell ()
@property (nonatomic, strong) BDDeviceIconView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *actionButton;
@end

@implementation BDDeviceCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
		_iconView = [[BDDeviceIconView alloc] initWithFrame:CGRectZero];
		_titleLabel = [UILabel new];
		_titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
		_statusLabel = [UILabel new];
		_statusLabel.font = [UIFont systemFontOfSize:13];
		_statusLabel.textColor = UIColor.secondaryLabelColor;
		_statusLabel.numberOfLines = 2;

		UIButtonConfiguration *config = [UIButtonConfiguration tintedButtonConfiguration];
		config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
		config.buttonSize = UIButtonConfigurationSizeSmall;
		_actionButton = [UIButton buttonWithConfiguration:config primaryAction:nil];
		[_actionButton addTarget:self action:@selector(actionTapped) forControlEvents:UIControlEventTouchUpInside];
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
			[_iconView.widthAnchor constraintEqualToConstant:48],
			[_iconView.heightAnchor constraintEqualToConstant:48],
			[row.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
			[row.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
			[row.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
			[row.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
		]];
		self.accessoryType = UITableViewCellAccessoryNone;
	}
	return self;
}

- (void)actionTapped {
	if (self.onAction) self.onAction();
}

- (void)configureWithDevice:(BluetoothDevice *)device mode:(BDDeviceCellMode)mode {
	BDBluetooth *bt = BDBluetooth.shared;
	BDDeviceKind *kind = [BDDeviceKind kindForDevice:device];
	[self.iconView configureWithDevice:device];
	self.titleLabel.text = device.name.length ? device.name : @"(không tên)";

	BOOL connecting = [bt isConnecting:device] || [bt isWaitingToPlayOn:device];
	NSMutableArray *status = [NSMutableArray arrayWithObject:kind.name];
	if (mode == BDDeviceCellModeDiscovered) {
		if (device.paired) [status addObject:device.connected ? @"Đã kết nối" : @"Đã ghép đôi"];
		[status addObject:device.address ?: @""];
	} else if (connecting) {
		[status addObject:@"Đang kết nối…"];
	} else if (device.connected) {
		[status addObject:[bt isPlayingOn:device] ? @"Đang phát" : @"Đã kết nối"];
	} else {
		[status addObject:@"Chưa kết nối"];
	}
	NSInteger battery = BDBatteryPercent(device);
	if (battery >= 0) [status addObject:[NSString stringWithFormat:@"pin %ld%%", (long)battery]];
	self.statusLabel.text = [status componentsJoinedByString:@" · "];
	self.statusLabel.textColor = device.connected && mode != BDDeviceCellModeDiscovered ? UIColor.systemBlueColor : UIColor.secondaryLabelColor;

	UIButtonConfiguration *config = self.actionButton.configuration;
	config.showsActivityIndicator = connecting;
	switch (mode) {
		case BDDeviceCellModePaired:
			config.title = device.connected ? @"Ngắt" : @"Kết nối";
			config.baseForegroundColor = device.connected ? UIColor.systemRedColor : nil;
			break;
		case BDDeviceCellModeDiscovered:
			config.title = device.paired ? (device.connected ? @"Đã nối" : @"Kết nối") : @"Ghép đôi";
			break;
		case BDDeviceCellModePlayHere:
			config.title = @"Phát ra đây";
			break;
	}
	if (connecting) config.title = nil;
	self.actionButton.configuration = config;
	self.actionButton.enabled = !connecting;
}

@end
