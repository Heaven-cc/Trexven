import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'integration_test_support.dart';

void main() {
  testWidgets(
    'Camera count reviews multiple lines and recovers the exact original batch',
    (tester) async {
      final attempts = <Map<String, dynamic>>[];
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://example.invalid',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            final path = request.url.path;
            dynamic data = [];
            var status = 200;
            if (path.endsWith('/products')) {
              data = [
                {
                  'id': 'a',
                  'name': 'Rice',
                  'barcode': 'A',
                  'quantity': 20,
                  'selling_price': 100,
                  'unit': 'kg',
                },
                {
                  'id': 'b',
                  'name': 'Beans',
                  'barcode': 'B',
                  'quantity': 20,
                  'selling_price': 100,
                  'unit': 'kg',
                },
              ];
            } else if (path.endsWith('/stocktake_sessions')) {
              data = [
                {'id': 'session', 'name': 'Morning count', 'status': 'open'},
              ];
            } else if (path.endsWith('/stocktake_counts')) {
              expect(request.url.queryParameters['session_id'], 'eq.session');
              data = [
                {'product_id': 'a', 'version': 3},
                {'product_id': 'b', 'version': 7},
              ];
            } else if (path.endsWith('/count_trexven_stock')) {
              attempts.add(
                Map<String, dynamic>.from(jsonDecode(request.body) as Map),
              );
              status = attempts.length == 1 ? 503 : 200;
              data = attempts.length == 1
                  ? {'message': 'Synthetic uncertain response'}
                  : {'status': 'confirmed'};
            } else if (path.endsWith('/get_trexven_operation_receipt') ||
                path.endsWith('/record_trexven_application_error')) {
              data = null;
            }
            return http.Response(
              jsonEncode(data),
              status,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      ))!;
      await tester.runAsync(() => signInSynthetic(client));
      final scans = ['A', 'B', 'A'].iterator;
      final state = MemoryOperationState();
      final api = OperationsClient(
        client,
        'business',
        journal: OperationJournal(stateFactory: () async => state),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryOperationsScreen(
            api: api,
            scanBarcode: (_) async {
              expect(scans.moveNext(), true);
              return scans.current;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Morning count'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Morning count'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan a product to count'));
      await tester.pumpAndSettle();
      for (final quantity in ['1', '2', '0.5']) {
        await tester.enterText(find.byType(TextField), quantity);
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
        expect(attempts, isEmpty);
        if (quantity != '0.5') {
          await tester.tap(find.text('Scan another product'));
          await tester.pumpAndSettle();
        }
      }
      expect(find.text('Qty 1.5 · version 3'), findsOneWidget);
      expect(find.text('Qty 2 · version 7'), findsOneWidget);
      await tester.tap(find.text('Beans'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2.25');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit reviewed batch'));
      await tester.pumpAndSettle();
      expect(attempts, hasLength(1));
      expect(attempts.single['p_session_id'], 'session');
      expect(attempts.single['p_counts'], [
        {'product_id': 'a', 'version': 3, 'quantity': 1.5},
        {'product_id': 'b', 'version': 7, 'quantity': 2.25},
      ]);
      expect(await api.journal.pending(), isNotNull);
      await tester.ensureVisible(find.text('Recover original count batch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recover original count batch'));
      await tester.pumpAndSettle();
      expect(attempts, hasLength(2));
      expect(attempts.last, attempts.first);
      expect(await api.journal.pending(), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(client.dispose);
    },
  );
}
