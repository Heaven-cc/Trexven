import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/recording_service.dart';

class RecordingsScreen extends StatefulWidget {
  final String? cameraId;
  final String? cameraName;

  const RecordingsScreen({
    super.key,
    this.cameraId,
    this.cameraName,
  });

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  static const _bg = Color(0xFFF8FAFC);
  static const _dark = Color(0xFF0F172A);
  static const _blue = Color(0xFF2563EB);
  static const _muted = Color(0xFF64748B);

  final _recordingService = RecordingService();
  bool _loading = true;
  List<Map<String, dynamic>> _recordings = [];

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    setState(() => _loading = true);
    try {
      final items = await _recordingService.getRecordings(cameraId: widget.cameraId);
      if (!mounted) return;
      setState(() {
        _recordings = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _playVideo(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not play video clip')),
      );
    }
  }

  String _formatDuration(dynamic secs) {
    if (secs == null) return '5m 0s';
    final totalSecs = (secs is num) ? secs.toInt() : 0;
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m}m ${s}s';
  }

  String _formatSize(dynamic bytes) {
    if (bytes == null) return '0 MB';
    final b = (bytes is num) ? bytes.toInt() : 0;
    final mb = b / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.cameraName != null
        ? '${widget.cameraName} Recordings'
        : 'CCTV Recordings';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _dark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _dark),
            onPressed: _loadRecordings,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecordings,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _recordings.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: _recordings.length,
                    itemBuilder: (context, index) {
                      final item = _recordings[index];
                      return _buildRecordingCard(item);
                    },
                  ),
      ),
    );
  }

  Widget _buildRecordingCard(Map<String, dynamic> item) {
    final startedAt = DateTime.tryParse(item['started_at'] ?? '')?.toLocal();
    final dateStr = startedAt != null
        ? DateFormat('MMM d, y • h:mm a').format(startedAt)
        : 'Unknown time';

    final duration = _formatDuration(item['duration_seconds']);
    final size = _formatSize(item['file_size_bytes']);
    final playbackUrl = item['playback_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.play_circle_fill_rounded, color: _blue, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _dark,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 13, color: _muted),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.storage_outlined, size: 13, color: _muted),
                    const SizedBox(width: 4),
                    Text(
                      size,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _playVideo(playbackUrl),
            icon: const Icon(Icons.play_arrow_rounded, color: _blue, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Icon(Icons.videocam_off_outlined, size: 48, color: _muted),
                SizedBox(height: 16),
                Text(
                  'No recordings found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'CCTV video segments uploaded by the vision server will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
