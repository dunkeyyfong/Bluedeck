# Bluedeck

Trình quản lý Bluetooth cho iOS 15 (rootless, arm64) — thay cho trang Bluetooth mặc định.

**Trạng thái:** P0 — app Chẩn đoán, in ra mọi thứ các API riêng (BluetoothManager, BatteryCenter,
MPAVRoutingController, AVAudioSession, CoreBluetooth) trả về trên máy thật.

## Build
Không cần Theos trên máy: mỗi lần push, GitHub Actions (Ubuntu + toolchain L1ghtmann + SDK iPhoneOS16.5)
build `.deb` rootless. Tải ở tab **Actions** (artifact) hoặc **Releases** (khi push tag `v*`).

## Kế hoạch
- **P0** Chẩn đoán API trên iOS 15.
- **P1** Danh sách thiết bị (thẻ, ảnh, pin), chi tiết thông số, kết nối/ngắt/quên/đổi tên, quét + ghép đôi, chuyển loa phát một chạm.
- **P2** Điều khiển AirPods/Beats, thông tin BLE (pin, hãng, firmware, RSSI), thông tin luồng âm thanh, giữ nhạc khi app khác phát video (bật/tắt, chọn app).
- **P3** Popup khi kết nối, cảnh báo pin yếu, lịch sử + biểu đồ, ảnh thiết bị tự chọn, thay mục Bluetooth trong Settings.
