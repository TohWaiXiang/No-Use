import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/gamification_service.dart';
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

  // Yoga levels are single poses, one per stage. `apiPoseId` looks the pose
  // up on the public Yoga API (github.com/alexcumplido/yoga-api) for a
  // reference image/benefits; it's null for poses outside that API's
  // 48-pose catalog (Cobra and Legs-Up-the-Wall), which fall back to the
  // steps below only. Framed around relaxation/stress/sleep, not medical
  // claims — yoga here supports well-being, it doesn't treat symptoms.
  final List<Map<String, dynamic>> yogaLevels = [
    {
      'level': 1,
      'title': "Child's Pose",
      'durationMinutes': 5,
      'goal': 'Calm the mind and ease everyday stress',
      'phase': 'Any',
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
      'phase': 'Follicular',
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
      'phase': 'Menstrual',
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
      'phase': 'Luteal',
      'apiPoseId': null,
      'youtubeId': 'n6jrC6WeF84',
      'steps': [
        'Lie face down with your legs extended and the tops of your feet on the mat.',
        'Place your palms under your shoulders, elbows hugging into your sides.',
        'Press into your hands and lift your chest, keeping your lower ribs on the mat.',
        'Draw your shoulders back and down, away from your ears.',
        'Hold for a few breaths, then lower back down slowly.',
      ],
    },
    {
      'level': 5,
      'title': 'Legs-Up-the-Wall',
      'durationMinutes': 10,
      'goal': 'Support deep relaxation and restful sleep',
      'phase': 'Ovulation',
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
  ];

  @override
  void initState() {
    super.initState();
    loadProgress();
  }

  bool get _isMenstrualPhase => currentPhase == 'Menstrual';

  Future<void> loadProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final state = await GamificationService.getState();

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
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load progress: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _openLevel(Map<String, dynamic> item) async {
    final int level = item['level'];
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => YogaLevelDetailScreen(
          level: level,
          title: item['title'],
          durationMinutes: item['durationMinutes'],
          goal: item['goal'],
          steps: List<String>.from(item['steps']),
          apiPoseId: item['apiPoseId'] as int?,
          defaultYoutubeId: item['youtubeId'] as String,
        ),
      ),
    );

    if (completed == true) {
      await completeLevel(level);
    }
  }

  Future<void> completeLevel(int level) async {
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

    final unlockedNext = result['unlocked_next'] == true;
    final alreadyCompleted = result['already_completed'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          unlockedNext
              ? 'Level $level completed! Next level unlocked 🌸  (+${level * 10} XP)'
              : alreadyCompleted
                  ? 'Level $level completed again — great consistency!'
                  : 'Level $level completed! (+${level * 10} XP)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yoga & Relaxation Journey 🌸')),
      body: Column(
        children: [
          _buildStatsHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: yogaLevels.length,
              itemBuilder: (context, index) {
                final item = yogaLevels[index];
                final int level = item['level'];
                final bool isRecommended =
                    item['phase'] == 'Any' || item['phase'] == currentPhase;
                // Sequentially unlocked, or reachable today via a phase
                // recommendation — a rough period shouldn't be blocked by
                // an unfinished strength-training level.
                final bool isUnlocked = level <= unlockedLevel || isRecommended;
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
                      '${'⭐' * level}  ${item['title']}',
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      isRecommended && !isCurrent
                          ? '${item['durationMinutes']} min • ${item['goal']} • Recommended today'
                          : '${item['durationMinutes']} min • ${item['goal']}',
                      style: isRecommended && !isCurrent
                          ? const TextStyle(
                              color: Colors.pink, fontWeight: FontWeight.w500)
                          : null,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFEEEDFE),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.star, '$xp XP', const Color(0xFF3C3489)),
          _statItem(Icons.local_fire_department, '$streakCount day streak',
              Colors.deepOrange),
          _statItem(Icons.flag, 'Level $unlockedLevel', const Color(0xFF7F77DD)),
        ],
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
