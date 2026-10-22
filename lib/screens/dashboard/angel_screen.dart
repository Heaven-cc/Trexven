import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/database_service.dart';
import '../../services/angel_repository.dart';
import 'package:uuid/uuid.dart';
import '../../widgets/angel_markdown.dart';

class AngelScreen extends StatefulWidget {
  const AngelScreen({super.key, this.client, this.database});
  final SupabaseClient? client;
  final DatabaseService? database;

  @override
  State<AngelScreen> createState() => _AngelScreenState();
}

class _AngelScreenState extends State<AngelScreen> {
  Color get bg => Theme.of(context).scaffoldBackgroundColor;
  Color get surface => Theme.of(context).colorScheme.surface;
  Color get inputBg => Theme.of(context).colorScheme.surfaceContainerHighest;
  Color get border => Theme.of(context).colorScheme.outlineVariant;
  Color get blue => Theme.of(context).colorScheme.primary;
  Color get muted => Theme.of(context).colorScheme.onSurfaceVariant;

  late final _supabase = widget.client ?? Supabase.instance.client;
  late final _db = widget.database ?? DatabaseService(client: _supabase);
  late final _repository = AngelRepository(_supabase);
  final Map<String, List<_AngelMessage>> _historyCache = {};
  Map<String, dynamic>? _oldestMessage;
  bool _hasOlder = false;
  bool _loadingOlder = false;
  String? _newConversationId;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<_AngelMessage> _messages = [];

  List<Map<String, dynamic>> _conversations = [];

  String? _businessId;
  String? _conversationId;
  String? _error;
  String? _failedMessage;

  bool _loading = true;
  bool _loadingChats = false;
  bool _thinking = false;

  int _loadVersion = 0;
  bool _moreChats = true;
  String? _ownerUserId;
  StreamSubscription<AuthState>? _authChanges;

  @override
  void initState() {
    super.initState();
    _ownerUserId = _supabase.auth.currentUser?.id;
    _authChanges = _supabase.auth.onAuthStateChange.listen((state) {
      if (!mounted || state.session?.user.id == _ownerUserId) return;
      ++_loadVersion;
      setState(() {
        _messages.clear();
        _historyCache.clear();
        _conversations.clear();
        _error = 'Return to the original account to use this conversation.';
        _conversationId = null;
        _businessId = null;
        _thinking = false;
        _loading = false;
      });
    });
    _initialize();
  }

  @override
  void dispose() {
    _authChanges?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (_supabase.auth.currentUser?.id != _ownerUserId) return;
    final version = _loadVersion;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final businessId = await _db.requireBusinessId().timeout(
        const Duration(seconds: 20),
      );
      if (!mounted || _supabase.auth.currentUser?.id != _ownerUserId) return;
      final userId = _supabase.auth.currentUser?.id;

      if (userId == null) {
        throw StateError('Sign in to use Angel.');
      }

      _businessId = businessId;

      await _loadConversations();

      if (!mounted ||
          version != _loadVersion ||
          _supabase.auth.currentUser?.id != _ownerUserId)
        return;

      if (_conversations.isNotEmpty) {
        final latest = _conversations.first;
        await _openConversation(latest['id'].toString());
      }
    } catch (_) {
      if (mounted &&
          version == _loadVersion &&
          _supabase.auth.currentUser?.id == _ownerUserId) {
        setState(() {
          _error = 'Unable to load Angel. Please try again.';
        });
      }
    } finally {
      if (mounted &&
          version == _loadVersion &&
          _supabase.auth.currentUser?.id == _ownerUserId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadConversations({bool more = false}) async {
    final businessId = _businessId;
    final userId = _supabase.auth.currentUser?.id;

    if (businessId == null || userId == null) return;

    setState(() => _loadingChats = true);

    try {
      final rows = await _supabase
          .from('angel_conversations')
          .select('id,title,updated_at')
          .eq('business_id', businessId)
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .order('id')
          .range(
            more ? _conversations.length : 0,
            (more ? _conversations.length : 0) + 99,
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted ||
          _supabase.auth.currentUser?.id != userId ||
          _businessId != businessId)
        return;

      setState(() {
        _moreChats = rows.length == 100;
        final next = List<Map<String, dynamic>>.from(
          rows.map((row) => Map<String, dynamic>.from(row)),
        );
        if (more) {
          final known = _conversations.map((e) => e['id']).toSet();
          _conversations.addAll(next.where((e) => !known.contains(e['id'])));
        } else {
          _conversations = next;
        }
      });
    } catch (_) {
      if (mounted) {
        if (_conversations.isEmpty && _messages.isEmpty) {
          setState(
            () => _error = 'Unable to load saved conversations. Please retry.',
          );
        }
        _showSnack('Unable to refresh conversation history.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingChats = false);
      }
    }
  }

  Future<void> _openConversation(String id) async {
    if (_thinking) return;

    final version = ++_loadVersion;

    final same = _conversationId == id;
    if (_conversationId != null)
      _historyCache[_conversationId!] = List.of(_messages);
    setState(() {
      _conversationId = id;
      _messages
        ..clear()
        ..addAll(_historyCache[id] ?? []);
      if (!same) _failedMessage = null;
      _error = null;
      _loading = true;
      _oldestMessage = null;
      _hasOlder = false;
    });

    try {
      final rows = await _repository.history(_businessId!, id);

      if (!mounted || version != _loadVersion) return;

      setState(() {
        _oldestMessage = rows.isEmpty ? null : rows.last;
        _hasOlder = rows.length == 100;
        _failedMessage = null;
        _messages.clear();
        _messages.addAll(
          rows.reversed.map(
            (row) => _AngelMessage(
              text: '${row['content'] ?? ''}',
              isAngel: row['role'] == 'assistant',
            ),
          ),
        );
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted || version != _loadVersion) return;

      setState(
        () => _error = 'Unable to load this conversation. Please retry.',
      );
      _showSnack('Unable to load this conversation.');
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _loading = false);
      }
    }
  }

  void _newChat() {
    if (_thinking) return;

    ++_loadVersion;

    setState(() {
      _conversationId = null;
      _newConversationId = null;
      _oldestMessage = null;
      _hasOlder = false;
      _messages.clear();
      _messageController.clear();
      _failedMessage = null;
      _error = null;
      _loading = false;
    });

    _scaffoldKey.currentState?.closeDrawer();

    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _sendMessage({String? preset, bool retry = false}) async {
    final message = (preset ?? _messageController.text).trim();

    if (message.isEmpty || _thinking || _loading || _failedMessage != null) {
      return;
    }

    final businessId = _businessId;

    if (businessId == null) {
      _showSnack('Business information is unavailable.');
      return;
    }

    var activeConversation = _conversationId;
    var invoked = false;
    final sendVersion = _loadVersion;

    setState(() {
      if (!retry) {
        _messages.add(_AngelMessage(text: message, isAngel: false));
      }

      _messageController.clear();
      _failedMessage = null;
      _thinking = true;
    });

    _scrollToBottom();

    try {
      if (activeConversation == null) {
        _newConversationId ??= const Uuid().v4();
        activeConversation = await _repository.create(
          businessId,
          _newConversationId!,
          message,
        );
        if (!mounted ||
            sendVersion != _loadVersion ||
            _supabase.auth.currentUser?.id != _ownerUserId)
          return;
        setState(() => _conversationId = activeConversation);
      }
      if (sendVersion != _loadVersion ||
          _supabase.auth.currentUser?.id != _ownerUserId)
        return;
      invoked = true;
      final response = await _supabase.functions
          .invoke(
            'angel',
            body: {
              'business_id': businessId,
              'message': message,
              'timezone_offset_minutes':
                  DateTime.now().timeZoneOffset.inMinutes,
              'conversation_id': activeConversation,
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = response.data;

      Map<String, dynamic> result;

      if (data is Map) {
        result = Map<String, dynamic>.from(data);
      } else if (data is String) {
        final decoded = jsonDecode(data);

        if (decoded is! Map) {
          throw const FormatException('Invalid Angel response.');
        }

        result = Map<String, dynamic>.from(decoded);
      } else {
        throw const FormatException('Invalid Angel response.');
      }

      if (result['success'] != true) {
        throw StateError(
          '${result['error'] ?? 'Angel could not process the message.'}',
        );
      }

      final reply = '${result['reply'] ?? ''}'.trim();

      if (reply.isEmpty) {
        throw StateError('Angel returned an empty answer.');
      }

      if (!mounted ||
          sendVersion != _loadVersion ||
          _supabase.auth.currentUser?.id != _ownerUserId)
        return;

      setState(() {
        final id = result['conversation_id'];

        if (id is String && id.isNotEmpty) {
          _conversationId = id;
        }

        _messages.add(_AngelMessage(text: reply, isAngel: true));

        _thinking = false;
      });

      _scrollToBottom();

      await _loadConversations();
    } catch (error) {
      if (!mounted ||
          sendVersion != _loadVersion ||
          _supabase.auth.currentUser?.id != _ownerUserId)
        return;

      setState(() {
        _thinking = false;
        _failedMessage = invoked ? message : null;
        if (!invoked) {
          _messages.removeLast();
          _messageController.text = message;
        }
      });

      _showSnack(
        error is TimeoutException
            ? 'Angel took too long to respond. '
                  'Please check your connection.'
            : error is FunctionException && error.status == 503
            ? 'Angel is temporarily unavailable.'
            : 'Angel could not answer right now.',
      );
    }
  }

  Future<void> _retryMessage() async {
    final id = _conversationId;
    if (id == null || _thinking) return;
    await _openConversation(id);
    if (mounted && _error == null)
      _showSnack(
        'History refreshed. No message was resent. Check the saved exchange before composing another message.',
      );
  }

  Future<void> _loadOlderMessages() async {
    final id = _conversationId;
    if (id == null || !_hasOlder || _loadingOlder || _loading || _thinking)
      return;
    final version = _loadVersion;
    setState(() => _loadingOlder = true);
    try {
      final rows = await _repository.history(
        _businessId!,
        id,
        before: _oldestMessage,
      );
      if (!mounted || version != _loadVersion) return;
      setState(() {
        if (rows.isNotEmpty) _oldestMessage = rows.last;
        _hasOlder = rows.length == 100;
        _messages.insertAll(
          0,
          rows.reversed.map(
            (row) => _AngelMessage(
              text: row['content']?.toString() ?? '',
              isAngel: row['role'] == 'assistant',
            ),
          ),
        );
      });
    } catch (_) {
      if (mounted) _showSnack('Older messages could not load. Please retry.');
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _deleteConversation(Map<String, dynamic> conversation) async {
    if (_thinking) return;

    final id = conversation['id']?.toString();
    final businessId = _businessId;
    final userId = _supabase.auth.currentUser?.id;

    if (id == null || businessId == null || userId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete conversation?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'This will permanently delete the conversation '
          'if permitted by your account.',
          style: TextStyle(color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final deleted = await _supabase
          .from('angel_conversations')
          .delete()
          .eq('id', id)
          .eq('business_id', businessId)
          .eq('user_id', userId)
          .select('id')
          .timeout(const Duration(seconds: 20));

      if (deleted.isEmpty) {
        throw StateError('Deletion not authorized.');
      }

      if (!mounted) return;

      _historyCache.remove(id);
      if (_conversationId == id) {
        ++_loadVersion;

        setState(() {
          _conversationId = null;
          _messages.clear();
          _failedMessage = null;
        });
      }

      await _loadConversations();
    } catch (_) {
      if (mounted) {
        _showSnack(
          'Unable to delete conversation. '
          'Check Supabase permissions.',
        );
      }
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _conversationTitle(Map<String, dynamic> conversation, int index) {
    final title = conversation['title'];

    if (title is String && title.trim().isNotEmpty) {
      return title.trim();
    }

    final updated = DateTime.tryParse('${conversation['updated_at']}');

    if (updated != null) {
      final date = updated.toLocal();

      return 'Chat · ${date.day}/${date.month}/${date.year}';
    }

    return 'Conversation ${index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        backgroundColor: bg,
        drawer: _buildDrawer(),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(
              child: _loading && _messages.isEmpty
                  ? Center(child: CircularProgressIndicator(color: blue))
                  : _error != null && _messages.isEmpty
                  ? _errorView()
                  : _messages.isEmpty
                  ? _welcomeScreen()
                  : _conversationView(),
            ),
            if (_hasOlder)
              TextButton(
                onPressed: _loadingOlder ? null : _loadOlderMessages,
                child: Text(
                  _loadingOlder
                      ? 'Loading older messages…'
                      : 'Load older messages',
                ),
              ),
            if (_error != null && _messages.isNotEmpty)
              TextButton(
                onPressed: _loading
                    ? null
                    : () => _openConversation(_conversationId!),
                child: Text('Refresh conversation'),
              ),
            if (_failedMessage != null) _retryBar(),
            SafeArea(top: false, child: _inputArea()),
          ],
        ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: bg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Chat history',
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        icon: Icon(Icons.menu_rounded, color: Theme.of(context).colorScheme.onSurface, size: 26),
      ),
      title: Text(
        'Angel',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'New chat',
          onPressed: _thinking ? null : _newChat,
          icon: Icon(Icons.edit_square, color: Theme.of(context).colorScheme.onSurface, size: 23),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: bg,
      width: MediaQuery.sizeOf(context).width * 0.84,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: blue, size: 25),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Angel',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _thinking ? null : _newChat,
                  icon: Icon(Icons.add_rounded, size: 19),
                  label: Text('New chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    side: BorderSide(color: border),
                    minimumSize: const Size(0, 48),
                    alignment: Alignment.centerLeft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent chats',
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh history',
                    onPressed: _loadingChats ? null : _loadConversations,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: muted,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loadingChats && _conversations.isEmpty
                  ? Center(child: CircularProgressIndicator(color: blue))
                  : _conversations.isEmpty
                  ? Center(
                      child: Text(
                        'No saved conversations yet',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: _conversations.length + (_moreChats ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _conversations.length)
                          return TextButton(
                            onPressed: _loadingChats
                                ? null
                                : () => _loadConversations(more: true),
                            child: Text('Load older chats'),
                          );
                        final chat = _conversations[index];
                        final id = '${chat['id']}';
                        final active = _conversationId == id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            color: active ? surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Icon(
                              Icons.chat_bubble_outline,
                              color: active ? blue : muted,
                              size: 19,
                            ),
                            title: Text(
                              _conversationTitle(chat, index),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: active ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Chat options',
                              icon: Icon(
                                Icons.more_horiz_rounded,
                                color: muted,
                                size: 20,
                              ),
                              onSelected: (action) {
                                if (action == 'delete') {
                                  _deleteConversation(chat);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete conversation'),
                                ),
                              ],
                            ),
                            onTap: _thinking
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _openConversation(id);
                                  },
                          ),
                        );
                      },
                    ),
            ),
            Divider(color: border),
            Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'TREXVEN Business Assistant',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: blue,
                size: 35,
              ),
            ),
            const SizedBox(height: 25),
            Text(
              "Hi! What's on your mind today?",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 23,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ask Angel about your business.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conversationView() {
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(15, 18, 15, 24),
      itemCount: _messages.length + (_thinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _thinkingBubble();
        }

        return _messageBubble(_messages[index]);
      },
    );
  }

  Widget _messageBubble(_AngelMessage message) {
    if (message.isAngel) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: blue,
                size: 17,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 7),
                    child: Text(
                      'Angel',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AngelMarkdown(data: message.text),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        margin: const EdgeInsets.only(bottom: 22),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _thinkingBubble() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(color: blue, strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text(
            'Angel is thinking...',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _retryBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: _thinking ? null : _retryMessage,
            icon: Icon(Icons.refresh_rounded, size: 17),
            label: Text('Refresh history · send outcome unknown'),
          ),
        ],
      ),
    );
  }

  Widget _inputArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: inputBg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _messageController,
              enabled: !_loading && !_thinking && _failedMessage == null,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Message Angel...',
                hintStyle: TextStyle(color: muted, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TREXVEN Angel',
                    style: TextStyle(color: muted, fontSize: 11),
                  ),
                ),
                SizedBox(
                  width: 39,
                  height: 39,
                  child: IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _loading || _thinking || _failedMessage != null
                        ? null
                        : () => _sendMessage(),
                    style: IconButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      shape: const CircleBorder(),
                    ),
                    icon: Icon(Icons.arrow_upward_rounded, size: 21),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: muted, size: 34),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _conversationId == null
                  ? _initialize
                  : () => _openConversation(_conversationId!),
              child: Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AngelMessage {
  final String text;
  final bool isAngel;

  const _AngelMessage({required this.text, required this.isAngel});
}
