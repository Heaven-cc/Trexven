import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';

import 'integration_test_support.dart';

void main() {
  testWidgets(
    'Opening an unread notification acknowledges it and displays its read state',
    (tester) async {
      final marks = <Map>[];
      var opens = 0;
      final client = SupabaseClient(
        'https://example.invalid',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          Object? response;
          if (request.url.path.endsWith('/get_trexven_notifications')) {
            response = [
              {
                'alert_key': 'staff:synthetic',
                'title': 'Employee access changed',
                'message': 'Legacy generic text',
                'route': 'employees',
                'reference_id': null,
                'read_at': null,
                'occurred_at': '2026-10-29T12:00:00Z',
                'employee_name': 'Sample employee',
                'actor_name': 'Business owner',
                'action': 'employee_permission_changed',
                'details': {'permission': 'manage_inventory', 'granted': true},
              },
            ];
          } else if (request.url.path.endsWith(
            '/mark_trexven_notification_read',
          )) {
            marks.add(jsonDecode(request.body) as Map);
          }
          return http.Response(
            jsonEncode(response),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await tester.runAsync(() => signInSynthetic(client));
      await tester.pumpWidget(
        MaterialApp(
          theme: TrexvenTheme.lightTheme,
          home: NotificationCenterScreen(
            api: OperationsClient(client, 'business'),
            open: (_, route, _) {
              expect(route, 'employees');
              opens++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Sample employee'), findsOneWidget);
      expect(find.textContaining('Legacy generic text'), findsNothing);
      expect(find.byIcon(Icons.mark_email_unread_outlined), findsOneWidget);
      expect(find.textContaining('Oct'), findsOneWidget);
      await tester.tap(find.text('Employee access changed'));
      await tester.pumpAndSettle();
      expect(marks.single['p_read'], true);
      expect(opens, 1);
      expect(find.byIcon(Icons.drafts_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mark_email_unread_outlined), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(client.dispose);
    },
  );
}
