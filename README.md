# Bluedeck

Trình quản lý Bluetooth cho iOS 15 (rootless, arm64) — thay cho trang Bluetooth mặc định.

**Trạng thái:** P1 — tab Thiết bị (kết nối/ngắt/quên, quét + ghép đôi, thông số), tab Âm thanh
(chuyển loa một chạm), tab Chẩn đoán (in ra mọi thứ các API riêng trả về trên máy thật).

## Build
Không cần Theos trên máy: mỗi lần push, GitHub Actions (Ubuntu + toolchain L1ghtmann + SDK iPhoneOS16.5)
build `.deb` rootless. Tải ở tab **Actions** (artifact) hoặc **Releases** (khi push tag `v*`).

## Kế hoạch
- **P0** Chẩn đoán API trên iOS 15. ✓
- **P1** Danh sách thiết bị (icon theo loại, pin), chi tiết thông số, kết nối/ngắt/quên, quét + ghép đôi, chuyển loa phát một chạm. ✓
- **P2** Thứ tự ưu tiên kết nối, chọn profile cho từng thiết bị, đo chất lượng sóng, điều khiển AirPods/Beats, thông tin BLE, giữ nhạc khi app khác phát video (bật/tắt, chọn app).
- **P3** Popup khi kết nối, cảnh báo pin yếu, lịch sử + biểu đồ, thay mục Bluetooth trong Settings.
