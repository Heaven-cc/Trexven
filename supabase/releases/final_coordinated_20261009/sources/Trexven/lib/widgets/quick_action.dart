import 'package:flutter/material.dart';
import 'trexven_widgets.dart';

class QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const QuickAction({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.colorScheme.primary;

    return TrexvenTapCard(
      onTap: onTap,
      borderRadius: 15,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 17,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: brandBlue,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
