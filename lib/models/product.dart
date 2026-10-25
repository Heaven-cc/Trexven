class Product {
  final String? id;
  final String? businessId;
  final String name;
  final double price;
  final bool isPricePending;
  final num stock;
  final String? category;
  final String? brand;
  final String? sku;
  final String? barcode;
  final String? description;
  final String? imageUrl;
  final String unit;
  final bool active;
  final String? catalogGroupId;
  final Map<String, dynamic> variantAttributes;
  final num lowStockThreshold;
  final DateTime? createdAt;

  Product({
    this.id,
    this.businessId,
    required this.name,
    required this.price,
    this.isPricePending = false,
    required this.stock,
    this.category,
    this.brand,
    this.sku,
    this.barcode,
    this.description,
    this.imageUrl,
    this.unit = 'piece',
    this.active = true,
    this.catalogGroupId,
    this.variantAttributes = const {},
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
      isPricePending: map['selling_price'] == null,
      stock: (map['quantity'] as num?) ?? 0,
      category: map['category'],
      brand: map['brand'],
      sku: map['sku'],
      barcode: map['barcode'],
      description: map['description'],
      imageUrl: map['image_url'],
      unit: map['unit'] ?? 'piece',
      active: map['active'] != false && map['is_active'] != false,
      catalogGroupId: map['catalog_group_id'],
      variantAttributes: Map<String, dynamic>.from(
        map['variant_attributes'] ?? {},
      ),
      lowStockThreshold: (map['low_stock_threshold'] as num?) ?? 5,
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
      'selling_price': isPricePending ? null : price,
      'quantity': stock,
      'category': category,
      if (brand != null) 'brand': brand,
      'sku': sku,
      'barcode': barcode,
      'description': description,
      'image_url': imageUrl,
      'unit': unit,
      'active': active,
      if (catalogGroupId != null) 'catalog_group_id': catalogGroupId,
      if (variantAttributes.isNotEmpty) 'variant_attributes': variantAttributes,
      'low_stock_threshold': lowStockThreshold,
    };
  }

  bool get isLowStock =>
      active && !isPricePending && stock <= lowStockThreshold;
  bool get isOutOfStock => stock == 0;
  bool get supportsFractionalQuantity => const {
    'kg',
    'g',
    'litre',
    'ml',
    'metre',
    'cm',
  }.contains(unit.trim().toLowerCase());
}
