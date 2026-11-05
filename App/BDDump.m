#import "BDDump.h"
#import <objc/runtime.h>

NSString *BDDescribe(id value) {
	if (!value) return @"nil";
	if ([value isKindOfClass:NSString.class]) return [NSString stringWithFormat:@"\"%@\"", value];
	if ([value isKindOfClass:NSData.class]) {
		NSData *data = value;
		NSMutableString *hex = [NSMutableString stringWithFormat:@"<%lu byte> ", (unsigned long)data.length];
		const uint8_t *bytes = data.bytes;
		for (NSUInteger i = 0; i < MIN(data.length, (NSUInteger)64); i++) [hex appendFormat:@"%02x", bytes[i]];
		return hex;
	}
	NSString *desc = [value description];
	return desc ?: [NSString stringWithFormat:@"<%@>", NSStringFromClass([value class])];
}

NSString *BDCallGetter(id obj, NSString *selectorName) {
	SEL sel = NSSelectorFromString(selectorName);
	if (!obj || ![obj respondsToSelector:sel]) return nil;
	NSMethodSignature *sig = [obj methodSignatureForSelector:sel];
	if (!sig) return @"(không có chữ ký)";
	if (sig.numberOfArguments != 2) return @"(cần tham số)";

	const char *type = sig.methodReturnType;
	while (*type && strchr("rnNoORV", *type)) type++;

	NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
	inv.target = obj;
	inv.selector = sel;
	@try {
		[inv invoke];
	} @catch (NSException *e) {
		return [NSString stringWithFormat:@"⚠︎ %@: %@", e.name, e.reason];
	}

#define BD_RET(T, FMT, ...) { T r = 0; [inv getReturnValue:&r]; return [NSString stringWithFormat:FMT, __VA_ARGS__]; }
	switch (*type) {
		case '@': { __unsafe_unretained id r = nil; [inv getReturnValue:&r]; return BDDescribe(r); }
		case 'B': { bool r = false; [inv getReturnValue:&r]; return r ? @"YES" : @"NO"; }
		case 'c': BD_RET(signed char, @"%d", (int)r)
		case 'C': BD_RET(unsigned char, @"%u (0x%x)", (unsigned)r, (unsigned)r)
		case 's': BD_RET(short, @"%d", (int)r)
		case 'S': BD_RET(unsigned short, @"%u (0x%x)", (unsigned)r, (unsigned)r)
		case 'i': BD_RET(int, @"%d", r)
		case 'I': BD_RET(unsigned int, @"%u (0x%x)", r, r)
		case 'l': BD_RET(long, @"%ld", r)
		case 'L': BD_RET(unsigned long, @"%lu (0x%lx)", r, r)
		case 'q': BD_RET(long long, @"%lld", r)
		case 'Q': BD_RET(unsigned long long, @"%llu (0x%llx)", r, r)
		case 'f': BD_RET(float, @"%g", r)
		case 'd': BD_RET(double, @"%g", r)
		case '^': { void *r = NULL; [inv getReturnValue:&r]; return [NSString stringWithFormat:@"ptr %p", r]; }
		case 'v': return @"(void)";
		default: return [NSString stringWithFormat:@"(kiểu %s)", type];
	}
#undef BD_RET
}

NSArray<NSArray<NSString *> *> *BDDumpProperties(id obj) {
	NSMutableArray *rows = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet setWithArray:@[@"hash", @"superclass", @"description", @"debugDescription"]];
	for (Class cls = [obj class]; cls && cls != NSObject.class; cls = class_getSuperclass(cls)) {
		unsigned int count = 0;
		objc_property_t *props = class_copyPropertyList(cls, &count);
		for (unsigned int i = 0; i < count; i++) {
			NSString *name = @(property_getName(props[i]));
			if ([seen containsObject:name]) continue;
			[seen addObject:name];
			NSString *getter = name;
			char *custom = property_copyAttributeValue(props[i], "G");
			if (custom) {
				getter = @(custom);
				free(custom);
			}
			NSString *value = BDCallGetter(obj, getter);
			if (value) [rows addObject:@[name, value]];
		}
		free(props);
	}
	return [rows sortedArrayUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
		return [a[0] compare:b[0]];
	}];
}

static void BDAppendMethods(Class cls, NSString *prefix, NSMutableArray *out) {
	unsigned int count = 0;
	Method *methods = class_copyMethodList(cls, &count);
	for (unsigned int i = 0; i < count; i++) {
		[out addObject:[prefix stringByAppendingString:NSStringFromSelector(method_getName(methods[i]))]];
	}
	free(methods);
}

NSArray<NSString *> *BDMethodList(Class cls) {
	if (!cls) return @[];
	NSMutableArray *out = [NSMutableArray array];
	BDAppendMethods(object_getClass(cls), @"+", out);
	BDAppendMethods(cls, @"-", out);
	return [out sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
		return [[a substringFromIndex:1] compare:[b substringFromIndex:1]];
	}];
}
