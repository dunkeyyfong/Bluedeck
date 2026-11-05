#import <UIKit/UIKit.h>

@class BDSection;

@interface BDRow : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy) NSArray<BDSection *> *detail; // tap pushes these
@property (nonatomic, copy) void (^action)(void);         // tap runs this
+ (instancetype)key:(NSString *)key value:(NSString *)value;
@end

@interface BDSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSMutableArray<BDRow *> *rows;
+ (instancetype)title:(NSString *)title;
- (BDRow *)add:(NSString *)key value:(NSString *)value;
@end

// Plain-text rendering used for the shareable report.
NSString *BDRenderSections(NSArray<BDSection *> *sections, NSString *indent);

// Grouped table that shows key/value rows; rows with detail push another instance.
@interface BDSectionsController : UITableViewController
@property (nonatomic, copy) NSArray<BDSection *> *sections;
@end
