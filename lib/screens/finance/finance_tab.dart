import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/sale.dart';
import 'record_sale_screen.dart';

class FinanceTab extends StatelessWidget {
  FinanceTab({super.key});

  final DatabaseService _db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    const Color dark = Color(0xFF0F172A);
    const Color muted = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Finance',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: dark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Understand your business finances.',
              style: TextStyle(color: muted, fontSize: 14),
            ),
            const SizedBox(height: 22),
            _liveRevenueHero(),
            const SizedBox(height: 30),
            const Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Sale>>(
              // `sales` has no product-name column of its own, so this
              // resolves each sale's product name via a one-shot products
              // lookup rather than the raw table stream.
              future: _db.getSalesWithProductNames(limit: 50),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sales = snapshot.data ?? [];
                if (sales.isEmpty) {
                  return const Center(child: Text('No transactions recorded yet'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sales.length,
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        sale.productName.isEmpty ? 'Product' : sale.productName,
                      ),
                      subtitle: Text('Qty: ${sale.quantity}'),
                      trailing: Text('₦${sale.totalPrice}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecordSaleScreen()),
          );
        },
        label: const Text('Record Sale', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }

  Widget _liveRevenueHero() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _db.getTodayStats(),
      builder: (context, snapshot) {
        final revenue = snapshot.data?['sales'] ?? 0.0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Today's Revenue", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                '₦$revenue',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        );
      },
    );
  }
}
