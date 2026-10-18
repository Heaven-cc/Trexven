class Camera {
  final String id;
  final String businessId;
  final String name;
  final String? location;
  final String? deviceId;
  final String? cameraType;
  final String? streamUrl;
  final String? provider;
  final String status;
  final bool isActive;
  final bool aiEnabled;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> settings;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Camera({
    required this.id,
    required this.businessId,
    required this.name,
    this.location,
    this.deviceId,
    this.cameraType,
    this.streamUrl,
    this.provider,
    this.status = 'offline',
    this.isActive = true,
    this.aiEnabled = false,
    this.capabilities = const {},
    this.settings = const {},
    this.lastSeenAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Camera.fromMap(Map<String, dynamic> map) {
    return Camera(
      id: map['id']?.toString() ?? '',
      businessId: map['business_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unnamed Camera',
      location: map['location']?.toString(),
      deviceId: map['device_id']?.toString(),
      cameraType: map['camera_type']?.toString(),
      streamUrl: map['stream_url']?.toString(),
      provider: map['provider']?.toString(),
      status: map['status']?.toString() ?? 'offline',
      isActive: map['is_active'] != false,
      aiEnabled: map['ai_enabled'] == true,
      capabilities: Map<String, dynamic>.from(map['capabilities'] ?? {}),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      lastSeenAt: map['last_seen_at'] != null
          ? DateTime.tryParse(map['last_seen_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'name': name,
      'location': location,
      'device_id': deviceId,
      'camera_type': cameraType,
      'stream_url': streamUrl,
      'provider': provider,
      'status': status,
      'is_active': isActive,
      'ai_enabled': aiEnabled,
      'capabilities': capabilities,
      'settings': settings,
      'last_seen_at': lastSeenAt?.toIso8601String(),
    };
  }

  Camera copyWith({
    String? id,
    String? businessId,
    String? name,
    String? location,
    String? deviceId,
    String? cameraType,
    String? streamUrl,
    String? provider,
    String? status,
    bool? isActive,
    bool? aiEnabled,
    Map<String, dynamic>? capabilities,
    Map<String, dynamic>? settings,
    DateTime? lastSeenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Camera(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      location: location ?? this.location,
      deviceId: deviceId ?? this.deviceId,
      cameraType: cameraType ?? this.cameraType,
      streamUrl: streamUrl ?? this.streamUrl,
      provider: provider ?? this.provider,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      capabilities: capabilities ?? this.capabilities,
      settings: settings ?? this.settings,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isOnline => status.toLowerCase() == 'online';
  bool get isOffline => status.toLowerCase() == 'offline';
  bool get isDegraded => status.toLowerCase() == 'degraded';
}
