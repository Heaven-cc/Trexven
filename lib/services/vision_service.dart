import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_service.dart';

import 'dart:convert';

import '../models/camera.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VisionService {
  static const _prefKey = 'vision_server_url';
  static const _apiKeyPrefKey = 'vision_api_key';
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();
  VisionService.withAccess({required this.accessHeaders, String? cloudUrl}) {
    if (cloudUrl != null) _baseUrl = normalizeCloudUrl(cloudUrl);
  }
  Future<Map<String, String>> Function()? accessHeaders;
  String? _businessId, _userId;
  DateTime? _businessFetchedAt;

  Future<Map<String, String>> appHeaders() async {
    await init();
    if (accessHeaders != null) return {..._headers, ...await accessHeaders!()};
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw StateError('Sign in to view business cameras.');
    if (_userId != session.user.id ||
        _businessFetchedAt == null ||
        DateTime.now().difference(_businessFetchedAt!).inSeconds > 30) {
      _businessId = await DatabaseService().requireBusinessId();
      _userId = session.user.id;
      _businessFetchedAt = DateTime.now();
    }
    return {
      ..._headers,
      'Authorization': 'Bearer ${session.accessToken}',
      'X-Business-ID': _businessId!,
    };
  }

  static String appPath(String path) {
    if ([
      '/cameras',
      '/events',
      '/alerts',
      '/recordings',
      '/test-connection',
      '/intelligence',
    ].any(
      (prefix) =>
          path == prefix ||
          path.startsWith('$prefix/') ||
          path.startsWith('$prefix?'),
    )) {
      return '/app$path';
    }
    return path;
  }

  final _secure = const FlutterSecureStorage();
  String _baseUrl = const String.fromEnvironment('VISION_CLOUD_URL');
  String _apiKey = '';
  Future<void>? _initializing;
  Future<void> init() => _initializing ??= _load();
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // A device's legacy LAN address must never become the cloud endpoint.
    // Cloud routing is configured by the app release, not by individual staff.
    if (_baseUrl.isNotEmpty) _baseUrl = normalizeCloudUrl(_baseUrl);
    _apiKey = await _secure.read(key: _apiKeyPrefKey) ?? '';
    final legacy = prefs.getString(_apiKeyPrefKey);
    if (legacy != null) {
      if (_apiKey.isEmpty) {
        await _secure.write(key: _apiKeyPrefKey, value: legacy);
        _apiKey = legacy;
      }
      await prefs.remove(_apiKeyPrefKey);
    }
  }

  static String normalizeCloudUrl(String url) {
    final value = normalizeUrl(url);
    final uri = Uri.parse(value);
    final host = uri.host.toLowerCase();
    if (uri.scheme != 'https' ||
        !host.contains('.') ||
        RegExp(r'^[0-9.]+$').hasMatch(host) ||
        host.contains(':') ||
        host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal')) {
      throw const FormatException(
        'Cloud Vision requires a public HTTPS address.',
      );
    }
    return value;
  }

  Future<Map<String, dynamic>> connectCloud() async {
    await init();
    if (!isConfigured) throw StateError('Cloud Vision is not available yet.');
    // Business-scoped JWT authorization; no shared server secret in the app.
    final health = await request('/health');
    await request('/cameras');
    return health;
  }

  static String normalizeUrl(String url) {
    final value = url.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException('Enter a complete server address');
    }
    return value;
  }

  Future<void> setServerUrl(String url) async {
    await init();
    final value = normalizeUrl(url);
    await (await SharedPreferences.getInstance()).setString(_prefKey, value);
    _baseUrl = value;
  }

  Future<void> setApiKey(String key) async {
    await init();
    await _secure.write(key: _apiKeyPrefKey, value: key.trim());
    _apiKey = key.trim();
  }

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  bool get isConfigured => _baseUrl.isNotEmpty;
  Map<String, String> get _headers => {'Content-Type': 'application/json'};
  String frameUrl(String cameraId) =>
      '$_baseUrl/app/cameras/${Uri.encodeComponent(cameraId)}/frame';
  static Map<String, dynamic> decodeResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw Exception(
        'Your Vision access could not be verified. Sign in again and retry.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Vision request failed (HTTP ${response.statusCode}).');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected Vision Server response.');
    }
    return data;
  }

  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    await init();
    if (!isConfigured) throw StateError('Cloud Vision is not available yet.');
    try {
      final scoped = appPath(path);
      final headers = scoped.startsWith('/app/')
          ? await appHeaders()
          : _headers;
      final uri = Uri.parse('$_baseUrl$scoped');
      final response = await (switch (method) {
        'POST' => http.post(
          uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
        ),
        'DELETE' => http.delete(uri, headers: headers),
        _ => http.get(uri, headers: headers),
      }).timeout(const Duration(seconds: 10));
      return decodeResponse(response);
    } on http.ClientException {
      throw Exception(
        'Cannot reach Cloud Vision. Check your internet connection and retry.',
      );
    }
  }

  Future<Map<String, dynamic>> health() async {
    try {
      return await request('/health');
    } catch (error) {
      return {'error': error.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyConnection(String url, String key) async {
    final address = normalizeUrl(url);
    final headers = {...await appHeaders(), 'X-Vision-API-Key': key.trim()};
    final version = decodeResponse(
      await http
          .get(Uri.parse('$address/version'), headers: headers)
          .timeout(const Duration(seconds: 6)),
    );
    if (version['product'] != 'TREXVEN Vision') {
      throw Exception('This address is not a TREXVEN Vision Server.');
    }
    // Health is public; cameras verifies the key before pairing is saved.
    decodeResponse(
      await http
          .get(Uri.parse('$address/app/cameras'), headers: headers)
          .timeout(const Duration(seconds: 6)),
    );
    return decodeResponse(
      await http
          .get(Uri.parse('$address/health'), headers: headers)
          .timeout(const Duration(seconds: 6)),
    );
  }

  static String cameraSource(
    String source, {
    String username = '',
    String password = '',
  }) {
    final value = source.trim();
    if (RegExp(r'^\d+$').hasMatch(value)) {
      if (username.isNotEmpty || password.isNotEmpty) {
        throw const FormatException('Webcams do not use camera credentials.');
      }
      return value;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['rtsp', 'rtsps', 'http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException(
        'Enter a complete RTSP/HTTP camera URL, or 0 for the server webcam.',
      );
    }
    if (password.isNotEmpty && username.isEmpty) {
      throw const FormatException(
        'Enter the camera username with its password.',
      );
    }
    if (username.isEmpty) return value;
    return uri
        .replace(
          userInfo:
              '${Uri.encodeComponent(username)}:${Uri.encodeComponent(password)}',
        )
        .toString();
  }

  Future<Map<String, dynamic>> testConnection(String source) async {
    try {
      return await request(
        '/test-connection',
        method: 'POST',
        body: {'stream_url': source, 'timeout_seconds': 5.0},
      );
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not test camera. Check Vision Server pairing and connection.',
      };
    }
  }

  static Camera cameraFromServer(Map<String, dynamic> data) => Camera.fromMap({
    ...data,
    'id': data['camera_id'],
    'provider': 'vision_local',
    'is_active': data['enabled'],
    'ai_enabled': data['enabled'],
    'last_seen_at': data['last_seen'],
  });

  Future<List<Camera>> getCameras() async {
    final data = await request('/cameras');
    return (data['cameras'] as List)
        .map((row) => cameraFromServer(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<Camera> addCamera({
    required String name,
    required String source,
    String? location,
    bool enabled = true,
  }) async {
    final data = await request(
      '/cameras',
      method: 'POST',
      body: {
        'name': name.trim(),
        'location': location,
        'stream_url': source,
        'enabled': enabled,
      },
    );
    return cameraFromServer(Map<String, dynamic>.from(data['camera'] as Map));
  }

  Future<List<int>?> getFrame(
    String cameraId, {
    http.Client? client,
    bool annotated = false,
  }) async {
    try {
      await init();
      if (!isConfigured) return null;
      final headers = await appHeaders();
      final url = '${frameUrl(cameraId)}${annotated ? '?annotated=true' : ''}';
      final response =
          await (client == null
                  ? http.get(Uri.parse(url), headers: headers)
                  : client.get(Uri.parse(url), headers: headers))
              .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200 &&
          (response.headers['content-type'] ?? '').startsWith('image/jpeg')) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> pairBusiness() async =>
      request('/app/pair-business', method: 'POST');
  Future<List<Map<String, dynamic>>> getEvents({String? cameraId}) async {
    final query = Uri(
      queryParameters: {
        'limit': '100',
        if (cameraId != null) 'camera_id': cameraId,
      },
    ).query;
    final data = await request('/events?$query');
    return List<Map<String, dynamic>>.from(data['events'] as List);
  }

  Future<Map<String, dynamic>> getEvent(String id) =>
      request('/events/${Uri.encodeComponent(id)}');
  Future<Map<String, dynamic>> getSharedState() =>
      request('/intelligence/state');
  Future<List<Map<String, dynamic>>> getGlobalEvents() async {
    final data = await request('/intelligence/events');
    return List<Map<String, dynamic>>.from(data['events'] as List);
  }

  Future<Map<String, dynamic>> getGlobalEvent(String id) =>
      request('/intelligence/events/${Uri.encodeComponent(id)}');
  Future<Map<String, dynamic>> getOrientation(String id) =>
      request('/intelligence/cameras/${Uri.encodeComponent(id)}/orientation');
  Future<void> setOrientation(String id, Map<String, dynamic> options) async =>
      request(
        '/intelligence/cameras/${Uri.encodeComponent(id)}/orientation',
        method: 'POST',
        body: options,
      );
  Future<void> correctGlobalEvent(String id, String classification) async =>
      request(
        '/intelligence/events/${Uri.encodeComponent(id)}/correct',
        method: 'POST',
        body: {'classification': classification},
      );
  Future<List<Map<String, dynamic>>> getAlerts() async {
    final data = await request('/alerts?limit=100');
    return List<Map<String, dynamic>>.from(data['alerts'] as List);
  }

  Future<Map<String, dynamic>> getAlertInbox() async {
    await init();
    if (!isConfigured)
      return {'alerts': <Map<String, dynamic>>[], 'unread_count': 0};
    return request('/alerts?limit=100');
  }

  Future<void> markAlertRead(String id) async =>
      request('/alerts/${Uri.encodeComponent(id)}/read', method: 'POST');
  Future<void> markAllAlertsRead() async =>
      request('/alerts/read-all', method: 'POST');
  Future<List<Map<String, dynamic>>> getRecordings({String? cameraId}) async {
    final query = Uri(
      queryParameters: {
        'limit': '100',
        if (cameraId != null) 'camera_id': cameraId,
      },
    ).query;
    final data = await request('/recordings?$query');
    return List<Map<String, dynamic>>.from(data['recordings'] as List);
  }

  String recordingUrl(String id) =>
      '$_baseUrl/app/recordings/${Uri.encodeComponent(id)}/video';
}
