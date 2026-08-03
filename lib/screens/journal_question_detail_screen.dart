import 'package:flutter/material.dart';
import '../models/journal_content.dart';

/// Full Q&A for one question. Back (top-left) is the default AppBar back
/// arrow; the top-right arrow advances to the next question in the same
/// section in place, so back always returns to the journal list.
class JournalQuestionDetailScreen extends StatefulWidget {
  final String sectionTitle;
  final List<JournalQuestion> questions;
  final int initialIndex;

  const JournalQuestionDetailScreen({
    super.key,
    required this.sectionTitle,
    required this.questions,
    required this.initialIndex,
  });

  @override
  State<JournalQuestionDetailScreen> createState() =>
      _JournalQuestionDetailScreenState();
}

class _JournalQuestionDetailScreenState
    extends State<JournalQuestionDetailScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void _next() {
    if (_index < widget.questions.length - 1) {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_index];
    final bool hasNext = _index < widget.questions.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEEEDFE),
        foregroundColor: const Color(0xFF3C3489),
        elevation: 0,
        title: Text(widget.sectionTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            tooltip: 'Next question',
            onPressed: hasNext ? _next : null,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              q.question,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3C3489),
              ),
            ),
            const SizedBox(height: 16),
            ..._buildParagraphs(q.paragraphs),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Question ${_index + 1} of ${widget.questions.length} in this section',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildParagraphs(List<String> paragraphs) {
    return paragraphs.map((p) {
      if (p.startsWith('- ')) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(color: Color(0xFF7F77DD))),
              Expanded(
                child: Text(p.substring(2),
                    style: const TextStyle(height: 1.5, fontSize: 15)),
              ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(p, style: const TextStyle(height: 1.5, fontSize: 15)),
      );
    }).toList();
  }
}
