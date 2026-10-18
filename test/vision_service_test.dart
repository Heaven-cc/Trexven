import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:odt/services/vision_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:odt/screens/intelligence/vision_server_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferences.setMockInitialValues({
      'vision_server_url': 'http://localhost:8000',
      'vision_api_key': 'legacy-test-key',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });
  final vision = VisionService.withAccess(
    accessHeaders: () async => {
      'Authorization': 'Bearer test-session',
      'X-Business-ID': 'test-business',
    },
  );
  test('migrates legacy API key out of preferences', () async {
    await VisionService().init();
    expect(VisionService().apiKey, 'legacy-test-key');
    expect(
      (await SharedPreferences.getInstance()).getString('vision_api_key'),
      isNull,
    );
    expect(
      await const FlutterSecureStorage().read(key: 'vision_api_key'),
      'legacy-test-key',
    );
  });
  test('validates server address without accepting embedded credentials', () {
    expect(
      VisionService.normalizeUrl(' http://192.168.1.19:8000/ '),
      'http://192.168.1.19:8000',
    );
    for (final bad in [
      '192.168.1.19:8000',
      'file:///tmp/server',
      'http://user:secret@host:8000',
      'http://host:8000?key=secret',
    ]) {
      expect(() => VisionService.normalizeUrl(bad), throwsFormatException);
    }
  });
  test('pairing rejects a wrong key even when health is public', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      expect(request.headers['X-Vision-API-Key'], 'wrong');
      if (request.url.path == '/version')
        return http.Response('{"product":"TREXVEN Vision"}', 200);
      return http.Response('{"detail":"Invalid vision API key"}', 401);
    });
    await expectLater(
      http.runWithClient(
        () => vision.verifyConnection('http://localhost:8000', 'wrong'),
        () => client,
      ),
      throwsException,
    );
    expect(paths, ['/version', '/app/cameras']);
    expect(VisionService().apiKey, 'legacy-test-key');
  });
  test('pairing verifies product, protected cameras and health', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
        request.url.path == '/version'
            ? '{"product":"TREXVEN Vision"}'
            : request.url.path == '/cameras'
            ? '{"cameras":[]}'
            : '{"status":"ok"}',
        200,
      );
    });
    final result = await http.runWithClient(
      () => vision.verifyConnection('http://localhost:8000', 'test-key'),
      () => client,
    );
    expect(result['status'], 'ok');
    expect(paths, ['/version', '/app/cameras', '/health']);
  });
  test('frames use authenticated server camera route', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/app/cameras/cam-123/frame');
      expect(request.headers['X-Vision-API-Key'], 'legacy-test-key');
      return http.Response.bytes(
        [255, 216, 255, 217],
        200,
        headers: {'content-type': 'image/jpeg'},
      );
    });
    expect(
      await http.runWithClient(() => vision.getFrame('cam-123'), () => client),
      [255, 216, 255, 217],
    );
  });
  test('a missing processed frame returns no image', () async {
    final client = MockClient(
      (_) async => http.Response('{"detail":"Camera is not processing"}', 404),
    );
    expect(
      await http.runWithClient(() => vision.getFrame('cam-123'), () => client),
      isNull,
    );
  });
  testWidgets('pairing screen loads saved address and masks the API key', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: VisionServerScreen()));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Connect and save'), findsOneWidget);
    expect(find.text('http://localhost:8000'), findsOneWidget);
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.last.obscureText, isTrue);
    expect(find.text('Connected'), findsNothing);
  });
  test('camera credentials are encoded into the stream source', () {
    final source = VisionService.cameraSource(
      'rtsp://192.168.1.50:554/live',
      username: 'user@shop',
      password: 'p:a/ss',
    );
    final uri = Uri.parse(source);
    expect(uri.userInfo, 'user%40shop:p%3Aa%2Fss');
    expect(uri.host, '192.168.1.50');
    expect(
      () => VisionService.cameraSource('192.168.1.50'),
      throwsFormatException,
    );
    expect(
      () => VisionService.cameraSource('0', username: 'user'),
      throwsFormatException,
    );
  });
  test('adding camera posts to real registry and maps its identity', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/app/cameras');
      expect(request.headers['X-Vision-API-Key'], 'legacy-test-key');
      final body = jsonDecode(request.body) as Map;
      expect(body['stream_url'], 'rtsp://camera/live');
      expect(body['enabled'], false);
      return http.Response(
        '{"camera":{"camera_id":"local-123","name":"Front","enabled":false,"status":"offline"},"worker_started":false}',
        200,
      );
    });
    final camera = await http.runWithClient(
      () => vision.addCamera(
        name: 'Front',
        source: 'rtsp://camera/live',
        enabled: false,
      ),
      () => client,
    );
    expect(camera.id, 'local-123');
    expect(camera.provider, 'vision_local');
    expect(camera.aiEnabled, false);
  });
  test('Test Connection sends source to real server probe', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/app/test-connection');
      expect(jsonDecode(request.body)['stream_url'], 'rtsp://camera/live');
      return http.Response('{"success":true,"width":640,"height":480}', 200);
    });
    final result = await http.runWithClient(
      () => vision.testConnection('rtsp://camera/live'),
      () => client,
    );
    expect(result['success'], true);
  });
  test('registration errors are never reported as success', () async {
    final client = MockClient((_) async => http.Response('{}', 401));
    await expectLater(
      http.runWithClient(
        () => vision.addCamera(name: 'Front', source: '0'),
        () => client,
      ),
      throwsException,
    );
  });
}
