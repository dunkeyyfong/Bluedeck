#import <Foundation/Foundation.h>

// Entitlements embedded in a Mach-O's code signature (thin or fat; arm64 slice preferred).
NSDictionary *BDEntitlementsOfBinary(NSString *path, NSString **error);

// "com.apple.…" strings in a binary that look like entitlement names the binary checks
// (contain bluetooth/BT/pairing), e.g. what bluetoothd asks its clients for.
NSArray<NSString *> *BDEntitlementLikeStrings(NSString *path, NSString **error);

// Opens Settings › Bluetooth (needs com.apple.springboard.opensensitiveurl).
void BDOpenBluetoothSettings(void);
