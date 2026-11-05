// BluedeckSystem: one dylib loaded into every UIKit process, with two roles.
//   SpringBoard → BDSpringBoardStart(): publishes mix settings, enforces per-device profiles.
//   Other apps  → BDMixStart(): keeps the music playing when this app plays audio/video.
#import <Foundation/Foundation.h>

void BDSpringBoardStart(void);
void BDMixStart(NSString *bundleID);

uint64_t BDNotifyGetState(const char *name);
// Sets a notify state and keeps the registration alive (notifyd forgets unregistered names).
void BDNotifySetState(const char *name, uint64_t state);
int BDNotifyHoldToken(const char *name);
