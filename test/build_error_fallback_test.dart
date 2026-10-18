import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odt/widgets/build_error_fallback.dart';

void main() {
  testWidgets(
    'Build error fallback is bounded inside a scrolling form and retry works',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const Text('Product'),
                  BuildErrorFallback(onRetry: () => retries++),
                  const Text('Quantity received'),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(BuildErrorFallback)).height,
        lessThanOrEqualTo(240),
      );
      await tester.tap(find.text('Try to Restart'));
      expect(retries, 1);
      expect(find.text('Quantity received'), findsOneWidget);
    },
  );
}
