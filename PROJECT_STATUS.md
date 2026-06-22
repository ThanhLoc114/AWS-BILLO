# Trạng thái dự án AWS BILLO

> Cập nhật: 20/06/2026  
> Môi trường đang sử dụng: `dev`  
> Tài liệu này phản ánh trạng thái mã nguồn và tài nguyên AWS thật tại thời điểm cập nhật.

## 1. Tổng quan

AWS BILLO hiện là một ứng dụng ví điện tử/POS gồm:

- Frontend Flutter, đang chạy local bằng Chrome/thiết bị Flutter.
- Backend serverless đã triển khai thật trên AWS.
- Ba vai trò: `customer`, `merchant`, `admin`.
- Đăng nhập bằng số điện thoại qua Amazon Cognito.
- Ví, chuyển tiền, thanh toán QR, lịch sử giao dịch và hoàn tiền dùng DynamoDB.
- Đăng ký kinh doanh, admin duyệt hồ sơ và quản lý cửa hàng/dịch vụ.

Các luồng nghiệp vụ chính đã hoạt động. Dự án vẫn là bản `dev/demo`, chưa đủ điều kiện phát hành production.

## 2. Môi trường AWS hiện tại

| Thành phần | Giá trị |
|---|---|
| AWS Account ID | `930458520721` |
| Region | Singapore - `ap-southeast-1` |
| CloudFormation stack | `wallet-app-backend-dev` |
| Trạng thái stack | `UPDATE_COMPLETE` |
| API Gateway | `https://zsqkp5vpb9.execute-api.ap-southeast-1.amazonaws.com/dev` |
| Cognito User Pool | `ap-southeast-1_AKc39KB4L` |
| Cognito App Client | `1cj39vsl5tuoa7g7pk304hakm4` |
| DynamoDB chính | `wallet-app-main-dev` |
| DynamoDB idempotency | `wallet-app-idempotency-dev` |
| S3 upload | `wallet-app-backend-dev-uploadbucket-tex0xqxlssus` |
| SMS account tier | `SANDBOX` |
| Số SMS sandbox đã xác minh | 1/10 |

Stack hiện có 11 Lambda functions:

1. `AuthProfileFunction`
2. `PostConfirmationFunction`
3. `MerchantApplicationFunction`
4. `UploadPresignFunction`
5. `AdminApprovalFunction`
6. `MerchantStoreProductFunction`
7. `MerchantOrderFunction`
8. `PaymentSessionFunction`
9. `WalletTransferFunction`
10. `TransactionHistoryFunction`
11. `DirectorySearchFunction`

### Hạ tầng AWS đã cấu hình

- Cognito User Pool và các group `customer`, `merchant`, `admin`.
- Cognito Post Confirmation trigger tự tạo profile và ví cho user mới.
- API Gateway HTTP API dùng JWT authorizer của Cognito.
- Lambda Node.js 22.x.
- DynamoDB chế độ `PAY_PER_REQUEST`.
- DynamoDB GSI cho hồ sơ merchant, danh bạ số điện thoại, cửa hàng và đơn hàng.
- DynamoDB Point-in-Time Recovery.
- Bảng idempotency có TTL.
- S3 mã hóa AES-256, versioning và CORS.
- S3 pre-signed URL để upload/download ảnh.
- IAM policy theo nhóm chức năng cho DynamoDB, S3 và Cognito.
- CloudWatch Logs mặc định cho Lambda.
- AWS SAM/CloudFormation để build và deploy.

## 3. Các chức năng đã hoàn thành

### 3.1. Authentication và phân quyền

- Đăng ký bằng số điện thoại và mật khẩu qua Cognito.
- Gửi và xác nhận OTP đăng ký.
- Gửi lại OTP.
- Đăng nhập bằng số điện thoại/mật khẩu.
- Chuẩn hóa số Việt Nam:
  - `0853555443` -> `+84853555443`.
  - Chấp nhận số quốc tế khi nhập đầy đủ dấu `+`.
- Đọc Cognito group từ ID token và điều hướng theo vai trò.
- Customer mới được tạo profile và ví tự động.
- Admin duyệt hồ sơ sẽ thêm user vào group merchant.
- Có đổi mật khẩu bằng Cognito `ChangePassword` trong Profile customer.
- Có đăng xuất và xóa session trong bộ nhớ.

### 3.2. Customer

#### Home

- Hiển thị tên người dùng và số dư ví thật từ AWS.
- Quick actions: chuyển tiền, nhận tiền, quét QR.
- Hiển thị ba giao dịch gần nhất từ DynamoDB.
- Thanh tìm kiếm mở màn hình danh bạ thật.

#### Tìm kiếm

- Hiển thị người nhận gần đây dựa trên lịch sử giao dịch.
- Tìm chính xác người nhận theo số điện thoại hoặc user ID.
- Hỗ trợ nhập số Việt Nam dạng `085...`.
- Tìm cửa hàng đã được duyệt theo tiền tố tên.
- Chạm người nhận để mở form chuyển tiền đã điền sẵn user ID.

#### Chuyển và nhận tiền

- Chuyển tiền giữa hai ví bằng DynamoDB transaction.
- Kiểm tra số dư bằng condition expression.
- Idempotency key chống gửi lặp giao dịch.
- Nhập người nhận bằng số điện thoại, user ID hoặc QR.
- Xác minh người nhận và hiển thị tên/số điện thoại đã che trước khi chuyển.
- Không cho chuyển cho chính mình.
- QR nhận tiền cá nhân chứa user ID.
- Sao chép mã ví và chia sẻ payload nhận tiền qua clipboard.
- Quét QR người nhận bằng camera.

#### Thanh toán QR tại cửa hàng

- Quét QR trực tiếp bằng camera.
- Bật/tắt flash và đổi camera.
- Chọn ảnh QR từ máy/thư viện.
- Nhập session ID thủ công làm phương án dự phòng.
- Bộ đọc QR hỗ trợ PNG/JPG/WebP, nền trong suốt và QR thiếu quiet zone.
- Hiển thị hóa đơn trước khi thanh toán:
  - Tên cửa hàng.
  - Địa chỉ.
  - Thời gian.
  - Danh sách dịch vụ, số lượng và đơn giá.
  - Tổng tiền và trạng thái.
- Nút chuyển tiền và hủy.
- Thanh toán nguyên tử: trừ customer, cộng merchant, cập nhật order/session và ghi lịch sử.
- Chặn thanh toán khi thiếu số dư, session hết hạn hoặc trạng thái đã đổi.

#### Lịch sử giao dịch

- Danh sách giao dịch thật từ DynamoDB.
- Bộ lọc: tất cả, nhận, chuyển, thanh toán.
- Lọc theo khoảng ngày.
- Pull-to-refresh.
- Hiển thị tiền vào/ra, thời gian, nội dung và mã đơn.
- Bấm giao dịch để xem chi tiết.
- Chi tiết giao dịch có trạng thái, mã giao dịch và nội dung.
- Giao dịch cửa hàng có bill đầy đủ: quán, địa chỉ, món, số lượng, giá, tổng tiền và mã đơn.
- Lịch sử nhận hoàn tiền được ghi cho customer.

#### Profile

- Hiển thị họ tên, số điện thoại, CCCD đã che và địa chỉ.
- Chỉnh sửa họ tên, địa chỉ và CCCD đã che.
- Đổi mật khẩu Cognito.
- Truy cập đăng ký kinh doanh.
- Đăng xuất.

### 3.3. Merchant

#### Đăng ký và phê duyệt kinh doanh

- Customer gửi hồ sơ đăng ký kinh doanh.
- Các trường: chủ kinh doanh, tên doanh nghiệp, điện thoại, CCCD, địa chỉ.
- Upload ảnh giấy phép kinh doanh lên S3.
- Hiển thị trạng thái `NOT_SUBMITTED`, `PENDING`, `APPROVED`, `REJECTED`.
- Ngăn gửi trùng hồ sơ khi đang pending hoặc đã approved.
- Khi admin duyệt:
  - Chuyển hồ sơ sang `APPROVED`.
  - Thêm Cognito group merchant.
  - Cập nhật profile role.
  - Tạo cửa hàng và thêm vào directory.

#### Tổng quan kinh doanh

- Hiển thị thông tin cửa hàng thật.
- Doanh thu hôm nay.
- Số đơn đã thanh toán hôm nay.
- Số đơn đang chờ.
- Pull-to-refresh và nút refresh.

#### Quản lý cửa hàng

- Chỉnh sửa tên quán, địa chỉ và số điện thoại.
- Upload/thay ảnh đại diện quán lên S3.
- Ảnh được trả về bằng signed URL.
- Cập nhật lại chỉ mục tìm kiếm cửa hàng.

#### Quản lý dịch vụ/sản phẩm

- Danh sách dịch vụ thật từ DynamoDB.
- Thêm dịch vụ: tên, giá, mô tả và ảnh.
- Chỉnh sửa dịch vụ và giữ ảnh cũ nếu không upload ảnh mới.
- Xóa dịch vụ.
- Hiển thị ảnh từ S3 signed URL.
- Backend kiểm tra sản phẩm tồn tại và đang active trước khi tạo order.
- Backend tự lấy lại giá từ DynamoDB, không tin giá do frontend gửi lên.

#### POS và order

- Thêm/giảm số lượng dịch vụ trong giỏ hàng.
- Tính tổng tiền realtime.
- Màn tóm tắt đơn hàng.
- Chọn thanh toán tiền mặt hoặc QR.
- Thanh toán tiền mặt cập nhật order thành `PAID` với payment method `CASH`.
- Thanh toán QR tạo order và payment session thật.
- QR hiển thị realtime và polling trạng thái mỗi hai giây.
- Tải QR PNG có nền trắng và quiet zone chuẩn.
- QR/session hết hạn sau năm phút.
- Lịch sử đơn hàng theo thứ tự mới nhất.
- Xem chi tiết món, số lượng, giá, tổng tiền, phương thức và mã đơn.
- Trạng thái: `WAITING_PAYMENT`, `PAID`, `CANCELLED`, `EXPIRED`, `REFUNDED`.
- Hủy đơn đang chờ.
- Session QR hết hạn sẽ cập nhật order/session khi được kiểm tra.
- Hoàn tiền QR nguyên tử:
  - Trừ ví merchant.
  - Cộng lại ví customer.
  - Cập nhật order thành `REFUNDED`.
  - Ghi giao dịch hoàn tiền cho hai phía.
- Hoàn tiền order tiền mặt bằng cách đánh dấu `REFUNDED`.

### 3.4. Admin

- Đăng nhập bằng Cognito group admin.
- API chỉ cho role admin truy cập.
- Danh sách hồ sơ merchant đang chờ duyệt.
- Xem chi tiết hồ sơ.
- Xem ảnh giấy phép kinh doanh bằng signed URL.
- Duyệt hồ sơ.
- Từ chối hồ sơ kèm lý do.
- Ghi `reviewedBy`, `reviewedAt` và trạng thái vào DynamoDB.
- Không cho xử lý lại hồ sơ đã approved/rejected.

### 3.5. Backend/API đã có

| Method | Path | Chức năng |
|---|---|---|
| GET/POST/PATCH | `/me/profile` | Đọc, tạo, cập nhật profile |
| POST | `/merchant/applications` | Gửi hồ sơ kinh doanh |
| GET | `/merchant/applications/me` | Trạng thái hồ sơ của user |
| POST | `/uploads/presign` | Tạo pre-signed URL |
| GET | `/admin/merchant-applications` | Danh sách hồ sơ theo trạng thái |
| GET | `/admin/merchant-applications/{applicationId}` | Chi tiết hồ sơ |
| POST | `/admin/merchant-applications/{applicationId}/approve` | Duyệt hồ sơ |
| POST | `/admin/merchant-applications/{applicationId}/reject` | Từ chối hồ sơ |
| GET/PATCH | `/merchant/store` | Đọc/cập nhật cửa hàng |
| GET/POST | `/merchant/products` | Danh sách/thêm dịch vụ |
| PATCH/DELETE | `/merchant/products/{productId}` | Sửa/xóa dịch vụ |
| GET/POST | `/merchant/orders` | Danh sách/tạo order |
| GET | `/merchant/orders/{orderId}` | Chi tiết order |
| POST | `/merchant/orders/{orderId}/checkout-cash` | Thanh toán tiền mặt |
| POST | `/merchant/orders/{orderId}/checkout-qr` | Tạo QR session |
| POST | `/merchant/orders/{orderId}/cancel` | Hủy order |
| POST | `/merchant/orders/{orderId}/refund` | Hoàn tiền order |
| GET | `/payments/sessions/{sessionId}` | Hóa đơn/trạng thái session |
| POST | `/payments/sessions/{sessionId}/confirm-transfer` | Customer thanh toán QR |
| GET | `/wallet/balance` | Số dư ví |
| POST | `/wallet/transfer` | Chuyển tiền |
| GET | `/wallet/recipients/resolve` | Tra cứu người nhận |
| GET | `/wallet/transactions` | Lịch sử giao dịch |
| GET | `/wallet/transactions/{txId}` | Chi tiết giao dịch/bill |
| GET | `/directory/search` | Người nhận gần đây/cửa hàng |

## 4. Kiểm thử và xác minh đã thực hiện

- `flutter analyze`: đạt, không có issue tại lần kiểm tra gần nhất.
- `flutter test`: 33 tests đạt tại lần kiểm tra gần nhất.
- `npm test`: 4 backend tests đạt.
- `sam validate --lint`: template hợp lệ.
- `sam build`: thành công.
- `flutter build web --dart-define-from-file=config/dev.json`: thành công.
- CloudFormation stack deploy thành công.
- Đã gọi Lambda/API thật để kiểm tra:
  - Danh sách merchant order.
  - Chi tiết transaction và bill.
  - Directory search.
  - Resolve recipient bằng số Việt Nam.
  - Hủy order đang chờ.
- Đã kiểm tra thanh toán QR thật giữa merchant và customer dev.
- Đã kiểm tra QR PNG được tải xuống và đọc lại.

Các nhóm test frontend hiện có:

- API client và JWT.
- Chuẩn hóa số điện thoại.
- QR image decoder.
- Customer edge cases.
- Customer repository/recent transactions.
- Merchant POS mock flow.
- Admin approval flow.
- Điều hướng theo role.

## 5. Các phần chưa hoàn thành

### 5.1. Phát hành và vận hành

- Frontend chưa deploy lên AWS Amplify/S3/CloudFront; hiện vẫn chạy localhost.
- Chưa có domain riêng và HTTPS frontend production.
- Chưa có stack `staging` hoặc `prod` đã triển khai.
- Chưa có CI/CD tự động cho test/build/deploy.
- Chưa có quy trình migration/backfill dữ liệu chính thức.
- Chưa có backup/restore test dù DynamoDB PITR đã bật.
- Chưa có CloudWatch Alarm, dashboard vận hành hoặc cảnh báo lỗi.
- Chưa có AWS Budget/cảnh báo chi phí được quản lý bằng IaC.
- Chưa cấu hình log retention; CloudWatch Logs có thể tích lũy.
- S3 versioning đang bật nhưng chưa có lifecycle rule dọn version/ảnh cũ.
- Khi thay/xóa ảnh sản phẩm, object cũ chưa được xóa khỏi S3.

### 5.2. Authentication và bảo mật

- SMS vẫn ở sandbox; chỉ số đích đã xác minh mới nhận OTP.
- Chưa xin production access cho SMS.
- Chưa có Forgot Password/Reset Password bằng OTP.
- Chưa có Splash và Onboarding hoàn chỉnh.
- Đăng ký customer chưa thu họ tên/CCCD/điều khoản ngay trong màn signup; cập nhật sau ở Profile.
- OTP UI chưa phải sáu ô riêng và chưa có countdown gửi lại.
- Token chỉ lưu trong bộ nhớ; reload app sẽ mất session.
- Chưa lưu token bằng secure storage.
- Chưa tự refresh access/ID token bằng refresh token.
- Chưa có cơ chế xử lý session hết hạn toàn cục.
- Chưa có MFA/2FA cho admin.
- Chưa có CAPTCHA, WAF, device risk hoặc chống bot đăng ký/OTP pumping ở frontend.
- Chưa có rate limit nghiệp vụ riêng cho đăng ký, resend OTP, chuyển tiền và thanh toán.
- CORS API hiện còn rộng, phù hợp dev nhưng cần siết cho production.

### 5.3. Customer

- Profile chưa upload avatar thật; hiện dùng icon mặc định.
- Chia sẻ QR nhận tiền mới sao chép payload/ID, chưa tích hợp native share sheet đầy đủ.
- Chưa tải QR nhận tiền thành file PNG như QR merchant.
- Search người dùng chủ yếu hỗ trợ exact phone/user ID và recent recipients; chưa có tìm gần đúng theo tên toàn hệ thống.
- Search cửa hàng chỉ theo tiền tố tên.
- Bấm cửa hàng trong kết quả search chưa mở trang cửa hàng/catalog dịch vụ.
- Chưa có public store detail/products API cho customer.
- Chưa có danh sách yêu thích, cửa hàng gần đây theo vị trí hoặc đánh giá.
- Chưa có thông báo/push notification sau chuyển tiền, thanh toán hoặc hoàn tiền.
- Chưa có PIN giao dịch, biometric hoặc bước xác nhận bảo mật bổ sung.
- Chưa có hạn mức chuyển tiền/ngày và kiểm soát gian lận.
- Chưa có định dạng tiền tệ chuẩn có dấu phân cách hàng nghìn ở toàn bộ màn hình.
- Chưa có export/chia sẻ hóa đơn PDF.

### 5.4. Merchant

- Danh sách dịch vụ chưa có search/filter theo trạng thái.
- Chưa có nút bật/tắt `isActive`; hiện chủ yếu thêm/sửa/xóa.
- Xóa dịch vụ chưa có confirm dialog.
- Chưa có inventory, danh mục, biến thể hoặc tồn kho.
- Dashboard mới có KPI trong ngày; chưa có biểu đồ tuần/tháng và export báo cáo.
- Chưa có lọc order theo ngày/trạng thái/phương thức thanh toán.
- Chưa có phân trang/cursor cho order lớn.
- Hoàn tiền QR chưa có quy trình admin phê duyệt.
- Hoàn tiền tiền mặt chỉ đổi trạng thái; tiền mặt thực tế phải được merchant xử lý ngoài hệ thống.
- Một số order QR cũ tạo trước khi lưu `customerUserId/paymentTxId` có thể không hoàn tiền tự động. Một order dev gần nhất đã được backfill.
- Hết hạn QR hiện được ghi khi payment session được GET/poll; chưa có EventBridge Scheduler tự quét session hết hạn.
- Chưa có hóa đơn in/POS printer.

### 5.5. Admin

- Admin UI hiện chủ yếu chỉ hiển thị hồ sơ `PENDING`.
- Chưa có dashboard số lượng pending/approved/rejected theo ngày.
- Chưa có tab/filter xem lịch sử approved/rejected.
- Chưa có tìm kiếm hồ sơ theo tên/số điện thoại.
- Chưa có màn Approval Result/log riêng.
- Chưa có danh sách user, khóa/mở tài khoản hoặc thu hồi quyền merchant.
- Chưa có quản lý giao dịch, điều tra thanh toán và duyệt hoàn tiền.
- Chưa có audit log bất biến cho các thao tác admin.

### 5.6. Backend và dữ liệu

- Backend tests mới tập trung vào auth utility; chưa có unit/integration test đầy đủ cho từng Lambda.
- Chưa có DynamoDB Local/LocalStack test suite.
- Chưa có automated end-to-end test chạy xuyên Cognito -> API -> DynamoDB -> S3.
- Một số API giới hạn cứng 50/100 bản ghi và chưa trả pagination token.
- Directory search chưa phải full-text search.
- Chưa có schema version cho DynamoDB items.
- Chưa có quy trình xử lý dead-letter queue cho Lambda.
- Chưa có tracing AWS X-Ray.
- Chưa có reconciliation job kiểm tra tổng tiền ví/giao dịch/order.
- Chưa có double-entry ledger hoàn chỉnh; hiện dùng wallet balance + transaction records.
- Chưa có cơ chế đóng băng ví hoặc xử lý chargeback/tranh chấp.

### 5.7. UI/UX

- Giao diện mới ở mức chức năng, chưa có design system hoàn chỉnh.
- Chưa triển khai đầy đủ Splash, Onboarding và role registration picker theo wireframe.
- Chưa tối ưu toàn bộ màn hình cho mobile nhỏ/tablet/desktop.
- Chưa kiểm tra accessibility, keyboard navigation, screen reader và contrast toàn diện.
- Chưa có localization/i18n; nội dung đang cố định tiếng Việt và một số lỗi backend còn bằng tiếng Anh.
- Chưa có skeleton loading nhất quán.
- Một số màn mock vẫn được giữ khi chạy app không có AWS config.

## 6. Hạn chế và lưu ý quan trọng

1. Đây là môi trường `dev`, không dùng cho tiền thật.
2. Số dư hiện là dữ liệu demo trong DynamoDB, không kết nối ngân hàng hoặc cổng thanh toán.
3. Không lưu mật khẩu tài khoản dev trong repository hoặc tài liệu này.
4. SMS sandbox chỉ cho phép tối đa 10 verified destination numbers; hiện đã dùng 1.
5. Muốn gửi OTP đến số bất kỳ phải xin AWS End User Messaging production access.
6. Camera QR cần người dùng cấp quyền camera; Web chỉ hoạt động trên localhost hoặc HTTPS.
7. Hoàn tiền QR thực sự thay đổi số dư hai ví trong môi trường dev.
8. Cost Explorer tại lần kiểm tra gần nhất cho thấy Lambda/API Gateway/DynamoDB/Cognito đang khoảng `$0`, S3 chỉ phát sinh lượng rất nhỏ; chi phí có thể tăng khi có traffic/SMS/log/ảnh.
9. Không được đưa file `frontend/config/dev.json` hoặc AWS resource identifiers vào ứng dụng public production mà chưa rà soát cấu hình. App Client ID/API URL không phải secret, nhưng môi trường vẫn cần tách biệt.

## 7. Cách chạy và kiểm tra

### Frontend AWS dev

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define-from-file=config/dev.json
```

Do dự án dùng plugin camera, sau khi thêm/cập nhật dependency nên dừng hẳn app rồi chạy lại thay vì chỉ Hot Restart.

### Kiểm tra frontend

```powershell
cd frontend
dart format lib test
flutter analyze
flutter test
flutter build web --dart-define-from-file=config/dev.json
```

### Kiểm tra backend

```powershell
cd backend
npm test
sam validate --lint -t template.yaml
sam build -t template.yaml
```

### Deploy backend dev

```powershell
cd backend
sam build -t template.yaml
sam deploy --no-confirm-changeset --no-fail-on-empty-changeset
```

### Xem tài nguyên trên AWS Console

1. Chọn region `Asia Pacific (Singapore)`.
2. Mở CloudFormation.
3. Chọn stack `wallet-app-backend-dev`.
4. Mở tab Resources để xem Lambda, API Gateway, DynamoDB, Cognito và S3.

## 8. Thứ tự ưu tiên đề xuất

### Ưu tiên P0 - trước khi cho người khác dùng thử rộng rãi

1. Secure storage và refresh token.
2. Forgot Password.
3. Rate limit/chống bot OTP và transfer.
4. CloudWatch alarms, log retention và AWS Budget.
5. Test tích hợp cho payment/refund/idempotency.
6. Tách hẳn dev/staging/prod.

### Ưu tiên P1 - hoàn thiện nghiệp vụ demo

1. Admin dashboard, filter/search và lịch sử phê duyệt.
2. Public store detail/catalog cho customer.
3. Filter/search order và sản phẩm.
4. Scheduled expiration bằng EventBridge.
5. Push notification/receipt.
6. Avatar customer và tải/chia sẻ QR nhận tiền.

### Ưu tiên P2 - hoàn thiện sản phẩm

1. Design system và responsive UI.
2. Báo cáo merchant theo tuần/tháng.
3. Export/chia sẻ hóa đơn.
4. Audit log và reconciliation.
5. CI/CD và automated E2E.
6. Deploy frontend lên Amplify hoặc S3 + CloudFront.

## 9. Tiêu chí để gọi là sẵn sàng production

Dự án chỉ nên được coi là production-ready khi tối thiểu hoàn thành:

- SMS production access hoặc thay bằng kênh xác thực production khác.
- Frontend production được host qua HTTPS.
- Secure session/refresh token.
- Hạn mức và chống gian lận giao dịch.
- Monitoring, alarm, budget và log retention.
- Backup/restore test.
- CI/CD và test payment/refund/idempotency tự động.
- Security review IAM, API, CORS, S3 và dữ liệu cá nhân.
- Chính sách quyền riêng tư/điều khoản sử dụng.
- Tách dev/staging/prod và không dùng dữ liệu demo trong production.

