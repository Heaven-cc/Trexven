class Business {
  final String id;
  final String businessName;
  final String? businessType;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? country;
  final String? currency;
  final String? logoUrl;
  final Map<String, dynamic>? businessHours;
  final String ownerId;

  Business({
    required this.id,
    required this.businessName,
    this.businessType,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.country,
    this.currency,
    this.logoUrl,
    this.businessHours,
    required this.ownerId,
  });

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id']?.toString() ?? '',
      businessName: map['business_name']?.toString() ?? '',
      businessType: map['business_type']?.toString(),
      address: map['address']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      website: map['website']?.toString(),
      country: map['country']?.toString(),
      currency: map['currency']?.toString(),
      logoUrl: map['logo_url']?.toString(),
      businessHours: map['business_hours'] as Map<String, dynamic>?,
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
      'email': email,
      'website': website,
      'country': country,
      'currency': currency,
      'logo_url': logoUrl,
      'business_hours': businessHours,
      'owner_id': ownerId,
    };
  }
}
