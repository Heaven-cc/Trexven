import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:odt/services/database_service.dart';
import 'package:odt/services/auth_service.dart';
import 'package:odt/models/sale.dart';

void main() {
  late SupabaseClient client;
  late DatabaseService db;
  late List<http.Request> requests;
  String? owner;
  bool multipleOwners = false;
  Map<String, dynamic>? member;
  bool failSale = false;
  setUp(() async {
    requests = [];
    owner = 'business-a';
    member = null;
    failSale = false;
    multipleOwners = false;
    client = SupabaseClient(
      'https://example.invalid',
      'test-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        Object? data;
        if (path.endsWith('/businesses')) {
          data =
              owner == null ||
                  (request.url.queryParameters['id'] != null &&
                      request.url.queryParameters['id'] != 'eq.$owner')
              ? []
              : [
                  {'id': owner},
                  if (multipleOwners &&
                      request.url.queryParameters['id'] == null)
                    {'id': 'business-b'},
                ];
        } else if (path.endsWith('/business_members')) {
          data = member == null ? [] : [member];
        } else if (path.endsWith('/submit_trexven_sale')) {
          if (failSale)
            return http.Response(
              jsonEncode({
                'code': 'P0001',
                'message': 'Insufficient stock',
                'details': null,
                'hint': null,
              }),
              400,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          data = {'id': 'sale-a', 'sale_number': 'TRX-sale-a'};
        } else if (path.endsWith('/recover')) {
          data = {};
        } else {
          data = [];
        }
        return http.Response(
          jsonEncode(data),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': 'user-a',
              'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            }),
          ),
        )
        .replaceAll('=', '');
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': 'user-a',
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
    db = DatabaseService(client: client);
  });
  tearDown(() async {
    db.clearBusinessSelection();
    await client.dispose();
  });
  test('Multiple owned businesses require explicit selection', () async {
    multipleOwners = true;
    await expectLater(
      db.getCurrentBusinessId(),
      throwsA(isA<OwnerBusinessSelectionRequired>()),
    );
    await db.selectOwnedBusiness('business-a');
    expect(
      await DatabaseService(client: client).getCurrentBusinessId(),
      'business-a',
    );
    expect(requests.last.url.queryParameters['owner_id'], 'eq.user-a');
    expect(requests.last.url.queryParameters['id'], 'eq.business-a');
  });
  test('Forged owner selection is rejected without writes', () async {
    await expectLater(
      db.selectOwnedBusiness('other-business'),
      throwsA(isA<OwnerAppAccessDenied>()),
    );
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });
  test('Selected business ownership is rechecked on every lookup', () async {
    await db.selectOwnedBusiness('business-a');
    owner = null;
    await expectLater(
      db.getCurrentBusinessId(),
      throwsA(isA<OwnerAppAccessDenied>()),
    );
  });
  test('Owner business resolves without creating records', () async {
    expect(await db.getCurrentBusinessId(), 'business-a');
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });
  test('Employee membership cannot enter the Owner app', () async {
    owner = null;
    member = {'business_id': 'business-b', 'status': 'active'};
    await expectLater(db.getCurrentBusinessId(), throwsStateError);
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });
  test('Suspended membership cannot enter onboarding as a new owner', () async {
    owner = null;
    member = {'business_id': 'business-b', 'status': 'suspended'};
    await expectLater(db.getCurrentBusinessId(), throwsStateError);
  });
  test(
    'New account returns no business without inserting duplicates',
    () async {
      owner = null;
      expect(await db.getCurrentBusinessId(), isNull);
      expect(requests.every((r) => r.method == 'GET'), isTrue);
    },
  );
  test(
    'Product reads are explicitly scoped to the resolved business',
    () async {
      await db.getProducts();
      expect(requests.last.url.queryParameters['business_id'], 'eq.business-a');
    },
  );
  test(
    'Sale uses one atomic RPC and never directly writes product stock',
    () async {
      await db.recordSale(
        Sale(
          productId: 'product-a',
          productName: 'A',
          quantity: 2,
          unitPrice: 10,
          totalPrice: 20,
        ),
        requestId: 'request-a',
      );
      final writes = requests.where((r) => r.method != 'GET').toList();
      expect(writes, hasLength(1));
      expect(writes.single.url.path, endsWith('/rpc/submit_trexven_sale'));
      expect(jsonDecode(writes.single.body), {
        'p_business_id': 'business-a',
        'p_request_id': 'request-a',
        'p_employee_id': null,
        'p_total': 20,
        'p_payment_method': 'cash',
        'p_quick': true,
        'p_items': [
          {
            'product_id': 'product-a',
            'quantity': 2,
            'unit_price': 10,
            'discount': 0,
          },
        ],
      });
    },
  );
  test('Rejected sale propagates to the UI without a fallback write', () async {
    failSale = true;
    await expectLater(
      db.recordSale(
        Sale(
          productId: 'a',
          productName: 'A',
          quantity: 2,
          unitPrice: 10,
          totalPrice: 20,
        ),
        requestId: 'request-a',
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests.where((r) => r.method != 'GET').length, 1);
  });
  test('Invalid quantities fail before sending a request', () async {
    await expectLater(
      db.recordSale(
        Sale(
          productId: 'a',
          productName: 'A',
          quantity: 0,
          unitPrice: 10,
          totalPrice: 0,
        ),
        requestId: 'request-a',
      ),
      throwsArgumentError,
    );
    expect(requests, isEmpty);
  });
  test(
    'Password reset calls Supabase with the registered mobile callback',
    () async {
      await AuthService(
        client: client,
      ).resetPassword(' person@example.invalid ');
      final request = requests.single;
      expect(request.url.path, endsWith('/recover'));
      expect(jsonDecode(request.body)['email'], 'person@example.invalid');
      expect(
        request.url.queryParameters['redirect_to'],
        AuthService.callbackUrl,
      );
    },
  );
  test(
    'Google OAuth URL requests Google and the callback without embedded secrets',
    () async {
      final result = await client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: AuthService.callbackUrl,
      );
      final uri = Uri.parse(result.url);
      expect(uri.queryParameters['provider'], 'google');
      expect(uri.queryParameters['redirect_to'], AuthService.callbackUrl);
      expect(uri.queryParameters.containsKey('client_secret'), isFalse);
    },
  );
}
