import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/business.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // BUSINESS
  // ============================================================

  Future<String?> getCurrentBusinessId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final business = await _supabase
        .from('businesses')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    return business?['id']?.toString();
  }

  Future<Business?> getBusinessProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return null;

    final response = await _supabase
        .from('businesses')
        .select()
        .eq('owner_id', user.id)
        .maybeSingle();

    if (response == null) return null;

    return Business.fromMap(response);
  }

  // ============================================================
  // PRODUCTS
  // ============================================================

  Stream<List<Product>> getProductsStream() {
    return _supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .order('name')
        .map(
          (data) => data
          .map((map) => Product.fromMap(map))
          .toList(),
    );
  }

  Future<List<Product>> getProducts() async {
    final response = await _supabase
        .from('products')
        .select()
        .order('name');

    return response
        .map<Product>(
          (map) => Product.fromMap(map),
    )
        .toList();
  }

  Future<void> addProduct(Product product) async {
    final businessId = await getCurrentBusinessId();
    if (businessId == null) {
      throw Exception('No business is associated with the current account.');
    }

    final payload = product.toMap()..['business_id'] = businessId;
    await _supabase.from('products').insert(payload);
  }

  Future<void> updateProductStock(
      String productId,
      int newQuantity,
      ) async {
    await _supabase
        .from('products')
        .update({
      'quantity': newQuantity,
    })
        .eq('id', productId);
  }

  // ============================================================
  // SALES
  // ============================================================

  Stream<List<Sale>> getSalesStream() {
    return _supabase
        .from('sales')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map(
          (data) => data
          .map((map) => Sale.fromMap(map))
          .toList(),
    );
  }

  Future<List<Sale>> getSales() async {
    final response = await _supabase
        .from('sales')
        .select()
        .order('created_at', ascending: false);

    return response
        .map<Sale>(
          (map) => Sale.fromMap(map),
    )
        .toList();
  }

  /// `sales` doesn't carry a product name column (that lives on the
  /// separate `sale_items` table, which this app's quick-sale flow doesn't
  /// use) — this fills in each sale's display name from a one-shot products
  /// lookup so the Finance tab can show something better than a blank line.
  Future<List<Sale>> getSalesWithProductNames({int? limit}) async {
    final products = await getProducts();
    final namesById = {
      for (final p in products)
        if (p.id != null) p.id!: p.name,
    };

    var query = _supabase.from('sales').select();
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

  Future<void> recordSale(Sale sale) async {
    final businessId = await getCurrentBusinessId();
    if (businessId == null) {
      throw Exception('No business is associated with the current account.');
    }
    // sales.employee_id is a foreign key to business_members(id), not the
    // auth user id directly — resolve this account's membership row first.
    final userId = _supabase.auth.currentUser?.id;
    String? employeeId;
    if (userId != null) {
      final member = await _supabase
          .from('business_members')
          .select('id')
          .eq('business_id', businessId)
          .eq('user_id', userId)
          .maybeSingle();
      employeeId = member?['id']?.toString();
    }

    // ----------------------------------------------------------
    // 1. Record the sale
    // ----------------------------------------------------------

    final payload = sale.toMap()
      ..['business_id'] = businessId
      ..['employee_id'] = employeeId;

    await _supabase.from('sales').insert(payload);

    // ----------------------------------------------------------
    // 2. Get current product quantity
    // ----------------------------------------------------------

    final productData = await _supabase
        .from('products')
        .select('quantity')
        .eq('id', sale.productId)
        .single();

    final int currentQuantity =
        (productData['quantity'] as num?)?.toInt() ?? 0;

    // ----------------------------------------------------------
    // 3. Deduct sold quantity
    // ----------------------------------------------------------

    final int newQuantity =
        currentQuantity - sale.quantity;

    await updateProductStock(
      sale.productId,
      newQuantity < 0 ? 0 : newQuantity,
    );
  }

  // ============================================================
  // TODAY'S DASHBOARD STATS
  // ============================================================

  Future<Map<String, dynamic>> getTodayStats() async {
    final now = DateTime.now();

    final startOfToday = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final startOfTomorrow = startOfToday.add(
      const Duration(days: 1),
    );

    // ----------------------------------------------------------
    // TODAY'S SALES
    // ----------------------------------------------------------

    final salesResponse = await _supabase
        .from('sales')
        .select('total')
        .gte(
      'created_at',
      startOfToday.toIso8601String(),
    )
        .lt(
      'created_at',
      startOfTomorrow.toIso8601String(),
    );

    double totalSales = 0;

    for (final sale in salesResponse) {
      totalSales +=
          (sale['total'] as num?)?.toDouble() ?? 0;
    }

    // ----------------------------------------------------------
    // PRODUCT / INVENTORY DATA
    // ----------------------------------------------------------

    final productsResponse = await _supabase
        .from('products')
        .select(
      'id, name, quantity, selling_price, cost_price, low_stock_threshold',
    );

    double stockValue = 0;
    int lowStockCount = 0;

    for (final product in productsResponse) {
      final int quantity =
          (product['quantity'] as num?)?.toInt() ?? 0;

      final double sellingPrice =
          (product['selling_price'] as num?)?.toDouble() ?? 0;

      final int lowStockThreshold =
          (product['low_stock_threshold'] as num?)?.toInt() ?? 5;

      // Inventory value based on selling price.
      stockValue += quantity * sellingPrice;

      if (quantity > 0 && quantity <= lowStockThreshold) {
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
}
