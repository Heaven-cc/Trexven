import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:odt/services/database_service.dart';

class CatalogDatabase extends DatabaseService {
  CatalogDatabase(SupabaseClient client) : super(client: client);
  @override
  Future<Map<String, dynamic>> getBusinessDay() async => {
    'timezone': 'Africa/Lagos',
    'local_date': DateTime.now().toUtc().toIso8601String().substring(0, 10),
  };
  @override
  Future<String?> getCurrentBusinessId() async => 'business';
}

void main() {
  test(
    'Dashboard aggregates all authorized pages instead of truncating KPIs',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: MockClient((request) async {
          requests.add(request);
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          final products = request.url.path.endsWith('/products');
          final yesterday = request.url.queryParameters['select'] == 'total';
          final total = products
              ? 1001
              : yesterday
              ? 0
              : 501;
          final length = (total - offset).clamp(0, 500);
          final rows = List.generate(
            length,
            (index) => products
                ? {
                    'id': 'p${offset + index}',
                    'name': 'Product',
                    'selling_price': 1,
                    'quantity': 1,
                  }
                : {
                    'id': 's${offset + index}',
                    'product_id': 'p0',
                    'quantity': 1,
                    'unit_price': 1,
                    'total': 1,
                    'created_at': DateTime.now().toUtc().toIso8601String(),
                  },
          );
          return http.Response(
            jsonEncode(rows),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final stats = await CatalogDatabase(client).getDetailedDashboardStats();
      expect(stats['inventory']['productCount'], 1001);
      expect(stats['inventory']['totalValue'], 1001);
      expect(stats['sales']['totalToday'], 501);
      expect(stats['sales']['countToday'], 501);
      expect(
        requests.where((r) => r.url.path.endsWith('/products')),
        hasLength(3),
      );
      expect(
        requests.every(
          (r) => r.url.queryParameters['business_id'] == 'eq.business',
        ),
        true,
      );
      expect(requests.where((r) => r.method != 'GET'), isEmpty);
      await client.dispose();
    },
  );
  test(
    'Dashboard uses granted catalog columns and counts empty sellable stock',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: MockClient((request) async {
          requests.add(request);
          final products = request.url.path.endsWith('/products');
          final select = request.url.queryParameters['select'] ?? '';
          if (products && (select == '*' || select.contains('cost_price'))) {
            return http.Response(
              jsonEncode({
                'code': '42501',
                'message': 'permission denied for table products',
              }),
              403,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(
              products
                  ? [
                      {
                        'id': 'empty',
                        'name': 'Empty',
                        'selling_price': 10,
                        'quantity': 0,
                        'active': true,
                        'low_stock_threshold': 5,
                      },
                      {
                        'id': 'available',
                        'name': 'Available',
                        'selling_price': 10,
                        'quantity': 3,
                        'active': true,
                        'low_stock_threshold': 5,
                      },
                      {
                        'id': 'pending',
                        'name': 'Pending price',
                        'selling_price': null,
                        'quantity': 0,
                        'active': true,
                      },
                      {
                        'id': 'inactive',
                        'name': 'Inactive',
                        'selling_price': 10,
                        'quantity': 0,
                        'active': false,
                      },
                      {
                        'id': 'free',
                        'name': 'Existing zero price',
                        'selling_price': 0,
                        'quantity': 0,
                        'active': true,
                      },
                    ]
                  : [],
            ),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final stats = await CatalogDatabase(client).getDetailedDashboardStats();
      expect(stats['inventory']['totalValue'], 30);
      expect(stats['lowStock']['totalCount'], 3);
      expect(stats['lowStock']['critical'].map((p) => p.id), ['empty', 'free']);
      expect(stats['transactions'].containsKey('failed'), false);
      expect(stats['transactions'].containsKey('pending'), false);
      expect(requests.where((r) => r.method != 'GET'), isEmpty);
      for (final request in requests) {
        expect(request.url.queryParameters['business_id'], 'eq.business');
      }
      expect(
        requests.where((r) => r.url.path.endsWith('/products')),
        hasLength(1),
      );
      await client.dispose();
    },
  );
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
