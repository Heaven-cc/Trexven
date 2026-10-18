import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/vision_service.dart';
import 'recording_playback_screen.dart';
import '../../core/app_theme.dart';
import '../../services/recording_service.dart';

class RecordingsScreen extends StatefulWidget {
  final String? cameraId;
  final String? cameraName;

  const RecordingsScreen({super.key, this.cameraId, this.cameraName});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
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
      final items = <Map<String, dynamic>>[];
      final failures = <String>[];
      await Future.wait([
        (() async {
          try {
            items.addAll(
              await _recordingService.getRecordings(cameraId: widget.cameraId),
            );
          } catch (_) {
            failures.add('Cloud recordings');
          }
        })(),
        (() async {
          try {
            items.addAll(
              (await VisionService().getRecordings(
                cameraId: widget.cameraId,
              )).map((row) => {...row, 'is_local': true}),
            );
          } catch (_) {
            failures.add('Vision recordings');
          }
        })(),
      ]);
      items.sort(
        (a, b) => (b['started_at'] ?? '').toString().compareTo(
          (a['started_at'] ?? '').toString(),
        ),
      );
      if (mounted && failures.isNotEmpty)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${failures.join(' and ')} could not load. Refresh to retry.',
            ),
          ),
        );
      if (!mounted) return;
      setState(() {
        _recordings = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load recordings. Please retry.'),
        ),
      );
    }
  }

  Future<void> _playVideo(Map<String, dynamic> item) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RecordingPlaybackScreen(
        recordingId: item['id'].toString(),
        isLocal: item['is_local'] == true,
      ),
    ),
  );

  String _formatDuration(dynamic secs) {
    if (secs == null) return 'Duration unavailable';
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
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;

    final title = widget.cameraName != null
        ? '${widget.cameraName} Recordings'
        : 'CCTV Recordings';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: _loadRecordings,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: brandBlue,
        onRefresh: _loadRecordings,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: brandBlue))
            : _recordings.isEmpty
            ? _buildEmptyState(theme)
            : ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: _recordings.length,
                itemBuilder: (context, index) {
                  final item = _recordings[index];
                  return _buildRecordingCard(theme, item);
                },
              ),
      ),
    );
  }

  Widget _buildRecordingCard(ThemeData theme, Map<String, dynamic> item) {
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    final startedAt = DateTime.tryParse(item['started_at'] ?? '')?.toLocal();
    final dateStr = startedAt != null
        ? DateFormat('MMM d, y • h:mm a').format(startedAt)
        : 'Unknown time';

    final duration = _formatDuration(item['duration_seconds']);
    final size = _formatSize(item['file_size_bytes']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: brandBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.play_circle_fill_rounded,
              color: brandBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['camera_name'] == null ? '' : '${item['camera_name']} · '}$dateStr',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 13, color: muted),
                    const SizedBox(width: 4),
                    Text(
                      duration,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.storage_outlined, size: 13, color: muted),
                    const SizedBox(width: 4),
                    Text(size, style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _playVideo(item),
            icon: Icon(Icons.play_arrow_rounded, color: brandBlue, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.trexvenColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.videocam_off_outlined, size: 48, color: muted),
                const SizedBox(height: 16),
                Text(
                  'No recordings found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'CCTV video segments uploaded by the vision server will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
