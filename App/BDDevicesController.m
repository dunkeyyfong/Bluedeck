#import "BDDevicesController.h"
#import "BDBluetooth.h"
#import "BDCards.h"
#import "BDDeviceDetailController.h"
#import "BDScanController.h"
#import "BDSettingsController.h"
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, BDListSection) {
	BDListSectionPower,
	BDListSectionHero,
	BDListSectionConnected,
	BDListSectionOther,
	BDListSectionAdd,
};

void BDPresentForget(UIViewController *host, id deviceObj, void (^done)(void)) {
	BluetoothDevice *device = deviceObj;
	UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Quên “%@”?", device.name]
		message:@"Thiết bị sẽ bị xoá khỏi danh sách ghép đôi. Muốn dùng lại phải ghép đôi từ đầu." preferredStyle:UIAlertControllerStyleActionSheet];
	[sheet addAction:[UIAlertAction actionWithTitle:@"Quên thiết bị" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
		[BDBluetooth.shared forget:device];
		if (done) done();
	}]];
	[sheet addAction:[UIAlertAction actionWithTitle:@"Huỷ" style:UIAlertActionStyleCancel handler:nil]];
	sheet.popoverPresentationController.sourceView = host.view;
	sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(host.view.bounds), CGRectGetMidY(host.view.bounds), 1, 1);
	[host presentViewController:sheet animated:YES completion:nil];
}

UIBarButtonItem *BDSettingsButton(UIViewController *host) {
	__weak UIViewController *weakHost = host;
	UIAction *open = [UIAction actionWithTitle:@"Cài đặt" image:nil identifier:nil handler:^(UIAction *action) {
		[weakHost.navigationController pushViewController:[BDSettingsController new] animated:YES];
	}];
	return [[UIBarButtonItem alloc] initWithTitle:nil image:[UIImage systemImageNamed:@"gearshape"] primaryAction:open menu:nil];
}

@interface BDDevicesController ()
@property (nonatomic, copy) NSArray<NSNumber *> *sectionKinds;
@property (nonatomic, strong) BluetoothDevice *hero;
@property (nonatomic, copy) NSArray<BluetoothDevice *> *connected;
@property (nonatomic, copy) NSArray<BluetoothDevice *> *others;
@end

@implementation BDDevicesController

- (instancetype)init {
	__block __weak BDDevicesController *weakSelf = nil;
	UICollectionViewLayout *layout = BDCardLayout(^BDSectionStyle(NSInteger section) {
		BDListSection kind = [weakSelf kindAt:section];
		return kind == BDListSectionConnected || kind == BDListSectionOther ? BDSectionStyleGrid : BDSectionStyleFull;
	}, ^BOOL(NSInteger section) {
		BDListSection kind = [weakSelf kindAt:section];
		return kind == BDListSectionConnected || kind == BDListSectionOther;
	});
	if ((self = [super initWithCollectionViewLayout:layout])) {
		weakSelf = self;
		self.title = @"Bluetooth";
		self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Thiết bị" image:[UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"] tag:0];
		_sectionKinds = @[@(BDListSectionPower)];
	}
	return self;
}

- (BDListSection)kindAt:(NSInteger)section {
	return section < (NSInteger)self.sectionKinds.count ? (BDListSection)self.sectionKinds[section].integerValue : BDListSectionPower;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.collectionView.backgroundColor = UIColor.systemGroupedBackgroundColor;
	self.collectionView.alwaysBounceVertical = YES;
	self.collectionView.contentInset = UIEdgeInsetsMake(8, 0, 24, 0);
	[self.collectionView registerClass:BDPowerCell.class forCellWithReuseIdentifier:@"power"];
	[self.collectionView registerClass:BDHeroCell.class forCellWithReuseIdentifier:@"hero"];
	[self.collectionView registerClass:BDTileCell.class forCellWithReuseIdentifier:@"tile"];
	[self.collectionView registerClass:BDActionCell.class forCellWithReuseIdentifier:@"action"];
	[self.collectionView registerClass:BDSectionHeaderView.class forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header"];
	self.navigationItem.rightBarButtonItem = BDSettingsButton(self);
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(reload) name:BDBluetoothDidChangeNotification object:nil];
	[self reload];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[BDBluetooth.shared refreshRoutes];
	[self reload];
}

- (void)reload {
	BDBluetooth *bt = BDBluetooth.shared;
	BluetoothDevice *hero = nil;
	NSMutableArray *connected = [NSMutableArray array], *others = [NSMutableArray array];
	for (BluetoothDevice *device in bt.pairedDevices) {
		if (device.connected && !hero && [bt isPlayingOn:device]) hero = device;
		else [(device.connected ? connected : others) addObject:device];
	}
	self.hero = hero;
	self.connected = connected;
	self.others = others;

	NSMutableArray *kinds = [NSMutableArray arrayWithObject:@(BDListSectionPower)];
	if (bt.available && bt.powered) {
		if (hero) [kinds addObject:@(BDListSectionHero)];
		if (connected.count) [kinds addObject:@(BDListSectionConnected)];
		if (others.count) [kinds addObject:@(BDListSectionOther)];
		[kinds addObject:@(BDListSectionAdd)];
	}
	self.sectionKinds = kinds;
	[self.collectionView reloadData];
}

- (NSArray<BluetoothDevice *> *)devicesIn:(BDListSection)kind {
	return kind == BDListSectionConnected ? self.connected : kind == BDListSectionOther ? self.others : @[];
}

- (BluetoothDevice *)deviceAt:(NSIndexPath *)indexPath {
	BDListSection kind = [self kindAt:indexPath.section];
	if (kind == BDListSectionHero) return self.hero;
	NSArray *devices = [self devicesIn:kind];
	return indexPath.item < (NSInteger)devices.count ? devices[indexPath.item] : nil;
}

#pragma mark - Data source

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
	return self.sectionKinds.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	BDListSection kind = [self kindAt:section];
	if (kind == BDListSectionConnected || kind == BDListSectionOther) return [self devicesIn:kind].count;
	return 1;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
	BDSectionHeaderView *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:indexPath];
	header.label.text = [self kindAt:indexPath.section] == BDListSectionConnected ? @"Đang kết nối" : @"Thiết bị của tôi";
	return header;
}

- (NSString *)statusFor:(BluetoothDevice *)device {
	BDBluetooth *bt = BDBluetooth.shared;
	NSMutableArray *parts = [NSMutableArray array];
	if ([bt isForgetting:device]) [parts addObject:@"Đang quên…"];
	else if ([bt isConnecting:device] || [bt isWaitingToPlayOn:device]) [parts addObject:@"Đang kết nối…"];
	else [parts addObject:device.connected ? @"Đã kết nối" : @"Chưa kết nối"];
	NSInteger battery = BDBatteryPercent(device);
	if (battery >= 0) [parts addObject:[NSString stringWithFormat:@"%ld%%", (long)battery]];
	return [parts componentsJoinedByString:@" · "];
}

- (NSString *)streamDetail:(BDDeviceKind *)kind {
	AVAudioSession *session = AVAudioSession.sharedInstance;
	NSUInteger channels = session.currentRoute.outputs.firstObject.channels.count;
	return [NSString stringWithFormat:@"%@ · %.1f kHz · %@", kind.name, session.sampleRate / 1000.0,
		channels == 2 ? @"Stereo" : channels == 1 ? @"Mono" : [NSString stringWithFormat:@"%lu kênh", (unsigned long)channels]];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	BDBluetooth *bt = BDBluetooth.shared;
	__weak typeof(self) weakSelf = self;
	switch ([self kindAt:indexPath.section]) {
		case BDListSectionPower: {
			BDPowerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"power" forIndexPath:indexPath];
			NSString *subtitle;
			if (!bt.available) subtitle = @"Đang kết nối tới dịch vụ Bluetooth…";
			else if (!bt.powered) subtitle = @"Đang tắt";
			else {
				NSUInteger count = self.connected.count + (self.hero ? 1 : 0);
				subtitle = count ? [NSString stringWithFormat:@"%lu thiết bị đang kết nối", (unsigned long)count] : @"Đang bật · chưa kết nối thiết bị nào";
			}
			[cell configureWithTitle:@"Bluetooth" subtitle:subtitle on:bt.powered enabled:bt.available];
			cell.onToggle = ^(BOOL on) { [BDBluetooth.shared setPowered:on]; };
			return cell;
		}
		case BDListSectionHero: {
			BDHeroCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"hero" forIndexPath:indexPath];
			BluetoothDevice *device = self.hero;
			BDDeviceKind *kind = [BDDeviceKind kindForDevice:device];
			[cell configureWithKind:kind overline:@"Đang phát" title:device.name detail:[self streamDetail:kind]
				primary:@"Chuyển loa" primarySymbol:@"hifispeaker.2.fill" secondary:@"Ngắt" secondarySymbol:@"xmark"];
			cell.onPrimary = ^{ weakSelf.tabBarController.selectedIndex = 1; };
			cell.onSecondary = ^{ if (weakSelf.hero) [BDBluetooth.shared disconnect:weakSelf.hero]; };
			return cell;
		}
		case BDListSectionConnected:
		case BDListSectionOther: {
			BDTileCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"tile" forIndexPath:indexPath];
			BluetoothDevice *device = [self deviceAt:indexPath];
			BOOL busy = [bt isForgetting:device] || [bt isConnecting:device] || [bt isWaitingToPlayOn:device];
			[cell configureWithKind:[BDDeviceKind kindForDevice:device] title:device.name ?: @"(không tên)" subtitle:[self statusFor:device]
				dotColor:device.connected ? UIColor.systemGreenColor : nil selected:NO busy:busy
				accessorySymbol:device.connected ? @"xmark.circle.fill" : @"link.circle.fill"
				accessoryTint:device.connected ? UIColor.tertiaryLabelColor : UIColor.systemBlueColor];
			__weak BluetoothDevice *weakDevice = device;
			cell.onAccessory = ^{
				BluetoothDevice *d = weakDevice;
				if (!d) return;
				if (d.connected) [BDBluetooth.shared disconnect:d];
				else [BDBluetooth.shared connect:d];
			};
			return cell;
		}
		case BDListSectionAdd: {
			BDActionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"action" forIndexPath:indexPath];
			[cell configureWithSymbol:@"plus.circle.fill" title:@"Thêm thiết bị mới" tint:self.view.tintColor];
			return cell;
		}
	}
	return [UICollectionViewCell new];
}

#pragma mark - Delegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
	BDListSection kind = [self kindAt:indexPath.section];
	if (kind == BDListSectionAdd) {
		[self.navigationController pushViewController:[BDScanController new] animated:YES];
		return;
	}
	BluetoothDevice *device = [self deviceAt:indexPath];
	if (device) [self.navigationController pushViewController:[[BDDeviceDetailController alloc] initWithAddress:device.address] animated:YES];
}

- (UIContextMenuConfiguration *)collectionView:(UICollectionView *)collectionView contextMenuConfigurationForItemAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
	BluetoothDevice *device = [self deviceAt:indexPath];
	if (!device) return nil;
	__weak typeof(self) weakSelf = self;
	return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray *suggested) {
		NSMutableArray *actions = [NSMutableArray array];
		if (device.connected) {
			[actions addObject:[UIAction actionWithTitle:@"Ngắt kết nối" image:[UIImage systemImageNamed:@"xmark.circle"] identifier:nil handler:^(UIAction *a) {
				[BDBluetooth.shared disconnect:device];
			}]];
		} else {
			[actions addObject:[UIAction actionWithTitle:@"Kết nối" image:[UIImage systemImageNamed:@"link"] identifier:nil handler:^(UIAction *a) {
				[BDBluetooth.shared connect:device];
			}]];
		}
		if (BDDeviceSupports(device, BDServiceA2DP) && ![BDBluetooth.shared isPlayingOn:device]) {
			[actions addObject:[UIAction actionWithTitle:@"Phát âm thanh ra đây" image:[UIImage systemImageNamed:@"hifispeaker.2"] identifier:nil handler:^(UIAction *a) {
				[BDBluetooth.shared playOn:device];
			}]];
		}
		UIAction *forget = [UIAction actionWithTitle:@"Quên thiết bị" image:[UIImage systemImageNamed:@"trash"] identifier:nil handler:^(UIAction *a) {
			BDPresentForget(weakSelf, device, nil);
		}];
		forget.attributes = UIMenuElementAttributesDestructive;
		[actions addObject:[UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[forget]]];
		return [UIMenu menuWithTitle:device.name ?: @"" children:actions];
	}];
}

@end
