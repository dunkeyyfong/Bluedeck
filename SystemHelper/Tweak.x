#import "BDSystem.h"
#import <notify.h>

uint64_t BDNotifyGetState(const char *name) {
	int token = 0;
	uint64_t state = 0;
	if (notify_register_check(name, &token) != NOTIFY_STATUS_OK) return 0;
	notify_get_state(token, &state);
	notify_cancel(token);
	return state;
}

void BDNotifySetState(const char *name, uint64_t state) {
	int token = 0;
	if (notify_register_check(name, &token) != NOTIFY_STATUS_OK) return;
	notify_set_state(token, state);
	notify_cancel(token);
}

%ctor {
	NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
	if (!bundleID) return;
	if ([bundleID isEqualToString:@"com.apple.springboard"]) {
		BDSpringBoardStart();
		return;
	}
	// Never touch our own processes or Settings.
	if ([bundleID hasPrefix:@"com.pgong."] || [bundleID isEqualToString:@"com.apple.Preferences"]) return;
	BDMixStart(bundleID);
}
