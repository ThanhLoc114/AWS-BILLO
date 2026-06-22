import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/app/app.dart';

void main() {
  group('Customer edge cases', () {
    testWidgets('QR flow failed path shows failed result', (tester) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Khách hàng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quét QR thanh toán'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mock_qr_scan_success')));
      await tester.pumpAndSettle();

      expect(find.text('Hóa đơn thanh toán'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fail_invoice_transfer')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payment_failed_text')), findsOneWidget);
      expect(find.text('Thanh toán thất bại'), findsOneWidget);
    });

    testWidgets('Transfer validation: empty fields', (tester) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Khách hàng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chuyển tiền'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('transfer_submit_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('không được để trống'), findsNWidgets(3));
    });

    testWidgets('Transfer validation: amount is not a number', (tester) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Khách hàng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chuyển tiền'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('transfer_receiver_field')),
        '0909000999',
      );
      await tester.enterText(
        find.byKey(const Key('transfer_amount_field')),
        'abc',
      );
      await tester.enterText(
        find.byKey(const Key('transfer_content_field')),
        'Thanh toán',
      );
      await tester.tap(find.byKey(const Key('transfer_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Số tiền phải là số lớn hơn 0'), findsOneWidget);
    });

    testWidgets('Transfer validation: amount is huge number but still valid', (
      tester,
    ) async {
      await tester.pumpWidget(const WalletApp());

      await tester.tap(find.text('Khách hàng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chuyển tiền'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('transfer_receiver_field')),
        '0909000999',
      );
      await tester.enterText(
        find.byKey(const Key('transfer_amount_field')),
        '999999999',
      );
      await tester.enterText(
        find.byKey(const Key('transfer_content_field')),
        'Noi dung rat dai test boundary',
      );
      await tester.tap(find.byKey(const Key('transfer_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('Tạo lệnh chuyển tiền thành công (mock)'),
        findsOneWidget,
      );
    });
  });
}
