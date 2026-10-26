import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../services/recording_service.dart';
import '../../services/vision_service.dart';

class RecordingPlaybackScreen extends StatefulWidget {
  const RecordingPlaybackScreen({
    super.key,
    required this.recordingId,
    this.isLocal = false,
  });
  final String recordingId;
  final bool isLocal;
  @override
  State<RecordingPlaybackScreen> createState() =>
      _RecordingPlaybackScreenState();
}

class _RecordingPlaybackScreenState extends State<RecordingPlaybackScreen> {
  VideoPlayerController? _controller;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    VideoPlayerController? controller;
    try {
      final vision = VisionService();
      final headers = widget.isLocal
          ? await vision.appHeaders()
          : <String, String>{};
      final url = widget.isLocal
          ? vision.recordingUrl(widget.recordingId)
          : await RecordingService().getPlaybackUrl(widget.recordingId);
      controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
      );
      await controller.initialize().timeout(Duration(seconds: 20));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_changed);
      setState(() => _controller = controller);
      await controller.play();
    } catch (_) {
      await controller?.dispose();
      if (mounted) {
        setState(() {
          _controller = null;
          _failed = true;
        });
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _controller;
    return Scaffold(
      appBar: AppBar(title: Text('Recording')),
      body: Center(
        child: _failed || (player?.value.hasError ?? false)
            ? Text('Unable to play this recording. Reopen it to retry.')
            : player == null
            ? Text('Please wait…')
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: player.value.aspectRatio,
                    child: VideoPlayer(player),
                  ),
                  VideoProgressIndicator(player, allowScrubbing: true),
                  IconButton(
                    tooltip: player.value.isPlaying ? 'Pause' : 'Play',
                    icon: Icon(
                      player.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: () =>
                        player.value.isPlaying ? player.pause() : player.play(),
                  ),
                ],
              ),
      ),
    );
  }
}
