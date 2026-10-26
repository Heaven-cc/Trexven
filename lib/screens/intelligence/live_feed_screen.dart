import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/vision_service.dart';
import '../../models/camera.dart';

/// Full-screen live AI feed from the vision server.
/// Polls the server's authenticated per-camera JPEG endpoint.
class LiveFeedScreen extends StatefulWidget {
  final Camera camera;
  final Future<List<int>?> Function()? frameLoader;
  final bool aiLive;
  final Future<Map<String, dynamic>> Function()? stateLoader;
  final Future<List<Camera>> Function()? cameraLoader;
  final Future<Map<String, dynamic>> Function()? orientationLoader;
  final Future<void> Function(Map<String, dynamic>)? orientationSaver;
  const LiveFeedScreen({
    super.key,
    required this.camera,
    this.frameLoader,
    this.aiLive = false,
    this.stateLoader,
    this.cameraLoader,
    this.orientationLoader,
    this.orientationSaver,
  });

  @override
  State<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends State<LiveFeedScreen>
    with WidgetsBindingObserver {
  final _vision = VisionService();
  http.Client? _client;
  int _generation = 0;
  int _selectionGeneration = 0;
  Timer? _timer;
  Timer? _selectionTimer;
  String? _selectedId;
  String _selectionReason = 'Checking all cameras…';
  bool _selecting = false;
  late Camera _camera;
  Uint8List? _frameBytes;
  bool _connected = false;
  bool _annotated = false;
  bool _fetching = false;
  bool _attempted = false;
  int _fps = 0;
  int _frameCount = 0;
  DateTime? _lastFpsUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera = widget.camera;
    _selectedId = widget.aiLive ? null : widget.camera.id;
    _startPolling();
  }

  void _startPolling() {
    _client ??= http.Client();
    if (widget.aiLive) {
      _selectCamera();
      _selectionTimer = Timer.periodic(
        Duration(seconds: 1),
        (_) => _selectCamera(),
      );
    }
    _fetchFrame(); // First image starts immediately, with no timer delay.
    _timer = Timer.periodic(Duration(milliseconds: 250), (_) => _fetchFrame());
  }

  Future<void> _fetchFrame() async {
    if (_fetching || _selectedId == null) return;
    _fetching = true;
    final generation = _generation;
    try {
      final bytes =
          await (widget.frameLoader?.call() ??
              _vision.getFrame(
                _selectedId!,
                client: _client,
                annotated: _annotated,
              ));
      if (!mounted || generation != _generation) return;
      if (bytes == null) {
        // A timeout stops waiting on a Future but does not cancel its socket.
        // Closing this screen-owned client prevents stale requests accumulating.
        _client?.close();
        _client = http.Client();
      }
      final now = DateTime.now();
      setState(() {
        _attempted = true;
        _connected = bytes != null;
        // A failed request clears the old image; stale footage is never LIVE.
        _frameBytes = bytes == null ? null : Uint8List.fromList(bytes);
        if (bytes != null) _frameCount++;
        _lastFpsUpdate ??= now;
        if (now.difference(_lastFpsUpdate!).inMilliseconds >= 1000) {
          _fps = _frameCount;
          _frameCount = 0;
          _lastFpsUpdate = now;
        }
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _connected = false;
          _attempted = true;
          _frameBytes = null;
        });
      }
    } finally {
      if (generation == _generation) _fetching = false;
    }
  }

  void _stopPolling() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _selectionTimer?.cancel();
    _selectionTimer = null;
    _selectionGeneration++;
    if (widget.aiLive) _selectedId = null;
    _selecting = false;
    _client?.close();
    _client = null;
    _fetching = false;
  }

  Future<void> _selectCamera() async {
    if (_selecting) return;
    _selecting = true;
    final generation = _selectionGeneration;
    try {
      final state =
          await (widget.stateLoader?.call() ?? _vision.getSharedState());
      if (!mounted || generation != _selectionGeneration) return;
      final selection = Map<String, dynamic>.from(state['ai_live'] as Map);
      final id = selection['camera_id']?.toString();
      if (id != _selectedId) {
        final cameras = id == null
            ? <Camera>[]
            : id == _camera.id
            ? [_camera]
            : await (widget.cameraLoader?.call() ?? _vision.getCameras());
        if (!mounted || generation != _selectionGeneration) return;
        final selected = cameras.where((camera) => camera.id == id);
        _generation++;
        _client?.close();
        _client = http.Client();
        _fetching = false;
        setState(() {
          _selectedId = id;
          if (selected.isNotEmpty) _camera = selected.first;
          _frameBytes = null;
          _connected = false;
          _attempted = id == null;
          _fps = 0;
          _frameCount = 0;
          _lastFpsUpdate = null;
        });
        _fetchFrame();
      }
      setState(
        () => _selectionReason =
            '${selection['reason'] ?? ''}${selection['hold_reason'] == null ? '' : ' · ${selection['hold_reason']}'}',
      );
    } catch (_) {
      if (mounted && generation == _selectionGeneration) {
        _generation++;
        _fetching = false;
        _client?.close();
        _client = http.Client();
        setState(() {
          _selectedId = null;
          _frameBytes = null;
          _connected = false;
          _attempted = true;
          _selectionReason =
              'AI Live is unavailable. Retry the Vision Server connection.';
        });
      }
    } finally {
      if (generation == _selectionGeneration) _selecting = false;
    }
  }

  Future<void> _adjustOrientation() async {
    final id = _selectedId;
    if (id == null) return;
    try {
      final options =
          await (widget.orientationLoader?.call() ??
              _vision.getOrientation(id));
      if (!mounted) return;
      var turns = (options['quarter_turns'] as num? ?? 0).toInt();
      var level = (options['level_degrees'] as num? ?? 0).toDouble();
      var mirror = options['mirror'] == true;
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            scrollable: true,
            title: Text('Adjust camera image'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Rotation: ${turns * 90}°'),
                TextButton.icon(
                  onPressed: () => update(() => turns = (turns + 1) % 4),
                  icon: Icon(Icons.rotate_right),
                  label: Text('Rotate 90°'),
                ),
                Text('Level: ${level.toStringAsFixed(1)}°'),
                Slider(
                  value: level,
                  min: -15,
                  max: 15,
                  divisions: 60,
                  onChanged: (value) => update(() => level = value),
                ),
                SwitchListTile(
                  title: Text('Mirror image'),
                  value: mirror,
                  onChanged: (value) => update(() => mirror = value),
                ),
                Text(
                  'Applies to this camera’s live video, analysis and new recordings.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (save != true) return;
      final savedOptions = {
        ...options,
        'quarter_turns': turns,
        'level_degrees': level,
        'mirror': mirror,
      };
      await (widget.orientationSaver?.call(savedOptions) ??
          _vision.setOrientation(id, savedOptions));
      if (mounted) {
        _generation++;
        _client?.close();
        _client = http.Client();
        _fetching = false;
        setState(() => _frameBytes = null);
        _fetchFrame();
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camera adjustment requires the business owner and a connected Vision Server.',
            ),
          ),
        );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _stopPolling();
      if (mounted) {
        setState(() {
          _frameBytes = null;
          _connected = false;
          _attempted = false;
        });
      }
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black, // Keep black for video feed
      body: Stack(
        children: [
          // Main feed
          _buildFeed(brandBlue),
          // Top overlay
          _buildTopBar(theme, brandBlue),
          // Bottom stats
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildFeed(Color brandBlue) {
    if (_frameBytes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_attempted) Text('Please wait…'),
            SizedBox(height: TrexvenSpacing.fieldGap),
            Text(
              _attempted
                  ? 'Camera offline or unavailable. Reconnecting…'
                  : 'Connecting to camera…',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            if (_attempted)
              TextButton(
                onPressed: widget.aiLive ? _selectCamera : _fetchFrame,
                child: Text('Retry'),
              ),
          ],
        ),
      );
    }
    return Center(
      child: Image.memory(
        _frameBytes!,
        gaplessPlayback: true,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, Color brandBlue) {
    final errorColor = theme.trexvenColors.error!;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.aiLive
                          ? 'AI Live · ${_selectedId == null ? 'No camera' : _camera.name}'
                          : _camera.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: TrexvenFontSize.input,
                      ),
                    ),
                    if (_camera.location != null)
                      Text(
                        _camera.location!,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: TrexvenFontSize.caption,
                        ),
                      ),
                  ],
                ),
              ),
              // Live badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _connected
                      ? errorColor
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(TrexvenRadii.card),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _connected ? Colors.white : Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5),
                    Text(
                      _connected ? 'LIVE' : 'OFF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: TrexvenFontSize.caption,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Adjust camera image',
                onPressed: _adjustOrientation,
                icon: Icon(Icons.screen_rotation, color: Colors.white),
              ),
              if (_camera.aiEnabled && !widget.aiLive) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: brandBlue.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  ),
                  child: Text(
                    'AI enabled',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: TrexvenFontSize.caption,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.aiLive)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    _selectionReason,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      _generation++;
                      _client?.close();
                      _client = http.Client();
                      _fetching = false;
                      setState(() {
                        _annotated = !_annotated;
                        _frameBytes = null;
                      });
                      _fetchFrame();
                    },
                    child: Text(
                      '$_fps FPS · ${_annotated ? 'AI boxes' : 'Live'}',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  _badge(
                    _connected ? 'Online' : 'Offline · Reconnecting…',
                    _connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: TrexvenFontSize.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
