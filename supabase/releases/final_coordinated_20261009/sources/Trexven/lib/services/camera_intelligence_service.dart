import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/camera.dart';
import '../models/camera_event.dart';
import 'camera_service.dart';

class CameraIntelligenceService {
  final SupabaseClient _supabase;
  final CameraService _cameraService;

  CameraIntelligenceService({
    SupabaseClient? supabase,
    CameraService? cameraService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _cameraService = cameraService ?? CameraService();

  // ============================================================
  // CAMERAS
  // ============================================================

  Future<List<Camera>> getCameras() async {
    return _cameraService.getCameras();
  }

  Stream<List<Camera>> camerasStream() {
    return _cameraService.camerasStream();
  }

  Future<Camera> addCamera({
    required String name,
    String? location,
    String? deviceId,
  }) async {
    return _cameraService.addCamera(
      name: name,
      location: location,
      deviceId: deviceId,
    );
  }

  Future<void> deleteCamera(String cameraId) {
    return _cameraService.deleteCamera(cameraId);
  }

  Future<void> setAiEnabled(String cameraId, bool enabled) async {
    await _cameraService.updateCamera(
      cameraId: cameraId,
      aiEnabled: enabled,
    );
  }

  // ============================================================
  // CAMERA STATUS
  // ============================================================

  Future<void> setCameraOnline(String cameraId) async {
    await _updateCameraStatus(cameraId, 'online');
  }

  Future<void> setCameraOffline(String cameraId) async {
    await _updateCameraStatus(cameraId, 'offline');
  }

  Future<void> _updateCameraStatus(String cameraId, String status) async {
    await _supabase
        .from('cameras')
        .update({'status': status})
        .eq('id', cameraId);
  }

  // ============================================================
  // EVENTS
  // ============================================================

  Future<List<CameraEvent>> getEvents(String cameraId) async {
    return _cameraService.getCameraEvents(cameraId: cameraId);
  }

  Stream<List<CameraEvent>> eventsStream(String cameraId) {
    return _cameraService.cameraEventsStream(cameraId: cameraId);
  }

  // ============================================================
  // CREATE EVENT THROUGH BACKEND
  // ============================================================

  Future<CameraEvent> createEvent({
    required String cameraId,
    required String eventType,
    String? title,
    String? description,
    double? confidence,
    String severity = 'info',
    Map<String, dynamic>? metadata,
  }) async {
    final businessId = await _cameraService.getCurrentBusinessId();

    if (businessId == null) {
      throw Exception('No business is associated with the current account.');
    }

    final response = await _supabase.functions.invoke(
      'camera-ingest',
      body: {
        'business_id': businessId,
        'camera_id': cameraId,
        'event_type': eventType,
        'confidence': confidence,
        'description': description,
        'metadata': metadata ?? {},
        'occurred_at': DateTime.now().toIso8601String(),
        'severity': severity,
        'source_provider': 'flutter-app',
        'model_name': null,
      },
    );

    final result = response.data;
    if (result is! Map) {
      throw Exception('Camera ingest returned an invalid response.');
    }

    final map = Map<String, dynamic>.from(result);
    if (map['success'] != true || map['event_id'] == null) {
      throw Exception(
        map['error']?.toString() ?? 'Could not create camera event.',
      );
    }

    final eventResponse = await _supabase
        .from('camera_events')
        .select()
        .eq('id', map['event_id'])
        .eq('business_id', businessId)
        .single();

    return CameraEvent.fromMap(Map<String, dynamic>.from(eventResponse));
  }

  // ============================================================
  // REVIEW EVENT
  // ============================================================

  Future<void> markEventReviewed(String eventId) async {
    await _updateEventState(eventId, {
      'reviewed_at': DateTime.now().toIso8601String(),
      'review_status': 'reviewed',
    });
  }

  Future<void> dismissEvent(String eventId) async {
    await _updateEventState(eventId, {
      'reviewed_at': DateTime.now().toIso8601String(),
      'review_status': 'dismissed',
    });
  }

  Future<void> _updateEventState(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    await _supabase.from('camera_events').update(updates).eq('id', eventId);
  }

  // ============================================================
  // RECENT SECURITY EVENTS
  // ============================================================

  Future<List<CameraEvent>> getRecentSecurityEvents() async {
    final businessId = await _cameraService.getCurrentBusinessId();

    if (businessId == null) {
      return [];
    }

    final response = await _supabase
        .from('camera_events')
        .select()
        .eq('business_id', businessId)
        .inFilter('severity', ['high', 'critical'])
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List)
        .map((item) => CameraEvent.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
