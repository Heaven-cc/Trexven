import 'package:flutter/material.dart';

import '../../models/camera.dart';
import '../../services/camera_intelligence_service.dart';
import 'camera_event_screen.dart';
import 'camera_alert_screen.dart';

class CameraDetailScreen extends StatefulWidget {
  final Camera camera;

  const CameraDetailScreen({
    super.key,
    required this.camera,
  });

  @override
  State<CameraDetailScreen> createState() =>
      _CameraDetailScreenState();
}

class _CameraDetailScreenState
    extends State<CameraDetailScreen> {
  final CameraIntelligenceService _intelligenceService = CameraIntelligenceService();

  late Camera _camera;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _camera = widget.camera;
  }

  Future<void> _toggleAI(bool enabled) async {
    setState(() {
      _loading = true;
    });

    try {
      await _intelligenceService.setAiEnabled(
        _camera.id,
        enabled,
      );

      if (!mounted) return;

      setState(() {
        _camera = _camera.copyWith(aiEnabled: enabled);
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Camera intelligence enabled.'
                : 'Camera intelligence disabled.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update AI: $e'),
        ),
      );
    }
  }

  Future<void> _deleteCamera() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete camera?'),
        content: const Text(
          'This will remove this camera from the business.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _intelligenceService.deleteCamera(_camera.id);

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete camera: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = _camera.status.toLowerCase() == 'online';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: const Text(
          'Camera',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _deleteCamera,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.red,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            height: 210,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(
                Icons.videocam_rounded,
                color: Colors.white54,
                size: 60,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _camera.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _camera.location?.isNotEmpty == true
                ? _camera.location!
                : 'Location not specified',
            style: const TextStyle(
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          _infoCard(
            title: 'Connection',
            icon: Icons.wifi_rounded,
            value: online ? 'Online' : 'Offline',
            valueColor:
            online ? Colors.green.shade700 : Colors.grey,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(
                color: Color(0xFFE2E8F0),
              ),
            ),
            child: SwitchListTile(
              value: _camera.aiEnabled,
              onChanged: _loading ? null : _toggleAI,
              title: const Text(
                'Camera Intelligence',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                _camera.aiEnabled
                    ? 'AI analysis is enabled'
                    : 'AI analysis is disabled',
              ),
              secondary: const Icon(
                Icons.auto_awesome,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _actionTile(
            icon: Icons.timeline_rounded,
            title: 'Camera Events',
            subtitle: 'View detected activity',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraEventsScreen(
                    camera: _camera,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _actionTile(
            icon: Icons.warning_amber_rounded,
            title: 'Camera Alerts',
            subtitle: 'Review important security events',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraAlertsScreen(
                    camera: _camera,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required String value,
    required Color valueColor,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2563EB)),
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEFF6FF),
          child: Icon(
            icon,
            color: const Color(0xFF2563EB),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_right_rounded,
        ),
      ),
    );
  }
}