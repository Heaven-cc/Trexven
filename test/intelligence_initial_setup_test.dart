import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:odt/services/vision_service.dart';
import 'package:odt/screens/intelligence/intelligence_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Unconfigured Intelligence shows setup without calling a server',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      var requests = 0;
      final vision = VisionService.withAccess(accessHeaders: () async => {});
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: TrexvenTheme.lightTheme,
              home: IntelligenceTab(vision: vision),
            ),
          );
          await tester.pumpAndSettle();
        },
        () => MockClient((_) async {
          requests++;
          throw StateError(
            'An unconfigured tab must not query the default server',
          );
        }),
      );
      expect(requests, 0);
      expect(find.text('Set up Intelligence'), findsOneWidget);
      expect(find.text('Could not load cameras'), findsNothing);
      expect(find.text('Connect Cloud Vision'), findsOneWidget);
      expect(vision.isConfigured, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Configured server with zero cameras shows the real empty state',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'vision_server_url': 'http://vision.test:8000',
      });
      FlutterSecureStorage.setMockInitialValues({
        'vision_api_key': 'configured-key',
      });
      final vision = VisionService.withAccess(
        accessHeaders: () async => {},
        cloudUrl: 'https://vision.example.com',
      );
      var requests = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: TrexvenTheme.lightTheme,
              home: IntelligenceTab(vision: vision),
            ),
          );
          await tester.pumpAndSettle();
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.path, '/app/cameras');
          return http.Response('{"cameras":[]}', 200, request: request);
        }),
      );
      expect(requests, 1);
      expect(find.text('No cameras yet'), findsOneWidget);
      expect(find.text('Could not load cameras'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Configured server failure stays visible and retry can recover', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'vision_server_url': 'http://vision.test:8000',
    });
    FlutterSecureStorage.setMockInitialValues({
      'vision_api_key': 'configured-key',
    });
    final vision = VisionService.withAccess(
      accessHeaders: () async => {},
      cloudUrl: 'https://vision.example.com',
    );
    var fail = true;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: TrexvenTheme.lightTheme,
            home: IntelligenceTab(vision: vision),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Your Vision access could not be verified. Sign in again and retry.',
          ),
          findsOneWidget,
        );
        expect(find.text('No cameras yet'), findsNothing);
        expect(find.text('Set up Intelligence'), findsNothing);
        fail = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('No cameras yet'), findsOneWidget);
        expect(find.text('Could not load cameras'), findsNothing);
      },
      () => MockClient(
        (request) async => http.Response(
          fail ? '{"detail":"unauthorized"}' : '{"cameras":[]}',
          fail ? 401 : 200,
          request: request,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
