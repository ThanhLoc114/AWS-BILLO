import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/auth/cognito_auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/phone_number.dart';
import '../../admin/admin_shell.dart';
import '../../customer/customer_shell.dart';
import '../../merchant/merchant_shell.dart';

class AuthScreen extends StatefulWidget {
  final CognitoAuthService authService;

  const AuthScreen({super.key, required this.authService});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _registering = false;
  bool _awaitingCode = false;
  bool _loading = false;
  String? _error;

  String get _normalizedPhone => normalizePhoneNumber(_phone.text);

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_awaitingCode) {
        await widget.authService.confirmSignUp(
          phone: _normalizedPhone,
          code: _code.text.trim(),
        );
        setState(() {
          _awaitingCode = false;
          _registering = false;
        });
        return;
      }
      if (_registering) {
        try {
          await widget.authService.signUp(
            phone: _normalizedPhone,
            password: _password.text,
          );
        } on ApiException catch (error) {
          if (!error.message.toLowerCase().contains('already exists')) {
            rethrow;
          }
        }
        setState(() => _awaitingCode = true);
        return;
      }

      final session = await widget.authService.signIn(
        phone: _normalizedPhone,
        password: _password.text,
      );
      if (!mounted) return;
      final role = _roleFromIdToken(session.idToken);
      final apiClient = ApiClient(
        config: widget.authService.config,
        sessionStore: widget.authService.sessionStore,
      );
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (routeContext) {
            void signOut() {
              widget.authService.signOut();
              Navigator.of(routeContext).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => AuthScreen(authService: widget.authService),
                ),
                (_) => false,
              );
            }

            return switch (role) {
              'admin' => AdminShell(apiClient: apiClient, onSignOut: signOut),
              'merchant' => MerchantShell(
                apiClient: apiClient,
                onSignOut: signOut,
              ),
              _ => CustomerShell(apiClient: apiClient, onSignOut: signOut),
            };
          },
        ),
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Không thể kết nối AWS. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.authService.resendConfirmationCode(phone: _normalizedPhone);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AWS đã gửi lại mã OTP đăng ký.')),
        );
      }
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _roleFromIdToken(String token) {
    try {
      final parts = token.split('.');
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final rawGroups = payload['cognito:groups'];
      final groups = rawGroups is List ? rawGroups.cast<String>() : <String>[];
      if (groups.contains('admin')) return 'admin';
      if (groups.contains('merchant')) return 'merchant';
    } catch (_) {
      // A valid Cognito token is expected; customer is the safest fallback.
    }
    return 'customer';
  }

  @override
  Widget build(BuildContext context) {
    final title = _awaitingCode
        ? 'Xác nhận OTP'
        : _registering
        ? 'Tạo tài khoản'
        : 'Đăng nhập';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 72),
              const SizedBox(height: 24),
              TextField(
                controller: _phone,
                enabled: !_awaitingCode,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  hintText: '0853555443',
                  helperText:
                      'Số Việt Nam: 085...; số quốc tế: nhập cả dấu +, ví dụ +1206...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (!_awaitingCode)
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mã OTP',
                    border: OutlineInputBorder(),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_awaitingCode ? 'Xác nhận' : title),
              ),
              if (_awaitingCode)
                TextButton(
                  onPressed: _loading ? null : _resendCode,
                  child: const Text('Gửi lại OTP'),
                ),
              if (!_awaitingCode)
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                          _registering = !_registering;
                          _error = null;
                        }),
                  child: Text(
                    _registering
                        ? 'Đã có tài khoản? Đăng nhập'
                        : 'Chưa có tài khoản? Đăng ký',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
