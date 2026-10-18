import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/camera.dart';
import '../../models/camera_event.dart';
import '../../services/camera_intelligence_service.dart';

class CameraIntelligenceScreen
    extends StatefulWidget {
  const CameraIntelligenceScreen({
    super.key,
  });

  @override
  State<CameraIntelligenceScreen> createState() =>
      _CameraIntelligenceScreenState();
}

class _CameraIntelligenceScreenState
    extends State<CameraIntelligenceScreen> {
  final CameraIntelligenceService
  _intelligence =
  CameraIntelligenceService();

  bool _loading = true;

  List<Camera> _cameras = [];
  List<CameraEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cameras =
      await _intelligence.getCameras();

      final List<CameraEvent> events = [];

      for (final camera in cameras) {
        final cameraEvents =
        await _intelligence.getEvents(
          camera.id,
        );

        events.addAll(cameraEvents);
      }

      events.sort(
            (a, b) {
          final aDate =
              a.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(
                    0,
                  );

          final bDate =
              b.createdAt ??
                  DateTime.fromMillisecondsSinceEpoch(
                    0,
                  );

          return bDate.compareTo(aDate);
        },
      );

      if (!mounted) return;

      setState(() {
        _cameras = cameras;
        _events = events;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showError(
        'Could not load camera intelligence.\n$error',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;

    final online =
        _cameras.where(
              (camera) => camera.isOnline,
        ).length;

    final aiEnabled =
        _cameras.where(
              (camera) => camera.aiEnabled,
        ).length;

    final alerts =
        _events.where(
              (event) => event.isHighSeverity,
        ).length;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Camera Intelligence',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: brandBlue),
            )
          : RefreshIndicator(
              color: brandBlue,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _buildOverview(theme, online, aiEnabled, alerts),
                  const SizedBox(height: 24),
                  Text(
                    'Cameras',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_cameras.isEmpty)
                    _empty(theme, 'No cameras connected yet.')
                  else
                    ..._cameras.map((c) => _cameraCard(theme, c)),
                  const SizedBox(height: 24),
                  Text(
                    'Recent intelligence',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_events.isEmpty)
                    _empty(theme, 'No camera events detected yet.')
                  else
                    ..._events.take(20).map((e) => _eventCard(theme, e)),
                ],
              ),
            ),
    );
  }

  Widget _buildOverview(
      ThemeData theme,
      int online,
      int aiEnabled,
      int alerts,
      ) {
    return Row(
      children: [
        Expanded(
          child: _stat(
            theme,
            'Online',
            online.toString(),
            Icons.videocam_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            theme,
            'AI Active',
            aiEnabled.toString(),
            Icons.auto_awesome,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            theme,
            'Alerts',
            alerts.toString(),
            Icons.warning_amber_rounded,
          ),
        ),
      ],
    );
  }

  Widget _stat(
      ThemeData theme,
      String label,
      String value,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.trexvenColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraCard(ThemeData theme, Camera camera) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final successColor = theme.trexvenColors.success ?? Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: camera.isOnline
                  ? successColor.withOpacity(0.08)
                  : theme.colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.videocam_outlined,
              color: camera.isOnline ? successColor : muted,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  camera.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  camera.location ?? 'No location',
                  style: TextStyle(
                    fontSize: 12,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                camera.isOnline ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: camera.isOnline ? successColor : muted,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                camera.aiEnabled ? 'AI ON' : 'AI OFF',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventCard(ThemeData theme, CameraEvent event) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final errorColor = theme.trexvenColors.error ?? Colors.red;
    final brandBlue = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: event.isHighSeverity
                  ? errorColor.withOpacity(0.1)
                  : brandBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              event.isHighSeverity
                  ? Icons.warning_rounded
                  : Icons.visibility_rounded,
              color: event.isHighSeverity ? errorColor : brandBlue,
              size: 19,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title ?? event.eventType,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                if (event.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: muted,
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                Text(
                  'Confidence: ${event.confidenceLabel}',
                  style: TextStyle(
                    fontSize: 10,
                    color: muted.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: theme.trexvenColors.muted,
        ),
      ),
    );
  }
}