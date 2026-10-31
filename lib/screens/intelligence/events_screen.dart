import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/intelligence_events_service.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
    this.cameraId,
    this.cameraName,
    this.loadEvents,
  });
  final String? cameraId, cameraName;
  final Future<List<Map<String, dynamic>>> Function()? loadEvents;
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<List<Map<String, dynamic>>> _events;
  final _service = IntelligenceEventsService();
  bool _reviewOnly = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _events =
        widget.loadEvents?.call() ??
        _service.getEvents(cameraId: widget.cameraId);
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _events;
    } catch (_) {
      /* FutureBuilder presents the failure. */
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.cameraName == null ? 'Events' : '${widget.cameraName} Events',
      ),
      actions: [
        IconButton(
          tooltip: _reviewOnly
              ? 'Show all events'
              : 'Show events requiring review',
          icon: Icon(
            _reviewOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
          ),
          onPressed: () => setState(() => _reviewOnly = !_reviewOnly),
        ),
        IconButton(
          tooltip: 'Refresh events',
          onPressed: _refresh,
          icon: Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _events,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const TrexvenSkeleton(kind: TrexvenSkeletonKind.events);
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Unable to load events. Check the server connection.'),
                TextButton(onPressed: _refresh, child: Text('Retry')),
              ],
            ),
          );
        }
        final events = (snapshot.data ?? [])
            .where((event) => !_reviewOnly || event['requires_review'] == true)
            .toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(18),
            children: [
              if (_service.warning != null)
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(_service.warning!),
                ),
              ...events.isEmpty
                  ? [
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No events detected yet.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ]
                  : events.map((event) {
                      final date = DateTime.tryParse(
                        (event['occurred_at'] ??
                                event['detected_at'] ??
                                event['created_at'] ??
                                '')
                            .toString(),
                      )?.toLocal();
                      final label = (event['event_type'] ?? 'Event')
                          .toString()
                          .replaceAll('_', ' ');
                      return Card(
                        child: ListTile(
                          leading: Icon(Icons.visibility_outlined),
                          title: Text(
                            label,
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              if (event['camera_name'] != null)
                                event['camera_name'].toString(),
                              if (date != null)
                                DateFormat('MMM d, h:mm a').format(date),
                              if (event['description'] != null)
                                event['description'].toString(),
                              if (event['severity'] != null)
                                event['severity'].toString(),
                              if (event['state'] != null)
                                event['state'].toString().replaceAll('_', ' '),
                              if (event['requires_review'] == true)
                                'Owner review required',
                            ].join('\n'),
                          ),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(
                                eventId: event['id'].toString(),
                                source:
                                    event['event_source']?.toString() ??
                                    'vision_local',
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
            ],
          ),
        );
      },
    ),
  );
}
