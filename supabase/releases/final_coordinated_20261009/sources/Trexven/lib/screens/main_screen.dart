import '../services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/user_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'dashboard/angel_screen.dart';
import 'inventory/inventory_tab.dart';
import 'finance/finance_tab.dart';
import 'intelligence/intelligence_tab.dart';
import 'intelligence/alerts_screen.dart';
import '../services/alert_navigation.dart';
import 'me/me_tab.dart';
import '../services/alert_service.dart';
import '../services/camera_service.dart';
import '../widgets/trexven_widgets.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _lastUnreadCount = 0;
  final _alertService = AlertService();
  final _cameraService = CameraService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _alertService.onNotificationTap = _openNotification;
    _initAlerts();
  }

  bool _switchingBusiness = false;
  Future<void> _switchBusiness() async {
    if (_switchingBusiness) return;
    setState(() => _switchingBusiness = true);
    final database = DatabaseService();
    try {
      if (await database.hasUnresolvedOperation()) {
        throw StateError(
          'Recover the original interrupted operation before switching business.',
        );
      }
      final rows = await database.getOwnedBusinesses();
      if (!mounted) return;
      final id = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Select your business'),
          children: [
            for (final row in rows)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, row['id'] as String),
                child: Text(row['business_name']?.toString() ?? 'Business'),
              ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No owned business is currently accessible.'),
              ),
          ],
        ),
      );
      if (id == null || !mounted) return;
      final provider = context.read<UserProvider>();
      final previous = provider.business?.id;
      await database.selectOwnedBusiness(id);
      await provider.refreshBusiness();
      if (provider.business?.id != id) {
        if (previous != null) await database.selectOwnedBusiness(previous);
        throw StateError(
          'Business refresh was not confirmed. Reopen the original business.',
        );
      }
      await _alertService.init(id);
      if (mounted) _onAlertsChanged();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Business switch was not confirmed. Recover any interrupted operation first, then verify your owner access online.',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _switchingBusiness = false);
    }
  }

  Future<void> _initAlerts() async {
    try {
      final bizId = await _cameraService.getCurrentBusinessId();
      if (!mounted) return;
      if (bizId != null) {
        await _alertService.init(bizId);
        if (!mounted) {
          await _alertService.dispose();
          return;
        }
        _alertService.addListener(_onAlertsChanged);
        _onAlertsChanged();
        final pending = _alertService.takePendingNotification();
        if (pending != null && mounted) _openNotification(pending);
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Alerts could not connect. Please reopen this screen to retry.',
            ),
          ),
        );
    }
  }

  void _openNotification(Map<String, dynamic> alert) {
    if (mounted) openAlertDestination(context, alert);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _alertService.refresh();
  }

  void _onAlertsChanged() {
    final unread = _alertService.unreadCount;
    if (mounted && unread != _lastUnreadCount) {
      setState(() => _lastUnreadCount = unread);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alertService.onNotificationTap = null;
    _alertService.removeListener(_onAlertsChanged);
    _alertService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = _alertService.unreadCount;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Text(
          'TREXVEN',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Switch owned business',
            onPressed: _switchingBusiness ? null : _switchBusiness,
            icon: const Icon(Icons.business_outlined),
          ),
          // ANGEL BUTTON
          TrexvenPressable(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AngelScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Angel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // NOTIFICATION BELL (ALERTS)
          IconButton(
            tooltip: 'Security Alerts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertsScreen()),
              );
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 24,
                  color: theme.colorScheme.onSurface,
                ),
                if (unread > 0)
                  Positioned(
                    right: -1,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: theme.trexvenColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: KeyedSubtree(
          key: ValueKey(context.watch<UserProvider>().business?.id),
          child: _buildCurrentPage(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: theme.trexvenColors.cardBackground,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        indicatorColor: theme.colorScheme.primary.withOpacity(0.08),
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Finance',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Intelligence',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Me',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    final userProvider = context.watch<UserProvider>();

    switch (_currentIndex) {
      case 0:
        return DashboardScreen(
          ownerName: userProvider.ownerName,
          businessName: userProvider.businessName,
          onOpenCameras: () => setState(() => _currentIndex = 3),
        );
      case 1:
        return const InventoryTab();
      case 2:
        return FinanceTab();
      case 3:
        return const IntelligenceTab();
      case 4:
        return MeTab(
          ownerName: userProvider.ownerName,
          businessName: userProvider.businessName,
        );
      default:
        return DashboardScreen(
          ownerName: userProvider.ownerName,
          businessName: userProvider.businessName,
        );
    }
  }
}
