# Dự án Ví Điện Tử Flutter (tham khảo phong cách hiện đại, trẻ trung)

## 1) Cấu trúc thư mục dự án (thiết kế trước)

```text
wallet_app/
├─ README.md
├─ pubspec.yaml
├─ analysis_options.yaml
├─ assets/
│  ├─ images/
│  │  ├─ logos/
│  │  ├─ icons/
│  │  ├─ onboarding/
│  │  └─ placeholders/
│  ├─ lottie/
│  └─ fonts/
├─ docs/
│  ├─ wireframes/
│  │  ├─ customer/
│  │  ├─ merchant/
│  │  ├─ admin/
│  │  └─ shared/
│  ├─ flows/
│  │  ├─ auth_flow.md
│  │  ├─ customer_payment_flow.md
│  │  ├─ merchant_pos_flow.md
│  │  └─ approval_flow.md
│  └─ api_contracts/
│     ├─ auth_api.yaml
│     ├─ customer_api.yaml
│     ├─ merchant_api.yaml
│     └─ admin_api.yaml
├─ lib/
│  ├─ app/
│  │  ├─ app.dart
│  │  ├─ bootstrap.dart
│  │  ├─ router/
│  │  │  ├─ app_router.dart
│  │  │  ├─ route_names.dart
│  │  │  └─ guards/
│  │  │     ├─ auth_guard.dart
│  │  │     ├─ role_guard.dart
│  │  │     └─ merchant_approval_guard.dart
│  │  ├─ theme/
│  │  │  ├─ app_colors.dart
│  │  │  ├─ app_typography.dart
│  │  │  ├─ app_theme.dart
│  │  │  └─ app_spacing.dart
│  │  └─ config/
│  │     ├─ env.dart
│  │     ├─ flavor.dart
│  │     └─ constants.dart
│  ├─ core/
│  │  ├─ network/
│  │  │  ├─ api_client.dart
│  │  │  ├─ api_endpoints.dart
│  │  │  ├─ interceptors/
│  │  │  │  ├─ auth_interceptor.dart
│  │  │  │  ├─ logging_interceptor.dart
│  │  │  │  └─ retry_interceptor.dart
│  │  │  └─ exceptions/
│  │  │     ├─ api_exception.dart
│  │  │     └─ error_mapper.dart
│  │  ├─ storage/
│  │  │  ├─ secure_storage_service.dart
│  │  │  └─ local_cache_service.dart
│  │  ├─ utils/
│  │  │  ├─ currency_formatter.dart
│  │  │  ├─ date_formatter.dart
│  │  │  ├─ qr_utils.dart
│  │  │  ├─ validators.dart
│  │  │  └─ image_picker_utils.dart
│  │  ├─ widgets/
│  │  │  ├─ app_scaffold.dart
│  │  │  ├─ app_button.dart
│  │  │  ├─ app_text_field.dart
│  │  │  ├─ app_search_bar.dart
│  │  │  ├─ empty_state.dart
│  │  │  ├─ loading_state.dart
│  │  │  └─ error_state.dart
│  │  └─ models/
│  │     ├─ user_model.dart
│  │     ├─ wallet_model.dart
│  │     ├─ transaction_model.dart
│  │     ├─ store_model.dart
│  │     ├─ product_model.dart
│  │     ├─ order_model.dart
│  │     └─ payment_session_model.dart
│  ├─ features/
│  │  ├─ auth/
│  │  │  ├─ data/
│  │  │  │  ├─ datasources/auth_remote_datasource.dart
│  │  │  │  ├─ repositories/auth_repository_impl.dart
│  │  │  │  └─ models/
│  │  │  ├─ domain/
│  │  │  │  ├─ entities/
│  │  │  │  ├─ repositories/auth_repository.dart
│  │  │  │  └─ usecases/
│  │  │  └─ presentation/
│  │  │     ├─ controllers/auth_controller.dart
│  │  │     ├─ screens/
│  │  │     │  ├─ splash_screen.dart
│  │  │     │  ├─ onboarding_screen.dart
│  │  │     │  ├─ login_screen.dart
│  │  │     │  ├─ register_role_picker_screen.dart
│  │  │     │  ├─ register_customer_screen.dart
│  │  │     │  ├─ register_merchant_screen.dart
│  │  │     │  └─ otp_verify_screen.dart
│  │  │     └─ widgets/
│  │  ├─ customer_home/
│  │  │  ├─ data/ domain/ presentation/
│  │  │  └─ presentation/screens/
│  │  │     ├─ customer_home_screen.dart
│  │  │     ├─ search_screen.dart
│  │  │     ├─ transfer_screen.dart
│  │  │     ├─ receive_screen.dart
│  │  │     ├─ qr_scan_screen.dart
│  │  │     ├─ payment_confirmation_screen.dart
│  │  │     ├─ transaction_history_screen.dart
│  │  │     └─ profile_screen.dart
│  │  ├─ merchant/
│  │  │  ├─ data/ domain/ presentation/
│  │  │  └─ presentation/screens/
│  │  │     ├─ merchant_pending_approval_screen.dart
│  │  │     ├─ merchant_dashboard_screen.dart
│  │  │     ├─ merchant_store_info_screen.dart
│  │  │     ├─ merchant_products_screen.dart
│  │  │     ├─ merchant_add_product_screen.dart
│  │  │     ├─ merchant_create_order_screen.dart
│  │  │     ├─ merchant_order_summary_screen.dart
│  │  │     ├─ merchant_qr_checkout_screen.dart
│  │  │     └─ merchant_order_history_screen.dart
│  │  ├─ admin/
│  │  │  ├─ data/ domain/ presentation/
│  │  │  └─ presentation/screens/
│  │  │     ├─ admin_login_screen.dart
│  │  │     ├─ admin_dashboard_screen.dart
│  │  │     ├─ merchant_approval_list_screen.dart
│  │  │     ├─ merchant_approval_detail_screen.dart
│  │  │     └─ approval_result_screen.dart
│  │  ├─ notifications/
│  │  └─ settings/
│  ├─ l10n/
│  │  ├─ app_vi.arb
│  │  └─ app_en.arb
│  └─ main.dart
├─ test/
│  ├─ unit/
│  ├─ widget/
│  └─ integration/
└─ tooling/
   ├─ scripts/
   └─ ci/
```

---

## 2) Toàn bộ wireframe màn hình (để kiểm tra trước khi code)

## A. Shared/Auth (dùng chung)

### A1. Splash

- Logo app giữa màn hình
- Nền gradient sáng
- Tự điều hướng theo trạng thái đăng nhập

### A2. Onboarding (3 slides)

- Slide 1: Thanh toán nhanh
- Slide 2: Quét QR tiện lợi
- Slide 3: Quản lý chi tiêu
- Nút: Bỏ qua / Tiếp tục / Bắt đầu

### A3. Login

- Input số điện thoại
- Input mật khẩu/OTP
- Nút Đăng nhập
- Link Quên mật khẩu
- Link Đăng ký

### A4. Chọn vai trò đăng ký

- Card “Khách hàng”
- Card “Chủ cửa tiệm”
- CTA: Tiếp tục

### A5. Đăng ký Khách hàng

- Họ tên
- Số điện thoại
- CCCD
- Checkbox điều khoản
- Nút Đăng ký

### A6. Đăng ký Chủ cửa tiệm

- Họ tên
- Địa chỉ
- SĐT
- CCCD
- Upload giấy phép kinh doanh
- Nút Gửi hồ sơ

### A7. OTP Verify

- 6 ô OTP
- Đếm ngược gửi lại mã
- Nút Xác nhận

---

## B. Customer App Wireframes

### B1. Customer Home

- Header cá nhân hóa (avatar + lời chào)
- Thanh tìm kiếm
- Quick actions: Chuyển tiền / Nhận tiền / Quét QR
- Card số dư ví
- Danh sách giao dịch gần đây
- Bottom nav: Home / Lịch sử / QR / Profile

### B2. Search

- Search bar sticky
- Kết quả: người nhận gần đây, cửa tiệm gần đây
- Empty state + gợi ý

### B3. Transfer

- Người nhận (số ĐT/ID/scan)
- Số tiền
- Nội dung
- Nút Tiếp tục

### B4. Receive

- QR cá nhân
- STK/ID ví
- Nút chia sẻ mã

### B5. QR Scan

- Camera khung scan
- Nút bật đèn flash
- Nút chọn ảnh QR từ thư viện

### B6. Payment Confirmation (sau quét QR cửa tiệm)

- Thông tin cửa tiệm
- Địa chỉ
- Ngày giờ
- Danh sách món + giá
- Tổng tiền
- Nút Chuyển tiền
- Nút Hủy

### B7. Transaction History

- Tabs: Tất cả / Nhận / Chuyển / Thanh toán
- Bộ lọc ngày
- Item giao dịch: trạng thái, số tiền, thời gian

### B8. Profile

- Avatar
- Họ tên, SĐT, CCCD (masked)
- Cài đặt bảo mật
- Đăng xuất

---

## C. Merchant App Wireframes

### C1. Pending Approval

- Banner trạng thái: Chờ duyệt
- Timeline: Hồ sơ đã gửi / Đang kiểm tra / Kết quả
- Nút cập nhật hồ sơ (nếu bị từ chối)

### C2. Merchant Dashboard

- KPIs: Doanh thu hôm nay, số đơn hôm nay
- Nút “Tạo đơn mới”
- Shortcut: Sản phẩm / Lịch sử đơn / Thông tin quán

### C3. Quản lý thông tin quán

- Tên quán
- Địa chỉ
- Số điện thoại liên hệ
- Ảnh đại diện quán

### C4. Quản lý sản phẩm

- Danh sách sản phẩm dạng card/list
- Search + filter trạng thái
- FAB: Thêm sản phẩm

### C5. Add/Edit Product

- Upload ảnh sản phẩm
- Tên sản phẩm
- Giá tiền
- Mô tả ngắn (optional)
- Nút Lưu

### C6. Tạo đơn tại quầy (POS)

- Danh sách sản phẩm + tăng/giảm số lượng
- Giỏ hàng tạm
- Tổng tiền realtime
- Nút Tiếp tục

### C7. Order Summary

- Danh sách món đã chọn
- Tổng tiền
- Chọn phương thức:
  - Tiền mặt
  - Chuyển khoản QR
- Nút Hoàn tất (tiền mặt) hoặc Xuất QR

### C8. Merchant QR Checkout

- QR thanh toán theo order/session
- Tổng tiền lớn, dễ nhìn
- Trạng thái thanh toán realtime (waiting/paid/expired)

### C9. Lịch sử đơn hàng

- Danh sách đơn
- Trạng thái: paid/cancelled/refunded
- Chi tiết đơn

---

## D. Admin Wireframes

### D1. Admin Login

- Tài khoản admin
- Mật khẩu/2FA

### D2. Admin Dashboard

- Số merchant chờ duyệt
- Số đã duyệt / từ chối hôm nay

### D3. Merchant Approval List

- Danh sách hồ sơ
- Filter: pending/approved/rejected
- Search theo SĐT/tên

### D4. Merchant Approval Detail

- Thông tin cá nhân
- CCCD
- Địa chỉ
- Giấy phép kinh doanh (preview ảnh)
- Nút Duyệt / Từ chối + lý do

### D5. Approval Result

- Thông báo kết quả xử lý hồ sơ
- Log thời gian + admin thực hiện

---

## 3) Luồng điều hướng chính (wireflow)

1. Auth -> chọn role
2. Customer: vào Home ngay
3. Merchant: vào Pending Approval đến khi approved
4. Merchant approved -> Dashboard -> POS -> QR Checkout
5. Customer scan QR -> Invoice -> Confirm Transfer
6. Cập nhật lịch sử giao dịch cho cả 2 phía

---

## 4) Thorough testing plan cho giai đoạn thiết kế

### Đã kiểm thử:

- Chưa có (vì vừa hoàn thành bản thiết kế tài liệu).

### Các mục sẽ kiểm tra kỹ (thorough):

1. Bao phủ đủ toàn bộ màn hình đã nêu (shared/customer/merchant/admin)
2. Đủ trạng thái UI: loading/empty/error/success
3. Đủ luồng nghiệp vụ chính + ngoại lệ:
   - Merchant chưa duyệt vẫn bị chặn
   - QR hết hạn
   - Giao dịch lỗi/số dư không đủ
4. Tính nhất quán điều hướng giữa các vai trò
5. Tính phù hợp mobile-first (thành phần lớn, dễ chạm, đọc rõ)

```
Kết luận hiện tại:
- Đã hoàn tất: thiết kế cấu trúc thư mục + toàn bộ wireframe.
- Sẵn sàng nhận phản hồi của bạn để chỉnh sửa trước khi chuyển sang bước chỉ dùng AWS.
```
