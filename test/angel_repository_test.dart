import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:odt/services/angel_repository.dart';
import 'integration_test_support.dart';

void main() {
  test(
    'New chat has an explicit stable identity; message history uses an authorized cursor',
    () async {
      final requests = <http.Request>[];
      final conversations = <String>{};
      final client = SupabaseClient(
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
              expect(body['user_id'], 'synthetic-owner');
              if (!conversations.add(body['id'] as String)) {
                status = 409;
                data = {'code': '23505', 'message': 'Synthetic duplicate'};
              }
            } else {
              expect(
                request.url.queryParameters['user_id'],
                'eq.synthetic-owner',
              );
              expect(request.url.queryParameters['business_id'], 'eq.business');
              data = {'id': request.url.queryParameters['id']!.substring(3)};
            }
          } else if (request.url.path.endsWith('/angel_messages')) {
            expect(request.method, 'GET');
            data = [
              {
                'id': 'message',
                'role': 'assistant',
                'content': 'Synthetic reply',
                'created_at': '2026-10-12T00:00:00Z',
              },
            ];
          } else {
            throw StateError('No provider calls are allowed in this test.');
          }
          return http.Response(
            jsonEncode(data),
            status,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await signInSynthetic(client);
      final repository = AngelRepository(client);
      expect(
        await repository.create('business', 'new-chat', 'First question'),
        'new-chat',
      );
      expect(
        await repository.create('business', 'new-chat', 'First question'),
        'new-chat',
      );
      expect(
        await repository.create('business', 'second-chat', 'Next question'),
        'second-chat',
      );
      expect(conversations.length, 2);
      final page = await repository.history('business', 'new-chat');
      await repository.history('business', 'new-chat', before: page.last);
      final query = requests.last.url.queryParameters;
      expect(query['or'], contains('created_at.lt.2026-10-12T00:00:00Z'));
      expect(query['or'], contains('id.lt.message'));
      expect(query['order'], 'created_at.desc.nullslast,id.desc.nullslast');
      expect(query['limit'], '100');
      expect(
        requests.where((r) => r.url.path.contains('/functions/')),
        isEmpty,
      );
      await client.dispose();
    },
  );
}
