#import <UIKit/UIKit.h>

// "Thiết bị" tab: Bluetooth power, connected devices, other paired devices, add new.
@interface BDDevicesController : UITableViewController
@end

// Shared confirm/rename helpers used by the list and the detail page.
void BDPresentRename(UIViewController *host, id device);
void BDPresentForget(UIViewController *host, id device, void (^done)(void));
