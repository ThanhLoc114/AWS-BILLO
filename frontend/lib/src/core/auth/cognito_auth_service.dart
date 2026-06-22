import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../app/config/app_config.dart';
import '../network/api_exception.dart';
import 'auth_session.dart';

class CognitoAuthService {
  final AppConfig config;
  final AuthSessionStore sessionStore;
  final http.Client _client;

  CognitoAuthService({
    required this.config,
    required this.sessionStore,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<void> signUp({required String phone, required String password}) async {
    await _call('SignUp', {
      'ClientId': config.cognitoClientId,
      'Username': phone,
      'Password': password,
      'UserAttributes': [
        {'Name': 'phone_number', 'Value': phone},
      ],
    });
  }

  Future<void> confirmSignUp({
    required String phone,
    required String code,
  }) async {
    await _call('ConfirmSignUp', {
      'ClientId': config.cognitoClientId,
      'Username': phone,
      'ConfirmationCode': code,
    });
  }

  Future<void> resendConfirmationCode({required String phone}) async {
    await _call('ResendConfirmationCode', {
      'ClientId': config.cognitoClientId,
      'Username': phone,
    });
  }

  Future<AuthSession> signIn({
    required String phone,
    required String password,
  }) async {
    final payload = await _call('InitiateAuth', {
      'AuthFlow': 'USER_PASSWORD_AUTH',
      'ClientId': config.cognitoClientId,
      'AuthParameters': {'USERNAME': phone, 'PASSWORD': password},
    });
    final result = payload['AuthenticationResult'] as Map<String, dynamic>?;
    if (result == null) throw ApiException('Cognito did not return a session');

    final session = AuthSession(
      idToken: result['IdToken'] as String,
      accessToken: result['AccessToken'] as String,
      refreshToken: result['RefreshToken'] as String?,
      expiresAt: DateTime.now().add(
        Duration(seconds: (result['ExpiresIn'] as num?)?.toInt() ?? 3600),
      ),
    );
    sessionStore.save(session);
    return session;
  }

  void signOut() => sessionStore.clear();

  Future<Map<String, dynamic>> _call(
    String operation,
    Map<String, dynamic> body,
  ) async {
    if (config.cognitoClientId.isEmpty) {
      throw ApiException('COGNITO_CLIENT_ID is not configured');
    }
    final response = await _client.post(
      config.cognitoEndpoint,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': 'AWSCognitoIdentityProviderService.$operation',
      },
      body: jsonEncode(body),
    );
    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        payload['message'] as String? ??
            payload['Message'] as String? ??
            'Cognito request failed',
      );
    }
    return payload;
  }
}
