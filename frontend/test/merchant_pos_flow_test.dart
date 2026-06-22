import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/features/merchant/merchant_shell.dart';

void main() {
  testWidgets(
    'Merchant POS flow: add product -> create order -> paid -> back',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MerchantShell()));

      await tester.tap(find.text('POS'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('increase_Cà phê sữa')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('merchant_total_amount')), findsOneWidget);
      expect(find.textContaining('30000đ'), findsWidgets);

      await tester.tap(find.byKey(const Key('merchant_create_order_button')));
      await tester.pumpAndSettle();

      expect(find.text('QR Checkout'), findsOneWidget);

      await tester.tap(find.byKey(const Key('merchant_mark_paid_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('PAID'), findsOneWidget);

      await tester.tap(find.byKey(const Key('merchant_back_after_paid')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('merchant_checkout_status')), findsOneWidget);
      expect(find.textContaining('Đã thanh toán thành công'), findsOneWidget);
    },
  );
}
