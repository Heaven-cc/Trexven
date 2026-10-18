import 'package:flutter/material.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/app_sizing.dart';
import '../../core/user_provider.dart';
import '../../services/database_service.dart';
import '../../widgets/trexven_widgets.dart';
import '../../models/sale.dart';
import '../../models/product.dart';
import '../inventory/add_product_screen.dart';
import '../finance/record_sale_screen.dart';
import '../me/employment_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String ownerName;
  final String businessName;
  final VoidCallback? onOpenCameras;

  const DashboardScreen({
    super.key,
    required this.ownerName,
    required this.businessName,
    this.onOpenCameras,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _db = DatabaseService();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₦',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  String? _errorMessage;

  int? _expandedIndex;

  Map<String, dynamic> _stats = {
    'sales': {
      'totalToday': 0.0,
      'countToday': 0,
      'avgToday': 0.0,
      'totalYesterday': 0.0,
      'countYesterday': 0,
      'recent': <Sale>[],
      'hourly': List.filled(24, 0.0),
    },
    'transactions': {
      'successful': 0,
      'pending': 0,
      'failed': 0,
      'totalValue': 0.0,
      'recent': <Sale>[],
    },
    'inventory': {
      'totalValue': 0.0,
      'totalUnits': 0,
      'productCount': 0,
      'addedToday': 0,
      'topProducts': <Product>[],
    },
    'lowStock': {
      'critical': <Product>[],
      'warning': <Product>[],
      'totalCount': 0,
    },
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // ============================================================
  // LOAD DASHBOARD DATA
  // ============================================================

  Future<void> _loadStats() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final stats = await _db.getDetailedDashboardStats();

      if (!mounted) return;

      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load dashboard data.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading stats: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // GREETING
  // ============================================================

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning';
    }

    if (hour < 17) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }

  // ============================================================
  // EXPAND KPI
  // ============================================================

  void _toggleExpand(int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else {
        _expandedIndex = index;
      }
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: theme.colorScheme.primary,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      color: theme.colorScheme.primary,
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: AppSizing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: AppSizing.sectionGap),

            _buildSalesCard(),

            const SizedBox(height: AppSizing.sectionGap),

            _buildSectionTitle('Today'),

            const SizedBox(height: 12),

            _buildKpiSection(),

            const SizedBox(height: AppSizing.sectionGap),

            _buildIntelligenceCard(),

            const SizedBox(height: 20),

            _buildSectionTitle('Quick Actions'),

            const SizedBox(height: 12),

            _buildQuickActions(),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final errorColor = theme.trexvenColors.error ?? Colors.red;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.cloud_off_rounded, color: errorColor, size: 28),
            ),

            const SizedBox(height: 16),

            Text(
              'Dashboard unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'We could not load your business data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: theme.trexvenColors.muted),
            ),

            const SizedBox(height: 18),

            ElevatedButton(
              onPressed: _loadStats,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Try again',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final userProvider = context.watch<UserProvider>();

    final firstName = userProvider.ownerName.trim().isEmpty
        ? 'there'
        : userProvider.ownerName.trim().split(' ').first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.trexvenColors.muted,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppSizing.pageTitle,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                userProvider.businessName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SALES CARD
  // ============================================================

  Widget _buildSalesCard() {
    final theme = Theme.of(context);
    final today = _stats['sales']['totalToday'] ?? 0.0;
    final yesterday = _stats['sales']['totalYesterday'] ?? 0.0;
    final transactionCount = _stats['sales']['countToday'] ?? 0;

    return Container(
      key: const ValueKey('dashboard-sales-hero'),
      width: double.infinity,
      padding: AppSizing.cardPadding,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : theme.trexvenColors.brandDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: theme.colorScheme.primaryContainer.withOpacity(0.8),
                  size: 21,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales today',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Current business performance',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.trexvenColors.success?.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 7,
                      color: theme.trexvenColors.success,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: theme.trexvenColors.success?.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            _currencyFormat.format(today),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            '$transactionCount ${transactionCount == 1 ? 'transaction' : 'transactions'} today',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 12),

          Container(height: 1, color: Colors.white.withOpacity(0.07)),

          const SizedBox(height: 10),

          Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 16,
                color: Colors.white.withOpacity(0.3),
              ),

              const SizedBox(width: 7),

              Flexible(
                child: Text(
                  'Yesterday',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  _currencyFormat.format(yesterday),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // ============================================================
  // KPI SECTION
  // ============================================================

  Widget _buildKpiSection() {
    if (_expandedIndex != null) {
      return _buildDetailedCard(
        _expandedIndex!,
        _getCardData()[_expandedIndex!],
      );
    }

    final metrics = [
      (
        'Transactions',
        '${_stats['transactions']['successful']}',
        Icons.receipt_long_rounded,
      ),
      (
        'Stock value',
        _currencyFormat.format(_stats['inventory']['totalValue']),
        Icons.inventory_2_outlined,
      ),
      (
        'Low stock',
        '${_stats['lowStock']['totalCount']}',
        Icons.warning_amber_rounded,
      ),
      (
        'Products',
        '${_stats['inventory']['productCount']}',
        Icons.widgets_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit the actual text rather than impose an unapproved fixed card height
        // or numeric viewport breakpoint. Large text naturally chooses one column.
        var requiredWidth = 0.0;
        for (final metric in metrics) {
          final painter = TextPainter(
            text: TextSpan(
              text: metric.$2,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final width = painter.width + 36 + 12 + 30;
          if (width > requiredWidth) requiredWidth = width;
          painter.dispose();
        }
        final columns = (constraints.maxWidth - 12) / 2 >= requiredWidth
            ? 2
            : 1;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < metrics.length; i++)
              SizedBox(
                width: width,
                child: _miniKPICard(
                  i,
                  metrics[i].$1,
                  metrics[i].$2,
                  metrics[i].$3,
                  isAlert: i == 2,
                ),
              ),
          ],
        );
      },
    );
  }

  // ============================================================
  // KPI CARD
  // ============================================================

  Widget _miniKPICard(
    int index,
    String title,
    String value,
    IconData icon, {
    bool isAlert = false,
  }) {
    final theme = Theme.of(context);
    final color = isAlert
        ? theme.trexvenColors.error ?? Colors.red
        : theme.trexvenColors.brandBlue ?? Colors.blue;
    return TrexvenPressable(
      onTap: () => _toggleExpand(index),
      child: Container(
        key: ValueKey('dashboard-kpi-$index'),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: theme.trexvenColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        child: MetricContent(
          title: title,
          value: value,
          icon: icon,
          color: color,
          valueStyle: TextStyle(
            fontSize: 21,
            height: 1,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.trexvenColors.muted,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // KPI DATA
  // ============================================================

  List<Map<String, dynamic>> _getCardData() {
    return [
      {
        'title': 'Transactions',
        'value': '${_stats['transactions']['successful']}',
        'icon': Icons.receipt_long_rounded,
      },
      {
        'title': 'Stock value',
        'value': _currencyFormat.format(_stats['inventory']['totalValue']),
        'icon': Icons.inventory_2_outlined,
      },
      {
        'title': 'Low stock',
        'value': '${_stats['lowStock']['totalCount']}',
        'icon': Icons.warning_amber_rounded,
      },
      {
        'title': 'Products',
        'value': '${_stats['inventory']['productCount']}',
        'icon': Icons.widgets_outlined,
      },
    ];
  }

  // ============================================================
  // INTELLIGENCE
  // ============================================================

  Widget _buildIntelligenceCard() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : theme.trexvenColors.brandDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: theme.colorScheme.primaryContainer.withOpacity(0.9),
              size: 21,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TREXVEN Intelligence',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'AI monitoring system ready',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: theme.trexvenColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:
                      theme.trexvenColors.success?.withOpacity(0.45) ??
                      Colors.green,
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _quickAction(
                icon: Icons.add_box_outlined,
                title: 'Add Product',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddProductScreen()),
                  ).then((_) => _loadStats());
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _quickAction(
                icon: Icons.point_of_sale_rounded,
                title: 'Record Sale',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RecordSaleScreen()),
                  ).then((_) => _loadStats());
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _quickAction(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Add Employee',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmploymentScreen()),
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _quickAction(
                icon: Icons.camera_alt_outlined,
                title: 'Cameras',
                onTap: widget.onOpenCameras,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // QUICK ACTION CARD
  // ============================================================

  Widget _quickAction({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return TrexvenPressable(
      onTap: onTap,
      child: Container(
        key: ValueKey('dashboard-action-$title'),
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.trexvenColors.cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),

            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: theme.trexvenColors.muted?.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETAILED CARD
  // ============================================================

  Widget _buildDetailedCard(int index, Map<String, dynamic> data) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.2 : 0.03,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  data['icon'],
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.trexvenColors.muted,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      data['value'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () => _toggleExpand(index),
                splashRadius: 20,
                icon: Icon(
                  Icons.close_rounded,
                  size: 19,
                  color: theme.trexvenColors.muted?.withOpacity(0.6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _getDetailView(index),
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL VIEW
  // ============================================================

  Widget _getDetailView(int index) {
    switch (index) {
      case 0:
        return _buildTransactionsDetail();

      case 1:
        return _buildStockValueDetail();

      case 2:
        return _buildLowStockDetail();

      case 3:
        return _buildProductsDetail();

      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // TRANSACTIONS DETAIL
  // ============================================================

  Widget _buildTransactionsDetail() {
    final theme = Theme.of(context);
    final data = _stats['transactions'];
    final recent = (data['recent'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _statusChip(
                'Successful',
                data['successful'] ?? 0,
                theme.trexvenColors.success ?? Colors.green,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _statusChip(
                'Pending',
                data['pending'] ?? 0,
                theme.trexvenColors.warning ?? Colors.orange,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _statusChip(
                'Failed',
                data['failed'] ?? 0,
                theme.trexvenColors.error ?? Colors.red,
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        _detailStatItem(
          'Total Value',
          _currencyFormat.format(data['totalValue'] ?? 0),
        ),

        const SizedBox(height: 22),

        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 12),

        if (recent.isEmpty)
          Text(
            'No recent activity',
            style: TextStyle(fontSize: 13, color: theme.trexvenColors.muted),
          )
        else
          ...(recent as List<Sale>).map((sale) => _buildSaleListItem(sale)),
      ],
    );
  }

  // ============================================================
  // STOCK VALUE DETAIL
  // ============================================================

  Widget _buildStockValueDetail() {
    final theme = Theme.of(context);
    final data = _stats['inventory'];
    final topProducts = (data['topProducts'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _detailStatItem(
                'Total Units',
                '${data['totalUnits'] ?? 0}',
              ),
            ),

            Expanded(
              child: _detailStatItem(
                'Products',
                '${data['productCount'] ?? 0}',
              ),
            ),

            Expanded(
              child: _detailStatItem('New Today', '${data['addedToday'] ?? 0}'),
            ),
          ],
        ),

        const SizedBox(height: 22),

        Text(
          'Top Products by Value',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 12),

        if (topProducts.isEmpty)
          Text(
            'No products found',
            style: TextStyle(fontSize: 13, color: theme.trexvenColors.muted),
          )
        else
          ...(topProducts as List<Product>).map(
            (product) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Text(
                    _currencyFormat.format(product.stock * product.price),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // PRODUCTS DETAIL
  // ============================================================

  Widget _buildProductsDetail() {
    final data = _stats['inventory'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _detailStatItem(
                'Products',
                '${data['productCount'] ?? 0}',
              ),
            ),
            Expanded(
              child: _detailStatItem('Units', '${data['totalUnits'] ?? 0}'),
            ),
          ],
        ),

        const SizedBox(height: 20),

        Text(
          'Inventory Overview',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          '${data['addedToday'] ?? 0} new products added today.',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).trexvenColors.muted,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LOW STOCK DETAIL
  // ============================================================

  Widget _buildLowStockDetail() {
    final theme = Theme.of(context);
    final data = _stats['lowStock'];
    final critical = (data['critical'] as List?) ?? [];
    final warning = (data['warning'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (critical.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: theme.trexvenColors.error,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                'Critical',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.trexvenColors.error,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ...(critical as List<Product>).map(
            (product) => _buildLowStockItem(
              product,
              theme.trexvenColors.error ?? Colors.red,
            ),
          ),

          const SizedBox(height: 15),
        ],

        if (warning.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.trexvenColors.warning,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                'Low Stock',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.trexvenColors.warning,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          ...(warning as List<Product>).map(
            (product) => _buildLowStockItem(
              product,
              theme.trexvenColors.warning ?? Colors.orange,
            ),
          ),
        ],

        if (critical.isEmpty && warning.isEmpty)
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 17,
                color: theme.trexvenColors.success,
              ),
              const SizedBox(width: 7),
              Text(
                'All products are well stocked',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.trexvenColors.success,
                ),
              ),
            ],
          ),

        const SizedBox(height: 18),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 17,
                color: theme.colorScheme.primary,
              ),

              const SizedBox(width: 9),

              Expanded(
                child: Text(
                  'Consider reordering top-selling items before they run out.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: theme.trexvenColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DETAIL STAT
  // ============================================================

  Widget _detailStatItem(String label, String value) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: theme.trexvenColors.muted?.withOpacity(0.7),
          ),
        ),

        const SizedBox(height: 4),

        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget _statusChip(String label, int count, Color color) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: theme.trexvenColors.muted?.withOpacity(0.8),
            ),
          ),

          const SizedBox(height: 3),

          Text(
            '$count',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SALE LIST ITEM
  // ============================================================

  Widget _buildSaleListItem(Sale sale) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 17,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  '${sale.quantity} units · ${DateFormat('HH:mm').format(sale.createdAt ?? DateTime.now())}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.trexvenColors.muted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Text(
            _currencyFormat.format(sale.totalPrice),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOW STOCK ITEM
  // ============================================================

  Widget _buildLowStockItem(Product product, Color color) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ),

          const SizedBox(width: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${product.stock} left',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// DASHED CIRCLE PAINTER
// ================================================================

class DashedCirclePainter extends CustomPainter {
  final Color color;

  DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;

    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double dashWidth = 3;
    const double dashSpace = 3;

    final double circumference = 2 * 3.1415926535 * radius;

    final int dashCount = (circumference / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final double startAngle =
          (i * (dashWidth + dashSpace) / circumference) * 2 * 3.1415926535;

      final double sweepAngle = (dashWidth / circumference) * 2 * 3.1415926535;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
