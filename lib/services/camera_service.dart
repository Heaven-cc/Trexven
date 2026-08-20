import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/camera.dart';
import '../models/camera_event.dart';

class CameraService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // BUSINESS
  // ============================================================

  Future<String?> getCurrentBusinessId() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final business = await _supabase
        .from('businesses')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    return business?['id']?.toString();
  }

  // ============================================================
  // CAMERAS
  // ============================================================

  Future<List<Camera>> getCameras() async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      return [];
    }

    final response = await _supabase
        .from('cameras')
        .select()
        .eq('business_id', businessId)
        .order('created_at', ascending: true);

    return (response as List).map((map) => Camera.fromMap(map)).toList();
  }

  Stream<List<Camera>> camerasStream() async* {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      yield [];
      return;
    }

    yield* _supabase
        .from('cameras')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId)
        .order('created_at', ascending: true)
        .map((list) => list.map((map) => Camera.fromMap(map)).toList());
  }

  Future<Camera?> getCamera(
    String cameraId,
  ) async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      return null;
    }

    final response = await _supabase
        .from('cameras')
        .select()
        .eq('id', cameraId)
        .eq('business_id', businessId)
        .maybeSingle();

    return response != null ? Camera.fromMap(response) : null;
  }

  Future<Camera> addCamera({
    required String name,
    String? location,
    String cameraType = 'security',
    String? streamUrl,
    String provider = 'manual',
    String? deviceId,
    bool aiEnabled = false,
    Map<String, dynamic>? capabilities,
    Map<String, dynamic>? settings,
  }) async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      throw Exception(
        'No business is associated with the current account.',
      );
    }

    final response = await _supabase.from('cameras').insert({
      'business_id': businessId,
      'name': name,
      'location': location,
      'camera_type': cameraType,
      'stream_url': streamUrl,
      'status': 'offline',
      'is_active': true,
      'ai_enabled': aiEnabled,
      'provider': provider,
      'device_id': deviceId,
      'capabilities': capabilities ?? {},
      'settings': settings ?? {},
    }).select().single();

    return Camera.fromMap(response);
  }

  Future<Camera> updateCamera({
    required String cameraId,
    String? name,
    String? location,
    String? cameraType,
    String? streamUrl,
    String? status,
    bool? isActive,
    bool? aiEnabled,
    String? provider,
    String? deviceId,
    Map<String, dynamic>? capabilities,
    Map<String, dynamic>? settings,
  }) async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      throw Exception(
        'No business is associated with the current account.',
      );
    }

    final Map<String, dynamic> updates = {};

    if (name != null) updates['name'] = name;
    if (location != null) updates['location'] = location;
    if (cameraType != null) updates['camera_type'] = cameraType;
    if (streamUrl != null) updates['stream_url'] = streamUrl;
    if (status != null) updates['status'] = status;
    if (isActive != null) updates['is_active'] = isActive;
    if (aiEnabled != null) updates['ai_enabled'] = aiEnabled;
    if (provider != null) updates['provider'] = provider;
    if (deviceId != null) updates['device_id'] = deviceId;
    if (capabilities != null) {
      updates['capabilities'] = capabilities;
    }
    if (settings != null) {
      updates['settings'] = settings;
    }

    if (updates.isEmpty) {
      final current = await getCamera(cameraId);
      if (current == null) throw Exception('Camera not found');
      return current;
    }

    final response = await _supabase
        .from('cameras')
        .update(updates)
        .eq('id', cameraId)
        .eq('business_id', businessId)
        .select()
        .single();

    return Camera.fromMap(response);
  }

  Future<void> deleteCamera(
    String cameraId,
  ) async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      throw Exception(
        'No business is associated with the current account.',
      );
    }

    await _supabase
        .from('cameras')
        .delete()
        .eq('id', cameraId)
        .eq('business_id', businessId);
  }

  // ============================================================
  // CAMERA EVENTS
  // ============================================================

  Future<List<CameraEvent>> getCameraEvents({
    String? cameraId,
    int limit = 50,
  }) async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      return [];
    }

    var query = _supabase
        .from('camera_events')
        .select()
        .eq('business_id', businessId);

    if (cameraId != null) {
      query = query.eq('camera_id', cameraId);
    }

    final response = await query
        .order('occurred_at', ascending: false)
        .limit(limit);

    return (response as List).map((map) => CameraEvent.fromMap(map)).toList();
  }

  Stream<List<CameraEvent>> cameraEventsStream({
    String? cameraId,
  }) async* {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      yield [];
      return;
    }

    final stream = _supabase
        .from('camera_events')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId);

    if (cameraId == null) {
      yield* stream.map(
          (list) => list.map((map) => CameraEvent.fromMap(map)).toList());
    } else {
      yield* stream
          .eq('camera_id', cameraId)
          .map((list) => list.map((map) => CameraEvent.fromMap(map)).toList());
    }
  }

  Future<List<CameraEvent>> getRecentEvents({
    int limit = 20,
  }) async {
    return getCameraEvents(limit: limit);
  }

  // ============================================================
  // CAMERA DETECTIONS
  // ============================================================

  Future<List<Map<String, dynamic>>> getDetections({
    String? cameraId,
    int limit = 50,
  }) async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      return [];
    }

    var query = _supabase
        .from('camera_detections')
        .select()
        .eq('business_id', businessId);

    if (cameraId != null) {
      query = query.eq('camera_id', cameraId);
    }

    final response = await query
        .order('occurred_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> detectionsStream({
    String? cameraId,
  }) async* {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      yield [];
      return;
    }

    final stream = _supabase
        .from('camera_detections')
        .stream(primaryKey: ['id'])
        .eq('business_id', businessId);

    if (cameraId == null) {
      yield* stream;
    } else {
      yield* stream.eq('camera_id', cameraId);
    }
  }

  // ============================================================
  // CAMERA ZONES
  // ============================================================

  Future<List<Map<String, dynamic>>> getZones({
    String? cameraId,
  }) async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      return [];
    }

    var query = _supabase
        .from('camera_zones')
        .select()
        .eq('business_id', businessId);

    if (cameraId != null) {
      query = query.eq('camera_id', cameraId);
    }

    final response = await query
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addZone({
    required String cameraId,
    required String name,
    required String zoneType,
    List<dynamic>? polygon,
    String? description,
  }) async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      throw Exception(
        'No business is associated with the current account.',
      );
    }

    await _supabase.from('camera_zones').insert({
      'business_id': businessId,
      'camera_id': cameraId,
      'name': name,
      'zone_type': zoneType,
      'polygon': polygon ?? [],
      'description': description,
      'is_active': true,
    });
  }

  Future<void> updateZone({
    required String zoneId,
    String? name,
    String? zoneType,
    List<dynamic>? polygon,
    String? description,
    bool? isActive,
  }) async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      throw Exception(
        'No business is associated with the current account.',
      );
    }

    final Map<String, dynamic> updates = {};

    if (name != null) updates['name'] = name;
    if (zoneType != null) updates['zone_type'] = zoneType;
    if (polygon != null) updates['polygon'] = polygon;
    if (description != null) {
      updates['description'] = description;
    }
    if (isActive != null) {
      updates['is_active'] = isActive;
    }

    if (updates.isEmpty) {
      return;
    }

    await _supabase
        .from('camera_zones')
        .update(updates)
        .eq('id', zoneId)
        .eq('business_id', businessId);
  }

  Future<void> deleteZone(
      String zoneId,
      ) async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      throw Exception(
        'No business is associated with the current account.',
      );
    }

    await _supabase
        .from('camera_zones')
        .delete()
        .eq('id', zoneId)
        .eq('business_id', businessId);
  }

  // ============================================================
  // INTELLIGENCE SUMMARY
  // ============================================================

  Future<Map<String, dynamic>> getIntelligenceSummary() async {
    final businessId = await getCurrentBusinessId();

    if (businessId == null) {
      return {
        'cameras': 0,
        'onlineCameras': 0,
        'events': 0,
        'detections': 0,
        'highSeverityEvents': 0,
      };
    }

    final cameras = await _supabase
        .from('cameras')
        .select('id, status, is_active')
        .eq('business_id', businessId);

    final events = await _supabase
        .from('camera_events')
        .select('id, severity, occurred_at')
        .eq('business_id', businessId);

    final detections = await _supabase
        .from('camera_detections')
        .select('id')
        .eq('business_id', businessId);

    int onlineCameras = 0;
    int highSeverityEvents = 0;

    for (final camera in cameras) {
      if (camera['status'] == 'online' &&
          camera['is_active'] == true) {
        onlineCameras++;
      }
    }

    for (final event in events) {
      final severity =
      event['severity']?.toString().toLowerCase();

      if (severity == 'high' ||
          severity == 'critical') {
        highSeverityEvents++;
      }
    }

    return {
      'cameras': cameras.length,
      'onlineCameras': onlineCameras,
      'events': events.length,
      'detections': detections.length,
      'highSeverityEvents': highSeverityEvents,
    };
  }
}