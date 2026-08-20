import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/alert_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const _bg = Color(0xFFF8FAFC);
  static const _dark = Color(0xFF0F172A);
  static const _blue = Color(0xFF2563EB);
  static const _muted = Color(0xFF64748B);

  final _alertService = AlertService();

  @override
  void initState() {
    super.initState();
    _alertService.addListener(_onAlertsChanged);
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
    final alerts = _alertService.alerts;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Security Alerts',
          style: TextStyle(
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
          if (alerts.any((a) => a['is_read'] != true))
            TextButton(
              onPressed: () => _alertService.markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: alerts.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(18),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _buildAlertCard(alert);
              },
            ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final isRead = alert['is_read'] == true;
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
        badgeColor = const Color(0xFFEF4444);
        icon = Icons.warning_amber_rounded;
        break;
      case 'warning':
        badgeColor = const Color(0xFFF59E0B);
        icon = Icons.error_outline_rounded;
        break;
      default:
        badgeColor = _blue;
        icon = Icons.info_outline_rounded;
    }

    return GestureDetector(
      onTap: () {
        if (!isRead && alert['id'] != null) {
          _alertService.markRead(alert['id']);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE),
            width: isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
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
                            fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                            fontSize: 14,
                            color: _dark,
                          ),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 13, color: _muted, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 48, color: _muted),
            SizedBox(height: 16),
            Text(
              'No security alerts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'AI alerts generated by loitering, crowd detection or zone violations will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}
