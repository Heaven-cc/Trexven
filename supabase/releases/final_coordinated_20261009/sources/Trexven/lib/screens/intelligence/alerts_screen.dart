import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/alert_service.dart';
import '../../services/alert_navigation.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.alertService});
  final AlertService? alertService;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final _alertService = widget.alertService ?? AlertService();

  @override
  void initState() {
    super.initState();
    _alertService.addListener(_onAlertsChanged);
    _alertService.refresh();
  }

  @override
  void dispose() {
    _alertService.removeListener(_onAlertsChanged);
    super.dispose();
  }

  void _onAlertsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alerts = _alertService.alerts;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Notifications',
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
            tooltip: 'Refresh notifications',
            onPressed: _alertService.refresh,
            icon: const Icon(Icons.refresh),
          ),
          if (alerts.any((a) => a['is_read'] != true))
            TextButton(
              onPressed: () async {
                try {
                  await _alertService.markAllRead();
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Some notifications could not be marked read. Please retry.',
                        ),
                      ),
                    );
                }
              },
              child: Text(
                'Mark all read',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_alertService.connectionError != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_alertService.connectionError!),
            ),
          Expanded(
            child: _alertService.loading
                ? const Center(child: CircularProgressIndicator())
                : alerts.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      return _buildAlertCard(theme, alert);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(ThemeData theme, Map<String, dynamic> alert) {
    final isRead = alert['is_read'] == true;
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final brandBlue = theme.colorScheme.primary;

    final severity = alert['severity']?.toString().toLowerCase() ?? 'info';
    final title = alert['title']?.toString() ?? 'Security Alert';
    final message = alert['message']?.toString() ?? '';
    final createdAt = DateTime.tryParse(alert['created_at'] ?? '')?.toLocal();

    final dateStr = createdAt != null
        ? DateFormat('MMM d, h:mm a').format(createdAt)
        : '';

    Color badgeColor;
    IconData icon;

    switch (severity) {
      case 'critical':
        badgeColor = theme.trexvenColors.error ?? Colors.red;
        icon = Icons.warning_amber_rounded;
        break;
      case 'warning':
        badgeColor = theme.trexvenColors.warning ?? Colors.orange;
        icon = Icons.error_outline_rounded;
        break;
      default:
        badgeColor = brandBlue;
        icon = Icons.info_outline_rounded;
    }

    return GestureDetector(
      onTap: () => openAlertDestination(context, alert, service: _alertService),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead
              ? theme.trexvenColors.cardBackground
              : brandBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? (theme.trexvenColors.border ?? const Color(0xFFE2E8F0))
                : brandBlue.withOpacity(0.15),
            width: isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: badgeColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isRead
                                ? FontWeight.w700
                                : FontWeight.w900,
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (alert['camera_name'] != null)
                    Text(
                      alert['camera_name'].toString(),
                      style: TextStyle(color: muted),
                    ),
                  Text(
                    message,
                    style: TextStyle(fontSize: 13, color: muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.trexvenColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 48, color: muted),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Important camera and business notifications will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
