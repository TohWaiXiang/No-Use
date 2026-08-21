import 'package:flutter/material.dart';
import '../models/journal_content.dart';
import 'journal_question_detail_screen.dart';

/// Journal home: each section renders as a small bordered card with the
/// section name bold at the top, expanding to a list of question tiles.
/// Tapping a question opens the full Q&A; the detail screen's back arrow
/// returns here.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'Journal',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3C3489),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Period education, answered.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            for (final group in journalGroups) ..._buildGroup(context, group),
            const SizedBox(height: 8),
            _safetyBanner(),
          ],
        ),
      ),
    );
  }

  Widget _safetyBanner() {
    return Card(
      color: const Color(0xFFFBEAEA),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFF3D2D2)),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFC0392B)),
        title: const Text(
          'Seek urgent care if…',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC0392B)),
        ),
        collapsedIconColor: const Color(0xFFC0392B),
        iconColor: const Color(0xFFC0392B),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: journalUrgentSigns
                  .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ', style: TextStyle(color: Color(0xFFC0392B))),
                            Expanded(child: Text(s, style: const TextStyle(height: 1.4))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroup(BuildContext context, JournalGroup group) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
        child: Text(
          'GROUP ${group.id} — ${group.title.toUpperCase()}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: Colors.grey,
          ),
        ),
      ),
      for (final section in group.sections) _sectionCard(context, section),
    ];
  }

  Widget _sectionCard(BuildContext context, JournalSection section) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEEEDFE)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          section.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF3C3489),
          ),
        ),
        subtitle: Text(
          '${section.questions.length} questions',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        childrenPadding: EdgeInsets.zero,
        children: [
          for (int i = 0; i < section.questions.length; i++)
            _questionTile(context, section, i),
        ],
      ),
    );
  }

  Widget _questionTile(BuildContext context, JournalSection section, int i) {
    final q = section.questions[i];
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      title: Text(q.question, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JournalQuestionDetailScreen(
            sectionTitle: section.title,
            questions: section.questions,
            initialIndex: i,
          ),
        ),
      ),
    );
  }
}
