import 'package:flutter/material.dart';
import 'package:trexven_design_system/trexven_design_system.dart';

/// A noninteractive Home shell while owner access is resolved.
/// It never constructs a business screen or starts business data reads.
class StartupSkeleton extends StatelessWidget {
  const StartupSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('TREXVEN'),
      actions: const [
        IconButton(onPressed: null, icon: Icon(Icons.business_outlined)),
        IconButton(onPressed: null, icon: Icon(Icons.auto_awesome)),
        IconButton(onPressed: null, icon: Icon(Icons.notifications_outlined)),
      ],
    ),
    body: const TrexvenSkeleton(kind: TrexvenSkeletonKind.dashboard),
    bottomNavigationBar: IgnorePointer(
      child: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Finance',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Intelligence',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Me'),
        ],
      ),
    ),
  );
}
