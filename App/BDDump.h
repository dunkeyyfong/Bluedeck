#import <Foundation/Foundation.h>

// Calls a zero-argument getter by name and formats whatever it returns.
// Returns nil when the object does not respond to the selector.
NSString *BDCallGetter(id obj, NSString *selectorName);

// Every declared property of obj's class chain (stopping at NSObject) as @[name, value] pairs.
NSArray<NSArray<NSString *> *> *BDDumpProperties(id obj);

// "-name" / "+name" for every method the class itself implements, sorted.
NSArray<NSString *> *BDMethodList(Class cls);

NSString *BDDescribe(id value);
