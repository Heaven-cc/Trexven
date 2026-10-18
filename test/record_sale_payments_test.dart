import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:odt/models/product.dart';
import 'package:odt/screens/finance/record_sale_screen.dart';
import 'record_sale_flow_test.dart' show FakeDatabase;

Future<void> frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Future<void> choose(WidgetTester tester, String name) async {
  await tester.ensureVisible(find.text('Search or select products'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Search or select products'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Finder input(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> confirm(WidgetTester tester) async {
  final checkbox = find.byType(Checkbox).last;
  await tester.ensureVisible(checkbox);
  await tester.tap(checkbox);
  await frames(tester);
  final button =
      find.widgetWithText(FilledButton, 'Confirm Payment').evaluate().isNotEmpty
      ? find.widgetWithText(FilledButton, 'Confirm Payment')
      : find.widgetWithText(FilledButton, 'Request Approval');
  await tester.tap(button);
  await frames(tester);
}

void main() {
  testWidgets(
    'Searchable cart merges, independently edits and removes products; requires confirmation',
    (tester) async {
      final db = FakeDatabase();
      await tester.pumpWidget(
        MaterialApp(
          theme: TrexvenTheme.lightTheme,
          home: RecordSaleScreen(database: db),
        ),
      );
      db.updates.add([
        Product(id: 'rice', name: 'Rice', unit: 'kg', price: 10, stock: 5),
        Product(id: 'milk', name: 'Milk', price: 5, stock: 5),
      ]);
      await frames(tester);
      await choose(tester, 'Rice');
      await choose(tester, 'Milk');
      await choose(tester, 'Rice');
      await tester.tap(find.byKey(const ValueKey('quantity-rice')));
      await frames(tester);
      await tester.enterText(
        find.byKey(const ValueKey('record-sale-quantity-input')),
        '2.5',
      );
      await tester.tap(find.text('Apply'));
      await frames(tester);
      final milkRow = find
          .ancestor(of: find.text('Milk'), matching: find.byType(Row))
          .first;
      await tester.tap(
        find.descendant(
          of: milkRow,
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await frames(tester);
      await choose(tester, 'Milk');
      final submit = find.byKey(const ValueKey('record-sale-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await frames(tester);
      expect(db.submissions, 0);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm Payment'),
            )
            .onPressed,
        isNull,
      );
      await confirm(tester);
      expect(db.submissions, 1);
      expect(db.submittedItems, [
        {
          'product_id': 'rice',
          'quantity': 2.5,
          'unit_price': 10.0,
          'discount': 0,
        },
        {'product_id': 'milk', 'quantity': 1, 'unit_price': 5.0, 'discount': 0},
      ]);
      expect(db.submitted!.totalPrice, 30);
      db.result.complete('one-cart-receipt');
      await frames(tester);
      await tester.pumpWidget(const SizedBox());
      await db.updates.close();
    },
  );
  for (final method in ['Terminal', 'Transfer']) {
    testWidgets(
      '$method needs external reference and explicit user confirmation',
      (tester) async {
        final db = FakeDatabase();
        await tester.pumpWidget(
          MaterialApp(
            theme: TrexvenTheme.lightTheme,
            home: RecordSaleScreen(database: db),
          ),
        );
        db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 5)]);
        await frames(tester);
        await choose(tester, 'Widget');
        await tester.ensureVisible(find.text(method));
        await tester.tap(find.text(method));
        await tester.ensureVisible(
          find.byKey(const ValueKey('record-sale-submit')),
        );
        await tester.tap(find.byKey(const ValueKey('record-sale-submit')));
        await frames(tester);
        await confirm(tester);
        expect(db.submissions, 0);
        expect(
          find.text('External confirmation reference required.'),
          findsOneWidget,
        );
        final reference = method == 'Terminal'
            ? input('Verified payment reference').last
            : input('Verified payment reference').first;
        await tester.ensureVisible(reference);
        await tester.enterText(reference, 'synthetic-reference');
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm Payment'));
        await tester.pump();
        expect(db.submissions, 1);
        expect(
          db.confirmedPayments.single!.single['method'],
          method == 'Terminal' ? 'card' : 'bank_transfer',
        );
        expect(
          db.confirmedPayments.single!.single['evidence'],
          'synthetic-reference',
        );
        db.result.complete('external-receipt');
        await frames(tester);
        await tester.pumpWidget(const SizedBox());
        await db.updates.close();
      },
    );
  }
  for (final partial in [false, true]) {
    testWidgets(
      '${partial ? 'Partial' : 'Full'} credit collects debtor details and requires an explicit exact-cart approval',
      (tester) async {
        final db = FakeDatabase()..requiresApproval = true;
        await tester.pumpWidget(
          MaterialApp(
            theme: TrexvenTheme.lightTheme,
            home: RecordSaleScreen(database: db),
          ),
        );
        db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 5)]);
        await frames(tester);
        await choose(tester, 'Widget');
        await tester.ensureVisible(find.text('Credit'));
        await tester.tap(find.text('Credit'));
        await tester.ensureVisible(
          find.byKey(const ValueKey('record-sale-submit')),
        );
        await tester.tap(find.byKey(const ValueKey('record-sale-submit')));
        await frames(tester);
        for (final pair in [
          ('Debtor name', 'Customer'),
          ('Contact reference', 'synthetic-phone'),
          ('Due date (YYYY-MM-DD)', '2026-12-31'),
        ]) {
          await tester.ensureVisible(input(pair.$1));
          await tester.enterText(input(pair.$1), pair.$2);
        }
        if (partial) {
          await tester.ensureVisible(input('Amount received').first);
          await tester.enterText(input('Amount received').first, '4.00');
        }
        await confirm(tester);
        expect(db.approvalCalls, 0);
        expect(db.submissions, 1);
        expect(find.text('Review credit approval'), findsOneWidget);
        await tester.tap(find.text('Approve credit'));
        await frames(tester);
        expect(db.approvalCalls, 1);
        expect(db.submissions, 2);
        expect(db.keys[0], db.keys[1]);
        expect(db.submittedCredit, {
          'debtor_name': 'Customer',
          'contact': 'synthetic-phone',
          'due_date': '2026-12-31',
        });
        expect(
          db.confirmedPayments.last!.fold<double>(
            0,
            (sum, p) => sum + (p['amount'] as num).toDouble(),
          ),
          partial ? 4 : 0,
        );
        db.result.complete('credit-receipt');
        await frames(tester);
        await tester.pumpWidget(const SizedBox());
        await db.updates.close();
      },
    );
  }
}
