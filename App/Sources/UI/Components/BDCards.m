#import "BDCards.h"

static void BDStyleCard(UIView *view) {
	view.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
	view.layer.cornerRadius = 18;
	view.layer.cornerCurve = kCACornerCurveContinuous;
	view.clipsToBounds = YES;
}

static UIColor *BDShade(UIColor *color, CGFloat brightness, CGFloat saturation) {
	CGFloat h = 0, s = 0, b = 0, a = 1;
	if (![color getHue:&h saturation:&s brightness:&b alpha:&a]) return color;
	return [UIColor colorWithHue:h saturation:MIN(1, s * saturation) brightness:MIN(1, b * brightness) alpha:a];
}

UICollectionViewLayout *BDCardLayout(BDSectionStyle (^styleForSection)(NSInteger section), BOOL (^hasHeader)(NSInteger section)) {
	UICollectionViewCompositionalLayoutConfiguration *config = [UICollectionViewCompositionalLayoutConfiguration new];
	config.interSectionSpacing = 22;
	return [[UICollectionViewCompositionalLayout alloc] initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger section, id<NSCollectionLayoutEnvironment> environment) {
		BOOL grid = styleForSection(section) == BDSectionStyleGrid;
		CGFloat estimate = grid ? 124 : 64;
		NSCollectionLayoutSize *itemSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:grid ? 0.5 : 1]
			heightDimension:[NSCollectionLayoutDimension estimatedDimension:estimate]];
		NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
		NSCollectionLayoutSize *groupSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
			heightDimension:[NSCollectionLayoutDimension estimatedDimension:estimate]];
		NSCollectionLayoutGroup *group = grid
			? [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize subitem:item count:2]
			: [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize subitems:@[item]];
		group.interItemSpacing = [NSCollectionLayoutSpacing fixedSpacing:12];
		NSCollectionLayoutSection *layoutSection = [NSCollectionLayoutSection sectionWithGroup:group];
		layoutSection.interGroupSpacing = 12;
		layoutSection.contentInsets = NSDirectionalEdgeInsetsMake(0, 16, 0, 16);
		if (hasHeader(section)) {
			NSCollectionLayoutSize *headerSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
				heightDimension:[NSCollectionLayoutDimension estimatedDimension:28]];
			NSCollectionLayoutBoundarySupplementaryItem *header = [NSCollectionLayoutBoundarySupplementaryItem
				boundarySupplementaryItemWithLayoutSize:headerSize elementKind:UICollectionElementKindSectionHeader alignment:NSRectAlignmentTop];
			layoutSection.boundarySupplementaryItems = @[header];
		}
		return layoutSection;
	} configuration:config];
}

#pragma mark - Header

@implementation BDSectionHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_label = [UILabel new];
		_label.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
		_label.translatesAutoresizingMaskIntoConstraints = NO;
		[self addSubview:_label];
		[NSLayoutConstraint activateConstraints:@[
			[_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
			[_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
			[_label.topAnchor constraintEqualToAnchor:self.topAnchor],
			[_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8],
		]];
	}
	return self;
}

@end

#pragma mark - Tile

@interface BDTileCell ()
@property (nonatomic, strong) BDDeviceIconView *iconView;
@property (nonatomic, strong) UIView *dotView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *accessoryButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation BDTileCell

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		UIView *card = self.contentView;
		BDStyleCard(card);

		_iconView = [[BDDeviceIconView alloc] initWithFrame:CGRectZero];
		_dotView = [UIView new];
		_dotView.layer.cornerRadius = 7;
		_dotView.layer.borderWidth = 2.5;
		_dotView.layer.borderColor = UIColor.secondarySystemGroupedBackgroundColor.CGColor;
		_titleLabel = [UILabel new];
		_titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
		_titleLabel.numberOfLines = 2;
		_subtitleLabel = [UILabel new];
		_subtitleLabel.font = [UIFont systemFontOfSize:13];
		_subtitleLabel.textColor = UIColor.secondaryLabelColor;
		_subtitleLabel.numberOfLines = 2;
		_accessoryButton = [UIButton buttonWithType:UIButtonTypeSystem];
		[_accessoryButton addTarget:self action:@selector(accessoryTapped) forControlEvents:UIControlEventTouchUpInside];
		_spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
		_spinner.hidesWhenStopped = YES;

		for (UIView *view in @[_iconView, _dotView, _titleLabel, _subtitleLabel, _accessoryButton, _spinner]) {
			view.translatesAutoresizingMaskIntoConstraints = NO;
			[card addSubview:view];
		}
		[NSLayoutConstraint activateConstraints:@[
			[_iconView.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
			[_iconView.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
			[_iconView.widthAnchor constraintEqualToConstant:46],
			[_iconView.heightAnchor constraintEqualToConstant:46],
			[_dotView.widthAnchor constraintEqualToConstant:14],
			[_dotView.heightAnchor constraintEqualToConstant:14],
			[_dotView.trailingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:2],
			[_dotView.bottomAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:2],
			[_accessoryButton.topAnchor constraintEqualToAnchor:card.topAnchor constant:10],
			[_accessoryButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-10],
			[_accessoryButton.widthAnchor constraintEqualToConstant:34],
			[_accessoryButton.heightAnchor constraintEqualToConstant:34],
			[_spinner.centerXAnchor constraintEqualToAnchor:_accessoryButton.centerXAnchor],
			[_spinner.centerYAnchor constraintEqualToAnchor:_accessoryButton.centerYAnchor],
			[_titleLabel.topAnchor constraintEqualToAnchor:_iconView.bottomAnchor constant:12],
			[_titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
			[_titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-12],
			[_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
			[_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
			[_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
			[_subtitleLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
		]];
	}
	return self;
}

- (void)accessoryTapped {
	if (self.onAccessory) self.onAccessory();
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	[UIView animateWithDuration:0.15 animations:^{
		self.contentView.transform = highlighted ? CGAffineTransformMakeScale(0.97, 0.97) : CGAffineTransformIdentity;
	}];
}

- (void)configureWithKind:(BDDeviceKind *)kind title:(NSString *)title subtitle:(NSString *)subtitle
		dotColor:(UIColor *)dotColor selected:(BOOL)selected busy:(BOOL)busy accessorySymbol:(NSString *)symbol accessoryTint:(UIColor *)tint {
	[self.iconView configureWithKind:kind];
	self.titleLabel.text = title;
	self.subtitleLabel.text = subtitle;
	self.dotView.hidden = dotColor == nil;
	self.dotView.backgroundColor = dotColor;
	self.contentView.layer.borderWidth = selected ? 2 : 0;
	self.contentView.layer.borderColor = (tint ?: UIColor.systemBlueColor).CGColor;
	if (busy) [self.spinner startAnimating];
	else [self.spinner stopAnimating];
	self.accessoryButton.hidden = busy || symbol == nil;
	if (symbol) {
		[self.accessoryButton setImage:BDSymbol(symbol, 26, UIFontWeightRegular) forState:UIControlStateNormal];
		self.accessoryButton.tintColor = tint ?: UIColor.systemBlueColor;
	}
}

@end

#pragma mark - Hero

@interface BDHeroCell ()
@property (nonatomic, strong) CAGradientLayer *gradient;
@property (nonatomic, strong) BDDeviceIconView *iconView;
@property (nonatomic, strong) UILabel *overlineLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UIButton *primaryButton;
@property (nonatomic, strong) UIButton *secondaryButton;
@end

@implementation BDHeroCell

- (UIButton *)glassButton:(SEL)action {
	UIButtonConfiguration *config = [UIButtonConfiguration filledButtonConfiguration];
	config.baseBackgroundColor = [UIColor colorWithWhite:1 alpha:0.22];
	config.baseForegroundColor = UIColor.whiteColor;
	config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
	config.imagePadding = 6;
	UIButton *button = [UIButton buttonWithConfiguration:config primaryAction:nil];
	[button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	return button;
}

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		UIView *card = self.contentView;
		card.layer.cornerRadius = 24;
		card.layer.cornerCurve = kCACornerCurveContinuous;
		card.clipsToBounds = YES;
		_gradient = [CAGradientLayer layer];
		_gradient.startPoint = CGPointMake(0, 0);
		_gradient.endPoint = CGPointMake(1, 1);
		[card.layer insertSublayer:_gradient atIndex:0];

		_iconView = [[BDDeviceIconView alloc] initWithFrame:CGRectZero];
		_iconView.layer.borderWidth = 3;
		_iconView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.55].CGColor;
		_overlineLabel = [UILabel new];
		_overlineLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
		_overlineLabel.textColor = [UIColor colorWithWhite:1 alpha:0.8];
		_titleLabel = [UILabel new];
		_titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
		_titleLabel.textColor = UIColor.whiteColor;
		_titleLabel.numberOfLines = 2;
		_detailLabel = [UILabel new];
		_detailLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
		_detailLabel.textColor = [UIColor colorWithWhite:1 alpha:0.85];
		_detailLabel.numberOfLines = 2;
		_primaryButton = [self glassButton:@selector(primaryTapped)];
		_secondaryButton = [self glassButton:@selector(secondaryTapped)];

		UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[_overlineLabel, _titleLabel, _detailLabel]];
		text.axis = UILayoutConstraintAxisVertical;
		text.spacing = 2;
		UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView, text]];
		top.alignment = UIStackViewAlignmentCenter;
		top.spacing = 14;
		UIStackView *buttons = [[UIStackView alloc] initWithArrangedSubviews:@[_primaryButton, _secondaryButton]];
		buttons.distribution = UIStackViewDistributionFillEqually;
		buttons.spacing = 10;
		UIStackView *all = [[UIStackView alloc] initWithArrangedSubviews:@[top, buttons]];
		all.axis = UILayoutConstraintAxisVertical;
		all.spacing = 18;
		all.translatesAutoresizingMaskIntoConstraints = NO;
		[card addSubview:all];
		[NSLayoutConstraint activateConstraints:@[
			[_iconView.widthAnchor constraintEqualToConstant:64],
			[_iconView.heightAnchor constraintEqualToConstant:64],
			[all.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],
			[all.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
			[all.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
			[all.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18],
		]];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	self.gradient.frame = self.contentView.bounds;
	[CATransaction commit];
}

- (void)primaryTapped {
	if (self.onPrimary) self.onPrimary();
}

- (void)secondaryTapped {
	if (self.onSecondary) self.onSecondary();
}

- (void)configureWithKind:(BDDeviceKind *)kind overline:(NSString *)overline title:(NSString *)title detail:(NSString *)detail
		primary:(NSString *)primary primarySymbol:(NSString *)primarySymbol secondary:(NSString *)secondary secondarySymbol:(NSString *)secondarySymbol {
	self.gradient.colors = @[(id)BDShade(kind.color, 1.08, 0.85).CGColor, (id)BDShade(kind.color, 0.62, 1.15).CGColor];
	[self.iconView configureWithKind:kind];
	self.overlineLabel.text = overline.uppercaseString;
	self.titleLabel.text = title;
	self.detailLabel.text = detail;
	UIButtonConfiguration *p = self.primaryButton.configuration;
	p.title = primary;
	p.image = BDSymbol(primarySymbol, 14, UIFontWeightSemibold);
	self.primaryButton.configuration = p;
	UIButtonConfiguration *s = self.secondaryButton.configuration;
	s.title = secondary;
	s.image = BDSymbol(secondarySymbol, 14, UIFontWeightSemibold);
	self.secondaryButton.configuration = s;
	self.secondaryButton.hidden = secondary == nil;
}

@end

#pragma mark - Power

@interface BDPowerCell ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UISwitch *toggle;
@end

@implementation BDPowerCell

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		UIView *card = self.contentView;
		BDStyleCard(card);
		UIView *badge = [UIView new];
		badge.backgroundColor = UIColor.systemBlueColor;
		badge.layer.cornerRadius = 10;
		badge.layer.cornerCurve = kCACornerCurveContinuous;
		UIImageView *glyph = [[UIImageView alloc] initWithImage:[BDSymbol(@"antenna.radiowaves.left.and.right", 17, UIFontWeightSemibold) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
		glyph.tintColor = UIColor.whiteColor;
		glyph.translatesAutoresizingMaskIntoConstraints = NO;
		[badge addSubview:glyph];
		_titleLabel = [UILabel new];
		_titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
		_subtitleLabel = [UILabel new];
		_subtitleLabel.font = [UIFont systemFontOfSize:13];
		_subtitleLabel.textColor = UIColor.secondaryLabelColor;
		_toggle = [UISwitch new];
		[_toggle addTarget:self action:@selector(toggled) forControlEvents:UIControlEventValueChanged];
		UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _subtitleLabel]];
		text.axis = UILayoutConstraintAxisVertical;
		text.spacing = 1;
		UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[badge, text, _toggle]];
		row.alignment = UIStackViewAlignmentCenter;
		row.spacing = 12;
		row.translatesAutoresizingMaskIntoConstraints = NO;
		[card addSubview:row];
		[NSLayoutConstraint activateConstraints:@[
			[badge.widthAnchor constraintEqualToConstant:36],
			[badge.heightAnchor constraintEqualToConstant:36],
			[glyph.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
			[glyph.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
			[row.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
			[row.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14],
			[row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14],
			[row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14],
		]];
	}
	return self;
}

- (void)toggled {
	if (self.onToggle) self.onToggle(self.toggle.on);
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle on:(BOOL)on enabled:(BOOL)enabled {
	self.titleLabel.text = title;
	self.subtitleLabel.text = subtitle;
	self.toggle.on = on;
	self.toggle.enabled = enabled;
}

@end

#pragma mark - Action

@interface BDActionCell ()
@property (nonatomic, strong) UIImageView *glyph;
@property (nonatomic, strong) UILabel *titleLabel;
@end

@implementation BDActionCell

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		UIView *card = self.contentView;
		BDStyleCard(card);
		_glyph = [UIImageView new];
		_titleLabel = [UILabel new];
		_titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
		UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[_glyph, _titleLabel]];
		row.alignment = UIStackViewAlignmentCenter;
		row.spacing = 10;
		row.translatesAutoresizingMaskIntoConstraints = NO;
		[card addSubview:row];
		[NSLayoutConstraint activateConstraints:@[
			[row.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
			[row.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
			[row.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
		]];
	}
	return self;
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	self.contentView.alpha = highlighted ? 0.6 : 1;
}

- (void)configureWithSymbol:(NSString *)symbol title:(NSString *)title tint:(UIColor *)tint {
	self.glyph.image = [BDSymbol(symbol, 20, UIFontWeightSemibold) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	self.glyph.tintColor = tint;
	self.titleLabel.text = title;
	self.titleLabel.textColor = tint;
}

@end

#pragma mark - Stats

@interface BDStatsCell ()
@property (nonatomic, strong) UIStackView *row;
@end

@implementation BDStatsCell

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		UIView *card = self.contentView;
		BDStyleCard(card);
		_row = [UIStackView new];
		_row.distribution = UIStackViewDistributionFillEqually;
		_row.translatesAutoresizingMaskIntoConstraints = NO;
		[card addSubview:_row];
		[NSLayoutConstraint activateConstraints:@[
			[_row.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
			[_row.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
			[_row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:8],
			[_row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8],
		]];
	}
	return self;
}

- (void)configureWithStats:(NSArray<NSArray<NSString *> *> *)stats {
	for (UIView *view in self.row.arrangedSubviews) [view removeFromSuperview];
	for (NSArray *stat in stats) {
		UILabel *value = [UILabel new];
		value.font = [UIFont monospacedDigitSystemFontOfSize:22 weight:UIFontWeightBold];
		value.textAlignment = NSTextAlignmentCenter;
		value.adjustsFontSizeToFitWidth = YES;
		value.text = stat[0];
		UILabel *caption = [UILabel new];
		caption.font = [UIFont systemFontOfSize:12];
		caption.textColor = UIColor.secondaryLabelColor;
		caption.textAlignment = NSTextAlignmentCenter;
		caption.text = stat[1];
		UIStackView *column = [[UIStackView alloc] initWithArrangedSubviews:@[value, caption]];
		column.axis = UILayoutConstraintAxisVertical;
		column.spacing = 2;
		[self.row addArrangedSubview:column];
	}
}

@end

#pragma mark - Round action

@interface BDRoundAction ()
@property (nonatomic, strong) UIView *circle;
@property (nonatomic, strong) UIImageView *glyph;
@property (nonatomic, strong) UILabel *caption;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation BDRoundAction

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		_circle = [UIView new];
		_circle.layer.cornerRadius = 27;
		_circle.userInteractionEnabled = NO;
		_glyph = [UIImageView new];
		_glyph.contentMode = UIViewContentModeCenter;
		_spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
		_spinner.hidesWhenStopped = YES;
		_caption = [UILabel new];
		_caption.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
		_caption.textAlignment = NSTextAlignmentCenter;
		_caption.numberOfLines = 2;
		for (UIView *view in @[_circle, _glyph, _spinner, _caption]) {
			view.translatesAutoresizingMaskIntoConstraints = NO;
			view.userInteractionEnabled = NO;
			[self addSubview:view];
		}
		[NSLayoutConstraint activateConstraints:@[
			[_circle.topAnchor constraintEqualToAnchor:self.topAnchor],
			[_circle.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
			[_circle.widthAnchor constraintEqualToConstant:54],
			[_circle.heightAnchor constraintEqualToConstant:54],
			[_glyph.centerXAnchor constraintEqualToAnchor:_circle.centerXAnchor],
			[_glyph.centerYAnchor constraintEqualToAnchor:_circle.centerYAnchor],
			[_spinner.centerXAnchor constraintEqualToAnchor:_circle.centerXAnchor],
			[_spinner.centerYAnchor constraintEqualToAnchor:_circle.centerYAnchor],
			[_caption.topAnchor constraintEqualToAnchor:_circle.bottomAnchor constant:6],
			[_caption.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
			[_caption.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
			[_caption.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
		]];
	}
	return self;
}

- (void)setHighlighted:(BOOL)highlighted {
	[super setHighlighted:highlighted];
	self.alpha = highlighted ? 0.5 : 1;
}

- (void)configureWithSymbol:(NSString *)symbol title:(NSString *)title tint:(UIColor *)tint busy:(BOOL)busy {
	self.circle.backgroundColor = [tint colorWithAlphaComponent:0.15];
	self.glyph.image = [BDSymbol(symbol, 21, UIFontWeightSemibold) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	self.glyph.tintColor = tint;
	self.glyph.hidden = busy;
	self.spinner.color = tint;
	if (busy) [self.spinner startAnimating];
	else [self.spinner stopAnimating];
	self.caption.text = title;
	self.caption.textColor = tint;
	self.enabled = !busy;
}

@end
