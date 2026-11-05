#import <UIKit/UIKit.h>
#import "BDPrivate.h"

// What a device is, derived from its Class of Device (and Apple product id).
@interface BDDeviceKind : NSObject
@property (nonatomic, copy) NSString *name;   // "Loa", "Tai nghe", …
@property (nonatomic, copy) NSString *symbol; // SF Symbol
@property (nonatomic, strong) UIColor *color;
+ (instancetype)kindForDevice:(BluetoothDevice *)device;
@end

// "Âm thanh/Video · Loa (0x240414)" style description of the Class of Device.
NSString *BDClassDescription(BluetoothDevice *device);

// User-chosen photos, stored in /var/mobile/Library/Bluedeck/Photos.
UIImage *BDDevicePhoto(NSString *address);
BOOL BDSaveDevicePhoto(UIImage *image, NSString *address);
void BDRemoveDevicePhoto(NSString *address);

UIImage *BDSymbol(NSString *name, CGFloat pointSize, UIFontWeight weight);

// Round device avatar: the user's photo, or the kind's symbol on a gradient.
@interface BDDeviceIconView : UIView
- (void)configureWithDevice:(BluetoothDevice *)device;
@end
