class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([super.message = 'Unauthorized'])
    : super(statusCode: 401);
}

class NetworkException extends ApiException {
  NetworkException([super.message = 'Network error']);
}

class TimeoutApiException extends ApiException {
  TimeoutApiException([super.message = 'Request timeout']);
}
