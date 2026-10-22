# BaKhi Điểm Danh

Ứng dụng Flutter điểm danh sinh viên bằng QR, GPS và nhận diện khuôn mặt. Ứng dụng kết nối API dùng chung; vai trò tài khoản (sinh viên, giảng viên, quản trị viên) quyết định các màn hình và thao tác được phép.

## Yêu cầu

- Flutter SDK có Dart tương thích với ràng buộc trong `pubspec.yaml`.
- Android Studio/Android SDK và thiết bị Android hoặc emulator.
- Quyền Internet; Camera cho quét QR/nhận diện khuôn mặt; Vị trí cho buổi điểm danh có giới hạn GPS.

## Cài đặt và chạy

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://42-96-2-9.sslip.io
```

Có thể mở thư mục này trong Android Studio và chạy cấu hình Flutter trên thiết bị Android. API mặc định là `https://42-96-2-9.sslip.io`; dùng `--dart-define=API_BASE_URL=...` để trỏ sang máy chủ khác.

## Tài liệu API

- Swagger UI: <https://42-96-2-9.sslip.io/swagger>
- API base URL: <https://42-96-2-9.sslip.io>

## Chức năng

### Sinh viên

- Đăng ký tài khoản và xác minh OTP; mã `devCode` được điền tự động khi API trả về.
- Đăng nhập bằng tài khoản/mật khẩu hoặc khuôn mặt. Nếu API trả token trực tiếp, ứng dụng vào thẳng màn hình theo vai trò; nếu API trả ticket thì chuyển sang bước OTP.
- Xem lớp, buổi học và trạng thái điểm danh.
- Quét QR để điểm danh, gửi vị trí GPS khi có quyền, và xác minh khuôn mặt nếu buổi học yêu cầu.
- Gửi đơn xin phép vắng kèm ảnh minh chứng.
- Cập nhật hồ sơ, đăng ký/thay đổi/xóa dữ liệu khuôn mặt.

### Giảng viên

- Xem lớp được phân công và tạo buổi học với tên, giờ bắt đầu/kết thúc, vị trí GPS, bán kính điểm danh và tùy chọn bắt buộc xác minh khuôn mặt.
- Tạo hoặc làm mới mã QR điểm danh.
- Theo dõi sinh viên có mặt, đi trễ, chưa điểm danh, vắng hoặc có phép; duyệt/từ chối đơn xin phép.

### Quản trị viên

- Tạo, sửa, xóa lớp; phân công giảng viên phụ trách.
- Quản lý tài khoản sinh viên và giảng viên.
- Xem danh sách sinh viên theo lớp, thêm sinh viên vào lớp hoặc gỡ khỏi lớp.

## Nhận diện khuôn mặt

Ứng dụng dùng ML Kit để phát hiện khuôn mặt và MobileFaceNet để tạo embedding 192 chiều ngay trên thiết bị. Ảnh khuôn mặt không được tải lên máy chủ; API nhận embedding theo hợp đồng của dịch vụ. Model và giấy phép Apache-2.0 nằm trong `assets/models/`.

## Bảo mật và dữ liệu

- JWT được lưu bằng `flutter_secure_storage`.
- Không đưa tài khoản demo, mật khẩu, token hay `android/local.properties` vào kho mã nguồn.
- Tài khoản giảng viên/quản trị do hệ thống API cấp hoặc quản trị viên tạo.

## Cấu trúc chính

```text
lib/main.dart                 Giao diện, điều hướng và tích hợp API
lib/face_recognition.dart     Quét/phát hiện khuôn mặt và tạo embedding
assets/models/                Model MobileFaceNet và giấy phép
android/                      Cấu hình ứng dụng Android
```

## Kiểm tra và build

```bash
flutter analyze
flutter build apk --debug
```

APK debug được tạo tại `build/app/outputs/flutter-apk/app-debug.apk`.
