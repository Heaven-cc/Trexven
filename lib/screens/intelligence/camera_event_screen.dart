import 'package:flutter/material.dart';

import '../../models/camera.dart';
import '../../models/camera_event.dart';
import '../../services/camera_intelligence_service.dart';

class CameraEventsScreen extends StatefulWidget {
  final Camera camera;

  const CameraEventsScreen({
    super.key,
    required this.camera,
  });

  @override
  State<CameraEventsScreen> createState() =>
      _CameraEventsScreenState();
}

class _CameraEventsScreenState
    extends State<CameraEventsScreen> {
  final CameraIntelligenceService _intelligenceService = CameraIntelligenceService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: Text(
          '${widget.camera.name} Events',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: StreamBuilder<List<CameraEvent>>(
        stream: _intelligenceService.eventsStream(
          widget.camera.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load events.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
              ),
            );
          }

          final events = snapshot.data ?? [];

          if (events.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timeline_outlined,
                      size: 55,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 15),
                    Text(
                      'No events detected',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Camera intelligence events will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: events.length,
            itemBuilder: (context, index) {
              return _eventCard(events[index]);
            },
          );
        },
      ),
    );
  }

  Widget _eventCard(CameraEvent event) {
    final eventType = event.eventType;

    final description =
        event.description ?? 'Camera activity detected.';

    final createdAt = event.createdAt;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEFF6FF),
          child: Icon(
            Icons.visibility_outlined,
            color: Color(0xFF2563EB),
          ),
        ),
        title: Text(
          eventType,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(description),
        ),
        trailing: createdAt == null
            ? null
            : Text(
          _formatDate(createdAt),
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}