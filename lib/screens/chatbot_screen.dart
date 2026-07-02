import 'package:flutter/material.dart';

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

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'bot',
      'text':
          'Hi XXX! I\'m Luna, your menstrual health assistant. Ask me anything about your cycle, symptoms, or wellness.',
    },
  ];

  final Map<String, String> _replies = {
    'period late':
        'Your period can be late due to stress, sleep changes, or hormonal shifts. You\'re currently on day 26 of a 28-day cycle — still within normal range!',
    'cramp':
        'Gentle yoga and walking are best for cramps. Low-impact movement boosts blood flow and reduces prostaglandins. Check your Wellness page for today\'s full plan!',
    'fertile':
        'Based on your 28-day cycle, your fertile window is days 10–16, with peak ovulation around day 14. Your next window starts in about 2 weeks.',
    'phase':
        'You are currently in the late luteal phase (day 26). Progesterone is dropping, which may cause bloating, mood changes and fatigue. This is completely normal.',
    'symptom':
        'Common late-luteal symptoms include bloating, breast tenderness, mood swings and fatigue. Log your symptoms daily so Luna can give you more accurate predictions.',
    'exercise':
        'During the luteal phase, low-impact exercises like yoga, walking and swimming are recommended. Avoid high-intensity workouts as recovery is slower.',
  };

  final List<String> _quickQuestions = [
    'Why is my period late?',
    'Best exercise for cramps?',
    'When is my fertile window?',
    'What phase am I in?',
  ];

  String _getReply(String input) {
    final lower = input.toLowerCase();
    for (final key in _replies.keys) {
      if (lower.contains(key)) return _replies[key]!;
    }
    return 'I\'m here to help with your cycle and wellness questions. For personalised medical advice, please consult a healthcare professional.';
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text.trim()});
      _showQuickPills = false;
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 1500), () {
      setState(() {
        _isTyping = false;
        _messages.add({'role': 'bot', 'text': _getReply(text)});
      });
      _scrollToBottom();
    });
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
                    final isBot = msg['role'] == 'bot';
                    return _buildBubble(msg['text'], isBot);
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isBot ? Colors.white : const Color(0xFF7F77DD),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isBot ? 4 : 14),
            bottomRight: Radius.circular(isBot ? 14 : 4),
          ),
          border: isBot ? Border.all(color: const Color(0xFFEEEDFE)) : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isBot ? const Color(0xFF2C2C2A) : Colors.white,
            height: 1.5,
          ),
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
