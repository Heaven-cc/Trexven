import 'package:trexven_design_system/trexven_design_system.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odt/models/product.dart';
import 'package:odt/models/sale.dart';
import 'package:odt/services/database_service.dart';
import 'package:odt/screens/finance/record_sale_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';

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
  List<Map<String, dynamic>>? submittedItems;
  Map<String, dynamic>? submittedCredit;
  bool requiresApproval = false, approved = false;
  int approvalCalls = 0;
  bool pendingRecovery = false;
  int recoveries = 0;
  @override
  Stream<List<Product>> getProductsStream() {
    subscriptions++;
    return updates.stream;
  }

  @override
  Future<String> recordCartSale({
    required String requestId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    required double total,
    Map<String, dynamic>? credit,
    String? shiftId,
  }) {
    submissions++;
    submittedItems = items;
    submittedCredit = credit;
    keys.add(requestId);
    confirmedPayments.add(payments);
    submitted = Sale(
      productId: items.first['product_id'],
      productName: '',
      quantity: items.first['quantity'],
      unitPrice: items.first['unit_price'],
      totalPrice: total,
    );
    if (requiresApproval && !approved)
      return Future.error(CreditApprovalRequired('approval'));
    return result.future;
  }

  @override
  Future<void> approveCartCredit(
    String approvalId, {
    String? overLimitReason,
  }) async {
    expect(approvalId, 'approval');
    approved = true;
    approvalCalls++;
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final checkbox = find.byType(Checkbox).last;
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm Payment'));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'Unconfirmed quick sale retries the same request and returns the receipt',
    (tester) async {
      final db = FakeDatabase();
      await tester.pumpWidget(
        MaterialApp(
          theme: TrexvenTheme.lightTheme,
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
      await tester.tap(find.text('Search or select products'));
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
          theme: TrexvenTheme.lightTheme,
          home: RecordSaleScreen(database: db),
        ),
      );
      Product product(int stock) =>
          Product(id: 'p', name: 'Widget', price: 10, stock: stock);
      db.updates.add([product(5)]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search or select products'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Widget').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsWidgets);
      expect(db.subscriptions, 1);
      db.updates.add([product(4)]);
      await tester.pumpAndSettle();
      expect(find.text('Widget'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(tester.takeException(), isNull);
      final submit = find.byType(FilledButton);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
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
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
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
        theme: TrexvenTheme.lightTheme,
        home: RecordSaleScreen(database: db),
      ),
    );
    db.updates.add([Product(id: 'p', name: 'Widget', price: 10, stock: 5)]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Search or select products'));
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
          theme: TrexvenTheme.lightTheme,
          home: RecordSaleScreen(database: db),
        ),
      );
      db.updates.add([
        Product(id: 'p', name: 'Rice', unit: 'kg', price: 10, stock: 3),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Search or select products'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rice').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quantity-p')));
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
