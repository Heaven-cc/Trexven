import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
            fontSize: TrexvenFontSize.section,
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
            icon: Icon(Icons.refresh),
          ),
          if (alerts.any((a) => a['is_read'] != true))
            TextButton(
              onPressed: () async {
                try {
                  await _alertService.markAllRead();
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
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
              padding: EdgeInsets.all(12),
              child: Text(_alertService.connectionError!),
            ),
          Expanded(
            child: _alertService.loading
                ? const TrexvenSkeleton(kind: TrexvenSkeletonKind.notifications)
                : alerts.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: EdgeInsets.all(18),
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
    final muted = theme.trexvenColors.muted!;
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
        badgeColor = theme.trexvenColors.error!;
        icon = Icons.warning_amber_rounded;
        break;
      case 'warning':
        badgeColor = theme.trexvenColors.warning!;
        icon = Icons.error_outline_rounded;
        break;
      default:
        badgeColor = brandBlue;
        icon = Icons.info_outline_rounded;
    }

    return GestureDetector(
      onTap: () => openAlertDestination(context, alert, service: _alertService),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: TrexvenSpacing.cardPadding,
        decoration: BoxDecoration(
          color: isRead
              ? theme.trexvenColors.cardBackground
              : brandBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(TrexvenRadii.card),
              ),
              child: Icon(icon, color: badgeColor, size: 22),
            ),
            SizedBox(width: 14),
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
                            fontSize: TrexvenFontSize.body,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: TrexvenFontSize.caption,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  if (alert['camera_name'] != null)
                    Text(
                      alert['camera_name'].toString(),
                      style: TextStyle(color: muted),
                    ),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: TrexvenFontSize.body,
                      color: muted,
                      height: 1.4,
                    ),
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
    final muted = theme.trexvenColors.muted!;

    return Center(
      child: Container(
        padding: EdgeInsets.all(32),
        margin: TrexvenSpacing.pagePadding,
        decoration: BoxDecoration(
          color: theme.trexvenColors.cardBackground,
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 48, color: muted),
            SizedBox(height: TrexvenSpacing.fieldGap),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: TrexvenFontSize.input,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Important camera and business notifications will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: TrexvenFontSize.body, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
