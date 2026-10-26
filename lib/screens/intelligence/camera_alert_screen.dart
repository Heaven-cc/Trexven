import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:flutter/material.dart';

import '../../models/camera.dart';
import '../../models/camera_event.dart';
import '../../services/camera_ai_service.dart';
import '../../services/camera_intelligence_service.dart';

class CameraAlertsScreen extends StatefulWidget {
  final Camera camera;

  const CameraAlertsScreen({super.key, required this.camera});

  @override
  State<CameraAlertsScreen> createState() => _CameraAlertsScreenState();
}

class _CameraAlertsScreenState extends State<CameraAlertsScreen> {
  final CameraIntelligenceService _intelligenceService =
      CameraIntelligenceService();
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
          scrollable: true,
          title: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: TrexvenTheme.primaryBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text('AI analysis'),
            ],
          ),
          content: SingleChildScrollView(child: Text(answer)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CustomerPresentation.error(
              e,
              fallback: 'Could not analyze this alert. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _analyzingEventId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted!;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Camera Alerts',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: StreamBuilder<List<CameraEvent>>(
        stream: _intelligenceService.eventsStream(widget.camera.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                CustomerPresentation.error(
                  snapshot.error,
                  fallback: 'We could not load your alerts. Please try again.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Loading…'));
          }

          final events = snapshot.data ?? [];

          final alerts = events
              .where((event) => event.isHighSeverity || event.isSecurityEvent)
              .toList();

          if (alerts.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 55,
                      color: theme.trexvenColors.success!,
                    ),
                    SizedBox(height: TrexvenSpacing.fieldGap),
                    Text(
                      'No active alerts',
                      style: TextStyle(
                        fontSize: TrexvenFontSize.section,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Important camera intelligence alerts will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(18),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              return _alertCard(theme, alerts[index]);
            },
          );
        },
      ),
    );
  }

  Widget _alertCard(ThemeData theme, CameraEvent alert) {
    final severity = alert.severity.toLowerCase();
    final brandBlue = theme.colorScheme.primary;

    final title = alert.title ?? alert.eventType;

    final description =
        alert.description ?? 'Potentially important activity detected.';

    final critical = severity == 'critical';
    final warningColor = theme.trexvenColors.warning!;
    final errorColor = theme.trexvenColors.error!;

    final severityColor = critical ? errorColor : warningColor;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: theme.trexvenColors.cardBackground,
      child: Padding(
        padding: TrexvenSpacing.cardPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(TrexvenRadii.card),
              ),
              child: Icon(
                critical ? Icons.warning_rounded : Icons.warning_amber_rounded,
                color: severityColor,
              ),
            ),
            SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: TrexvenFontSize.input,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    severity.toUpperCase(),
                    style: TextStyle(
                      fontSize: TrexvenFontSize.caption,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                      color: severityColor,
                    ),
                  ),
                  if (alert.id != null) ...[
                    SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _analyzingEventId == alert.id
                            ? null
                            : () => _askAi(alert),
                        icon: _analyzingEventId == alert.id
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: Icon(Icons.more_horiz_rounded, size: 16),
                              )
                            : Icon(Icons.auto_awesome, size: 16),
                        label: Text(
                          _analyzingEventId == alert.id
                              ? 'Analyzing…'
                              : 'Ask AI to explain',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: brandBlue,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
