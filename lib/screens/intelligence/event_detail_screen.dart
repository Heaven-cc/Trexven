import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/intelligence_events_service.dart';
import '../../services/vision_service.dart';
import '../../services/database_service.dart';
import 'recording_playback_screen.dart';
import '../finance/record_sale_screen.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.source = 'vision_local',
    this.loadEvent,
  });
  final String eventId, source;
  final Future<Map<String, dynamic>> Function()? loadEvent;
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Future<Map<String, dynamic>> _detail;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _detail =
        widget.loadEvent?.call() ??
        IntelligenceEventsService().getEvent(widget.eventId, widget.source);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Event details'),
      actions: [
        IconButton(
          tooltip: 'Refresh event',
          onPressed: () => setState(_load),
          icon: Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Text('Loading…'));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('This event could not be loaded.'),
                TextButton(
                  onPressed: () => setState(_load),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }
        final event = Map<String, dynamic>.from(snapshot.data!['event'] as Map);
        final clips = List<Map<String, dynamic>>.from(
          snapshot.data!['recordings'] as List? ?? [],
        );
        final date = DateTime.tryParse(
          (event['occurred_at'] ??
                  event['started_at'] ??
                  event['created_at'] ??
                  '')
              .toString(),
        )?.toLocal();
        final confidence = num.tryParse(event['confidence']?.toString() ?? '');
        return ListView(
          padding: TrexvenSpacing.cardPadding,
          children: [
            Text(
              (event['event_type'] ?? 'Event').toString().replaceAll('_', ' '),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 12),
            if (event['camera_name'] != null)
              Text(event['camera_name'].toString()),
            if (date != null)
              Text(DateFormat('MMM d, y • h:mm a').format(date)),
            if (event['severity'] != null)
              Text(
                'Severity: ${CustomerPresentation.label(event['severity'])}',
              ),
            if (event['review_status'] != null)
              Text(
                'Status: ${CustomerPresentation.label(event['review_status'])}',
              ),
            if (confidence != null)
              Text('Confidence: ${(confidence * 100).round()}%'),
            if (widget.source.startsWith('vision_intelligence')) ...[
              Text('State: ${CustomerPresentation.label(event['state'])}'),
              Text(
                'Classification: ${CustomerPresentation.label(event['classification'])}',
              ),
              Text(
                'Evidence score: ${((event['intelligence_confidence'] as num? ?? 0) * 100).round()}% (rule score, not a probability)',
              ),
              Text('Cameras: ${(event['camera_ids'] as List? ?? []).length}'),
              if (event['requires_review'] == true)
                Text('Owner review required'),
              if (event['requires_review'] == true &&
                  event['product_id'] != null &&
                  event['related_sale_id'] == null &&
                  [
                    'product_removed',
                    'possible_product_removal',
                  ].contains(event['event_type']))
                TextButton.icon(
                  icon: Icon(Icons.receipt_long),
                  label: Text('Review suggested sale'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecordSaleScreen(
                          submitCartSale: DatabaseService().recordCartSale,
                          suggestedProductId: event['product_id'].toString(),
                          suggestedQuantity: (event['quantity'] as num? ?? 1)
                              .toInt(),
                        ),
                      ),
                    );
                    if (mounted) setState(_load);
                  },
                ),
              SizedBox(height: 12),
              ...(event['reasoning'] as List? ?? []).map(
                (reason) => Text(reason.toString()),
              ),
              SizedBox(height: 12),
              Text(
                'Evidence timeline',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...(event['timeline'] as List? ?? []).map(
                (entry) => ListTile(
                  title: Text(
                    (entry['event_type'] ?? entry['kind'] ?? 'Observation')
                        .toString()
                        .replaceAll('_', ' '),
                  ),
                  subtitle: Text(
                    '${CustomerPresentation.date(entry['timestamp'] ?? entry['occurred_at'], includeTime: true)} · ${entry['camera_id'] ?? ''}',
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Record owner correction',
                onSelected: (classification) async {
                  try {
                    await VisionService().correctGlobalEvent(
                      widget.eventId,
                      classification,
                    );
                    if (mounted) setState(_load);
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Correction requires the business owner and a connected Vision Server.',
                          ),
                        ),
                      );
                  }
                },
                itemBuilder: (_) =>
                    [
                          'legitimate_sale',
                          'returned_product',
                          'incorrect_detection',
                          'employee',
                          'requires_review',
                        ]
                        .map(
                          (value) => PopupMenuItem(
                            value: value,
                            child: Text(value.replaceAll('_', ' ')),
                          ),
                        )
                        .toList(),
                child: ListTile(
                  leading: Icon(Icons.fact_check_outlined),
                  title: Text('Record owner correction'),
                ),
              ),
            ],
            SizedBox(height: TrexvenSpacing.fieldGap),
            if (event['description'] != null)
              Text(event['description'].toString()),
            SizedBox(height: TrexvenSpacing.sectionGap),
            Text(
              'Associated footage',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            if (clips.isEmpty)
              Text(
                'No stored clip is available yet. Qualifying event footage appears after the recording segment finishes. Refresh to check.',
              ),
            ...clips.map(
              (clip) => Card(
                child: ListTile(
                  leading: Icon(Icons.play_circle_outline),
                  title: Text(
                    'Video clip · ${clip['duration_seconds'] ?? '?'}s',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecordingPlaybackScreen(
                        recordingId: clip['id'].toString(),
                        isLocal:
                            clip['source'] != 'supabase' &&
                            widget.source.startsWith('vision_'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
