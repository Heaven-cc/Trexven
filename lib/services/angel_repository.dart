import 'package:supabase_flutter/supabase_flutter.dart';

/// Existing author-scoped conversation persistence; message sends are never retried.
class AngelRepository {
  final SupabaseClient client;
  AngelRepository(this.client);
  String get user =>
      client.auth.currentUser?.id ??
      (throw StateError('Sign in to use Angel.'));
  Future<String> create(String business, String id, String title) async {
    final actor = user;
    try {
      await client
          .from('angel_conversations')
          .insert({
            'id': id,
            'business_id': business,
            'user_id': actor,
            'title': title.length > 80 ? title.substring(0, 80) : title,
          })
          .timeout(const Duration(seconds: 20));
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
    final row = await client
        .from('angel_conversations')
        .select('id')
        .eq('id', id)
        .eq('business_id', business)
        .eq('user_id', actor)
        .single()
        .timeout(const Duration(seconds: 20));
    if (user != actor) throw StateError('Account changed.');
    return row['id'] as String;
  }

  Future<List<Map<String, dynamic>>> history(
    String business,
    String id, {
    Map<String, dynamic>? before,
  }) async {
    final actor = user;
    // Explicit conversation ownership check supplements existing message RLS.
    await client
        .from('angel_conversations')
        .select('id')
        .eq('id', id)
        .eq('business_id', business)
        .eq('user_id', actor)
        .single()
        .timeout(const Duration(seconds: 20));
    var query = client
        .from('angel_messages')
        .select('id,role,content,created_at')
        .eq('conversation_id', id);
    if (before != null) {
      query = query.or(
        'created_at.lt.${before['created_at']},and(created_at.eq.${before['created_at']},id.lt.${before['id']})',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(100)
        .timeout(const Duration(seconds: 20));
    if (user != actor) throw StateError('Account changed.');
    return List<Map<String, dynamic>>.from(rows);
  }
}
