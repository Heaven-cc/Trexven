import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';
import 'vision_service.dart';

class IntelligenceEventsService {
  String? warning;
  Future<List<Map<String, dynamic>>> getEvents({String? cameraId}) async {
    final rows = <Map<String, dynamic>>[];
    final failures = <String>[];
    await Future.wait([
      (() async {
        try {
          rows.addAll(
            (await VisionService().getGlobalEvents())
                .where(
                  (row) =>
                      cameraId == null ||
                      (row['camera_ids'] as List).contains(cameraId),
                )
                .map(
                  (row) => {
                    ...row,
                    'occurred_at': row['started_at'],
                    'description': (row['reasoning'] as List).join('; '),
                    'event_source': 'vision_intelligence',
                  },
                ),
          );
        } catch (_) {
          failures.add('Intelligence events');
        }
      })(),
      (() async {
        try {
          rows.addAll(
            (await VisionService().getEvents(
              cameraId: cameraId,
            )).map((row) => {...row, 'event_source': 'vision_local'}),
          );
        } catch (_) {
          failures.add('Vision events');
        }
      })(),
      (() async {
        try {
          final business = await DatabaseService().requireBusinessId();
          var query = Supabase.instance.client
              .from('camera_events')
              .select()
              .eq('business_id', business);
          if (cameraId != null) query = query.eq('camera_id', cameraId);
          rows.addAll(
            (await query.order('occurred_at', ascending: false).limit(100)).map(
              (row) => {...row, 'event_source': 'supabase'},
            ),
          );
          final insights = await Supabase.instance.client
              .from('angel_insights')
              .select('id,metadata')
              .eq('business_id', business)
              .eq('source', 'vision_intelligence')
              .order('created_at', ascending: false)
              .limit(100);
          for (final insight in insights) {
            final metadata = insight['metadata'];
            if (metadata is! Map) continue;
            if (cameraId != null &&
                !(metadata['camera_ids'] as List? ?? []).contains(cameraId))
              continue;
            rows.add({
              ...Map<String, dynamic>.from(metadata),
              'occurred_at': metadata['started_at'],
              'description': (metadata['reasoning'] as List? ?? []).join('; '),
              'event_source': 'vision_intelligence_cloud',
            });
          }
        } catch (_) {
          failures.add('Cloud events');
        }
      })(),
    ]);
    warning = failures.isEmpty
        ? null
        : '${failures.join(' and ')} could not refresh.';
    if (failures.length == 3 && rows.isEmpty)
      throw StateError('Events are unavailable.');
    final localIds = rows
        .where((row) => row['event_source'] == 'vision_intelligence')
        .map((row) => row['id'])
        .toSet();
    rows.removeWhere(
      (row) =>
          row['event_source'] == 'vision_intelligence_cloud' &&
          localIds.contains(row['id']),
    );
    rows.sort(
      (a, b) => (b['occurred_at'] ?? '').toString().compareTo(
        (a['occurred_at'] ?? '').toString(),
      ),
    );
    return rows;
  }

  Future<Map<String, dynamic>> getEvent(String id, String source) async {
    if (source == 'vision_local') return VisionService().getEvent(id);
    if (source == 'vision_intelligence')
      return VisionService().getGlobalEvent(id);
    if (source == 'vision_intelligence_cloud') {
      try {
        return await VisionService().getGlobalEvent(id);
      } catch (_) {
        /* Stored cloud snapshot remains readable. */
      }
      final business = await DatabaseService().requireBusinessId();
      final row = await Supabase.instance.client
          .from('angel_insights')
          .select('metadata')
          .eq('id', id)
          .eq('business_id', business)
          .eq('source', 'vision_intelligence')
          .single();
      final event = Map<String, dynamic>.from(row['metadata'] as Map);
      return {
        'event': event,
        'recordings': event['recording_references'] ?? <Map<String, dynamic>>[],
      };
    }
    final businessId = await DatabaseService().requireBusinessId();
    final event = await Supabase.instance.client
        .from('camera_events')
        .select()
        .eq('id', id)
        .eq('business_id', businessId)
        .single();
    // Existing cloud event payloads may reference a recording in metadata.
    final metadata = event['metadata'];
    final recordingId = metadata is Map ? metadata['recording_id'] : null;
    final recordings = recordingId == null
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await Supabase.instance.client
                .from('recordings')
                .select()
                .eq('id', recordingId)
                .eq('business_id', businessId)
                .eq('status', 'ready'),
          );
    return {'event': event, 'recordings': recordings};
  }
}
