import 'package:flutter/material.dart';

import '../../models/camera.dart';
import '../../models/camera_event.dart';
import '../../services/camera_ai_service.dart';
import '../../services/camera_intelligence_service.dart';

class CameraAlertsScreen extends StatefulWidget {
  final Camera camera;

  const CameraAlertsScreen({
    super.key,
    required this.camera,
  });

  @override
  State<CameraAlertsScreen> createState() =>
      _CameraAlertsScreenState();
}

class _CameraAlertsScreenState
    extends State<CameraAlertsScreen> {
  final CameraIntelligenceService _intelligenceService = CameraIntelligenceService();
  final CameraAiService _aiService = CameraAiService();
  String? _analyzingEventId;

  Future<void> _askAi(CameraEvent alert) async {
    final eventId = alert.id;
    if (eventId == null || _analyzingEventId != null) return;

    setState(() => _analyzingEventId = eventId);
    try {
      final answer = await _aiService.analyzeSpecificEvent(
        cameraId: widget.camera.id,
        eventId: eventId,
        eventType: alert.eventType,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text('AI analysis'),
            ],
          ),
          content: SingleChildScrollView(child: Text(answer)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not analyze this alert: $e')),
      );
    } finally {
      if (mounted) setState(() => _analyzingEventId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: const Text(
          'Camera Alerts',
          style: TextStyle(
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
                'Could not load alerts.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
              ),
            );
          }

          final events = snapshot.data ?? [];

          final alerts = events
              .where((event) => event.isHighSeverity || event.isSecurityEvent)
              .toList();

          if (alerts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 55,
                      color: Colors.green,
                    ),
                    SizedBox(height: 15),
                    Text(
                      'No active alerts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Important camera intelligence alerts will appear here.',
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
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              return _alertCard(alerts[index]);
            },
          );
        },
      ),
    );
  }

  Widget _alertCard(CameraEvent alert) {
    final severity = alert.severity.toLowerCase();

    final title =
        alert.title ?? alert.eventType;

    final description = alert.description ??
        'Potentially important activity detected.';

    final critical = severity == 'critical';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: critical ? Colors.red.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: critical ? Colors.red.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                critical ? Icons.warning_rounded : Icons.warning_amber_rounded,
                color: critical ? Colors.red : Colors.orange.shade800,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    severity.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                      color: critical ? Colors.red : Colors.orange.shade800,
                    ),
                  ),
                  if (alert.id != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _analyzingEventId == alert.id
                            ? null
                            : () => _askAi(alert),
                        icon: _analyzingEventId == alert.id
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome, size: 16),
                        label: Text(
                          _analyzingEventId == alert.id
                              ? 'Analyzing…'
                              : 'Ask AI to explain',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}