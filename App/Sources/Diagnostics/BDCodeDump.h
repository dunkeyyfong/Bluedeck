#import <Foundation/Foundation.h>

// Dumps the first `length` bytes of a method's implementation as hex plus a light AArch64
// annotation (bl/b targets via dladdr, adrp+ldr/add resolved to the pointer or C string they
// load). Lets us read private framework code that lives only in the device's shared cache.
NSArray<NSString *> *BDDumpMethodCode(Class cls, SEL sel, BOOL classMethod, NSUInteger length);
