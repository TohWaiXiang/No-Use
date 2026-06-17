import 'package:flutter/material.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'All';
  final List<String> _filters = ['All', 'Cycle', 'Wellness', 'Insight'];

  final List<Map<String, dynamic>> _alerts = [
    {
      'title': 'Period starting soon',
      'body':
          'Your period is estimated to begin in 2 days. Stock up on supplies and take it easy.',
      'time': 'Today · 8:00 AM',
      'tag': 'Cycle',
      'dotColor': Color(0xFF7F77DD),
      'tagBg': Color(0xFFEEEDFE),
      'tagText': Color(0xFF3C3489),
      'read': false,
    },
    {
      'title': 'Wellness reminder',
      'body':
          'You haven\'t logged your exercise today. Gentle yoga is recommended for your phase.',
      'time': 'Today · 7:30 AM',
      'tag': 'Wellness',
      'dotColor': Color(0xFF378ADD),
      'tagBg': Color(0xFFE6F1FB),
      'tagText': Color(0xFF0C447C),
      'read': false,
    },
    {
      'title': 'Log your symptoms',
      'body':
          'Tracking daily symptoms helps Luna give you more accurate cycle predictions.',
      'time': 'Yesterday · 9:00 AM',
      'tag': 'Insight',
      'dotColor': Color(0xFF97C459),
      'tagBg': Color(0xFFEAF3DE),
      'tagText': Color(0xFF27500A),
      'read': true,
    },
    {
      'title': 'Ovulation window closing',
      'body':
          'Your fertile window ends tomorrow. Ovulation was predicted around day 14.',
      'time': '3 days ago · 8:00 AM',
      'tag': 'Cycle',
      'dotColor': Color(0xFF7F77DD),
      'tagBg': Color(0xFFEEEDFE),
      'tagText': Color(0xFF3C3489),
      'read': true,
    },
    {
      'title': 'Weekly exercise summary',
      'body':
          'You completed 2 of 4 workouts this week. Keep it up — you\'re doing great!',
      'time': '4 days ago · 6:00 PM',
      'tag': 'Wellness',
      'dotColor': Color(0xFF378ADD),
      'tagBg': Color(0xFFE6F1FB),
      'tagText': Color(0xFF0C447C),
      'read': true,
    },
    {
      'title': 'New AI insight available',
      'body':
          'Luna has a new personalised insight based on your recent symptom logs.',
      'time': '5 days ago · 10:00 AM',
      'tag': 'Insight',
      'dotColor': Color(0xFF97C459),
      'tagBg': Color(0xFFEAF3DE),
      'tagText': Color(0xFF27500A),
      'read': true,
    },
  ];

  List<Map<String, dynamic>> get _filtered => _filter == 'All'
      ? _alerts
      : _alerts.where((a) => a['tag'] == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              color: const Color(0xFFEEEDFE),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alerts',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3C3489),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Reminders & health notifications',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) {
                        final active = _filter == f;
                        return GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFF7F77DD)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active
                                    ? const Color(0xFF7F77DD)
                                    : const Color(0xFFEEEDFE),
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: active ? Colors.white : Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Alert list
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final a = _filtered[i];
                  return GestureDetector(
                    onTap: () => setState(() => a['read'] = true),
                    child: Container(
                      color: a['read']
                          ? Colors.transparent
                          : const Color(0xFFF0EFFE),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dot
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: a['read']
                                    ? Colors.transparent
                                    : a['dotColor'],
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a['title'],
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: a['read']
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                    color: const Color(0xFF2C2C2A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  a['body'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  a['time'],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Tag badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: a['tagBg'],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              a['tag'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: a['tagText'],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
