import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/business.dart';
import 'owner_checkout.dart';
import 'business_reporting.dart';
import 'package:trexven_operations/trexven_operations.dart';

class OwnerAppAccessDenied extends StateError {
  OwnerAppAccessDenied()
    : super(
        'TREXVEN is for business owners. Use TREXVEN POS for employee access.',
      );
}

class OwnerBusinessSelectionRequired extends StateError {
  OwnerBusinessSelectionRequired() : super('Select one of your businesses.');
}

class OwnerOperationRecoveryRequired extends StateError {
  final bool canRecoverHere;
  OwnerOperationRecoveryRequired({required this.canRecoverHere})
    : super(
        canRecoverHere
            ? 'Recover the interrupted operation before confirming another payment.'
            : 'Return to the original user and business to recover the interrupted operation before confirming another payment.',
      );
}

class DatabaseService {
  static const catalogProductColumns =
      'id,business_id,name,selling_price,quantity,category,sku,barcode,description,image_url,unit,active,is_active,catalog_group_id,variant_attributes,low_stock_threshold,created_at';
  static const productColumns =
      'id,business_id,name,selling_price,quantity,category,sku,barcode,description,image_url,unit,active,is_active,low_stock_threshold,created_at';
  static final Map<String, String> _selectedBusinesses = {};
  final SupabaseClient _supabase;
  final OperationJournal _operationJournal;
  bool _legacyProjection = false;
  Map<String, String>? _checkoutScope;
  DatabaseService({SupabaseClient? client, OperationJournal? operationJournal})
    : _supabase = client ?? Supabase.instance.client,
      _operationJournal = operationJournal ?? OperationJournal();

  // ============================================================
  // BUSINESS
  // ============================================================

  Future<String?> getCurrentBusinessId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final selected = _selectedBusinesses[user.id];
    if (selected != null) {
      final verified = await _supabase
          .from('businesses')
          .select('id')
          .eq('owner_id', user.id)
          .eq('id', selected)
          .maybeSingle();
      if (verified != null) {
        return verified['id']?.toString();
      }
      _selectedBusinesses.remove(user.id);
    }

    final businesses = await _supabase
        .from('businesses')
        .select('id')
        .eq('owner_id', user.id)
        .order('created_at')
        .limit(10);

    if (businesses.isNotEmpty) {
      final defaultId = businesses.first['id']?.toString();
      if (defaultId != null) {
        _selectedBusinesses[user.id] = defaultId;
        return defaultId;
      }
    }

    final member = await _supabase
        .from('business_members')
        .select('business_id, status')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();
    if (member != null) throw OwnerAppAccessDenied();
    return null;
  }

  Future<List<Map<String, dynamic>>> getOwnedBusinesses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw OwnerAppAccessDenied();
    return await _supabase
        .from('businesses')
        .select('id,business_name')
        .eq('owner_id', user.id)
        .order('created_at');
  }

  Future<void> selectOwnedBusiness(String id) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw OwnerAppAccessDenied();
    final owned = await _supabase
        .from('businesses')
        .select('id')
        .eq('owner_id', user.id)
        .eq('id', id)
        .maybeSingle();
    if (owned == null) throw OwnerAppAccessDenied();
    _selectedBusinesses[user.id] = id;
  }

  Future<bool> hasUnresolvedOperation() async =>
      await _operationJournal.pending() != null;

  void clearBusinessSelection() {
    final user = _supabase.auth.currentUser;
    if (user != null) _selectedBusinesses.remove(user.id);
  }

  Future<Business?> getBusinessProfile() async {
    final id = await getCurrentBusinessId();
    if (id == null) return null;
    final row = await _supabase
        .from('businesses')
        .select()
        .eq('id', id)
        .single();
    return Business.fromMap(row);
  }

  Future<String> requireBusinessId() async {
    final id = await getCurrentBusinessId();
    if (id == null) {
      throw StateError('No business is associated with this account.');
    }
    return id;
  }

  Future<void> updateBusinessProfile(Business business) async {
    final response = await _supabase
        .from('businesses')
        .update(
          business.toMap()
            ..remove('id')
            ..remove('owner_id'),
        )
        .eq('id', business.id)
        .select()
        .maybeSingle();

    if (response == null) {
      throw Exception(
        'Failed to update business profile. No rows were affected.',
      );
    }
  }

  Future<void> updateUserProfile({String? name, String? phone}) async {
    final Map<String, dynamic> updates = {};
    if (name != null) updates['full_name'] = name;
    if (phone != null) updates['phone'] = phone;

    if (updates.isNotEmpty) {
      await _supabase.auth.updateUser(UserAttributes(data: updates));
    }

    // If there was a separate profiles table, we'd update it here too.
    // Based on my grep, everything seems metadata-driven for now.
  }

  // ============================================================
  // PRODUCTS
  // ============================================================

  Stream<List<Product>> getProductsStream() async* {
    final businessId = await requireBusinessId();
    // Column-restricted products cannot use SupabaseStream's SELECT *.
    // Realtime only invalidates this projection; payloads never enter models.
    final changes = StreamController<void>();
    final channel = _supabase
        .channel('owner-products-$businessId-${identityHashCode(changes)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (_) {
            if (!changes.isClosed) changes.add(null);
          },
        )
        .subscribe();
    try {
      yield await _productsForBusiness(businessId);
      await for (final _ in changes.stream) {
        yield await _productsForBusiness(businessId);
      }
    } finally {
      await _supabase.removeChannel(channel);
      await changes.close();
    }
  }

  Future<List<Product>> _productsForBusiness(String businessId) async {
    final rows = await _catalogProjection(
      (columns) => _readDashboardPages(
        (start, end) => _supabase
            .from('products')
            .select(columns)
            .eq('business_id', businessId)
            .order('name')
            .order('id')
            .range(start, end),
      ),
    );
    return rows.map(Product.fromMap).toList();
  }

  // Keep authorized totals complete beyond PostgREST's default row limit.
  // A failed page rejects the load; partial totals are never presented.
  Future<List<Map<String, dynamic>>> _readDashboardPages(
    Future<List<Map<String, dynamic>>> Function(int, int) load,
  ) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    for (var start = 0; ; start += pageSize) {
      final page = await load(start, start + pageSize - 1);
      rows.addAll(page);
      if (page.length < pageSize) return rows;
    }
  }

  Future<T> _catalogProjection<T>(Future<T> Function(String) load) async {
    if (_legacyProjection) return await load(productColumns);
    try {
      return await load(catalogProductColumns);
    } on PostgrestException catch (e) {
      if ((e.code == '42703' || e.code == 'PGRST204') &&
          (e.message.contains('catalog_group_id') ||
              e.message.contains('variant_attributes'))) {
        _legacyProjection = true;
        return await load(productColumns);
      }
      rethrow;
    }
  }

  Future<List<Product>> getProducts() async =>
      _productsForBusiness(await requireBusinessId());

  Future<void> addProduct(Product product) async {
    final businessId = await getCurrentBusinessId();
    if (businessId == null) {
      throw Exception('No business is associated with the current account.');
    }

    final fields = product.toMap()
      ..remove('id')
      ..remove('business_id')
      ..remove('quantity');
    await _supabase.rpc(
      'import_trexven_catalog',
      params: {
        'p_business_id': businessId,
        'p_request_id': product.id ?? const Uuid().v4(),
        'p_rows': [
          {...fields, 'initial_quantity': product.stock},
        ],
      },
    );
  }

  Future<void> adjustProductStock(
    String productId,
    num delta,
    String reason,
    String requestId,
  ) async {
    final business = await requireBusinessId();
    await _supabase.rpc(
      'adjust_trexven_catalog_stock',
      params: {
        'p_business_id': business,
        'p_product_id': productId,
        'p_delta': delta.toString(),
        'p_reason': reason,
        'p_request_id': requestId,
      },
    );
  }

  Future<void> updateProductStock(String productId, int newQuantity) async {
    // Compatibility caller: derive a delta once; new restock UI sends its intent directly.
    final products = await getProducts();
    final product = products.firstWhere((p) => p.id == productId);
    await adjustProductStock(
      productId,
      newQuantity - product.stock,
      'Owner stock adjustment',
      const Uuid().v4(),
    );
  }

  Future<String> saveCatalogProduct(
    String? id,
    Map<String, dynamic> fields,
    String requestId,
  ) async {
    return await _supabase.rpc(
          'save_trexven_catalog_product',
          params: {
            'p_business_id': await requireBusinessId(),
            'p_product_id': id,
            'p_fields': fields,
            'p_request_id': requestId,
          },
        )
        as String;
  }

  Future<List<Map<String, dynamic>>> getProductGroups() async => await _supabase
      .from('product_groups')
      .select('id,name')
      .eq('business_id', await requireBusinessId())
      .order('name');

  Future<String> saveProductGroup(String name, {String? id}) async =>
      await _supabase.rpc(
            'save_trexven_product_group',
            params: {
              'p_business_id': await requireBusinessId(),
              'p_group_id': id ?? const Uuid().v4(),
              'p_name': name,
            },
          )
          as String;

  Future<List<Map<String, dynamic>>> productMovements(
    String id,
  ) async => await _supabase
      .from('inventory_movements')
      .select(
        'id,movement_type,quantity,previous_quantity,new_quantity,reason,created_at',
      )
      .eq('business_id', await requireBusinessId())
      .eq('product_id', id)
      .order('created_at', ascending: false);

  Future<void> importCatalog(
    List<Map<String, dynamic>> rows,
    String requestId,
  ) async {
    await _supabase.rpc(
      'import_trexven_catalog',
      params: {
        'p_business_id': await requireBusinessId(),
        'p_request_id': requestId,
        'p_rows': rows,
      },
    );
  }

  // ============================================================
  // SALES
  // ============================================================

  Stream<List<Sale>> getSalesStream() async* {
    final businessId = await requireBusinessId();
    yield* _supabase
        .from('sales')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('created_at')
        .map((data) => data.map((map) => Sale.fromMap(map)).toList());
  }

  Future<List<Sale>> getSales() async {
    final businessId = await requireBusinessId();
    final response = await _supabase
        .from('sales')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: false);

    return response.map<Sale>((map) => Sale.fromMap(map)).toList();
  }

  /// `sales` doesn't carry a product name column (that lives on the
  /// separate `sale_items` table, which this app's quick-sale flow doesn't
  /// use) — this fills in each sale's display name from a one-shot products
  /// lookup so the Finance tab can show something better than a blank line.
  Future<List<Sale>> getSalesWithProductNames({int? limit}) async {
    final businessId = await requireBusinessId();
    final products = await getProducts();
    final namesById = {
      for (final p in products)
        if (p.id != null) p.id!: p.name,
    };

    var query = _supabase.from('sales').select().eq('business_id', businessId);
    final response = await query.order('created_at', ascending: false);
    final rows = limit != null ? response.take(limit).toList() : response;

    return rows.map<Sale>((map) {
      final sale = Sale.fromMap(map);
      final resolvedName = namesById[sale.productId];
      if (resolvedName == null || sale.productName.isNotEmpty) return sale;
      return Sale(
        id: sale.id,
        businessId: sale.businessId,
        productId: sale.productId,
        productName: resolvedName,
        quantity: sale.quantity,
        unitPrice: sale.unitPrice,
        totalPrice: sale.totalPrice,
        employeeId: sale.employeeId,
        createdAt: sale.createdAt,
      );
    }).toList();
  }

  Future<String> recordSale(
    Sale sale, {
    required String requestId,
    String paymentMethod = 'cash',
    List<Map<String, dynamic>>? payments,
    String? shiftId,
  }) async {
    if (!sale.quantity.isFinite ||
        sale.quantity <= 0 ||
        !sale.unitPrice.isFinite ||
        sale.unitPrice < 0) {
      throw ArgumentError('Sale quantity and price must be valid.');
    }
    final businessId = await requireBusinessId();
    if (payments != null) {
      final receipt =
          await OperationsClient(
            _supabase,
            businessId,
            journal: _operationJournal,
          ).call('record_confirmed_trexven_owner_sale', {
            'p_request_id': requestId,
            'p_business_id': businessId,
            'p_product_id': sale.productId,
            'p_units': sale.quantity,
            'p_unit_price': sale.unitPrice,
            'p_payments': payments,
            'p_shift_id': shiftId,
          });
      return (receipt as Map)['sale_number'] as String;
    }
    if (sale.quantity != sale.quantity.truncate()) {
      throw ArgumentError(
        'Fractional sales require the confirmed-payment checkout.',
      );
    }
    final receipt = await _supabase.rpc(
      'submit_trexven_sale',
      params: {
        'p_request_id': requestId,
        'p_business_id': businessId,
        'p_employee_id': null,
        'p_total': double.parse(
          (sale.quantity * sale.unitPrice).toStringAsFixed(2),
        ),
        'p_payment_method': paymentMethod,
        'p_items': [
          {
            'product_id': sale.productId,
            'quantity': sale.quantity,
            'unit_price': sale.unitPrice,
            'discount': 0,
          },
        ],
        'p_quick': true,
      },
    );
    return (receipt as Map)['sale_number'] as String;
  }

  Future<Map<String, dynamic>> saleCashContext() async {
    final businessId = await requireBusinessId();
    final pending = await _operationJournal.pending();
    if (pending != null) {
      throw OwnerOperationRecoveryRequired(
        canRecoverHere:
            pending['user'] == _supabase.auth.currentUser?.id &&
            pending['business'] == businessId,
      );
    }
    final user = _supabase.auth.currentUser!.id;
    final member = await _supabase
        .from('business_members')
        .select('id')
        .eq('business_id', businessId)
        .eq('user_id', user)
        .eq('status', 'active')
        .single();
    final context = await OperationsClient(
      _supabase,
      businessId,
      journal: _operationJournal,
    ).cashContext();
    final day =
        await _supabase.rpc(
              'get_trexven_business_day',
              params: {'p_business_id': businessId},
            )
            as Map;
    if (_supabase.auth.currentUser?.id != user) throw OwnerAppAccessDenied();
    _checkoutScope = {
      'user': user,
      'business': businessId,
      'member': member['id'] as String,
    };
    return {...context, 'local_date': day['local_date']};
  }

  Future<String> recordCartSale({
    required String requestId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    required double total,
    Map<String, dynamic>? credit,
    String? shiftId,
  }) async {
    var scope = _checkoutScope;
    if (scope == null) {
      await saleCashContext();
      scope = _checkoutScope!;
    }
    final user = _supabase.auth.currentUser?.id;
    final businessId = scope['business']!;
    if (user != scope['user'] ||
        (_selectedBusinesses[user] ?? businessId) != businessId) {
      throw OwnerOperationRecoveryRequired(canRecoverHere: false);
    }
    final receipt =
        await OwnerCheckout(_supabase, _operationJournal, businessId).complete({
          'p_request_id': requestId,
          'p_business_id': businessId,
          'p_employee_id': scope['member'],
          'p_total': total,
          'p_items': items,
          'p_payments': payments,
          'p_credit': credit,
          'p_branch_id': null,
          'p_shift_id': shiftId,
        });
    return (receipt as Map)['sale_number'] as String;
  }

  Future<void> approveCartCredit(
    String approvalId, {
    String? overLimitReason,
  }) async {
    final businessId = await requireBusinessId();
    await _supabase
        .from('credit_approvals')
        .select('id')
        .eq('business_id', businessId)
        .eq('id', approvalId)
        .single();
    await _supabase.rpc(
      'decide_trexven_credit_approval',
      params: {
        'p_approval_id': approvalId,
        'p_approve': true,
        'p_over_limit_reason': overLimitReason,
      },
    );
  }

  Future<dynamic> recoverPendingOperation() async {
    final businessId = await requireBusinessId();
    final pending = await _operationJournal.pending();
    if (pending != null && pending['rpc'] == 'complete_trexven_transaction') {
      if (pending['user'] != _supabase.auth.currentUser?.id ||
          pending['business'] != businessId) {
        throw StateError('Recover with the original user and business.');
      }
      return OwnerCheckout(
        _supabase,
        _operationJournal,
        businessId,
      ).complete(Map<String, dynamic>.from(pending['args'] as Map));
    }
    return OperationsClient(
      _supabase,
      businessId,
      journal: _operationJournal,
    ).recoverPending();
  }

  // ============================================================
  // TODAY'S DASHBOARD STATS
  // ============================================================

  Future<Map<String, dynamic>> getTodayStats() async {
    final report = await getFinanceReport('today');
    final products = await getProducts();
    return {
      'sales': financialNumber(report.summary['gross_sales']),
      'transactions': report.sales.length,
      'stockValue': products.fold<double>(
        0,
        (sum, p) => sum + p.stock * p.price,
      ),
      'lowStock': products.where((p) => p.isLowStock).length,
    };
  }

  Future<Map<String, dynamic>> getDetailedDashboardStats() async {
    final businessId = await requireBusinessId();
    final day = await getBusinessDay();
    final todayPeriod = BusinessPeriod.fromDay(day, 'today');
    final yesterdayPeriod = BusinessPeriod.fromDay(day, 'yesterday');
    final startOfToday = todayPeriod.start;
    final startOfTomorrow = todayPeriod.end;
    final startOfYesterday = yesterdayPeriod.start;

    List<Map<String, dynamic>> todaySalesRows = [];
    List<Map<String, dynamic>> yesterdaySalesRows = [];
    List<Product> products = [];

    // 1. Sales Data
    todaySalesRows = await _readDashboardPages(
      (start, end) => _supabase
          .from('sales')
          .select()
          .eq('business_id', businessId)
          .or(
            'and(sold_at.gte.${startOfToday.toIso8601String()},sold_at.lt.${startOfTomorrow.toIso8601String()}),and(sold_at.is.null,created_at.gte.${startOfToday.toIso8601String()},created_at.lt.${startOfTomorrow.toIso8601String()})',
          )
          .order('created_at', ascending: false)
          .order('id')
          .range(start, end),
    );
    yesterdaySalesRows = await _readDashboardPages(
      (start, end) => _supabase
          .from('sales')
          .select('total')
          .eq('business_id', businessId)
          .or(
            'and(sold_at.gte.${startOfYesterday.toIso8601String()},sold_at.lt.${startOfToday.toIso8601String()}),and(sold_at.is.null,created_at.gte.${startOfYesterday.toIso8601String()},created_at.lt.${startOfToday.toIso8601String()})',
          )
          .order('id')
          .range(start, end),
    );
    // 2. Products Data
    products = await _productsForBusiness(businessId);

    double todayTotal = 0;
    for (var r in todaySalesRows) {
      todayTotal += (r['total'] as num?)?.toDouble() ?? 0;
    }

    double yesterdayTotal = 0;
    for (var r in yesterdaySalesRows) {
      yesterdayTotal += (r['total'] as num?)?.toDouble() ?? 0;
    }

    final namesById = {
      for (final p in products)
        if (p.id != null) p.id!: p.name,
    };

    final todaySales = todaySalesRows.map((e) {
      final sale = Sale.fromMap(e);
      return Sale(
        id: sale.id,
        businessId: sale.businessId,
        productId: sale.productId,
        productName: namesById[sale.productId] ?? 'Unknown Product',
        quantity: sale.quantity,
        unitPrice: sale.unitPrice,
        totalPrice: sale.totalPrice,
        employeeId: sale.employeeId,
        createdAt: sale.createdAt,
      );
    }).toList();

    final todayAvg = todaySales.isEmpty ? 0.0 : todayTotal / todaySales.length;

    // Hourly sales for today
    final List<double> hourlySales = List.filled(24, 0.0);
    for (var r in todaySalesRows) {
      final createdAt = DateTime.tryParse(
        (r['sold_at'] ?? r['created_at']).toString(),
      );
      if (createdAt != null) {
        hourlySales[todayPeriod.local(createdAt).hour] +=
            (r['total'] as num?)?.toDouble() ?? 0;
      }
    }

    double totalInventoryValue = 0;
    num totalUnits = 0;
    int addedToday = 0;
    for (var p in products) {
      totalInventoryValue += p.stock * p.price;
      totalUnits += p.stock;
      if (p.createdAt != null && p.createdAt!.isAfter(startOfToday)) {
        addedToday++;
      }
    }

    final sortedByValue = List<Product>.from(products)
      ..sort((a, b) => (b.stock * b.price).compareTo(a.stock * a.price));
    final top3Products = sortedByValue.take(3).toList();

    final criticalLowStock = products
        .where((p) => p.isLowStock && p.stock <= 2)
        .toList();
    final warningLowStock = products
        .where((p) => p.isLowStock && p.stock > 2)
        .toList();

    return {
      'sales': {
        'totalToday': todayTotal,
        'countToday': todaySales.length,
        'avgToday': todayAvg,
        'totalYesterday': yesterdayTotal,
        'countYesterday': yesterdaySalesRows.length,
        'recent': todaySales.take(5).toList(),
        'hourly': hourlySales,
      },
      'transactions': {
        'successful': todaySales.length,
        'totalValue': todayTotal,
        'recent': todaySales.take(5).toList(),
      },
      'inventory': {
        'totalValue': totalInventoryValue,
        'totalUnits': totalUnits,
        'productCount': products.length,
        'addedToday': addedToday,
        'topProducts': top3Products,
      },
      'lowStock': {
        'critical': criticalLowStock,
        'warning': warningLowStock,
        'totalCount': criticalLowStock.length + warningLowStock.length,
      },
    };
  }

  Future<Map<String, dynamic>> getBusinessDay() async {
    final res = await _supabase.rpc(
      'get_trexven_business_day',
      params: {'p_business_id': await requireBusinessId()},
    );
    if (res is! Map ||
        res['timezone'] is! String ||
        res['local_date'] is! String) {
      throw StateError('The business calendar is unavailable. Please retry.');
    }
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> getFinancialSales(
    BusinessPeriod period, {
    int? offset,
    int pageSize = 100,
  }) async {
    final business = await requireBusinessId();
    Future<List<Map<String, dynamic>>> page(
      int start,
      int end,
    ) async => List<Map<String, dynamic>>.from(
      await _supabase
          .from('sales')
          .select(
            'id,total,created_at,sold_at,status,payment_method,payment_kind,sale_items(product_id,product_name,quantity,unit_price)',
          )
          .eq('business_id', business)
          .or(
            'and(sold_at.gte.${period.start.toIso8601String()},sold_at.lt.${period.end.toIso8601String()}),and(sold_at.is.null,created_at.gte.${period.start.toIso8601String()},created_at.lt.${period.end.toIso8601String()})',
          )
          .order('created_at', ascending: false)
          .order('id')
          .range(start, end),
    );
    if (offset != null) return page(offset, offset + pageSize - 1);
    return _readDashboardPages(page);
  }

  Future<List<Map<String, dynamic>>> getExpenses(BusinessPeriod period) async {
    final business = await requireBusinessId();
    return _readDashboardPages(
      (start, end) async => List<Map<String, dynamic>>.from(
        await _supabase
            .from('expenses')
            .select('id,category,description,amount,payment_method,created_at')
            .eq('business_id', business)
            .gte('created_at', period.start.toIso8601String())
            .lt('created_at', period.end.toIso8601String())
            .order('created_at', ascending: false)
            .order('id')
            .range(start, end),
      ),
    );
  }

  Future<FinanceReport> getFinanceReport(
    String duration, {
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final period = BusinessPeriod.fromDay(
      await getBusinessDay(),
      duration,
      customStart: customStart,
      customEnd: customEnd,
    );
    final business = await requireBusinessId();

    final summaryRes = await _supabase.rpc(
      'get_trexven_financial_summary',
      params: {
        'p_business_id': business,
        'p_start': period.start.toIso8601String(),
        'p_end': period.end.toIso8601String(),
      },
    );
    if (summaryRes is! Map) {
      throw StateError('The financial summary is unavailable. Please retry.');
    }
    final rows = await Future.wait([
      getFinancialSales(period),
      getExpenses(period),
    ]);
    return FinanceReport(
      period,
      Map<String, dynamic>.from(summaryRes),
      rows[0],
      rows[1],
    );
  }
}
