import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_theme.dart';
import '../../services/database_service.dart';

class AngelScreen extends StatefulWidget {
  const AngelScreen({super.key});

  @override
  State<AngelScreen> createState() => _AngelScreenState();
}

class _AngelScreenState extends State<AngelScreen> {
  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final List<_AngelMessage> _messages = [];

  bool _loadingHistory = true;
  String? _conversationId;
  bool _isThinking = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();

    _messages.add(
      const _AngelMessage(
        text:
            "Hello. I'm Angel. I'm here to help you understand and manage your business.",
        isAngel: true,
      ),
    );
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final businessId = await _db.requireBusinessId();
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw StateError('Sign in to use Angel.');
      final conversation = await _supabase
          .from('angel_conversations')
          .select('id')
          .eq('business_id', businessId)
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (conversation != null) {
        final history = await _supabase
            .from('angel_messages')
            .select('role,content')
            .eq('conversation_id', conversation['id'])
            .order('created_at', ascending: false)
            .limit(100);
        if (!mounted) return;
        setState(() {
          _conversationId = conversation['id'] as String;
          if (history.isNotEmpty) {
            _messages.clear();
            _messages.addAll(
              history.reversed.map(
                (row) => _AngelMessage(
                  text: row['content'] as String,
                  isAngel: row['role'] == 'assistant',
                ),
              ),
            );
          }
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted)
        _showError('Unable to load Angel history. Reopen Angel to retry.');
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND MESSAGE TO ANGEL
  // ============================================================

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isThinking || _loadingHistory) {
      return;
    }

    // Add user's message immediately.
    setState(() {
      _messages.add(_AngelMessage(text: text, isAngel: false));

      _messageController.clear();
      _isThinking = true;
    });

    _scrollToBottom();

    try {
      final response = await _supabase.functions
          .invoke(
            'angel',
            body: {
              'business_id': await _db.requireBusinessId(),
              'message': text,
              'timezone_offset_minutes':
                  DateTime.now().timeZoneOffset.inMinutes,
              if (_conversationId != null) 'conversation_id': _conversationId,
            },
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      final data = response.data;

      if (data == null) {
        throw Exception('Angel returned an empty response.');
      }

      Map<String, dynamic> result;

      if (data is Map<String, dynamic>) {
        result = data;
      } else if (data is Map) {
        result = Map<String, dynamic>.from(data);
      } else if (data is String) {
        result = jsonDecode(data);
      } else {
        throw Exception('Invalid response from Angel.');
      }

      if (result['success'] != true) {
        throw Exception(
          result['details']?.toString().isNotEmpty == true
              ? '${result['error'] ?? 'Angel could not process your request.'}\n${result['details']}'
              : result['error']?.toString() ??
                    'Angel could not process your request.',
        );
      }

      final answer = result['reply']?.toString().trim();

      if (answer == null || answer.isEmpty) {
        throw Exception('Angel returned an empty answer.');
      }

      setState(() {
        _conversationId = result['conversation_id'] as String?;
        _messages.add(_AngelMessage(text: answer, isAngel: true));

        _isThinking = false;
      });

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isThinking = false;
      });

      String displayError = error.toString();
      if (error is TimeoutException) {
        displayError = "Connection timed out. Please try again.";
      }

      _showError('Angel could not connect right now.\n\n$displayError');
    }
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // VOICE
  // ============================================================

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.trexvenColors.muted ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Angel',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Business intelligence',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 15, 18, 20),
                    itemCount: _messages.length + (_isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isThinking && index == _messages.length) {
                        return _buildThinkingBubble();
                      }
                      return _buildMessage(_messages[index]);
                    },
                  ),
          ),
          _buildSuggestionArea(),
          _buildInputArea(),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  Widget _buildMessage(_AngelMessage message) {
    final theme = Theme.of(context);
    final isAngel = message.isAngel;

    return Align(
      alignment: isAngel ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .82,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isAngel
              ? theme.trexvenColors.cardBackground
              : theme.colorScheme.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isAngel ? 4 : 18),
            bottomRight: Radius.circular(isAngel ? 18 : 4),
          ),
          border: isAngel
              ? Border.all(
                  color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAngel)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'ANGEL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: isAngel ? theme.colorScheme.onSurface : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // THINKING
  // ============================================================

  Widget _buildThinkingBubble() {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
        decoration: BoxDecoration(
          color: theme.trexvenColors.cardBackground,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Angel is thinking...',
              style: TextStyle(fontSize: 12, color: theme.trexvenColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUGGESTIONS
  // ============================================================

  Widget _buildSuggestionArea() {
    return SizedBox(
      height: 48,

      child: ListView(
        scrollDirection: Axis.horizontal,

        padding: const EdgeInsets.symmetric(horizontal: 18),

        children: [
          _suggestion('How are sales today?'),

          _suggestion('Check my stock'),

          _suggestion('Any unusual activity?'),

          _suggestion('What happened today?'),
        ],
      ),
    );
  }

  Widget _suggestion(String text) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: theme.trexvenColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.trexvenColors.muted,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _buildInputArea() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: theme.trexvenColors.cardBackground,
        border: Border(
          top: BorderSide(
            color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: theme.trexvenColors.border ?? const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                enabled: !_loadingHistory && !_isThinking,
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Message Angel...',
                  hintStyle: TextStyle(
                    color: theme.trexvenColors.muted?.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) {
                  _sendMessage();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MESSAGE MODEL
// ============================================================

class _AngelMessage {
  final String text;
  final bool isAngel;

  const _AngelMessage({required this.text, required this.isAngel});
}
