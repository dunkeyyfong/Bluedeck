// Private API declarations. Classes are always looked up at runtime (NSClassFromString),
// so nothing here is linked; it only gives the compiler the selectors.
// Verified against iOS 15.8.4 method lists (Bluedeck diagnostics report, 2026-11-05).
#import <Foundation/Foundation.h>

@interface BluetoothDevice : NSObject
- (NSString *)name;
- (NSString *)productName;
- (NSString *)address;
- (NSString *)aclUID;
- (int)type;
- (unsigned int)majorClass;
- (unsigned int)minorClass;
- (unsigned int)vendorId;
- (unsigned int)productId;
- (BOOL)connected;
- (BOOL)paired;
- (BOOL)isAppleAudioDevice;
- (unsigned long long)connectedServices;
- (int)batteryLevel;
- (BOOL)supportsBatteryLevel;
- (BOOL)isServiceSupported:(unsigned int)service;
- (BOOL)inEarStatusPrimary:(int *)primary secondary:(int *)secondary;
- (unsigned int)clickHoldMode:(int *)left rightAction:(int *)right;
- (unsigned int)doubleTapActionEx:(unsigned int *)left rightAction:(unsigned int *)right;
- (void)connect;
- (void)connectWithServices:(unsigned int)services;
- (void)disconnect;
- (void)unpair;
- (void *)device; // BTDeviceImpl * for the MobileBluetooth C API
- (void)acceptSSP:(long long)result;
- (void)setPIN:(NSString *)pin;
@end

@interface BluetoothManager : NSObject
+ (id)sharedInstance;
+ (int)lastInitError;
- (BOOL)available;
- (BOOL)powered;
- (BOOL)enabled;
- (BOOL)setPowered:(BOOL)powered;
- (BOOL)setEnabled:(BOOL)enabled;
- (NSString *)localAddress;
- (NSArray *)pairedDevices;
- (NSArray *)connectedDevices;
- (NSArray *)connectingDevices;
- (void)connectDevice:(BluetoothDevice *)device;
- (void)connectDevice:(BluetoothDevice *)device withServices:(unsigned int)services;
- (void)disconnectDevice:(BluetoothDevice *)device;
- (void)unpairDevice:(BluetoothDevice *)device;
- (void)setDeviceScanningEnabled:(BOOL)enabled;
- (void)scanForServices:(unsigned int)services;
- (void)setDevicePairingEnabled:(BOOL)enabled;
- (BOOL)deviceScanningEnabled;
- (void)acceptSSP:(long long)result forDevice:(BluetoothDevice *)device;
- (void)setPincode:(NSString *)pin forDevice:(BluetoothDevice *)device;
- (void)cancelPairing;
@end

@interface BCBatteryDeviceController : NSObject
+ (id)sharedInstance;
- (NSArray *)connectedDevices;
- (void)addBatteryDeviceObserver:(id)observer queue:(dispatch_queue_t)queue;
- (void)removeBatteryDeviceObserver:(id)observer;
@end

@interface MPAVBatteryLevel : NSObject
- (NSNumber *)singlePercentage;
- (NSNumber *)leftPercentage;
- (NSNumber *)rightPercentage;
- (NSNumber *)casePercentage;
@end

@interface MPAVRoute : NSObject
- (NSString *)routeName;
- (NSString *)routeUID;
- (BOOL)isPicked;
- (BOOL)isDeviceSpeakerRoute;
- (BOOL)isHeadphonesRoute;
- (BOOL)isAirpodsRoute;
- (long long)routeSubtype;
- (MPAVBatteryLevel *)batteryLevel;
@end

@interface MPAVRoutingController : NSObject
- (instancetype)initWithName:(NSString *)name;
- (void)setDiscoveryMode:(long long)mode;
- (void)setDelegate:(id)delegate;
- (void)fetchAvailableRoutesWithCompletionHandler:(void (^)(NSArray *routes))handler;
- (BOOL)pickRoute:(MPAVRoute *)route;
@end
