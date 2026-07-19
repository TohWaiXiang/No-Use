import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Scoring for the two validated instruments (PSS-10, PSQI) used to
/// estimate hormonal-imbalance risk from stress and sleep quality.
class HormonalScoring {
  static const pssReverseIdx = {3, 4, 6, 7};

  static int pss10Score(List<int> a) {
    var total = 0;
    for (var i = 0; i < 10; i++) {
      total += pssReverseIdx.contains(i) ? (4 - a[i]) : a[i];
    }
    return total; // 0-40
  }

  static String pssCategory(int score) {
    if (score <= 13) return 'Low';
    if (score <= 26) return 'Moderate';
    return 'High';
  }

  static double timeInBedHours(TimeOfDay bed, TimeOfDay wake) {
    final bedMin = bed.hour * 60 + bed.minute;
    var wakeMin = wake.hour * 60 + wake.minute;
    if (wakeMin <= bedMin) wakeMin += 24 * 60;
    return (wakeMin - bedMin) / 60.0;
  }

  /// Returns the 7 PSQI component scores (0-3 each) and the global score (0-21).
  static Map<String, int> psqiScore({
    required int overallQuality, // Q9, 0-3
    required int latencyMinutes, // Q2
    required int troubleFallingAsleep30, // Q5a, 0-3
    required double hoursSlept, // Q4
    required TimeOfDay bedTime, // Q1
    required TimeOfDay wakeTime, // Q3
    required List<int> disturbances, // Q5b-j, 9 items 0-3
    required int medicationUse, // Q6, 0-3
    required int troubleStayingAwake, // Q7, 0-3
    required int enthusiasmProblem, // Q8, 0-3
  }) {
    final c1 = overallQuality;

    final latencyScore = latencyMinutes <= 15
        ? 0
        : latencyMinutes <= 30
        ? 1
        : latencyMinutes <= 60
        ? 2
        : 3;
    final sumC2 = latencyScore + troubleFallingAsleep30;
    final c2 = sumC2 == 0
        ? 0
        : sumC2 <= 2
        ? 1
        : sumC2 <= 4
        ? 2
        : 3;

    final c3 = hoursSlept > 7
        ? 0
        : hoursSlept >= 6
        ? 1
        : hoursSlept >= 5
        ? 2
        : 3;

    final timeInBed = timeInBedHours(bedTime, wakeTime);
    final efficiency = timeInBed <= 0
        ? 0.0
        : (hoursSlept / timeInBed * 100).clamp(0, 100);
    final c4 = efficiency >= 85
        ? 0
        : efficiency >= 75
        ? 1
        : efficiency >= 65
        ? 2
        : 3;

    final sumDisturbances = disturbances.fold<int>(0, (s, v) => s + v);
    final c5 = sumDisturbances == 0
        ? 0
        : sumDisturbances <= 9
        ? 1
        : sumDisturbances <= 18
        ? 2
        : 3;

    final c6 = medicationUse;

    final sum78 = troubleStayingAwake + enthusiasmProblem;
    final c7 = sum78 == 0
        ? 0
        : sum78 <= 2
        ? 1
        : sum78 <= 4
        ? 2
        : 3;

    final global = c1 + c2 + c3 + c4 + c5 + c6 + c7;
    return {
      'c1_quality': c1,
      'c2_latency': c2,
      'c3_duration': c3,
      'c4_efficiency': c4,
      'c5_disturbances': c5,
      'c6_medication': c6,
      'c7_daytime': c7,
      'global': global,
    };
  }

  static String psqiCategory(int global) => global <= 5 ? 'Good' : 'Poor';

  // ponytail: rule-based fusion of the two validated sub-scores, not a
  // trained model — no labelled "hormonal risk" outcome exists to train on.
  // Upgrade path: train against luna_backend/model/data/hormones_and_selfreport.csv
  // once a real hormonal-imbalance label is available.
  static String hormonalRisk(int pssScore, int psqiGlobal) {
    final pssBucket = pssScore <= 13
        ? 0
        : pssScore <= 26
        ? 1
        : 2;
    final psqiBucket = psqiGlobal <= 5
        ? 0
        : psqiGlobal <= 10
        ? 1
        : 2;
    final combined = pssBucket + psqiBucket;
    if (combined <= 1) return 'Low';
    if (combined <= 3) return 'Moderate';
    return 'High';
  }
}

const _pssQuestions = [
  'Been upset because of something that happened unexpectedly?',
  'Felt that you were unable to control the important things in your life?',
  'Felt nervous and stressed?',
  'Felt confident about your ability to handle your personal problems?',
  'Felt that things were going your way?',
  'Found that you could not cope with all the things that you had to do?',
  'Been able to control irritations in your life?',
  'Felt that you were on top of things?',
  'Been angered because of things that were outside of your control?',
  'Felt difficulties were piling up so high that you could not overcome them?',
];
const _pssOptions = [
  'Never',
  'Almost Never',
  'Sometimes',
  'Fairly Often',
  'Very Often',
];

const _disturbanceLabels = [
  'Wake up in the middle of the night or early morning',
  'Have to get up to use the bathroom',
  'Cannot breathe comfortably',
  'Cough or snore loudly',
  'Feel too cold',
  'Feel too hot',
  'Had bad dreams',
  'Have pain',
  'Other reasons',
];
const _freqOptions = [
  'Not during the past month',
  'Less than once a week',
  'Once or twice a week',
  'Three or more times a week',
];

class HormonalQuestionnaireScreen extends StatefulWidget {
  const HormonalQuestionnaireScreen({super.key});

  @override
  State<HormonalQuestionnaireScreen> createState() =>
      _HormonalQuestionnaireScreenState();
}

class _HormonalQuestionnaireScreenState
    extends State<HormonalQuestionnaireScreen> {
  final _pssAnswers = List<int?>.filled(10, null);
  final _disturbanceAnswers = List<int?>.filled(9, null);
  int? _troubleFallingAsleep30;
  int? _medicationUse;
  int? _troubleStayingAwake;
  int? _enthusiasmProblem;
  int? _overallQuality;
  double _latencyMinutes = 15;
  double _hoursSlept = 7;
  TimeOfDay _bedTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  bool _saving = false;

  bool get _pssComplete => !_pssAnswers.contains(null);
  bool get _psqiComplete =>
      !_disturbanceAnswers.contains(null) &&
      _troubleFallingAsleep30 != null &&
      _medicationUse != null &&
      _troubleStayingAwake != null &&
      _enthusiasmProblem != null &&
      _overallQuality != null;

  Future<void> _pickTime(bool isBedTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isBedTime ? _bedTime : _wakeTime,
    );
    if (picked != null) {
      setState(() => isBedTime ? _bedTime = picked : _wakeTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_pssComplete || !_psqiComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer every question.')),
      );
      return;
    }
    setState(() => _saving = true);

    final pssScore = HormonalScoring.pss10Score(
      _pssAnswers.cast<int>(),
    );
    final psqi = HormonalScoring.psqiScore(
      overallQuality: _overallQuality!,
      latencyMinutes: _latencyMinutes.round(),
      troubleFallingAsleep30: _troubleFallingAsleep30!,
      hoursSlept: _hoursSlept,
      bedTime: _bedTime,
      wakeTime: _wakeTime,
      disturbances: _disturbanceAnswers.cast<int>(),
      medicationUse: _medicationUse!,
      troubleStayingAwake: _troubleStayingAwake!,
      enthusiasmProblem: _enthusiasmProblem!,
    );
    final risk = HormonalScoring.hormonalRisk(pssScore, psqi['global']!);
    // stress_level (1-5) kept for the existing /predict cycle-phase model.
    final derivedStressLevel = 1 + (pssScore * 4 / 40).round();

    await AuthService.updateProfile({
      'stress_level': derivedStressLevel,
      'sleep_hours': _hoursSlept,
      'pss10_score': pssScore,
      'psqi_global_score': psqi['global'],
      'hormonal_risk': risk,
      'hormonal_assessment_date': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, {
      'risk': risk,
      'pssScore': pssScore,
      'psqiGlobal': psqi['global'],
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEEEDFE),
        foregroundColor: const Color(0xFF3C3489),
        title: const Text('Monthly Hormonal Check-in'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'PSS-10 — Perceived Stress',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'In the last month, how often have you...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _pssQuestions.length; i++)
              _likertCard(
                _pssQuestions[i],
                _pssOptions,
                _pssAnswers[i],
                (v) => setState(() => _pssAnswers[i] = v),
              ),

            const SizedBox(height: 16),
            const Text(
              'PSQI — Sleep Quality',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            _timeCard(
              'Usual bed time',
              _bedTime,
              () => _pickTime(true),
            ),
            _timeCard(
              'Usual wake time',
              _wakeTime,
              () => _pickTime(false),
            ),
            _sliderCard(
              'Minutes to fall asleep',
              _latencyMinutes,
              0,
              120,
              '${_latencyMinutes.round()} min',
              (v) => setState(() => _latencyMinutes = v),
            ),
            _sliderCard(
              'Hours of actual sleep per night',
              _hoursSlept,
              2,
              12,
              '${_hoursSlept.toStringAsFixed(1)} hrs',
              (v) => setState(() => _hoursSlept = v),
            ),
            _likertCard(
              'Trouble getting to sleep within 30 minutes',
              _freqOptions,
              _troubleFallingAsleep30,
              (v) => setState(() => _troubleFallingAsleep30 = v),
            ),
            for (var i = 0; i < _disturbanceLabels.length; i++)
              _likertCard(
                _disturbanceLabels[i],
                _freqOptions,
                _disturbanceAnswers[i],
                (v) => setState(() => _disturbanceAnswers[i] = v),
              ),
            _likertCard(
              'Taken medicine to help you sleep',
              _freqOptions,
              _medicationUse,
              (v) => setState(() => _medicationUse = v),
            ),
            _likertCard(
              'Trouble staying awake while driving, eating, or socialising',
              _freqOptions,
              _troubleStayingAwake,
              (v) => setState(() => _troubleStayingAwake = v),
            ),
            _likertCard(
              'Problem keeping up enthusiasm to get things done',
              const [
                'No problem at all',
                'Only a very slight problem',
                'Somewhat of a problem',
                'A very big problem',
              ],
              _enthusiasmProblem,
              (v) => setState(() => _enthusiasmProblem = v),
            ),
            _likertCard(
              'Overall, how would you rate your sleep quality?',
              const ['Very good', 'Fairly good', 'Fairly bad', 'Very bad'],
              _overallQuality,
              (v) => setState(() => _overallQuality = v),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7F77DD),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'See my results',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEEEDFE)),
    ),
    child: child,
  );

  Widget _likertCard(
    String question,
    List<String> options,
    int? value,
    ValueChanged<int> onChanged,
  ) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(options.length, (i) {
            final selected = value == i;
            return ChoiceChip(
              label: Text(options[i], style: const TextStyle(fontSize: 11)),
              selected: selected,
              selectedColor: const Color(0xFF7F77DD),
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFF2C2C2A),
              ),
              backgroundColor: const Color(0xFFF4F5FB),
              onSelected: (_) => onChanged(i),
            );
          }),
        ),
      ],
    ),
  );

  Widget _sliderCard(
    String label,
    double value,
    double min,
    double max,
    String display,
    ValueChanged<double> onChanged,
  ) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(
              display,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7F77DD),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFF7F77DD),
          inactiveColor: const Color(0xFFEEEDFE),
          onChanged: onChanged,
        ),
      ],
    ),
  );

  Widget _timeCard(String label, TimeOfDay time, VoidCallback onTap) => _card(
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        TextButton(onPressed: onTap, child: Text(time.format(context))),
      ],
    ),
  );
}
