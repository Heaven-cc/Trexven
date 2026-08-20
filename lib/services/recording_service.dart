import 'package:supabase_flutter/supabase_flutter.dart';

/// CRUD for recordings stored in Supabase.
class RecordingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> _businessId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final row = await _supabase
        .from('businesses')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();
    return row?['id']?.toString();
  }

  Future<List<Map<String, dynamic>>> getRecordings({
    String? cameraId,
    int limit = 60,
  }) async {
    final bizId = await _businessId();
    if (bizId == null) return [];

    var q = _supabase
        .from('recordings')
        .select()
        .eq('business_id', bizId)
        .eq('status', 'ready');
    if (cameraId != null) q = q.eq('camera_id', cameraId);
    final data = await q.order('started_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> deleteRecording(String recordingId) async {
    await _supabase.from('recordings').delete().eq('id', recordingId);
  }
}
