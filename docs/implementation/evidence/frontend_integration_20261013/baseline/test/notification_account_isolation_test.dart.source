import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/trexven_operations.dart';

void main() {
  for (final delayed in [false, true]) {
    testWidgets(
      'account change hides ${delayed ? 'in-flight' : 'cached'} notifications',
      (tester) async {
        final response = Completer<void>();
        final client = (await tester.runAsync(
          () async => SupabaseClient(
            'https://example.invalid',
            'synthetic-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
              if (request.url.path.endsWith('/get_trexven_notifications')) {
                if (delayed) await response.future;
                return http.Response(
                  jsonEncode([
                    {
                      'alert_key': 'synthetic-alert',
                      'title': 'Private original alert',
                      'message': 'Original account only',
                      'route': 'inventory',
                      'reference_id': null,
                      'read_at': null,
                    },
                  ]),
                  200,
                  request: request,
                  headers: {'content-type': 'application/json'},
                );
              }
              return http.Response(
                '{}',
                200,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ))!;
        final token = base64Url
            .encode(
              utf8.encode(
                jsonEncode({'sub': 'original-user', 'exp': 4102444800}),
              ),
            )
            .replaceAll('=', '');
        await tester.runAsync(
          () => client.auth.setInitialSession(
            jsonEncode({
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$token.synthetic',
              'refresh_token': 'synthetic-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'original-user',
                'aud': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: NotificationCenterScreen(
              api: OperationsClient(client, 'synthetic-business'),
              open: (_, _, _) =>
                  fail('An old notification must not navigate after sign-out.'),
            ),
          ),
        );
        await tester.pump();
        if (!delayed) {
          await tester.pumpAndSettle();
          expect(find.text('Private original alert'), findsOneWidget);
        }
        await tester.runAsync(
          () => client.auth.signOut(scope: SignOutScope.local),
        );
        if (delayed) response.complete();
        await tester.pumpAndSettle();
        expect(find.text('Private original alert'), findsNothing);
        expect(find.textContaining('original account'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(client.dispose);
      },
    );
  }
}
