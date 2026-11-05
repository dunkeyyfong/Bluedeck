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

// notifyd drops a name's state as soon as nobody is registered for it, so whoever sets a
// state keeps its registration for the life of the process.
int BDNotifyHoldToken(const char *name) {
	static NSMutableDictionary<NSString *, NSNumber *> *tokens;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ tokens = [NSMutableDictionary dictionary]; });
	NSString *key = @(name);
	@synchronized (tokens) {
		NSNumber *existing = tokens[key];
		if (existing) return existing.intValue;
		int token = 0;
		if (notify_register_check(name, &token) != NOTIFY_STATUS_OK) return -1;
		tokens[key] = @(token);
		return token;
	}
}

void BDNotifySetState(const char *name, uint64_t state) {
	int token = BDNotifyHoldToken(name);
	if (token >= 0) notify_set_state(token, state);
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
