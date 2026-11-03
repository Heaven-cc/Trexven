import 'package:trexven_operations/trexven_operations.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
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
  Color get ink => Theme.of(context).colorScheme.onSurface;
  Color get userBubble => blue.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .25 : .12);

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
  String? _sendError;

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
        _sendError = null;
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
      _sendError = null;
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
      _sendError = null;
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
        _sendError = error is TimeoutException
            ? 'Angel took too long to respond.'
            : error is FunctionException
                ? CustomerPresentation.angelError(error.status)
                : 'Angel could not answer right now.';
        if (!invoked) {
          _messages.removeLast();
          _messageController.text = message;
        }
      });

      if (!invoked) _showSnack(_sendError!);
    }
  }

  Future<void> _retryMessage() async {
    final id = _conversationId;
    if (id == null || _thinking) return;
    await _openConversation(id);
    if (mounted && _error == null) {
      _showSnack('History refreshed. No message was resent.');
    }
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
        _sendError = null;
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
      resizeToAvoidBottomInset: true,
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _loading && _messages.isEmpty
                ? _chatSkeleton()
                : _error != null && _messages.isEmpty
                    ? _errorView()
                    : _messages.isEmpty
                        ? _welcomeScreen()
                        : _conversationView(),
          ),
          if (_hasOlder)
            TextButton(
              onPressed: _loadingOlder ? null : _loadOlderMessages,
              child: Text(_loadingOlder ? 'Loading older messages…' : 'Load older messages'),
            ),
          if (_error != null && _messages.isNotEmpty)
            TextButton(
              onPressed: _loading || _conversationId == null ? null : () => _openConversation(_conversationId!),
              child: const Text('Refresh conversation'),
            ),
          if (_failedMessage != null) _retryBar(),
          SafeArea(top: false, child: _inputArea()),
        ],
      ),
    );
  }

  Widget _chatSkeleton() {
    return Padding(
      padding: TrexvenSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TrexvenSkeletonBlock(width: 90, height: 12),
          const SizedBox(height: TrexvenSpacing.fieldGap),
          const TrexvenSkeletonBlock(width: 245, height: 60),
          const SizedBox(height: TrexvenSpacing.fieldGap),
          Align(
            alignment: Alignment.centerRight,
            child: const TrexvenSkeletonBlock(width: 170, height: 50),
          ),
        ],
      ),
    );
  }

    PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: bg,
      toolbarHeight: 68,
      leading: IconButton(
        tooltip: 'Chat history',
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        icon: const Icon(Icons.view_sidebar_outlined),
      ),
      titleSpacing: 4,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: blue.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(TrexvenRadii.field),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: blue, size: 19),
          ),
          const SizedBox(width: TrexvenSpacing.labelGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Angel', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text('Your business assistant',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: muted)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'New chat',
          onPressed: _thinking ? null : _newChat,
          icon: const Icon(Icons.edit_square_outlined),
        ),
        const SizedBox(width: TrexvenSpacing.labelGap),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: border.withValues(alpha: .4)),
      ),
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
                  ? Center(child: Text('Please wait…'))
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
                'Your business assistant',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeScreen() {
    final theme = Theme.of(context);
    final suggestions = <(IconData, String)>[
      (Icons.bar_chart_rounded, "Summarize today's sales"),
      (Icons.inventory_2_outlined, 'Show low-stock products'),
      (Icons.insights_outlined, 'Review recent activity'),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        padding: TrexvenSpacing.pagePadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight > 24 ? constraints.maxHeight - 24 : 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(TrexvenRadii.card),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: blue, size: 27),
              ),
              const SizedBox(height: TrexvenSpacing.fieldGap),
              Text('What can I help with?', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: TrexvenSpacing.labelGap),
              Text('Ask about sales, inventory, expenses or business activity.',
                  textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
              const SizedBox(height: TrexvenSpacing.sectionGap),
              for (final suggestion in suggestions) ...[
                Material(
                  color: inputBg.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(TrexvenRadii.field),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(TrexvenRadii.field),
                    onTap: _loading || _thinking ? null : () => _sendMessage(preset: suggestion.$2),
                    child: Padding(
                      padding: TrexvenSpacing.fieldPadding,
                      child: Row(
                        children: [
                          Icon(suggestion.$1, color: blue, size: 19),
                          const SizedBox(width: TrexvenSpacing.labelGap),
                          Expanded(child: Text(suggestion.$2, style: theme.textTheme.bodyMedium)),
                          Icon(Icons.north_west_rounded, color: muted, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: TrexvenSpacing.labelGap),
              ],
            ],
          ),
        ),
      );
    });
  }

    Widget _conversationView() {
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _messages.length + (_thinking ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) return _thinkingBubble();
        return _messageBubble(_messages[index]);
      },
    );
  }

    Widget _messageBubble(_AngelMessage message) {
    final theme = Theme.of(context);
    if (message.isAngel) {
      return Padding(
        padding: const EdgeInsets.only(bottom: TrexvenSpacing.fieldGap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: blue.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(TrexvenRadii.status),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: blue, size: 16),
            ),
            const SizedBox(width: TrexvenSpacing.labelGap),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(TrexvenRadii.card),
                  border: Border.all(color: border.withValues(alpha: .32)),
                ),
                child: AngelMarkdown(data: message.text),
              ),
            ),
          ],
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .80),
        margin: const EdgeInsets.only(bottom: TrexvenSpacing.fieldGap),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: userBubble,
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        child: SelectableText(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(color: ink),
        ),
      ),
    );
  }

    Widget _thinkingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: TrexvenSpacing.fieldGap),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: blue, size: 18),
          const SizedBox(width: TrexvenSpacing.labelGap),
          Text('Angel is thinking…', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

    Widget _retryBar() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
          border: Border.all(color: theme.colorScheme.error.withValues(alpha: .28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 18),
                const SizedBox(width: TrexvenSpacing.labelGap),
                Expanded(child: Text('Response unavailable',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: TrexvenSpacing.labelGap),
            Text(
              '${_sendError ?? 'Angel could not respond.'} Your message may have been saved. Check the conversation before sending again.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: TrexvenSpacing.labelGap),
            TextButton.icon(
              onPressed: _thinking || _loading ? null : _retryMessage,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh history'),
            ),
          ],
        ),
      ),
    );
  }

    Widget _inputArea() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(TrexvenRadii.dialog),
              border: Border.all(color: border.withValues(alpha: .65)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_loading && !_thinking && _failedMessage == null,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Message Angel...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(color: muted),
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: TrexvenSpacing.labelGap),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton.filled(
                      tooltip: 'Send message',
                      onPressed: _loading || _thinking || _failedMessage != null ? null : () => _sendMessage(),
                      style: IconButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(40, 40),
                      ),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('Review important actions before confirming.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: muted)),
        ],
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
