import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Shows the real reminders NotificationService has scheduled (period,
/// ovulation, wellness check-in, AI insight tip), mirrored into
/// users/{uid}/alerts. No mock data — an empty list here means no reminder
/// has actually fired yet.
///
/// The Firestore collection stays named `alerts` (renaming it would orphan
/// every user's existing notification history); only the UI-facing name
/// changed to Notifications.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'All';
  final List<String> _filters = ['All', 'Cycle', 'Wellness', 'Insight'];

  Color _dotColor(String tag) => switch (tag) {
    'Wellness' => const Color(0xFF378ADD),
    'Insight' => const Color(0xFFDDA627),
    _ => const Color(0xFF7F77DD),
  };

  Color _tagBg(String tag) => switch (tag) {
    'Wellness' => const Color(0xFFE6F1FB),
    'Insight' => const Color(0xFFFCF3E1),
    _ => const Color(0xFFEEEDFE),
  };

  Color _tagText(String tag) => switch (tag) {
    'Wellness' => const Color(0xFF378ADD),
    'Insight' => const Color(0xFFB98615),
    _ => const Color(0xFF3C3489),
  };

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'AM' : 'PM';
    final timeStr = '$hour12:$minute $ampm';
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return 'Today · $timeStr';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${t.day} ${months[t.month - 1]} · $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

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
                    'Notifications',
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

            // Notification list
            Expanded(
              child: uid == null
                  ? const Center(
                      child: Text(
                        'Sign in to see your notifications',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('alerts')
                          .orderBy('time', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Could not load notifications: ${snapshot.error}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        final docs = snapshot.data?.docs ?? [];
                        final filtered = _filter == 'All'
                            ? docs
                            : docs
                                  .where((d) => d.data()['tag'] == _filter)
                                  .toList();
                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text(
                              'No notifications yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.shade100,
                          ),
                          itemBuilder: (_, i) {
                            final doc = filtered[i];
                            final a = doc.data();
                            final tag = a['tag'] as String? ?? 'Cycle';
                            final read = a['read'] == true;
                            final time = (a['time'] as Timestamp?)?.toDate();

                            return GestureDetector(
                              onTap: read
                                  ? null
                                  : () => doc.reference.update({'read': true}),
                              child: Container(
                                color: read
                                    ? Colors.transparent
                                    : const Color(0xFFF0EFFE),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  14,
                                ),
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
                                          color: read
                                              ? Colors.transparent
                                              : _dotColor(tag),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a['title'] as String? ?? '',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: read
                                                  ? FontWeight.normal
                                                  : FontWeight.w600,
                                              color: const Color(0xFF2C2C2A),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            a['body'] as String? ?? '',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            time != null
                                                ? _formatTime(time)
                                                : '',
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
                                        color: _tagBg(tag),
                                        borderRadius: BorderRadius.circular(
                                          20,
                                        ),
                                      ),
                                      child: Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: _tagText(tag),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
