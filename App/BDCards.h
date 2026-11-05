#import <UIKit/UIKit.h>
#import "BDDeviceStyle.h"

// Card-style building blocks shared by the Thiết bị and Âm thanh tabs.

typedef NS_ENUM(NSInteger, BDSectionStyle) {
	BDSectionStyleFull, // one card per row
	BDSectionStyleGrid, // two cards per row
};

// Compositional layout: each section is either full-width cards or a 2-column grid, with an
// optional header (supplementary kind UICollectionElementKindSectionHeader).
UICollectionViewLayout *BDCardLayout(BDSectionStyle (^styleForSection)(NSInteger section), BOOL (^hasHeader)(NSInteger section));

@interface BDSectionHeaderView : UICollectionReusableView
@property (nonatomic, strong, readonly) UILabel *label;
@end

// Device / route tile: avatar, name, status line, status dot, optional round accessory button.
@interface BDTileCell : UICollectionViewCell
@property (nonatomic, copy) void (^onAccessory)(void);
- (void)configureWithKind:(BDDeviceKind *)kind title:(NSString *)title subtitle:(NSString *)subtitle
	dotColor:(UIColor *)dotColor selected:(BOOL)selected busy:(BOOL)busy accessorySymbol:(NSString *)symbol accessoryTint:(UIColor *)tint;
@end

// Big "Đang phát" card on a gradient of the device's colour, with two buttons.
@interface BDHeroCell : UICollectionViewCell
@property (nonatomic, copy) void (^onPrimary)(void);
@property (nonatomic, copy) void (^onSecondary)(void);
- (void)configureWithKind:(BDDeviceKind *)kind overline:(NSString *)overline title:(NSString *)title detail:(NSString *)detail
	primary:(NSString *)primary primarySymbol:(NSString *)primarySymbol secondary:(NSString *)secondary secondarySymbol:(NSString *)secondarySymbol;
@end

// Bluetooth power row: icon, title, subtitle, switch.
@interface BDPowerCell : UICollectionViewCell
@property (nonatomic, strong, readonly) UISwitch *toggle;
@property (nonatomic, copy) void (^onToggle)(BOOL on);
- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle on:(BOOL)on enabled:(BOOL)enabled;
@end

// Full-width tappable card: tinted symbol + title (e.g. "Thêm thiết bị mới").
@interface BDActionCell : UICollectionViewCell
- (void)configureWithSymbol:(NSString *)symbol title:(NSString *)title tint:(UIColor *)tint;
@end

// Row of big numbers with captions (sample rate / channels / latency).
@interface BDStatsCell : UICollectionViewCell
- (void)configureWithStats:(NSArray<NSArray<NSString *> *> *)stats; // @[@[value, caption], …]
@end

// Round button with a caption under it, like the Contacts app action row.
@interface BDRoundAction : UIControl
- (void)configureWithSymbol:(NSString *)symbol title:(NSString *)title tint:(UIColor *)tint busy:(BOOL)busy;
@end
