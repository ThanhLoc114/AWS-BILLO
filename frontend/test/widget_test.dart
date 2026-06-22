import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/src/app/app.dart';

void main() {
  group('Role selection', () {
    testWidgets('renders role selection screen', (WidgetTester tester) async {
      await tester.pumpWidget(const WalletApp());

      expect(find.text('Chọn vai trò'), findsOneWidget);
      expect(find.text('Khách hàng'), findsOneWidget);
      expect(find.text('Chủ cửa tiệm'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('navigates to CustomerShell', (WidgetTester tester) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Khách hàng'));
      await tester.pumpAndSettle();

      expect(find.text('Xin chào, Khách hàng'), findsOneWidget);
      expect(find.text('Lịch sử'), findsOneWidget);
      expect(find.text('QR'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('navigates to MerchantShell', (WidgetTester tester) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Chủ cửa tiệm'));
      await tester.pumpAndSettle();

      expect(find.text('Chủ cửa tiệm'), findsOneWidget);
      expect(find.text('Chờ duyệt'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('POS'), findsOneWidget);
    });

    testWidgets('navigates to AdminShell', (WidgetTester tester) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      expect(find.text('Admin duyệt hồ sơ'), findsOneWidget);
      expect(find.text('Hồ sơ #APP001'), findsOneWidget);
      expect(find.text('Hồ sơ #APP002'), findsOneWidget);
    });
  });

  group('Customer interactions', () {
    testWidgets('navigates Home -> Transfer screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Khách hàng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chuyển tiền'));
      await tester.pumpAndSettle();

      expect(find.text('Chuyển tiền'), findsOneWidget);
      expect(find.text('Người nhận'), findsOneWidget);
      expect(find.text('Số tiền'), findsOneWidget);
      expect(find.text('Nội dung'), findsOneWidget);
    });

    testWidgets('navigates Home -> Receive screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Khách hàng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nhận tiền'));
      await tester.pumpAndSettle();

      expect(find.text('Nhận tiền'), findsOneWidget);
      expect(find.text('Hiển thị QR cá nhân + mã ví'), findsOneWidget);
    });

    testWidgets('navigates Home -> QR Scan screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Khách hàng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quét QR thanh toán'));
      await tester.pumpAndSettle();

      expect(find.text('Quét QR'), findsOneWidget);
      expect(find.text('Giả lập quét thành công'), findsOneWidget);
    });

    testWidgets('QR flow end-to-end: scan -> invoice -> success', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Khách hàng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quét QR thanh toán'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mock_qr_scan_success')));
      await tester.pumpAndSettle();

      expect(find.text('Hóa đơn thanh toán'), findsOneWidget);
      expect(find.textContaining('Quán Trà Sữa Mặt Trời'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_invoice_transfer')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment_success_text')), findsOneWidget);
      expect(find.text('Thanh toán thành công'), findsOneWidget);
    });

    testWidgets('bottom navigation switches tabs', (WidgetTester tester) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Khách hàng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Màn hình Lịch sử giao dịch'), findsOneWidget);

      await tester.tap(find.text('QR'));
      await tester.pumpAndSettle();
      expect(find.text('Màn hình QR (scan/hiển thị mã)'), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Màn hình Profile khách hàng'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Xin chào, Khách hàng'), findsOneWidget);
    });
  });
}
