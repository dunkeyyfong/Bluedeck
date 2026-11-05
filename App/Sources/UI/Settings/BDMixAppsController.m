#import "BDMixAppsController.h"
#import "BDPrefsStore.h"
#import <notify.h>

// What the hooks in that app last reported (see kBDMixStatus* in BDPrefs.h).
static NSString *BDMixStatusText(NSString *bundleID) {
	int token = 0;
	uint64_t state = 0;
	if (notify_register_check(BDMixStatusStateName(bundleID).UTF8String, &token) != NOTIFY_STATUS_OK) return nil;
	notify_get_state(token, &state);
	notify_cancel(token);
	uint8_t flags = state & 0xff;
	if (!(flags & kBDMixStatusLoaded)) return @"Chưa chạy — tắt hẳn app rồi mở lại";
	NSDateFormatter *fmt = [NSDateFormatter new];
	fmt.dateFormat = @"HH:mm";
	NSString *when = [fmt stringFromDate:[NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)(state >> 8)]];
	if (flags & kBDMixStatusRejected) return [NSString stringWithFormat:@"⚠︎ iOS từ chối phát chung (%@)", when];
	if (flags & kBDMixStatusAccepted) return [NSString stringWithFormat:@"✓ Đang phát chung (%@)", when];
	return [NSString stringWithFormat:@"Đã nạp, app chưa phát âm thanh (%@)", when];
}

@interface UIImage (BDPrivateIcons)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier format:(int)format scale:(CGFloat)scale;
@end

@interface BDAppEntry : NSObject
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) BOOL system;
@end

@implementation BDAppEntry
@end

// Installed apps via LSApplicationWorkspace; hidden system apps and Bluedeck itself left out.
static NSArray<BDAppEntry *> *BDInstalledApps(void) {
	Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
	SEL sharedSel = NSSelectorFromString(@"defaultWorkspace");
	SEL allSel = NSSelectorFromString(@"allInstalledApplications");
	id workspace = [workspaceClass respondsToSelector:sharedSel] ? ((id (*)(Class, SEL))[workspaceClass methodForSelector:sharedSel])(workspaceClass, sharedSel) : nil;
	NSArray *proxies = [workspace respondsToSelector:allSel] ? ((id (*)(id, SEL))[workspace methodForSelector:allSel])(workspace, allSel) : @[];
	NSMutableArray *apps = [NSMutableArray array];
	for (id proxy in proxies) {
		NSString *bundleID = [proxy valueForKey:@"applicationIdentifier"];
		NSString *type = [proxy respondsToSelector:NSSelectorFromString(@"applicationType")] ? [proxy valueForKey:@"applicationType"] : nil;
		NSArray *tags = [proxy respondsToSelector:NSSelectorFromString(@"appTags")] ? [proxy valueForKey:@"appTags"] : nil;
		if (!bundleID || [tags containsObject:@"hidden"] || [bundleID hasPrefix:@"com.pgong."]) continue;
		if (![type isEqualToString:@"User"] && ![type isEqualToString:@"System"]) continue;
		BDAppEntry *entry = [BDAppEntry new];
		entry.bundleID = bundleID;
		NSString *name = [proxy respondsToSelector:NSSelectorFromString(@"localizedName")] ? [proxy valueForKey:@"localizedName"] : nil;
		entry.name = name.length ? name : bundleID;
		entry.system = [type isEqualToString:@"System"];
		[apps addObject:entry];
	}
	return [apps sortedArrayUsingComparator:^NSComparisonResult(BDAppEntry *a, BDAppEntry *b) {
		return [a.name localizedCaseInsensitiveCompare:b.name];
	}];
}

@interface BDMixAppsController () <UISearchResultsUpdating>
@property (nonatomic, copy) NSArray<BDAppEntry *> *allApps;
@property (nonatomic, copy) NSArray<NSArray<BDAppEntry *> *> *sections; // user apps, system apps
@property (nonatomic, strong) NSMutableSet<NSString *> *selected;
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *icons;
@end

@implementation BDMixAppsController

- (instancetype)init {
	if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
		self.title = @"Chọn app";
		self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
		_selected = [NSMutableSet setWithArray:BDPrefsStore.shared.mixApps];
		_icons = [NSCache new];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	UISearchController *search = [[UISearchController alloc] initWithSearchResultsController:nil];
	search.searchResultsUpdater = self;
	search.obscuresBackgroundDuringPresentation = NO;
	search.searchBar.placeholder = @"Tìm app";
	self.navigationItem.searchController = search;
	self.navigationItem.hidesSearchBarWhenScrolling = NO;
	[NSNotificationCenter.defaultCenter addObserver:self.tableView selector:@selector(reloadData) name:UIApplicationDidBecomeActiveNotification object:nil];
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSArray *apps = BDInstalledApps();
		dispatch_async(dispatch_get_main_queue(), ^{
			self.allApps = apps;
			[self filter:nil];
		});
	});
}

- (void)filter:(NSString *)query {
	NSMutableArray *user = [NSMutableArray array], *system = [NSMutableArray array];
	for (BDAppEntry *app in self.allApps) {
		if (query.length && ![app.name localizedCaseInsensitiveContainsString:query] && ![app.bundleID localizedCaseInsensitiveContainsString:query]) continue;
		[(app.system ? system : user) addObject:app];
	}
	self.sections = @[user, system];
	[self.tableView reloadData];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
	[self filter:searchController.searchBar.text];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.sections[section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (!self.sections[section].count) return nil;
	return section == 0 ? @"App đã cài" : @"App hệ thống";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section != 0) return nil;
	return @"Bật cho app hay phát video/âm thanh làm dừng nhạc (TikTok, Facebook, YouTube…). Đừng bật cho chính app nghe nhạc. "
		@"App đang mở cần tắt hẳn rồi mở lại để có hiệu lực.";
}

- (UIImage *)iconFor:(NSString *)bundleID {
	UIImage *icon = [self.icons objectForKey:bundleID];
	if (icon) return icon;
	if ([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
		icon = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:0 scale:UIScreen.mainScreen.scale];
	}
	if (icon) [self.icons setObject:icon forKey:bundleID];
	return icon;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"app"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"app"];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		UISwitch *toggle = [UISwitch new];
		[toggle addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
	}
	BDAppEntry *app = self.sections[indexPath.section][indexPath.row];
	UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
	content.text = app.name;
	BOOL picked = [self.selected containsObject:app.bundleID];
	content.secondaryText = picked ? (BDMixStatusText(app.bundleID) ?: app.bundleID) : app.bundleID;
	content.secondaryTextProperties.color = UIColor.secondaryLabelColor;
	content.image = [self iconFor:app.bundleID] ?: [UIImage systemImageNamed:@"app.fill"];
	content.imageProperties.maximumSize = CGSizeMake(32, 32);
	content.imageProperties.cornerRadius = 7;
	cell.contentConfiguration = content;
	UISwitch *toggle = (UISwitch *)cell.accessoryView;
	toggle.on = picked;
	toggle.accessibilityIdentifier = app.bundleID;
	return cell;
}

- (void)toggled:(UISwitch *)toggle {
	NSString *bundleID = toggle.accessibilityIdentifier;
	if (!bundleID) return;
	if (toggle.on) [self.selected addObject:bundleID];
	else [self.selected removeObject:bundleID];
	BDPrefsStore.shared.mixApps = [self.selected.allObjects sortedArrayUsingSelector:@selector(compare:)];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.tableView reloadData]; // refresh per-app status after coming back from another app
}

@end
