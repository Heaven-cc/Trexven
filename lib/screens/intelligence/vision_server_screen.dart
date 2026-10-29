import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';

import '../../services/vision_service.dart';
import '../../models/camera.dart';
import 'live_feed_screen.dart';
import 'add_camera_screen.dart';

class VisionServerScreen extends StatefulWidget {
  const VisionServerScreen({super.key, this.connectOnOpen = false});
  final bool connectOnOpen;
  @override
  State<VisionServerScreen> createState() => _VisionServerScreenState();
}

class _VisionServerScreenState extends State<VisionServerScreen> {
  final _vision = VisionService();
  bool _busy = true;
  bool _connected = false;
  String? _error;
  Map<String, dynamic>? _health;
  List<dynamic> _cameras = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _vision.init();
      if (!mounted) return;
      if (_vision.isConfigured) {
        await _connect();
        return;
      }
    } catch (_) {
      if (mounted) {
        _error = 'Cloud Vision settings could not load. Please retry.';
      }
    }
    if (mounted) {
      setState(() => _busy = false);
      if (widget.connectOnOpen && _error == null) await _connect();
    }
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
      _connected = false;
    });
    try {
      await _vision.init();
      if (!_vision.isConfigured) {
        setState(
          () => _error = 'Cloud Vision is not available yet. Cameras can be connected once the cloud service is activated.',
        );
        return;
      }
      final health = await _vision.connectCloud();
      await _loadData();
      if (mounted) {
        setState(() {
          _connected = true;
          _health = health;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Cloud Vision could not connect. Check your internet connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadData() async {
    final health = await _vision.request('/health');
    final cameras = await _vision.request('/cameras');

    if (!mounted) return;
    setState(() {
      _health = health;
      _cameras = cameras['cameras'] as List? ?? [];
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _loadData();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The request failed. Check the server connection and refresh.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCamera() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddCameraScreen()),
    );
    if (saved == true && mounted) await _run(() async {});
  }

  Future<void> _remove(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('Remove this camera?'),
        content: Text(
          'This stops processing and removes the camera from Cloud Vision.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(() async {
        await _vision.request(
          '/cameras/${Uri.encodeComponent(id)}',
          method: 'DELETE',
        );
      });
    }
  }

  Widget _camera(dynamic value) {
    final data = Map<String, dynamic>.from(value as Map);
    final id = data['camera_id'].toString();
    final enabled = data['enabled'] == true;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['name']?.toString() ?? 'Camera',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${data['status'] ?? 'offline'} · ${enabled ? 'Enabled' : 'Stopped'}',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LiveFeedScreen(
                              camera: Camera(
                                id: id,
                                businessId:
                                    data['business_id']?.toString() ?? '',
                                name: data['name']?.toString() ?? 'Camera',
                                status: data['status']?.toString() ?? 'offline',
                                aiEnabled: enabled,
                              ),
                            ),
                          ),
                        ),
                  icon: Icon(Icons.play_circle_outline),
                  label: Text('View live'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          await _vision.request(
                            '/cameras/${Uri.encodeComponent(id)}/${enabled ? 'stop' : 'start'}',
                            method: 'POST',
                          );
                        }),
                  child: Text(enabled ? 'Stop' : 'Start'),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _remove(id),
                  child: Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Cloud Vision')),
    body: ListView(
      padding: TrexvenSpacing.cardPadding,
      children: [
        Text('Cloud Vision', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Manage your cameras through the cloud. No in-store computer or shared Wi-Fi connection is required.',
        ),
        const SizedBox(height: 16),
        if (!_busy && !_connected && _error == null)
          const Text(
            'Cloud Vision is not available yet. Cameras can be connected once the cloud service is activated.',
          ),
        if (!_busy && !_connected) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _connect,
            icon: const Icon(Icons.cloud_sync_outlined),
            label: const Text('Check connection'),
          ),
        ],
        if (_busy)
          const SizedBox(
            height: 220,
            child: TrexvenSkeleton(kind: TrexvenSkeletonKind.detail),
          ),
        if (_error != null)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_connected) ...[
          SizedBox(height: TrexvenSpacing.fieldGap),
          Text(
            'Connected · Cloud Vision ${_health?['status'] ?? 'unknown'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Processing: ${_health?['processing'] == true ? 'active' : 'idle'} · Cameras: ${_health?['cameras_registered'] ?? 0}',
          ),
          if (_health?['has_errors'] == true)
            Text(
              'Cloud Vision reports a processing issue. Please contact support.',
            ),
          Wrap(
            spacing: 12,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : () => _run(() async {}),
                icon: Icon(Icons.refresh),
                label: Text('Refresh'),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _addCamera,
                icon: Icon(Icons.add),
                label: Text('Add camera'),
              ),
            ],
          ),
          ..._cameras.map(_camera),
          if (_cameras.isEmpty)
            Text('No cameras registered. Add a camera stream to begin.'),
        ],
      ],
    ),
  );
}
