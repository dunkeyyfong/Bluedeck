#import <Foundation/Foundation.h>

// Breadcrumb log at /var/mobile/Documents/Bluedeck/progress.log. Each line is flushed
// immediately, so after a crash the last line names the step that was running.
void BDLogReset(void);
void BDLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

// Last line of the previous run's log, or nil if that run finished cleanly.
NSString *BDLogUnfinishedStep(void);

// Writes uncaught Objective-C exceptions (reason + stack) into the log before the crash.
void BDInstallExceptionLogger(void);

// Runs block, logging "→ name" first; an exception is logged and returned instead of crashing.
NSException *BDStep(NSString *name, void (^block)(void));

extern NSString *const BDLogDoneMarker;
