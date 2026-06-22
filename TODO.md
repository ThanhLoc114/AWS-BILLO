# TODO - Hoàn thiện chức năng ví điện tử (Batch tiếp theo)

## 1) Customer

- [ ] Hoàn thiện flow QR thanh toán: Scan giả lập -> Invoice -> Confirm chuyển tiền -> kết quả thành công/thất bại (đang làm)
- [ ] Hoàn thiện validation form chuyển tiền (người nhận, số tiền, nội dung) (đang làm)

## 2) Merchant

- [ ] Hoàn thiện POS: chọn sản phẩm, tăng/giảm số lượng, tính tổng realtime (đang làm)
- [ ] Hoàn thiện tạo order + xuất QR checkout theo session mock (đang làm)
- [ ] Hiển thị trạng thái chờ thanh toán/đã thanh toán (đang làm)

## 3) Admin

- [ ] Hoàn thiện danh sách hồ sơ merchant chờ duyệt (đang làm)
- [ ] Hoàn thiện màn chi tiết hồ sơ (đang làm)
- [ ] Action duyệt/từ chối giả lập + cập nhật trạng thái (đang làm)

## 4) Thorough testing

- [ ] Bổ sung widget test cho Customer QR flow (đang làm)
- [ ] Bổ sung widget test cho Merchant POS flow (đang làm)
- [ ] Bổ sung widget test cho Admin approve/reject flow (đang làm)
- [ ] Chạy full `flutter test` và xử lý lỗi (nếu có)
