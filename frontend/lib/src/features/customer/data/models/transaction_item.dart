class TransactionItem {
  final String title;
  final String amount;
  final String type;

  const TransactionItem({
    required this.title,
    required this.amount,
    required this.type,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      title: json['title'] as String? ?? '',
      amount: json['amount'] as String? ?? '0',
      type: json['type'] as String? ?? 'unknown',
    );
  }
}
