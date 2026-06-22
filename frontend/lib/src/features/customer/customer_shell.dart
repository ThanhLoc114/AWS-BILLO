import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/files/image_picker.dart';
import '../../core/files/qr_image_decoder.dart';
import '../merchant/merchant_application_screen.dart';

class CustomerShell extends StatefulWidget {
  final ApiClient? apiClient;
  final VoidCallback? onSignOut;

  const CustomerShell({super.key, this.apiClient, this.onSignOut});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int index = 0;

  List<Widget> get screens => [
    CustomerHomeScreen(apiClient: widget.apiClient),
    CustomerHistoryScreen(apiClient: widget.apiClient),
    CustomerQrScreen(apiClient: widget.apiClient),
    CustomerProfileScreen(
      apiClient: widget.apiClient,
      onSignOut: widget.onSignOut,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Lịch sử',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: 'QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class CustomerHomeScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const CustomerHomeScreen({super.key, this.apiClient});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late final Future<List<Map<String, dynamic>>>? _awsOverview =
      widget.apiClient == null
      ? null
      : Future.wait([
          widget.apiClient!.get('/me/profile'),
          widget.apiClient!.get('/wallet/balance'),
          widget.apiClient!.get('/wallet/transactions'),
        ]);

  Widget _overview() {
    if (_awsOverview == null) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Xin chào, Khách hàng'),
        subtitle: Text('Chế độ dữ liệu mock'),
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _awsOverview,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Không tải được dữ liệu AWS: ${snapshot.error}');
        }
        final profile = snapshot.data![0]['data'] as Map<String, dynamic>;
        final wallet = snapshot.data![1]['data'] as Map<String, dynamic>;
        final fullName = profile['fullName'] as String? ?? 'Khách hàng';
        final balance = (wallet['balance'] as num? ?? 0).toInt();
        return Card(
          child: ListTile(
            title: Text('Xin chào, $fullName'),
            subtitle: Text('Số dư: $balance VND'),
            leading: const CircleAvatar(child: Icon(Icons.person)),
          ),
        );
      },
    );
  }

  Widget _recentTransactions() {
    if (_awsOverview == null) {
      return const Column(
        children: [
          _HistoryItem('Thanh toán quán A', '-50.000đ'),
          _HistoryItem('Nhận từ bạn B', '+120.000đ'),
          _HistoryItem('Chuyển đến bạn C', '-80.000đ'),
        ],
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _awsOverview,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Không tải được giao dịch gần đây: ${snapshot.error}');
        }
        final raw = snapshot.data![2]['data'];
        final transactions = raw is List
            ? raw.cast<Map<String, dynamic>>().take(3).toList()
            : <Map<String, dynamic>>[];
        if (transactions.isEmpty) {
          return const Card(child: ListTile(title: Text('Chưa có giao dịch')));
        }
        return Column(
          children: transactions.map((tx) {
            final incoming = tx['direction'] == 'IN';
            final amount = (tx['amount'] as num? ?? 0).toInt();
            return _HistoryItem(
              tx['content'] as String? ??
                  (incoming ? 'Nhận tiền' : 'Chuyển tiền'),
              '${incoming ? '+' : '-'}$amount VND',
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ví của tôi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _overview(),
          const SizedBox(height: 12),
          _SearchBox(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CustomerSearchScreen(apiClient: widget.apiClient),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TransferScreen(apiClient: widget.apiClient),
                      ),
                    );
                  },
                  child: const Text('Chuyển tiền'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReceiveScreen(apiClient: widget.apiClient),
                      ),
                    );
                  },
                  child: const Text('Nhận tiền'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QrScanScreen(apiClient: widget.apiClient),
                ),
              );
            },
            child: const Text('Quét QR thanh toán'),
          ),
          const SizedBox(height: 16),
          const _SectionTitle('Lịch sử gần đây'),
          _recentTransactions(),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBox({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextField(
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: 'Tìm kiếm người nhận/cửa tiệm...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class CustomerSearchScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const CustomerSearchScreen({super.key, this.apiClient});

  @override
  State<CustomerSearchScreen> createState() => _CustomerSearchScreenState();
}

class _CustomerSearchScreenState extends State<CustomerSearchScreen> {
  final _controller = TextEditingController();
  Future<Map<String, dynamic>>? _results;

  @override
  void initState() {
    super.initState();
    if (widget.apiClient != null) _search();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = Uri.encodeQueryComponent(_controller.text.trim());
    setState(() {
      _results = widget.apiClient?.get('/directory/search?query=$query');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Số điện thoại, mã ví hoặc tên cửa hàng',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: widget.apiClient == null
                ? const Center(child: Text('Tìm kiếm người nhận/cửa tiệm'))
                : FutureBuilder<Map<String, dynamic>>(
                    future: _results,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Không thể tìm kiếm: ${snapshot.error}'),
                        );
                      }
                      final data =
                          snapshot.data?['data'] as Map<String, dynamic>? ?? {};
                      final recipients =
                          (data['recipients'] as List? ?? const [])
                              .cast<Map<String, dynamic>>();
                      final stores = (data['stores'] as List? ?? const [])
                          .cast<Map<String, dynamic>>();
                      if (recipients.isEmpty && stores.isEmpty) {
                        return const Center(
                          child: Text(
                            'Không tìm thấy kết quả\nThử nhập đủ số điện thoại hoặc tên cửa hàng',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          if (recipients.isNotEmpty) ...[
                            Text(
                              _controller.text.trim().isEmpty
                                  ? 'Người nhận gần đây'
                                  : 'Người nhận',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            ...recipients.map(
                              (recipient) => Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(
                                    recipient['fullName'] as String? ??
                                        'Người dùng ví',
                                  ),
                                  subtitle: Text(
                                    recipient['phoneMasked'] as String? ?? '',
                                  ),
                                  trailing: const Icon(Icons.send_outlined),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TransferScreen(
                                        apiClient: widget.apiClient,
                                        initialRecipient:
                                            recipient['userId'] as String?,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (stores.isNotEmpty) ...[
                            Text(
                              'Cửa hàng',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            ...stores.map(
                              (store) => Card(
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.storefront),
                                  ),
                                  title: Text(
                                    store['storeName'] as String? ?? 'Cửa hàng',
                                  ),
                                  subtitle: Text(
                                    store['address'] as String? ?? '',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _HistoryItem extends StatelessWidget {
  final String title;
  final String amount;
  const _HistoryItem(this.title, this.amount);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          amount,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class CustomerHistoryScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const CustomerHistoryScreen({super.key, this.apiClient});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  late Future<Map<String, dynamic>>? _history;
  String _filter = 'ALL';
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _history = widget.apiClient?.get('/wallet/transactions');
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)} ${two(date.day)}/${two(date.month)}/${date.year}';
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (range != null && mounted) setState(() => _dateRange = range);
  }

  bool _matchesFilter(Map<String, dynamic> tx) {
    final payment = tx['orderId'] != null || tx['type'] == 'QR_PAYMENT';
    final direction = tx['direction'];
    final typeMatches = switch (_filter) {
      'IN' => direction == 'IN' && !payment,
      'OUT' => direction == 'OUT' && !payment,
      'PAYMENT' => payment,
      _ => true,
    };
    if (!typeMatches || _dateRange == null) return typeMatches;
    final createdAt = DateTime.tryParse(
      tx['createdAt']?.toString() ?? '',
    )?.toLocal();
    if (createdAt == null) return false;
    final start = DateTime(
      _dateRange!.start.year,
      _dateRange!.start.month,
      _dateRange!.start.day,
    );
    final end = DateTime(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day + 1,
    );
    return !createdAt.isBefore(start) && createdAt.isBefore(end);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.apiClient == null) {
      return const Scaffold(
        body: Center(child: Text('Màn hình Lịch sử giao dịch')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử giao dịch'),
        actions: [
          IconButton(
            tooltip: 'Lọc theo ngày',
            onPressed: _pickDateRange,
            icon: Icon(
              _dateRange == null
                  ? Icons.date_range_outlined
                  : Icons.event_available,
            ),
          ),
          if (_dateRange != null)
            IconButton(
              tooltip: 'Xóa lọc ngày',
              onPressed: () => setState(() => _dateRange = null),
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Không tải được lịch sử: ${snapshot.error}'),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => setState(_reload),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          final data = snapshot.data?['data'];
          final transactions = data is List
              ? data.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];
          final filtered = transactions.where(_matchesFilter).toList();
          return Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ALL', label: Text('Tất cả')),
                    ButtonSegment(value: 'IN', label: Text('Nhận')),
                    ButtonSegment(value: 'OUT', label: Text('Chuyển')),
                    ButtonSegment(value: 'PAYMENT', label: Text('Thanh toán')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) =>
                      setState(() => _filter = value.first),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(_reload);
                    await _history;
                  },
                  child: filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 150),
                            Icon(Icons.receipt_long_outlined, size: 64),
                            SizedBox(height: 12),
                            Center(child: Text('Không có giao dịch phù hợp')),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final tx = filtered[index];
                            final isIncoming = tx['direction'] == 'IN';
                            final amount = (tx['amount'] as num? ?? 0).toInt();
                            final isQrPayment =
                                tx['orderId'] != null ||
                                tx['type'] == 'QR_PAYMENT';
                            return Card(
                              child: ListTile(
                                onTap: tx['txId'] == null
                                    ? null
                                    : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              CustomerTransactionDetailScreen(
                                                apiClient: widget.apiClient!,
                                                txId: tx['txId'] as String,
                                              ),
                                        ),
                                      ),
                                leading: CircleAvatar(
                                  backgroundColor: isIncoming
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  child: Icon(
                                    isQrPayment
                                        ? Icons.storefront_outlined
                                        : isIncoming
                                        ? Icons.south_west
                                        : Icons.north_east,
                                    color: isIncoming
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                title: Text(
                                  tx['content'] as String? ??
                                      (isQrPayment
                                          ? 'Thanh toán QR'
                                          : isIncoming
                                          ? 'Nhận tiền'
                                          : 'Chuyển tiền'),
                                ),
                                subtitle: Text(
                                  '${_formatDate(tx['createdAt'])}'
                                  '${tx['orderId'] == null ? '' : '\nĐơn: ${tx['orderId']}'}',
                                ),
                                isThreeLine: tx['orderId'] != null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${isIncoming ? '+' : '-'}$amount VND',
                                      style: TextStyle(
                                        color: isIncoming
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CustomerTransactionDetailScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String txId;

  const CustomerTransactionDetailScreen({
    super.key,
    required this.apiClient,
    required this.txId,
  });

  @override
  State<CustomerTransactionDetailScreen> createState() =>
      _CustomerTransactionDetailScreenState();
}

class _CustomerTransactionDetailScreenState
    extends State<CustomerTransactionDetailScreen> {
  late final Future<Map<String, dynamic>> _detail;

  @override
  void initState() {
    super.initState();
    _detail = widget.apiClient.get('/wallet/transactions/${widget.txId}');
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)} ${two(date.day)}/${two(date.month)}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết giao dịch')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Không tải được chi tiết: ${snapshot.error}'),
            );
          }
          final data = snapshot.data!['data'] as Map<String, dynamic>;
          final tx = data['transaction'] as Map<String, dynamic>;
          final order = data['order'] as Map<String, dynamic>?;
          final store = data['store'] as Map<String, dynamic>?;
          final incoming = tx['direction'] == 'IN';
          final amount = (tx['amount'] as num? ?? 0).toInt();
          final items = (order?['items'] as List? ?? const [])
              .cast<Map<String, dynamic>>();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: incoming
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        child: Icon(
                          incoming ? Icons.south_west : Icons.north_east,
                          color: incoming ? Colors.green : Colors.red,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${incoming ? '+' : '-'}$amount VND',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: incoming ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        tx['status'] == 'SUCCESS'
                            ? 'Giao dịch thành công'
                            : tx['status']?.toString() ?? 'Không xác định',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Thông tin giao dịch',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Thời gian'),
                      trailing: Text(_formatDate(tx['createdAt'])),
                    ),
                    ListTile(
                      title: const Text('Nội dung'),
                      trailing: Text(
                        tx['content'] as String? ??
                            (order == null
                                ? 'Chuyển tiền'
                                : 'Thanh toán dịch vụ'),
                      ),
                    ),
                    ListTile(
                      title: const Text('Mã giao dịch'),
                      subtitle: SelectableText(tx['txId'] as String? ?? ''),
                    ),
                  ],
                ),
              ),
              if (order != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Hóa đơn dịch vụ',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          store?['storeName'] as String? ?? 'Cửa hàng',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(store?['address'] as String? ?? ''),
                        const Divider(height: 28),
                        ...items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['name'] ?? 'Dịch vụ'} × ${item['qty'] ?? 1}',
                                  ),
                                ),
                                Text('${item['price'] ?? 0} VND'),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tổng cộng'),
                            Text(
                              '${order['totalAmount'] ?? amount} VND',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Thanh toán: ${order['paymentMethod'] ?? 'QR'}'),
                        Text('Mã đơn: ${order['orderId'] ?? ''}'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class CustomerQrScreen extends StatelessWidget {
  final ApiClient? apiClient;

  const CustomerQrScreen({super.key, this.apiClient});

  @override
  Widget build(BuildContext context) {
    if (apiClient == null) {
      return const Scaffold(
        body: Center(child: Text('Màn hình QR (scan/hiển thị mã)')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán QR')),
      body: PaymentCodeEntry(apiClient: apiClient!),
    );
  }
}

class CustomerProfileScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final VoidCallback? onSignOut;

  const CustomerProfileScreen({super.key, this.apiClient, this.onSignOut});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late Future<Map<String, dynamic>>? _profile;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _profile = widget.apiClient?.get('/me/profile');
  }

  Future<void> _editProfile(Map<String, dynamic> profile) async {
    final name = TextEditingController(text: profile['fullName'] as String?);
    final address = TextEditingController(text: profile['address'] as String?);
    final cccd = TextEditingController(text: profile['cccdMasked'] as String?);
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa hồ sơ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
              ),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
              ),
              TextField(
                controller: cccd,
                decoration: const InputDecoration(
                  labelText: 'CCCD đã che hoặc 4 số cuối',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'fullName': name.text.trim(),
              'address': address.text.trim(),
              'cccdMasked': cccd.text.trim(),
            }),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    name.dispose();
    address.dispose();
    cccd.dispose();
    if (values == null || !mounted) return;
    try {
      await widget.apiClient!.patch('/me/profile', body: values);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể cập nhật: $error')));
      }
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
            ),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
            ),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (next.text.length < 8 || next.text != confirm.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mật khẩu mới chưa hợp lệ hoặc không khớp'),
                  ),
                );
                return;
              }
              Navigator.pop(context, [current.text, next.text]);
            },
            child: const Text('Đổi mật khẩu'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (values == null || !mounted) return;
    try {
      await widget.apiClient!.changePassword(
        previousPassword: values[0],
        proposedPassword: values[1],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đổi mật khẩu thành công')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đổi mật khẩu: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.apiClient == null) {
      return const Scaffold(
        body: Center(child: Text('Màn hình Profile khách hàng')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Không tải được hồ sơ: ${snapshot.error}'),
            );
          }
          final profile = snapshot.data!['data'] as Map<String, dynamic>;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        child: Icon(Icons.person, size: 42),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile['fullName'] as String? ?? 'Khách hàng',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(profile['phone'] as String? ?? ''),
                    ],
                  ),
                ),
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('CCCD'),
                      trailing: Text(
                        profile['cccdMasked'] as String? ?? 'Chưa cập nhật',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Địa chỉ'),
                      subtitle: Text(
                        profile['address'] as String? ?? 'Chưa cập nhật',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Chỉnh sửa hồ sơ'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _editProfile(profile),
                    ),
                  ],
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Đổi mật khẩu'),
                  subtitle: const Text('Cài đặt bảo mật tài khoản'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePassword,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Đăng ký kinh doanh'),
                  subtitle: const Text(
                    'Gửi hồ sơ để mở cửa hàng và bán dịch vụ',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MerchantApplicationScreen(
                        apiClient: widget.apiClient!,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.onSignOut != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Đăng xuất'),
                    onTap: widget.onSignOut,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class TransferScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final String? initialRecipient;

  const TransferScreen({super.key, this.apiClient, this.initialRecipient});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _receiverController;
  final _amountController = TextEditingController();
  final _contentController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _receiverController = TextEditingController(text: widget.initialRecipient);
  }

  @override
  void dispose() {
    _receiverController.dispose();
    _amountController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return '$field không được để trống';
    }
    return null;
  }

  String? _amountValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Số tiền không được để trống';
    }
    final amount = int.tryParse(value.trim());
    if (amount == null || amount <= 0) return 'Số tiền phải là số lớn hơn 0';
    return null;
  }

  String _recipientQuery(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri?.scheme == 'walletapp' && uri?.host == 'transfer') {
      return uri?.queryParameters['userId'] ?? trimmed;
    }
    return trimmed;
  }

  Future<void> _scanRecipient() async {
    if (widget.apiClient == null) return;
    final userId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RecipientQrScannerScreen()),
    );
    if (userId != null && mounted) _receiverController.text = userId;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.apiClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo lệnh chuyển tiền thành công (mock)')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final query = _recipientQuery(_receiverController.text);
      final recipientResponse = await widget.apiClient!.get(
        '/wallet/recipients/resolve?query=${Uri.encodeQueryComponent(query)}',
      );
      final recipient = recipientResponse['data'] as Map<String, dynamic>;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận người nhận'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipient['fullName'] as String? ?? 'Người dùng ví',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(recipient['phoneMasked'] as String? ?? ''),
              const SizedBox(height: 12),
              Text('Số tiền: ${_amountController.text.trim()} VND'),
              Text('Nội dung: ${_contentController.text.trim()}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Chuyển tiền'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final response = await widget.apiClient!.post(
        '/wallet/transfer',
        body: {
          'toUserId': recipient['userId'],
          'amount': int.parse(_amountController.text.trim()),
          'content': _contentController.text.trim(),
        },
        idempotencyKey: 'flutter-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      final data = response['data'] as Map<String, dynamic>? ?? {};
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thành công: ${data['txId'] ?? ''}')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Chuyển tiền thất bại: $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chuyển tiền')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                key: const Key('transfer_receiver_field'),
                controller: _receiverController,
                decoration: const InputDecoration(
                  labelText: 'Người nhận',
                  helperText: 'Nhập số điện thoại, mã user hoặc quét QR',
                ),
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                validator: (v) => _requiredValidator(v, 'Người nhận'),
              ),
              if (widget.apiClient != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _scanRecipient,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Quét QR người nhận'),
                  ),
                ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('transfer_amount_field'),
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Số tiền'),
                keyboardType: TextInputType.number,
                validator: _amountValidator,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('transfer_content_field'),
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Nội dung'),
                validator: (v) => _requiredValidator(v, 'Nội dung'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('transfer_submit_button'),
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Xác nhận chuyển'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecipientQrScannerScreen extends StatefulWidget {
  const RecipientQrScannerScreen({super.key});

  @override
  State<RecipientQrScannerScreen> createState() =>
      _RecipientQrScannerScreenState();
}

class _RecipientQrScannerScreenState extends State<RecipientQrScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      final uri = value == null ? null : Uri.tryParse(value);
      final userId = uri?.scheme == 'walletapp' && uri?.host == 'transfer'
          ? uri?.queryParameters['userId']
          : null;
      if (userId == null || userId.isEmpty) continue;
      _handled = true;
      Navigator.pop(context, userId);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét QR người nhận')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Không mở được camera. Hãy cấp quyền camera cho ứng dụng.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: FilledButton.tonalIcon(
              onPressed: _controller.toggleTorch,
              icon: const Icon(Icons.flashlight_on_outlined),
              label: const Text('Bật/tắt đèn flash'),
            ),
          ),
        ],
      ),
    );
  }
}

class ReceiveScreen extends StatelessWidget {
  final ApiClient? apiClient;

  const ReceiveScreen({super.key, this.apiClient});

  @override
  Widget build(BuildContext context) {
    if (apiClient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nhận tiền')),
        body: const Center(child: Text('Hiển thị QR cá nhân + mã ví')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Nhận tiền')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: apiClient!.get('/me/profile'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Không tải được mã ví: ${snapshot.error}'),
            );
          }
          final profile = snapshot.data?['data'] as Map<String, dynamic>? ?? {};
          final userId = profile['userId'] as String? ?? '';
          final payload = 'walletapp://transfer?userId=$userId';
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                children: [
                  Text(
                    'QR nhận tiền',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Card(
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: QrImageView(data: payload, size: 260),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile['fullName'] as String? ?? 'Khách hàng',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text('Mã ví', textAlign: TextAlign.center),
                  SelectableText(userId, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: payload));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép mã nhận tiền'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Chia sẻ mã nhận tiền'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: userId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép mã ví')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Sao chép mã ví'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class QrScanScreen extends StatelessWidget {
  final ApiClient? apiClient;

  const QrScanScreen({super.key, this.apiClient});

  @override
  Widget build(BuildContext context) {
    if (apiClient != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quét QR thanh toán')),
        body: PaymentCodeEntry(apiClient: apiClient!),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Quét QR')),
      body: Center(
        child: FilledButton(
          key: const Key('mock_qr_scan_success'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PaymentInvoiceScreen(
                  storeName: 'Quán Trà Sữa Mặt Trời',
                  storeAddress: '12 Nguyễn Trãi, Q1',
                  items: ['Trà sữa trân châu - 45.000đ', 'Bánh flan - 20.000đ'],
                  total: '65.000đ',
                ),
              ),
            );
          },
          child: const Text('Giả lập quét thành công'),
        ),
      ),
    );
  }
}

class PaymentCodeEntry extends StatefulWidget {
  final ApiClient apiClient;

  const PaymentCodeEntry({super.key, required this.apiClient});

  @override
  State<PaymentCodeEntry> createState() => _PaymentCodeEntryState();
}

class _PaymentCodeEntryState extends State<PaymentCodeEntry> {
  final _controller = TextEditingController();
  final _scannerController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _decoding = false;
  bool _openingInvoice = false;

  @override
  void dispose() {
    _controller.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  String _sessionId(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    return uri?.queryParameters['sessionId'] ?? trimmed;
  }

  Future<void> _openInvoice(String value) async {
    final sessionId = _sessionId(value);
    if (sessionId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AwsPaymentInvoiceScreen(
          apiClient: widget.apiClient,
          sessionId: sessionId,
        ),
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_openingInvoice) return;
    final payload = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstWhere(
          (value) =>
              value.startsWith('ps_') ||
              (value.startsWith('walletapp://pay') &&
                  Uri.tryParse(value)?.queryParameters['sessionId'] != null),
          orElse: () => '',
        );
    if (payload.isEmpty) return;
    _openingInvoice = true;
    _controller.text = payload;
    await _scannerController.stop();
    if (mounted) await _openInvoice(payload);
    _openingInvoice = false;
    if (mounted) await _scannerController.start();
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thiết bị này không hỗ trợ đèn flash')),
        );
      }
    }
  }

  Future<void> _chooseQrImage() async {
    setState(() => _decoding = true);
    try {
      final image = await pickImage();
      if (image == null) return;
      final payload = QrImageDecoder.decode(image);
      _controller.text = payload;
      if (mounted) await _openInvoice(payload);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không đọc được QR: $error')));
      }
    } finally {
      if (mounted) setState(() => _decoding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 360,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) => ColoredBox(
                        color: Colors.black87,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Không mở được camera. Hãy cấp quyền camera cho trình duyệt hoặc chọn ảnh QR.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Đưa mã QR thanh toán vào giữa khung',
              textAlign: TextAlign.center,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Bật/tắt đèn flash',
                  onPressed: _toggleTorch,
                  icon: const Icon(Icons.flashlight_on_outlined),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: 'Đổi camera',
                  onPressed: _scannerController.switchCamera,
                  icon: const Icon(Icons.cameraswitch_outlined),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _decoding ? null : _chooseQrImage,
              icon: const Icon(Icons.image_search),
              label: _decoding
                  ? const Text('Đang đọc QR...')
                  : const Text('Chọn ảnh QR từ thư viện'),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Nhập mã thủ công'),
              tilePadding: EdgeInsets.zero,
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Mã thanh toán/session ID',
                    hintText: 'ps_... hoặc walletapp://pay?...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _openInvoice(_controller.text),
                    child: const Text('Xem hóa đơn'),
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

class AwsPaymentInvoiceScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String sessionId;

  const AwsPaymentInvoiceScreen({
    super.key,
    required this.apiClient,
    required this.sessionId,
  });

  @override
  State<AwsPaymentInvoiceScreen> createState() =>
      _AwsPaymentInvoiceScreenState();
}

class _AwsPaymentInvoiceScreenState extends State<AwsPaymentInvoiceScreen> {
  late final Future<Map<String, dynamic>> _invoice;
  bool _paying = false;

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)} ${two(date.day)}/${two(date.month)}/${date.year}';
  }

  @override
  void initState() {
    super.initState();
    _invoice = widget.apiClient.get('/payments/sessions/${widget.sessionId}');
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      await widget.apiClient.post(
        '/payments/sessions/${widget.sessionId}/confirm-transfer',
        idempotencyKey:
            'qr-${widget.sessionId}-${DateTime.now().microsecondsSinceEpoch}',
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PaymentResultScreen(success: true),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Thanh toán thất bại: $error')));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hóa đơn AWS')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _invoice,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Không tải được hóa đơn: ${snapshot.error}'),
            );
          }
          final invoice = snapshot.data!['data'] as Map<String, dynamic>;
          final items = (invoice['items'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          final status = invoice['status'] as String? ?? 'UNKNOWN';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                invoice['storeName'] as String? ?? 'Cửa hàng',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(invoice['storeAddress'] as String? ?? ''),
              Text(_formatDate(invoice['createdAt'])),
              const Divider(height: 28),
              ...items.map(
                (item) => ListTile(
                  title: Text(item['name'] as String),
                  subtitle: Text('${item['qty']} × ${item['price']} VND'),
                ),
              ),
              const Divider(),
              Text(
                'Tổng tiền: ${invoice['amount']} VND',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Trạng thái: $status'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _paying ? null : () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: status == 'WAITING' && !_paying ? _pay : null,
                      icon: const Icon(Icons.payment),
                      label: _paying
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Chuyển tiền'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class PaymentInvoiceScreen extends StatelessWidget {
  final String storeName;
  final String storeAddress;
  final List<String> items;
  final String total;

  const PaymentInvoiceScreen({
    super.key,
    required this.storeName,
    required this.storeAddress,
    required this.items,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hóa đơn thanh toán')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(storeName, style: Theme.of(context).textTheme.titleLarge),
            Text(storeAddress),
            const SizedBox(height: 12),
            const Text('Danh sách món:'),
            ...items.map((e) => Text('- $e')),
            const SizedBox(height: 12),
            Text(
              'Tổng tiền: $total',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            FilledButton(
              key: const Key('confirm_invoice_transfer'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentResultScreen(success: true),
                  ),
                );
              },
              child: const Text('Chuyển tiền'),
            ),
            TextButton(
              key: const Key('fail_invoice_transfer'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentResultScreen(success: false),
                  ),
                );
              },
              child: const Text('Giả lập lỗi thanh toán'),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentResultScreen extends StatelessWidget {
  final bool success;
  const PaymentResultScreen({super.key, required this.success});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả thanh toán')),
      body: Center(
        child: Text(
          success ? 'Thanh toán thành công' : 'Thanh toán thất bại',
          key: Key(success ? 'payment_success_text' : 'payment_failed_text'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
