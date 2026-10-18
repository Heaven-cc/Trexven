import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odt/models/product.dart';
import 'package:odt/core/app_theme.dart';
import 'package:odt/models/sale.dart';
import 'package:odt/services/database_service.dart';
import 'package:odt/screens/finance/record_sale_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeDatabase extends DatabaseService {
  FakeDatabase()
    : super(
        client: SupabaseClient(
          'https://example.invalid',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final updates = StreamController<List<Product>>.broadcast();
  Completer<String> result = Completer<String>();
  final keys = <String>[];
  final confirmedPayments = <List<Map<String, dynamic>>?>[];
  int subscriptions = 0;
  int submissions = 0;
  Sale? submitted;
  bool pendingRecovery = false;
  int recoveries = 0;
  @override
  Stream<List<Product>> getProductsStream() {
    subscriptions++;
    return updates.stream;
  }

  @override
  Future<String> recordSale(
    Sale sale, {
    required String requestId,
    String paymentMethod = 'cash',
    List<Map<String, dynamic>>? payments,
    String? shiftId,
  }) {
    submissions++;
    keys.add(requestId);
    confirmedPayments.add(payments);
    submitted = sale;
    return result.future;
  }

  @override
  Future<Map<String, dynamic>> saleCashContext() async {
    if (pendingRecovery) {
      throw OwnerOperationRecoveryRequired(canRecoverHere: true);
    }
    return {'configured': false, 'shifts': []};
  }

  @override
  Future<dynamic> recoverPendingOperation() async {
    recoveries++;
    pendingRecovery = false;
    return {'sale_number': 'TRX-prior-sale'};
  }
}

void main() {
  Future<void> confirmReceived(WidgetTester tester) async {
    // The page deliberately shows a progress indicator while confirmation is
    // open, so settling all animations would wait forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final confirmation = find.byType(CheckboxListTile).last;
    await tester.ensureVisible(confirmation);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(confirmation);
    await tester.pump();
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'Unconfirmed quick sale retries the same request and returns the receipt',
    (tester) async {
      final db = FakeDatabase();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RecordSaleScreen(database: db),
                  ),
                ),
                child: const Text('Open sale'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sale'));
      await tester.pump(const Duration(milliseconds: 400));
      db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 1)]);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Widget').last);
      await tester.pumpAndSettle();
      final submit = find.byType(FilledButton);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await confirmReceived(tester);
      db.result.completeError(Exception('response lost'));
      await tester.pumpAndSettle();
      // The original request stays available even if its committed stock change arrives.
      db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 0)]);
      await tester.pumpAndSettle();
      expect(find.textContaining('outcome is unconfirmed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      db.result = Completer();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(db.keys, hasLength(2));
      expect(db.keys[0], db.keys[1]);
      expect(db.confirmedPayments[1], db.confirmedPayments[0]);
      db.result.complete('TRX-saved-sale');
      await tester.pumpAndSettle();
      expect(find.text('Open sale'), findsOneWidget);
      expect(find.textContaining('Receipt: TRX-saved-sale'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await db.updates.close();
    },
  );
  testWidgets(
    'Selection and quantity survive fresh stream rows; double tap submits once',
    (tester) async {
      final db = FakeDatabase();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RecordSaleScreen(database: db),
        ),
      );
      Product product(int stock) =>
          Product(id: 'p', name: 'Widget', price: 10, stock: stock);
      db.updates.add([product(5)]);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Widget').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(db.subscriptions, 1);
      db.updates.add([product(4)]);
      await tester.pumpAndSettle();
      expect(find.text('4 in stock'), findsWidgets);
      expect(find.text('2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final submit = find.byType(FilledButton);
      await tester.ensureVisible(submit);
      final submitAgain = tester.widget<FilledButton>(submit).onPressed!;
      submitAgain();
      submitAgain();
      await confirmReceived(tester);
      expect(db.submissions, 1);
      expect(db.submitted!.quantity, 2);
      db.result.completeError(
        const PostgrestException(message: 'Insufficient stock', code: 'P0001'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Insufficient stock'), findsOneWidget);
      expect(db.subscriptions, 1);
      expect(find.textContaining('outcome is unconfirmed'), findsOneWidget);
      // A server rejection does not undo confirmed money. Keep the exact sale
      // and payment identity even if the product subsequently leaves the list.
      db.updates.add([]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      db.result = Completer<String>();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      expect(db.submissions, 2);
      expect(db.keys[1], db.keys[0]);
      expect(db.submitted!.quantity, 2);
      expect(db.submitted!.unitPrice, 10);
      expect(db.confirmedPayments[1], db.confirmedPayments[0]);
      db.result.completeError(
        const PostgrestException(message: 'Insufficient stock', code: 'P0001'),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await db.updates.close();
    },
  );

  testWidgets('pending financial intent blocks collecting a second payment', (
    tester,
  ) async {
    final db = FakeDatabase()..pendingRecovery = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: RecordSaleScreen(database: db),
      ),
    );
    db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 5)]);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Widget').last);
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('record-sale-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(db.submissions, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('outcome is unconfirmed'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final recover = find.text('Recover interrupted operation');
    await tester.ensureVisible(recover);
    await tester.tap(recover);
    await tester.pumpAndSettle();
    expect(db.recoveries, 1);
    expect(find.textContaining('Receipt: TRX-prior-sale'), findsOneWidget);
    expect(db.submissions, 0);
    await tester.pumpWidget(const SizedBox());
    await db.updates.close();
  });

  testWidgets(
    'fractional sale keeps exact units, payment and request on rejection',
    (tester) async {
      final db = FakeDatabase();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: RecordSaleScreen(database: db),
        ),
      );
      db.updates.add([
        Product(id: 'p', name: 'Rice', unit: 'kg', price: 10, stock: 3),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rice').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter quantity (kg)'));
      await tester.pumpAndSettle();
      final units = find.byKey(const ValueKey('record-sale-quantity-input'));
      await tester.enterText(units, '4');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Only 3 kg available.'), findsOneWidget);
      await tester.enterText(units, '2.5001');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.textContaining('three decimal places'), findsOneWidget);
      await tester.enterText(units, '2.5');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey('record-sale-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await confirmReceived(tester);
      expect(db.submitted!.quantity, 2.5);
      expect(db.submitted!.totalPrice, 25);
      expect(db.confirmedPayments.single, [
        {'method': 'cash', 'amount': 25, 'confirmed': true},
      ]);
      db.result.completeError(
        const PostgrestException(message: 'Insufficient stock', code: 'P0001'),
      );
      await tester.pumpAndSettle();
      db.updates.add([
        Product(id: 'p', name: 'Rice', unit: 'kg', price: 30, stock: 0),
      ]);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      db.result = Completer<String>();
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(db.keys[1], db.keys[0]);
      expect(db.submitted!.quantity, 2.5);
      expect(db.submitted!.unitPrice, 10);
      expect(db.submitted!.totalPrice, 25);
      expect(db.confirmedPayments[1], db.confirmedPayments[0]);
      expect(find.byType(AlertDialog), findsNothing);
      db.result.completeError(
        const PostgrestException(message: 'Insufficient stock', code: 'P0001'),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await db.updates.close();
    },
  );
}
