import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase;
  AuthService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;
  static const callbackUrl = 'com.trexven.app://auth/callback';
  static String? get redirectUrl => kIsWeb ? Uri.base.origin : callbackUrl;
  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;
  Future<AuthResponse> signIn(String email, String password) => _supabase.auth
      .signInWithPassword(email: email.trim(), password: password);
  Future<AuthResponse> signUp(String email, String password, String name) =>
      _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: redirectUrl,
        data: {'full_name': name.trim()},
      );
  Future<void> signInWithGoogle() async {
    final launched = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (!launched) {
      throw const AuthException(
        'Could not open Google sign-in. Please try again.',
      );
    }
  }

  Future<void> resetPassword(String email) => _supabase.auth
      .resetPasswordForEmail(email.trim(), redirectTo: redirectUrl);
  Future<void> signOut() => _supabase.auth.signOut();
}
