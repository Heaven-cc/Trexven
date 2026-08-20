class Product {
  final String? id;
  final String? businessId;
  final String name;
  final double price;
  final int stock;
  final String? category;
  final String? sku;
  final double? costPrice;
  final int lowStockThreshold;
  final DateTime? createdAt;

  Product({
    this.id,
    this.businessId,
    required this.name,
    required this.price,
    required this.stock,
    this.category,
    this.sku,
    this.costPrice,
    this.lowStockThreshold = 5,
    this.createdAt,
  });

  // NOTE: the `products` table's real columns are `selling_price` and
  // `quantity` (this app's `price`/`stock` are just friendlier Dart-side
  // names for the same data) — map to those, not `price`/`stock` literally.
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString(),
      businessId: map['business_id']?.toString(),
      name: map['name'] ?? '',
      price: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
      stock: (map['quantity'] as num?)?.toInt() ?? 0,
      category: map['category'],
      sku: map['sku'],
      costPrice: (map['cost_price'] as num?)?.toDouble(),
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toInt() ?? 5,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      'name': name,
      'selling_price': price,
      'quantity': stock,
      'category': category,
      'sku': sku,
      // `cost_price` is NOT NULL with a default of 0 — sending an explicit
      // null would override the default and violate the constraint, so omit
      // it entirely when unset rather than sending `cost_price: null`.
      if (costPrice != null) 'cost_price': costPrice,
      'low_stock_threshold': lowStockThreshold,
    };
  }

  bool get isLowStock => stock > 0 && stock <= lowStockThreshold;
  bool get isOutOfStock => stock == 0;
}
