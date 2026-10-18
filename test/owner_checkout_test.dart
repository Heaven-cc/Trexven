import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:odt/services/database_service.dart';
import 'integration_test_support.dart';

void main() {
  for (final method in ['cash', 'card', 'bank_transfer', 'credit', 'partial']) {
    test(
      'Owner $method cart uses one exact approved atomic transaction',
      () async {
        final requests = <http.Request>[];
        final state = MemoryOperationState();
        var approvalStatus = 'pending';
        Map<String, dynamic>? saved;
        final client = SupabaseClient(
          'https://example.invalid',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            requests.add(request);
            final path = request.url.path;
            dynamic result;
            if (path.endsWith('/businesses')) {
              expect(
                request.url.queryParameters['owner_id'],
                'eq.synthetic-owner',
              );
              result = request.url.queryParameters.containsKey('id')
                  ? {'id': 'business'}
                  : [
                      {'id': 'business'},
                    ];
            } else if (path.endsWith('/business_members')) {
              expect(
                request.url.queryParameters['user_id'],
                'eq.synthetic-owner',
              );
              expect(request.url.queryParameters['status'], 'eq.active');
              result = {'id': 'owner-member'};
            } else if (path.endsWith('/get_trexven_cash_context')) {
              result = {
                'configured': true,
                'shifts': [
                  {
                    'id': 'shift',
                    'joined': true,
                    'status': 'open',
                    'register_active': true,
                  },
                ],
              };
            } else if (path.endsWith('/get_trexven_business_day')) {
              result = {'local_date': '2026-10-13'};
            } else if (path.endsWith('/get_trexven_operation_receipt')) {
              result = saved;
            } else if (path.endsWith('/request_trexven_credit_approval')) {
              result = 'approval';
            } else if (path.endsWith('/credit_approvals')) {
              result = request.url.queryParameters['select'] == 'id'
                  ? {'id': 'approval'}
                  : {'status': approvalStatus};
            } else if (path.endsWith('/decide_trexven_credit_approval')) {
              approvalStatus = 'approved';
              result = null;
            } else if (path.endsWith('/complete_trexven_transaction')) {
              expect(
                (await OperationJournal(
                  stateFactory: () async => state,
                ).pending())!['args']['p_request_id'],
                'original',
              );
              saved = {'id': 'one-sale', 'sale_number': 'TRX-one-receipt'};
              result = saved;
            } else if (path.endsWith('/record_trexven_application_error')) {
              result = null;
            } else {
              throw StateError('Unexpected request: $path');
            }
            return http.Response(
              jsonEncode(result),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        await signInSynthetic(client);
        final journal = OperationJournal(stateFactory: () async => state);
        final database = DatabaseService(
          client: client,
          operationJournal: journal,
        );
        await database.saleCashContext();
        final items = <Map<String, dynamic>>[
          {
            'product_id': 'rice',
            'quantity': 2.5,
            'unit_price': 10.0,
            'discount': 0,
          },
          {
            'product_id': 'milk',
            'quantity': 2,
            'unit_price': 5.0,
            'discount': 0,
          },
        ];
        final payments = <Map<String, dynamic>>[
          if (method != 'credit')
            {
              'method': method == 'partial' ? 'cash' : method,
              'amount': method == 'partial' ? 10.0 : 35.0,
              'confirmed': true,
              if (['card', 'bank_transfer'].contains(method))
                'evidence': 'synthetic-reference',
            },
        ];
        final credit = ['credit', 'partial'].contains(method)
            ? {
                'debtor_name': 'Customer',
                'contact': 'synthetic-contact',
                'due_date': '2026-12-31',
              }
            : null;
        Future<String> send() => database.recordCartSale(
          requestId: 'original',
          items: items,
          payments: payments,
          total: 35,
          credit: credit,
          shiftId: 'shift',
        );
        if (credit != null) {
          await expectLater(send(), throwsA(isA<CreditApprovalRequired>()));
          expect(
            requests.where(
              (r) => r.url.path.endsWith('/complete_trexven_transaction'),
            ),
            isEmpty,
          );
          final pending = await journal.pending();
          expect(pending!['args']['p_credit'], credit);
          final approval =
              jsonDecode(
                    requests
                        .firstWhere(
                          (r) => r.url.path.endsWith(
                            '/request_trexven_credit_approval',
                          ),
                        )
                        .body,
                  )
                  as Map;
          expect(approval['p_payload'], {
            'member': 'owner-member',
            'total': 35,
            'items': items,
            'payments': payments,
            'credit': credit,
            'branch': null,
            'shift': 'shift',
          });
          await database.approveCartCredit('approval');
        }
        expect(await send(), 'TRX-one-receipt');
        final writes = requests
            .where((r) => r.url.path.endsWith('/complete_trexven_transaction'))
            .toList();
        expect(writes.length, 1);
        final args = jsonDecode(writes.single.body) as Map;
        expect(args['p_items'], items);
        expect(args['p_payments'], payments);
        expect(args['p_employee_id'], 'owner-member');
        expect(args['p_request_id'], 'original');
        if (credit != null)
          expect(args['p_credit'], {...credit, 'approval_id': 'approval'});
        expect(await journal.pending(), isNull);
        // Simulate a lost success response by restoring the exact original intent.
        final original = Map<String, dynamic>.from(args)..['p_credit'] = credit;
        await journal.reserve(
          'synthetic-owner',
          'business',
          'complete_trexven_transaction',
          original,
        );
        final restarted = DatabaseService(
          client: client,
          operationJournal: OperationJournal(stateFactory: () async => state),
        );
        expect(
          (await restarted.recoverPendingOperation())['sale_number'],
          'TRX-one-receipt',
        );
        expect(
          requests
              .where(
                (r) => r.url.path.endsWith('/complete_trexven_transaction'),
              )
              .length,
          1,
        );
        expect(await journal.pending(), isNull);
        await client.dispose();
      },
    );
  }
}
