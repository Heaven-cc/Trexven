class CameraEvent {
  final String? id;
  final String cameraId;
  final String? businessId;

  final String eventType;
  final String? title;
  final String? description;

  final double? confidence;

  final String severity;

  final Map<String, dynamic> metadata;

  final DateTime? detectedAt;
  final DateTime? createdAt;

  final bool reviewed;
  final bool dismissed;

  const CameraEvent({
    this.id,
    required this.cameraId,
    this.businessId,
    required this.eventType,
    this.title,
    this.description,
    this.confidence,
    this.severity = 'info',
    this.metadata = const {},
    this.detectedAt,
    this.createdAt,
    this.reviewed = false,
    this.dismissed = false,
  });

  factory CameraEvent.fromMap(
      Map<String, dynamic> map,
      ) {
    return CameraEvent(
      id: map['id']?.toString(),

      cameraId:
      map['camera_id']?.toString() ?? '',

      businessId:
      map['business_id']?.toString(),

      eventType:
      map['event_type']?.toString() ??
          map['type']?.toString() ??
          'unknown',

      title:
      map['title']?.toString(),

      description:
      map['description']?.toString(),

      confidence:
      map['confidence'] == null
          ? null
          : double.tryParse(
        map['confidence'].toString(),
      ),

      severity:
      map['severity']?.toString() ??
          'info',

      metadata:
      map['metadata'] is Map
          ? Map<String, dynamic>.from(
        map['metadata'],
      )
          : {},

      detectedAt:
      map['detected_at'] != null
          ? DateTime.tryParse(
        map['detected_at'].toString(),
      )
          : map['occurred_at'] != null
          ? DateTime.tryParse(
        map['occurred_at'].toString(),
      )
          : null,

      createdAt:
      map['created_at'] != null
          ? DateTime.tryParse(
        map['created_at'].toString(),
      )
          : null,

      reviewed:
      map['reviewed'] == true,

      dismissed:
      map['dismissed'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'camera_id': cameraId,
      if (businessId != null)
        'business_id': businessId,
      'event_type': eventType,
      'title': title,
      'description': description,
      'confidence': confidence,
      'severity': severity,
      'metadata': metadata,
      'detected_at':
      detectedAt?.toIso8601String(),
      'reviewed': reviewed,
      'dismissed': dismissed,
    };
  }

  CameraEvent copyWith({
    String? id,
    String? cameraId,
    String? businessId,
    String? eventType,
    String? title,
    String? description,
    double? confidence,
    String? severity,
    Map<String, dynamic>? metadata,
    DateTime? detectedAt,
    DateTime? createdAt,
    bool? reviewed,
    bool? dismissed,
  }) {
    return CameraEvent(
      id: id ?? this.id,
      cameraId: cameraId ?? this.cameraId,
      businessId: businessId ?? this.businessId,
      eventType: eventType ?? this.eventType,
      title: title ?? this.title,
      description:
      description ?? this.description,
      confidence:
      confidence ?? this.confidence,
      severity: severity ?? this.severity,
      metadata: metadata ?? this.metadata,
      detectedAt:
      detectedAt ?? this.detectedAt,
      createdAt:
      createdAt ?? this.createdAt,
      reviewed:
      reviewed ?? this.reviewed,
      dismissed:
      dismissed ?? this.dismissed,
    );
  }

  String get confidenceLabel {
    if (confidence == null) {
      return 'Unknown';
    }

    return '${(confidence! * 100).round()}%';
  }

  bool get isHighSeverity =>
      severity.toLowerCase() == 'high' ||
          severity.toLowerCase() == 'critical';

  bool get isMediumSeverity =>
      severity.toLowerCase() == 'medium';

  bool get isLowSeverity =>
      severity.toLowerCase() == 'low';

  bool get isSecurityEvent {
    final type = eventType.toLowerCase();

    return type.contains('theft') ||
        type.contains('suspicious') ||
        type.contains('intrusion') ||
        type.contains('unauthorized') ||
        type.contains('cash') ||
        type.contains('security');
  }
}