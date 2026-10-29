import 'package:trexven_operations/trexven_operations.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'vision_service.dart';

/// One inbox for Supabase notifications and the active local Vision store.
/// Events remain in their own repository and presentation screens.
class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal()
    : _supabase = Supabase.instance.client,
      _vision = VisionService(),
      _realtime = true,
      _nativeNotifications = true;
  AlertService.withClients({
    required SupabaseClient supabase,
    required VisionService vision,
    bool realtime = true,
    bool notifications = true,
  }) : _supabase = supabase,
       _vision = vision,
       _realtime = realtime,
       _nativeNotifications = notifications;
  final SupabaseClient _supabase;
  final VisionService _vision;
  final bool _realtime;
  final bool _nativeNotifications;
  final _notifications = FlutterLocalNotificationsPlugin();
  RealtimeChannel? _channel;
  Timer? _timer;
  String? _businessId;
  String? _userId;
  StreamSubscription<AuthState>? _authSubscription;
  int _generation = 0;
  int? _refreshGeneration;
  int _readRevision = 0;
  bool _localSeeded = false;
  bool _cloudSeeded = false;
  bool _notificationsReady = false;
  final _alerts = <Map<String, dynamic>>[];
  final _listeners = <void Function()>[];
  Map<String, dynamic>? _pendingNotification;
  void Function(Map<String, dynamic>)? onNotificationTap;
  String? connectionError;
  bool loading = false;
  int _cloudUnread = 0, _localUnread = 0;

  List<Map<String, dynamic>> get alerts => List.unmodifiable(_alerts);
  int get unreadCount => _cloudUnread + _localUnread;
  Map<String, dynamic>? takePendingNotification() {
    final pending = _pendingNotification;
    _pendingNotification = null;
    return pending;
  }

  Future<void> init(String businessId) async {
    final generation = ++_generation;
    _timer?.cancel();
    await _channel?.unsubscribe();
    if (generation != _generation) return;
    _businessId = businessId;
    _userId = _supabase.auth.currentUser?.id;
    await _authSubscription?.cancel();
    _authSubscription = _supabase.auth.onAuthStateChange.listen((state) {
      if (state.session?.user.id == _userId) return;
      _generation++;
      _timer?.cancel();
      _businessId = null;
      _alerts.clear();
      _cloudUnread = 0;
      _localUnread = 0;
      _pendingNotification = null;
      loading = false;
      _notifyListeners();
    });
    _alerts.clear();
    _cloudUnread = 0;
    _localUnread = 0;
    _localSeeded = false;
    _cloudSeeded = false;
    loading = true;
    _notifyListeners();
    try {
      if (_nativeNotifications &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        await _notifications.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
          onDidReceiveNotificationResponse: (response) =>
              _notificationTap(response.payload),
        );
        await _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        _notificationsReady = true;
        final launch = await _notifications.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) {
          _notificationTap(launch?.notificationResponse?.payload);
        }
      }
    } catch (_) {
      _notificationsReady = false;
    }
    if (generation != _generation) return;
    if (_realtime) {
      _channel = _supabase
          .channel('alerts-$businessId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'alerts',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'business_id',
              value: businessId,
            ),
            callback: (payload) {
              if (generation != _generation) return;
              unawaited(refresh());
            },
          )
          .subscribe((status, error) {
            if (generation == _generation &&
                status == RealtimeSubscribeStatus.subscribed) {
              unawaited(refresh());
            }
          });
    }
    await refresh();
    if (generation != _generation) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  Future<void> refresh() async {
    final businessId = _businessId;
    final generation = _generation;
    if (businessId == null || _refreshGeneration == generation) return;
    _refreshGeneration = generation;
    final readRevision = _readRevision;
    final errors = <String>[];
    List<Map<String, dynamic>>? cloud, local;
    int? cloudUnread, localUnread;
    await Future.wait([
      (() async {
        try {
          final notifications = <Map<String, dynamic>>[];
          for (var offset = 0; offset <= 100000; offset += 100) {
            final rows =
                await _supabase
                        .rpc(
                          'get_trexven_notifications',
                          params: {
                            'p_business_id': businessId,
                            'p_application': 'owner',
                            'p_offset': offset,
                          },
                        )
                        .timeout(const Duration(seconds: 20))
                    as List;
            notifications.addAll(
              rows.map((e) => Map<String, dynamic>.from(e as Map)),
            );
            if (rows.length < 100) break;
          }
          // Only metadata is read from the legacy source. Operational RPC rows
          // and their personal read markers are the sole cloud inbox entries.
          final legacy = await _supabase
              .from('alerts')
              .select('id,source,reference_id,alert_type,severity')
              .eq('business_id', businessId)
              .order('created_at', ascending: false)
              .limit(100)
              .timeout(const Duration(seconds: 20));
          final metadata = {
            for (final row in legacy) 'alert:${row['id']}': row,
          };
          cloud = notifications
              .map(
                (row) => <String, dynamic>{
                  ...?metadata[row['alert_key']],
                  ...row,
                  'message': CustomerPresentation.notificationMessage(row),
                  'id': 'op:${row['alert_key']}',
                  'business_id': businessId,
                  'source':
                      metadata[row['alert_key']]?['source'] ??
                      (row['route'] == 'vision' ? 'camera_ai' : 'operational'),
                  'created_at': row['occurred_at'],
                  'is_read': row['read_at'] != null,
                },
              )
              .toList();
          cloudUnread = cloud!.where((row) => row['is_read'] != true).length;
        } catch (_) {
          errors.add('Cloud notifications could not refresh.');
        }
      })(),
      (() async {
        try {
          final inbox = await _vision.getAlertInbox();
          local = List<Map<String, dynamic>>.from(
            inbox['alerts'] as List,
          ).map((row) => {...row, 'id': 'vision:${row['id']}'}).toList();
          localUnread =
              (inbox['unread_count'] as num?)?.toInt() ??
              local!.where((row) => row['is_read'] != true).length;
        } catch (_) {
          errors.add(
            'Vision notifications could not refresh. Check Cloud Vision.',
          );
        }
      })(),
    ]);
    if (generation != _generation || _supabase.auth.currentUser?.id != _userId)
      return;
    if (readRevision != _readRevision) {
      // An acknowledgement completed while this snapshot was loading.
      // Reload before applying it so an older unread marker cannot reappear.
      _refreshGeneration = null;
      return refresh();
    }
    if (cloud != null && _cloudSeeded) {
      final known = _alerts.map((row) => row['id']).toSet();
      for (final row in cloud!) {
        if (!known.contains(row['id']) && row['is_read'] != true) {
          unawaited(_showLocalNotification(row, generation));
        }
      }
    }
    if (cloud != null) _cloudSeeded = true;
    if (local != null && _localSeeded) {
      final known = _alerts.map((row) => row['id']).toSet();
      for (final row in local!) {
        if (!known.contains(row['id']) && row['is_read'] != true) {
          unawaited(_showLocalNotification(row, generation));
        }
      }
    }
    if (local != null) _localSeeded = true;
    _cloudUnread = cloudUnread ?? _cloudUnread;
    _localUnread = localUnread ?? _localUnread;
    final oldLocal = _alerts
        .where((row) => row['id'].toString().startsWith('vision:'))
        .toList();
    final oldCloud = _alerts
        .where((row) => !row['id'].toString().startsWith('vision:'))
        .toList();
    _alerts
      ..clear()
      ..addAll([...(cloud ?? oldCloud), ...(local ?? oldLocal)]);
    _alerts.sort(
      (a, b) => (b['created_at'] ?? '').toString().compareTo(
        (a['created_at'] ?? '').toString(),
      ),
    );
    connectionError = errors.isEmpty ? null : errors.join(' ');
    loading = false;
    _refreshGeneration = null;
    _notifyListeners();
  }

  Future<void> markRead(String id) async {
    final businessId = _businessId;
    final generation = _generation;
    if (businessId == null || _supabase.auth.currentUser?.id != _userId) {
      throw StateError('Notifications are not connected.');
    }
    if (id.startsWith('vision:')) {
      await _vision.markAlertRead(id.substring(7));
    } else if (id.startsWith('op:')) {
      await _supabase.rpc(
        'mark_trexven_notification_read',
        params: {
          'p_business_id': businessId,
          'p_alert_key': id.substring(3),
          'p_read': true,
          'p_application': 'owner',
        },
      );
    } else {
      await _supabase
          .from('alerts')
          .update({'is_read': true})
          .eq('id', id)
          .eq('business_id', businessId)
          .select('id')
          .single();
    }
    if (generation != _generation) return;
    ++_readRevision;
    final index = _alerts.indexWhere((row) => row['id'].toString() == id);
    if (index >= 0 && _alerts[index]['is_read'] != true) {
      if (id.startsWith('vision:')) {
        _localUnread = (_localUnread - 1).clamp(0, 1 << 30);
      } else {
        _cloudUnread = (_cloudUnread - 1).clamp(0, 1 << 30);
      }
      _alerts[index] = {..._alerts[index], 'is_read': true};
    }
    _notifyListeners();
  }

  Future<void> markAllRead() async {
    final business = _businessId;
    final generation = _generation;
    if (business == null) throw StateError('Notifications are not connected.');
    final results = await Future.wait([
      (() async {
        try {
          for (final row in List<Map<String, dynamic>>.of(_alerts)) {
            final id = row['id'].toString();
            if (id.startsWith('op:') && row['is_read'] != true) {
              if (generation != _generation ||
                  _supabase.auth.currentUser?.id != _userId)
                return false;
              await markRead(id);
            }
          }
          return true;
        } catch (_) {
          return false;
        }
      })(),
      (() async {
        try {
          await _vision.markAllAlertsRead();
          return true;
        } catch (_) {
          return false;
        }
      })(),
    ]);
    if (generation != _generation) return;
    ++_readRevision;
    for (var i = 0; i < _alerts.length; i++) {
      final local = _alerts[i]['id'].toString().startsWith('vision:');
      if (results[local ? 1 : 0]) _alerts[i] = {..._alerts[i], 'is_read': true};
    }
    if (results[0]) _cloudUnread = 0;
    if (results[1]) _localUnread = 0;
    _notifyListeners();
    if (results.contains(false))
      throw StateError('Some notifications could not be marked read.');
  }

  void addListener(void Function() listener) {
    if (!_listeners.contains(listener)) _listeners.add(listener);
  }

  void removeListener(void Function() listener) => _listeners.remove(listener);
  void _notifyListeners() {
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }

  void _notificationTap(String? payload) {
    if (payload == null) return;
    try {
      final row = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      if (row['business_id'] != _businessId) return;
      // Defer cold-start navigation until MainScreen finishes initialization.
      _pendingNotification = row;
      if (!loading && onNotificationTap != null) {
        _pendingNotification = null;
        onNotificationTap!(row);
      }
    } catch (_) {
      /* Invalid or stale notification payload is ignored. */
    }
  }

  Future<void> _showLocalNotification(
    Map<String, dynamic> alert,
    int generation,
  ) async {
    if (!_notificationsReady) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation ||
          prefs.getBool('notifications_enabled') == false) {
        return;
      }
      final type = alert['alert_type']?.toString() ?? '';
      if (type.contains('stock') &&
          prefs.getBool('notify_low_stock') == false) {
        return;
      }
      if (type.contains('sale') && prefs.getBool('notify_sales') == false) {
        return;
      }
      if ([
            'camera_ai',
            'vision_local',
            'vision_intelligence',
          ].contains(alert['source']) &&
          prefs.getBool('notify_ai_alerts') == false) {
        return;
      }
      if ((type.contains('security') ||
              type.contains('auth') ||
              type.contains('password')) &&
          prefs.getBool('notify_security') == false)
        return;
      final severity = alert['severity']?.toString() ?? 'info';
      await _notifications.show(
        alert['id'].toString().hashCode & 0x7fffffff,
        alert['title']?.toString() ?? 'TREXVEN notification',
        alert['message']?.toString() ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'trexven_alerts',
            'Trexven Alerts',
            channelDescription: 'Security and business notifications',
            importance: severity == 'critical'
                ? Importance.max
                : Importance.high,
            priority: severity == 'critical' ? Priority.max : Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode({
          for (final key in [
            'id',
            'source',
            'reference_id',
            'business_id',
            'title',
            'message',
            'route',
          ])
            key: alert[key],
        }),
      );
    } catch (_) {
      /* A denied notification permission must not break the inbox. */
    }
  }

  Future<void> dispose() async {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _businessId = null;
    _alerts.clear();
    _cloudUnread = 0;
    _localUnread = 0;
    _pendingNotification = null;
    await _authSubscription?.cancel();
    _authSubscription = null;
    final channel = _channel;
    _channel = null;
    await channel?.unsubscribe();
  }
}
