import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luna_health/screens/hormonal_questionnaire_screen.dart';

void main() {
  test('PSS-10 scores reverse items correctly', () {
    // All "2" (Sometimes): reverse items still contribute (4-2)=2, so total stays 20.
    expect(HormonalScoring.pss10Score(List.filled(10, 2)), 20);
    // 6 non-reverse items at 4 (=24) + 4 reverse items scored (4-4)=0 each.
    expect(HormonalScoring.pss10Score(List.filled(10, 4)), 24);
    // 6 non-reverse items at 0 + 4 reverse items scored (4-0)=4 each (=16).
    expect(HormonalScoring.pss10Score(List.filled(10, 0)), 16);
  });

  test('PSS-10 category cutoffs', () {
    expect(HormonalScoring.pssCategory(13), 'Low');
    expect(HormonalScoring.pssCategory(14), 'Moderate');
    expect(HormonalScoring.pssCategory(26), 'Moderate');
    expect(HormonalScoring.pssCategory(27), 'High');
  });

  test('PSQI global score for a healthy sleeper is low', () {
    final result = HormonalScoring.psqiScore(
      overallQuality: 0,
      latencyMinutes: 10,
      troubleFallingAsleep30: 0,
      hoursSlept: 8,
      bedTime: const TimeOfDay(hour: 23, minute: 0),
      wakeTime: const TimeOfDay(hour: 7, minute: 0),
      disturbances: List.filled(9, 0),
      medicationUse: 0,
      troubleStayingAwake: 0,
      enthusiasmProblem: 0,
    );
    expect(result['global'], 0);
    expect(HormonalScoring.psqiCategory(result['global']!), 'Good');
  });

  test('PSQI global score for a poor sleeper is high', () {
    final result = HormonalScoring.psqiScore(
      overallQuality: 3,
      latencyMinutes: 90,
      troubleFallingAsleep30: 3,
      hoursSlept: 4,
      bedTime: const TimeOfDay(hour: 22, minute: 0),
      wakeTime: const TimeOfDay(hour: 6, minute: 0),
      disturbances: List.filled(9, 3),
      medicationUse: 3,
      troubleStayingAwake: 3,
      enthusiasmProblem: 3,
    );
    expect(result['global'], 21);
    expect(HormonalScoring.psqiCategory(result['global']!), 'Poor');
  });

  test('hormonal risk fuses PSS and PSQI buckets', () {
    expect(HormonalScoring.hormonalRisk(0, 0), 'Low');
    expect(HormonalScoring.hormonalRisk(20, 8), 'Moderate');
    expect(HormonalScoring.hormonalRisk(40, 21), 'High');
  });
}
