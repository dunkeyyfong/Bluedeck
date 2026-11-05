#import <Foundation/Foundation.h>
#import "BDPrivate.h"

// Posted (debounced, main thread) whenever devices, power, scanning or audio routes change.
extern NSString *const BDBluetoothDidChangeNotification;
// Posted when bluetoothd asks for pairing input. userInfo: @"name", @"device" (maybe), @"info".
extern NSString *const BDBluetoothPairingRequestNotification;
// Posted when Settings could not forget a device. userInfo: @"name", @"events" (reason).
extern NSString *const BDBluetoothForgetFailedNotification;
// Posted when a helper-backed action (power, pairing) fails. userInfo: @"title", @"message".
extern NSString *const BDBluetoothHelperErrorNotification;

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

// Single owner of BluetoothManager + MPAVRoutingController for the app. Forget, discovery,
// pairing and power go through BluedeckHelper in Settings (bluetoothd ignores Bluedeck there).
@interface BDBluetooth : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) BOOL available;
@property (nonatomic, readonly) BOOL powered;
@property (nonatomic, readonly) NSString *localAddress;
@property (nonatomic, readonly) NSArray<BluetoothDevice *> *pairedDevices; // connected first, then by name
// Found by Settings during the scan: @{address, name, major, minor, paired}; new devices first.
@property (nonatomic, readonly) NSArray<NSDictionary *> *discoveredDevices;
@property (nonatomic, readonly) BOOL scanning;
@property (nonatomic, readonly) NSInteger discoveryHits;
@property (nonatomic, readonly, copy) NSString *scanError;      // why Settings could not scan, or nil
@property (nonatomic, readonly, copy) NSString *pairingAddress; // device being paired right now
@property (nonatomic, readonly) NSArray<NSString *> *recentEventLines; // newest first, for on-screen debugging
@property (nonatomic, readonly) NSArray<MPAVRoute *> *routes;

- (void)setPowered:(BOOL)powered;
- (BOOL)isConnecting:(BluetoothDevice *)device;
- (void)connect:(BluetoothDevice *)device;
- (void)connectAddress:(NSString *)address;
- (void)disconnect:(BluetoothDevice *)device;
- (void)forget:(BluetoothDevice *)device;
- (BOOL)isForgetting:(BluetoothDevice *)device;

- (void)startScan;
- (void)stopScan;
- (void)pairAddress:(NSString *)address;
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
