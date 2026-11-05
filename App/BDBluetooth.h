#import <Foundation/Foundation.h>
#import "BDPrivate.h"

// Posted (debounced, main thread) whenever devices, power, scanning or audio routes change.
extern NSString *const BDBluetoothDidChangeNotification;
// Posted when bluetoothd asks for pairing input. userInfo: @"name", @"device" (maybe), @"info".
extern NSString *const BDBluetoothPairingRequestNotification;

// Service bits of -[BluetoothDevice isServiceSupported:] / connectedServices.
// 0x1/0x8/0x10/0x2000 matched against real devices in the P0 report; the rest are best guesses.
typedef NS_OPTIONS(unsigned int, BDService) {
	BDServiceHandsfree = 0x1,
	BDServicePhonebook = 0x2,
	BDServiceAVRCP = 0x8,
	BDServiceA2DP = 0x10,
	BDServiceHID = 0x20,
	BDServiceDeviceID = 0x2000,
};

// Single owner of BluetoothManager + MPAVRoutingController for the app.
@interface BDBluetooth : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) BOOL available;
@property (nonatomic, readonly) BOOL powered;
@property (nonatomic, readonly) NSString *localAddress;
@property (nonatomic, readonly) NSArray<BluetoothDevice *> *pairedDevices;     // connected first, then by name
@property (nonatomic, readonly) NSArray<BluetoothDevice *> *discoveredDevices; // not paired yet
@property (nonatomic, readonly) BOOL scanning;
@property (nonatomic, readonly) NSArray<MPAVRoute *> *routes;

- (void)setPowered:(BOOL)powered;
- (BOOL)isConnecting:(BluetoothDevice *)device;
- (void)connect:(BluetoothDevice *)device;
- (void)disconnect:(BluetoothDevice *)device;
- (void)forget:(BluetoothDevice *)device;
- (BOOL)rename:(BluetoothDevice *)device to:(NSString *)name;

- (void)startScan;
- (void)stopScan;
- (void)pair:(BluetoothDevice *)device;
- (void)acceptPairingForDevice:(BluetoothDevice *)device;
- (void)sendPIN:(NSString *)pin forDevice:(BluetoothDevice *)device;
- (void)cancelPairing;

- (void)refreshRoutes;
- (MPAVRoute *)pickedRoute;
- (MPAVRoute *)routeForDevice:(BluetoothDevice *)device;
- (BOOL)isPlayingOn:(BluetoothDevice *)device;
- (void)pickRoute:(MPAVRoute *)route;
// Connects first when needed, then switches audio output to the device once its route shows up.
- (void)playOn:(BluetoothDevice *)device;
- (BOOL)isWaitingToPlayOn:(BluetoothDevice *)device;

@end

// Helpers shared by the UI.
BOOL BDDeviceSupports(BluetoothDevice *device, BDService service);
NSArray<NSString *> *BDServiceNames(unsigned long long mask);
NSArray<NSString *> *BDSupportedServiceNames(BluetoothDevice *device);
// Battery percentage from the device or its audio route, or -1.
NSInteger BDBatteryPercent(BluetoothDevice *device);
