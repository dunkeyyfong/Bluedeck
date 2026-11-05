// Bluedeck ⇄ BluedeckHelper (tweak inside Settings) protocol, over Darwin notifications.
//
// bluetoothd silently ignores unpair / discovery / pairing from Bluedeck even with Settings'
// entitlements, so those run inside Preferences, which is allowed to do them.
//
// Request state (64 bit): seq << 56 | op << 48 | MAC (48 bit). Result state: seq << 56 | op << 48 | status.
#import <Foundation/Foundation.h>

#define kBDHelperRequest "com.pgong.bluedeck.helper/request"
#define kBDHelperResult "com.pgong.bluedeck.helper/result"
#define kBDHelperPing "com.pgong.bluedeck.helper/ping"
#define kBDHelperPong "com.pgong.bluedeck.helper/pong"
#define kBDHelperDiscovered "com.pgong.bluedeck.helper/discovered"
#define kBDHelperDiscoveredPath @"/var/mobile/Library/Bluedeck/discovered.plist"

typedef NS_ENUM(uint8_t, BDHelperOp) {
	BDHelperOpForget = 1,
	BDHelperOpScanStart = 2,
	BDHelperOpScanStop = 3,
	BDHelperOpPair = 4,
	BDHelperOpPowerOn = 5,
	BDHelperOpPowerOff = 6,
};

typedef NS_ENUM(uint16_t, BDHelperStatus) {
	BDHelperStatusOK = 0,
	BDHelperStatusNotFound = 1,
	BDHelperStatusFailed = 2,
	BDHelperStatusUnavailable = 3, // BluetoothManager never became available in Settings
	BDHelperStatusNoHelper = 4,    // Settings did not answer (tweak not loaded?)
	BDHelperStatusTimeout = 5,
};

static inline uint64_t BDHelperMACValue(NSString *address) {
	uint64_t value = 0;
	for (NSString *part in [address componentsSeparatedByString:@":"]) {
		value = (value << 8) | (strtoul(part.UTF8String, NULL, 16) & 0xff);
	}
	return value & 0xffffffffffffull;
}

static inline NSString *BDHelperMACString(uint64_t value) {
	return [NSString stringWithFormat:@"%02llX:%02llX:%02llX:%02llX:%02llX:%02llX",
		(value >> 40) & 0xff, (value >> 32) & 0xff, (value >> 24) & 0xff, (value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff];
}
