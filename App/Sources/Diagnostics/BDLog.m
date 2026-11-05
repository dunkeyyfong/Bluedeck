#import "BDLog.h"

NSString *const BDLogDoneMarker = @"✓ XONG";

static NSString *BDLogPath(void) {
	return @"/var/mobile/Documents/Bluedeck/progress.log";
}

static void BDLogWrite(NSString *line, BOOL truncate) {
	NSString *path = BDLogPath();
	[NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
	if (truncate || ![NSFileManager.defaultManager fileExistsAtPath:path]) {
		[NSData.data writeToFile:path atomically:NO];
	}
	NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
	if (!handle) return;
	[handle seekToEndOfFile];
	[handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
	[handle synchronizeFile];
	[handle closeFile];
}

static NSString *BDTimestamp(void) {
	NSDateFormatter *fmt = [NSDateFormatter new];
	fmt.dateFormat = @"HH:mm:ss.SSS";
	return [fmt stringFromDate:NSDate.date];
}

void BDLogReset(void) {
	BDLogWrite(@"", YES);
}

void BDLog(NSString *format, ...) {
	va_list args;
	va_start(args, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	BDLogWrite([NSString stringWithFormat:@"%@ %@\n", BDTimestamp(), message], NO);
}

NSString *BDLogUnfinishedStep(void) {
	NSString *text = [NSString stringWithContentsOfFile:BDLogPath() encoding:NSUTF8StringEncoding error:nil];
	NSArray *lines = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsSeparatedByString:@"\n"];
	NSString *last = lines.lastObject;
	if (!last.length || [last containsString:BDLogDoneMarker]) return nil;
	return last;
}

static void BDUncaughtException(NSException *exception) {
	BDLog(@"✗ EXCEPTION %@: %@\n%@", exception.name, exception.reason,
		[exception.callStackSymbols componentsJoinedByString:@"\n"]);
}

void BDInstallExceptionLogger(void) {
	NSSetUncaughtExceptionHandler(&BDUncaughtException);
}

NSException *BDStep(NSString *name, void (^block)(void)) {
	BDLog(@"→ %@", name);
	@try {
		block();
	} @catch (NSException *e) {
		BDLog(@"✗ %@: %@: %@", name, e.name, e.reason);
		return e;
	}
	return nil;
}
