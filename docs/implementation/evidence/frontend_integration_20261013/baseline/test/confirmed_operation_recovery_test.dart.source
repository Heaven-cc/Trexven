import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/src/encrypted_state_native.dart';
import 'package:trexven_operations/trexven_operations.dart';

void main() {
  for (final errorCode in ['P0001', '42501', '23514']) {
    test(
      'confirmed payment survives $errorCode and restart recovery',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'trexven_recovery_',
        );
        final requests = <Map<String, dynamic>>[];
        var rejected = true;
        final client = SupabaseClient(
          'https://example.invalid',
          'synthetic-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            Object? response;
            var status = 200;
            if (request.url.path.endsWith(
              '/record_confirmed_trexven_owner_sale',
            )) {
              requests.add(jsonDecode(request.body) as Map<String, dynamic>);
              if (rejected) {
                response = {
                  'code': errorCode,
                  'message': 'Synthetic rejection',
                };
                status = 400;
              } else {
                response = {'id': 'sale-a', 'sale_number': 'TRX-sale-a'};
              }
            } else if (request.url.path.endsWith(
              '/record_trexven_application_error',
            )) {
              response = {};
            } else if (!request.url.path.endsWith(
              '/get_trexven_operation_receipt',
            )) {
              throw StateError('Unexpected test request ${request.url.path}');
            }
            return http.Response(
              jsonEncode(response),
              status,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        try {
          final token = base64Url
              .encode(
                utf8.encode(
                  jsonEncode({
                    'sub': 'synthetic-owner',
                    'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
                  }),
                ),
              )
              .replaceAll('=', '');
          await client.auth.setInitialSession(
            jsonEncode({
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$token.test',
              'refresh_token': 'synthetic-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'synthetic-owner',
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
          );
          final file = File('${directory.path}/confirmed.enc');
          final key = SecretKey(List<int>.filled(32, 7));
          OperationJournal journal() => OperationJournal(
            stateFactory: () async => EncryptedStateFile(
              file,
              () async => key,
              aad: 'SYNTHETIC_RECOVERY_TEST',
            ),
          );
          final original = {
            'p_request_id': 'original-request',
            'p_business_id': 'synthetic-business',
            'p_product_id': 'product-a',
            'p_units': 2,
            'p_unit_price': 10,
            'p_payments': [
              {
                'method': 'bank_transfer',
                'amount': 20,
                'confirmed': true,
                'evidence': 'synthetic-reference',
              },
            ],
            'p_shift_id': null,
          };
          final first = OperationsClient(
            client,
            'synthetic-business',
            journal: journal(),
          );
          await expectLater(
            first.call('record_confirmed_trexven_owner_sale', original),
            throwsA(
              isA<PostgrestException>().having(
                (e) => e.code,
                'code',
                errorCode,
              ),
            ),
          );
          final recoveredJournal = journal();
          expect((await recoveredJournal.pending())!['args'], original);
          expect(
            await file.readAsString(),
            isNot(contains('synthetic-reference')),
          );
          rejected = false;
          final restarted = OperationsClient(
            client,
            'synthetic-business',
            journal: recoveredJournal,
          );
          final receipt = await restarted.recoverPending();
          expect(receipt['sale_number'], 'TRX-sale-a');
          expect(requests, [original, original]);
          expect(await recoveredJournal.pending(), isNull);
        } finally {
          await client.dispose();
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
