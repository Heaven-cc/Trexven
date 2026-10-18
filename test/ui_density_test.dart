import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odt/models/product.dart';
import 'package:odt/screens/finance/record_sale_screen.dart';
import 'record_sale_flow_test.dart' show FakeDatabase;

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 1000),
    const Size(780, 360),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Record Sale fits $size at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = FakeDatabase();
        await tester.pumpWidget(
          MaterialApp(
            theme: scale == 1
                ? TrexvenTheme.lightTheme
                : TrexvenTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RecordSaleScreen(database: db),
          ),
        );
        db.updates.add([
          Product(id: 'p', name: 'Widget', price: 1234567890.12, stock: 10),
        ]);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Search or select products'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Widget').last);
        await tester.pumpAndSettle();
        final submit = find.byKey(const ValueKey('record-sale-submit'));
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Compact actions retain the approved minimum 48px touch target.
        expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
        expect(submit.hitTestable(), findsOneWidget);
        await tester.tap(submit);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        // Opening checkout must not submit before actual payment confirmation.
        expect(db.submissions, 0);
        expect(find.text('Confirm Payment'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await db.updates.close();
      });
    }
  }

  testWidgets('Shared action grows for long labels and large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TrexvenTheme.lightTheme,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SizedBox(
              width: 240,
              child: TrexvenButton(
                text: 'Save business profile changes',
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ElevatedButton)).height, greaterThan(56));
  });
}
