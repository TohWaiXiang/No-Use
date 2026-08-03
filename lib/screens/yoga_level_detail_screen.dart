import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/yoga_api_service.dart';

/// Full-screen guided practice for a single yoga level: local step-by-step
/// instructions (always available), optionally enriched with a reference
/// image/benefits from the Yoga API, plus a demonstration video embedded
/// and played directly from YouTube. Completion is reported back via
/// Navigator.pop with a result map once the user has actually started the
/// countdown, rather than the moment they tap in.
class YogaLevelDetailScreen extends StatefulWidget {
  final int level;
  final String title;
  final int durationMinutes;
  final String goal;
  final String guide;
  final List<String> steps;
  final int? apiPoseId;

  /// Hardcoded fallback video, used until (and unless) an override for this
  /// level is found in Firestore at config/yoga_videos. Keeping overrides in
  /// Firestore lets a since-removed/unavailable video be swapped out without
  /// an app release.
  final String defaultYoutubeId;

  const YogaLevelDetailScreen({
    super.key,
    required this.level,
    required this.title,
    required this.durationMinutes,
    required this.goal,
    required this.guide,
    required this.steps,
    required this.apiPoseId,
    required this.defaultYoutubeId,
  });

  @override
  State<YogaLevelDetailScreen> createState() => _YogaLevelDetailScreenState();
}

class _YogaLevelDetailScreenState extends State<YogaLevelDetailScreen> {
  late int _secondsRemaining;
  Timer? _timer;
  bool _started = false;
  YogaPose? _apiPose;
  late YoutubePlayerController _videoController;
  int? _comfortBefore;
  int? _stressBefore;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.durationMinutes * 60;
    _videoController = YoutubePlayerController(
      initialVideoId: widget.defaultYoutubeId,
      flags: const YoutubePlayerFlags(autoPlay: false),
    );
    _loadVideoOverride();
    if (widget.apiPoseId != null) {
      YogaApiService.fetchPoseById(widget.apiPoseId!).then((pose) {
        if (mounted && pose != null) setState(() => _apiPose = pose);
      });
    }
  }

  /// config/yoga_videos holds `{"level": "youtubeId"}` overrides so a
  /// video that gets pulled/blocked on YouTube can be swapped in Firestore
  /// without shipping an app update. Missing doc/field/error just keeps the
  /// hardcoded default already loaded above.
  Future<void> _loadVideoOverride() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('yoga_videos')
          .get();
      final override = doc.data()?['${widget.level}'] as String?;
      if (override != null &&
          override.isNotEmpty &&
          override != widget.defaultYoutubeId) {
        _videoController.load(override);
      }
    } catch (_) {
      // Keep the default video.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _beginPractice() async {
    final before = await _askRatings(title: 'Before you start');
    setState(() {
      _comfortBefore = before?.comfort;
      _stressBefore = before?.stress;
      _started = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  Future<void> _markComplete() async {
    final after = await _askRatings(title: 'How do you feel now?', withNote: true);
    if (!mounted) return;
    Navigator.of(context).pop({
      'completed': true,
      'comfortBefore': _comfortBefore,
      'stressBefore': _stressBefore,
      'comfortAfter': after?.comfort,
      'stressAfter': after?.stress,
      'note': after?.note,
    });
  }

  /// Quick 1-5 comfort/stress check-in. Skippable — this is for the user's
  /// own tracking, not a gate on completing the practice.
  Future<_Ratings?> _askRatings({required String title, bool withNote = false}) {
    int comfort = 3;
    int stress = 3;
    final noteCtrl = TextEditingController();
    return showDialog<_Ratings>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comfort: $comfort / 5'),
              Slider(
                value: comfort.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$comfort',
                onChanged: (v) => setDialogState(() => comfort = v.round()),
              ),
              Text('Stress: $stress / 5'),
              Slider(
                value: stress.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: '$stress',
                onChanged: (v) => setDialogState(() => stress = v.round()),
              ),
              if (withNote)
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(hintText: 'Optional note'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                ctx,
                _Ratings(comfort, stress, noteCtrl.text.trim()),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String get _timeLabel {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final finished = _started && _secondsRemaining == 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${widget.durationMinutes} min session • ${widget.goal}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEDFE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.guide,
                      style: const TextStyle(
                          color: Color(0xFF3C3489), fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Text(
                      'Practise within your comfort level and stop if you feel '
                      'pain, dizziness or discomfort. These sessions support '
                      'general wellness and do not replace medical care.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                  if (_apiPose != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _apiPose!.sanskritName,
                      style: const TextStyle(
                          fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                    if (_apiPose!.imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Image.network(_apiPose!.imageUrl, height: 140),
                      ),
                    ],
                    if (_apiPose!.benefitsList.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ..._apiPose!.benefitsList.map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  '),
                              Expanded(
                                child: Text(b,
                                    style: const TextStyle(height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  ...List.generate(widget.steps.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFF7F77DD),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.steps[i],
                              style: const TextStyle(height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  const Text(
                    'Demonstration video',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  YoutubePlayer(controller: _videoController),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_started)
                    Text(
                      finished ? 'Session complete 🌸' : '$_timeLabel remaining',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: !_started ? _beginPractice : _markComplete,
                      child: Text(!_started ? 'Begin Practice' : 'Mark Complete'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ratings {
  final int comfort;
  final int stress;
  final String? note;
  _Ratings(this.comfort, this.stress, [this.note]);
}
