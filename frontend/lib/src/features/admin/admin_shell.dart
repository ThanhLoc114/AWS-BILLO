import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';

class AdminShell extends StatefulWidget {
  final ApiClient? apiClient;
  final VoidCallback? onSignOut;

  const AdminShell({super.key, this.apiClient, this.onSignOut});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final List<MerchantApplication> applications = [
    MerchantApplication(
      id: 'APP001',
      ownerName: 'Nguyễn Văn A',
      phone: '0901000001',
      address: 'Q1, TP.HCM',
      status: 'PENDING',
    ),
    MerchantApplication(
      id: 'APP002',
      ownerName: 'Trần Thị B',
      phone: '0901000002',
      address: 'Q3, TP.HCM',
      status: 'APPROVED',
    ),
  ];

  void _updateStatus(String id, String status) {
    setState(() {
      final index = applications.indexWhere((e) => e.id == id);
      if (index >= 0) {
        applications[index] = applications[index].copyWith(status: status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.apiClient != null) {
      return _AwsAdminApprovals(
        apiClient: widget.apiClient!,
        onSignOut: widget.onSignOut,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Admin duyệt hồ sơ')),
      body: ListView.builder(
        key: const Key('admin_application_list'),
        padding: const EdgeInsets.all(16),
        itemCount: applications.length,
        itemBuilder: (context, index) {
          final item = applications[index];
          return Card(
            child: ListTile(
              key: Key('admin_item_${item.id}'),
              title: Text('Hồ sơ #${item.id}'),
              subtitle: Text('${item.ownerName} - ${item.status}'),
              onTap: () async {
                final result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MerchantApprovalDetailScreen(application: item),
                  ),
                );
                if (result != null) {
                  _updateStatus(item.id, result);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _AwsAdminApprovals extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback? onSignOut;

  const _AwsAdminApprovals({required this.apiClient, this.onSignOut});

  @override
  State<_AwsAdminApprovals> createState() => _AwsAdminApprovalsState();
}

class _AwsAdminApprovalsState extends State<_AwsAdminApprovals> {
  late Future<List<Map<String, dynamic>>> _applications;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _applications = widget.apiClient
        .get('/admin/merchant-applications?status=PENDING')
        .then(
          (response) => (response['data'] as List).cast<Map<String, dynamic>>(),
        );
  }

  Future<void> _open(Map<String, dynamic> summary) async {
    final id = summary['applicationId'] as String;
    final response = await widget.apiClient.get(
      '/admin/merchant-applications/$id',
    );
    if (!mounted) return;
    final application = response['data'] as Map<String, dynamic>;
    final action = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _AwsApprovalDetail(application: application),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'APPROVED') {
        await widget.apiClient.post('/admin/merchant-applications/$id/approve');
      } else {
        await widget.apiClient.post(
          '/admin/merchant-applications/$id/reject',
          body: {'rejectReason': action},
        );
      }
      if (mounted) setState(_reload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Xử lý hồ sơ thất bại: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt đăng ký kinh doanh'),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _applications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Không tải được hồ sơ: ${snapshot.error}'),
            );
          }
          final applications = snapshot.data ?? [];
          if (applications.isEmpty) {
            return const Center(child: Text('Không có hồ sơ chờ duyệt'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: applications.length,
            itemBuilder: (context, index) {
              final item = applications[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.store)),
                  title: Text(item['businessName'] as String? ?? 'Cửa hàng'),
                  subtitle: Text('${item['fullName']} • ${item['phone']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(item),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AwsApprovalDetail extends StatelessWidget {
  final Map<String, dynamic> application;

  const _AwsApprovalDetail({required this.application});

  @override
  Widget build(BuildContext context) {
    final licenseUrl = application['businessLicenseUrl'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết hồ sơ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            application['businessName'] as String? ?? 'Cửa hàng',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('Chủ kinh doanh: ${application['fullName']}'),
          Text('SĐT: ${application['phone']}'),
          Text('CCCD: ${application['cccdMasked']}'),
          Text('Địa chỉ: ${application['address']}'),
          const SizedBox(height: 16),
          if (licenseUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                licenseUrl,
                height: 260,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Text('Không tải được ảnh giấy phép'),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'APPROVED'),
            icon: const Icon(Icons.check),
            label: const Text('Duyệt hồ sơ'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final controller = TextEditingController();
              final reason = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Lý do từ chối'),
                  content: TextField(controller: controller),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        context,
                        controller.text.trim().isEmpty
                            ? 'Hồ sơ chưa hợp lệ'
                            : controller.text.trim(),
                      ),
                      child: const Text('Xác nhận'),
                    ),
                  ],
                ),
              );
              controller.dispose();
              if (reason != null && context.mounted) {
                Navigator.pop(context, reason);
              }
            },
            icon: const Icon(Icons.close),
            label: const Text('Từ chối'),
          ),
        ],
      ),
    );
  }
}

class MerchantApprovalDetailScreen extends StatelessWidget {
  final MerchantApplication application;

  const MerchantApprovalDetailScreen({super.key, required this.application});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chi tiết hồ sơ #${application.id}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chủ quán: ${application.ownerName}'),
            Text('SĐT: ${application.phone}'),
            Text('Địa chỉ: ${application.address}'),
            const SizedBox(height: 8),
            Text('Trạng thái hiện tại: ${application.status}'),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('admin_approve_button'),
                    onPressed: () => Navigator.pop(context, 'APPROVED'),
                    child: const Text('Duyệt'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const Key('admin_reject_button'),
                    onPressed: () => Navigator.pop(context, 'REJECTED'),
                    child: const Text('Từ chối'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MerchantApplication {
  final String id;
  final String ownerName;
  final String phone;
  final String address;
  final String status;

  MerchantApplication({
    required this.id,
    required this.ownerName,
    required this.phone,
    required this.address,
    required this.status,
  });

  MerchantApplication copyWith({
    String? id,
    String? ownerName,
    String? phone,
    String? address,
    String? status,
  }) {
    return MerchantApplication(
      id: id ?? this.id,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      status: status ?? this.status,
    );
  }
}
