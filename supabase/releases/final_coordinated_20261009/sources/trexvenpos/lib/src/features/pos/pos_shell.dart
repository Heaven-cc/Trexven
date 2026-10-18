import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product.dart';
import '../auth/auth_provider.dart';
import '../auth/permission_service.dart';
import '../inventory/product_detail_screen.dart';
import '../inventory/product_search_screen.dart';
import '../inventory/scanner_screen.dart';
import 'dashboard_screen.dart';
import 'recent_sales_screen.dart';
import 'operations_screen.dart';
import 'checkout_screen.dart';
import 'cart_provider.dart';
import 'pending_sale_provider.dart';
import '../auth/branch_context.dart';
import 'employee_settings_screen.dart';
import 'package:trexven_operations/trexven_operations.dart';

/// Tabs retain the existing repositories and checkout. Auth, pending-sale and
/// authorized-branch gates remain outside this shell.
class PosShell extends ConsumerStatefulWidget {
  const PosShell({super.key});
  @override
  ConsumerState<PosShell> createState() => _PosShellState();
}

class _PosShellState extends ConsumerState<PosShell> {
  String selected = 'Home';
  final Set<String> visited = {'Home'};
  @override
  Widget build(BuildContext context) {
    final access = ref.watch(permissionServiceProvider);
    final auth = ref.watch(authStateProvider);
    final tabs = <({String label, IconData icon, Widget screen})>[
      (
        label: 'Home',
        icon: Icons.home_outlined,
        screen: const DashboardScreen(),
      ),
      if (access.canCompleteSales || access.hasPermission('view_sales'))
        (
          label: 'Sales',
          icon: Icons.receipt_long_outlined,
          screen: const _SalesLanding(),
        ),
      if (access.hasPermission('view_inventory'))
        (
          label: 'Inventory',
          icon: Icons.inventory_2_outlined,
          screen: const ProductSearchScreen(),
        ),
      (label: 'More', icon: Icons.more_horiz, screen: const _MoreScreen()),
    ];
    final selectedIndex = tabs.indexWhere((tab) => tab.label == selected);
    final index = selectedIndex < 0 ? 0 : selectedIndex;
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: tabs
            .map(
              (tab) => visited.contains(tab.label)
                  ? KeyedSubtree(
                      key: ValueKey(
                        '${auth.activeBusiness?.id}:${auth.employee?.membershipId}:${tab.label}',
                      ),
                      child: tab.screen,
                    )
                  : const SizedBox.shrink(),
            )
            .toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() {
          selected = tabs[i].label;
          visited.add(selected);
        }),
        destinations: tabs
            .map(
              (t) => NavigationDestination(icon: Icon(t.icon), label: t.label),
            )
            .toList(),
      ),
    );
  }
}

class _SalesLanding extends ConsumerWidget {
  const _SalesLanding();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(permissionServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (access.canCompleteSales) ...[
            FilledButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Product'),
              onPressed: () async {
                final product = await Navigator.push<Product>(
                  context,
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                );
                if (product != null && context.mounted)
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(product: product),
                    ),
                  );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('New Sale'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductSearchScreen()),
              ),
            ),
            if (ref.watch(cartProvider).isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Review current cart'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                ),
              ),
          ],
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Sales History'),
            subtitle: const Text(
              'Your authorized business and reporting scope',
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecentSalesScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreScreen extends ConsumerWidget {
  const _MoreScreen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final access = ref.watch(permissionServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          if (!auth.offlineCashOnly)
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Switch authorized business'),
              onTap: () async {
                try {
                  if (await (await ref.read(
                        pendingSaleStoreProvider.future,
                      )).read() !=
                      null) {
                    throw StateError(
                      'Recover the retained sale before switching business.',
                    );
                  }
                  if (ref.read(cartProvider).isNotEmpty) {
                    throw StateError(
                      'Finish or remove the unsubmitted cart before switching business.',
                    );
                  }
                  final rows =
                      await ref
                              .read(supabaseProvider)
                              .rpc('get_trexven_pos_context')
                          as List;
                  if (!context.mounted) return;
                  final id = await showDialog<String>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: const Text('Select authorized business'),
                      children: [
                        for (final row in rows)
                          if (!access.isOwner ||
                              (row['employee'] as Map)['role'] == 'owner')
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(
                                context,
                                (row['business'] as Map)['id'] as String,
                              ),
                              child: Text(
                                (row['business'] as Map)['business_name']
                                        ?.toString() ??
                                    'Business',
                              ),
                            ),
                      ],
                    ),
                  );
                  if (id != null && context.mounted) {
                    await ref
                        .read(authStateProvider.notifier)
                        .restoreSession(businessId: id);
                    ref.invalidate(branchContextProvider);
                  }
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Business switch was not confirmed. Recover pending sales and finish the current cart before verifying access online.',
                        ),
                      ),
                    );
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(auth.employee?.name ?? 'My Profile'),
            subtitle: Text(
              '${auth.activeBusiness?.name ?? ''} · ${auth.employee?.employeeCode ?? ''}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('My settings'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeeSettingsScreen()),
            ),
          ),
          if (!auth.offlineCashOnly && auth.activeBusiness != null)
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Business notifications'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificationCenterScreen(
                    api: OperationsClient.pos(
                      ref.read(supabaseProvider),
                      auth.activeBusiness!.id,
                    ),
                    open: (context, route, referenceId) {
                      final current = ref.read(permissionServiceProvider);
                      if ((route == 'inventory' &&
                              current.hasPermission('view_inventory')) ||
                          (route == 'cash' &&
                              current.hasPermission('review_cash_shifts'))) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PosOperationsScreen(),
                          ),
                        );
                      } else if (route == 'employees' &&
                          current.hasPermission('manage_employees')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmployeeAccessScreen(
                              api: OperationsClient.pos(
                                ref.read(supabaseProvider),
                                auth.activeBusiness!.id,
                              ),
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Current permission is required to open this notification.',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          if (access.hasPermission('manage_employees') &&
              auth.activeBusiness != null)
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Employees & permissions'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeeAccessScreen(
                    api: OperationsClient.pos(
                      ref.read(supabaseProvider),
                      auth.activeBusiness!.id,
                    ),
                  ),
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Operations'),
            subtitle: const Text(
              'Authorized credit, returns, inventory, cash drawers and synchronization',
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PosOperationsScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & recovery'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => const AlertDialog(
                title: Text('Safe recovery'),
                content: Text(
                  'Keep pending transactions and retry their original request. Never collect payment twice. Contact the business owner for access or payment discrepancies. Do not uninstall while sales are unsynced.',
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About TREXVEN POS'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'TREXVEN POS',
              applicationVersion: const String.fromEnvironment(
                'TREXVEN_BUILD_VERSION',
                defaultValue: 'Development build — version not supplied',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text(
                    'Pending sales and encrypted queues stay on this device. The original employee must sign in to recover them. Unsubmitted cart changes are not a completed sale.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (yes == true)
                await ref.read(authStateProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}
