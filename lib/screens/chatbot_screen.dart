import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/backend_config.dart';
import '../widgets/chat_infographics.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showQuickPills = true;
  bool _isTyping = false;

  static const Map<String, String> _chartTitles = {
    'cycle_phase': 'Your Cycle Phase',
    'fertile_window': 'Fertile Window',
    'symptom_trend': 'Symptom Trend',
  };

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'type': 'text',
      'text':
          'Hi! I\'m Luna, your menstrual health assistant. Ask me anything about your cycle, symptoms, or wellness.',
    },
  ];

  final List<String> _quickQuestions = [
    'Why is my period late?',
    'Best exercise for cramps?',
    'When is my fertile window?',
    'What phase am I in?',
  ];

  @override
  void initState() {
    super.initState();
    _loadGreeting();
    _loadChatHistory();
  }

  Future<void> _loadGreeting() async {
    final profile = await AuthService.getUserProfile();
    final username = profile?['username'] as String?;
    if (username != null && username.isNotEmpty && mounted) {
      setState(() {
        _messages[0]['text'] =
            'Hi $username! I\'m Luna, your menstrual health assistant. Ask me anything about your cycle, symptoms, or wellness.';
      });
    }
  }

  // ── Restore prior turns so the conversation survives app restarts ──
  Future<void> _loadChatHistory() async {
    final uid = AuthService.userId;
    if (uid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat_logs')
          .orderBy('timestamp')
          .limit(50)
          .get();
      if (snap.docs.isEmpty || !mounted) return;
      final history = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        history.add({
          'role': 'user',
          'type': 'text',
          'text': data['message'] as String? ?? '',
        });
        history.add({
          'role': 'assistant',
          'type': 'text',
          'text': data['reply'] as String? ?? '',
        });
      }
      setState(() {
        _messages.addAll(history);
        _showQuickPills = false;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Firestore chat history load error: $e');
    }
  }

  // Content sent to the backend for a prior message, whatever its rendered form was.
  String _contentForApi(Map<String, dynamic> m) {
    if (m['type'] == 'infographic') {
      return 'Displayed a ${m['chart']} infographic to the user.';
    }
    return m['text'] as String? ?? '';
  }

  // The backend owns the OpenAI key, pulls Firestore context, calls the model,
  // and writes the chat_logs entry — the app never talks to OpenAI directly.
  Future<Map<String, dynamic>> _getReply(String input) async {
    final uid = AuthService.userId;
    try {
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/chatbot'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': uid,
              'message': input,
              'history': _messages
                  .map((m) => {'role': m['role'], 'content': _contentForApi(m)})
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['type'] == 'infographic') {
          return {
            'type': 'infographic',
            'chart': data['chart'] as String,
            'data': Map<String, dynamic>.from(data['data'] as Map),
          };
        }
        return {'type': 'text', 'text': data['text'] as String? ?? ''};
      }

      String reason = 'Please try again.';
      try {
        final errorBody = jsonDecode(response.body);
        final detail = errorBody['detail'];
        if (detail is String) reason = detail;
      } catch (_) {
        // Body wasn't the expected JSON error shape — keep the generic reason.
      }
      return {
        'type': 'text',
        'text': 'Sorry, I ran into an error (${response.statusCode}): $reason',
      };
    } catch (e) {
      return {
        'type': 'text',
        'text': 'Sorry, I couldn\'t reach the chatbot service. Please check your connection and try again.',
      };
    }
  }

  void _send(String text) async {
    if (text.trim().isEmpty) return;
    final trimmed = text.trim();
    setState(() {
      _messages.add({'role': 'user', 'type': 'text', 'text': trimmed});
      _showQuickPills = false;
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    final reply = await _getReply(trimmed);

    setState(() {
      _isTyping = false;
      _messages.add({'role': 'assistant', ...reply});
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              color: const Color(0xFFEEEDFE),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F77DD),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Luna',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3C3489),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(14),
                itemCount:
                    _messages.length +
                    (_showQuickPills ? 1 : 0) +
                    (_isTyping ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i < _messages.length) {
                    final msg = _messages[i];
                    final isBot = msg['role'] == 'assistant';
                    if (msg['type'] == 'infographic') {
                      return _buildInfographicBubble(msg, isBot);
                    }
                    return _buildBubble(msg['text'] as String, isBot);
                  } else if (_showQuickPills && i == _messages.length) {
                    return _buildQuickPills();
                  } else {
                    return _buildTyping();
                  }
                },
              ),
            ),

            // Input
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: 'Ask about your health...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F5FB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _send(_controller.text),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7F77DD),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(String text, bool isBot) {
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isBot ? Colors.white : const Color(0xFF7F77DD),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isBot ? 4 : 18),
            bottomRight: Radius.circular(isBot ? 18 : 4),
          ),
          border: isBot ? Border.all(color: const Color(0xFFEEEDFE)) : null,
        ),
        child: isBot
            ? MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF333333),
                    height: 1.5,
                  ),
                  strong: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF333333),
                    height: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                  h1: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.bold,
                  ),
                  h2: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.bold,
                  ),
                  listBullet: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF333333),
                    height: 1.5,
                  ),
                  blockSpacing: 10,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
      ),
    );
  }

  Widget _buildInfographicBubble(Map<String, dynamic> msg, bool isBot) {
    final chart = msg['chart'] as String;
    final data = Map<String, dynamic>.from(msg['data'] as Map);
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isBot ? 4 : 14),
            bottomRight: Radius.circular(isBot ? 14 : 4),
          ),
          border: Border.all(color: const Color(0xFFEEEDFE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _chartTitles[chart] ?? 'Overview',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3C3489),
              ),
            ),
            const SizedBox(height: 10),
            ChatInfographic(chart: chart, data: data),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPills() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _quickQuestions.map((q) {
          return GestureDetector(
            onTap: () => _send(q),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFAFA9EC)),
              ),
              child: Text(
                q,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7F77DD)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: const Color(0xFFEEEDFE)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_dot(0), _dot(200), _dot(400)],
        ),
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder: (_, v, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFAFA9EC),
              const Color(0xFF7F77DD),
              v,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
