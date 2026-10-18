import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/camera.dart';
import '../../services/vision_service.dart';
import 'add_camera_screen.dart';
import 'live_feed_screen.dart';
import 'vision_server_screen.dart';
import 'recordings_screen.dart';
import 'events_screen.dart';
import '../../widgets/trexven_widgets.dart';

class IntelligenceTab extends StatefulWidget {
  const IntelligenceTab({super.key, this.loadCameras, this.liveFrameLoader});
  final Future<List<Camera>> Function()? loadCameras;
  final Future<List<int>?> Function()? liveFrameLoader;

  @override
  State<IntelligenceTab> createState() => _IntelligenceTabState();
}

class _IntelligenceTabState extends State<IntelligenceTab> {
  final VisionService _intelligenceService = VisionService();

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
      final cameras =
          await (widget.loadCameras?.call() ??
              _intelligenceService.getCameras());

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
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final brandBlue = theme.colorScheme.primary;

    final online = _cameras.where((c) => c.isOnline).length;
    final offline = _cameras.where((c) => c.isOffline).length;
    final aiEnabled = _cameras.where((c) => c.aiEnabled).length;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Intelligence',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'AI Live',
            icon: const Icon(Icons.auto_awesome),
            onPressed: _cameras.isEmpty
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LiveFeedScreen(camera: _cameras.first, aiLive: true),
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'Vision Server',
            icon: const Icon(Icons.dns_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VisionServerScreen(connectOnOpen: true),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecordingsScreen()),
              );
            },
            icon: Icon(
              Icons.video_library_outlined,
              color: theme.colorScheme.onSurface,
            ),
            tooltip: 'Recordings',
          ),
          IconButton(
            onPressed: _loadCameras,
            icon: Icon(
              Icons.refresh_rounded,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCamera,
        backgroundColor: brandBlue,
        icon: const Icon(Icons.videocam_outlined, color: Colors.white),
        label: const Text(
          'Add camera',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCameras,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  Icon(
                    Icons.error_outline,
                    size: 50,
                    color: theme.trexvenColors.error,
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
                    style: TextStyle(color: muted),
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
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                children: [
                  _buildOverview(online, offline, aiEnabled),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cameras',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EventsScreen(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.timeline_rounded,
                          size: 16,
                          color: brandBlue,
                        ),
                        label: Text(
                          'Events',
                          style: TextStyle(
                            color: brandBlue,
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
                    ..._cameras.map(_buildCameraCard),
                ],
              ),
      ),
    );
  }

  Widget _buildOverview(int online, int offline, int aiEnabled) {
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
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;

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
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );
  }

  Widget _buildCameraCard(Camera camera) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    final statusColor = camera.isOnline
        ? (theme.trexvenColors.success ?? Colors.green)
        : camera.isDegraded
        ? (theme.trexvenColors.warning ?? Colors.orange)
        : muted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TrexvenTapCard(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveFeedScreen(
                camera: camera,
                frameLoader: widget.liveFrameLoader,
              ),
            ),
          );
        },
        padding: const EdgeInsets.all(15),
        borderRadius: 17,
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: brandBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.videocam_rounded, color: brandBlue),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camera.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (camera.location != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        camera.location!,
                        style: TextStyle(fontSize: 12, color: muted),
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
                        Icon(Icons.auto_awesome, size: 13, color: brandBlue),
                        const SizedBox(width: 3),
                        Text(
                          'AI enabled',
                          style: TextStyle(
                            fontSize: 11,
                            color: brandBlue,
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
                    builder: (_) => LiveFeedScreen(
                      camera: camera,
                      frameLoader: widget.liveFrameLoader,
                    ),
                  ),
                );
              },
              icon: Icon(
                Icons.play_circle_fill_rounded,
                color: brandBlue,
                size: 28,
              ),
              tooltip: 'Live Feed',
            ),
            Icon(Icons.chevron_right_rounded, color: muted.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: brandBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.videocam_outlined, size: 34, color: brandBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'No cameras yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Add an IP camera to start building your business intelligence system.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: muted),
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
