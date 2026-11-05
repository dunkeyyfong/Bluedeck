#import <Foundation/Foundation.h>
#import "BDHelperProtocol.h"

// Talks to BluedeckHelper inside Settings. Wakes Settings in the background when it is not
// running (or is suspended and cannot answer), then sends the request.
@interface BDHelperClient : NSObject

+ (instancetype)shared;

// wake = NO only sends if Settings is already answering (used for "stop scanning").
- (void)send:(BDHelperOp)op address:(NSString *)address wake:(BOOL)wake completion:(void (^)(BDHelperStatus status))completion;

// Devices Settings found during the last scan: @[@{address, name, major, minor, paired}].
@property (nonatomic, copy) void (^onDiscovered)(NSArray<NSDictionary *> *devices);

@end

NSString *BDHelperStatusText(BDHelperStatus status);
