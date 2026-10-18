import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odt/models/product.dart';
import 'package:odt/screens/inventory/inventory_tab.dart';
import 'record_sale_flow_test.dart' show FakeDatabase;

void main() {
  testWidgets('Inventory search retains its stream; failure can be retried', (
    tester,
  ) async {
    final db = FakeDatabase();
    await tester.pumpWidget(
      MaterialApp(
        theme: TrexvenTheme.lightTheme,
        home: InventoryTab(database: db),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 8)]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Wid');
    await tester.pumpAndSettle();
    expect(find.text('Widget'), findsOneWidget);
    expect(db.subscriptions, 1);
    db.updates.addError(Exception('network unavailable'));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to load inventory. Please retry.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 9)]);
    await tester.pumpAndSettle();
    expect(find.text('Widget'), findsOneWidget);
    expect(db.subscriptions, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await db.updates.close();
  });
}
