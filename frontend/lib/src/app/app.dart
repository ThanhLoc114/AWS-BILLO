import 'package:flutter/material.dart';

import '../features/admin/admin_shell.dart';
import 'config/app_config.dart';
import '../core/auth/auth_session.dart';
import '../core/auth/cognito_auth_service.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/customer/customer_shell.dart';
import '../features/merchant/merchant_shell.dart';

class WalletApp extends StatelessWidget {
  const WalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = AppConfig.fromEnvironment();
    final sessionStore = AuthSessionStore();
    return MaterialApp(
      title: 'Ví Điện Tử AWS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C4DFF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        useMaterial3: true,
      ),
      home: config.isAwsConfigured
          ? AuthScreen(
              authService: CognitoAuthService(
                config: config,
                sessionStore: sessionStore,
              ),
            )
          : const RoleSelectScreen(),
    );
  }
}

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn vai trò')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _RoleButton(
              title: 'Khách hàng',
              subtitle: 'Sử dụng ví, chuyển/nhận tiền, quét QR',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerShell()),
                );
              },
            ),
            const SizedBox(height: 12),
            _RoleButton(
              title: 'Chủ cửa tiệm',
              subtitle: 'Quản lý quán, sản phẩm, tạo đơn/QR',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MerchantShell()),
                );
              },
            ),
            const SizedBox(height: 12),
            _RoleButton(
              title: 'Admin',
              subtitle: 'Duyệt hồ sơ chủ cửa hàng',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminShell()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}
