import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles the yoga journey's XP/level/streak state in Firestore.
///
/// Schema (users/{uid}):
///   yoga_level        int    — highest level the user has unlocked (starts at 1)
///   completed_levels  List   — ids of every level ever completed (levels can be
///                              replayed via phase recommendations without
///                              re-unlocking anything)
///   xp                int    — total XP earned
///   badges            List   — badge ids earned
///   streak_count      int    — consecutive days with a completed level
///   streak_last_date  String — yyyy-MM-dd of the last day a level was completed
class GamificationService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Marks [levelId] as completed for the current user.
  ///
  /// - Only advances `yoga_level` (unlocks the next level) when [levelId] is
  ///   the current frontier level — replaying an earlier level via a phase
  ///   recommendation still awards XP but never re-locks/unlocks anything.
  /// - [isMenstrualPhase] pauses (rather than resets) the streak on a gap day,
  ///   so a missed day during a painful period doesn't punish the user.
  ///
  /// Returns the updated `{yoga_level, xp, streak_count, unlocked_next, completed_levels, badges}`.
  static Future<Map<String, dynamic>> completeLevel({
    required int levelId,
    required int xpReward,
    bool isMenstrualPhase = false,
    String? badgeId,
  }) async {
    final uid = _uid;
    if (uid.isEmpty) {
      return {'success': false, 'error': 'Not signed in.'};
    }

    final docRef = _db.collection('users').doc(uid);
    final today = _dateKey(DateTime.now());

    try {
      final result = await _db.runTransaction<Map<String, dynamic>>((
        txn,
      ) async {
        final snapshot = await txn.get(docRef);
        final data = snapshot.data() ?? {};

        final completedLevels = List<int>.from(data['completed_levels'] ?? []);
        final yogaLevel = (data['yoga_level'] as int?) ?? 1;
        final xp = (data['xp'] as int?) ?? 0;
        final badges = List<String>.from(data['badges'] ?? []);
        final streakCount = (data['streak_count'] as int?) ?? 0;
        final streakLastDate = data['streak_last_date'] as String?;

        final alreadyCompleted = completedLevels.contains(levelId);
        final update = <String, dynamic>{};

        // XP and completion history — awarded once per level.
        if (!alreadyCompleted) {
          completedLevels.add(levelId);
          update['completed_levels'] = completedLevels;
          update['xp'] = xp + xpReward;
        }

        // Sequential unlock: only advance if this was the current frontier.
        final unlockedNext = !alreadyCompleted && levelId == yogaLevel;
        if (unlockedNext) {
          update['yoga_level'] = yogaLevel + 1;
        }

        if (badgeId != null && !badges.contains(badgeId)) {
          badges.add(badgeId);
          update['badges'] = badges;
        }

        // Streak: increment on a new day, hold steady mid-period phase,
        // reset only on a genuine gap outside menstrual phase.
        int newStreak = streakCount;
        if (streakLastDate == today) {
          // Already logged today — no change.
        } else if (streakLastDate == _dateKey(DateTime.now().subtract(const Duration(days: 1)))) {
          newStreak = streakCount + 1;
        } else if (streakLastDate == null) {
          newStreak = 1;
        } else if (isMenstrualPhase) {
          // Gap during menstrual phase: hold the streak rather than reset it.
          newStreak = streakCount == 0 ? 1 : streakCount;
        } else {
          newStreak = 1;
        }
        update['streak_count'] = newStreak;
        update['streak_last_date'] = today;

        txn.set(docRef, update, SetOptions(merge: true));

        return {
          'yoga_level': update['yoga_level'] ?? yogaLevel,
          'xp': update['xp'] ?? xp,
          'streak_count': newStreak,
          'unlocked_next': unlockedNext,
          'completed_levels': update['completed_levels'] ?? completedLevels,
          'badges': update['badges'] ?? badges,
          'already_completed': alreadyCompleted,
        };
      });

      return {'success': true, ...result};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Reads the current gamification state without mutating anything.
  static Future<Map<String, dynamic>> getState() async {
    final uid = _uid;
    if (uid.isEmpty) return _defaultState();

    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return _defaultState();

    return {
      'yoga_level': data['yoga_level'] ?? 1,
      'xp': data['xp'] ?? 0,
      'streak_count': data['streak_count'] ?? 0,
      'completed_levels': List<int>.from(data['completed_levels'] ?? []),
      'badges': List<String>.from(data['badges'] ?? []),
    };
  }

  static Map<String, dynamic> _defaultState() => {
    'yoga_level': 1,
    'xp': 0,
    'streak_count': 0,
    'completed_levels': <int>[],
    'badges': <String>[],
  };

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
