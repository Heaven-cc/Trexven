import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:odt/services/alert_service.dart';
import 'package:odt/services/vision_service.dart';
import 'integration_test_support.dart';

class InboxVision extends VisionService {
  InboxVision() : super.withAccess(accessHeaders: () async => {});
  bool read = false;
  @override
  Future<Map<String, dynamic>> getAlertInbox() async => {
    'alerts': [
      {
        'id': 1,
        'source': 'vision_local',
        'reference_id': 7,
        'is_read': read,
        'created_at': '2026-10-13T01:00:00Z',
      },
    ],
  };
  @override
  Future<void> markAlertRead(String id) async {
    read = true;
  }

  @override
  Future<void> markAllAlertsRead() async {
    read = true;
  }
}

void main() {
  test(
    'Owner inbox pages role feed, deduplicates cloud alerts and uses personal acknowledgements',
    () async {
      final calls = <http.Request>[];
      final reads = <String>{};
      Completer<void>? metadataStarted, metadataRelease;
      final client = SupabaseClient(
        'https://example.invalid',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          calls.add(request);
          dynamic data;
          if (request.url.path.endsWith('/get_trexven_notifications')) {
            final args = jsonDecode(request.body) as Map;
            expect(args['p_business_id'], 'business');
            expect(args['p_application'], 'owner');
            final offset = args['p_offset'] as int;
            data = List.generate(
              offset == 0 ? 100 : 1,
              (i) => {
                'alert_key': 'alert:${offset + i}',
                'title': 'Alert ${offset + i}',
                'message': 'Synthetic',
                'route': 'vision',
                'reference_id': 'event',
                'occurred_at': '2026-10-13T00:00:00Z',
                'read_at': reads.contains('alert:${offset + i}')
                    ? '2026-10-13T02:00:00Z'
                    : null,
              },
            );
          } else if (request.url.path.endsWith(
            '/mark_trexven_notification_read',
          )) {
            final args = jsonDecode(request.body) as Map;
            expect(args['p_application'], 'owner');
            expect(args['p_read'], true);
            reads.add(args['p_alert_key'] as String);
            data = null;
          } else if (request.url.path.endsWith('/alerts')) {
            expect(request.method, 'GET');
            if (metadataStarted != null && !metadataStarted.isCompleted) {
              metadataStarted.complete();
              await metadataRelease!.future;
            }
            data = [
              {'id': '0', 'source': 'camera_ai', 'reference_id': 'event'},
            ];
          } else {
            data = null;
          }
          return http.Response(
            jsonEncode(data),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await signInSynthetic(client);
      final vision = InboxVision();
      final service = AlertService.withClients(
        supabase: client,
        vision: vision,
        realtime: false,
        notifications: false,
      );
      await service.init('business');
      expect(service.alerts.length, 102);
      expect(service.unreadCount, 102);
      expect(service.alerts.where((a) => a['id'] == 'op:alert:0').length, 1);
      // Hold a snapshot containing an unread marker, then acknowledge while
      // it is in flight. Applying that snapshot must not undo the personal read.
      metadataStarted = Completer<void>();
      metadataRelease = Completer<void>();
      final refreshing = service.refresh();
      await metadataStarted.future;
      await service.markRead('op:alert:0');
      expect(service.unreadCount, 101);
      final counts = <int>[];
      service.addListener(() => counts.add(service.unreadCount));
      metadataRelease.complete();
      await refreshing;
      expect(service.unreadCount, 101);
      expect(counts, isNot(contains(102)));
      await service.markAllRead();
      expect(service.unreadCount, 0);
      expect(reads.length, 101);
      expect(vision.read, true);
      await client.auth.signOut(scope: SignOutScope.local);
      await Future<void>.delayed(Duration.zero);
      expect(service.alerts, isEmpty);
      expect(service.unreadCount, 0);
      expect(calls.where((r) => r.method == 'PATCH'), isEmpty);
      await service.dispose();
      await client.dispose();
    },
  );
  test('Late Owner inbox response is discarded after sign-out', () async {
    final started = Completer<void>(), response = Completer<void>();
    final client = SupabaseClient(
      'https://example.invalid',
      'synthetic',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        dynamic data = [];
        if (request.url.path.endsWith('/get_trexven_notifications')) {
          if (!started.isCompleted) started.complete();
          await response.future;
          data = [
            {
              'alert_key': 'alert:old',
              'title': 'Private old account',
              'route': 'inventory',
              'read_at': null,
            },
          ];
        }
        return http.Response(
          jsonEncode(data),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await signInSynthetic(client);
    final service = AlertService.withClients(
      supabase: client,
      vision: InboxVision(),
      realtime: false,
      notifications: false,
    );
    final initializing = service.init('business');
    await started.future;
    await client.auth.signOut(scope: SignOutScope.local);
    await Future<void>.delayed(Duration.zero);
    response.complete();
    await initializing;
    expect(service.alerts, isEmpty);
    expect(service.unreadCount, 0);
    await service.dispose();
    await client.dispose();
  });
}
