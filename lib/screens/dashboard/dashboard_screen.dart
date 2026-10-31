import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';

import '../../core/user_provider.dart';
import '../../services/database_service.dart';
import '../../services/business_currency.dart';
import '../../models/sale.dart';
import '../../models/product.dart';
import '../inventory/add_product_screen.dart';
import '../finance/record_sale_screen.dart';
import '../me/employment_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String ownerName;
  final String businessName;
  final VoidCallback? onOpenCameras;
  final DatabaseService? database;

  const DashboardScreen({
    super.key,
    required this.ownerName,
    required this.businessName,
    this.onOpenCameras,
    this.database,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const double _sectionGap = 16;
  static const double _gridGap = 10;
  static const double _actionGap = 10;

  late final DatabaseService _db;

  bool _isLoading = true;
  bool _hasLoadedStats = false;
  int _statsVersion = 0;
  String? _errorMessage;
  int? _expandedIndex;

  NumberFormat get _currencyFormat => BusinessCurrency.formatter(
    context.read<UserProvider>().business?.currency,
  );

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
    _db = widget.database ?? DatabaseService();
    _loadStats();
  }

  Map<String, dynamic> _section(String key) {
    final value = _stats[key];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    final version = ++_statsVersion;

    setState(() {
      _isLoading = !_hasLoadedStats;
      _errorMessage = null;
    });

    try {
      final stats = await _db.getDetailedDashboardStats().timeout(
        const Duration(seconds: 20),
      );

      if (!mounted || version != _statsVersion) return;

      setState(() {
        _stats = stats;
        _hasLoadedStats = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || version != _statsVersion) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load dashboard data.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CustomerPresentation.error(
              error,
              fallback: 'We could not load your dashboard. Please try again.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';

    return 'Good evening';
  }

  void _toggleExpand(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  void _openPage(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((
      _,
    ) {
      if (mounted) _loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_errorMessage != null && !_hasLoadedStats) {
      return _buildErrorState();
    }

    return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: TrexvenSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_errorMessage != null)
              TextButton(
                onPressed: _loadStats,
                child: const Text('Refresh failed. Showing cached data. Retry'),
              ),

            const SizedBox(height: _sectionGap),

            _buildSalesCard(),

            const SizedBox(height: _sectionGap),

            _buildSectionTitle('Today'),

            const SizedBox(height: 10),

            _buildKpiSection(),

            const SizedBox(height: _sectionGap),

            _buildSectionTitle('Quick actions'),

            const SizedBox(height: 10),

            _buildQuickActions(),

            const SizedBox(height: 12),
          ],
        ),
      );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final errorColor = theme.trexvenColors.error ?? theme.colorScheme.error;

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
                color: errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(TrexvenRadii.card),
              ),
              child: Icon(Icons.cloud_off_rounded, color: errorColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Dashboard unavailable',
              style: TextStyle(
                fontSize: TrexvenFontSize.section,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'We could not load your business data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: TrexvenFontSize.body,
                color: theme.trexvenColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStats,
              child: const Text('Try again'),
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
    final user = context.watch<UserProvider>();

    final ownerName = user.ownerName.trim().isEmpty
        ? widget.ownerName.trim()
        : user.ownerName.trim();

    final firstName = ownerName.isEmpty ? 'there' : ownerName.split(' ').first;

    final businessName = user.businessName.trim().isEmpty
        ? widget.businessName
        : user.businessName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_greeting()}, $firstName',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 5),
        Text('Your business at a glance', style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: theme.trexvenColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                size: 19,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: TrexvenFontSize.body,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
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
  // SALES TODAY HERO
  // ============================================================

  Widget _buildSalesCard() {
    final sales = _section('sales');

    return Container(
      key: const ValueKey('dashboard-sales-hero'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 17),
      decoration: BoxDecoration(
        color: const Color(0xFF111B35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SALES TODAY',
            style: TextStyle(
              color: Color(0xFFB5C4DB),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _isLoading
                ? const TrexvenSkeletonBlock(width: 170, height: 31)
                : Text(
              _currencyFormat.format(sales['totalToday'] ?? 0.0),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            "Today's recorded sales",
            style: TextStyle(color: Color(0xFFB5C4DB), fontSize: 12),
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
        fontSize: TrexvenFontSize.section,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // ============================================================
  // KPI DATA
  // ============================================================

  List<Map<String, dynamic>> _getCardData() {
    final transactions = _section('transactions');
    final inventory = _section('inventory');
    final lowStock = _section('lowStock');
    final alerts = _section('alerts');

    final alertCount =
        alerts['totalCount'] ?? alerts['count'] ?? _stats['alertCount'];

    return [
      {
        'title': 'Transactions',
        'value': '${transactions['successful'] ?? 0}',
        'icon': Icons.receipt_long_rounded,
      },
      {
        'title': 'Stock value',
        'value': _currencyFormat.format(inventory['totalValue'] ?? 0),
        'icon': Icons.inventory_2_outlined,
      },
      {
        'title': 'Low stock',
        'value': '${lowStock['totalCount'] ?? 0}',
        'icon': Icons.warning_amber_rounded,
      },
      {
        'title': 'Alerts',
        'value': alertCount == null ? '—' : '$alertCount',
        'icon': Icons.notifications_none_rounded,
      },
    ];
  }

  // ============================================================
  // FIXED 2 x 2 KPI GRID
  // ============================================================

  Widget _buildKpiSection() {
    final cards = _getCardData();

    if (_expandedIndex != null) {
      return _buildDetailedCard(_expandedIndex!, cards[_expandedIndex!]);
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _miniKPICard(
                0,
                cards[0]['title'] as String,
                cards[0]['value'] as String,
              ),
            ),
            const SizedBox(width: _gridGap),
            Expanded(
              child: _miniKPICard(
                1,
                cards[1]['title'] as String,
                cards[1]['value'] as String,
              ),
            ),
          ],
        ),
        const SizedBox(height: _gridGap),
        Row(
          children: [
            Expanded(
              child: _miniKPICard(
                2,
                cards[2]['title'] as String,
                cards[2]['value'] as String,
              ),
            ),
            const SizedBox(width: _gridGap),
            Expanded(
              child: _miniKPICard(
                3,
                cards[3]['title'] as String,
                cards[3]['value'] as String,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // COMPACT KPI CARD
  // ============================================================

  Widget _miniKPICard(int index, String title, String value) {
    final theme = Theme.of(context);

    return Material(
      color: theme.trexvenColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('dashboard-kpi-$index'),
        onTap: () => _toggleExpand(index),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 85),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.trexvenColors.muted,
                ),
              ),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _isLoading
                      ? const TrexvenSkeletonBlock(width: 78, height: 22)
                      : Text(
                    value,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FIXED 2 x 2 QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _quickAction(
                icon: Icons.point_of_sale_rounded,
                title: 'Record Sale',
                onTap: () {
                  _openPage(
                    RecordSaleScreen(
                      database: _db,
                      submitCartSale: _db.recordCartSale,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: _actionGap),
            Expanded(
              child: _quickAction(
                icon: Icons.add_box_outlined,
                title: 'Add Product',
                onTap: () {
                  _openPage(AddProductScreen());
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: _actionGap),
        Row(
          children: [
            Expanded(
              child: _quickAction(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Add Employee',
                onTap: () {
                  _openPage(EmploymentScreen());
                },
              ),
            ),
            const SizedBox(width: _actionGap),
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

    return Material(
      color: theme.trexvenColors.cardBackground,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          key: ValueKey('dashboard-action-$title'),
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EXPANDED KPI CARD
  // ============================================================

  Widget _buildDetailedCard(int index, Map<String, dynamic> data) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(TrexvenRadii.card),
                ),
                child: Icon(
                  data['icon'] as IconData,
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
                      data['title'].toString(),
                      style: TextStyle(
                        fontSize: TrexvenFontSize.caption,
                        fontWeight: FontWeight.w600,
                        color: theme.trexvenColors.muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data['value'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: TrexvenFontSize.section,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close details',
                onPressed: () => _toggleExpand(index),
                icon: Icon(
                  Icons.close_rounded,
                  size: 19,
                  color: theme.trexvenColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _getDetailView(index),
        ],
      ),
    );
  }

  Widget _getDetailView(int index) {
    switch (index) {
      case 0:
        return _buildTransactionsDetail();
      case 1:
        return _buildStockValueDetail();
      case 2:
        return _buildLowStockDetail();
      case 3:
        return _buildAlertsDetail();
      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // TRANSACTIONS DETAIL
  // ============================================================

  Widget _buildTransactionsDetail() {
    final theme = Theme.of(context);
    final data = _section('transactions');

    final recent = data['recent'] is List ? data['recent'] as List : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusChip(
          'Completed',
          (data['successful'] as num?)?.toInt() ?? 0,
          theme.trexvenColors.success ?? Colors.green,
        ),
        const SizedBox(height: 16),
        _detailStatItem(
          'Total Value',
          _currencyFormat.format(data['totalValue'] ?? 0),
        ),
        const SizedBox(height: 16),
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: TrexvenFontSize.body,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          _mutedText('No recent activity')
        else
          for (final item in recent)
            if (item is Sale) _buildSaleListItem(item),
      ],
    );
  }

  // ============================================================
  // STOCK VALUE DETAIL
  // ============================================================

  Widget _buildStockValueDetail() {
    final theme = Theme.of(context);
    final data = _section('inventory');

    final topProducts = data['topProducts'] is List
        ? data['topProducts'] as List
        : [];

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
        const SizedBox(height: 16),
        Text(
          'Top Products by Value',
          style: TextStyle(
            fontSize: TrexvenFontSize.body,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (topProducts.isEmpty)
          _mutedText('No products found')
        else
          for (final item in topProducts)
            if (item is Product)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: TrexvenFontSize.body,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _currencyFormat.format(item.stock * item.price),
                      style: TextStyle(
                        fontSize: TrexvenFontSize.body,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
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
    final data = _section('lowStock');

    final critical = data['critical'] is List ? data['critical'] as List : [];

    final warning = data['warning'] is List ? data['warning'] as List : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (critical.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 17,
                color: theme.trexvenColors.error,
              ),
              const SizedBox(width: 7),
              Text(
                'Critical',
                style: TextStyle(
                  fontSize: TrexvenFontSize.body,
                  fontWeight: FontWeight.w800,
                  color: theme.trexvenColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in critical)
            if (item is Product)
              _buildLowStockItem(item, theme.trexvenColors.error ?? Colors.red),
          const SizedBox(height: 16),
        ],
        if (warning.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 17,
                color: theme.trexvenColors.warning,
              ),
              const SizedBox(width: 7),
              Text(
                'Low Stock',
                style: TextStyle(
                  fontSize: TrexvenFontSize.body,
                  fontWeight: FontWeight.w800,
                  color: theme.trexvenColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in warning)
            if (item is Product)
              _buildLowStockItem(
                item,
                theme.trexvenColors.warning ?? Colors.orange,
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
              Expanded(
                child: Text(
                  'All products are well stocked',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.body,
                    fontWeight: FontWeight.w600,
                    color: theme.trexvenColors.success,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(TrexvenRadii.card),
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
                    fontSize: TrexvenFontSize.caption,
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
  // ALERTS DETAIL
  // ============================================================

  Widget _buildAlertsDetail() {
    final theme = Theme.of(context);
    final alerts = _section('alerts');

    if (alerts.isEmpty) {
      return _mutedText(
        'Alert statistics are not available in the current dashboard response.',
      );
    }

    final recent = alerts['recent'];

    if (recent is! List || recent.isEmpty) {
      return _mutedText('No recent alert details available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Alerts',
          style: TextStyle(
            fontSize: TrexvenFontSize.body,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        for (final item in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item is Map
                        ? (item['title'] ??
                                  item['message'] ??
                                  item['alert_type'] ??
                                  'Alert')
                              .toString()
                        : item.toString(),
                    style: TextStyle(
                      fontSize: TrexvenFontSize.body,
                      color: theme.colorScheme.onSurface,
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
  // DETAIL STAT ITEM
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
            fontSize: TrexvenFontSize.caption,
            fontWeight: FontWeight.w500,
            color: theme.trexvenColors.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: TrexvenFontSize.input,
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
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: TrexvenFontSize.caption,
              fontWeight: FontWeight.w600,
              color: theme.trexvenColors.muted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: TrexvenFontSize.input,
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
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
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
                    fontSize: TrexvenFontSize.caption,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sale.quantity} units · '
                  '${DateFormat('HH:mm').format(sale.createdAt ?? DateTime.now())}',
                  style: TextStyle(
                    fontSize: TrexvenFontSize.caption,
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
              fontSize: TrexvenFontSize.caption,
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
                fontSize: TrexvenFontSize.caption,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(TrexvenRadii.status),
            ),
            child: Text(
              '${product.stock} left',
              style: TextStyle(
                fontSize: TrexvenFontSize.caption,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mutedText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: TrexvenFontSize.body,
        color: Theme.of(context).trexvenColors.muted,
      ),
    );
  }
}
