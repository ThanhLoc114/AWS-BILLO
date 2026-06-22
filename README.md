# AWS BILLO Wallet

Prototype ví điện tử gồm Flutter frontend và AWS serverless backend.

## Trạng thái hiện tại

- Flutter vẫn giữ chế độ mock để phát triển UI khi chưa có AWS.
- Khi truyền đủ `API_BASE_URL` và `COGNITO_CLIENT_ID`, app mở luồng đăng ký, OTP và đăng nhập Cognito thật.
- Backend AWS SAM gồm Cognito, API Gateway HTTP API, Lambda, DynamoDB và S3.
- Nhóm Cognito quyết định quyền: `customer`, `merchant`, `admin`.
- Người dùng mới mặc định là customer. Khi admin duyệt hồ sơ, backend thêm người dùng vào nhóm merchant.

## Kiểm tra local

```powershell
cd backend
npm install
npm test
sam validate --lint
sam build

cd ..\frontend
flutter pub get
flutter analyze
flutter test
```

## Triển khai backend dev

Lần đầu nên xem change set trước khi xác nhận vì thao tác này tạo tài nguyên AWS có thể phát sinh chi phí:

```powershell
cd backend
sam build
sam deploy --guided
```

Các lần sau có thể dùng cấu hình trong `samconfig.toml`:

```powershell
sam deploy
```

Sau deploy, lấy các output `ApiBaseUrl`, `UserPoolId` và `UserPoolClientId` từ CloudFormation.

## Chạy Flutter với AWS dev

Stack dev hiện đã được cấu hình trong `frontend/config/dev.json`:

```powershell
cd frontend
flutter run --dart-define-from-file=config/dev.json
```

Hoặc truyền từng biến thủ công:

```powershell
cd frontend
flutter run `
  --dart-define=API_BASE_URL=https://YOUR_API_ID.execute-api.ap-southeast-1.amazonaws.com/dev `
  --dart-define=AWS_REGION=ap-southeast-1 `
  --dart-define=COGNITO_CLIENT_ID=YOUR_USER_POOL_CLIENT_ID
```

Không truyền các biến trên thì app tiếp tục chạy role selector và dữ liệu mock như trước.

## Tạo admin đầu tiên

Đăng ký một tài khoản qua app, sau đó thêm tài khoản đó vào nhóm `admin` bằng AWS CLI hoặc Cognito Console. Không cho phép mobile client tự gán role.

```powershell
aws cognito-idp admin-add-user-to-group `
  --user-pool-id YOUR_USER_POOL_ID `
  --username YOUR_COGNITO_USERNAME `
  --group-name admin `
  --region ap-southeast-1
```

## Việc còn lại gần nhất

- Lưu token bằng secure storage và refresh session.
- Thay dữ liệu mock Customer/Merchant/Admin bằng `ApiClient`.
- Thêm API pre-signed upload cho giấy phép và ảnh sản phẩm.
- Bổ sung test Lambda với DynamoDB local hoặc AWS dev stack.
- Thiết kế UI hoàn chỉnh theo `PROJECT_STRUCTURE_AND_WIREFRAMES.md`.

## Kiểm thử đăng ký kinh doanh

1. Đăng nhập tài khoản customer, mở `Tài khoản` → `Đăng ký kinh doanh`.
2. Điền hồ sơ và tải ảnh giấy phép; hồ sơ chuyển sang `PENDING`.
3. Đăng xuất và đăng nhập admin dev để duyệt hồ sơ.
4. Customer đăng xuất/đăng nhập lại để token nhận group `merchant`.
5. Trong `Không gian kinh doanh`, mở tab `Dịch vụ` để thêm hình ảnh, tên, mô tả và giá.

Không lưu thông tin đăng nhập admin dev trong repository. Tạo hoặc đổi mật khẩu bằng Cognito CLI khi cần kiểm thử.

## Seed ví kiểm thử dev

Script này chỉ chạy với bảng có hậu tố `-dev` và cần cờ xác nhận rõ ràng:

```powershell
cd backend
$env:SEED_DEV_WALLETS="1"
$env:CURRENT_USER_ID="COGNITO_SUB"
npm run seed:dev
```

Script đặt ví hiện tại thành `1.000.000 VND` và tạo ví nhận `dev-receiver-001` với `100.000 VND`. Không dùng script này cho staging hoặc production.
