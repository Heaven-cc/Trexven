import 'package:trexven_design_system/trexven_design_system.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'operations_client.dart';
import 'customer_presentation.dart';

class NotificationCenterScreen extends StatefulWidget {
  final OperationsClient api;
  final void Function(BuildContext context, String route, String? referenceId)
  open;
  const NotificationCenterScreen({
    super.key,
    required this.api,
    required this.open,
  });
  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late Future<List<Map<String, dynamic>>> rows;
  late String? user;
  bool busy = false;
  List<Map<String, dynamic>> _items = [];
  String? error;
  StreamSubscription<AuthState>? accountChanges;
  @override
  void initState() {
    super.initState();
    user = widget.api.client.auth.currentUser?.id;
    accountChanges = widget.api.client.auth.onAuthStateChange.listen((_) {
      if (mounted && widget.api.client.auth.currentUser?.id != user) {
        setState(() {
          rows = Future.value([]);
          error = null;
        });
      }
    });
    rows = load().timeout(const Duration(seconds: 25));
  }

  @override
  void dispose() {
    accountChanges?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> load() async {
    if (user == null || widget.api.client.auth.currentUser?.id != user) {
      throw StateError('Original authenticated account required.');
    }
    final result = <Map<String, dynamic>>[];
    // Bounded pages; no broad direct table access or Vision endpoint in POS.
    for (var offset = 0; offset < 1000; offset += 100) {
      final page =
          await widget.api
                  .call('get_trexven_notifications', {
                    'p_business_id': widget.api.businessId,
                    'p_application': widget.api.application,
                    'p_offset': offset,
                  })
                  .timeout(const Duration(seconds: 20))
              as List;
      if (widget.api.client.auth.currentUser?.id != user) {
        throw StateError('Account changed during notification refresh.');
      }
      result.addAll(page.map((row) => Map<String, dynamic>.from(row as Map)));
      if (page.length < 100) break;
    }
    _items = result;
    return result;
  }

  Future<void> mark(Map<String, dynamic> row, {bool? read}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.api.client.auth.currentUser?.id != user)
        throw StateError('Account changed.');
      final nextRead = read ?? row['read_at'] == null;
      await widget.api
          .call('mark_trexven_notification_read', {
            'p_business_id': widget.api.businessId,
            'p_alert_key': row['alert_key'],
            'p_read': nextRead,
            'p_application': widget.api.application,
          })
          .timeout(const Duration(seconds: 20));
      if (mounted && widget.api.client.auth.currentUser?.id == user) {
        setState(() {
          row['read_at'] = nextRead
              ? DateTime.now().toUtc().toIso8601String()
              : null;
          rows = Future.value(_items);
        });
      }
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Read status was not confirmed. Refresh current access before retrying.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _message(Map<String, dynamic> row) =>
      CustomerPresentation.notificationMessage(row);

  String _time(Map<String, dynamic> row) {
    final time = DateTime.tryParse('${row['occurred_at'] ?? ''}')?.toLocal();
    if (time == null) return 'Time unavailable';
    return MaterialLocalizations.of(context).formatMediumDate(time) +
        ' · ' +
        MaterialLocalizations.of(context).formatTimeOfDay(
          TimeOfDay.fromDateTime(time),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        );
  }

  Future<void> _open(Map<String, dynamic> row) async {
    if (busy || widget.api.client.auth.currentUser?.id != user) return;
    if (row['read_at'] == null) await mark(row, read: true);
    if (!mounted || widget.api.client.auth.currentUser?.id != user) return;
    widget.open(
      context,
      row['route'] as String,
      row['reference_id'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.api.client.auth.currentUser?.id != user) {
      return Scaffold(
        body: Center(
          child: Text(
            'Sign in with the original account or reopen notifications.',
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh notifications',
            onPressed: busy
                ? null
                : () => setState(
                    () => rows = load().timeout(const Duration(seconds: 25)),
                  ),
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: rows,
        builder: (context, state) {
          if (state.hasError && TrexvenPresentation.isPos(context))
            return Center(
              child: TrexvenErrorState(
                message: 'Notifications unavailable. Check your connection and current access.',
                onRetry: () => setState(() => rows = load()),
              ),
            );
          if (state.hasError)
            return Center(
              child: Text(
                'Notifications unavailable. Current access must be verified online.',
              ),
            );
          if (!state.hasData)
            return const TrexvenSkeleton(
              kind: TrexvenSkeletonKind.notifications,
            );
          return ListView(
            padding: TrexvenSpacing.pagePadding,
            children: [
              Padding(
                padding: TrexvenSpacing.cardPadding,
                child: Text(
                  'Updates for your business. Tap a notification to view its details.',
                ),
              ),
              if (error != null)
                Padding(
                  padding: TrexvenSpacing.cardPadding,
                  child: Text(error!),
                ),
              if (busy) Text('Working…'),
              if (state.data!.isEmpty)
                TrexvenPresentation.isPos(context)
                    ? const TrexvenEmptyState(
                        title: 'No notifications',
                        message: 'New operational updates will appear here.',
                        icon: Icons.notifications_none_rounded,
                      )
                    : ListTile(title: Text('No current notifications.')),
              for (final row in state.data!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(TrexvenRadii.card),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      minVerticalPadding: 10,
                      title: Text(
                        row['title'] as String,
                        style: TextStyle(
                          fontSize: TrexvenFontSize.body,
                          fontWeight: row['read_at'] == null
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _message(row),
                              style: const TextStyle(
                                fontSize: TrexvenFontSize.caption,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_time(row)} · ${row['read_at'] == null ? 'Unread' : 'Read'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: busy ? null : () => _open(row),
                      trailing: IconButton(
                        tooltip: row['read_at'] == null
                            ? 'Mark read'
                            : 'Mark unread',
                        onPressed: busy ? null : () => mark(row),
                        icon: Icon(
                          row['read_at'] == null
                              ? Icons.mark_email_unread_outlined
                              : Icons.drafts_outlined,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
