# Bluedeck

Trình quản lý Bluetooth cho iOS 15 (rootless, arm64) — thay cho trang Bluetooth mặc định.

**Trạng thái:** 2 tab Thiết bị (kết nối/ngắt/quên, quét + ghép đôi, thông số) và Âm thanh (chuyển loa
một chạm). Quên / quét / ghép đôi / bật-tắt chạy qua **BluedeckHelper** — tweak nằm trong app Cài đặt,
vì bluetoothd chỉ cho Cài đặt làm những việc này. Chẩn đoán nằm ở ⚙︎ › Nâng cao.

## Cấu trúc
```
App/                       Bluedeck.app (Theos application)
  Sources/
    main.m, BDAppDelegate  khởi động, tab bar, cảnh báo ghép đôi/lỗi
    Bluetooth/             BDBluetooth (BluetoothManager + chuyển loa), BDHelperClient, BDPrivate.h
    UI/
      Components/          BDCards (thẻ, lưới, nút tròn), BDDeviceStyle (loại thiết bị, icon)
      Devices/             danh sách, chi tiết, quét + ghép đôi
      Audio/               chọn ngõ ra, thông số luồng âm thanh
      Settings/            trang ⚙︎
    Diagnostics/           trang Chẩn đoán + công cụ đọc API, quyền, mã máy
  Resources/               Info.plist, icon (tools/gen_icon.py vẽ lúc build)
  entitlements.plist
SettingsHelper/            BluedeckHelper.dylib — tweak tiêm vào Cài đặt (Preferences)
Shared/                    BDHelperProtocol.h — giao thức Darwin notify giữa app và tweak
tools/                     script phụ (vẽ icon)
.github/workflows/         build .deb trên GitHub Actions
```

## Build
Không cần Theos trên máy: mỗi lần push, GitHub Actions (Ubuntu + toolchain L1ghtmann + SDK iPhoneOS16.5)
build `.deb` rootless. Tải ở tab **Actions** (artifact) hoặc **Releases** (khi push tag `v*`).

## Kế hoạch
- **P0** Chẩn đoán API trên iOS 15. ✓
- **P1** Danh sách thiết bị, chi tiết thông số, kết nối/ngắt/quên, quét + ghép đôi, chuyển loa một chạm. ✓
- **P2** Thứ tự ưu tiên kết nối, chọn profile cho từng thiết bị, đo chất lượng sóng, điều khiển AirPods/Beats, thông tin BLE, giữ nhạc khi app khác phát video (bật/tắt, chọn app).
- **P3** Popup khi kết nối, cảnh báo pin yếu, lịch sử + biểu đồ, thay mục Bluetooth trong Settings.
