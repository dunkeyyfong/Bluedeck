#import <Foundation/Foundation.h>

// Lists exported symbols of a loaded image (matched by path suffix) that start with prefix,
// by walking its export trie. Returns nil and sets *error when the image or trie is missing.
NSArray<NSString *> *BDExportedSymbols(NSString *imageSuffix, NSString *prefix, NSString **error);
