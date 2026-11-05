#import <UIKit/UIKit.h>
#import "BDPrivate.h"

typedef NS_ENUM(NSInteger, BDDeviceCellMode) {
	BDDeviceCellModePaired,     // button: Kết nối / Ngắt
	BDDeviceCellModeDiscovered, // button: Ghép đôi
	BDDeviceCellModePlayHere,   // button: Phát ra đây
};

// Avatar + name + status line + one trailing action button.
@interface BDDeviceCell : UITableViewCell
@property (nonatomic, copy) void (^onAction)(void);
- (void)configureWithDevice:(BluetoothDevice *)device mode:(BDDeviceCellMode)mode;
@end
