import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/business_reporting.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  final BusinessPeriod? period;
  const ExpenseHistoryScreen({super.key, this.period});
  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _rows;
  final _database = DatabaseService();
  BusinessPeriod? _period;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _rows = (() async {
      _period =
          widget.period ??
          BusinessPeriod.fromDay(await _database.getBusinessDay(), 'today');
      return _database.getExpenses(_period!);
    })().timeout(const Duration(seconds: 20));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Expense history')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: TextButton(
              onPressed: () => setState(_load),
              child: const Text('Unable to load expenses. Retry'),
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Expense entry is unavailable until a safe, idempotent write contract is approved.',
            ),
            const SizedBox(height: 16),
            if (snapshot.data!.isEmpty)
              const Text('No expenses in this period.'),
            for (final row in snapshot.data!)
              ListTile(
                title: Text(row['category']?.toString() ?? 'Expense'),
                subtitle: Text(
                  '${row['description'] ?? ''}\n'
                  '${DateFormat('d MMM, h:mm a').format(_period!.local(DateTime.parse(row['created_at'] as String)))} · ${row['payment_method'] ?? ''}',
                ),
                trailing: Text(
                  NumberFormat.currency(
                    locale: 'en_NG',
                    symbol: '₦',
                    decimalDigits: 2,
                  ).format(financialNumber(row['amount'])),
                ),
              ),
          ],
        );
      },
    ),
  );
}
