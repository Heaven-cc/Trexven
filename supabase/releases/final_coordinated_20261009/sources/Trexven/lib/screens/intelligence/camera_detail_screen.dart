import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
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
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final brandBlue = theme.colorScheme.primary;
    final online = _camera.status.toLowerCase() == 'online';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Camera',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _deleteCamera,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: theme.trexvenColors.error,
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
              color: theme.brightness == Brightness.dark 
                  ? theme.colorScheme.surface 
                  : theme.trexvenColors.brandDark,
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
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _camera.location?.isNotEmpty == true
                ? _camera.location!
                : 'Location not specified',
            style: TextStyle(
              color: muted,
            ),
          ),
          const SizedBox(height: 20),
          _infoCard(
            theme,
            title: 'Connection',
            icon: Icons.wifi_rounded,
            value: online ? 'Online' : 'Offline',
            valueColor:
            online ? (theme.trexvenColors.success ?? Colors.green) : muted,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.trexvenColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
              ),
            ),
            child: SwitchListTile(
              value: _camera.aiEnabled,
              onChanged: _loading ? null : _toggleAI,
              title: Text(
                'Camera Intelligence',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                _camera.aiEnabled
                    ? 'AI analysis is enabled'
                    : 'AI analysis is disabled',
                style: TextStyle(color: muted),
              ),
              secondary: Icon(
                Icons.auto_awesome,
                color: brandBlue,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _actionTile(
            theme,
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
            theme,
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

  Widget _infoCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required String value,
    required Color valueColor,
  }) {
    return Card(
      elevation: 0,
      color: theme.trexvenColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: TextStyle(color: theme.colorScheme.onSurface)),
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

  Widget _actionTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Card(
      elevation: 0,
      color: theme.trexvenColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.08),
          child: Icon(
            icon,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(color: muted)),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: muted.withOpacity(0.4),
        ),
      ),
    );
  }
}