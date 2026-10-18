import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odt/services/business_reporting.dart';
import 'package:odt/screens/finance/finance_tab.dart';
import 'record_sale_flow_test.dart' show FakeDatabase;

class FinanceDatabase extends FakeDatabase {
  int salesRequests = 0;
  int statsRequests = 0;
  bool fail = false;
  @override
  Future<FinanceReport> getFinanceReport(
    String duration, {
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    salesRequests++;
    statsRequests++;
    if (fail) throw Exception('offline');
    final period = BusinessPeriod.fromDay(
      {'timezone': 'Africa/Lagos', 'local_date': '2026-10-13'},
      duration,
      customStart: customStart,
      customEnd: customEnd,
    );
    return FinanceReport(
      period,
      {
        'gross_sales': '500.00',
        'net_collected': '450.00',
        'refunds': '50.00',
        'sale_collections': '500.00',
        'repayment_collections': '0.00',
      },
      List.generate(
        50,
        (i) => {
          'id': 's$i',
          'total': 10,
          'created_at': '2026-10-13T01:00:00Z',
          'sale_items': [
            {'product_name': 'Product $i', 'quantity': 1, 'unit_price': 10},
          ],
        },
      ),
      [
        {'amount': 25, 'created_at': '2026-10-13T01:00:00Z'},
      ],
    );
  }
}

void main() {
  testWidgets('Finance retains requests on rebuild and refreshes explicitly', (
    tester,
  ) async {
    final db = FinanceDatabase();
    Future<void> show(Brightness brightness) => tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light
            ? TrexvenTheme.lightTheme
            : TrexvenTheme.darkTheme,
        home: FinanceTab(database: db),
      ),
    );
    await show(Brightness.light);
    await tester.pumpAndSettle();
    expect(db.salesRequests, 1);
    expect(db.statsRequests, 1);
    expect(find.text('Product 49'), findsNothing);
    await show(Brightness.dark);
    await tester.pumpAndSettle();
    expect(db.salesRequests, 1);
    expect(db.statsRequests, 1);
    final refreshing = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refreshing;
    expect(db.salesRequests, 2);
    expect(db.statsRequests, 2);
    await tester.scrollUntilVisible(
      find.text('Product 7'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Product 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await db.updates.close();
  });

  testWidgets('Finance failure is visible and retry recovers', (tester) async {
    final db = FinanceDatabase()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: TrexvenTheme.lightTheme,
        home: FinanceTab(database: db),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to load revenue. Please retry.'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to load transactions. Please retry.'),
      findsOneWidget,
    );
    db.fail = false;
    await tester.tap(find.text('Retry').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('₦500.00').first,
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('₦500.00'), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(
      find.text('Product 0'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Product 0'), findsOneWidget);
    expect(db.salesRequests, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await db.updates.close();
  });
}
