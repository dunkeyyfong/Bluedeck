#import "BDAppDelegate.h"
#import "BDAudioController.h"
#import "BDBluetooth.h"
#import "BDDevicesController.h"
#import "BDHelperClient.h"

@implementation BDAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	[BDBluetooth shared];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(pairingRequest:) name:BDBluetoothPairingRequestNotification object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(forgetFailed:) name:BDBluetoothForgetFailedNotification object:nil];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(helperError:) name:BDBluetoothHelperErrorNotification object:nil];

	// Diagnostics lives under the gear button (Cài đặt › Nâng cao), not in the tab bar.
	UITabBarController *tabs = [UITabBarController new];
	NSMutableArray *navs = [NSMutableArray array];
	for (UIViewController *root in @[[BDDevicesController new], [BDAudioController new]]) {
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
		nav.navigationBar.prefersLargeTitles = YES;
		nav.tabBarItem = root.tabBarItem;
		[navs addObject:nav];
	}
	tabs.viewControllers = navs;

	self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
	self.window.rootViewController = tabs;
	self.window.tintColor = UIColor.systemBlueColor;
	[self.window makeKeyAndVisible];
	return YES;
}

- (UIViewController *)topController {
	UIViewController *top = self.window.rootViewController;
	while (top.presentedViewController) top = top.presentedViewController;
	return top;
}

- (void)helperError:(NSNotification *)note {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:note.userInfo[@"title"] message:note.userInfo[@"message"] preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"Mở Cài đặt › Bluetooth" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		BDOpenBluetoothSettings();
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
	[[self topController] presentViewController:alert animated:YES completion:nil];
}

- (void)forgetFailed:(NSNotification *)note {
	NSString *message = [NSString stringWithFormat:@"Không quên được “%@”.\n\nLý do: %@",
		note.userInfo[@"name"], note.userInfo[@"events"] ?: @"không rõ"];
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chưa quên được thiết bị" message:message preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"Mở Cài đặt › Bluetooth" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		BDOpenBluetoothSettings();
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Sao chép" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		UIPasteboard.generalPasteboard.string = message;
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
	[[self topController] presentViewController:alert animated:YES completion:nil];
}

// bluetoothd wants a PIN or a confirmation while pairing.
- (void)pairingRequest:(NSNotification *)note {
	NSString *name = note.userInfo[@"name"];
	BluetoothDevice *device = note.userInfo[@"device"];
	NSString *info = note.userInfo[@"info"];
	BOOL wantsPIN = [name containsString:@"PIN"] || [name containsString:@"Pincode"];
	NSString *title = device.name ? [NSString stringWithFormat:@"Ghép đôi “%@”", device.name] : @"Ghép đôi thiết bị";
	NSString *message = wantsPIN ? @"Nhập mã PIN của thiết bị (thường là 0000 hoặc 1234)."
		: [NSString stringWithFormat:@"Xác nhận mã hiển thị trên thiết bị khớp với mã dưới đây.\n\n%@", info ?: @""];

	UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
	if (wantsPIN) {
		[alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
			field.keyboardType = UIKeyboardTypeNumberPad;
			field.text = @"0000";
		}];
	}
	[alert addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
		[BDBluetooth.shared cancelPairing];
	}]];
	[alert addAction:[UIAlertAction actionWithTitle:@"Ghép đôi" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		if (wantsPIN) [BDBluetooth.shared sendPIN:alert.textFields.firstObject.text forDevice:device];
		else [BDBluetooth.shared acceptPairingForDevice:device];
	}]];
	[[self topController] presentViewController:alert animated:YES completion:nil];
}

@end
