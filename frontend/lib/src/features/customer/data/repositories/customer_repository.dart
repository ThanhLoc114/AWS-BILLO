import '../../../../core/network/api_exception.dart';
import '../datasources/customer_mock_api.dart';
import '../models/transaction_item.dart';

class CustomerRepository {
  final CustomerMockApi api;

  CustomerRepository(this.api);

  Future<List<TransactionItem>> getRecentTransactions() async {
    try {
      final json = await api.fetchRecentTransactions();
      return json.map(TransactionItem.fromJson).toList();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Lỗi không xác định');
    }
  }
}
