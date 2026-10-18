import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'database_service.dart';

class AccountDeletionError implements Exception {
  final String message;
  AccountDeletionError(this.message);
  @override
  String toString() => message;
}

/// A deletion capability is stored only in device secure storage. Financial
/// journals and their encryption keys are never removed by account cleanup.
class AccountDeletionService {
  static const _key = 'trexven_account_deletion_v1';
  static Future<void> _storageQueue = Future<void>.value();
  final SupabaseClient client;
  final FlutterSecureStorage storage;
  AccountDeletionService({
    SupabaseClient? client,
    FlutterSecureStorage? storage,
  }) : client = client ?? Supabase.instance.client,
       storage = storage ?? const FlutterSecureStorage();

  Future<T> _editStorage<T>(Future<T> Function() change) {
    final operation = _storageQueue.then<T>((_) => change());
    _storageQueue = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  bool _sameIntent(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a['user_id'] == b['user_id'] &&
      a['request_id'] == b['request_id'] &&
      a['recovery_token'] == b['recovery_token'];

  Future<void> _removeIntent(
    Map<String, dynamic> intent,
  ) => _editStorage<void>(() async {
    final remaining = await pending();
    if (remaining == null) return;
    if (!_sameIntent(remaining, intent)) {
      throw AccountDeletionError(
        'Deletion recovery context changed. The new record has been preserved.',
      );
    }
    await storage.delete(key: _key).timeout(const Duration(seconds: 10));
  });

  Future<Map<String, dynamic>?> pending() async {
    final encoded = await storage
        .read(key: _key)
        .timeout(const Duration(seconds: 10));
    if (encoded == null) return null;
    final value = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
    if (value['user_id'] is! String ||
        value['request_id'] is! String ||
        value['recovery_token'] is! String ||
        !RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(value['recovery_token'] as String)) {
      throw AccountDeletionError(
        'The original deletion recovery record could not be read. Preserve device storage and contact support.',
      );
    }
    return value;
  }

  Future<void> deleteConfirmed() async {
    final user = client.auth.currentUser?.id;
    if (user == null)
      throw AccountDeletionError('Sign in before confirming account deletion.');
    final original = await pending();
    if (original != null) {
      if (original['user_id'] != user) {
        throw AccountDeletionError(
          'Finish the previously confirmed deletion before starting another account deletion.',
        );
      }
      return recover();
    }
    if (await DatabaseService(client: client).hasUnresolvedOperation()) {
      throw AccountDeletionError(
        'Recover your interrupted financial operation before deleting your account.',
      );
    }
    if (client.auth.currentUser?.id != user)
      throw AccountDeletionError(
        'Account changed. Confirm deletion from the original account.',
      );
    final random = Random.secure();
    final intent = <String, dynamic>{
      'user_id': user,
      'request_id': const Uuid().v4(),
      'recovery_token': List.generate(
        32,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
    };
    await _editStorage<void>(() async {
      if (await pending() != null || client.auth.currentUser?.id != user) {
        throw AccountDeletionError(
          'Account or deletion recovery context changed. Recover the original request.',
        );
      }
      await storage
          .write(key: _key, value: jsonEncode(intent))
          .timeout(const Duration(seconds: 10));
    });
    await _begin(intent);
  }

  Future<void> recover() async {
    final intent = await pending();
    if (intent == null)
      throw AccountDeletionError('No interrupted account deletion remains.');
    if (intent['confirmed_deleted'] == true) return _cleanDevice(intent);
    Map<String, dynamic> data;
    try {
      data = await _invoke('account-deletion-recovery', {
        'request_id': intent['request_id'],
        'recovery_token': intent['recovery_token'],
      });
    } on AccountDeletionResponseError catch (error) {
      if (error.data['code'] == 'ACCOUNT_DELETION_NOT_FOUND') {
        // The original request may never have reached the server. Resubmit only
        // that same confirmed identity, under its original authenticated account.
        return _begin(intent);
      }
      rethrow;
    }
    await _complete(intent, data);
  }

  Future<void> _begin(Map<String, dynamic> intent) async {
    final session = client.auth.currentSession;
    if (session == null || session.user.id != intent['user_id']) {
      throw AccountDeletionError(
        'Sign in to the original account to finish this deletion request.',
      );
    }
    try {
      final data = await _invoke('delete-account', {
        'action': 'delete',
        'confirmation': 'DELETE',
        'request_id': intent['request_id'],
        'recovery_token': intent['recovery_token'],
      }, accessToken: session.accessToken);
      await _complete(intent, data);
    } on AccountDeletionResponseError catch (error) {
      // These responses explicitly establish that no deletion was accepted.
      // Transport failures and uncertain responses always retain recovery data.
      if (error.data['accepted'] == false) {
        await _removeIntent(intent);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _invoke(
    String function,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    try {
      final result = await client.functions
          .invoke(
            function,
            body: body,
            headers: accessToken == null
                ? null
                : {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 60));
      final data = result.data;
      if (data is! Map)
        throw AccountDeletionError(
          'Account deletion was not confirmed. Recover the original request.',
        );
      final parsed = Map<String, dynamic>.from(data);
      if (parsed['success'] != true || parsed['deleted_user'] != true) {
        throw AccountDeletionResponseError(parsed);
      }
      return parsed;
    } on FunctionException catch (error) {
      if (error.details is Map)
        throw AccountDeletionResponseError(
          Map<String, dynamic>.from(error.details as Map),
        );
      throw AccountDeletionError(
        'Account deletion was not confirmed. Keep the original request and recover it.',
      );
    }
  }

  Future<void> _complete(
    Map<String, dynamic> intent,
    Map<String, dynamic> data,
  ) async {
    if (data['request_id'] != intent['request_id'] ||
        data['financial_records_preserved'] != true) {
      throw AccountDeletionError(
        'The deletion receipt did not match your original request. Keep it for recovery.',
      );
    }
    await _editStorage<void>(() async {
      final remaining = await pending();
      if (remaining == null) return;
      if (!_sameIntent(remaining, intent))
        throw AccountDeletionError(
          'Deletion context changed. Preserve the original receipt.',
        );
      await storage
          .write(
            key: _key,
            value: jsonEncode({...intent, 'confirmed_deleted': true}),
          )
          .timeout(const Duration(seconds: 10));
    });
    await _cleanDevice(intent);
  }

  Future<void> _cleanDevice(Map<String, dynamic> intent) async {
    if (client.auth.currentUser?.id == intent['user_id']) {
      DatabaseService(client: client).clearBusinessSelection();
      try {
        await client.auth
            .signOut(scope: SignOutScope.local)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        if (client.auth.currentSession != null) {
          throw AccountDeletionError(
            'Your account is deleted. Recover once more to clear the remaining device session.',
          );
        }
      }
      if (client.auth.currentSession != null) {
        throw AccountDeletionError(
          'Your account is deleted. Device sign-out is still pending; recover this request.',
        );
      }
    }
    // A different currently signed-in account is never signed out or deleted.
    await _removeIntent(intent);
  }
}

class AccountDeletionResponseError extends AccountDeletionError {
  final Map<String, dynamic> data;
  AccountDeletionResponseError(this.data)
    : super(
        data['error'] is String
            ? data['error'] as String
            : 'Account deletion is not confirmed. Recover the original request.',
      );
}
