import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../app/config/app_config.dart';
import '../auth/auth_session.dart';
import 'api_exception.dart';

class ApiClient {
  final AppConfig config;
  final AuthSessionStore sessionStore;
  final http.Client _client;

  ApiClient({
    required this.config,
    required this.sessionStore,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) => _send('POST', path, body: body, idempotencyKey: idempotencyKey);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) => _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<void> changePassword({
    required String previousPassword,
    required String proposedPassword,
  }) async {
    final session = sessionStore.current;
    if (session == null || session.isExpired) {
      throw UnauthorizedException('Phiên đăng nhập đã hết hạn');
    }
    final response = await _client.post(
      config.cognitoEndpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.ChangePassword',
      },
      body: jsonEncode({
        'AccessToken': session.accessToken,
        'PreviousPassword': previousPassword,
        'ProposedPassword': proposedPassword,
      }),
    );
    if (response.statusCode >= 400) {
      final payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw ApiException(
        payload['message'] as String? ?? 'Không thể đổi mật khẩu',
      );
    }
  }

  Future<void> uploadToSignedUrl({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final response = await _client.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Tải ảnh thất bại (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final session = sessionStore.current;
    if (session == null || session.isExpired) {
      throw UnauthorizedException('Phiên đăng nhập đã hết hạn');
    }
    final request = http.Request(method, config.apiUri(path));
    request.headers.addAll({
      'Authorization': 'Bearer ${session.idToken}',
      'Content-Type': 'application/json',
    });
    if (idempotencyKey != null) {
      request.headers['Idempotency-Key'] = idempotencyKey;
    }
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw UnauthorizedException(payload['message'] as String? ?? 'Forbidden');
    }
    if (response.statusCode >= 400) {
      throw ApiException(payload['message'] as String? ?? 'API request failed');
    }
    return payload;
  }
}
