import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../data/repositories/customer_repository.dart';

class RecentTransactionsScreen extends StatefulWidget {
  final CustomerRepository repository;

  const RecentTransactionsScreen({super.key, required this.repository});

  @override
  State<RecentTransactionsScreen> createState() =>
      _RecentTransactionsScreenState();
}

class _RecentTransactionsScreenState extends State<RecentTransactionsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getRecentTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử gần đây (Mock API)')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final error = snapshot.error;
            if (error is ApiException) {
              return Center(child: Text('Lỗi: ${error.message}'));
            }
            return const Center(child: Text('Lỗi không xác định'));
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Chưa có giao dịch nào'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text(item.title.toString()),
                  trailing: Text(item.amount.toString()),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
