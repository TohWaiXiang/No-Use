import 'package:flutter/material.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  int? _expandedIndex;

  final List<Map<String, dynamic>> _exercises = [
    {
      'icon': Icons.self_improvement,
      'name': 'Gentle Yoga',
      'meta': '20 min · Reduces bloating & cramps',
      'badge': 'Easy',
      'badgeColor': Color(0xFFE6F1FB),
      'badgeText': Color(0xFF0C447C),
      'detail':
          'Hip-opening poses and deep breathing to ease late-luteal tension. Includes child\'s pose, cat-cow and supine twist.',
      'tip': 'Best done in the morning before breakfast.',
    },
    {
      'icon': Icons.directions_walk,
      'name': 'Brisk Walking',
      'meta': '30 min · Boosts mood & circulation',
      'badge': 'Easy',
      'badgeColor': Color(0xFFE6F1FB),
      'badgeText': Color(0xFF0C447C),
      'detail':
          'A steady-pace walk helps regulate cortisol and serotonin during the luteal phase. Avoid high-incline terrain.',
      'tip': 'Pair with calming music for best effect.',
    },
    {
      'icon': Icons.pool,
      'name': 'Light Swimming',
      'meta': '25 min · Low-impact full body',
      'badge': 'Moderate',
      'badgeColor': Color(0xFFFAEEDA),
      'badgeText': Color(0xFF633806),
      'detail':
          'Water resistance reduces joint strain. Focus on gentle freestyle or breaststroke laps.',
      'tip': 'A warm shower afterward helps relax uterine muscles.',
    },
    {
      'icon': Icons.fitness_center,
      'name': 'Strength Training',
      'meta': '40 min · Not recommended today',
      'badge': 'Avoid',
      'badgeColor': Color(0xFFEEEDFE),
      'badgeText': Color(0xFF3C3489),
      'detail':
          'High-intensity lifting is not advised during the late luteal phase — recovery ability is reduced.',
      'tip': 'Schedule this for your follicular phase (days 1–13).',
    },
  ];

  final List<Map<String, dynamic>> _progress = [
    //database
    {'day': 'Mon', 'pct': 1.0, 'done': true},
    {'day': 'Tue', 'pct': 1.0, 'done': true},
    {'day': 'Wed', 'pct': 0.6, 'done': false},
    {'day': 'Thu', 'pct': 0.0, 'done': false},
    {'day': 'Fri', 'pct': 0.0, 'done': false},
    {'day': 'Sat', 'pct': 0.0, 'done': false},
    {'day': 'Sun', 'pct': 0.0, 'done': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                color: const Color(0xFFEEEDFE),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wellness Exercise',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3C3489),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Recommended for your cycle phase',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF378ADD),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        '◆  Late Luteal Phase · Day 26', //change
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Weekly progress
                    const Text(
                      'WEEKLY PROGRESS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEEEDFE)),
                      ),
                      child: Column(
                        children: _progress.map((p) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    p['day'],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: p['pct'],
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFFF4F5FB),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Color(0xFF7F77DD),
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    p['done']
                                        ? 'Done'
                                        : p['pct'] == 0.0
                                        ? '—'
                                        : '60%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: p['done']
                                          ? const Color(0xFF7F77DD)
                                          : Colors.grey,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Recommended exercises
                    const Text(
                      'RECOMMENDED FOR TODAY',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_exercises.length, (i) {
                      final ex = _exercises[i];
                      final isOpen = _expandedIndex == i;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _expandedIndex = isOpen ? null : i),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? const Color(0xFFEEEDFE)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isOpen
                                  ? const Color(0xFF7F77DD)
                                  : const Color(0xFFEEEDFE),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEEDFE),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      ex['icon'],
                                      color: const Color(0xFF7F77DD),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ex['name'],
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2C2C2A),
                                          ),
                                        ),
                                        Text(
                                          ex['meta'],
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ex['badgeColor'],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      ex['badge'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: ex['badgeText'],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isOpen) ...[
                                const SizedBox(height: 10),
                                Divider(height: 1, color: Colors.grey.shade200),
                                const SizedBox(height: 10),
                                Text(
                                  ex['detail'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.lightbulb_outline,
                                      size: 13,
                                      color: Color(0xFF7F77DD),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'AI tip: ${ex['tip']}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF3C3489),
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 8),
                    // AI tip strip
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F1FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '💡 Why these? Low-impact movement supports hormonal balance and reduces PMS symptoms during your current luteal phase.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0C447C),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
