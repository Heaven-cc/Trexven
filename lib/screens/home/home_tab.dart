import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/quick_action.dart';
import '../inventory/add_product_screen.dart';
import '../finance/record_sale_screen.dart';

class HomeTab extends StatefulWidget {
  final String ownerName;
  final String businessName;
  final VoidCallback? onOpenCameras;

  const HomeTab({
    super.key,
    required this.ownerName,
    required this.businessName,
    this.onOpenCameras,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  Map<String, dynamic> _stats = {
    'sales': 0.0,
    'transactions': 0,
    'stockValue': 0.0,
    'lowStock': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _db.getTodayStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color dark = Color(0xFF0F172A);
    const Color blue = Color(0xFF2563EB);
    const Color muted = Color(0xFF64748B);

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: const TextStyle(fontSize: 14, color: muted),
            ),
            const SizedBox(height: 4),
            Text(
              widget.ownerName,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: dark,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.businessName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: blue,
              ),
            ),
            const SizedBox(height: 25),
            _sectionTitle('Today'),
            const SizedBox(height: 14),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Sales',
                          value: '₦${_stats['sales']}',
                          icon: Icons.trending_up_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Transactions',
                          value: '${_stats['transactions']}',
                          icon: Icons.receipt_long_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          title: 'Stock Value',
                          value: '₦${_stats['stockValue']}',
                          icon: Icons.inventory_2_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          title: 'Low Stock',
                          value: '${_stats['lowStock']}',
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 28),
            _sectionTitle('Business Intelligence'),
            const SizedBox(height: 12),
            _aiStatusCard(),
            const SizedBox(height: 28),
            _sectionTitle('Quick Actions'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: QuickAction(
                    icon: Icons.add_box_outlined,
                    title: 'Add Product',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddProductScreen()),
                      );
                      _loadStats();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickAction(
                    icon: Icons.point_of_sale_outlined,
                    title: 'Record Sale',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecordSaleScreen()),
                      );
                      _loadStats();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: QuickAction(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Employee',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Employee management is coming soon.'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickAction(
                    icon: Icons.camera_alt_outlined,
                    title: 'Cameras',
                    onTap: widget.onOpenCameras,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _aiStatusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFF60A5FA),
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TREXVEN Intelligence',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'AI monitoring system ready',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
