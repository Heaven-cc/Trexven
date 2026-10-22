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
  bool _showAllCameras = false;

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Intelligence', style: theme.textTheme.titleLarge),
                Text('Vision monitoring',
                  style: theme.textTheme.bodySmall),
              ],
            )),
            IconButton(
              tooltip: 'Refresh cameras',
              onPressed: _loading ? null : _loadCameras,
              icon: const Icon(Icons.refresh_rounded)),
            PopupMenuButton<String>(
              tooltip: 'Vision settings',
              icon: const Icon(Icons.settings_outlined),
              onSelected: (value) {
                if (value == 'server') {
                  _openVisionServer();
                } else if (value == 'camera') {
                  _addCamera();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'server',
                  child: Text(_needsSetup
                    ? 'Connect Vision server' : 'Vision Server')),
                if (!_needsSetup)
                  const PopupMenuItem(
                    value: 'camera', child: Text('Add camera')),
              ],
            ),
          ]),
        ),
        if (_needsSetup)
          Align(alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openVisionServer,
              icon: const Icon(Icons.dns_outlined),
              label: const Text('Connect Vision server')),
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
                      _modeSelector(),
                      const SizedBox(height: TrexvenSpacing.fieldGap),
                      if (!_showAllCameras) ...[
                        _aiLiveHero(),
                        const SizedBox(height: TrexvenSpacing.labelGap),
                        _quickActions(),
                        const SizedBox(height: TrexvenSpacing.fieldGap),
                        _compactMetrics(online, offline, aiEnabled),
                        const SizedBox(height: TrexvenSpacing.fieldGap),
                        Row(children: [
                          Expanded(child: Text('Recent Cameras',
                            style: theme.textTheme.titleMedium)),
                          TextButton(
                            onPressed: () => setState(
                              () => _showAllCameras = true),
                            child: const Text('View all')),
                        ]),
                        if (_cameras.isEmpty) _buildEmptyState()
                        else ..._cameras.take(3).map(_buildCameraCard),
                      ] else ...[
                        Row(children: [
                          Expanded(child: Text('All Cameras',
                            style: theme.textTheme.titleMedium)),
                          Text(_cameras.length.toString() + ' cameras',
                            style: theme.textTheme.bodySmall),
                        ]),
                        const SizedBox(height: TrexvenSpacing.labelGap),
                        _compactMetrics(online, offline, aiEnabled),
                        const SizedBox(height: TrexvenSpacing.fieldGap),
                        if (_cameras.isEmpty) _buildEmptyState()
                        else ..._cameras.map(_buildCameraCard),
                        OutlinedButton.icon(
                          onPressed: _addCamera,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add camera')),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _openAiLive() {
    if (_cameras.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => LiveFeedScreen(
        camera: _cameras.first, aiLive: true,
        frameLoader: widget.liveFrameLoader)));
  }

  void _openCamera(Camera camera) => Navigator.push(context,
    MaterialPageRoute(builder: (_) => LiveFeedScreen(
      camera: camera, frameLoader: widget.liveFrameLoader)));

  Widget _modeSelector() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TrexvenRadii.field)),
      child: Row(children: [
        Expanded(child: _modeButton('AI Live', Icons.auto_awesome,
          !_showAllCameras, () => setState(() => _showAllCameras = false))),
        Expanded(child: _modeButton('All Cameras', Icons.videocam_outlined,
          _showAllCameras, () => setState(() => _showAllCameras = true))),
      ]),
    );
  }

  Widget _modeButton(String title, IconData icon, bool selected, VoidCallback tap) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(TrexvenRadii.status),
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(TrexvenRadii.status),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TrexvenSpacing.buttonHeight),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 17,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Flexible(child: Text(title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant))),
          ]),
        ),
      ),
    );
  }

  Widget _aiLiveHero() {
    final theme = Theme.of(context);
    return Container(
      padding: TrexvenSpacing.cardPadding,
      decoration: BoxDecoration(
        color: const Color(0xFF102846),
        borderRadius: BorderRadius.circular(TrexvenRadii.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome, color: Color(0xFFA9C8F4), size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('AI Live',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          Text('SERVER CONTROLLED',
            style: TextStyle(color: Color(0xFFA9C8F4), fontSize: 10)),
        ]),
        const SizedBox(height: TrexvenSpacing.labelGap),
        Container(
          height: 112, width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF071728),
            borderRadius: BorderRadius.circular(TrexvenRadii.field)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.videocam_outlined,
              color: Color(0xFF9DBCDD), size: 28),
            const SizedBox(height: 6),
            Text(_cameras.isEmpty ? 'Connect a camera to start'
                : 'Open Live to view the AI-selected camera',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFC5D4E5), fontSize: 12)),
          ]),
        ),
        const SizedBox(height: TrexvenSpacing.labelGap),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Automatic camera attention',
                style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 13)),
              Text('Vision chooses which camera to display',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFC5D4E5))),
            ])),
          const SizedBox(width: TrexvenSpacing.labelGap),
          FilledButton(onPressed: _cameras.isEmpty ? null : _openAiLive,
            child: const Text('Open Live')),
        ]),
      ]),
    );
  }

  Widget _quickActions() => Row(children: [
    Expanded(child: _quickAction(
      'Events', 'Detected activity', Icons.timeline_rounded, () {
        Navigator.push(context,
          MaterialPageRoute(builder: (_) => const EventsScreen()));
      })),
    const SizedBox(width: TrexvenSpacing.labelGap),
    Expanded(child: _quickAction(
      'Recordings', 'Saved clips', Icons.video_library_outlined, () {
        Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RecordingsScreen()));
      })),
  ]);

  Widget _quickAction(
    String title, String subtitle, IconData icon, VoidCallback action) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: title,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        child: InkWell(
          onTap: action,
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 65),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(TrexvenRadii.card)),
            child: Row(children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: TrexvenSpacing.labelGap),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                ],
              )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _compactMetrics(int online, int offline, int ai) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = [
      (_cameras.length.toString(), 'Cameras'),
      (online.toString(), 'Online'),
      (offline.toString(), 'Offline'),
      (ai.toString(), 'AI'),
    ];
    return Row(children: [
      for (var i = 0; i < metrics.length; i++) ...[
        if (i != 0) const SizedBox(width: 5),
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(TrexvenRadii.status)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(metrics[i].$1, style: Theme.of(context).textTheme.labelLarge),
            Text(metrics[i].$2,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
          ]),
        )),
      ],
    ]);
  }

  Widget _buildCameraCard(Camera camera) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = camera.isOnline
      ? theme.trexvenColors.success ?? scheme.primary
      : camera.isDegraded
        ? theme.trexvenColors.warning ?? scheme.error
        : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: TrexvenSpacing.labelGap),
      child: TrexvenTapCard(
        onTap: () => _openCamera(camera),
        padding: const EdgeInsets.all(12),
        borderRadius: TrexvenRadii.card,
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(TrexvenRadii.status)),
            child: Icon(Icons.videocam_outlined, color: scheme.primary)),
          const SizedBox(width: TrexvenSpacing.labelGap),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(camera.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge),
              if (camera.location != null)
                Text(camera.location!, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
              Row(children: [
                Icon(Icons.circle, size: 7, color: color),
                const SizedBox(width: 4),
                Flexible(child: Text(camera.status,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: color))),
                if (camera.aiEnabled) ...[
                  const SizedBox(width: 7),
                  Icon(Icons.auto_awesome, size: 12, color: scheme.primary),
                  const SizedBox(width: 2),
                  Text('AI', style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.primary)),
                ],
              ]),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ]),
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
