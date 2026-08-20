import 'package:flutter/material.dart';

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
      backgroundColor:
      const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor:
        const Color(0xFFF8FAFC),
        elevation: 0,

        title: const Text(
          'Camera Intelligence',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),

        actions: [
          IconButton(
            onPressed: _loading
                ? null
                : _load,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body: _loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding:
          const EdgeInsets.all(18),
          children: [
            _buildOverview(
              online,
              aiEnabled,
              alerts,
            ),

            const SizedBox(height: 24),

            const Text(
              'Cameras',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
                color:
                Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 12),

            if (_cameras.isEmpty)
              _empty(
                'No cameras connected yet.',
              )
            else
              ..._cameras.map(
                _cameraCard,
              ),

            const SizedBox(height: 24),

            const Text(
              'Recent intelligence',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
                color:
                Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 12),

            if (_events.isEmpty)
              _empty(
                'No camera events detected yet.',
              )
            else
              ..._events
                  .take(20)
                  .map(
                _eventCard,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(
      int online,
      int aiEnabled,
      int alerts,
      ) {
    return Row(
      children: [
        Expanded(
          child: _stat(
            'Online',
            online.toString(),
            Icons.videocam_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            'AI Active',
            aiEnabled.toString(),
            Icons.auto_awesome,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _stat(
            'Alerts',
            alerts.toString(),
            Icons.warning_amber_rounded,
          ),
        ),
      ],
    );
  }

  Widget _stat(
      String label,
      String value,
      IconData icon,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color:
            const Color(0xFF2563EB),
            size: 20,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight:
              FontWeight.w800,
              color:
              Color(0xFF0F172A),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color:
              Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cameraCard(Camera camera) {
    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
      const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: camera.isOnline
                  ? const Color(
                0xFFECFDF5,
              )
                  : const Color(
                0xFFF1F5F9,
              ),
              borderRadius:
              BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.videocam_outlined,
              color: camera.isOnline
                  ? const Color(
                0xFF059669,
              )
                  : const Color(
                0xFF64748B,
              ),
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  camera.name,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  camera.location ??
                      'No location',
                  style:
                  const TextStyle(
                    fontSize: 12,
                    color:
                    Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Text(
                camera.isOnline
                    ? 'ONLINE'
                    : 'OFFLINE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w800,
                  color: camera.isOnline
                      ? const Color(
                    0xFF059669,
                  )
                      : const Color(
                    0xFF64748B,
                  ),
                ),
              ),

              const SizedBox(height: 5),

              Text(
                camera.aiEnabled
                    ? 'AI ON'
                    : 'AI OFF',
                style:
                const TextStyle(
                  fontSize: 10,
                  fontWeight:
                  FontWeight.w700,
                  color:
                  Color(0xFF2563EB),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventCard(
      CameraEvent event,
      ) {
    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
      const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: event.isHighSeverity
                  ? const Color(
                0xFFFEF2F2,
              )
                  : const Color(
                0xFFEFF6FF,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              event.isHighSeverity
                  ? Icons.warning_rounded
                  : Icons.visibility_rounded,
              color: event.isHighSeverity
                  ? const Color(
                0xFFDC2626,
              )
                  : const Color(
                0xFF2563EB,
              ),
              size: 19,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  event.title ??
                      event.eventType,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w700,
                    color:
                    Color(0xFF0F172A),
                  ),
                ),

                if (event.description !=
                    null) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description!,
                    style:
                    const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color:
                      Color(0xFF64748B),
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                Text(
                  'Confidence: ${event.confidenceLabel}',
                  style:
                  const TextStyle(
                    fontSize: 10,
                    color:
                    Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Container(
      padding:
      const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color:
          const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color:
          Color(0xFF64748B),
        ),
      ),
    );
  }
}