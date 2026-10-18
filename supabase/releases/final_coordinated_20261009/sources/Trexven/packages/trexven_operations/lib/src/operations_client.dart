import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'operation_journal.dart';

class OperationsClient {
  final SupabaseClient client;
  final String businessId;
  final OperationJournal journal;
  final String application;
  OperationsClient(this.client, this.businessId, {OperationJournal? journal})
    : journal = journal ?? OperationJournal(),
      application = 'owner';
  OperationsClient.pos(
    this.client,
    this.businessId, {
    OperationJournal? journal,
  }) : journal = journal ?? OperationJournal(),
       application = 'pos';

  Future<void> reportUnconfirmed() async {
    // Fixed codes only: no customer payload, exception text or credentials.
    try {
      await client
          .rpc(
            'record_trexven_application_error',
            params: {
              'p_business_id': businessId,
              'p_application': application,
              'p_error_code': 'OPERATION_UNCONFIRMED',
            },
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Telemetry must not replace the original outcome or journal. */
    }
  }

  Future<Map<String, dynamic>> cashContext() async => Map<String, dynamic>.from(
    await client.rpc(
          'get_trexven_cash_context',
          params: {'p_business_id': businessId},
        )
        as Map,
  );
  Future<List<Map<String, dynamic>>> list(
    String table, {
    String? foreignKey,
    String? foreignId,
  }) async {
    if (table == 'cash_shifts' && foreignKey == null) {
      return ((await cashContext())['shifts'] as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    }
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      // Products retain the Batch 3 public projection; never request cost fields.
      var query = client
          .from(table)
          .select(
            table == 'products'
                ? 'id,business_id,name,quantity,selling_price,barcode,unit'
                : table == 'employees'
                ? 'id,business_id,user_id,name,role,status'
                : table == 'business_members'
                ? 'id,business_id,user_id,full_name,role,status'
                : '*',
          );
      if (foreignKey != null) {
        query = query.eq(foreignKey, foreignId!);
      } else {
        query = query.eq('business_id', businessId);
      }
      final rows = await query.order('id').range(offset, offset + 199);
      result.addAll(rows.map((x) => Map<String, dynamic>.from(x)));
      if (rows.length < 200) return result;
    }
  }

  Future<dynamic> call(String rpc, Map<String, dynamic> args) async {
    if (!args.containsKey('p_request_id')) return client.rpc(rpc, params: args);
    final user = client.auth.currentUser?.id;
    if (user == null) throw StateError('Sign in before an operation.');
    final reserved = await journal.reserve(user, businessId, rpc, args);
    dynamic response;
    try {
      response = await client.rpc(rpc, params: reserved);
    } catch (_) {
      await reportUnconfirmed();
      rethrow;
    }
    // A verified RPC response is durable server acknowledgement; unresolved
    // transport failures retain the original payload and key for safe recovery.
    await journal.complete(
      user,
      businessId,
      reserved['p_request_id'] as String,
    );
    return response;
  }

  Future<dynamic> recoverPending() async {
    final pending = await journal.pending();
    if (pending == null) return null;
    if (pending['user'] != client.auth.currentUser?.id ||
        pending['business'] != businessId) {
      throw StateError('Recover with the original user and business.');
    }
    final args = Map<String, dynamic>.from(pending['args'] as Map);
    final receipt = await client.rpc(
      'get_trexven_operation_receipt',
      params: {
        'p_business_id': businessId,
        'p_request_id': args['p_request_id'],
      },
    );
    if (receipt != null) {
      await journal.complete(
        pending['user'] as String,
        businessId,
        args['p_request_id'] as String,
      );
      return receipt;
    }
    return call(pending['rpc'] as String, args);
  }

  Future<void> discardUncommitted({required bool noMoneyMoved}) async {
    final pending = await journal.pending();
    if (pending == null) return;
    final user = client.auth.currentUser?.id;
    if (!noMoneyMoved ||
        pending['user'] != user ||
        pending['business'] != businessId) {
      throw StateError(
        'Original context and no-money-moved confirmation required.',
      );
    }
    final request = (pending['args'] as Map)['p_request_id'] as String;
    final result = await client.rpc(
      'cancel_trexven_uncommitted_operation',
      params: {
        'p_business_id': businessId,
        'p_request_id': request,
        'p_no_money_moved': true,
      },
    );
    if ((result as Map)['status'] != 'cancelled')
      throw StateError('Cancellation not confirmed.');
    await journal.complete(user!, businessId, request);
  }

  String requestId() => const Uuid().v4();
  static int moneyCents(String input, {bool allowZero = false}) {
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(input.trim())) {
      throw const FormatException(
        'Enter money with at most two decimal places.',
      );
    }
    final parts = input.trim().split('.');
    final cents =
        int.parse(parts.first) * 100 +
        int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    if (cents < 0 || (!allowZero && cents == 0))
      throw const FormatException('Enter a positive amount.');
    return cents;
  }

  static String amount(int cents) =>
      '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
}
