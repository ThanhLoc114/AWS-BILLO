import 'package:flutter/material.dart';

import '../../core/files/image_picker.dart';
import '../../core/files/picked_image.dart';
import '../../core/files/upload_service.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/phone_number.dart';

class MerchantApplicationScreen extends StatefulWidget {
  final ApiClient apiClient;

  const MerchantApplicationScreen({super.key, required this.apiClient});

  @override
  State<MerchantApplicationScreen> createState() =>
      _MerchantApplicationScreenState();
}

class _MerchantApplicationScreenState extends State<MerchantApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _businessName = TextEditingController();
  final _phone = TextEditingController();
  final _cccd = TextEditingController();
  final _address = TextEditingController();
  PickedImage? _licenseImage;
  bool _loading = false;
  late Future<Map<String, dynamic>> _statusFuture;

  @override
  void initState() {
    super.initState();
    _reloadStatus();
  }

  void _reloadStatus() {
    _statusFuture = widget.apiClient.get('/merchant/applications/me');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _businessName.dispose();
    _phone.dispose();
    _cccd.dispose();
    _address.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Không được để trống' : null;

  Future<void> _chooseLicense() async {
    try {
      final image = await pickImage();
      if (image != null && mounted) {
        setState(() => _licenseImage = image);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Đã chọn ảnh: ${image.name}')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không chọn được ảnh: $error')));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ảnh giấy phép kinh doanh')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final licenseKey = await UploadService(
        widget.apiClient,
      ).uploadImage(_licenseImage!, 'BUSINESS_LICENSE');
      await widget.apiClient.post(
        '/merchant/applications',
        body: {
          'fullName': _fullName.text.trim(),
          'businessName': _businessName.text.trim(),
          'phone': normalizePhoneNumber(_phone.text),
          'cccd': _cccd.text.trim(),
          'address': _address.text.trim(),
          'businessLicenseS3Key': licenseKey,
        },
      );
      if (!mounted) return;
      setState(_reloadStatus);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi hồ sơ thất bại: $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _statusCard(Map<String, dynamic> application) {
    final status = application['approvalStatus'] as String? ?? 'NOT_SUBMITTED';
    final color = switch (status) {
      'APPROVED' => Colors.green,
      'REJECTED' => Colors.red,
      _ => Colors.orange,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.storefront, size: 56, color: color),
            const SizedBox(height: 12),
            Text(switch (status) {
              'APPROVED' => 'Hồ sơ đã được duyệt',
              'REJECTED' => 'Hồ sơ bị từ chối',
              _ => 'Hồ sơ đang chờ admin duyệt',
            }, style: Theme.of(context).textTheme.titleLarge),
            if (application['rejectReason'] != null)
              Text('Lý do: ${application['rejectReason']}'),
            if (status == 'APPROVED')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Hãy đăng xuất và đăng nhập lại để mở giao diện kinh doanh.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Đăng ký kinh doanh',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fullName,
            decoration: const InputDecoration(
              labelText: 'Họ tên chủ kinh doanh',
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _businessName,
            decoration: const InputDecoration(
              labelText: 'Tên cửa hàng/doanh nghiệp',
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại',
              prefixText: '+84 ',
              hintText: '0853555443',
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _cccd,
            decoration: const InputDecoration(labelText: 'CCCD'),
            validator: _required,
          ),
          TextFormField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Địa chỉ kinh doanh'),
            validator: _required,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loading ? null : _chooseLicense,
            icon: const Icon(Icons.image_outlined),
            label: Text(_licenseImage?.name ?? 'Chọn ảnh giấy phép kinh doanh'),
          ),
          if (_licenseImage != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _licenseImage!.bytes,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Gửi hồ sơ xét duyệt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ kinh doanh')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Không tải được hồ sơ: ${snapshot.error}'),
            );
          }
          final application =
              snapshot.data?['data'] as Map<String, dynamic>? ?? {};
          final status =
              application['approvalStatus'] as String? ?? 'NOT_SUBMITTED';
          if (status == 'NOT_SUBMITTED' || status == 'REJECTED') return _form();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [_statusCard(application)],
          );
        },
      ),
    );
  }
}
