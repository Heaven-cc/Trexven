class Business {
  final String id;
  final String businessName;
  final String? businessType;
  final String? address;
  final String? phone;
  final String? country;
  final String? currency;
  final String ownerId;

  Business({
    required this.id,
    required this.businessName,
    this.businessType,
    this.address,
    this.phone,
    this.country,
    this.currency,
    required this.ownerId,
  });

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id']?.toString() ?? '',
      businessName: map['business_name']?.toString() ?? '',
      businessType: map['business_type']?.toString(),
      address: map['address']?.toString(),
      phone: map['phone']?.toString(),
      country: map['country']?.toString(),
      currency: map['currency']?.toString(),
      ownerId: map['owner_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_name': businessName,
      'business_type': businessType,
      'address': address,
      'phone': phone,
      'country': country,
      'currency': currency,
      'owner_id': ownerId,
    };
  }
}
