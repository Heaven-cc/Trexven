import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:flutter/material.dart';
import '../../models/camera.dart';
import '../../services/vision_service.dart';
import 'add_camera_screen.dart';
import 'live_feed_screen.dart';
import 'vision_server_screen.dart';
import 'recordings_screen.dart';
import 'events_screen.dart';

class IntelligenceTab extends StatefulWidget {
  const IntelligenceTab({
    super.key,
    this.loadCameras,
    this.liveFrameLoader,
    this.vision,
  });
  final Future<List<Camera>> Function()? loadCameras;
  final Future<List<int>?> Function()? liveFrameLoader;
  final VisionService? vision;

  @override
  State<IntelligenceTab> createState() => _IntelligenceTabState();
}

class _IntelligenceTabState extends State<IntelligenceTab> {
  late final VisionService _intelligenceService;

  bool _loading = true;
  String? _error;
  List<Camera> _cameras = [];
  bool _needsSetup = false;

  @override
  void initState() {
    super.initState();
    _intelligenceService = widget.vision ?? VisionService();
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (widget.loadCameras == null) {
        await _intelligenceService.init();
        if (!mounted) return;
        if (!_intelligenceService.isConfigured) {
          setState(() {
            _needsSetup = true;
            _cameras = [];
            _loading = false;
          });
          return;
        }
      }
      final cameras =
          await (widget.loadCameras?.call() ??
              _intelligenceService.getCameras());

      if (!mounted) return;

      setState(() {
        _cameras = cameras;
        _needsSetup = false;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = CustomerPresentation.error(
          error,
          fallback: 'We could not load your cameras. Please try again.',
        );
      });
    }
  }

  Future<void> _addCamera() async {
    if (_needsSetup) {
      await _openVisionServer();
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddCameraScreen()),
    );

    if (result == true && mounted) {
      _loadCameras();
    }
  }

  Future<void> _openVisionServer() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => VisionServerScreen(connectOnOpen: !_needsSetup),
      ),
    );
    if (mounted) await _loadCameras();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted!;
    final brandBlue = theme.colorScheme.primary;

    final online = _cameras.where((c) => c.isOnline).length;
    final offline = _cameras.where((c) => c.isOffline).length;
    final aiEnabled = _cameras.where((c) => c.aiEnabled).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Intelligence', style: TextStyle(
                fontSize: TrexvenFontSize.section,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              )),
              Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _cameras.isEmpty ? null : () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) =>
                        LiveFeedScreen(camera: _cameras.first, aiLive: true)),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('AI Live'),
                  ),
                  TextButton.icon(
                    onPressed: _openVisionServer,
                    icon: const Icon(Icons.dns_outlined, size: 18),
                    label: const Text('Vision Server'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => RecordingsScreen(),
                    )),
                    icon: const Icon(Icons.video_library_outlined, size: 18),
                    label: const Text('Recordings'),
                  ),
                  TextButton.icon(
                    onPressed: _loading ? null : _loadCameras,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh'),
                  ),
                  TextButton.icon(
                    onPressed: _loading ? null : _addCamera,
                    icon: Icon(_needsSetup ? Icons.dns_outlined : Icons.add_rounded, size: 18),
                    label: Text(_needsSetup ? 'Connect Vision server' : 'Add camera'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCameras,
            child: _loading
                ? Center(child: TrexvenLoading())
                : _error != null
                ? ListView(
                    padding: TrexvenSpacing.pagePadding,
                    children: [
                      SizedBox(height: 100),
                      Icon(
                        Icons.error_outline,
                        size: 50,
                        color: theme.trexvenColors.error,
                      ),
                      SizedBox(height: TrexvenSpacing.fieldGap),
                      Center(
                        child: Text(
                          'Could not load cameras',
                          style: TextStyle(
                            fontSize: TrexvenFontSize.section,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted),
                      ),
                      SizedBox(height: TrexvenSpacing.fieldGap),
                      Center(
                        child: ElevatedButton(
                          onPressed: _loadCameras,
                          child: Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : _needsSetup
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                    children: [_buildEmptyState()],
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(18, 8, 18, 100),
                    children: [
                      _buildOverview(online, offline, aiEnabled),
                      SizedBox(height: TrexvenSpacing.fieldGap),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cameras',
                            style: TextStyle(
                              fontSize: TrexvenFontSize.section,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => EventsScreen()),
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
                                fontSize: TrexvenFontSize.body,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      if (_cameras.isEmpty)
                        _buildEmptyState()
                      else
                        ..._cameras.map(_buildCameraCard),
                    ],
                  ),
          ),
        ),
      ],
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
        SizedBox(width: 8),
        Expanded(
          child: _statCard(
            icon: Icons.wifi_rounded,
            title: 'Online',
            value: online.toString(),
          ),
        ),
        SizedBox(width: 8),
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
    final muted = theme.trexvenColors.muted!;

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: TrexvenFontSize.section,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: TrexvenFontSize.caption, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraCard(Camera camera) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted!;

    final statusColor = camera.isOnline
        ? (theme.trexvenColors.success!)
        : camera.isDegraded
        ? (theme.trexvenColors.warning!)
        : muted;

    return Padding(
      padding: EdgeInsets.only(bottom: 10),
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
        padding: EdgeInsets.all(15),
        borderRadius: 17,
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: brandBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(TrexvenRadii.card),
              ),
              child: Icon(Icons.videocam_rounded, color: brandBlue),
            ),
            SizedBox(width: 13),
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
                      padding: EdgeInsets.only(top: 3),
                      child: Text(
                        camera.location!,
                        style: TextStyle(
                          fontSize: TrexvenFontSize.caption,
                          color: muted,
                        ),
                      ),
                    ),
                  SizedBox(height: 7),
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
                      SizedBox(width: 5),
                      Text(
                        camera.status,
                        style: TextStyle(
                          fontSize: TrexvenFontSize.caption,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (camera.aiEnabled) ...[
                        SizedBox(width: 10),
                        Icon(Icons.auto_awesome, size: 13, color: brandBlue),
                        SizedBox(width: 3),
                        Text(
                          'AI enabled',
                          style: TextStyle(
                            fontSize: TrexvenFontSize.caption,
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
            Icon(
              Icons.chevron_right_rounded,
              color: muted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 25, vertical: 40),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: brandBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
            ),
            child: Icon(Icons.videocam_outlined, size: 34, color: brandBlue),
          ),
          SizedBox(height: TrexvenSpacing.fieldGap),
          Text(
            _needsSetup ? 'Set up Intelligence' : 'No cameras yet',
            style: TextStyle(
              fontSize: TrexvenFontSize.section,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 7),
          Text(
            _needsSetup
                ? 'Connect your Vision server, then add your first camera to start monitoring your business.'
                : 'Add an IP camera to start building your business intelligence system.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: TrexvenFontSize.body,
              height: 1.5,
              color: muted,
            ),
          ),
          SizedBox(height: TrexvenSpacing.fieldGap),
          ElevatedButton.icon(
            onPressed: _addCamera,
            icon: Icon(_needsSetup ? Icons.dns_outlined : Icons.add_rounded),
            label: Text(
              _needsSetup ? 'Connect Vision server' : 'Add your first camera',
            ),
          ),
        ],
      ),
    );
  }
}
