import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/business.dart';
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
      if (verified == null) {
        _selectedBusinesses.remove(user.id);
        throw OwnerAppAccessDenied();
      }
      return verified['id']?.toString();
    }
    final businesses = await _supabase
        .from('businesses')
        .select('id')
        .eq('owner_id', user.id)
        .limit(2);

    if (businesses.length > 1) throw OwnerBusinessSelectionRequired();
    if (businesses.isNotEmpty) return businesses.first['id']?.toString();

    final member = await _supabase
        .from('business_members')
        .select('business_id, status')
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();
    // Membership grants POS access, not ownership of the Owner app.
    // Keep the lookup so staff cannot fall through into new-owner onboarding.
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
      (columns) => _supabase
          .from('products')
          .select(columns)
          .eq('business_id', businessId)
          .order('name'),
    );
    return rows.map(Product.fromMap).toList();
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
    return OperationsClient(
      _supabase,
      businessId,
      journal: _operationJournal,
    ).cashContext();
  }

  Future<dynamic> recoverPendingOperation() async => OperationsClient(
    _supabase,
    await requireBusinessId(),
    journal: _operationJournal,
  ).recoverPending();

  // ============================================================
  // TODAY'S DASHBOARD STATS
  // ============================================================

  Future<Map<String, dynamic>> getTodayStats() async {
    final businessId = await requireBusinessId();
    final day =
        await _supabase.rpc(
              'get_trexven_business_day',
              params: {'p_business_id': businessId},
            )
            as Map;
    final startOfToday = DateTime.parse(day['starts_at'] as String);
    final startOfTomorrow = DateTime.parse(day['ends_at'] as String);

    // ----------------------------------------------------------
    // TODAY'S SALES
    // ----------------------------------------------------------

    final salesResponse = await _supabase
        .from('sales')
        .select('total')
        .eq('business_id', businessId)
        .eq('status', 'completed')
        .gte('created_at', startOfToday.toUtc().toIso8601String())
        .lt('created_at', startOfTomorrow.toUtc().toIso8601String());

    double totalSales = 0;

    for (final sale in salesResponse) {
      totalSales += (sale['total'] as num?)?.toDouble() ?? 0;
    }

    // ----------------------------------------------------------
    // PRODUCT / INVENTORY DATA
    // ----------------------------------------------------------

    final productsResponse = await _supabase
        .from('products')
        .select(
          'id, name, quantity, selling_price, low_stock_threshold, active, is_active',
        )
        .eq('business_id', businessId);

    double stockValue = 0;
    int lowStockCount = 0;

    for (final product in productsResponse) {
      final num quantity = (product['quantity'] as num?) ?? 0;

      final double sellingPrice =
          (product['selling_price'] as num?)?.toDouble() ?? 0;

      final num lowStockThreshold =
          (product['low_stock_threshold'] as num?) ?? 5;

      // Inventory value based on selling price.
      stockValue += quantity * sellingPrice;

      if (product['selling_price'] != null &&
          product['active'] != false &&
          product['is_active'] != false &&
          quantity <= lowStockThreshold) {
        lowStockCount++;
      }
    }

    return {
      'sales': totalSales,
      'transactions': salesResponse.length,
      'stockValue': stockValue,
      'lowStock': lowStockCount,
    };
  }

  Future<Map<String, dynamic>> getDetailedDashboardStats() async {
    final businessId = await requireBusinessId();
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));

    // 1. Sales Data
    final todaySalesRows = await _supabase
        .from('sales')
        .select()
        .eq('business_id', businessId)
        .eq('status', 'completed')
        .gte('created_at', startOfToday.toUtc().toIso8601String())
        .lt('created_at', startOfTomorrow.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    final yesterdaySalesRows = await _supabase
        .from('sales')
        .select('total')
        .eq('business_id', businessId)
        .eq('status', 'completed')
        .gte('created_at', startOfYesterday.toUtc().toIso8601String())
        .lt('created_at', startOfToday.toUtc().toIso8601String());

    double todayTotal = 0;
    for (var r in todaySalesRows) {
      todayTotal += (r['total'] as num?)?.toDouble() ?? 0;
    }

    double yesterdayTotal = 0;
    for (var r in yesterdaySalesRows) {
      yesterdayTotal += (r['total'] as num?)?.toDouble() ?? 0;
    }

    // 2. Products Data
    final productsRows = await _supabase
        .from('products')
        .select()
        .eq('business_id', businessId);
    final products = productsRows.map((e) => Product.fromMap(e)).toList();

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
      final createdAt = DateTime.tryParse(r['created_at'].toString());
      if (createdAt != null) {
        hourlySales[createdAt.toLocal().hour] +=
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
        .where((p) => p.stock <= 2 && p.stock > 0)
        .toList();
    final warningLowStock = products
        .where((p) => p.stock > 2 && p.stock <= p.lowStockThreshold)
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
        'pending': 0,
        'failed': 0,
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
}
