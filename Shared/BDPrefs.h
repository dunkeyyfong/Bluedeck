// Preferences shared by Bluedeck.app (writes) and BluedeckSystem (reads in SpringBoard).
// Sandboxed apps can't read the plist, so SpringBoard republishes the mix settings as Darwin
// notify state that every app can query.
#import <Foundation/Foundation.h>

#define kBDPrefsPath @"/var/mobile/Library/Preferences/com.pgong.bluedeck.plist"
#define kBDPrefsChanged "com.pgong.bluedeck/prefs-changed"

// Keep music playing when another app plays video.
#define kBDPrefMixEnabled @"mixEnabled"   // BOOL
#define kBDPrefMixApps @"mixApps"         // NSArray<NSString *> bundle ids
#define kBDMixEnabledState "com.pgong.bluedeck.mix/enabled"
#define kBDMixAppStatePrefix "com.pgong.bluedeck.mix/app/"

// Which profiles a device may use: @{address: @(BDProfile)}.
#define kBDPrefProfiles @"profiles"
// Set once Bluedeck saw BTDeviceDisconnectServices work; SpringBoard only enforces after that.
#define kBDPrefProfilesVerified @"profilesVerified"

typedef NS_ENUM(NSInteger, BDProfile) {
	BDProfileBoth = 0,
	BDProfileMusic = 1, // A2DP + AVRCP only, calls stay on the iPhone
	BDProfileCalls = 2, // hands-free only
};

#define kBDServiceHandsfree 0x1u
#define kBDServiceMusic 0x18u // AVRCP 0x8 | A2DP 0x10

static inline NSString *BDMixAppStateName(NSString *bundleID) {
	return [@kBDMixAppStatePrefix stringByAppendingString:bundleID ?: @""];
}
