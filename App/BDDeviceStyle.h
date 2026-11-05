#import <UIKit/UIKit.h>
#import "BDPrivate.h"

// What a device is, derived from its Class of Device (and Apple product id).
@interface BDDeviceKind : NSObject
@property (nonatomic, copy) NSString *name;   // "Loa", "Tai nghe", …
@property (nonatomic, copy) NSString *symbol; // SF Symbol
@property (nonatomic, strong) UIColor *color;
+ (instancetype)kindForDevice:(BluetoothDevice *)device;
// For devices known only by their Class of Device (scan results relayed from Settings).
+ (instancetype)kindForMajor:(unsigned int)majorClass minor:(unsigned int)minorClass;
@end

// "Âm thanh/Video · Loa (0x240414)" style description of the Class of Device.
NSString *BDClassDescription(BluetoothDevice *device);

UIImage *BDSymbol(NSString *name, CGFloat pointSize, UIFontWeight weight);

// Round device avatar: the kind's symbol on a gradient.
@interface BDDeviceIconView : UIView
- (void)configureWithDevice:(BluetoothDevice *)device;
- (void)configureWithKind:(BDDeviceKind *)kind;
@end
