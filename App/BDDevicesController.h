#import <UIKit/UIKit.h>

// "Thiết bị" tab: Bluetooth power, connected devices, other paired devices, add new.
@interface BDDevicesController : UITableViewController
@end

// Confirm sheet shared by the list and the detail page.
void BDPresentForget(UIViewController *host, id device, void (^done)(void));
