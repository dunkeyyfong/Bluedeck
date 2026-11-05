// Private API declarations. Classes are always looked up at runtime (NSClassFromString),
// so nothing here is linked; it only gives the compiler the selectors.
#import <Foundation/Foundation.h>

@interface BluetoothDevice : NSObject
- (NSString *)name;
- (NSString *)address;
- (BOOL)connected;
- (BOOL)paired;
- (int)batteryLevel;
- (BOOL)supportsBatteryLevel;
- (BOOL)isServiceSupported:(unsigned int)service;
- (BOOL)inEarStatusPrimary:(int *)primary secondary:(int *)secondary;
- (unsigned int)clickHoldMode:(int *)left rightAction:(int *)right;
- (unsigned int)doubleTapActionEx:(unsigned int *)left rightAction:(unsigned int *)right;
@end

@interface BluetoothManager : NSObject
+ (id)sharedInstance;
+ (int)lastInitError;
- (BOOL)available;
- (NSArray *)pairedDevices;
- (NSArray *)connectedDevices;
- (NSArray *)connectingDevices;
@end

@interface BCBatteryDeviceController : NSObject
+ (id)sharedInstance;
- (NSArray *)connectedDevices;
- (void)addBatteryDeviceObserver:(id)observer queue:(dispatch_queue_t)queue;
- (void)removeBatteryDeviceObserver:(id)observer;
@end

@interface MPAVRoutingController : NSObject
- (instancetype)initWithName:(NSString *)name;
- (void)setDiscoveryMode:(long long)mode;
- (void)fetchAvailableRoutesWithCompletionHandler:(void (^)(NSArray *routes))handler;
@end
