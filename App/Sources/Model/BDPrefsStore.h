#import <Foundation/Foundation.h>
#import "BDPrefs.h"

// Bluedeck's settings, stored in kBDPrefsPath so BluedeckSystem (SpringBoard) can read them.
// Every change is written immediately and announced with kBDPrefsChanged.
@interface BDPrefsStore : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) BOOL mixEnabled;
@property (nonatomic, copy) NSArray<NSString *> *mixApps;
@property (nonatomic, assign) BOOL profilesVerified;

- (BDProfile)profileForAddress:(NSString *)address;
- (void)setProfile:(BDProfile)profile forAddress:(NSString *)address;

@end

// Current value of a Darwin notify state (0 if unset).
uint64_t BDGetState(const char *name);
