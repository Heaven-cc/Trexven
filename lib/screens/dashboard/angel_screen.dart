import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AngelScreen extends StatefulWidget {
const AngelScreen({super.key});

@override
State<AngelScreen> createState() => _AngelScreenState();
}

class _AngelScreenState extends State<AngelScreen> {
final TextEditingController _messageController =
TextEditingController();

final ScrollController _scrollController =
ScrollController();

final List<_AngelMessage> _messages = [];

bool _isListening = false;
bool _isThinking = false;

final SupabaseClient _supabase =
Supabase.instance.client;

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

if (text.isEmpty || _isThinking) {
return;
}

// Add user's message immediately.
setState(() {
_messages.add(
_AngelMessage(
text: text,
isAngel: false,
),
);

_messageController.clear();
_isThinking = true;
});

_scrollToBottom();

try {
/*
        Flutter
            ↓
        Supabase Edge Function: angel
            ↓
        Groq API
            ↓
        Angel
            ↓
        Response
            ↓
        Flutter
      */

final response = await _supabase.functions.invoke(
'angel',
body: {
'message': text,
'conversation': _messages
    .map(
(message) => {
'role':
message.isAngel ? 'assistant' : 'user',
'content': message.text,
},
)
    .toList(),
},
);

if (!mounted) return;

final data = response.data;

if (data == null) {
throw Exception(
'Angel returned an empty response.',
);
}

Map<String, dynamic> result;

if (data is Map<String, dynamic>) {
result = data;
} else if (data is Map) {
result = Map<String, dynamic>.from(data);
} else if (data is String) {
result = jsonDecode(data);
} else {
throw Exception(
'Invalid response from Angel.',
);
}

if (result['success'] != true) {
throw Exception(
result['error']?.toString() ??
'Angel could not process your request.',
);
}

final answer =
result['reply']?.toString().trim();

if (answer == null || answer.isEmpty) {
throw Exception(
'Angel returned an empty answer.',
);
}

setState(() {
_messages.add(
_AngelMessage(
text: answer,
isAngel: true,
),
);

_isThinking = false;
});

_scrollToBottom();
} catch (error) {
if (!mounted) return;

setState(() {
_isThinking = false;
});

_showError(
'Angel could not connect right now.\n\n$error',
);
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

void _toggleListening() {
setState(() {
_isListening = !_isListening;
});

if (_isListening) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Voice input is ready to be connected.',
),
behavior: SnackBarBehavior.floating,
),
);
}
}

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
duration:
const Duration(milliseconds: 300),
curve: Curves.easeOut,
);
});
}

// ============================================================
// BUILD
// ============================================================

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor:
const Color(0xFFF8FAFC),

appBar: AppBar(
backgroundColor:
const Color(0xFFF8FAFC),
elevation: 0,
surfaceTintColor:
Colors.transparent,

leading: IconButton(
icon: const Icon(
Icons.arrow_back_rounded,
color: Color(0xFF0F172A),
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
color:
const Color(0xFFEFF6FF),
borderRadius:
BorderRadius.circular(12),
),
child: const Icon(
Icons.auto_awesome,
color:
Color(0xFF2563EB),
size: 20,
),
),

const SizedBox(width: 11),

const Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
'Angel',
style: TextStyle(
fontSize: 17,
fontWeight:
FontWeight.w800,
color:
Color(0xFF0F172A),
),
),

SizedBox(height: 1),

Text(
'Business intelligence',
style: TextStyle(
fontSize: 11,
color:
Color(0xFF64748B),
),
),
],
),
],
),
),

body: Column(
children: [
Expanded(
child: ListView.builder(
controller:
_scrollController,
padding:
const EdgeInsets.fromLTRB(
18,
15,
18,
20,
),
itemCount:
_messages.length +
(_isThinking ? 1 : 0),
itemBuilder:
(context, index) {
if (_isThinking &&
index ==
_messages.length) {
return
_buildThinkingBubble();
}

return _buildMessage(
_messages[index],
);
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

Widget _buildMessage(
_AngelMessage message,
) {
return Align(
alignment: message.isAngel
? Alignment.centerLeft
    : Alignment.centerRight,

child: Container(
constraints:
BoxConstraints(
maxWidth:
MediaQuery.of(context)
    .size
    .width *
.82,
),

margin:
const EdgeInsets.only(
bottom: 12,
),

padding:
const EdgeInsets.symmetric(
horizontal: 15,
vertical: 12,
),

decoration:
BoxDecoration(
color: message.isAngel
? Colors.white
    : const Color(0xFF2563EB),

borderRadius:
BorderRadius.only(
topLeft:
const Radius.circular(18),
topRight:
const Radius.circular(18),

bottomLeft:
Radius.circular(
message.isAngel
? 4
    : 18,
),

bottomRight:
Radius.circular(
message.isAngel
? 18
    : 4,
),
),

border: message.isAngel
? Border.all(
color:
const Color(
0xFFE2E8F0),
)
    : null,
),

child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
if (message.isAngel)
const Padding(
padding:
EdgeInsets.only(
bottom: 5,
),
child: Text(
'ANGEL',
style: TextStyle(
fontSize: 10,
fontWeight:
FontWeight.w800,
letterSpacing: .8,
color:
Color(0xFF2563EB),
),
),
),

Text(
message.text,
style: TextStyle(
fontSize: 14,
height: 1.45,
color: message.isAngel
? const Color(
0xFF334155)
    : Colors.white,
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
return Align(
alignment:
Alignment.centerLeft,

child: Container(
margin:
const EdgeInsets.only(
bottom: 12,
),

padding:
const EdgeInsets.symmetric(
horizontal: 17,
vertical: 14,
),

decoration:
BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(17),
border: Border.all(
color:
const Color(0xFFE2E8F0),
),
),

child: const Row(
mainAxisSize:
MainAxisSize.min,
children: [
SizedBox(
width: 16,
height: 16,
child:
CircularProgressIndicator(
strokeWidth: 2,
color:
Color(0xFF2563EB),
),
),

SizedBox(width: 10),

Text(
'Angel is thinking...',
style: TextStyle(
fontSize: 12,
color:
Color(0xFF64748B),
),
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
scrollDirection:
Axis.horizontal,

padding:
const EdgeInsets.symmetric(
horizontal: 18,
),

children: [
_suggestion(
'How are sales today?',
),

_suggestion(
'Check my stock',
),

_suggestion(
'Any unusual activity?',
),

_suggestion(
'What happened today?',
),
],
),
);
}

Widget _suggestion(
String text,
) {
return GestureDetector(
onTap: () {
_messageController.text =
text;

_sendMessage();
},

child: Container(
margin:
const EdgeInsets.only(
right: 8,
bottom: 8,
),

padding:
const EdgeInsets.symmetric(
horizontal: 13,
vertical: 8,
),

decoration:
BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(20),
border: Border.all(
color:
const Color(0xFFE2E8F0),
),
),

child: Text(
text,
style: const TextStyle(
fontSize: 11,
fontWeight:
FontWeight.w600,
color:
Color(0xFF475569),
),
),
),
);
}

// ============================================================
// INPUT
// ============================================================

Widget _buildInputArea() {
return Container(
padding:
const EdgeInsets.fromLTRB(
14,
10,
14,
14,
),

decoration:
const BoxDecoration(
color: Colors.white,

border: Border(
top: BorderSide(
color:
Color(0xFFE2E8F0),
),
),
),

child: Row(
crossAxisAlignment:
CrossAxisAlignment.end,
children: [
Expanded(
child: Container(
decoration:
BoxDecoration(
color:
const Color(
0xFFF8FAFC),
borderRadius:
BorderRadius.circular(
17),
border: Border.all(
color:
const Color(
0xFFE2E8F0),
),
),

child: TextField(
controller:
_messageController,

minLines: 1,
maxLines: 5,

textInputAction:
TextInputAction.newline,

decoration:
const InputDecoration(
hintText:
'Message Angel...',

hintStyle:
TextStyle(
color:
Color(0xFF94A3B8),
fontSize: 14,
),

border:
InputBorder.none,

contentPadding:
EdgeInsets.symmetric(
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
onTap:
_toggleListening,

child: Container(
width: 48,
height: 48,

decoration:
BoxDecoration(
color: _isListening
? const Color(
0xFF0F172A)
    : const Color(
0xFFF1F5F9),

shape:
BoxShape.circle,
),

child: Icon(
_isListening
? Icons.mic_rounded
    : Icons.mic_none_rounded,

color: _isListening
? Colors.white
    : const Color(
0xFF334155),

size: 22,
),
),
),

const SizedBox(width: 8),

GestureDetector(
onTap:
_sendMessage,

child: Container(
width: 48,
height: 48,

decoration:
const BoxDecoration(
color:
Color(0xFF2563EB),
shape:
BoxShape.circle,
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

const _AngelMessage({
required this.text,
required this.isAngel,
});
}