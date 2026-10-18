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
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 32,
            ),
            const SizedBox(height: 8),
            const Text(
              'Unable to display this control. Please restart this screen.',
              textAlign: TextAlign.center,
            ),
            TextButton(onPressed: onRetry, child: const Text('Try to Restart')),
          ],
        ),
      ),
    ),
  );
}
