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
  final _url = TextEditingController();
  final _key = TextEditingController();
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
      _url.text = _vision.baseUrl;
      _key.text = _vision.apiKey;
    } catch (_) {
      if (mounted) {
        _error =
            'Could not load saved pairing. Please enter the address and key.';
      }
    }
    if (mounted) {
      setState(() => _busy = false);
      if (widget.connectOnOpen && _error == null) await _connect();
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
      _connected = false;
    });
    try {
      final health = await _vision.verifyConnection(_url.text, _key.text);
      await _vision.setServerUrl(_url.text);
      await _vision.setApiKey(_key.text);
      await _vision.pairBusiness();
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
          () => _error =
              'Connection failed. Check the server address, API key, Wi-Fi and firewall.',
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
      MaterialPageRoute(builder: (_) => const AddCameraScreen()),
    );
    if (saved == true && mounted) await _run(() async {});
  }

  Future<void> _remove(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this camera?'),
        content: const Text(
          'This stops processing and removes the camera from the Vision Server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
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
        padding: const EdgeInsets.all(12),
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
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('View frame'),
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
                  child: const Text('Remove'),
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
    appBar: AppBar(title: const Text('Vision Server')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Connect to your local Vision Server. Keep this device and the server on the same Wi-Fi.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _url,
          enabled: !_busy,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Server address',
            hintText: 'http://192.168.1.19:8000',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          enabled: !_busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Vision API key'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _connect,
          child: const Text('Connect and save'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_connected) ...[
          const SizedBox(height: 16),
          Text(
            'Connected · Server ${_health?['status'] ?? 'unknown'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Processing: ${_health?['processing'] == true ? 'active' : 'idle'} · Cameras: ${_health?['cameras_registered'] ?? 0}',
          ),
          if (_health?['has_errors'] == true)
            const Text(
              'The server reports a model or storage issue. Check the server logs.',
            ),
          Wrap(
            spacing: 12,
            children: [
              TextButton.icon(
                onPressed: _busy ? null : () => _run(() async {}),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _addCamera,
                icon: const Icon(Icons.add),
                label: const Text('Add camera'),
              ),
            ],
          ),
          ..._cameras.map(_camera),
          if (_cameras.isEmpty)
            const Text('No cameras registered. Add a camera stream to begin.'),
        ],
      ],
    ),
  );
}
