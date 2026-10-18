import 'package:flutter/material.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../core/app_theme.dart';
import 'trexven_widgets.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;
    final muted = theme.trexvenColors.muted ?? Colors.grey;
    final errorColor = theme.trexvenColors.error ?? Colors.red;

    final bool isLowStock = title.toLowerCase().contains('low stock');

    return TrexvenTapCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.05),
      hasBorder: false,
      child: MetricContent(
        title: title,
        value: value,
        icon: icon,
        color: isLowStock ? errorColor : brandBlue,
        valueStyle: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface,
          height: 1.1,
        ),
        titleStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
      ),
    );
  }
}
