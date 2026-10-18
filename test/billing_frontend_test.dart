import 'package:trexven_design_system/trexven_design_system.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:odt/screens/me/billing_screen.dart';

void main() {
  final requests = <http.Request>[];
  var configured = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.invalid',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        Object result;
        if (path.endsWith('/businesses')) {
          result = [
            {'id': 'business', 'owner_id': 'owner'},
          ];
        } else if (path.endsWith('/subscription_plans')) {
          result = [
            for (final id in ['start', 'core', 'pro'])
              {
                'id': id,
                'name': id.toUpperCase(),
                'price': null,
                'currency': null,
                'interval_months': null,
                'features': {'basic_vision': true, 'inventory': true},
              },
          ];
        } else if (path.endsWith('/rpc/get_trexven_entitlements')) {
          result = {
            'configured': configured,
            'enforced': false,
            'status': configured ? 'active' : 'unconfigured',
            if (configured) 'plan': 'core',
            'features': <String, bool>{},
          };
        } else if (path.endsWith('/billing_payments')) {
          result = <Object>[];
        } else {
          throw StateError('Unexpected billing request: $path');
        }
        return http.Response(
          jsonEncode(result),
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
              'sub': 'owner',
              'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            }),
          ),
        )
        .replaceAll('=', '');
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'eyJhbGciOiJIUzI1NiJ9.$payload.test',
        'refresh_token': 'test',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': 'owner',
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  for (final enrolled in [false, true]) {
    testWidgets(
      'Canonical billing reads actual entitlement state without charging: enrolled=$enrolled',
      (tester) async {
        configured = enrolled;
        requests.clear();
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: TrexvenTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const BillingScreen(),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Billing & Plans'), findsOneWidget);
        expect(
          find.text('Plan upgrades are not available yet.'),
          findsOneWidget,
        );
        if (enrolled) {
          expect(find.text('Current plan'), findsAtLeastNWidgets(1));
          expect(find.text('Active'), findsOneWidget);
        } else {
          expect(find.text('No active subscription'), findsOneWidget);
        }
        expect(find.textContaining('basic_vision'), findsNothing);
        expect(find.text('Pricing not configured'), findsNothing);
        expect(
          requests.where(
            (r) =>
                r.method != 'GET' &&
                !r.url.path.endsWith('/rpc/get_trexven_entitlements'),
          ),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
