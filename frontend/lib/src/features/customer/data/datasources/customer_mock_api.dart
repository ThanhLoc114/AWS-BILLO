import '../../../../core/network/api_exception.dart';

class CustomerMockApi {
  final Duration delay;
  final String mode;

  CustomerMockApi({
    this.delay = const Duration(milliseconds: 300),
    this.mode = 'success',
  });

  Future<List<Map<String, dynamic>>> fetchRecentTransactions() async {
    await Future.delayed(delay);

    switch (mode) {
      case 'success':
        return const [
          {'title': 'Thanh toán quán A', 'amount': '-50.000đ', 'type': 'out'},
          {'title': 'Nhận từ bạn B', 'amount': '+120.000đ', 'type': 'in'},
          {'title': 'Chuyển đến bạn C', 'amount': '-80.000đ', 'type': 'out'},
        ];
      case 'unauthorized':
        throw UnauthorizedException('Token hết hạn');
      case 'timeout':
        throw TimeoutApiException('Kết nối quá hạn');
      case 'network':
        throw NetworkException('Không có kết nối mạng');
      default:
        throw ApiException('Unknown mock mode');
    }
  }
}
