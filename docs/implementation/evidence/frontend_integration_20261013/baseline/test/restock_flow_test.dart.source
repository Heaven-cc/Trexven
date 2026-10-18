import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:odt/models/product.dart';
import 'package:odt/screens/inventory/add_product_screen.dart';
import 'record_sale_flow_test.dart' show FakeDatabase;

class RestockDatabase extends FakeDatabase {
  int? savedStock;
  String? savedId;
  Completer<void>? completion;
  int writes = 0;
  final prices = <Map<String, dynamic>>[];
  final priceRequests = <String>[];
  final stockRequests = <String>[];
  bool rejectPrice = false;
  @override
  Future<String> saveCatalogProduct(
    String? id,
    Map<String, dynamic> fields,
    String requestId,
  ) async {
    prices.add(Map.of(fields));
    priceRequests.add(requestId);
    if (rejectPrice) throw Exception('price rejected');
    return id!;
  }

  @override
  Future<void> adjustProductStock(
    String productId,
    num delta,
    String reason,
    String requestId,
  ) async {
    savedId = productId;
    savedStock = delta.toInt();
    writes++;
    stockRequests.add(requestId);
    if (completion != null) await completion!.future;
  }
}

Future<void> openRestock(WidgetTester tester, RestockDatabase db) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: TrexvenTheme.lightTheme,
      home: AddProductScreen(database: db),
    ),
  );
  await tester.tap(find.text('Restock existing'));
  await tester.pump();
}

void main() {
  Future<void> selectProduct(WidgetTester tester, RestockDatabase db) async {
    await openRestock(tester, db);
    db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 5)]);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Widget').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '2');
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.byType(FilledButton);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Restock validates and saves only the edited selling price before stock',
    (tester) async {
      final db = RestockDatabase();
      await selectProduct(tester, db);
      final price = find.byType(TextFormField).last;
      expect(tester.widget<TextFormField>(price).controller!.text, '10.00');
      await tester.enterText(price, '12.345');
      await submit(tester);
      expect(
        find.text('Enter a non-negative price with up to two decimal places.'),
        findsOneWidget,
      );
      expect(db.prices, isEmpty);
      expect(db.writes, 0);
      await tester.enterText(price, '12.50');
      await submit(tester);
      expect(db.prices, [
        {'selling_price': 12.5},
      ]);
      expect(db.savedStock, 2);
      expect(db.priceRequests.single, isNot(db.stockRequests.single));
      await tester.pumpWidget(const SizedBox());
      await db.updates.close();
    },
  );

  testWidgets(
    'Rejected selling price prevents restock and retry preserves intent and identity',
    (tester) async {
      final db = RestockDatabase()..rejectPrice = true;
      await selectProduct(tester, db);
      await tester.enterText(find.byType(TextFormField).last, '12.50');
      await submit(tester);
      expect(db.writes, 0);
      expect(db.prices, [
        {'selling_price': 12.5},
      ]);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).last).enabled,
        isFalse,
      );
      db.rejectPrice = false;
      await submit(tester);
      expect(db.writes, 1);
      expect(db.priceRequests[1], db.priceRequests[0]);
      expect(db.prices[1], db.prices[0]);
      await tester.pumpWidget(const SizedBox());
      await db.updates.close();
    },
  );

  testWidgets('Committed price is not repeated when stock update needs retry', (
    tester,
  ) async {
    final db = RestockDatabase()..completion = Completer<void>();
    await selectProduct(tester, db);
    await tester.enterText(find.byType(TextFormField).last, '12.50');
    final button = find.byType(FilledButton);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    db.completion!.completeError(Exception('stock update rejected'));
    await tester.pumpAndSettle();
    expect(find.textContaining('stock update is unconfirmed'), findsOneWidget);
    db.completion = null;
    await submit(tester);
    expect(db.prices, hasLength(1));
    expect(db.writes, 2);
    expect(db.stockRequests[1], db.stockRequests[0]);
    await tester.pumpWidget(const SizedBox());
    await db.updates.close();
  });

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
      await tester.enterText(find.byType(TextFormField).first, '2');
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
      await tester.enterText(find.byType(TextFormField).first, '2');
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
