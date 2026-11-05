// "Giữ nhạc khi phát video": in apps the user picked, every audio session that would
// interrupt other audio (SoloAmbient, Playback without MixWithOthers) is turned into a
// Playback session that mixes with others and doesn't duck them.
//
// Video apps (YouTube…) also ask for routeSharingPolicy LongFormVideo, which iOS refuses to
// combine with MixWithOthers — the whole setCategory call fails and the app stays exclusive.
// So the policy is forced back to Default as well.
#import "BDSystem.h"
#import "BDPrefs.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>

static NSString *gStateName;
static NSString *gStatusName;
static BOOL gActive;
static uint8_t gStatus;

// Lets Bluedeck show, per app, whether the hooks loaded and whether iOS accepted the mix.
static void BDMixReport(uint8_t flag) {
	gStatus |= flag;
	uint64_t now = (uint64_t)NSDate.date.timeIntervalSince1970;
	BDNotifySetState(gStatusName.UTF8String, (now << 8) | gStatus);
}

static void BDMixRefresh(void) {
	gActive = BDNotifyGetState(kBDMixEnabledState) == 1 && BDNotifyGetState(gStateName.UTF8String) == 1;
}

static AVAudioSessionCategory BDMixCategory(AVAudioSessionCategory category) {
	return [category isEqualToString:AVAudioSessionCategorySoloAmbient] ? AVAudioSessionCategoryPlayback : category;
}

static BOOL BDMixApplies(AVAudioSessionCategory category) {
	return [category isEqualToString:AVAudioSessionCategoryPlayback];
}

static AVAudioSessionCategoryOptions BDMixOptions(AVAudioSessionCategory category, AVAudioSessionCategoryOptions options) {
	if (!BDMixApplies(category)) return options;
	// Drop DuckOthers (0x2) and the "interrupt spoken audio" bit (0x10), keep/add MixWithOthers (0x1).
	return (options & ~(AVAudioSessionCategoryOptions)0x12) | AVAudioSessionCategoryOptionMixWithOthers;
}

static void BDMixResult(BOOL applied, BOOL ok) {
	if (applied) BDMixReport(ok ? kBDMixStatusAccepted : kBDMixStatusRejected);
}

static void BDMixEnsure(AVAudioSession *session) {
	if (!gActive) return;
	AVAudioSessionCategory category = session.category;
	BOOL solo = [category isEqualToString:AVAudioSessionCategorySoloAmbient];
	BOOL playback = [category isEqualToString:AVAudioSessionCategoryPlayback];
	BOOL exclusive = playback && ((session.categoryOptions & AVAudioSessionCategoryOptionMixWithOthers) == 0
		|| session.routeSharingPolicy != AVAudioSessionRouteSharingPolicyDefault);
	if (!solo && !exclusive) return;
	[session setCategory:AVAudioSessionCategoryPlayback mode:session.mode routeSharingPolicy:AVAudioSessionRouteSharingPolicyDefault
		options:BDMixOptions(AVAudioSessionCategoryPlayback, session.categoryOptions) error:nil];
}

%group Mix

%hook AVAudioSession

- (BOOL)setCategory:(AVAudioSessionCategory)category error:(NSError **)outError {
	if (!gActive) return %orig;
	AVAudioSessionCategory mixed = BDMixCategory(category);
	return [self setCategory:mixed withOptions:BDMixOptions(mixed, 0) error:outError];
}

- (BOOL)setCategory:(AVAudioSessionCategory)category withOptions:(AVAudioSessionCategoryOptions)options error:(NSError **)outError {
	if (!gActive) return %orig;
	AVAudioSessionCategory mixed = BDMixCategory(category);
	BOOL ok = %orig(mixed, BDMixOptions(mixed, options), outError);
	BDMixResult(BDMixApplies(mixed), ok);
	return ok;
}

- (BOOL)setCategory:(AVAudioSessionCategory)category mode:(AVAudioSessionMode)mode options:(AVAudioSessionCategoryOptions)options error:(NSError **)outError {
	if (!gActive) return %orig;
	AVAudioSessionCategory mixed = BDMixCategory(category);
	BOOL ok = %orig(mixed, mode, BDMixOptions(mixed, options), outError);
	BDMixResult(BDMixApplies(mixed), ok);
	return ok;
}

- (BOOL)setCategory:(AVAudioSessionCategory)category mode:(AVAudioSessionMode)mode routeSharingPolicy:(AVAudioSessionRouteSharingPolicy)policy options:(AVAudioSessionCategoryOptions)options error:(NSError **)outError {
	if (!gActive) return %orig;
	AVAudioSessionCategory mixed = BDMixCategory(category);
	BOOL applies = BDMixApplies(mixed);
	// Long-form policies can't be combined with MixWithOthers.
	BOOL ok = %orig(mixed, mode, applies ? AVAudioSessionRouteSharingPolicyDefault : policy, BDMixOptions(mixed, options), outError);
	BDMixResult(applies, ok);
	return ok;
}

// Apps that never set a category play in SoloAmbient; fix it right before activation.
- (BOOL)setActive:(BOOL)active error:(NSError **)outError {
	if (active) BDMixEnsure(self);
	return %orig;
}

- (BOOL)setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError {
	if (active) BDMixEnsure(self);
	return %orig;
}

%end

%end

void BDMixStart(NSString *bundleID) {
	gStateName = BDMixAppStateName(bundleID);
	gStatusName = BDMixStatusStateName(bundleID);
	BDMixRefresh();
	// Only apps that were picked when they launched get hooks; others stay untouched.
	if (BDNotifyGetState(gStateName.UTF8String) != 1) return;
	%init(Mix);
	BDMixReport(kBDMixStatusLoaded);
	int token = 0;
	notify_register_dispatch(kBDPrefsChanged, &token, dispatch_get_main_queue(), ^(int t) {
		BDMixRefresh();
		BDMixEnsure(AVAudioSession.sharedInstance);
	});
	[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil
		queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
			BDMixEnsure(AVAudioSession.sharedInstance);
		}];
}
