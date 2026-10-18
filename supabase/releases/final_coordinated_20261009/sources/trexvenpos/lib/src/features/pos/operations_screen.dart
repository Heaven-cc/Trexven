import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../auth/auth_provider.dart';
import '../auth/permission_service.dart';
import 'offline_cash_screen.dart';
import '../inventory/scanner_screen.dart';
import '../../models/product.dart';

final operationsEntitlementsProvider =
    FutureProvider.family<BusinessEntitlements, String>((ref, business) {
      ref.watch(authStateProvider.select((s) => s.employee?.userId));
      final client = ref.read(supabaseProvider);
      final channel = client
          .channel('operations-subscription-$business')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'business_subscriptions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'business_id',
              value: business,
            ),
            callback: (_) => ref.invalidateSelf(),
          )
          .subscribe();
      ref.onDispose(() {
        client.removeChannel(channel);
      });
      return BusinessEntitlements.load(OperationsClient.pos(client, business));
    });

class PosOperationsScreen extends ConsumerWidget {
  const PosOperationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider),
        access = ref.watch(permissionServiceProvider);
    if (auth.activeBusiness == null)
      return const Scaffold(body: Center(child: Text('Select a business.')));
    final subscription = ref.watch(
      operationsEntitlementsProvider(auth.activeBusiness!.id),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Operations')),
      body: ListView(
        children: [
          subscription.when(
            data: (s) => ListTile(
              title: Text('Subscription: ${s.status}'),
              subtitle: Text(
                s.enforced
                    ? 'Plan restrictions are checked by the server. Pending sales and receipts are retained.'
                    : 'Subscription enforcement has not been activated.',
              ),
              trailing: IconButton(
                tooltip: 'Refresh subscription status',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(
                  operationsEntitlementsProvider(auth.activeBusiness!.id),
                ),
              ),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, st) => const ListTile(
              title: Text(
                'Subscription status unavailable; no access grant assumed.',
              ),
            ),
          ),
          if (access.hasPermission('cash_shifts'))
            ListTile(
              leading: const Icon(Icons.point_of_sale),
              title: const Text('Shared cash drawers'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CashShiftScreen(
                    api: OperationsClient.pos(
                      ref.read(supabaseProvider),
                      auth.activeBusiness!.id,
                    ),
                    owner: access.isOwner,
                    reviewer: access.hasPermission('review_cash_shifts'),
                  ),
                ),
              ),
            ),
          if (access.hasPermission('view_inventory'))
            ListTile(
              leading: const Icon(Icons.inventory_2),
              title: const Text('Stocktaking and inventory operations'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InventoryOperationsScreen(
                    scanBarcode: (context) async {
                      final product = await Navigator.push<Product>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ScannerScreen(),
                        ),
                      );
                      return product?.barcode;
                    },
                    api: OperationsClient.pos(
                      ref.read(supabaseProvider),
                      auth.activeBusiness!.id,
                    ),
                  ),
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Credit, repayments and returns'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FinancialOperationsScreen(
                  api: OperationsClient.pos(
                    ref.read(supabaseProvider),
                    auth.activeBusiness!.id,
                  ),
                  owner: access.isOwner,
                ),
              ),
            ),
          ),
          if (access.hasPermission('offline_cash'))
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Offline cash and synchronization'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfflineCashScreen()),
              ),
            ),
        ],
      ),
    );
  }
}
