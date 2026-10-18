import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/pending_sale.dart';
import '../../services/pending_sale_unsupported.dart'
    if (dart.library.io) '../../services/pending_sale_file.dart'
    as storage;
import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
import 'sales_provider.dart';
import 'payment_confirmation_dialog.dart';
import 'package:trexven_operations/trexven_operations.dart';

final pendingSaleStoreProvider = FutureProvider<PendingSaleStore>(
  (ref) => storage.createPendingSaleStore(),
);
final pendingSaleProvider = FutureProvider<PendingSale?>(
  (ref) async => (await ref.watch(pendingSaleStoreProvider.future)).read(),
);

class PendingSaleGate extends ConsumerStatefulWidget {
  final Widget child;
  const PendingSaleGate({super.key, required this.child});
  @override
  ConsumerState<PendingSaleGate> createState() => _PendingSaleGateState();
}

class _PendingSaleGateState extends ConsumerState<PendingSaleGate> {
  bool busy = false;
  String? error;
  Future<void> cancelWithoutPayment(PendingSale pending) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm no payment moved'),
        content: const Text(
          'Use this only if no cash, bank transfer or card payment was received. A committed sale cannot be cancelled here. Requests with money received must remain available for recovery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('No money moved'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = ref.read(authStateProvider);
      if (!pending.belongsTo(
        auth.employee?.userId ?? '',
        auth.activeBusiness?.id ?? '',
        auth.employee?.membershipId ?? '',
      ))
        throw StateError('Original employee and business required.');
      final client = ref.read(supabaseProvider);
      final result = await client.rpc(
        'cancel_trexven_uncommitted_operation',
        params: {
          'p_business_id': pending.sale.businessId,
          'p_request_id': pending.sale.id,
          'p_no_money_moved': true,
        },
      );
      if ((result as Map)['status'] != 'cancelled')
        throw StateError('Server cancellation not confirmed.');
      await (await ref.read(
        pendingSaleStoreProvider.future,
      )).acknowledge(pending.sale.id);
      ref.invalidate(pendingSaleProvider);
    } catch (e) {
      if (mounted) setState(() => error = 'Request retained: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> recover(PendingSale pending) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = ref.read(authStateProvider);
      final employee = auth.employee;
      final business = auth.activeBusiness;
      if (employee == null ||
          business == null ||
          !pending.belongsTo(
            employee.userId,
            business.id,
            employee.membershipId,
          )) {
        throw StateError(
          'Sign in with the original employee and business to recover this sale.',
        );
      }
      if (pending.sale.branchId != null) {
        ref.invalidate(authorizedBranchesProvider);
        final branches = await ref.read(authorizedBranchesProvider.future);
        if (!branches.any(
          (b) => b.id == pending.sale.branchId && b.businessId == business.id,
        )) {
          throw StateError(
            'The original branch assignment must be authorized before recovery.',
          );
        }
      }
      final store = await ref.read(pendingSaleStoreProvider.future);
      final repository = ref.read(salesRepositoryProvider);
      var sale = pending.sale;
      var receipt = sale.payments == null
          ? await repository.recoverLegacyReceipt(sale)
          : null;
      if (receipt == null &&
          sale.payments == null &&
          sale.paymentMethod.toLowerCase() != 'cash') {
        if (!mounted) return;
        final api = OperationsClient.pos(
          ref.read(supabaseProvider),
          business.id,
        );
        final cashContext = await api.cashContext();
        if (!mounted) return;
        final shift = await chooseCashShift(
          context,
          api,
          allowNoDrawer: true,
          cashContext: cashContext,
        );
        if (!mounted) return;
        final draft = await confirmPayment(
          context,
          sale.total,
          sale.paymentMethod,
          recovery: true,
          cashAllowed: cashContext['configured'] != true || shift != null,
        );
        if (draft == null) return;
        if (draft.credit != null)
          throw StateError(
            'Recover the original payment; do not convert a legacy request into new credit.',
          );
        final originalMethod = switch (sale.paymentMethod.toLowerCase()) {
          'transfer' || 'bank_transfer' => 'bank_transfer',
          'pos terminal' || 'card' => 'card',
          _ => sale.paymentMethod.toLowerCase(),
        };
        if (draft.payments.length != 1 ||
            draft.payments.single['method'] != originalMethod)
          throw StateError(
            'Verify the original payment method and amount without collecting a second payment.',
          );
        final current = ref.read(authStateProvider);
        if (!pending.belongsTo(
          current.employee?.userId ?? '',
          current.activeBusiness?.id ?? '',
          current.employee?.membershipId ?? '',
        ))
          throw StateError('Original employee and business required.');
        sale = await PendingSaleSubmission(
          store,
        ).confirmLegacyPayment(pending, draft.payments, shift);
      }
      receipt ??= await PendingSaleSubmission(store).submit(
        userId: employee.userId,
        sale: sale,
        send: repository.completeSale,
      );
      final recoveredReceipt = receipt;
      if (!mounted) return;
      final current = ref.read(authStateProvider);
      if (!pending.belongsTo(
        current.employee?.userId ?? '',
        current.activeBusiness?.id ?? '',
        current.employee?.membershipId ?? '',
      )) {
        throw StateError('The original employee must recover this receipt.');
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Recovered sale receipt'),
          content: SelectableText(
            'Receipt: ${recoveredReceipt.id}\nTotal: ${recoveredReceipt.total}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      final acknowledging = ref.read(authStateProvider);
      if (!pending.belongsTo(
        acknowledging.employee?.userId ?? '',
        acknowledging.activeBusiness?.id ?? '',
        acknowledging.employee?.membershipId ?? '',
      )) {
        throw StateError(
          'The original employee must acknowledge this receipt.',
        );
      }
      await store.acknowledge(pending.sale.id);
      ref.invalidate(pendingSaleProvider);
    } catch (failure) {
      ref.invalidate(pendingSaleProvider);
      if (mounted)
        setState(() => error = 'Recovery could not be verified. $failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(pendingSaleProvider)
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (failure, stack) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to verify pending sale storage. Checkout is paused.',
                ),
                TextButton(
                  onPressed: () => ref.invalidate(pendingSaleProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (pending) => pending == null
            ? widget.child
            : Scaffold(
                appBar: AppBar(title: const Text('Recover pending sale')),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'An interrupted sale must be verified before another checkout.',
                      ),
                      if (error != null) Text(error!),
                      TextButton(
                        onPressed: busy ? null : () => recover(pending),
                        child: Text(
                          busy ? 'Checking…' : 'Check and recover receipt',
                        ),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () =>
                                  ref.read(authStateProvider.notifier).logout(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: TextButton(
                  onPressed: busy ? null : () => cancelWithoutPayment(pending),
                  child: const Text('Cancel only if no payment moved'),
                ),
              ),
      );
}
