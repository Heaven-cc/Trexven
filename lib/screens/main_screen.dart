import 'package:trexven_design_system/trexven_design_system.dart';
import '../services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};
  String? _navigationIdentity;
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
          title: Text('Select your business'),
          children: [
            for (final row in rows)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, row['id'] as String),
                child: Text(row['business_name']?.toString() ?? 'Business'),
              ),
            if (rows.isEmpty)
              Padding(
                padding: TrexvenSpacing.cardPadding,
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
          SnackBar(
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
          SnackBar(
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

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _visitedTabs.add(index);
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final identity = '${userProvider.user?.id ?? ''}:${userProvider.business?.id ?? ''}';
    if (_navigationIdentity != identity) {
      _navigationIdentity = identity;
      _currentIndex = 0;
      _visitedTabs..clear()..add(0);
    }
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: TrexvenFontSize.section,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Switch owned business',
            onPressed: _switchingBusiness ? null : _switchBusiness,
            icon: Icon(Icons.business_outlined),
          ),
          // ANGEL BUTTON
          TrexvenHeaderAction(
            label: 'Angel',
            icon: Icons.auto_awesome,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AngelScreen()),
              );
            },
          ),

          // NOTIFICATION BELL (ALERTS)
          IconButton(
            tooltip: 'Security Alerts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AlertsScreen()),
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
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: KeyedSubtree(
          key: ValueKey(identity),
          child: IndexedStack(
            index: _currentIndex,
            children: [
              for (var index = 0; index < 5; index++)
                _visitedTabs.contains(index)
                    ? TickerMode(
                        enabled: index == _currentIndex,
                        child: _buildPage(index, userProvider),
                      )
                    : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        destinations: [
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

  Widget _buildPage(int index, UserProvider userProvider) {
    switch (index) {
      case 0:
        return DashboardScreen(
          ownerName: userProvider.ownerName,
          businessName: userProvider.businessName,
          onOpenCameras: () => _selectTab(3),
        );
      case 1:
        return InventoryTab();
      case 2:
        return FinanceTab();
      case 3:
        return IntelligenceTab();
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
