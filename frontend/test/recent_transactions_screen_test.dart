import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/features/customer/data/datasources/customer_mock_api.dart';
import 'package:frontend/src/features/customer/data/repositories/customer_repository.dart';
import 'package:frontend/src/features/customer/presentation/screens/recent_transactions_screen.dart';

Widget _buildTestApp(CustomerRepository repository) {
  return MaterialApp(home: RecentTransactionsScreen(repository: repository));
}

void main() {
  group('RecentTransactionsScreen', () {
    testWidgets('shows loading then success list', (WidgetTester tester) async {
      final repo = CustomerRepository(
        CustomerMockApi(
          mode: 'success',
          delay: const Duration(milliseconds: 500),
        ),
      );

      await tester.pumpWidget(_buildTestApp(repo));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Thanh toán quán A'), findsOneWidget);
      expect(find.text('Nhận từ bạn B'), findsOneWidget);
      expect(find.text('Chuyển đến bạn C'), findsOneWidget);
    });

    testWidgets('shows unauthorized error', (WidgetTester tester) async {
      final repo = CustomerRepository(
        CustomerMockApi(
          mode: 'unauthorized',
          delay: const Duration(milliseconds: 100),
        ),
      );

      await tester.pumpWidget(_buildTestApp(repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Token hết hạn'), findsOneWidget);
    });

    testWidgets('shows timeout error', (WidgetTester tester) async {
      final repo = CustomerRepository(
        CustomerMockApi(
          mode: 'timeout',
          delay: const Duration(milliseconds: 100),
        ),
      );

      await tester.pumpWidget(_buildTestApp(repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Kết nối quá hạn'), findsOneWidget);
    });

    testWidgets('shows network error', (WidgetTester tester) async {
      final repo = CustomerRepository(
        CustomerMockApi(
          mode: 'network',
          delay: const Duration(milliseconds: 100),
        ),
      );

      await tester.pumpWidget(_buildTestApp(repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Không có kết nối mạng'), findsOneWidget);
    });
  });
}
