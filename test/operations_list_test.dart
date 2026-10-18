import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';

void main() {
  for (final table in ['credit_accounts', 'sale_returns']) {
    test(
      '$table uses its real key and pages within the selected business',
      () async {
        final requests = <http.Request>[];
        final key = table == 'credit_accounts' ? 'sale_id' : 'id';
        final client = SupabaseClient(
          'https://example.invalid',
          'synthetic',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            requests.add(request);
            expect(request.url.queryParameters['business_id'], 'eq.business');
            expect(request.url.queryParameters['order'], startsWith('$key.'));
            final offset = int.parse(
              request.url.queryParameters['offset'] ?? '0',
            );
            final count = offset == 0 ? 200 : 1;
            return http.Response(
              jsonEncode(List.generate(count, (i) => {key: '${offset + i}'})),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final rows = await OperationsClient(client, 'business').list(table);
        expect(rows.length, 201);
        expect(requests.length, 2);
        expect(rows.last[key], '200');
        await client.dispose();
      },
    );
  }
}
