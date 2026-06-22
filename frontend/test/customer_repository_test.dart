import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/network/api_exception.dart';
import 'package:frontend/src/features/customer/data/datasources/customer_mock_api.dart';
import 'package:frontend/src/features/customer/data/repositories/customer_repository.dart';

void main() {
  group('CustomerRepository', () {
    test('returns transactions on success', () async {
      final repo = CustomerRepository(CustomerMockApi(mode: 'success'));
      final result = await repo.getRecentTransactions();

      expect(result.isNotEmpty, true);
      expect(result.first.title, 'Thanh toán quán A');
    });

    test('throws UnauthorizedException on unauthorized mode', () async {
      final repo = CustomerRepository(CustomerMockApi(mode: 'unauthorized'));

      expect(
        () => repo.getRecentTransactions(),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('throws TimeoutApiException on timeout mode', () async {
      final repo = CustomerRepository(CustomerMockApi(mode: 'timeout'));

      expect(
        () => repo.getRecentTransactions(),
        throwsA(isA<TimeoutApiException>()),
      );
    });

    test('throws NetworkException on network mode', () async {
      final repo = CustomerRepository(CustomerMockApi(mode: 'network'));

      expect(
        () => repo.getRecentTransactions(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
