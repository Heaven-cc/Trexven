import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';

class BusinessDataExport {
  final String actorId;
  final String businessId;
  final String type;
  final List<List<dynamic>> rows;
  const BusinessDataExport({
    required this.actorId, required this.businessId,
    required this.type, required this.rows,
  });
}

/// Owner-only selected-business reads. CSVs are extracts, not restorable backups.
class BusinessDataExportService {
  final SupabaseClient _client;
  final DatabaseService _database;
  BusinessDataExportService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client,
        _database = DatabaseService(client: client);

  Future<void> _verify(String actorId, String businessId) async {
    if (_client.auth.currentUser?.id != actorId ||
        await _database.requireBusinessId().timeout(const Duration(seconds: 20)) != businessId ||
        _client.auth.currentUser?.id != actorId) {
      throw StateError('Export account or selected business changed. Start a new export.');
    }
  }

  Future<void> verifyScope(BusinessDataExport data) =>
      _verify(data.actorId, data.businessId);

  Future<BusinessDataExport> load(String type) async {
    if (type != 'products' && type != 'sales') throw ArgumentError('Unknown export');
    final actorId = _client.auth.currentUser?.id;
    if (actorId == null) throw StateError('Sign in to export your business data.');
    final businessId = await _database.requireBusinessId()
        .timeout(const Duration(seconds: 20));
    await _verify(actorId, businessId);
    final productExport = type == 'products';
    final table = productExport ? 'products' : 'sales';
    final columns = productExport
        ? 'id,business_id,name,category,selling_price,quantity'
        : 'id,business_id,branch_id,sale_number,total,total_amount,status,payment_method,payment_kind,created_at,product_id,quantity';
    final rows = <List<dynamic>>[
      productExport
          ? ['Business ID', 'Product ID', 'Name', 'Category', 'Price', 'Catalog stock']
          : ['Business ID', 'Sale ID', 'Branch ID', 'Sale number', 'Transaction total',
             'Legacy total', 'Status', 'Payment method', 'Payment kind', 'Created at',
             'Legacy product ID', 'Legacy quantity'],
    ];
    String? cursor;
    for (;;) {
      await _verify(actorId, businessId);
      var query = _client.from(table).select(columns).eq('business_id', businessId);
      if (cursor != null) query = query.gt('id', cursor);
      final page = await query.order('id').limit(500)
          .timeout(const Duration(seconds: 20));
      for (final record in page) {
        if (record['business_id'] != businessId ||
            record['id'] is! String || (record['id'] as String).isEmpty) {
          throw StateError('Export scope could not be confirmed.');
        }
        rows.add(productExport
            ? [businessId, record['id'], record['name'], record['category'],
               record['selling_price'], record['quantity']]
            : [businessId, record['id'], record['branch_id'], record['sale_number'],
               record['total'], record['total_amount'], record['status'],
               record['payment_method'], record['payment_kind'], record['created_at'],
               record['product_id'], record['quantity']]);
      }
      if (page.length < 500) break;
      final next = page.last['id'] as String;
      if (cursor != null && next.compareTo(cursor) <= 0) {
        throw StateError('Export pagination could not be confirmed.');
      }
      cursor = next;
    }
    final result = BusinessDataExport(actorId: actorId, businessId: businessId,
      type: type, rows: rows);
    await verifyScope(result);
    return result;
  }

  /// Keep numeric cells numeric; neutralize untrusted string formulas even after
  /// leading whitespace/control characters. CSV quoting alone cannot do this.
  static dynamic csvCell(dynamic value) {
    if (value == null) return '';
    if (value is! String) return value;
    if (RegExp(r'^[\s\u0000-\u001f\u007f\ufeff]*[=+\-@]').hasMatch(value) ||
        RegExp(r'^[\t\r\n]').hasMatch(value)) {
      return "'$value";
    }
    return value;
  }
}
