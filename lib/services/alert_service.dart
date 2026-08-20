import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Listens to Supabase Realtime on the [alerts] table and fires
/// local notifications when a new alert arrives for this business.
class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  RealtimeChannel? _channel;
  String? _businessId;

  final List<Map<String, dynamic>> _alerts = [];
  final List<void Function()> _listeners = [];

  List<Map<String, dynamic>> get alerts => List.unmodifiable(_alerts);
  int get unreadCount => _alerts.where((a) => a['is_read'] != true).length;

  Future<void> init(String businessId) async {
    _businessId = businessId;

    // Init local notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: android),
    );

    // Load existing unread alerts
    await _loadAlerts();

    // Subscribe to realtime inserts
    _channel = _supabase
        .channel('alerts-$businessId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: businessId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            _alerts.insert(0, row);
            _notifyListeners();
            _showLocalNotification(row);
          },
        )
        .subscribe();
  }

  Future<void> _loadAlerts() async {
    if (_businessId == null) return;
    final data = await _supabase
        .from('alerts')
        .select()
        .eq('business_id', _businessId!)
        .order('created_at', ascending: false)
        .limit(50);
    _alerts
      ..clear()
      ..addAll(List<Map<String, dynamic>>.from(data));
    _notifyListeners();
  }

  Future<void> markRead(String alertId) async {
    await _supabase
        .from('alerts')
        .update({'is_read': true})
        .eq('id', alertId);
    final idx = _alerts.indexWhere((a) => a['id'] == alertId);
    if (idx != -1) {
      _alerts[idx] = {..._alerts[idx], 'is_read': true};
      _notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    if (_businessId == null) return;
    await _supabase
        .from('alerts')
        .update({'is_read': true})
        .eq('business_id', _businessId!)
        .eq('is_read', false);
    for (var i = 0; i < _alerts.length; i++) {
      _alerts[i] = {..._alerts[i], 'is_read': true};
    }
    _notifyListeners();
  }

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final l in _listeners) {
      l();
    }
  }

  Future<void> _showLocalNotification(Map<String, dynamic> alert) async {
    final severity = alert['severity']?.toString() ?? 'info';
    final title = alert['title']?.toString() ?? 'Trexven Alert';
    final message = alert['message']?.toString() ?? '';

    final importance = severity == 'critical'
        ? Importance.max
        : severity == 'warning'
            ? Importance.high
            : Importance.defaultImportance;

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'trexven_alerts',
          'Trexven Alerts',
          channelDescription: 'Security and business alerts from Trexven AI',
          importance: importance,
          priority: severity == 'critical' ? Priority.max : Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _listeners.clear();
  }
}
