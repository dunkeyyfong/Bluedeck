#import "BDDeviceStyle.h"

static NSString *const kBDPhotoDir = @"/var/mobile/Library/Bluedeck/Photos";

static unsigned int BDMajor(BluetoothDevice *device) {
	unsigned int major = [device respondsToSelector:@selector(majorClass)] ? device.majorClass : 0;
	return major > 0x1f ? (major >> 8) & 0x1f : major;
}

static unsigned int BDMinor(BluetoothDevice *device) {
	unsigned int minor = [device respondsToSelector:@selector(minorClass)] ? device.minorClass : 0;
	return (minor >> 2) & 0x3f;
}

UIImage *BDSymbol(NSString *name, CGFloat pointSize, UIFontWeight weight) {
	UIImageSymbolWeight symbolWeight = weight >= UIFontWeightBold ? UIImageSymbolWeightBold
		: weight >= UIFontWeightSemibold ? UIImageSymbolWeightSemibold
		: weight >= UIFontWeightMedium ? UIImageSymbolWeightMedium : UIImageSymbolWeightRegular;
	UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:symbolWeight];
	return [UIImage systemImageNamed:name withConfiguration:config]
		?: [UIImage systemImageNamed:@"antenna.radiowaves.left.and.right" withConfiguration:config];
}

@implementation BDDeviceKind

+ (instancetype)name:(NSString *)name symbol:(NSString *)symbol color:(UIColor *)color {
	BDDeviceKind *kind = [self new];
	kind.name = name;
	kind.symbol = symbol;
	kind.color = color;
	return kind;
}

+ (instancetype)appleKindForDevice:(BluetoothDevice *)device {
	unsigned int pid = [device respondsToSelector:@selector(productId)] ? device.productId : 0;
	switch (pid) {
		case 0x200e: case 0x2014: case 0x2024: return [self name:@"AirPods Pro" symbol:@"airpodspro" color:UIColor.systemGrayColor];
		case 0x200a: case 0x201f: return [self name:@"AirPods Max" symbol:@"airpodsmax" color:UIColor.systemGrayColor];
		case 0x2002: case 0x200f: case 0x2013: case 0x2019: case 0x201b: return [self name:@"AirPods" symbol:@"airpods" color:UIColor.systemGrayColor];
		default: return nil;
	}
}

+ (instancetype)kindForDevice:(BluetoothDevice *)device {
	if ([device respondsToSelector:@selector(isAppleAudioDevice)] && device.isAppleAudioDevice) {
		BDDeviceKind *apple = [self appleKindForDevice:device];
		if (apple) return apple;
	}
	unsigned int major = BDMajor(device), minor = BDMinor(device);
	unsigned int rawMinor = [device respondsToSelector:@selector(minorClass)] ? device.minorClass : 0;
	switch (major) {
		case 1: return [self name:@"Máy tính" symbol:@"laptopcomputer" color:UIColor.systemBlueColor];
		case 2: return [self name:@"Điện thoại" symbol:@"iphone" color:UIColor.systemBlueColor];
		case 4:
			switch (minor) {
				case 1: return [self name:@"Tai nghe nhét tai" symbol:@"airpods" color:UIColor.systemTealColor];
				case 2: return [self name:@"Thiết bị rảnh tay" symbol:@"phone.connection" color:UIColor.systemTealColor];
				case 4: return [self name:@"Micro" symbol:@"mic.fill" color:UIColor.systemRedColor];
				case 5: return [self name:@"Loa" symbol:@"hifispeaker.fill" color:UIColor.systemOrangeColor];
				case 6: return [self name:@"Tai nghe chụp" symbol:@"headphones" color:UIColor.systemIndigoColor];
				case 7: return [self name:@"Máy nghe nhạc" symbol:@"music.note" color:UIColor.systemPinkColor];
				case 8: return [self name:@"Âm thanh xe hơi" symbol:@"car.fill" color:UIColor.systemGreenColor];
				case 10: return [self name:@"Dàn HiFi" symbol:@"hifispeaker.2.fill" color:UIColor.systemOrangeColor];
				case 14: case 15: return [self name:@"Màn hình / TV" symbol:@"tv.fill" color:UIColor.systemPurpleColor];
				default: return [self name:@"Thiết bị âm thanh" symbol:@"speaker.wave.2.fill" color:UIColor.systemOrangeColor];
			}
		case 5:
			if ((rawMinor & 0xc0) == 0x40) return [self name:@"Bàn phím" symbol:@"keyboard" color:UIColor.systemGrayColor];
			if ((rawMinor & 0xc0) == 0x80) return [self name:@"Chuột" symbol:@"computermouse.fill" color:UIColor.systemGrayColor];
			if ((rawMinor & 0x3c) == 0x08) return [self name:@"Tay cầm chơi game" symbol:@"gamecontroller.fill" color:UIColor.systemPurpleColor];
			return [self name:@"Thiết bị ngoại vi" symbol:@"keyboard" color:UIColor.systemGrayColor];
		case 6: return [self name:@"Máy in / camera" symbol:@"printer.fill" color:UIColor.systemGrayColor];
		case 7: return [self name:@"Thiết bị đeo" symbol:@"applewatch" color:UIColor.systemPinkColor];
		case 8: return [self name:@"Đồ chơi" symbol:@"gamecontroller.fill" color:UIColor.systemPurpleColor];
		case 9: return [self name:@"Thiết bị sức khoẻ" symbol:@"heart.fill" color:UIColor.systemRedColor];
		default: return [self name:@"Thiết bị Bluetooth" symbol:@"antenna.radiowaves.left.and.right" color:UIColor.systemBlueColor];
	}
}

@end

NSString *BDClassDescription(BluetoothDevice *device) {
	NSArray *majors = @[@"Khác", @"Máy tính", @"Điện thoại", @"Mạng", @"Âm thanh/Video", @"Ngoại vi", @"Hình ảnh",
		@"Thiết bị đeo", @"Đồ chơi", @"Sức khoẻ"];
	unsigned int major = BDMajor(device);
	NSString *majorName = major < majors.count ? majors[major] : @"Không rõ";
	unsigned int rawMajor = [device respondsToSelector:@selector(majorClass)] ? device.majorClass : 0;
	unsigned int rawMinor = [device respondsToSelector:@selector(minorClass)] ? device.minorClass : 0;
	return [NSString stringWithFormat:@"%@ · %@ (0x%04x)", majorName, [BDDeviceKind kindForDevice:device].name, rawMajor | rawMinor];
}

#pragma mark - Photos

static NSString *BDPhotoPath(NSString *address) {
	NSString *file = [[address stringByReplacingOccurrencesOfString:@":" withString:@""] stringByAppendingPathExtension:@"jpg"];
	return [kBDPhotoDir stringByAppendingPathComponent:file];
}

static NSCache *BDPhotoCache(void) {
	static NSCache *cache;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ cache = [NSCache new]; });
	return cache;
}

UIImage *BDDevicePhoto(NSString *address) {
	if (!address.length) return nil;
	UIImage *cached = [BDPhotoCache() objectForKey:address];
	if (cached) return cached;
	UIImage *image = [UIImage imageWithContentsOfFile:BDPhotoPath(address)];
	if (image) [BDPhotoCache() setObject:image forKey:address];
	return image;
}

BOOL BDSaveDevicePhoto(UIImage *image, NSString *address) {
	if (!image || !address.length) return NO;
	// Square-crop and shrink so cells stay cheap.
	CGFloat side = MIN(image.size.width, image.size.height);
	CGFloat target = MIN(side, 600);
	UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
	format.scale = 1;
	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(target, target) format:format];
	UIImage *square = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
		CGFloat scale = target / side;
		CGSize drawn = CGSizeMake(image.size.width * scale, image.size.height * scale);
		[image drawInRect:CGRectMake((target - drawn.width) / 2, (target - drawn.height) / 2, drawn.width, drawn.height)];
	}];
	[NSFileManager.defaultManager createDirectoryAtPath:kBDPhotoDir withIntermediateDirectories:YES attributes:nil error:nil];
	BOOL ok = [UIImageJPEGRepresentation(square, 0.85) writeToFile:BDPhotoPath(address) atomically:YES];
	if (ok) [BDPhotoCache() setObject:square forKey:address];
	return ok;
}

void BDRemoveDevicePhoto(NSString *address) {
	if (!address.length) return;
	[NSFileManager.defaultManager removeItemAtPath:BDPhotoPath(address) error:nil];
	[BDPhotoCache() removeObjectForKey:address];
}

#pragma mark - Icon view

@interface BDDeviceIconView ()
@property (nonatomic, strong) CAGradientLayer *gradient;
@property (nonatomic, strong) UIImageView *symbolView;
@property (nonatomic, strong) UIImageView *photoView;
@property (nonatomic, copy) NSString *symbolName;
@end

@implementation BDDeviceIconView

- (instancetype)initWithFrame:(CGRect)frame {
	if ((self = [super initWithFrame:frame])) {
		self.clipsToBounds = YES;
		_gradient = [CAGradientLayer layer];
		_gradient.startPoint = CGPointMake(0, 0);
		_gradient.endPoint = CGPointMake(1, 1);
		[self.layer addSublayer:_gradient];
		_symbolView = [UIImageView new];
		_symbolView.contentMode = UIViewContentModeCenter;
		_symbolView.tintColor = UIColor.whiteColor;
		[self addSubview:_symbolView];
		_photoView = [UIImageView new];
		_photoView.contentMode = UIViewContentModeScaleAspectFill;
		[self addSubview:_photoView];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	self.layer.cornerRadius = self.bounds.size.width / 2;
	self.gradient.frame = self.bounds;
	self.symbolView.frame = self.bounds;
	self.photoView.frame = self.bounds;
	[self updateSymbolSize];
}

- (void)updateSymbolSize {
	if (!self.symbolName) return;
	self.symbolView.image = [BDSymbol(self.symbolName, self.bounds.size.width * 0.42, UIFontWeightSemibold)
		imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)configureWithDevice:(BluetoothDevice *)device {
	BDDeviceKind *kind = [BDDeviceKind kindForDevice:device];
	UIColor *top = kind.color;
	CGFloat h = 0, s = 0, b = 0, a = 1;
	UIColor *bottom = top;
	if ([top getHue:&h saturation:&s brightness:&b alpha:&a]) {
		top = [UIColor colorWithHue:h saturation:s * 0.75 brightness:MIN(1, b * 1.12) alpha:a];
		bottom = [UIColor colorWithHue:h saturation:MIN(1, s * 1.1) brightness:b * 0.78 alpha:a];
	}
	self.gradient.colors = @[(id)top.CGColor, (id)bottom.CGColor];
	self.symbolName = kind.symbol;
	[self updateSymbolSize];
	UIImage *photo = BDDevicePhoto(device.address);
	self.photoView.image = photo;
	self.photoView.hidden = photo == nil;
}

@end
