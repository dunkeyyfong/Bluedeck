#import <UIKit/UIKit.h>

// "Thiết bị" tab: power card, "Đang phát" hero card, grids of connected / other devices, add new.
@interface BDDevicesController : UICollectionViewController
@end

// Confirm sheet shared by the list and the detail page.
void BDPresentForget(UIViewController *host, id device, void (^done)(void));

// Gear button that opens the Bluedeck settings page (shared by both tabs).
UIBarButtonItem *BDSettingsButton(UIViewController *host);
