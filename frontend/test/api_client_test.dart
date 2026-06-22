import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/app/config/app_config.dart';
import 'package:frontend/src/core/auth/auth_session.dart';
import 'package:frontend/src/core/network/api_client.dart';
import 'package:frontend/src/core/network/api_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = AppConfig(
    apiBaseUrl: 'https://example.execute-api.ap-southeast-1.amazonaws.com/dev',
    awsRegion: 'ap-southeast-1',
    cognitoClientId: 'client-id',
  );

  test('builds stage-aware API URL', () {
    expect(
      config.apiUri('/wallet/balance').toString(),
      'https://example.execute-api.ap-southeast-1.amazonaws.com/dev/wallet/balance',
    );
  });

  test('preserves API query parameters', () {
    expect(
      config.apiUri('/admin/merchant-applications?status=PENDING').toString(),
      'https://example.execute-api.ap-southeast-1.amazonaws.com/dev/admin/merchant-applications?status=PENDING',
    );
  });

  test('sends ID token to protected API', () async {
    final store = AuthSessionStore()
      ..save(
        AuthSession(
          idToken: 'id-token',
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
    final client = ApiClient(
      config: config,
      sessionStore: store,
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer id-token');
        return http.Response(
          jsonEncode({
            'data': {'balance': 1000},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final response = await client.get('/wallet/balance');
    expect((response['data'] as Map<String, dynamic>)['balance'], 1000);
  });

  test('rejects request without a session', () async {
    final client = ApiClient(
      config: config,
      sessionStore: AuthSessionStore(),
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(
      () => client.get('/wallet/balance'),
      throwsA(isA<UnauthorizedException>()),
    );
  });
}
