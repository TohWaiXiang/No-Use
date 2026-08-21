import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/gamification_service.dart';
import '../services/backend_config.dart';
import 'yoga_level_detail_screen.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key});

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  int unlockedLevel = 1;
  int xp = 0;
  int streakCount = 0;
  List<int> completedLevels = [];
  bool isLoading = true;
  String currentPhase = '—';
  int? stressLevel; // 0-5, from the profile's onboarding check-in.
  String? wellnessPlan;
  bool loadingWellnessPlan = false;
  bool wellnessPlanError = false;

  // Yoga levels are one pose each, but `durationMinutes` is total session
  // time, not one continuous hold — `guide` spells out the actual
  // hold/repeat pattern so a level never reads as "hold Cobra for 8
  // minutes straight". `apiPoseId` looks the pose up on the public Yoga API
  // (github.com/alexcumplido/yoga-api) for a reference image/benefits;
  // null for poses outside that API's 48-pose catalog (Cobra and
  // Legs-Up-the-Wall), which fall back to the steps below only.
  //
  // `energyTag` + `recommendedFor` are deliberately soft, non-medical
  // framing ("Low energy or mild discomfort") rather than a hard
  // phase-to-pose prescription — see _energyLevel below for how "today's
  // recommendation" is actually derived.
  final List<Map<String, dynamic>> yogaLevels = [
    {
      'level': 1,
      'title': "Child's Pose",
      'durationMinutes': 5,
      'goal': 'Calm the mind and ease everyday stress',
      'guide': 'Rest here for 1–3 minutes, breathing deeply.',
      'category': 'Restorative',
      'energyTag': 'low',
      'recommendedFor': 'Low energy or feeling overwhelmed',
      'apiPoseId': 10,
      'youtubeId': 'eqVMAPM00DM',
      'steps': [
        'Kneel on the mat with big toes touching, then sit back onto your heels.',
        'Separate your knees about hip-width apart and fold forward, resting your torso between your thighs.',
        'Extend your arms forward or rest them alongside your body, palms up.',
        'Rest your forehead on the mat and breathe slowly and deeply.',
        'Stay here, letting your back and shoulders soften with every exhale.',
      ],
    },
    {
      'level': 2,
      'title': 'Cat-Cow',
      'durationMinutes': 6,
      'goal': 'Warm up the spine and release tension',
      'guide': 'Flow slowly for 8–10 rounds, moving with your breath.',
      'category': 'Gentle movement',
      'energyTag': 'medium',
      'recommendedFor': 'Mild stiffness or moderate energy',
      'apiPoseId': 7,
      'youtubeId': 'y39PrKY_4JM',
      'steps': [
        'Come onto your hands and knees in a tabletop position, wrists under shoulders and knees under hips.',
        'Inhale, drop your belly, lift your chest and tailbone for Cow pose.',
        'Exhale, round your spine toward the ceiling and tuck your chin for Cat pose.',
        'Continue flowing between Cow and Cat, moving with your breath.',
        'Return to a neutral spine and pause, noticing the ease in your back.',
      ],
    },
    {
      'level': 3,
      'title': 'Butterfly Pose',
      'durationMinutes': 8,
      'goal': 'Gently open the hips for comfort',
      'guide': "Hold 1–2 minutes, release, repeat if you'd like.",
      'category': 'Gentle movement',
      'energyTag': 'low',
      'recommendedFor': 'Low energy or mild menstrual discomfort',
      'apiPoseId': 5,
      'youtubeId': 'SN9oQCE1zMs',
      'steps': [
        'Sit with your spine tall and bring the soles of your feet together in front of you.',
        'Let your knees drop out to the sides toward the floor.',
        'Hold your feet or ankles, gently pressing your knees down with your forearms if comfortable.',
        'Keep your spine long rather than rounding forward.',
        'Breathe steadily, allowing your hips and inner thighs to soften.',
      ],
    },
    {
      'level': 4,
      'title': 'Cobra Pose',
      'durationMinutes': 8,
      'goal': 'Stretch the front body and relieve stress',
      'guide': 'Hold 15–30 seconds, then release. Repeat 2–3 times.',
      'category': 'Energizing',
      'energyTag': 'high',
      'recommendedFor': 'Higher energy or wanting an active stretch',
      'apiPoseId': null,
      'youtubeId': 'n6jrC6WeF84',
      'steps': [
        'Lie face down with your legs extended and the tops of your feet on the mat.',
        'Place your palms under your shoulders, elbows hugging into your sides.',
        'Press into your hands and lift your chest, keeping your lower ribs on the mat.',
        'Draw your shoulders back and down, away from your ears.',
        'Hold for 15–30 seconds, breathing steadily, then lower back down slowly.',
        'Rest for a few breaths, then repeat 2–3 times.',
      ],
    },
    {
      'level': 5,
      'title': 'Legs-Up-the-Wall',
      'durationMinutes': 10,
      'goal': 'Support deep relaxation and restful sleep',
      'guide': 'Rest here for 5–10 minutes, breathing slowly.',
      'category': 'Restorative',
      'energyTag': 'low',
      'recommendedFor': 'Winding down or trouble sleeping',
      'apiPoseId': null,
      'youtubeId': 'xmcDj4Bf--0',
      'steps': [
        'Sit sideways next to a wall, then swing your legs up as you lie back.',
        'Scoot your hips as close to the wall as is comfortable.',
        'Let your legs rest against the wall, arms relaxed by your sides, palms up.',
        'Close your eyes and breathe slowly, letting your body settle.',
        'Stay for several minutes, then bend your knees and roll gently to one side to come up.',
      ],
    },
    {
      'level': 6,
      'title': 'Seated Forward Bend',
      'durationMinutes': 8,
      'goal': 'Stretch the back and hamstrings while calming the mind',
      'guide': "Hold 1–2 minutes, release, repeat if you'd like.",
      'category': 'Gentle movement',
      'energyTag': 'low',
      'recommendedFor': 'Low energy or lower back tension',
      'apiPoseId': 30,
      'youtubeId': 'Xn1wigQSrmI',
      'steps': [
        'Sit with your legs extended straight in front of you.',
        'Inhale and lengthen your spine tall.',
        'Exhale and hinge forward from your hips, reaching toward your feet.',
        'Hold wherever feels comfortable — shins, ankles, or feet — without forcing.',
        'Breathe steadily, releasing tension in your lower back with each exhale.',
      ],
    },
    {
      'level': 7,
      'title': 'Corpse Pose',
      'durationMinutes': 8,
      'goal': 'Rest and reset before finishing your practice',
      'guide': 'Lie still for 5–8 minutes, breathing naturally.',
      'category': 'Restorative',
      'energyTag': 'low',
      'recommendedFor': 'Very low energy or needing deep rest',
      'apiPoseId': 11,
      'youtubeId': '7MViudowD60',
      'steps': [
        'Lie flat on your back with legs extended and slightly apart, feet falling open.',
        'Rest your arms alongside your body, palms facing up.',
        'Close your eyes and let your whole body go heavy against the mat.',
        'Let your breath settle into a slow, natural rhythm.',
        'Stay here for several minutes, releasing tension with each exhale.',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    loadProgress();
  }

  bool get _isMenstrualPhase => currentPhase == 'Menstrual';

  /// Today's suggested energy level ('low'/'medium'/'high'), used only to
  /// highlight one already-unlocked level as "Recommended today" — never to
  /// gate access. Combines the predicted cycle phase with reported stress
  /// (from onboarding) rather than treating phase as the sole signal, since
  /// there's no clinical basis for "phase X requires pose Y".
  String get _energyLevel {
    if (currentPhase == 'Menstrual') return 'low';
    if ((stressLevel ?? 0) >= 3) return 'low';
    if (currentPhase == 'Follicular' || currentPhase == 'Ovulation') {
      return 'high';
    }
    return 'medium';
  }

  Future<void> loadProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final state = await GamificationService.getState();

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final predictionDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('predictions')
          .doc('latest')
          .get();

      if (!mounted) return;

      setState(() {
        unlockedLevel = state['yoga_level'] as int;
        xp = state['xp'] as int;
        streakCount = state['streak_count'] as int;
        completedLevels = List<int>.from(state['completed_levels'] as List);
        currentPhase = predictionDoc.data()?['current_phase']?.toString() ?? '—';
        stressLevel = (userDoc.data()?['stress_level'] as num?)?.toInt();
      });

      _fetchWellnessPlan(uid);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load progress: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchWellnessPlan(String uid) async {
    setState(() => loadingWellnessPlan = true);
    try {
      final response = await http
          .post(
            Uri.parse('$backendBaseUrl/ai/wellness-plan'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'user_id': uid}),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          wellnessPlan = data['text'] as String?;
          wellnessPlanError = false;
        });
      } else {
        setState(() => wellnessPlanError = true);
      }
    } catch (_) {
      // Network/timeout — not core functionality, but still worth telling
      // the user this failed rather than the card just vanishing.
      setState(() => wellnessPlanError = true);
    } finally {
      if (mounted) setState(() => loadingWellnessPlan = false);
    }
  }

  Future<void> _openLevel(Map<String, dynamic> item) async {
    final int level = item['level'];
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => YogaLevelDetailScreen(
          level: level,
          title: item['title'],
          durationMinutes: item['durationMinutes'],
          goal: item['goal'],
          guide: item['guide'],
          steps: List<String>.from(item['steps']),
          apiPoseId: item['apiPoseId'] as int?,
          defaultYoutubeId: item['youtubeId'] as String,
        ),
      ),
    );

    if (result != null && result['completed'] == true) {
      await completeLevel(level, checkIn: result);
    }
  }

  Future<void> completeLevel(int level, {Map<String, dynamic>? checkIn}) async {
    try {
      final result = await GamificationService.completeLevel(
        levelId: level,
        xpReward: level * 10,
        isMenstrualPhase: _isMenstrualPhase,
        badgeId: level == yogaLevels.length ? 'yoga_journey_complete' : null,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save progress: ${result['error']}')),
        );
        return;
      }

      setState(() {
        unlockedLevel = result['yoga_level'] as int;
        xp = result['xp'] as int;
        streakCount = result['streak_count'] as int;
        completedLevels = List<int>.from(result['completed_levels'] as List);
      });

      _saveCheckIn(level, checkIn);

      final unlockedNext = result['unlocked_next'] == true;
      final alreadyCompleted = result['already_completed'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unlockedNext
                ? 'Level $level completed! Next level unlocked 🌸'
                : alreadyCompleted
                    ? 'Level $level completed again — great consistency!'
                    : 'Level $level completed!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save your progress. Please try again.'),
        ),
      );
    }
  }

  /// Best-effort completion history: comfort/stress before & after, date,
  /// optional note. Skipped ratings are stored as null. Never blocks the
  /// XP/level save above — that already succeeded by the time this runs.
  Future<void> _saveCheckIn(int level, Map<String, dynamic>? checkIn) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final note = checkIn?['note'] as String?;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('yoga_checkins')
          .add({
        'level': level,
        'comfort_before': checkIn?['comfortBefore'],
        'stress_before': checkIn?['stressBefore'],
        'comfort_after': checkIn?['comfortAfter'],
        'stress_after': checkIn?['stressAfter'],
        'note': (note == null || note.isEmpty) ? null : note,
        'completed_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // History is a nice-to-have; the completion itself already saved.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Wellness')),
      body: Column(
        children: [
          _buildStatsHeader(),
          _buildWellnessPlanCard(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: yogaLevels.length,
              itemBuilder: (context, index) {
                final item = yogaLevels[index];
                final int level = item['level'];
                final bool isRecommended = item['energyTag'] == _energyLevel;
                // Recommendation is informational only — it never unlocks a
                // level early, so the game's sequential progression holds.
                final bool isUnlocked = level <= unlockedLevel;
                final bool isCurrent = level == unlockedLevel;
                final bool isDone = completedLevels.contains(level);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: isUnlocked ? null : Colors.grey.shade200,
                  child: ListTile(
                    leading: Icon(
                      isDone
                          ? Icons.check_circle
                          : isUnlocked
                              ? Icons.self_improvement
                              : Icons.lock,
                      color: isDone
                          ? Colors.green
                          : isCurrent
                              ? Colors.pink
                              : null,
                    ),
                    title: Text(
                      item['title'],
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Level $level'),
                        const SizedBox(height: 4),
                        Text(
                          isRecommended && !isCurrent
                              ? '${item['durationMinutes']} min • ${item['category']} • Suggested for ${item['recommendedFor']}'
                              : '${item['durationMinutes']} min • ${item['category']}',
                          style: isRecommended && !isCurrent
                              ? const TextStyle(
                                  color: Colors.pink, fontWeight: FontWeight.w500)
                              : null,
                        ),
                      ],
                    ),
                    trailing: isUnlocked
                        ? ElevatedButton(
                            onPressed: () => _openLevel(item),
                            child: const Text('Start'),
                          )
                        : Text('Complete Level ${level - 1}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    // unlockedLevel goes one past the last real level once it's completed
    // (so the next card would render as locked) — clamp so the header
    // never claims a "Level 6" that doesn't exist.
    final displayedLevel = unlockedLevel.clamp(1, yogaLevels.length);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFEEEDFE),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.local_fire_department, '$streakCount day streak',
              Colors.deepOrange),
          _statItem(Icons.flag, 'Level $displayedLevel', const Color(0xFF7F77DD)),
        ],
      ),
    );
  }

  Widget _buildWellnessPlanCard() {
    if (wellnessPlan == null && !loadingWellnessPlan && !wellnessPlanError) {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.spa_outlined, color: Color(0xFFEEEDFE), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Your Personalized Wellness Plan',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF3C3489)),
                ),
                const Spacer(),
                if (loadingWellnessPlan)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: wellnessPlan ??
                      (wellnessPlanError
                          ? "Couldn't load your wellness plan right now — try again shortly."
                          : 'Generating your plan...'),
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 13, height: 1.5),
                    strong: const TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.bold),
                    listBullet: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
