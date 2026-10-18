import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/business.dart';
import '../services/database_service.dart';

class UserProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _db = DatabaseService();

  StreamSubscription<AuthState>? _authSubscription;
  bool _disposed = false;
  int _businessGeneration = 0;
  User? _user;
  Business? _business;
  bool _isLoading = false;

  User? get user => _user;
  Business? get business => _business;
  bool get isLoading => _isLoading;

  String get ownerName => _user?.userMetadata?['full_name'] ?? 'Owner';
  String get businessName => _business?.businessName ?? 'Your Business';

  UserProvider() {
    _user = _supabase.auth.currentUser;
    _listenToAuthChanges();
    if (_user != null) {
      refreshBusiness();
    }
  }

  void _listenToAuthChanges() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen(
      (data) {
        final session = data.session;
        if (_user?.id != session?.user.id) _business = null;
        _user = session?.user;
        if (_user != null) {
          refreshBusiness();
        } else {
          _business = null;
        }
        notifyListeners();
      },
      onError: (Object error) {
        debugPrint('Unable to refresh authentication.');
      },
    );
  }

  Future<void> refreshUser() async {
    // Supabase.auth.getUser() fetches the fresh user data from the server
    final response = await _supabase.auth.getUser();
    _user = response.user;
    notifyListeners();
  }

  Future<void> refreshBusiness() async {
    final generation = ++_businessGeneration;
    _isLoading = true;
    notifyListeners();
    final userId = _user?.id;
    try {
      final business = await _db.getBusinessProfile();
      if (_disposed || _user?.id != userId || generation != _businessGeneration)
        return;
      _business = business;
    } catch (e) {
      debugPrint('BUSINESS_PROFILE_REFRESH_FAILED');
    } finally {
      if (!_disposed &&
          _user?.id == userId &&
          generation == _businessGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Updates the user metadata and refreshes local state
  Future<void> updateMetadata(Map<String, dynamic> data) async {
    final response = await _supabase.auth.updateUser(
      UserAttributes(data: data),
    );
    _user = response.user;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
