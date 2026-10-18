import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pos/cart_provider.dart';
import 'auth_provider.dart';

class AuthorizedBranch {
  final String id;
  final String businessId;
  final String name;
  const AuthorizedBranch({
    required this.id,
    required this.businessId,
    required this.name,
  });
}

class BranchContext extends StateNotifier<AuthorizedBranch?> {
  final String businessId;
  BranchContext(this.businessId) : super(null);

  void select(
    AuthorizedBranch branch,
    List<AuthorizedBranch> available, {
    required bool hasCart,
  }) {
    if (hasCart)
      throw StateError(
        'Finish or clear the current cart before switching branches.',
      );
    if (branch.businessId != businessId ||
        !available.any(
          (b) => b.id == branch.id && b.businessId == businessId,
        )) {
      throw StateError('Select an authorized branch.');
    }
    state = branch;
  }

  void clear({required bool hasCart}) {
    if (hasCart)
      throw StateError(
        'Finish or clear the current cart before switching branches.',
      );
    state = null;
  }
}

final branchContextProvider =
    StateNotifierProvider<BranchContext, AuthorizedBranch?>((ref) {
      ref.watch(
        authStateProvider.select(
          (s) => '${s.employee?.userId}:${s.activeBusiness?.id}',
        ),
      );
      return BranchContext(
        ref.read(authStateProvider).activeBusiness?.id ?? '',
      );
    });

final authorizedBranchesProvider = FutureProvider<List<AuthorizedBranch>>((
  ref,
) async {
  final business = ref.watch(authStateProvider).activeBusiness;
  if (business == null || !business.branchesEnabled) return const [];
  // RLS supplies the authoritative assignment list. Cached UI context is never
  // sent as proof of authority; every RPC checks assignments again.
  final rows = await ref
      .watch(supabaseProvider)
      .from('branches')
      .select('id,business_id,name')
      .eq('business_id', business.id)
      .eq('is_active', true)
      .order('name');
  return rows
      .map(
        (r) => AuthorizedBranch(
          id: r['id'].toString(),
          businessId: r['business_id'].toString(),
          name: r['name'].toString(),
        ),
      )
      .toList();
});

class BranchGate extends ConsumerWidget {
  final Widget child;
  const BranchGate({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(authStateProvider).activeBusiness;
    if (business == null || !business.branchesEnabled) return child;
    final selected = ref.watch(branchContextProvider);
    final branches = ref.watch(authorizedBranchesProvider);
    return branches.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to verify your branch assignments.'),
              TextButton(
                onPressed: () => ref.invalidate(authorizedBranchesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (available) {
        if (selected != null &&
            available.any(
              (b) => b.id == selected.id && b.businessId == business.id,
            ))
          return child;
        return Scaffold(
          appBar: AppBar(title: const Text('Select your branch')),
          body: available.isEmpty
              ? const Center(
                  child: Text(
                    'No active branch assignments. Contact your business owner.',
                  ),
                )
              : ListView(
                  children: [
                    for (final branch in available)
                      ListTile(
                        title: Text(branch.name),
                        onTap: () {
                          try {
                            ref
                                .read(branchContextProvider.notifier)
                                .select(
                                  branch,
                                  available,
                                  hasCart: ref.read(cartProvider).isNotEmpty,
                                );
                          } on StateError catch (error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.message)),
                            );
                          }
                        },
                      ),
                  ],
                ),
        );
      },
    );
  }
}
