#import "BDSectionsController.h"

@implementation BDRow
+ (instancetype)key:(NSString *)key value:(NSString *)value {
	BDRow *row = [self new];
	row.key = key;
	row.value = value;
	return row;
}
@end

@implementation BDSection
+ (instancetype)title:(NSString *)title {
	BDSection *section = [self new];
	section.title = title;
	section.rows = [NSMutableArray array];
	return section;
}

- (BDRow *)add:(NSString *)key value:(NSString *)value {
	BDRow *row = [BDRow key:key value:value];
	[self.rows addObject:row];
	return row;
}
@end

NSString *BDRenderSections(NSArray<BDSection *> *sections, NSString *indent) {
	NSMutableString *out = [NSMutableString string];
	for (BDSection *section in sections) {
		[out appendFormat:@"%@## %@\n", indent, section.title];
		for (BDRow *row in section.rows) {
			if (row.action && !row.value) continue;
			if (row.value.length) [out appendFormat:@"%@%@: %@\n", indent, row.key, row.value];
			else [out appendFormat:@"%@%@\n", indent, row.key];
			if (row.detail) [out appendString:BDRenderSections(row.detail, [indent stringByAppendingString:@"    "])];
		}
		[out appendString:@"\n"];
	}
	return out;
}

@implementation BDSectionsController

- (instancetype)init {
	return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.tableView.estimatedRowHeight = 52;
	self.tableView.rowHeight = UITableViewAutomaticDimension;
}

- (void)setSections:(NSArray<BDSection *> *)sections {
	_sections = [sections copy];
	if (self.isViewLoaded) [self.tableView reloadData];
}

- (BDRow *)rowAt:(NSIndexPath *)indexPath {
	return self.sections[indexPath.section].rows[indexPath.row];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.sections[section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return self.sections[section].title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"row"];
		cell.textLabel.numberOfLines = 0;
		cell.detailTextLabel.numberOfLines = 0;
		cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
		cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
	}
	BDRow *row = [self rowAt:indexPath];
	cell.textLabel.text = row.key;
	cell.textLabel.font = [UIFont systemFontOfSize:15 weight:row.action ? UIFontWeightSemibold : UIFontWeightRegular];
	cell.textLabel.textColor = row.action ? tableView.tintColor : UIColor.labelColor;
	NSString *value = row.value;
	if (value.length > 600) value = [[value substringToIndex:600] stringByAppendingString:@" …"];
	cell.detailTextLabel.text = value;
	cell.accessoryType = row.detail ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
	cell.selectionStyle = (row.detail || row.action) ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	BDRow *row = [self rowAt:indexPath];
	if (row.action) {
		row.action();
	} else if (row.detail) {
		BDSectionsController *next = [BDSectionsController new];
		next.title = row.key;
		next.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
		next.sections = row.detail;
		[self.navigationController pushViewController:next animated:YES];
	}
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
	BDRow *row = [self rowAt:indexPath];
	NSString *text = row.detail ? BDRenderSections(row.detail, @"") : [NSString stringWithFormat:@"%@: %@", row.key, row.value ?: @""];
	return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray *suggested) {
		UIAction *copy = [UIAction actionWithTitle:@"Sao chép" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(UIAction *action) {
			UIPasteboard.generalPasteboard.string = text;
		}];
		return [UIMenu menuWithTitle:@"" children:@[copy]];
	}];
}

@end
