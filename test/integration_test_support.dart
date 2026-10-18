import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trexven_operations/src/durable_state.dart';

class MemoryOperationState implements DurableState {
  final Map<String, dynamic> value = {};
  @override
  Future<Map<String, dynamic>> read() async => value;
  @override
  Future<T> mutate<T>(T Function(Map<String, dynamic>) change) async =>
      change(value);
}

Future<void> signInSynthetic(
  SupabaseClient client, {
  String user = 'synthetic-owner',
}) async {
  final token = base64Url
      .encode(utf8.encode(jsonEncode({'sub': user, 'exp': 4102444800})))
      .replaceAll('=', '');
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': 'eyJhbGciOiJIUzI1NiJ9.$token.synthetic',
      'refresh_token': 'synthetic-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': user,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );
}
