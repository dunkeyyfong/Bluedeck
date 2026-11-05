# Bluedeck

Trình quản lý Bluetooth cho **iOS 15, jailbreak rootless (Dopamine), arm64** — thay cho trang Bluetooth mặc định.

## Tính năng
- **Thiết bị** — công tắc Bluetooth, thẻ "Đang phát", lưới thiết bị đang kết nối / đã ghép đôi, kết nối – ngắt nhanh, nhấn giữ để mở menu.
- **Chi tiết** — loại thiết bị, địa chỉ, hãng / sản phẩm, pin (nếu thiết bị báo), profile hỗ trợ / đang dùng, thông số luồng âm thanh; Kết nối / Phát ra đây / Quên.
- **Âm thanh** — chuyển loa một chạm; loa chưa kết nối có "Phát ra đây".
- **Thêm thiết bị** — quét + ghép đôi.
- **Giữ nhạc khi phát video** — app đã chọn phát chung thay vì dừng nhạc.
- **Dùng cho** — Nhạc + gọi / Chỉ nghe nhạc / Chỉ cuộc gọi cho tai nghe có cả hai.
- **⚙︎ Cài đặt** — các tuỳ chọn trên, trạng thái thành phần chạy ngầm, Nâng cao › Chẩn đoán.

## Cài đặt
Tải `.deb` ở [Releases](../../releases), cài bằng Sileo / Zebra / Filza (cần ElleKit / mobilesubstrate). Máy sẽ respring.

## Cách hoạt động
Bluetooth của iOS (`bluetoothd`) chỉ cho app Cài đặt quên / quét / ghép đôi / bật-tắt, nên gói gồm ba phần:

| Thành phần | Chạy ở | Việc |
|---|---|---|
| **Bluedeck.app** | app riêng | giao diện, kết nối / ngắt, chuyển loa (BluetoothManager + MPAVRoutingController) |
| **BluedeckHelper** | app Cài đặt | quên, quét, ghép đôi, bật/tắt — Bluedeck mở Cài đặt ngầm khi cần |
| **BluedeckSystem** | SpringBoard + mọi app UIKit | giữ cờ "giữ nhạc" cho từng app, ép phát chung trong app đã chọn, giữ đúng profile khi thiết bị tự kết nối lại |

Bluedeck ⇄ các tweak nói chuyện qua Darwin notify (`Shared/BDHelperProtocol.h`, `Shared/BDPrefs.h`). Cài đặt lưu ở
`/var/mobile/Library/Preferences/com.pgong.bluedeck.plist`.

## Giới hạn
- iPhone chỉ có codec SBC / AAC và chỉ phát ra một thiết bị Bluetooth tại một thời điểm.
- Pin chỉ hiện với thiết bị tự báo pin cho iPhone.
- "Giữ nhạc" chưa hỗ trợ video trong Safari; app cần tắt hẳn rồi mở lại sau khi bật.

## Cấu trúc
```
App/                       Bluedeck.app (Theos application)
  Sources/
    main.m, BDAppDelegate  khởi động, tab bar, cảnh báo ghép đôi/lỗi
    Bluetooth/             BDBluetooth (BluetoothManager + chuyển loa + profile), BDHelperClient, BDPrivate.h
    Model/                 BDPrefsStore (cài đặt + công bố trạng thái cho tweak)
    UI/
      Components/          BDCards (thẻ, lưới, nút tròn), BDDeviceStyle (loại thiết bị, icon)
      Devices/             danh sách, chi tiết, quét + ghép đôi
      Audio/               chọn ngõ ra, thông số luồng âm thanh
      Settings/            trang ⚙︎, chọn app "giữ nhạc"
    Diagnostics/           trang Chẩn đoán + công cụ đọc API, quyền, mã máy
  Resources/               Info.plist, icon (tools/gen_icon.py vẽ lúc build)
  entitlements.plist
SettingsHelper/            BluedeckHelper.dylib — tweak trong Cài đặt (Preferences)
SystemHelper/              BluedeckSystem.dylib — tweak trong SpringBoard + app (giữ nhạc, profile)
Shared/                    giao thức + khoá cài đặt dùng chung
tools/                     script phụ (vẽ icon)
.github/workflows/         build .deb; tag v* → GitHub Release
```

## Build
Không cần Theos trên máy: mỗi lần push, GitHub Actions (Ubuntu + toolchain L1ghtmann + SDK iPhoneOS16.5)
build `.deb` rootless (artifact). Push tag `v*` để tạo Release kèm `.deb` và nội dung `RELEASE_NOTES.md`.
