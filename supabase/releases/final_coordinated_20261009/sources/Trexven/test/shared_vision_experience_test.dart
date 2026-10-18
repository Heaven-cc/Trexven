import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odt/core/app_theme.dart';
import 'package:odt/models/camera.dart';
import 'package:odt/screens/intelligence/live_feed_screen.dart';
import 'package:odt/screens/intelligence/event_detail_screen.dart';
import 'package:odt/services/vision_service.dart';

final image = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
);
final front = Camera(
  id: 'front',
  businessId: 'business',
  name: 'Front',
  status: 'online',
);
final aisle = Camera(
  id: 'aisle',
  businessId: 'business',
  name: 'Aisle',
  status: 'online',
);
Widget app(Widget screen) =>
    MaterialApp(theme: AppTheme.lightTheme, home: screen);
void main() {
  test('shared requests are authenticated app paths', () {
    expect(
      VisionService.appPath('/intelligence/state'),
      '/app/intelligence/state',
    );
    expect(
      VisionService.appPath('/intelligence/cameras/front/orientation'),
      '/app/intelligence/cameras/front/orientation',
    );
  });
  testWidgets('AI Live switches camera with reason and clears offline video', (
    tester,
  ) async {
    String? selected = 'front';
    await tester.pumpWidget(
      app(
        LiveFeedScreen(
          camera: front,
          aiLive: true,
          frameLoader: () async => image,
          cameraLoader: () async => [front, aisle],
          stateLoader: () async => {
            'ai_live': {
              'camera_id': selected,
              'reason': 'Review event on selected camera',
            },
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('AI Live · Front'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    selected = 'aisle';
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('AI Live · Aisle'), findsOneWidget);
    expect(find.text('Review event on selected camera'), findsOneWidget);
    selected = null;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.text('OFF'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('manual live view stays on the owner selected camera', (
    tester,
  ) async {
    var selections = 0;
    await tester.pumpWidget(
      app(
        LiveFeedScreen(
          camera: front,
          frameLoader: () async => image,
          stateLoader: () async {
            selections++;
            return {
              'ai_live': {'camera_id': 'aisle'},
            };
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(selections, 0);
    expect(find.text('Front'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('orientation adjustment preserves camera zones and priority', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    await tester.pumpWidget(
      app(
        LiveFeedScreen(
          camera: front,
          frameLoader: () async => image,
          orientationLoader: () async => {
            'quarter_turns': 0,
            'level_degrees': 0,
            'mirror': false,
            'zones': [
              {'id': 'checkout'},
            ],
            'priority': 12,
          },
          orientationSaver: (options) async {
            saved = options;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Adjust camera image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rotate 90°'));
    await tester.pump();
    expect(find.text('Rotation: 90°'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved!['quarter_turns'], 1);
    expect(saved!['priority'], 12);
    expect(saved!['zones'], [
      {'id': 'checkout'},
    ]);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'global event shows rule score, reasoning and multi camera timeline',
    (tester) async {
      await tester.pumpWidget(
        app(
          EventDetailScreen(
            eventId: 'global',
            source: 'vision_intelligence',
            loadEvent: () async => {
              'event': {
                'event_type': 'product_removed',
                'state': 'RESOLVED',
                'classification': 'likely_legitimate_sale',
                'intelligence_confidence': .85,
                'camera_ids': ['front', 'checkout'],
                'requires_review': false,
                'reasoning': [
                  'Unique completed POS sale supports this activity',
                ],
                'timeline': [
                  {
                    'event_type': 'product_removed',
                    'timestamp': 1000,
                    'camera_id': 'front',
                  },
                ],
              },
              'recordings': [],
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('State: RESOLVED'), findsOneWidget);
      expect(find.text('Cameras: 2'), findsOneWidget);
      expect(
        find.textContaining('rule score, not a probability'),
        findsOneWidget,
      );
      expect(
        find.text('Unique completed POS sale supports this activity'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
