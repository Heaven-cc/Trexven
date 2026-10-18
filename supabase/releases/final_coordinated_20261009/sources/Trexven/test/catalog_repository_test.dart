import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:odt/services/database_service.dart';

class CatalogDatabase extends DatabaseService {
  CatalogDatabase(SupabaseClient client) : super(client: client);
  @override
  Future<String?> getCurrentBusinessId() async => 'business';
}

void main() {
  test(
    'Owner reads pre-Batch-3 product schema without SELECT star or cost',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: MockClient((r) async {
          requests.add(r);
          return requests.length == 1
              ? http.Response(
                  jsonEncode({
                    'code': '42703',
                    'message': 'column variant_attributes does not exist',
                  }),
                  400,
                  request: r,
                  headers: {'content-type': 'application/json'},
                )
              : http.Response(
                  jsonEncode([
                    {
                      'id': 'p',
                      'name': 'Legacy',
                      'selling_price': 0,
                      'quantity': 0.125,
                      'unit': 'litre',
                    },
                  ]),
                  200,
                  request: r,
                  headers: {'content-type': 'application/json'},
                );
        }),
      );
      final products = await CatalogDatabase(client).getProducts();
      expect(products.single.stock, 0.125);
      expect(products.single.price, 0);
      expect(products.single.isPricePending, false);
      expect(requests.length, 2);
      for (final r in requests) {
        expect(r.url.queryParameters['business_id'], 'eq.business');
        expect(r.url.queryParameters['select'], isNot(contains('cost_price')));
        expect(r.url.queryParameters['select'], isNot('*'));
      }
      await client.dispose();
    },
  );
  test(
    'stock intent sends an authorized delta and stable request, not an absolute overwrite',
    () async {
      late Map<String, dynamic> payload;
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: MockClient((r) async {
          payload = jsonDecode(r.body);
          expect(r.url.path, endsWith('/rpc/adjust_trexven_catalog_stock'));
          return http.Response(
            '2.125',
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await CatalogDatabase(
        client,
      ).adjustProductStock('p', 0.125, 'Received stock', 'stable');
      expect(payload['p_delta'], '0.125');
      expect(payload['p_request_id'], 'stable');
      expect(payload.containsKey('new_quantity'), false);
      await client.dispose();
    },
  );
}
