# Flutter frontend

Ứng dụng có hai chế độ:

- Không có `--dart-define`: chạy prototype/mock để phát triển UI và widget test.
- Có cấu hình AWS: mở đăng ký, xác nhận OTP và đăng nhập Amazon Cognito.

Xem hướng dẫn chạy và triển khai tại [README dự án](../README.md).

Phiên Cognito hiện chỉ lưu trong bộ nhớ. Trước khi phát hành production cần bổ sung secure storage và refresh token.
