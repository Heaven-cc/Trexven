import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Handles all communication with the ODT vision server.
///
/// The vision server URL is stored in SharedPreferences so the user
/// can update it when they move to a cloud server.
class VisionService {
  static const String _prefKey = 'vision_server_url';
  static const String _apiKeyPrefKey = 'vision_api_key';

  // Singleton
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  String _baseUrl = 'http://10.0.2.2:8000'; // Android emulator default
  String _apiKey = '';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_prefKey) ?? 'http://10.0.2.2:8000';
    _apiKey = prefs.getString(_apiKeyPrefKey) ?? '';
  }

  Future<void> setServerUrl(String url) async {
    _baseUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _baseUrl);
  }

  Future<void> setApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyPrefKey, key);
  }

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;

  Map<String, String> get _headers => {
    'X-Vision-API-Key': _apiKey,
    'Content-Type': 'application/json',
  };

  /// Returns the URL for live MJPEG stream (for an <Image.network>).
  String streamUrl(String cameraId) => '$_baseUrl/stream/$cameraId';

  /// Returns the URL for a single processed frame (JPEG).
  String frameUrl(String cameraId) => '$_baseUrl/frame/$cameraId';

  /// Check if the vision server is reachable.
  Future<Map<String, dynamic>> health() async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/health'), headers: _headers)
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return {'error': 'HTTP ${resp.statusCode}'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Test whether an RTSP URL is reachable before saving.
  Future<Map<String, dynamic>> testConnection(String rtspUrl) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/test-connection'),
            headers: _headers,
            body: jsonEncode({'stream_url': rtspUrl, 'timeout_seconds': 10.0}),
          )
          .timeout(const Duration(seconds: 15));
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get a processed frame as bytes.
  Future<List<int>?> getFrame(String cameraId) async {
    try {
      final resp = await http
          .get(Uri.parse('$_baseUrl/frame/$cameraId'), headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) return resp.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }
}
