#import "BDAudioController.h"
#import "BDBluetooth.h"
#import "BDCards.h"
#import "BDDevicesController.h"
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, BDAudioSection) {
	BDAudioSectionRoutes,
	BDAudioSectionOffline,
	BDAudioSectionStream,
};

@interface BDAudioController ()
@property (nonatomic, copy) NSArray<NSNumber *> *sectionKinds;
@property (nonatomic, copy) NSArray<MPAVRoute *> *routes;
@property (nonatomic, copy) NSArray<BluetoothDevice *> *offline;
@end

@implementation BDAudioController

- (instancetype)init {
	__block __weak BDAudioController *weakSelf = nil;
	UICollectionViewLayout *layout = BDCardLayout(^BDSectionStyle(NSInteger section) {
		return [weakSelf kindAt:section] == BDAudioSectionStream ? BDSectionStyleFull : BDSectionStyleGrid;
	}, ^BOOL(NSInteger section) {
		return YES;
	});
	if ((self = [super initWithCollectionViewLayout:layout])) {
		weakSelf = self;
		self.title = @"Âm thanh";
		self.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Âm thanh" image:[UIImage systemImageNamed:@"hifispeaker.2"] tag:1];
		_sectionKinds = @[@(BDAudioSectionRoutes), @(BDAudioSectionStream)];
	}
	return self;
}

- (BDAudioSection)kindAt:(NSInteger)section {
	return section < (NSInteger)self.sectionKinds.count ? (BDAudioSection)self.sectionKinds[section].integerValue : BDAudioSectionRoutes;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.collectionView.backgroundColor = UIColor.systemGroupedBackgroundColor;
	self.collectionView.alwaysBounceVertical = YES;
	self.collectionView.contentInset = UIEdgeInsetsMake(8, 0, 24, 0);
	[self.collectionView registerClass:BDTileCell.class forCellWithReuseIdentifier:@"tile"];
	[self.collectionView registerClass:BDStatsCell.class forCellWithReuseIdentifier:@"stats"];
	[self.collectionView registerClass:BDActionCell.class forCellWithReuseIdentifier:@"empty"];
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
	self.routes = bt.routes;
	NSMutableArray *offline = [NSMutableArray array];
	for (BluetoothDevice *device in bt.pairedDevices) {
		if (BDDeviceSupports(device, BDServiceA2DP) && ![bt routeForDevice:device]) [offline addObject:device];
	}
	self.offline = offline;
	NSMutableArray *kinds = [NSMutableArray arrayWithObject:@(BDAudioSectionRoutes)];
	if (offline.count) [kinds addObject:@(BDAudioSectionOffline)];
	[kinds addObject:@(BDAudioSectionStream)];
	self.sectionKinds = kinds;
	[self.collectionView reloadData];
}

- (BluetoothDevice *)deviceForRoute:(MPAVRoute *)route {
	for (BluetoothDevice *device in BDBluetooth.shared.pairedDevices) {
		if ([BDBluetooth.shared routeForDevice:device] == route) return device;
	}
	return nil;
}

#pragma mark - Data source

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
	return self.sectionKinds.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
	switch ([self kindAt:section]) {
		case BDAudioSectionRoutes: return MAX(self.routes.count, (NSUInteger)1);
		case BDAudioSectionOffline: return self.offline.count;
		case BDAudioSectionStream: return 1;
	}
	return 0;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
	BDSectionHeaderView *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:indexPath];
	switch ([self kindAt:indexPath.section]) {
		case BDAudioSectionRoutes: header.label.text = @"Phát ra"; break;
		case BDAudioSectionOffline: header.label.text = @"Chưa kết nối"; break;
		case BDAudioSectionStream: header.label.text = @"Luồng âm thanh"; break;
	}
	return header;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
	BDBluetooth *bt = BDBluetooth.shared;
	switch ([self kindAt:indexPath.section]) {
		case BDAudioSectionRoutes: {
			if (!self.routes.count) {
				BDActionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"empty" forIndexPath:indexPath];
				[cell configureWithSymbol:@"hourglass" title:@"Đang lấy danh sách…" tint:UIColor.secondaryLabelColor];
				return cell;
			}
			MPAVRoute *route = self.routes[indexPath.item];
			BluetoothDevice *device = [self deviceForRoute:route];
			BDDeviceKind *kind = route.isDeviceSpeakerRoute
				? [BDDeviceKind kindWithName:@"iPhone" symbol:@"iphone" color:UIColor.systemGrayColor]
				: device ? [BDDeviceKind kindForDevice:device] : [BDDeviceKind kindWithName:@"Âm thanh" symbol:@"speaker.wave.2.fill" color:UIColor.systemOrangeColor];
			NSMutableArray *status = [NSMutableArray arrayWithObject:route.isPicked ? @"Đang phát" : @"Sẵn sàng"];
			NSInteger battery = device ? BDBatteryPercent(device) : -1;
			if (battery >= 0) [status addObject:[NSString stringWithFormat:@"%ld%%", (long)battery]];
			BDTileCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"tile" forIndexPath:indexPath];
			[cell configureWithKind:kind title:route.routeName ?: @"?" subtitle:[status componentsJoinedByString:@" · "]
				dotColor:route.isPicked ? UIColor.systemGreenColor : nil selected:route.isPicked busy:NO
				accessorySymbol:route.isPicked ? @"checkmark.circle.fill" : nil accessoryTint:UIColor.systemBlueColor];
			cell.onAccessory = nil;
			return cell;
		}
		case BDAudioSectionOffline: {
			BluetoothDevice *device = self.offline[indexPath.item];
			BOOL busy = [bt isWaitingToPlayOn:device] || [bt isConnecting:device];
			BDTileCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"tile" forIndexPath:indexPath];
			[cell configureWithKind:[BDDeviceKind kindForDevice:device] title:device.name ?: @"?" subtitle:busy ? @"Đang kết nối…" : @"Chạm để phát ra đây"
				dotColor:nil selected:NO busy:busy accessorySymbol:@"play.circle.fill" accessoryTint:UIColor.systemBlueColor];
			__weak BluetoothDevice *weakDevice = device;
			cell.onAccessory = ^{ if (weakDevice) [BDBluetooth.shared playOn:weakDevice]; };
			return cell;
		}
		case BDAudioSectionStream: {
			AVAudioSession *session = AVAudioSession.sharedInstance;
			NSUInteger channels = session.currentRoute.outputs.firstObject.channels.count ?: (NSUInteger)session.outputNumberOfChannels;
			BDStatsCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"stats" forIndexPath:indexPath];
			[cell configureWithStats:@[
				@[[NSString stringWithFormat:@"%.1f", session.sampleRate / 1000.0], @"kHz"],
				@[channels == 2 ? @"Stereo" : @(channels).stringValue, @"Kênh"],
				@[[NSString stringWithFormat:@"%.0f", session.outputLatency * 1000], @"ms trễ"],
			]];
			return cell;
		}
	}
	return [UICollectionViewCell new];
}

#pragma mark - Delegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
	switch ([self kindAt:indexPath.section]) {
		case BDAudioSectionRoutes:
			if (indexPath.item < (NSInteger)self.routes.count && !self.routes[indexPath.item].isPicked) {
				[BDBluetooth.shared pickRoute:self.routes[indexPath.item]];
			}
			break;
		case BDAudioSectionOffline:
			[BDBluetooth.shared playOn:self.offline[indexPath.item]];
			break;
		case BDAudioSectionStream:
			break;
	}
}

@end
