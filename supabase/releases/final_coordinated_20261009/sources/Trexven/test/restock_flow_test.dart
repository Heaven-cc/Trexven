import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:odt/core/app_theme.dart';
import 'package:odt/models/product.dart';
import 'package:odt/screens/inventory/add_product_screen.dart';
import 'record_sale_flow_test.dart' show FakeDatabase;

class RestockDatabase extends FakeDatabase {
  int? savedStock;
  String? savedId;
  Completer<void>? completion;
  int writes = 0;
  @override
  Future<void> adjustProductStock(String productId, num delta, String reason, String requestId) async {
    savedId = productId;
    savedStock = delta.toInt();
    writes++;
    if (completion != null) await completion!.future;
  }
}

Future<void> openRestock(WidgetTester tester, RestockDatabase db) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: AddProductScreen(database: db),
    ),
  );
  await tester.tap(find.text('Restock existing'));
  await tester.pump();
}

void main() {
  testWidgets(
    'Restock survives fresh product objects, typing, and menu dismissal',
    (tester) async {
      final db = RestockDatabase();
      await openRestock(tester, db);
      final initialBarriers = find.byType(ModalBarrier).evaluate().length;
      db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 5)]);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Widget').last);
      await tester.pumpAndSettle();
      db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 8)]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.pumpAndSettle();
      expect(db.subscriptions, 1);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(ModalBarrier), findsNWidgets(initialBarriers + 1));
      await tester.tapAt(const Offset(798, 598));
      await tester.pumpAndSettle();
      expect(find.byType(ModalBarrier), findsNWidgets(initialBarriers));
      final submit = find.byType(FilledButton);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(db.savedId, 'p');
      expect(db.savedStock, 2);
      await tester.pumpWidget(const SizedBox());
      await db.updates.close();
    },
  );

  testWidgets(
    'Restock distinguishes loading, failure, retry, empty, and deleted selection',
    (tester) async {
      final db = RestockDatabase();
      await openRestock(tester, db);
      expect(find.text('Loading products…'), findsOneWidget);
      db.updates.addError(Exception('network unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to load products. Check your connection and retry.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      db.updates.add([]);
      await tester.pumpAndSettle();
      expect(
        find.text('No products available. Add a product before restocking.'),
        findsOneWidget,
      );
      db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 5)]);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Widget').last);
      await tester.pumpAndSettle();
      db.updates.add([]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await db.updates.close();
    },
  );

  testWidgets(
    'Stalled product load becomes retryable instead of loading forever',
    (tester) async {
      final db = RestockDatabase();
      await openRestock(tester, db);
      await tester.pump(const Duration(seconds: 21));
      expect(
        find.text('Unable to load products. Check your connection and retry.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await db.updates.close();
    },
  );

  testWidgets(
    'Failed stock update restores controls and repeated taps write once',
    (tester) async {
      final db = RestockDatabase()..completion = Completer<void>();
      await openRestock(tester, db);
      db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 5)]);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Widget').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.pumpAndSettle();
      final submit = find.byType(FilledButton);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(db.writes, 1);
      db.completion!.completeError(Exception('stock update rejected'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to update stock'), findsOneWidget);
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      expect(db.subscriptions, 1);
      await tester.pumpWidget(const SizedBox());
      await db.updates.close();
    },
  );
}
