import 'package:supabase_flutter/supabase_flutter.dart';

class CameraAiService {
  final SupabaseClient _supabase;

  CameraAiService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  // ============================================================
  // ANALYZE CAMERA EVENT
  // ============================================================

  Future<Map<String, dynamic>> analyzeEvent({
    required String cameraId,
    required String eventType,
    required Map<String, dynamic> data,
    String? eventId,
  }) async {
    return _invoke({
      'camera_id': cameraId,
      'event_type': eventType,
      'data': data,
      'event_id': ?eventId,
    });
  }

  /// Explain one stored camera event using structured TREXVEN evidence.
  Future<String> analyzeSpecificEvent({
    required String cameraId,
    required String eventId,
    required String eventType,
  }) async {
    final result = await analyzeEvent(
      cameraId: cameraId,
      eventType: eventType,
      data: const {},
      eventId: eventId,
    );
    final answer = result['answer'];
    if (answer == null) {
      throw Exception('Camera AI could not answer for this event.');
    }
    return answer.toString();
  }

  Future<Map<String, dynamic>> _invoke(
    Map<String, dynamic> body,
  ) async {
    final response = await _supabase.functions.invoke(
      'camera-ai',
      body: body,
    );

    final result = response.data;

    if (result == null) {
      throw Exception('Camera AI returned no response.');
    }

    if (result is Map<String, dynamic>) {
      if (result['success'] == false) {
        throw Exception(
          result['error']?.toString() ?? 'Camera AI request failed.',
        );
      }
      return result;
    }

    if (result is Map) {
      final map = Map<String, dynamic>.from(result);
      if (map['success'] == false) {
        throw Exception(
          map['error']?.toString() ?? 'Camera AI request failed.',
        );
      }
      return map;
    }

    throw Exception('Invalid response from camera AI.');
  }
}
