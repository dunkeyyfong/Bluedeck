#import "BDSettingsController.h"
#import "BDDiagController.h"
#import "BDHelperClient.h"
#import "BDMixAppsController.h"
#import "BDPrefsStore.h"

NSString *BDAppVersion(void) {
	return [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
}

typedef NS_ENUM(NSInteger, BDSettingsSection) {
	BDSettingsSectionMix,
	BDSettingsSectionAbout,
	BDSettingsSectionSystem,
	BDSettingsSectionAdvanced,
	BDSettingsSectionCount,
};

@interface BDSettingsController ()
@property (nonatomic, copy) NSString *helperState;
@property (nonatomic, strong) UISwitch *mixSwitch;
@end

@implementation BDSettingsController

- (instancetype)init {
	if ((self = [super initWithStyle:UITableViewStyleInsetGrouped])) {
		self.title = @"Cài đặt";
		self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
		_helperState = @"Đang kiểm tra…";
		_mixSwitch = [UISwitch new];
		[_mixSwitch addTarget:self action:@selector(mixToggled:) forControlEvents:UIControlEventValueChanged];
	}
	return self;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.tableView reloadData];
	[BDHelperClient.shared checkAlive:^(BOOL alive) {
		self.helperState = alive ? @"Đang hoạt động" : @"Nghỉ (tự mở khi cần)";
		[self.tableView reloadData];
	}];
}

- (void)mixToggled:(UISwitch *)toggle {
	BDPrefsStore.shared.mixEnabled = toggle.on;
	[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:BDSettingsSectionMix] withRowAnimation:UITableViewRowAnimationNone];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return BDSettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case BDSettingsSectionMix: return BDPrefsStore.shared.mixEnabled ? 2 : 1;
		case BDSettingsSectionAbout: return 2;
		default: return 1;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case BDSettingsSectionMix: return @"Âm thanh";
		case BDSettingsSectionAbout: return @"Bluedeck";
		case BDSettingsSectionSystem: return @"Hệ thống";
		case BDSettingsSectionAdvanced: return @"Nâng cao";
	}
	return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	switch (section) {
		case BDSettingsSectionMix:
			return @"Nhạc đang phát không bị dừng khi app đã chọn phát video hay âm thanh — hai nguồn phát cùng lúc. "
				@"Video trong Safari chưa được hỗ trợ.";
		case BDSettingsSectionAbout:
			return @"Quên, quét, ghép đôi và bật/tắt Bluetooth được thực hiện bởi BluedeckHelper chạy ngầm trong app Cài đặt.";
		case BDSettingsSectionAdvanced:
			return @"Thông tin API, quyền và mã máy để gỡ lỗi.";
	}
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"]
		?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"row"];
	UIListContentConfiguration *content = [UIListContentConfiguration valueCellConfiguration];
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.accessoryView = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleDefault;
	NSString *symbol = nil;
	UIColor *color = UIColor.systemBlueColor;
	switch (indexPath.section) {
		case BDSettingsSectionMix:
			if (indexPath.row == 0) {
				content.text = @"Giữ nhạc khi phát video";
				symbol = @"music.note.list";
				color = UIColor.systemPinkColor;
				self.mixSwitch.on = BDPrefsStore.shared.mixEnabled;
				cell.accessoryView = self.mixSwitch;
				cell.selectionStyle = UITableViewCellSelectionStyleNone;
			} else {
				content.text = @"Chọn app";
				NSUInteger count = BDPrefsStore.shared.mixApps.count;
				content.secondaryText = count ? [NSString stringWithFormat:@"%lu app", (unsigned long)count] : @"Chưa chọn";
				symbol = @"square.grid.2x2.fill";
				color = UIColor.systemPinkColor;
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			}
			break;
		case BDSettingsSectionAbout:
			if (indexPath.row == 0) {
				content.text = @"Phiên bản";
				content.secondaryText = BDAppVersion();
				symbol = @"info.circle.fill";
			} else {
				content.text = @"BluedeckHelper";
				content.secondaryText = self.helperState;
				symbol = @"gearshape.2.fill";
				color = UIColor.systemGrayColor;
			}
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			break;
		case BDSettingsSectionSystem:
			content.text = @"Mở Cài đặt › Bluetooth";
			symbol = @"arrow.up.forward.app.fill";
			break;
		case BDSettingsSectionAdvanced:
			content.text = @"Chẩn đoán";
			symbol = @"stethoscope";
			color = UIColor.systemOrangeColor;
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			break;
	}
	content.image = [UIImage systemImageNamed:symbol];
	content.imageProperties.tintColor = color;
	cell.contentConfiguration = content;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	switch (indexPath.section) {
		case BDSettingsSectionMix:
			if (indexPath.row == 1) [self.navigationController pushViewController:[BDMixAppsController new] animated:YES];
			break;
		case BDSettingsSectionSystem:
			BDOpenBluetoothSettings();
			break;
		case BDSettingsSectionAdvanced:
			[self.navigationController pushViewController:[BDDiagController new] animated:YES];
			break;
	}
}

@end
