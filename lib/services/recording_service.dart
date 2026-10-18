import 'database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// CRUD for recordings stored in Supabase.
class RecordingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> _businessId() => DatabaseService().getCurrentBusinessId();

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

  Future<String> getPlaybackUrl(String recordingId) async {
    final businessId = await DatabaseService().requireBusinessId();
    final row = await _supabase.from('recordings').select('storage_path, playback_url')
        .eq('id', recordingId).eq('business_id', businessId).single();
    final path = row['storage_path']?.toString();
    if (path != null && path.isNotEmpty) {
      return _supabase.storage.from('recordings').createSignedUrl(path, 300);
    }
    final url = row['playback_url']?.toString();
    if (url == null || url.isEmpty) throw StateError('Recording is not ready for playback.');
    return url;
  }

  Future<void> deleteRecording(String recordingId) async {
    final businessId = await DatabaseService().requireBusinessId();
    await _supabase.from('recordings').delete().eq('id', recordingId).eq('business_id', businessId).select('id').single();
  }
}
