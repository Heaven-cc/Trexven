import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/vision_service.dart';
import '../../models/camera.dart';

/// Full-screen live AI feed from the vision server.
/// Polls /frame/{cameraId} every 150ms and updates the display.
class LiveFeedScreen extends StatefulWidget {
  final Camera camera;
  const LiveFeedScreen({super.key, required this.camera});

  @override
  State<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends State<LiveFeedScreen> {
  static const _bg = Color(0xFF0A0A0A);
  static const _blue = Color(0xFF2563EB);

  final _vision = VisionService();
  Timer? _timer;
  Uint8List? _frameBytes;
  bool _connected = false;
  int _fps = 0;
  int _frameCount = 0;
  DateTime? _lastFpsUpdate;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      final bytes = await _vision.getFrame(widget.camera.id);
      if (!mounted) return;
      setState(() {
        if (bytes != null) {
          _frameBytes = Uint8List.fromList(bytes);
          _connected = true;
          _frameCount++;
        } else {
          _connected = false;
        }
      });

      // Calculate FPS every second
      final now = DateTime.now();
      if (_lastFpsUpdate == null) {
        _lastFpsUpdate = now;
      } else if (now.difference(_lastFpsUpdate!).inMilliseconds >= 1000) {
        if (mounted) {
          setState(() {
            _fps = _frameCount;
            _frameCount = 0;
            _lastFpsUpdate = now;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Main feed
          _buildFeed(),
          // Top overlay
          _buildTopBar(),
          // Bottom stats
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildFeed() {
    if (_frameBytes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: _blue),
            const SizedBox(height: 16),
            Text(
              _connected
                  ? 'Loading feed…'
                  : 'Connecting to camera…',
              style: const TextStyle(color: Colors.white70),
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

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
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
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.camera.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    if (widget.camera.location != null)
                      Text(
                        widget.camera.location!,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // Live badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _connected
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(20),
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
                    const SizedBox(width: 5),
                    Text(
                      _connected ? 'LIVE' : 'OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.camera.aiEnabled) ...[  
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'AI ON',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xCC000000), Colors.transparent],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _badge('$_fps FPS', Icons.speed_rounded),
              _badge(
                _connected ? 'Connected' : 'Reconnecting…',
                _connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
