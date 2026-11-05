#import "BDEntitlements.h"
#import <UIKit/UIKit.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>

static uint32_t BDBE32(const uint8_t *p) {
	return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3];
}

static NSDictionary *BDEntitlementsInSlice(NSData *data, NSUInteger sliceOffset, NSUInteger sliceSize, NSString **error) {
	const uint8_t *base = data.bytes;
	if (sliceOffset + sizeof(struct mach_header_64) > data.length) return nil;
	const struct mach_header_64 *mh = (const void *)(base + sliceOffset);
	if (mh->magic != MH_MAGIC_64) {
		if (error) *error = @"không phải Mach-O 64-bit";
		return nil;
	}
	const uint8_t *cmd = (const uint8_t *)(mh + 1);
	const uint8_t *end = base + MIN(sliceOffset + sliceSize, data.length);
	for (uint32_t i = 0; i < mh->ncmds && cmd + sizeof(struct load_command) <= end; i++) {
		const struct load_command *lc = (const void *)cmd;
		if (lc->cmd == LC_CODE_SIGNATURE) {
			const struct linkedit_data_command *sig = (const void *)lc;
			const uint8_t *blob = base + sliceOffset + sig->dataoff;
			if (blob + 12 > end || BDBE32(blob) != 0xfade0cc0) break;
			uint32_t count = BDBE32(blob + 8);
			for (uint32_t j = 0; j < count && blob + 12 + j * 8 + 8 <= end; j++) {
				uint32_t type = BDBE32(blob + 12 + j * 8);
				uint32_t offset = BDBE32(blob + 12 + j * 8 + 4);
				const uint8_t *entry = blob + offset;
				if (type != 5 || entry + 8 > end || BDBE32(entry) != 0xfade7171) continue;
				uint32_t length = BDBE32(entry + 4);
				if (length < 8 || entry + length > end) break;
				NSData *xml = [NSData dataWithBytes:entry + 8 length:length - 8];
				id plist = [NSPropertyListSerialization propertyListWithData:xml options:0 format:NULL error:nil];
				if ([plist isKindOfClass:NSDictionary.class]) return plist;
			}
			if (error) *error = @"chữ ký không có blob entitlements";
			return @{};
		}
		cmd += lc->cmdsize;
	}
	if (error) *error = @"không có LC_CODE_SIGNATURE";
	return nil;
}

NSDictionary *BDEntitlementsOfBinary(NSString *path, NSString **error) {
	NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
	if (data.length < 8) {
		if (error) *error = @"không đọc được file";
		return nil;
	}
	const uint8_t *bytes = data.bytes;
	if (BDBE32(bytes) == FAT_MAGIC) {
		uint32_t n = BDBE32(bytes + 4);
		NSDictionary *fallback = nil;
		for (uint32_t i = 0; i < n && 8 + (i + 1) * 20 <= data.length; i++) {
			const uint8_t *arch = bytes + 8 + i * 20;
			uint32_t cputype = BDBE32(arch), subtype = BDBE32(arch + 4) & 0x00ffffff;
			NSDictionary *result = BDEntitlementsInSlice(data, BDBE32(arch + 8), BDBE32(arch + 12), error);
			if (cputype == CPU_TYPE_ARM64 && subtype == CPU_SUBTYPE_ARM64_ALL && result) return result;
			if (result && !fallback) fallback = result;
		}
		return fallback;
	}
	return BDEntitlementsInSlice(data, 0, data.length, error);
}

NSArray<NSString *> *BDEntitlementLikeStrings(NSString *path, NSString **error) {
	NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
	if (!data.length) {
		if (error) *error = @"không đọc được file";
		return nil;
	}
	NSMutableSet *found = [NSMutableSet set];
	const char *bytes = data.bytes;
	NSUInteger length = data.length;
	static const char prefix[] = "com.apple.";
	for (NSUInteger i = 0; i + sizeof(prefix) < length; i++) {
		if (bytes[i] != 'c' || memcmp(bytes + i, prefix, sizeof(prefix) - 1) != 0) continue;
		if (i > 0 && bytes[i - 1] != 0) continue; // only whole C strings
		NSUInteger j = i;
		while (j < length && j - i < 160 && bytes[j] > 0x20 && bytes[j] < 0x7f) j++;
		if (j >= length || bytes[j] != 0) continue;
		NSString *s = [[NSString alloc] initWithBytes:bytes + i length:j - i encoding:NSASCIIStringEncoding];
		NSString *lower = s.lowercaseString;
		if ([lower containsString:@"bluetooth"] || [lower containsString:@".bt"] || [lower containsString:@"pairing"]
				|| [lower containsString:@"private"]) {
			[found addObject:s];
		}
		i = j;
	}
	return [found.allObjects sortedArrayUsingSelector:@selector(compare:)];
}

void BDOpenBluetoothSettings(void) {
	NSURL *url = [NSURL URLWithString:@"prefs:root=Bluetooth"];
	Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
	SEL shared = NSSelectorFromString(@"defaultWorkspace");
	id workspace = [workspaceClass respondsToSelector:shared] ? ((id (*)(Class, SEL))[workspaceClass methodForSelector:shared])(workspaceClass, shared) : nil;
	SEL open = NSSelectorFromString(@"openSensitiveURL:withOptions:");
	if ([workspace respondsToSelector:open]) {
		((BOOL (*)(id, SEL, NSURL *, NSDictionary *))[workspace methodForSelector:open])(workspace, open, url, nil);
		return;
	}
	[UIApplication.sharedApplication openURL:[NSURL URLWithString:@"App-prefs:Bluetooth"] options:@{} completionHandler:nil];
}
