class Sale {
  final String? id;
  final String? businessId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? employeeId;
  final DateTime? createdAt;

  Sale({
    this.id,
    this.businessId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.employeeId,
    this.createdAt,
  });

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id']?.toString(),
      businessId: map['business_id']?.toString(),
      productId: map['product_id']?.toString() ?? '',
      // `sales` has no product_name column (only `sale_items` does) — this
      // is only populated when the caller merges it in from a product
      // lookup (see DatabaseService.getSales/getSalesStream).
      productName: map['product_name']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      totalPrice: (map['total'] as num?)?.toDouble() ?? 0,
      employeeId: map['employee_id']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(
        map['created_at'].toString(),
      )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (businessId != null) 'business_id': businessId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      // Populate both the "quick sale" flattened total and the classic
      // header totals (subtotal/total) so any reporting reading either
      // convention sees a consistent amount.
      'total_amount': totalPrice,
      'total': totalPrice,
      'subtotal': totalPrice,
      if (employeeId != null) 'employee_id': employeeId,
    };
  }
}
