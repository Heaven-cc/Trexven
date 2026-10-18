import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:odt/core/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:odt/models/camera.dart';
import 'package:odt/services/vision_service.dart';
import 'package:odt/services/alert_service.dart';
import 'package:odt/screens/intelligence/intelligence_tab.dart';
import 'package:odt/screens/intelligence/live_feed_screen.dart';
import 'package:odt/screens/intelligence/events_screen.dart';
import 'package:odt/screens/intelligence/event_detail_screen.dart';
import 'package:odt/screens/intelligence/alerts_screen.dart';
import 'package:odt/screens/intelligence/recording_playback_screen.dart';

const business = '00000000-0000-0000-0000-000000000001';
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
);

class NavigationAlertService extends AlertService {
  NavigationAlertService(SupabaseClient cloud)
    : super.withClients(
        supabase: cloud,
        vision: VisionService.withAccess(accessHeaders: () async => {}),
        realtime: false,
        notifications: false,
      );
  String? readId;
  @override
  List<Map<String, dynamic>> get alerts => [
    {
      'id': 'vision:1',
      'title': 'Attention',
      'source': 'vision_local',
      'reference_id': 7,
      'is_read': false,
    },
  ];
  @override
  Future<void> refresh() async {}
  @override
  Future<void> markRead(String id) async {
    readId = id;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'vision_server_url': 'http://vision.test:8000',
    });
    FlutterSecureStorage.setMockInitialValues({'vision_api_key': 'test-key'});
  });

  testWidgets(
    'camera card opens in-app live feed, with Events and existing Recordings access',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: IntelligenceTab(
            loadCameras: () async => [
              Camera(
                id: 'cam',
                businessId: business,
                name: 'Front camera',
                status: 'online',
                aiEnabled: true,
              ),
            ],
            liveFrameLoader: () async => png,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Events'), findsOneWidget);
      expect(find.byTooltip('Recordings'), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.text('Front camera')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(LiveFeedScreen), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Record'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'live feed never overlaps requests, clears stale image, reconnects and disposes',
    (tester) async {
      final first = Completer<List<int>?>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: LiveFeedScreen(
            camera: Camera(id: 'cam', businessId: business, name: 'Front'),
            frameLoader: () {
              calls++;
              return calls == 1
                  ? first.future
                  : Future.value(calls == 2 ? null : png);
            },
          ),
        ),
      );
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      first.complete(png);
      await tester.pump();
      expect(find.text('LIVE'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(find.textContaining('Camera offline'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(find.text('LIVE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      final disposedCalls = calls;
      await tester.pump(const Duration(seconds: 1));
      expect(calls, disposedCalls);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disposing live feed ignores a late response', (tester) async {
    final frame = Completer<List<int>?>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: LiveFeedScreen(
          camera: Camera(id: 'cam', businessId: business, name: 'Front'),
          frameLoader: () => frame.future,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    frame.complete(png);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Events display stored detections without fabricated confidence',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: EventsScreen(
            loadEvents: () async => [
              {
                'id': 1,
                'event_type': 'person_entered',
                'camera_name': 'Front',
                'occurred_at': '2026-10-02T12:00:00Z',
                'description': 'Person entered',
                'severity': 'info',
              },
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.text('person entered'), findsOneWidget);
      expect(find.textContaining('Front'), findsOneWidget);
      expect(find.textContaining('Confidence'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('event detail exposes only its stored associated clip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: EventDetailScreen(
          eventId: '7',
          loadEvent: () async => {
            'event': {
              'event_type': 'after_hours_activity',
              'description': 'Detected activity',
              'confidence': 0.9,
            },
            'recordings': [
              {'id': 'clip-7', 'duration_seconds': 3},
            ],
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Confidence: 90%'), findsOneWidget);
    expect(find.text('Video clip · 3s'), findsOneWidget);
    await tester.tap(find.text('Video clip · 3s'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final screen = tester.widget<RecordingPlaybackScreen>(
      find.byType(RecordingPlaybackScreen),
    );
    expect(screen.recordingId, 'clip-7');
    expect(screen.isLocal, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'local and cloud notifications use one inbox, durable read state and badge updates',
    () async {
      var localRead = false, cloudRead = false;
      var updates = 0;
      final vision = VisionService.withAccess(
        accessHeaders: () async => {
          'Authorization': 'Bearer test-session',
          'X-Business-ID': business,
        },
      );
      final client = MockClient((request) async {
        expect(request.headers['X-Business-ID'], business);
        if (request.url.path.endsWith('/read')) {
          localRead = true;
          return http.Response('{"updated":1}', 200);
        }
        return http.Response(
          jsonEncode({
            'alerts': [
              {
                'id': 1,
                'business_id': business,
                'source': 'vision_local',
                'reference_id': 7,
                'title': 'Attention',
                'message': 'Front camera',
                'is_read': localRead,
                'created_at': '2026-10-02T12:00:00Z',
              },
            ],
          }),
          200,
        );
      });
      final cloud = SupabaseClient(
        'http://cloud.test',
        'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.queryParameters['business_id'], 'eq.$business');
          if (request.method == 'HEAD') {
            return http.Response(
              '',
              200,
              request: request,
              headers: {'content-range': '*/${cloudRead ? 0 : 1}'},
            );
          }
          if (request.method == 'PATCH') {
            cloudRead = true;
            return http.Response(
              '{"id":"cloud-alert"}',
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode([
              {
                'id': 'cloud-alert',
                'business_id': business,
                'source': 'camera_ai',
                'reference_id': 'cloud-event',
                'title': 'Cloud attention',
                'is_read': cloudRead,
                'created_at': '2026-10-02T11:00:00Z',
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final service = AlertService.withClients(
        supabase: cloud,
        vision: vision,
        realtime: false,
        notifications: false,
      );
      service.addListener(() => updates++);
      await http.runWithClient(() async {
        await service.init(business);
        expect(service.connectionError, isNull);
        expect(service.unreadCount, 2);
        await service.markRead('vision:1');
        expect(localRead, isTrue);
        expect(service.unreadCount, 1);
        await service.markRead('cloud-alert');
        await service.refresh();
        expect(service.unreadCount, 0);
        expect(service.alerts.first['reference_id'], 7);
        expect(updates, greaterThan(3));
        await service.dispose();
      }, () => client);
      await cloud.dispose();
    },
  );

  testWidgets('notification tap opens its event and marks it read', (
    tester,
  ) async {
    late SupabaseClient cloud;
    await tester.runAsync(() async {
      cloud = SupabaseClient('http://cloud.test', 'test-key');
    });
    final service = NavigationAlertService(cloud);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AlertsScreen(alertService: service),
      ),
    );
    await tester.tapAt(tester.getCenter(find.text('Attention')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final destination = tester.widget<EventDetailScreen>(
      find.byType(EventDetailScreen),
    );
    expect(destination.eventId, '7');
    expect(destination.source, 'vision_local');
    expect(service.readId, 'vision:1');
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => cloud.dispose());
  });
}
