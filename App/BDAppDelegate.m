#import "BDAppDelegate.h"
#import "BDDiagController.h"

@implementation BDAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[BDDiagController new]];
	nav.navigationBar.prefersLargeTitles = YES;
	self.window.rootViewController = nav;
	self.window.tintColor = UIColor.systemBlueColor;
	[self.window makeKeyAndVisible];
	return YES;
}

@end
