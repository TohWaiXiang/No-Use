import 'dart:math';
import 'package:flutter/material.dart';

// Ink + chrome tokens (shared across all chat infographics).
const _inkPrimary = Color(0xFF2C2C2A);
const _inkSecondary = Color(0xFF52514E);
const _inkMuted = Color(0xFF898781);
const _gridline = Color(0xFFE1E0D9);
const _baseline = Color(0xFFC3C2B7);

// Fixed-order categorical palette for the 4 cycle phases (validated for
// colorblind-safe adjacent contrast — do not reorder or recolor per-instance).
const _phaseOrder = ['menstrual', 'follicular', 'ovulation', 'luteal'];
const _phaseColors = {
  'menstrual': Color(0xFF2A78D6),
  'follicular': Color(0xFF1BAF7A),
  'ovulation': Color(0xFFEDA100),
  'luteal': Color(0xFF4A3AA7),
};
const _phaseLabels = {
  'menstrual': 'Menstrual',
  'follicular': 'Follicular',
  'ovulation': 'Ovulation',
  'luteal': 'Luteal',
};
// Fixed share of the cycle each phase occupies, out of a 28-day reference —
// used only to draw proportional wedges, independent of the user's actual
// cycle length.
const _phaseFractions = {
  'menstrual': 5 / 28,
  'follicular': 8 / 28,
  'ovulation': 2 / 28,
  'luteal': 13 / 28,
};

// Single-hue sequential ramp (blue), light -> dark, for magnitude encoding.
const _seqLight = Color(0xFF86B6EF); // step 250
const _seqDark = Color(0xFF1C5CAB); // step 550

const _fertileBand = Color(0xFF4A3AA7);

/// Renders a chat-bubble-sized infographic for one of Luna's supported
/// chart types. Falls back to an empty box for unknown chart types so the
/// caller can decide whether to show the raw text instead.
class ChatInfographic extends StatelessWidget {
  final String chart;
  final Map<String, dynamic> data;

  const ChatInfographic({super.key, required this.chart, required this.data});

  @override
  Widget build(BuildContext context) {
    switch (chart) {
      case 'cycle_phase':
        return _CyclePhaseWheel(data: data);
      case 'fertile_window':
        return _FertileWindowTimeline(data: data);
      case 'symptom_trend':
        return _SymptomTrendChart(data: data);
      default:
        return const SizedBox.shrink();
    }
  }
}

int _intOr(dynamic v, int fallback, {int? min, int? max}) {
  final n = (v is num) ? v.toInt() : fallback;
  var result = n;
  if (min != null && result < min) result = min;
  if (max != null && result > max) result = max;
  return result;
}

class _CyclePhaseWheel extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CyclePhaseWheel({required this.data});

  @override
  Widget build(BuildContext context) {
    final rawPhase = (data['phase'] as String?)?.toLowerCase().trim() ?? '';
    final phase = _phaseOrder.contains(rawPhase) ? rawPhase : 'follicular';
    final cycleLength = _intOr(data['cycleLength'], 28, min: 20, max: 40);
    final dayOfCycle = _intOr(data['dayOfCycle'], 1, min: 1, max: cycleLength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(132, 132),
                painter: _WheelPainter(currentPhase: phase),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _phaseLabels[phase]!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Day $dayOfCycle of $cycleLength',
                    style: const TextStyle(fontSize: 11, color: _inkSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: _phaseOrder.map((p) {
            final isCurrent = p == phase;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _phaseColors[p],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _phaseLabels[p]!,
                  style: TextStyle(
                    fontSize: 11,
                    color: isCurrent ? _inkPrimary : _inkMuted,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final String currentPhase;
  const _WheelPainter({required this.currentPhase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 12;
    const gap = 0.06;
    double start = -pi / 2;

    for (final phase in _phaseOrder) {
      final sweep = _phaseFractions[phase]! * 2 * pi;
      final isCurrent = phase == currentPhase;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = isCurrent ? 16 : 10
        ..color = _phaseColors[phase]!.withValues(alpha: isCurrent ? 1.0 : 0.35);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start + gap / 2,
        sweep - gap,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.currentPhase != currentPhase;
}

class _FertileWindowTimeline extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FertileWindowTimeline({required this.data});

  @override
  Widget build(BuildContext context) {
    final cycleLength = _intOr(data['cycleLength'], 28, min: 20, max: 40);
    final ovulationDay = _intOr(
      data['ovulationDay'],
      max(1, cycleLength - 14),
      min: 1,
      max: cycleLength,
    );
    final fertileStartDay = _intOr(
      data['fertileStartDay'],
      max(1, ovulationDay - 5),
      min: 1,
      max: cycleLength,
    );
    final fertileEndDay = _intOr(
      data['fertileEndDay'],
      min(cycleLength, ovulationDay + 1),
      min: 1,
      max: cycleLength,
    );
    final currentDay = _intOr(data['currentDay'], 1, min: 1, max: cycleLength);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const padding = 6.0;
        final usable = width - padding * 2;

        double xFor(int day) {
          if (cycleLength <= 1) return padding;
          return padding + (day - 1) / (cycleLength - 1) * usable;
        }

        final fertileStartX = xFor(fertileStartDay);
        final fertileEndX = xFor(fertileEndDay);
        final ovulationX = xFor(ovulationDay);
        final todayX = xFor(currentDay);
        final sameDay = (ovulationDay - currentDay).abs() == 0;

        return SizedBox(
          height: sameDay ? 78 : 92,
          child: Stack(
            children: [
              Positioned(
                left: ovulationX - 30,
                top: 0,
                width: 60,
                child: Text(
                  'Ovulation · $ovulationDay',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _inkPrimary,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 30,
                height: 26,
                child: CustomPaint(
                  painter: _TimelinePainter(
                    fertileStartX: fertileStartX,
                    fertileEndX: fertileEndX,
                    ovulationX: ovulationX,
                    todayX: todayX,
                  ),
                ),
              ),
              if (!sameDay)
                Positioned(
                  left: todayX - 24,
                  top: 58,
                  width: 48,
                  child: Text(
                    'Today · $currentDay',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: _inkSecondary),
                  ),
                ),
              Positioned(
                left: 0,
                bottom: 0,
                child: Text(
                  'Day 1',
                  style: const TextStyle(fontSize: 10, color: _inkMuted),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Text(
                  'Day $cycleLength',
                  style: const TextStyle(fontSize: 10, color: _inkMuted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final double fertileStartX;
  final double fertileEndX;
  final double ovulationX;
  final double todayX;

  const _TimelinePainter({
    required this.fertileStartX,
    required this.fertileEndX,
    required this.ovulationX,
    required this.todayX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;

    final basePaint = Paint()
      ..color = _baseline
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), basePaint);

    final bandRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(fertileStartX, midY - 5, fertileEndX, midY + 5),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      bandRect,
      Paint()..color = _fertileBand.withValues(alpha: 0.18),
    );
    canvas.drawRRect(
      bandRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _fertileBand.withValues(alpha: 0.5),
    );

    canvas.drawCircle(Offset(ovulationX, midY), 5, Paint()..color = _fertileBand);

    final dashPaint = Paint()
      ..color = _inkMuted
      ..strokeWidth = 1.5;
    var y = 0.0;
    const dashHeight = 3.0, dashGap = 3.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(todayX, y),
        Offset(todayX, min(y + dashHeight, size.height)),
        dashPaint,
      );
      y += dashHeight + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.fertileStartX != fertileStartX ||
      oldDelegate.fertileEndX != fertileEndX ||
      oldDelegate.ovulationX != ovulationX ||
      oldDelegate.todayX != todayX;
}

class _SymptomTrendChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SymptomTrendChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final rawDays = (data['days'] as List?) ?? const [];
    final days = rawDays
        .whereType<Map>()
        .map((d) => {
              'label': (d['label'] as String?) ?? '',
              'symptomsCount': _intOr(d['symptomsCount'], 0, min: 0, max: 20),
              'moodLabel': d['moodLabel'] as String?,
            })
        .toList();
    final recent = days.length > 7
        ? days.sublist(days.length - 7)
        : days;

    if (recent.isEmpty) {
      return const Text(
        'Not enough logged days yet to show a trend.',
        style: TextStyle(fontSize: 12, color: _inkSecondary),
      );
    }

    final maxCount = recent
        .map((d) => d['symptomsCount'] as int)
        .fold<int>(1, (a, b) => max(a, b));

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: recent.map((d) {
          final count = d['symptomsCount'] as int;
          final mood = d['moodLabel'] as String?;
          final t = count / maxCount;
          final barHeight = 8.0 + t * 66.0;
          final color = Color.lerp(_seqLight, _seqDark, t)!;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 16,
                child: mood != null && mood.isNotEmpty
                    ? Text(
                        mood,
                        style: const TextStyle(fontSize: 9, color: _inkSecondary),
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
              ),
              Container(
                width: 18,
                height: barHeight,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(width: 18, height: 1, color: _gridline),
              const SizedBox(height: 4),
              Text(
                d['label'] as String,
                style: const TextStyle(fontSize: 9, color: _inkMuted),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
