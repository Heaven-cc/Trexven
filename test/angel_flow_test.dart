import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:odt/services/database_service.dart';
import 'package:odt/screens/dashboard/angel_screen.dart';
import 'integration_test_support.dart';

class ChatDatabase extends DatabaseService {
  ChatDatabase(SupabaseClient client) : super(client: client);
  @override
  Future<String> requireBusinessId() async => 'business';
}

void main() {
  for (final signOutWhileCreating in [false, true]) {
    testWidgets(
      signOutWhileCreating
          ? 'Late conversation creation after sign-out never restores a draft or sends'
          : 'New chat stays open, supplies an explicit conversation, and uncertain send only refreshes history',
      (tester) async {
        var sends = 0;
        String? created;
        final creationRelease = Completer<void>();
        final requests = <http.Request>[];
        final client = (await tester.runAsync(
          () async => SupabaseClient(
            'https://example.invalid',
            'synthetic',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
              requests.add(request);
              dynamic data;
              var status = 200;
              if (request.url.path.endsWith('/angel_conversations')) {
                if (request.method == 'POST') {
                  final body = jsonDecode(request.body) as Map;
                  created = body['id'] as String;
                  expect(body['business_id'], 'business');
                  expect(body['user_id'], 'synthetic-owner');
                } else if (request.url.queryParameters.containsKey('id')) {
                  if (signOutWhileCreating &&
                      created != null &&
                      request.url.queryParameters['id'] == 'eq.$created') {
                    await creationRelease.future;
                  }
                  data = {
                    'id': request.url.queryParameters['id']!.substring(3),
                  };
                } else {
                  data = [
                    {
                      'id': 'old-chat',
                      'title': 'Old chat',
                      'updated_at': '2026-10-13T01:00:00Z',
                    },
                  ];
                }
              } else if (request.url.path.endsWith('/angel_messages')) {
                final isNew =
                    request.url.queryParameters['conversation_id'] ==
                    'eq.$created';
                data = [
                  if (isNew && sends > 0)
                    {
                      'id': 'assistant',
                      'role': 'assistant',
                      'content': 'Saved synthetic answer',
                      'created_at': '2026-10-13T03:00:00Z',
                    },
                  {
                    'id': 'user',
                    'role': 'user',
                    'content': isNew ? 'Question' : 'Old question',
                    'created_at': '2026-10-13T02:00:00Z',
                  },
                ];
              } else if (request.url.path.endsWith('/angel')) {
                final body = jsonDecode(request.body) as Map;
                expect(body['conversation_id'], created);
                expect(created, isNotNull);
                sends++;
                status = 503;
                data = {'success': false, 'error': 'Synthetic lost response'};
              } else if (request.url.path.endsWith('/auth/v1/logout')) {
                data = {};
              } else {
                throw StateError(
                  'Unexpected synthetic request ${request.url.path}',
                );
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
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AngelScreen(
                        client: client,
                        database: ChatDatabase(client),
                      ),
                    ),
                  ),
                  child: const Text('Open Angel'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open Angel'));
        await tester.pumpAndSettle();
        expect(find.text('Old question'), findsOneWidget);
        await tester.tap(find.byTooltip('New chat'));
        await tester.pumpAndSettle();
        expect(find.byType(AngelScreen), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Question');
        // FunctionsClient decodes in a real isolate; do not advance the fake clock
        // through its request deadline while that isolate is being scheduled.
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('Send message'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        if (signOutWhileCreating) {
          expect(created, isNotNull);
          await tester.runAsync(() async {
            await client.auth.signOut(scope: SignOutScope.local);
            creationRelease.complete();
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await tester.pumpAndSettle();
          expect(sends, 0);
          expect(find.text('Question'), findsNothing);
          expect(find.text('Old question'), findsNothing);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(client.dispose);
          return;
        }
        await tester.pumpAndSettle();
        expect(sends, 1);
        expect(
          find.text('Refresh history · send outcome unknown'),
          findsOneWidget,
        );
        expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
        await tester.tap(find.text('Refresh history · send outcome unknown'));
        await tester.pumpAndSettle();
        expect(sends, 1);
        expect(find.text('Question'), findsOneWidget);
        expect(find.textContaining('Saved synthetic answer'), findsWidgets);
        expect(tester.widget<TextField>(find.byType(TextField)).enabled, true);
        final providerRequests = requests
            .where((r) => r.url.path.endsWith('/angel'))
            .toList();
        expect(providerRequests.length, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(client.dispose);
      },
    );
  }
}
