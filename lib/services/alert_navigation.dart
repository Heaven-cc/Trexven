import 'package:flutter/material.dart';
import '../screens/intelligence/event_detail_screen.dart';
import 'alert_service.dart';
import '../screens/finance/operational_finance_screen.dart';
import '../screens/inventory/inventory_tab.dart';
import '../screens/me/employment_screen.dart';

Future<void> openAlertDestination(
  BuildContext context,
  Map<String, dynamic> alert, {
  AlertService? service,
}) async {
  try {
    if (alert['id'] != null) {
      await (service ?? AlertService()).markRead(alert['id'].toString());
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to mark notification read. Please retry.'),
        ),
      );
    }
  }
  if (!context.mounted) return;
  final eventId = alert['reference_id'];
  final source = alert['source'];
  if (eventId != null &&
      (source == 'vision_local' ||
          source == 'vision_intelligence' ||
          source == 'camera_ai')) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(
          eventId: eventId.toString(),
          source: source == 'camera_ai' ? 'supabase' : source.toString(),
        ),
      ),
    );
  } else if (alert['route'] == 'inventory') {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InventoryTab()),
    );
  } else if (alert['route'] == 'cash') {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OperationalFinanceScreen()),
    );
  } else if (alert['route'] == 'employees') {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EmploymentScreen()),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(alert['title']?.toString() ?? 'Notification'),
        content: Text(alert['message']?.toString() ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
