import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';

/// A build failure may replace a widget inside an unbounded scrolling form.
/// Keep the fallback bounded instead of inserting another full-screen Scaffold.
class BuildErrorFallback extends StatelessWidget {
  const BuildErrorFallback({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => LimitedBox(
    maxWidth: 360,
    maxHeight: 240,
    child: Material(
      child: SingleChildScrollView(
        padding: TrexvenSpacing.cardPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              'Unable to display this control. Please restart this screen.',
              textAlign: TextAlign.center,
            ),
            TextButton(onPressed: onRetry, child: Text('Try to Restart')),
          ],
        ),
      ),
    ),
  );
}
