import '../../core/app_sizing.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/database_service.dart';
import '../../models/sale.dart';
import 'record_sale_screen.dart';
import 'operational_finance_screen.dart';

class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key, this.database});
  final DatabaseService? database;
  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  late final DatabaseService _db;
  late Future<List<Sale>> _sales;
  late Future<Map<String, dynamic>> _stats;
  Future<void>? _refreshing;

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? DatabaseService();
    _loadData();
  }

  void _loadData() {
    _sales = _db
        .getSalesWithProductNames(limit: 50)
        .timeout(const Duration(seconds: 20));
    _stats = _db.getTodayStats().timeout(const Duration(seconds: 20));
  }

  Future<void> _refresh() {
    if (_refreshing != null) return _refreshing!;
    setState(_loadData);
    // FutureBuilders display the individual failures; refresh still finishes.
    return _refreshing = Future.wait<Object>([_sales, _stats])
        .then<void>((_) {}, onError: (Object _, StackTrace __) {})
        .whenComplete(() => _refreshing = null);
  }

  Widget _retry(String message) => Column(
    children: [
      Text(message),
      TextButton(onPressed: _refresh, child: const Text('Retry')),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: AppSizing.pagePadding,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finance',
                      style: TextStyle(
                        fontSize: AppSizing.pageTitle,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Understand your business finances.',
                      style: TextStyle(color: muted, fontSize: 14),
                    ),
                    const SizedBox(height: AppSizing.sectionGap),
                    OutlinedButton.icon(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const OperationalFinanceScreen())),icon:const Icon(Icons.receipt_long),label:const Text('Credit, repayments and returns')),
                    _liveRevenueHero(context),
                    const SizedBox(height: 20),
                    Text(
                      'Recent Transactions',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: FutureBuilder<List<Sale>>(
                // `sales` has no product-name column of its own, so this
                // resolves each sale's product name via a one-shot products
                // lookup rather than the raw table stream.
                future: _sales,
                builder: (context, snapshot) {
                  if (!snapshot.hasData &&
                      snapshot.connectionState == ConnectionState.waiting) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError)
                    return SliverToBoxAdapter(
                      child: _retry(
                        'Unable to load transactions. Please retry.',
                      ),
                    );
                  final sales = snapshot.data ?? [];
                  if (sales.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          'No transactions recorded yet',
                          style: TextStyle(color: muted),
                        ),
                      ),
                    );
                  }
                  return SliverList.builder(
                    itemCount: sales.length,
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          sale.productName.isEmpty
                              ? 'Product'
                              : sale.productName,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Qty: ${sale.quantity}',
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                        trailing: Text(
                          '₦${sale.totalPrice}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecordSaleScreen()),
          );
          if (mounted) await _refresh();
        },
        label: const Text('Record Sale', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _liveRevenueHero(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, dynamic>>(
      future: _stats,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _retry('Unable to load revenue. Please retry.');
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final revenue = snapshot.data?['sales'] ?? 0.0;
        return Container(
          width: double.infinity,
          padding: AppSizing.cardPadding,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surface
                : theme.trexvenColors.brandDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Revenue",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '₦$revenue',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
