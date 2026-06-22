# AWS-Only Backend Blueprint cho dự án Ví điện tử Flutter

## 0) Mục tiêu

Tài liệu này triển khai đầy đủ 5 mục đã xác nhận:

1. Kiến trúc AWS chi tiết
2. Thiết kế DynamoDB chi tiết
3. API contract theo role
4. Luồng bảo mật giao dịch (idempotency, atomic transfer, audit)
5. IaC đề xuất + cấu trúc thư mục backend

---

## 1) Kiến trúc AWS chi tiết (AWS-only)

## 1.1 Thành phần chính

- **Amazon Cognito**
  - User Pool: đăng ký/đăng nhập, JWT
  - Group/Custom claims: `customer`, `merchant`, `admin`
- **Amazon API Gateway (HTTP API hoặc REST API)**
  - Expose API cho mobile app/admin portal
  - Authorizer dùng Cognito JWT
- **AWS Lambda**
  - Business logic theo domain (auth profile, merchant approval, wallet, order, payment)
- **Amazon DynamoDB**
  - Lưu dữ liệu nghiệp vụ ví điện tử
- **Amazon S3**
  - Lưu ảnh sản phẩm, giấy phép kinh doanh, avatar
- **Amazon CloudFront (optional)**
  - CDN cho ảnh public/private (qua signed URL nếu cần)
- **Amazon CloudWatch + X-Ray**
  - Logs, metrics, trace, alarm
- **AWS IAM**
  - Least privilege cho Lambda/S3/DynamoDB
- **AWS WAF**
  - Bảo vệ API chống bot/rate abuse cơ bản
- **AWS KMS**
  - Mã hóa dữ liệu nhạy cảm (at rest key management)
- **Amazon EventBridge (optional)**
  - Event-driven cho notification/audit pipeline
- **AWS Step Functions (optional)**
  - Workflow duyệt hồ sơ merchant nhiều bước

## 1.2 Mô hình triển khai

- Flutter app -> API Gateway -> Lambda -> DynamoDB/S3
- Admin (web/app nội bộ) -> API Gateway -> Lambda (admin scoped)
- Tất cả request bắt buộc JWT hợp lệ (trừ đăng nhập/đăng ký public)

## 1.3 Phân quyền role

- `customer`: chuyển/nhận tiền, quét QR, lịch sử cá nhân
- `merchant`: quản lý quán/sản phẩm/đơn, tạo QR thanh toán
- `admin`: duyệt merchant, theo dõi hệ thống, audit

---

## 2) Thiết kế DynamoDB chi tiết

## 2.1 Khuyến nghị mô hình

Dùng **single-table design** để tối ưu truy vấn và scale:

- Table: `WalletAppMain`
- PK: `PK` (string)
- SK: `SK` (string)
- TTL cho payment session
- Stream bật cho audit/event sourcing

## 2.2 Entity mapping (gợi ý)

### User Profile

- PK: `USER#{userId}`
- SK: `PROFILE#`
- attrs: `role`, `fullName`, `phone`, `cccdMasked`, `status`, `createdAt`, `updatedAt`

### Merchant Application

- PK: `USER#{userId}`
- SK: `MERCHANT_APP#{applicationId}`
- attrs: `address`, `businessLicenseS3Key`, `approvalStatus(PENDING|APPROVED|REJECTED)`, `reviewedBy`, `reviewedAt`, `rejectReason`

### Wallet

- PK: `USER#{userId}`
- SK: `WALLET#PRIMARY`
- attrs: `balance`, `currency`, `walletStatus`, `version`

### Store

- PK: `STORE#{storeId}`
- SK: `META#`
- attrs: `ownerUserId`, `storeName`, `address`, `approvalStatus`, `createdAt`

### Product

- PK: `STORE#{storeId}`
- SK: `PRODUCT#{productId}`
- attrs: `name`, `price`, `imageS3Key`, `isActive`, `updatedAt`

### Order

- PK: `STORE#{storeId}`
- SK: `ORDER#{orderId}`
- attrs: `items[]`, `totalAmount`, `status(DRAFT|WAITING_PAYMENT|PAID|CANCELLED)`, `paymentMethod`, `createdAt`

### Payment Session (QR)

- PK: `PAYMENT_SESSION#{sessionId}`
- SK: `META#`
- attrs: `orderId`, `storeId`, `merchantUserId`, `amount`, `status(WAITING|PAID|EXPIRED)`, `expiresAtEpoch(ttl)`

### Transaction

- PK: `USER#{userId}`
- SK: `TX#{timestamp}#{txId}`
- attrs: `direction(IN|OUT)`, `amount`, `counterpartyUserId`, `orderId`, `status`, `idempotencyKey`

### Global Transaction Record (audit)

- PK: `TX#{txId}`
- SK: `META#`
- attrs: toàn bộ snapshot giao dịch, phục vụ đối soát

## 2.3 GSI đề xuất

- **GSI1**: tìm merchant applications theo trạng thái
  - GSI1PK: `MERCHANT_APP_STATUS#{status}`
  - GSI1SK: `{createdAt}`
- **GSI2**: lịch sử đơn của store theo thời gian
  - GSI2PK: `STORE_ORDER#{storeId}`
  - GSI2SK: `{createdAt}`
- **GSI3**: tra cứu user theo phone
  - GSI3PK: `PHONE#{phone}`
  - GSI3SK: `USER#{userId}`
- **GSI4**: payment session theo status
  - GSI4PK: `PAYMENT_STATUS#{status}`
  - GSI4SK: `{expiresAt}`

---

## 3) API Contract đầy đủ theo role

## 3.1 Auth/Profile

- `POST /auth/register/customer`
- `POST /auth/register/merchant`
- `POST /auth/login` (nếu dùng custom auth; thường Cognito Hosted/SDK)
- `GET /me/profile`
- `PATCH /me/profile`

## 3.2 Merchant Approval (Admin + Merchant)

- `POST /merchant/applications`
- `GET /merchant/applications/me`
- `GET /admin/merchant-applications?status=pending`
- `GET /admin/merchant-applications/{applicationId}`
- `POST /admin/merchant-applications/{applicationId}/approve`
- `POST /admin/merchant-applications/{applicationId}/reject`

## 3.3 Store/Product (Merchant)

- `GET /merchant/store`
- `PATCH /merchant/store`
- `POST /merchant/products`
- `GET /merchant/products`
- `PATCH /merchant/products/{productId}`
- `DELETE /merchant/products/{productId}`

## 3.4 POS + Order (Merchant)

- `POST /merchant/orders`
- `GET /merchant/orders/{orderId}`
- `POST /merchant/orders/{orderId}/checkout-cash`
- `POST /merchant/orders/{orderId}/checkout-qr`

## 3.5 Customer Payment

- `GET /payments/sessions/{sessionId}` (xem invoice từ QR)
- `POST /payments/sessions/{sessionId}/confirm-transfer`
- `POST /wallet/transfer` (chuyển tiền thủ công)
- `GET /wallet/balance`
- `GET /wallet/transactions?from=&to=&type=`

## 3.6 Upload API (pre-signed URL)

- `POST /uploads/presign`  
  body: `{purpose: PRODUCT_IMAGE|BUSINESS_LICENSE|AVATAR, contentType}`  
  response: `{uploadUrl, s3Key, expiresIn}`

---

## 4) Luồng bảo mật giao dịch

## 4.1 Idempotency

- Mọi API tạo giao dịch bắt buộc header: `Idempotency-Key`
- Lưu key vào DynamoDB với TTL ngắn
- Nếu key đã tồn tại và request payload giống nhau -> trả lại response cũ
- Nếu key tồn tại nhưng payload khác -> reject `409 Conflict`

## 4.2 Atomic transfer (chuyển tiền an toàn)

Dùng `TransactWriteItems` của DynamoDB:

1. Check ví người gửi đủ số dư
2. Trừ tiền ví gửi
3. Cộng tiền ví nhận
4. Ghi transaction OUT cho sender
5. Ghi transaction IN cho receiver
6. Ghi global tx record

Tất cả trong 1 transaction, nếu lỗi rollback toàn bộ.

## 4.3 QR payment security

- QR chỉ chứa `sessionId` + chữ ký ngắn (HMAC)
- Session có TTL (ví dụ 5 phút)
- Confirm payment chỉ thành công khi session `WAITING` và chưa hết hạn
- Tránh double spend bằng condition expression + idempotency key

## 4.4 Audit & compliance

- CloudWatch log correlationId/requestId
- DynamoDB Streams -> Lambda -> bảng audit hoặc S3 audit archive
- Ẩn dữ liệu nhạy cảm trong log (PII masking)

## 4.5 IAM least privilege

- Lambda chỉ được quyền đúng partition key cần thiết (nếu khả thi)
- Tách role cho:
  - customer APIs
  - merchant APIs
  - admin APIs
- S3 bucket policy tách prefix theo purpose + signed URL

---

## 5) IaC đề xuất + cấu trúc backend

## 5.1 Chọn IaC

Khuyến nghị:

- **AWS SAM** nếu team ưu tiên serverless nhanh
- **Terraform** nếu hệ thống multi-env/multi-cloud governance mạnh

Tại giai đoạn MVP serverless, ưu tiên **AWS SAM**.

## 5.2 Cấu trúc thư mục backend (đề xuất)

```text
backend/
├─ template.yaml                  # AWS SAM template
├─ samconfig.toml
├─ src/
│  ├─ shared/
│  │  ├─ auth/
│  │  │  ├─ jwt_claims.dart|ts|py (tuỳ runtime)
│  │  ├─ utils/
│  │  │  ├─ response_builder.*
│  │  │  ├─ validator.*
│  │  │  ├─ idempotency.*
│  │  │  └─ logger.*
│  │  └─ data/
│  │     ├─ dynamo_client.*
│  │     └─ s3_client.*
│  ├─ functions/
│  │  ├─ auth_profile/
│  │  ├─ merchant_application/
│  │  ├─ admin_approval/
│  │  ├─ merchant_store_product/
│  │  ├─ merchant_order/
│  │  ├─ payment_session/
│  │  ├─ wallet_transfer/
│  │  └─ transaction_history/
│  └─ events/
│     └─ dynamo_stream_audit/
├─ layers/
│  └─ common_dependencies/
├─ docs/
│  ├─ openapi/
│  │  └─ wallet-api.yaml
│  ├─ dynamodb-schema.md
│  └─ runbooks/
└─ tests/
   ├─ unit/
   ├─ integration/
   └─ curl/
      ├─ auth.http
      ├─ merchant.http
      ├─ admin.http
      └─ wallet.http
```

## 5.3 Môi trường

- `dev`, `staging`, `prod` tách account hoặc tách stack
- Biến môi trường Lambda:
  - `TABLE_NAME`
  - `BUCKET_NAME`
  - `IDEMPOTENCY_TABLE`
  - `JWT_ISSUER`, `JWT_AUDIENCE`
  - `PAYMENT_SESSION_TTL_SECONDS`

---

## 6) NFR (phi chức năng) cần chốt sớm

- P95 API latency mục tiêu (< 300-500ms với request phổ biến)
- RTO/RPO cho dữ liệu giao dịch
- Alerting:
  - Lambda error rate
  - 5xx API Gateway
  - throttling
- Backup:
  - DynamoDB PITR
  - S3 versioning + lifecycle archive

---

## 7) Test strategy (thorough sau khi triển khai code backend)

## 7.1 API happy-path

- Đăng ký customer/merchant
- Admin duyệt merchant
- Merchant tạo sản phẩm, tạo order, tạo QR
- Customer quét QR và confirm transfer thành công

## 7.2 Error-path & edge cases

- Merchant chưa duyệt mà gọi API merchant protected
- QR expired
- Số dư không đủ
- Re-submit cùng idempotency key
- Unauthorized/forbidden claims

## 7.3 Curl test packs

- Mỗi endpoint có ít nhất:
  - 1 request thành công
  - 1 request sai dữ liệu
  - 1 request sai quyền
  - 1 request edge case

---

## 8) Kết luận

Blueprint này đảm bảo backend dùng **AWS-only**, phù hợp dự án ví điện tử Flutter theo yêu cầu:

- Có phân vai trò customer/merchant/admin
- Có kiểm duyệt merchant
- Có POS merchant + QR payment
- Có bảo mật giao dịch mức production-oriented (idempotency + atomic writes + audit)
