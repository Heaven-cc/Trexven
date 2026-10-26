import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/business_reporting.dart';
import '../../services/database_service.dart';

Widget financialTransactionTile(
  Map<String, dynamic> row,
  BusinessPeriod period,
) {
  final items = (row['sale_items'] as List? ?? []).cast<Map>();
  final date = DateTime.parse((row['sold_at'] ?? row['created_at']) as String);
  final money = NumberFormat.currency(
    locale: 'en_NG',
    symbol: '₦',
    decimalDigits: 2,
  );
  final summary = items.isEmpty
      ? 'Sale'
      : items.map((e) => e['product_name'] ?? 'Product').join(', ');
  return ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFF2864F0)),
    title: Text(
      summary,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      '${DateFormat('d MMM, h:mm a').format(period.local(date))} · '
      '${row['payment_kind'] ?? row['payment_method'] ?? ''} · ${row['status'] ?? ''}',
      style: const TextStyle(fontSize: 11),
    ),
    trailing: Text(
      money.format(financialNumber(row['total'])),
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
    ),
    children: [
      for (final item in items)
        ListTile(
          dense: true,
          title: Text(item['product_name']?.toString() ?? 'Product'),
          subtitle: Text(
            'Qty ${item['quantity']} × ${money.format(financialNumber(item['unit_price']))}',
          ),
        ),
    ],
  );
}

class TransactionHistoryScreen extends StatefulWidget {
  final DatabaseService database;
  final BusinessPeriod period;
  const TransactionHistoryScreen({
    super.key,
    required this.database,
    required this.period,
  });
  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  final List<Map<String, dynamic>> _rows = [];
  bool _busy = false, _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy || !_more) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await widget.database
          .getFinancialSales(widget.period, offset: _rows.length)
          .timeout(const Duration(seconds: 20));
      if (mounted)
        setState(() {
          _rows.addAll(rows);
          _more = rows.length == 100;
        });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load transactions.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Transactions')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final row in _rows) financialTransactionTile(row, widget.period),
        if (_rows.isEmpty && !_busy && _error == null)
          const Text('No transactions in this period.'),
        if (_error != null) Text(_error!),
        if (_busy) const Center(child: Text('Please wait…')),
        if (_more && !_busy)
          TextButton(
            onPressed: _load,
            child: Text(_error == null ? 'Load more' : 'Retry'),
          ),
      ],
    ),
  );
}
