import 'package:flutter/material.dart';
import 'dashboard/angel_screen.dart';
import 'home/home_tab.dart';
import 'inventory/inventory_tab.dart';
import 'finance/finance_tab.dart';
import 'intelligence/intelligence_tab.dart';
import 'intelligence/alerts_screen.dart';
import 'me/me_tab.dart';
import '../services/alert_service.dart';
import '../services/camera_service.dart';

class MainScreen extends StatefulWidget {
  final String businessName;
  final String ownerName;

  const MainScreen({
    super.key,
    required this.businessName,
    required this.ownerName,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final _alertService = AlertService();
  final _cameraService = CameraService();

  static const Color background = Color(0xFFF8FAFC);
  static const Color dark = Color(0xFF0F172A);
  static const Color blue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _initAlerts();
  }

  Future<void> _initAlerts() async {
    final bizId = await _cameraService.getCurrentBusinessId();
    if (bizId != null) {
      await _alertService.init(bizId);
      _alertService.addListener(_onAlertsChanged);
    }
  }

  void _onAlertsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _alertService.removeListener(_onAlertsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _alertService.unreadCount;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text(
          'TREXVEN',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: dark,
          ),
        ),
        actions: [
          // ANGEL BUTTON
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AngelScreen()),
              );
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCEBFF)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: blue),
                  SizedBox(width: 6),
                  Text('Angel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: blue)),
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
                const Icon(
                  Icons.notifications_none_rounded,
                  size: 28,
                  color: dark,
                ),
                if (unread > 0)
                  Positioned(
                    right: -1,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: background,
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
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: const Color(0xFFEFF6FF),
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
    switch (_currentIndex) {
      case 0:
        return HomeTab(
          ownerName: widget.ownerName,
          businessName: widget.businessName,
          onOpenCameras: () => setState(() => _currentIndex = 3),
        );
      case 1:
        return InventoryTab();
      case 2:
        return FinanceTab();
      case 3:
        return const IntelligenceTab();
      case 4:
        return MeTab(
          ownerName: widget.ownerName,
          businessName: widget.businessName,
        );
      default:
        return HomeTab(
          ownerName: widget.ownerName,
          businessName: widget.businessName,
        );
    }
  }
}
