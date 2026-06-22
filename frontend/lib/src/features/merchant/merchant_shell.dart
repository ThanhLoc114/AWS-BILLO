import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/files/image_picker.dart';
import '../../core/files/file_download.dart';
import '../../core/files/picked_image.dart';
import '../../core/files/upload_service.dart';
import '../../core/network/api_client.dart';

class MerchantShell extends StatefulWidget {
  final ApiClient? apiClient;
  final VoidCallback? onSignOut;

  const MerchantShell({super.key, this.apiClient, this.onSignOut});

  @override
  State<MerchantShell> createState() => _MerchantShellState();
}

class _MerchantShellState extends State<MerchantShell> {
  final List<_Product> _products = [
    _Product(name: 'Cà phê sữa', price: 30000),
    _Product(name: 'Bánh mì thịt', price: 25000),
    _Product(name: 'Nước cam', price: 20000),
  ];

  final Map<String, int> _cart = {};
  String _checkoutStatus = 'Chưa tạo phiên thanh toán';

  int get _totalAmount {
    int total = 0;
    for (final p in _products) {
      final qty = _cart[p.name] ?? 0;
      total += p.price * qty;
    }
    return total;
  }

  void _increase(_Product p) {
    setState(() {
      _cart[p.name] = (_cart[p.name] ?? 0) + 1;
    });
  }

  void _decrease(_Product p) {
    final qty = _cart[p.name] ?? 0;
    if (qty <= 0) return;
    setState(() {
      final newQty = qty - 1;
      if (newQty == 0) {
        _cart.remove(p.name);
      } else {
        _cart[p.name] = newQty;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.apiClient != null) {
      return _AwsMerchantShell(
        apiClient: widget.apiClient!,
        onSignOut: widget.onSignOut,
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chủ cửa tiệm'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chờ duyệt'),
              Tab(text: 'Dashboard'),
              Tab(text: 'POS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const Center(child: Text('Trạng thái: Đã được admin duyệt (mock)')),
            _MerchantDashboard(totalToday: 1250000, orderCount: 42),
            _MerchantPosTab(
              products: _products,
              cart: _cart,
              totalAmount: _totalAmount,
              checkoutStatus: _checkoutStatus,
              onIncrease: _increase,
              onDecrease: _decrease,
              onCreateOrderAndShowQr: () async {
                if (_totalAmount <= 0) return;
                final paid = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MerchantQrCheckoutScreen(totalAmount: _totalAmount),
                  ),
                );
                if (!mounted) return;
                setState(() {
                  _checkoutStatus = (paid ?? false)
                      ? 'Đã thanh toán thành công'
                      : 'Đang chờ thanh toán';
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MerchantDashboard extends StatelessWidget {
  final int totalToday;
  final int orderCount;

  const _MerchantDashboard({
    required this.totalToday,
    required this.orderCount,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: const Text('Doanh thu hôm nay'),
            subtitle: Text('${totalToday.toString()}đ'),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Số đơn hôm nay'),
            subtitle: Text(orderCount.toString()),
          ),
        ),
      ],
    );
  }
}

class _MerchantPosTab extends StatelessWidget {
  final List<_Product> products;
  final Map<String, int> cart;
  final int totalAmount;
  final String checkoutStatus;
  final void Function(_Product) onIncrease;
  final void Function(_Product) onDecrease;
  final VoidCallback onCreateOrderAndShowQr;

  const _MerchantPosTab({
    required this.products,
    required this.cart,
    required this.totalAmount,
    required this.checkoutStatus,
    required this.onIncrease,
    required this.onDecrease,
    required this.onCreateOrderAndShowQr,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('merchant_pos_list'),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Chọn sản phẩm',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...products.map((p) {
          final qty = cart[p.name] ?? 0;
          return Card(
            child: ListTile(
              title: Text(p.name),
              subtitle: Text('${p.price}đ'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('decrease_${p.name}'),
                    onPressed: () => onDecrease(p),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$qty', key: Key('qty_${p.name}')),
                  IconButton(
                    key: Key('increase_${p.name}'),
                    onPressed: () => onIncrease(p),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Text(
          'Tổng tiền: $totalAmountđ',
          key: const Key('merchant_total_amount'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('merchant_create_order_button'),
          onPressed: totalAmount > 0 ? onCreateOrderAndShowQr : null,
          child: const Text('Tạo order & Xuất QR'),
        ),
        const SizedBox(height: 8),
        Text(
          'Trạng thái checkout: $checkoutStatus',
          key: const Key('merchant_checkout_status'),
        ),
      ],
    );
  }
}

class MerchantQrCheckoutScreen extends StatefulWidget {
  final int totalAmount;
  const MerchantQrCheckoutScreen({super.key, required this.totalAmount});

  @override
  State<MerchantQrCheckoutScreen> createState() =>
      _MerchantQrCheckoutScreenState();
}

class _MerchantQrCheckoutScreenState extends State<MerchantQrCheckoutScreen> {
  String status = 'WAITING';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Session: SESSION_MOCK_001'),
            const SizedBox(height: 8),
            Text('Tổng tiền: ${widget.totalAmount}đ'),
            const SizedBox(height: 8),
            Text('Trạng thái: $status', key: const Key('merchant_qr_status')),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('merchant_mark_paid_button'),
              onPressed: () {
                setState(() => status = 'PAID');
              },
              child: const Text('Giả lập đã thanh toán'),
            ),
            TextButton(
              key: const Key('merchant_back_after_paid'),
              onPressed: () {
                Navigator.pop(context, status == 'PAID');
              },
              child: const Text('Quay lại POS'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Product {
  final String name;
  final int price;

  _Product({required this.name, required this.price});
}

class _AwsMerchantShell extends StatefulWidget {
  final ApiClient apiClient;
  final VoidCallback? onSignOut;

  const _AwsMerchantShell({required this.apiClient, this.onSignOut});

  @override
  State<_AwsMerchantShell> createState() => _AwsMerchantShellState();
}

class _AwsMerchantShellState extends State<_AwsMerchantShell> {
  late Future<List<Map<String, dynamic>>> _products;
  late Future<List<Map<String, dynamic>>> _orders;
  late Future<Map<String, dynamic>> _store;
  final Map<String, int> _awsCart = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _products = widget.apiClient
        .get('/merchant/products')
        .then(
          (response) => (response['data'] as List).cast<Map<String, dynamic>>(),
        );
    _orders = widget.apiClient
        .get('/merchant/orders')
        .then(
          (response) => (response['data'] as List).cast<Map<String, dynamic>>(),
        );
    _store = widget.apiClient.get('/merchant/store');
  }

  Future<void> _addProduct() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _AddServiceDialog(apiClient: widget.apiClient),
    );
    if (created == true && mounted) setState(_reload);
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _AddServiceDialog(apiClient: widget.apiClient, product: product),
    );
    if (updated == true && mounted) setState(_reload);
  }

  Future<void> _editStore(Map<String, dynamic> store) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _EditStoreDialog(apiClient: widget.apiClient, store: store),
    );
    if (updated == true && mounted) setState(_reload);
  }

  Future<void> _deleteProduct(String productId) async {
    await widget.apiClient.delete('/merchant/products/$productId');
    if (mounted) setState(_reload);
  }

  Future<void> _changeOrderStatus(
    Map<String, dynamic> order,
    String action,
  ) async {
    final isRefund = action == 'refund';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isRefund ? 'Xác nhận hoàn tiền' : 'Xác nhận hủy đơn'),
        content: Text(
          isRefund
              ? 'Số tiền ${order['totalAmount']} VND sẽ được trả lại khách hàng. Thao tác này không thể hoàn tác.'
              : 'Đơn ${order['orderId']} sẽ bị hủy và không thể thanh toán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isRefund ? 'Hoàn tiền' : 'Hủy đơn'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.apiClient.post(
        '/merchant/orders/${order['orderId']}/$action',
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isRefund ? 'Hoàn tiền thành công' : 'Đã hủy đơn'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isRefund ? 'Không thể hoàn tiền' : 'Không thể hủy đơn'}: $error',
            ),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _selectedItems(
    List<Map<String, dynamic>> products,
  ) => products
      .where((product) => (_awsCart[product['productId']] ?? 0) > 0)
      .map(
        (product) => {
          'productId': product['productId'],
          'qty': _awsCart[product['productId']],
        },
      )
      .toList();

  Future<Map<String, dynamic>> _createOrder(
    List<Map<String, dynamic>> products,
  ) async {
    final response = await widget.apiClient.post(
      '/merchant/orders',
      body: {'items': _selectedItems(products)},
    );
    return response['data'] as Map<String, dynamic>;
  }

  Future<void> _startQrCheckout(List<Map<String, dynamic>> products) async {
    if (_selectedItems(products).isEmpty) return;
    try {
      final order = await _createOrder(products);
      final checkoutResponse = await widget.apiClient.post(
        '/merchant/orders/${order['orderId']}/checkout-qr',
      );
      final checkout = checkoutResponse['data'] as Map<String, dynamic>;
      if (!mounted) return;
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MerchantLiveQrScreen(
            apiClient: widget.apiClient,
            sessionId: checkout['sessionId'] as String,
            qrPayload: checkout['qrPayload'] as String,
            totalAmount: (order['totalAmount'] as num).toInt(),
          ),
        ),
      );
      if (mounted) {
        setState(() {
          if (paid == true) _awsCart.clear();
          _reload();
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tạo QR thanh toán: $error')),
        );
      }
    }
  }

  Future<void> _checkoutCash(List<Map<String, dynamic>> products) async {
    try {
      final order = await _createOrder(products);
      await widget.apiClient.post(
        '/merchant/orders/${order['orderId']}/checkout-cash',
      );
      if (!mounted) return;
      setState(() {
        _awsCart.clear();
        _reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã hoàn tất thanh toán tiền mặt')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể thanh toán tiền mặt: $error')),
        );
      }
    }
  }

  Future<void> _showOrderSummary(
    List<Map<String, dynamic>> products,
    int total,
  ) async {
    final selected = products
        .where((product) => (_awsCart[product['productId']] ?? 0) > 0)
        .toList();
    final method = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tóm tắt đơn hàng',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...selected.map(
                (product) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(product['name'] as String),
                  subtitle: Text(
                    '${_awsCart[product['productId']]} × ${product['price']} VND',
                  ),
                ),
              ),
              const Divider(),
              Text(
                'Tổng tiền: $total VND',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'CASH'),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Hoàn tất bằng tiền mặt'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, 'QR'),
                icon: const Icon(Icons.qr_code),
                label: const Text('Xuất QR chuyển khoản'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (method == 'CASH') await _checkoutCash(products);
    if (method == 'QR') await _startQrCheckout(products);
  }

  Widget _buildAwsPos() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _products,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Không tải được POS: ${snapshot.error}'));
        }
        final products = snapshot.data ?? [];
        final total = products.fold<int>(0, (sum, product) {
          final qty = _awsCart[product['productId']] ?? 0;
          return sum + (product['price'] as num).toInt() * qty;
        });
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Chọn dịch vụ', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...products.map((product) {
              final id = product['productId'] as String;
              final qty = _awsCart[id] ?? 0;
              return Card(
                child: ListTile(
                  title: Text(product['name'] as String),
                  subtitle: Text('${product['price']} VND'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: qty == 0
                            ? null
                            : () => setState(() {
                                if (qty == 1) {
                                  _awsCart.remove(id);
                                } else {
                                  _awsCart[id] = qty - 1;
                                }
                              }),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$qty'),
                      IconButton(
                        onPressed: () => setState(() => _awsCart[id] = qty + 1),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Text('Tổng tiền: $total VND'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: total == 0
                  ? null
                  : () => _showOrderSummary(products, total),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Tiếp tục'),
            ),
          ],
        );
      },
    );
  }

  String _orderStatus(String? status) => switch (status) {
    'PAID' => 'Đã thanh toán',
    'WAITING_PAYMENT' => 'Chờ thanh toán',
    'CANCELLED' => 'Đã hủy',
    'EXPIRED' => 'Đã hết hạn',
    'REFUNDED' => 'Đã hoàn tiền',
    _ => status ?? 'Không xác định',
  };

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.hour)}:${two(date.minute)} ${two(date.day)}/${two(date.month)}/${date.year}';
  }

  Widget _buildOrders() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _orders,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Không tải được đơn hàng: ${snapshot.error}'),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => setState(_reload),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        final orders = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await _orders;
          },
          child: orders.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 180),
                    Icon(Icons.receipt_long_outlined, size: 64),
                    SizedBox(height: 12),
                    Center(child: Text('Chưa có đơn hàng')),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final status = order['status'] as String?;
                    final paid = status == 'PAID';
                    final refunded = status == 'REFUNDED';
                    final waiting = status == 'WAITING_PAYMENT';
                    final items = (order['items'] as List? ?? const [])
                        .cast<Map<String, dynamic>>();
                    return Card(
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: paid
                              ? Colors.green.shade100
                              : refunded
                              ? Colors.purple.shade100
                              : Colors.orange.shade100,
                          child: Icon(
                            paid
                                ? Icons.check
                                : refunded
                                ? Icons.replay
                                : waiting
                                ? Icons.schedule
                                : Icons.block,
                            color: paid
                                ? Colors.green
                                : refunded
                                ? Colors.purple
                                : Colors.orange,
                          ),
                        ),
                        title: Text('${order['totalAmount'] ?? 0} VND'),
                        subtitle: Text(
                          '${_orderStatus(status)} • ${_formatDate(order['createdAt'])}',
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          ...items.map(
                            (item) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(item['name'] as String? ?? 'Dịch vụ'),
                              subtitle: Text(
                                '${item['qty'] ?? 1} × ${item['price'] ?? 0} VND',
                              ),
                            ),
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Thanh toán: ${order['paymentMethod'] ?? 'Chưa có'}',
                              ),
                              SelectableText(order['orderId'] as String? ?? ''),
                            ],
                          ),
                          if (waiting)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _changeOrderStatus(order, 'cancel'),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Hủy đơn'),
                              ),
                            ),
                          if (paid)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _changeOrderStatus(order, 'refund'),
                                icon: const Icon(Icons.replay),
                                label: const Text('Hoàn tiền'),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildOverview() {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([_store, _orders]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Không tải được tổng quan: ${snapshot.error}'),
          );
        }
        final storeResponse = snapshot.data![0] as Map<String, dynamic>;
        final store = storeResponse['data'] as Map<String, dynamic>;
        final orders = snapshot.data![1] as List<Map<String, dynamic>>;
        final now = DateTime.now();
        bool isToday(Map<String, dynamic> order) {
          final date = DateTime.tryParse(
            order['paidAt']?.toString() ?? order['createdAt']?.toString() ?? '',
          )?.toLocal();
          return date != null &&
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        }

        final paidToday = orders
            .where((order) => order['status'] == 'PAID' && isToday(order))
            .toList();
        final revenueToday = paidToday.fold<int>(
          0,
          (sum, order) => sum + (order['totalAmount'] as num? ?? 0).toInt(),
        );
        final waiting = orders
            .where((order) => order['status'] == 'WAITING_PAYMENT')
            .length;

        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await Future.wait<dynamic>([_store, _orders]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundImage: store['imageUrl'] == null
                      ? null
                      : NetworkImage(store['imageUrl'] as String),
                  child: store['imageUrl'] == null
                      ? const Icon(Icons.storefront, size: 46)
                      : null,
                ),
              ),
              Text(
                store['storeName'] as String? ?? 'Cửa hàng',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                store['address'] as String? ?? '',
                textAlign: TextAlign.center,
              ),
              Text(
                store['phone'] as String? ?? '',
                textAlign: TextAlign.center,
              ),
              Center(
                child: TextButton.icon(
                  onPressed: () => _editStore(store),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Chỉnh sửa thông tin quán'),
                ),
              ),
              const SizedBox(height: 20),
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 3 : 1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 3.2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _MerchantMetricCard(
                    icon: Icons.payments_outlined,
                    label: 'Doanh thu hôm nay',
                    value: '$revenueToday VND',
                    color: Colors.green,
                  ),
                  _MerchantMetricCard(
                    icon: Icons.receipt_long_outlined,
                    label: 'Đơn đã thanh toán',
                    value: '${paidToday.length}',
                    color: Colors.blue,
                  ),
                  _MerchantMetricCard(
                    icon: Icons.schedule,
                    label: 'Đơn đang chờ',
                    value: '$waiting',
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.verified, color: Colors.green),
                  title: Text('Đã được admin phê duyệt'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Không gian kinh doanh'),
          actions: [
            IconButton(
              tooltip: 'Làm mới dữ liệu',
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh),
            ),
            if (widget.onSignOut != null)
              IconButton(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tổng quan'),
              Tab(text: 'Dịch vụ'),
              Tab(text: 'POS'),
              Tab(text: 'Đơn hàng'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverview(),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _products,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Không tải được dịch vụ: ${snapshot.error}'),
                  );
                }
                final products = snapshot.data ?? [];
                return Stack(
                  children: [
                    if (products.isEmpty)
                      const Center(child: Text('Chưa có dịch vụ kinh doanh'))
                    else
                      ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final imageUrl = product['imageUrl'] as String?;
                          return Card(
                            child: ListTile(
                              leading: SizedBox.square(
                                dimension: 64,
                                child: imageUrl == null
                                    ? const Icon(Icons.image_outlined)
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                              ),
                              title: Text(product['name'] as String),
                              subtitle: Text(
                                '${product['description'] ?? ''}\n${product['price']} VND',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _editProduct(product);
                                  if (value == 'delete') {
                                    _deleteProduct(
                                      product['productId'] as String,
                                    );
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Chỉnh sửa'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete_outline),
                                      title: Text('Xóa'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    Positioned(
                      right: 20,
                      bottom: 20,
                      child: FloatingActionButton.extended(
                        onPressed: _addProduct,
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm dịch vụ'),
                      ),
                    ),
                  ],
                );
              },
            ),
            _buildAwsPos(),
            _buildOrders(),
          ],
        ),
      ),
    );
  }
}

class _MerchantMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MerchantMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        subtitle: Text(value, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

class MerchantLiveQrScreen extends StatefulWidget {
  final ApiClient apiClient;
  final String sessionId;
  final String qrPayload;
  final int totalAmount;

  const MerchantLiveQrScreen({
    super.key,
    required this.apiClient,
    required this.sessionId,
    required this.qrPayload,
    required this.totalAmount,
  });

  @override
  State<MerchantLiveQrScreen> createState() => _MerchantLiveQrScreenState();
}

class _MerchantLiveQrScreenState extends State<MerchantLiveQrScreen> {
  Timer? _timer;
  String _status = 'WAITING';

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final response = await widget.apiClient.get(
        '/payments/sessions/${widget.sessionId}',
      );
      final status =
          (response['data'] as Map<String, dynamic>)['status'] as String;
      if (!mounted) return;
      setState(() => _status = status);
      if (status != 'WAITING') _timer?.cancel();
    } catch (_) {
      // A later poll can recover from a transient network error.
    }
  }

  Future<void> _downloadQr() async {
    try {
      const imageSize = 1024;
      const quietZone = 64.0;
      const qrSize = imageSize - quietZone * 2;
      final painter = QrPainter(
        data: widget.qrPayload,
        version: QrVersions.auto,
        gapless: true,
      );
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, imageSize.toDouble(), imageSize.toDouble()),
        ui.Paint()..color = Colors.white,
      );
      canvas.save();
      canvas.translate(quietZone, quietZone);
      painter.paint(canvas, const ui.Size(qrSize, qrSize));
      canvas.restore();
      final picture = recorder.endRecording();
      final qrImage = await picture.toImage(imageSize, imageSize);
      final data = await qrImage.toByteData(format: ui.ImageByteFormat.png);
      picture.dispose();
      qrImage.dispose();
      if (data == null) throw StateError('Không tạo được ảnh QR');
      await downloadFile(
        bytes: data.buffer.asUint8List(),
        fileName: 'wallet-payment-${widget.sessionId}.png',
        contentType: 'image/png',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tải ảnh QR thanh toán')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể tải QR: $error')));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR thanh toán')),
      body: Center(
        child: ListView(
          padding: const EdgeInsets.all(24),
          shrinkWrap: true,
          children: [
            Center(child: QrImageView(data: widget.qrPayload, size: 260)),
            const SizedBox(height: 12),
            SelectableText(
              'Mã thanh toán: ${widget.sessionId}',
              textAlign: TextAlign.center,
            ),
            OutlinedButton.icon(
              onPressed: _downloadQr,
              icon: const Icon(Icons.download),
              label: const Text('Tải ảnh QR'),
            ),
            Text(
              '${widget.totalAmount} VND',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              'Trạng thái: $_status',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _status == 'PAID' ? Colors.green : Colors.orange,
              ),
            ),
            if (_status == 'PAID')
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hoàn tất'),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditStoreDialog extends StatefulWidget {
  final ApiClient apiClient;
  final Map<String, dynamic> store;

  const _EditStoreDialog({required this.apiClient, required this.store});

  @override
  State<_EditStoreDialog> createState() => _EditStoreDialogState();
}

class _EditStoreDialogState extends State<_EditStoreDialog> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  PickedImage? _image;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.store['storeName'] as String?);
    _address = TextEditingController(text: widget.store['address'] as String?);
    _phone = TextEditingController(text: widget.store['phone'] as String?);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _address.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      var imageKey = widget.store['imageS3Key'] as String?;
      if (_image != null) {
        imageKey = await UploadService(
          widget.apiClient,
        ).uploadImage(_image!, 'AVATAR');
      }
      await widget.apiClient.patch(
        '/merchant/store',
        body: {
          'storeName': _name.text.trim(),
          'address': _address.text.trim(),
          'phone': _phone.text.trim(),
          'imageS3Key': imageKey,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật quán: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thông tin quán'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tên quán'),
              ),
              TextField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
              ),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại liên hệ',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        final image = await pickImage();
                        if (image != null && mounted) {
                          setState(() => _image = image);
                        }
                      },
                icon: const Icon(Icons.image_outlined),
                label: Text(_image?.name ?? 'Chọn ảnh đại diện quán'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}

class _AddServiceDialog extends StatefulWidget {
  final ApiClient apiClient;
  final Map<String, dynamic>? product;

  const _AddServiceDialog({required this.apiClient, this.product});

  @override
  State<_AddServiceDialog> createState() => _AddServiceDialogState();
}

class _AddServiceDialogState extends State<_AddServiceDialog> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _description;
  PickedImage? _image;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product?['name'] as String?);
    _price = TextEditingController(text: widget.product?['price']?.toString());
    _description = TextEditingController(
      text: widget.product?['description'] as String?,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = int.tryParse(_price.text.trim());
    if (_name.text.trim().isEmpty || price == null || price <= 0) return;
    setState(() => _loading = true);
    try {
      var imageKey = widget.product?['imageS3Key'] as String?;
      if (_image != null) {
        imageKey = await UploadService(
          widget.apiClient,
        ).uploadImage(_image!, 'PRODUCT_IMAGE');
      }
      final body = {
        'name': _name.text.trim(),
        'price': price,
        'description': _description.text.trim(),
        'imageS3Key': imageKey,
      };
      if (widget.product == null) {
        await widget.apiClient.post('/merchant/products', body: body);
      } else {
        await widget.apiClient.patch(
          '/merchant/products/${widget.product!['productId']}',
          body: body,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể lưu dịch vụ: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.product == null
            ? 'Thêm dịch vụ kinh doanh'
            : 'Chỉnh sửa dịch vụ',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tên dịch vụ'),
              ),
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá tiền'),
              ),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        final image = await pickImage();
                        if (image != null && mounted) {
                          setState(() => _image = image);
                        }
                      },
                icon: const Icon(Icons.image),
                label: Text(_image?.name ?? 'Chọn hình ảnh'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Lưu dịch vụ'),
        ),
      ],
    );
  }
}
