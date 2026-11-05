#import "BDCodeDump.h"
#import <dlfcn.h>
#import <mach/mach.h>
#import <objc/runtime.h>

static BOOL BDRead(uint64_t address, void *out, size_t size) {
	vm_size_t got = 0;
	return vm_read_overwrite(mach_task_self(), (vm_address_t)address, size, (vm_address_t)out, &got) == KERN_SUCCESS && got == size;
}

static NSString *BDSymbolAt(uint64_t address) {
	Dl_info info;
	if (!dladdr((const void *)address, &info)) return [NSString stringWithFormat:@"0x%llx", address];
	NSString *image = info.dli_fname ? @(info.dli_fname).lastPathComponent : @"?";
	if (info.dli_sname && info.dli_saddr) {
		uint64_t delta = address - (uint64_t)info.dli_saddr;
		return delta ? [NSString stringWithFormat:@"%s+0x%llx (%@)", info.dli_sname, delta, image]
			: [NSString stringWithFormat:@"%s (%@)", info.dli_sname, image];
	}
	return [NSString stringWithFormat:@"%@+0x%llx", image, address - (uint64_t)info.dli_fbase];
}

// Printable C string at address, or nil.
static NSString *BDCStringAt(uint64_t address) {
	char buffer[96] = {0};
	if (!BDRead(address, buffer, sizeof(buffer) - 1)) return nil;
	size_t n = 0;
	while (n < sizeof(buffer) - 1 && buffer[n] >= 0x20 && buffer[n] < 0x7f) n++;
	if (n < 3 || buffer[n] != 0) return nil;
	return [[NSString alloc] initWithBytes:buffer length:n encoding:NSASCIIStringEncoding];
}

static int64_t BDSignExtend(uint64_t value, int bits) {
	uint64_t mask = 1ull << (bits - 1);
	return (int64_t)((value ^ mask) - mask);
}

NSArray<NSString *> *BDDumpMethodCode(Class cls, SEL sel, BOOL classMethod, NSUInteger length) {
	NSMutableArray *lines = [NSMutableArray array];
	Method method = classMethod ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
	if (!method) {
		[lines addObject:@"(không có method)"];
		return lines;
	}
	uint64_t imp = (uint64_t)method_getImplementation(method);
	[lines addObject:[NSString stringWithFormat:@"imp %@", BDSymbolAt(imp)]];

	NSMutableData *code = [NSMutableData dataWithLength:length];
	if (!BDRead(imp, code.mutableBytes, length)) {
		[lines addObject:@"(không đọc được bộ nhớ)"];
		return lines;
	}
	const uint32_t *ins = code.bytes;
	NSUInteger count = length / 4;

	NSMutableString *hex = [NSMutableString string];
	for (NSUInteger i = 0; i < count; i++) {
		if (i % 8 == 0) [hex appendFormat:@"%s+%03lx:", i ? "\n" : "", (unsigned long)i * 4];
		[hex appendFormat:@" %08x", ins[i]];
	}
	[lines addObject:hex];

	uint64_t regs[32] = {0};
	BOOL known[32] = {NO};
	for (NSUInteger i = 0; i < count; i++) {
		uint32_t op = ins[i];
		uint64_t pc = imp + i * 4;
		NSString *note = nil;
		if ((op & 0x7c000000) == 0x14000000) { // b / bl
			uint64_t target = pc + BDSignExtend(op & 0x03ffffff, 26) * 4;
			note = [NSString stringWithFormat:@"%@ → %@", (op & 0x80000000) ? @"bl" : @"b", BDSymbolAt(target)];
		} else if ((op & 0x9f000000) == 0x90000000) { // adrp
			uint32_t rd = op & 0x1f;
			uint64_t imm = ((op >> 29) & 3) | (((op >> 5) & 0x7ffff) << 2);
			regs[rd] = (pc & ~0xfffull) + (BDSignExtend(imm, 21) << 12);
			known[rd] = YES;
		} else if ((op & 0xffc00000) == 0xf9400000) { // ldr x, [xn, #imm]
			uint32_t rn = (op >> 5) & 0x1f, rt = op & 0x1f;
			if (known[rn]) {
				uint64_t address = regs[rn] + ((op >> 10) & 0xfff) * 8;
				uint64_t value = 0;
				if (BDRead(address, &value, 8)) {
					value &= 0x0000000fffffffffull;
					NSString *str = BDCStringAt(value);
					note = [NSString stringWithFormat:@"ldr x%u ← [%@] = %@", rt, BDSymbolAt(address), str ? [NSString stringWithFormat:@"\"%@\"", str] : BDSymbolAt(value)];
				}
			}
			known[rt] = NO;
		} else if ((op & 0xff800000) == 0x91000000) { // add x, xn, #imm
			uint32_t rn = (op >> 5) & 0x1f, rd = op & 0x1f;
			if (known[rn]) {
				uint64_t imm = (op >> 10) & 0xfff;
				if (op & (1 << 22)) imm <<= 12;
				uint64_t address = regs[rn] + imm;
				NSString *str = BDCStringAt(address);
				note = [NSString stringWithFormat:@"add x%u = %@", rd, str ? [NSString stringWithFormat:@"\"%@\"", str] : BDSymbolAt(address)];
				regs[rd] = address;
				known[rd] = YES;
			}
		} else if (op == 0xd65f03c0) {
			note = @"ret";
		}
		if (note) [lines addObject:[NSString stringWithFormat:@"+%03lx %@", (unsigned long)i * 4, note]];
	}
	return lines;
}
