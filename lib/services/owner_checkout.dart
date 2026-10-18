import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';

/// Owner orchestration of the existing POS transaction contract. The journal
/// stores the original intent before any approval or transaction request.
class OwnerCheckout {
  final SupabaseClient client;
  final OperationJournal journal;
  final String businessId;
  OwnerCheckout(this.client, this.journal, this.businessId);

  Future<dynamic> complete(Map<String, dynamic> args) async {
    final user = client.auth.currentUser?.id;
    if (user == null) throw StateError('Sign in before checkout.');
    final original = await journal.reserve(
      user,
      businessId,
      'complete_trexven_transaction',
      args,
    );
    // Recheck ownership after intent is durable and before using the shared
    // POS contract. Staff membership alone never authorizes the Owner adapter.
    await client
        .from('businesses')
        .select('id')
        .eq('id', businessId)
        .eq('owner_id', user)
        .single()
        .timeout(const Duration(seconds: 20));
    if (client.auth.currentUser?.id != user)
      throw StateError('Account changed. Recover with the original account.');
    final request = original['p_request_id'] as String;
    final receipt = await client
        .rpc(
          'get_trexven_operation_receipt',
          params: {'p_business_id': businessId, 'p_request_id': request},
        )
        .timeout(const Duration(seconds: 30));
    if (receipt != null) {
      await journal.complete(user, businessId, request);
      return receipt;
    }
    return OperationsClient(
      client,
      businessId,
      journal: journal,
    ).call('complete_trexven_transaction', original);
  }
}
