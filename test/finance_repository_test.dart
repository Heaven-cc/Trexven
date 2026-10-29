import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:odt/services/database_service.dart';

class ReportingDatabase extends DatabaseService {
  ReportingDatabase(SupabaseClient client) : super(client: client);
  @override
  Future<String?> getCurrentBusinessId() async => 'business';
}

void main() {
  SupabaseClient failingClient(
    String failingPath, {
    bool malformedDay = false,
  }) => SupabaseClient(
    'https://example.invalid',
    'synthetic',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith(failingPath)) {
        return http.Response(
          jsonEncode({'code': 'P0001', 'message': 'Reporting unavailable'}),
          400,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }
      final data = path.endsWith('/get_trexven_business_day')
          ? {
              'local_date': '2026-10-15',
              if (!malformedDay) 'timezone': 'Africa/Lagos',
            }
          : path.endsWith('/businesses')
          ? {'currency': 'NGN'}
          : path.endsWith('/get_trexven_financial_summary')
          ? {'gross_sales': '10', 'net_collected': '10'}
          : [];
      return http.Response(
        jsonEncode(data),
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  test('Calendar failure preserves the backend error instead of a timezone-less fallback', () async {
    final client = failingClient('/get_trexven_business_day');
    await expectLater(
      ReportingDatabase(client).getFinanceReport('today'),
      throwsA(isA<PostgrestException>()),
    );
    await client.dispose();
  });
  test(
    'Malformed calendar is rejected before querying financial totals',
    () async {
      final client = failingClient('/unused', malformedDay: true);
      await expectLater(
        ReportingDatabase(client).getFinanceReport('today'),
        throwsStateError,
      );
      await client.dispose();
    },
  );
  for (final path in [
    '/get_trexven_financial_summary',
    '/sales',
    '/expenses',
  ]) {
    test(
      'Failed $path rejects the report instead of showing zero totals',
      () async {
        final client = failingClient(path);
        await expectLater(
          ReportingDatabase(client).getFinanceReport('today'),
          throwsA(isA<PostgrestException>()),
        );
        await client.dispose();
      },
    );
  }
  for (final path in ['/sales', '/products']) {
    test('Dashboard $path failure rejects the whole snapshot', () async {
      final client = failingClient(path);
      await expectLater(
        ReportingDatabase(client).getDetailedDashboardStats(),
        throwsA(isA<PostgrestException>()),
      );
      await client.dispose();
    });
  }
  test('Finance summary uses authoritative interval and pages all sales/items and expenses', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.invalid',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        dynamic data;
        if (path.endsWith('/get_trexven_business_day')) {
          data = {'timezone': 'Asia/Kolkata', 'local_date': '2026-10-13'};
        } else if (path.endsWith('/businesses')) {
          data = {'currency': 'GHS'};
        } else if (path.endsWith('/get_trexven_financial_summary')) {
          final args = jsonDecode(request.body) as Map;
          expect(args['p_start'], '2026-10-11T18:30:00.000Z');
          expect(args['p_end'], '2026-10-12T18:30:00.000Z');
          data = {
            'gross_sales': '2002.00',
            'net_collected': '1900.00',
            'refunds': '102.00',
          };
        } else {
          expect(request.url.queryParameters['business_id'], 'eq.business');
          final offset = int.parse(
            request.url.queryParameters['offset'] ?? '0',
          );
          final expenses = path.endsWith('/expenses');
          final count = ((expenses ? 501 : 1001) - offset).clamp(0, 500);
          if (!expenses) {
            expect(
              request.url.queryParameters['select'],
              contains('sale_items('),
            );
            expect(
              request.url.queryParameters['select'],
              isNot(contains('cost')),
            );
            expect(
              request.url.queryParameters['or'],
              contains('sold_at.is.null'),
            );
          }
          data = List.generate(
            count,
            (i) => expenses
                ? {
                    'id': 'e${offset + i}',
                    'amount': 1,
                    'created_at': '2026-10-12T00:00:00Z',
                  }
                : {
                    'id': 's${offset + i}',
                    'total': 2,
                    'created_at': '2026-10-12T00:00:00Z',
                    'sale_items': [
                      {'product_name': 'Rice', 'quantity': 2, 'unit_price': 1},
                    ],
                  },
          );
        }
        return http.Response(
          jsonEncode(data),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final report = await ReportingDatabase(client)
        .getFinanceReport('yesterday');
    expect(report.currency, 'GHS');
    expect(report.sales.length, 1001);
    expect(report.expenses.length, 501);
    expect(report.expenseTotal, 501);
    expect(requests.where((r) => r.url.path.endsWith('/sales')).length, 3);
    expect(requests.where((r) => r.url.path.endsWith('/expenses')).length, 2);
    final preview = await ReportingDatabase(client)
        .getFinancialSales(report.period, offset: 0);
    // The caller asks for a bounded page; the mock must honor that page limit.
    expect(requests.last.url.queryParameters['limit'], '100');
    expect(preview, isNotEmpty);
    await client.dispose();
  });
}
