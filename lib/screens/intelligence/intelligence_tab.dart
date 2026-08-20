import 'package:flutter/material.dart';
import '../../models/camera.dart';
import '../../services/camera_intelligence_service.dart';
import 'add_camera_screen.dart';
import 'live_feed_screen.dart';
import 'recordings_screen.dart';
import 'camera_detail_screen.dart';

class IntelligenceTab extends StatefulWidget {
  const IntelligenceTab({super.key});

  @override
  State<IntelligenceTab> createState() => _IntelligenceTabState();
}

class _IntelligenceTabState extends State<IntelligenceTab> {
  final CameraIntelligenceService _intelligenceService =
      CameraIntelligenceService();

  bool _loading = true;
  String? _error;
  List<Camera> _cameras = [];

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cameras = await _intelligenceService.getCameras();

      if (!mounted) return;

      setState(() {
        _cameras = cameras;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _addCamera() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddCameraScreen()),
    );

    if (result == true) {
      _loadCameras();
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = _cameras.where((c) => c.isOnline).length;
    final offline = _cameras.where((c) => c.isOffline).length;
    final aiEnabled = _cameras.where((c) => c.aiEnabled).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: const Text(
          'Intelligence',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecordingsScreen(),
                ),
              );
            },
            icon: const Icon(
              Icons.video_library_outlined,
              color: Color(0xFF0F172A),
            ),
            tooltip: 'Recordings',
          ),
          IconButton(
            onPressed: _loadCameras,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCamera,
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(
          Icons.videocam_outlined,
          color: Colors.white,
        ),
        label: const Text(
          'Add camera',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCameras,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 100),
                      const Icon(
                        Icons.error_outline,
                        size: 50,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'Could not load cameras',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: ElevatedButton(
                          onPressed: _loadCameras,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      8,
                      18,
                      100,
                    ),
                    children: [
                      _buildOverview(
                        online,
                        offline,
                        aiEnabled,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cameras',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RecordingsScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.play_circle_outline_rounded,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                            label: const Text(
                              'Recordings',
                              style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_cameras.isEmpty)
                        _buildEmptyState()
                      else
                        ..._cameras.map(
                          _buildCameraCard,
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildOverview(
    int online,
    int offline,
    int aiEnabled,
  ) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.videocam_outlined,
            title: 'Cameras',
            value: _cameras.length.toString(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            icon: Icons.wifi_rounded,
            title: 'Online',
            value: online.toString(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            icon: Icons.auto_awesome,
            title: 'AI',
            value: aiEnabled.toString(),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraCard(Camera camera) {
    final statusColor = camera.isOnline
        ? const Color(0xFF16A34A)
        : camera.isDegraded
            ? const Color(0xFFF59E0B)
            : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CameraDetailScreen(camera: camera),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.videocam_rounded,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camera.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (camera.location != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        camera.location!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        camera.status,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (camera.aiEnabled) ...[
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          'AI enabled',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Quick action to view Live Feed
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveFeedScreen(camera: camera),
                  ),
                );
              },
              icon: const Icon(
                Icons.play_circle_fill_rounded,
                color: Color(0xFF2563EB),
                size: 28,
              ),
              tooltip: 'Live Feed',
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.videocam_outlined,
              size: 34,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No cameras yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Add an IP camera to start building your business intelligence system.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _addCamera,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add your first camera'),
          ),
        ],
      ),
    );
  }
}
