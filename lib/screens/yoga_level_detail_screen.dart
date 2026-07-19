import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../services/yoga_api_service.dart';

/// Full-screen guided practice for a single yoga level: local step-by-step
/// instructions (always available), optionally enriched with a reference
/// image/benefits from the Yoga API, plus a demonstration video embedded
/// and played directly from YouTube. Completion is reported back via
/// Navigator.pop(true) once the user has actually started the countdown,
/// rather than the moment they tap in.
class YogaLevelDetailScreen extends StatefulWidget {
  final int level;
  final String title;
  final int durationMinutes;
  final String goal;
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

  void _beginPractice() {
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
    });
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
                    '${widget.durationMinutes} min • ${widget.goal}',
                    style: const TextStyle(color: Colors.grey),
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
                      onPressed: !_started
                          ? _beginPractice
                          : () => Navigator.of(context).pop(true),
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
