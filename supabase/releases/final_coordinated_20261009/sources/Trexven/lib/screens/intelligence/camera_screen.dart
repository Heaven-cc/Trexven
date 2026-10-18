import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/camera.dart';
import '../../services/vision_service.dart';
import 'add_camera_screen.dart';
import 'live_feed_screen.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({super.key});

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

class _CamerasScreenState extends State<CamerasScreen> {
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
      final cameras = await _intelligenceService.getCameras();

      if (!mounted) return;

      setState(() {
        _cameras = cameras;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _addCamera() async {
    final result = await Navigator.push(
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
    final brandBlue = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Cameras',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
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
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add camera',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    final brandBlue = theme.colorScheme.primary;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: brandBlue));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 50,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load cameras',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _loadCameras,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameras.isEmpty) {
      return _buildEmptyState(theme);
    }

    return RefreshIndicator(
      color: brandBlue,
      onRefresh: _loadCameras,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
        itemCount: _cameras.length,
        itemBuilder: (context, index) {
          return _cameraCard(theme, _cameras[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: brandBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.videocam_outlined, size: 40, color: brandBlue),
            ),
            const SizedBox(height: 20),
            Text(
              'No cameras yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a camera to begin building your business intelligence system.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addCamera,
              icon: const Icon(Icons.add),
              label: const Text('Add camera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraCard(ThemeData theme, Camera camera) {
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final borderColor = theme.trexvenColors.border ?? const Color(0xFFE2E8F0);

    final status = camera.status.toLowerCase();
    final online = status == 'online';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.trexvenColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LiveFeedScreen(camera: camera)),
          );

          _loadCameras();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: brandBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.videocam_rounded, color: brandBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      camera.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      camera.location?.isNotEmpty == true
                          ? camera.location!
                          : 'Location not specified',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _statusDot(online),
                        const SizedBox(width: 5),
                        Text(
                          online ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: online
                                ? (theme.trexvenColors.success ?? Colors.green)
                                : muted,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: camera.aiEnabled
                              ? brandBlue
                              : muted.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          camera.aiEnabled ? 'AI active' : 'AI off',
                          style: TextStyle(
                            fontSize: 11,
                            color: camera.aiEnabled
                                ? brandBlue
                                : muted.withOpacity(0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusDot(bool online) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: online ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}
