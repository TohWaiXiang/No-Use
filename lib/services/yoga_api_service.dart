import 'dart:convert';
import 'package:http/http.dart' as http;

/// Pose reference data from the public Yoga API
/// (https://github.com/alexcumplido/yoga-api), used to enrich a level's
/// locally-authored practice with a real pose name/image/benefits.
class YogaPose {
  final String englishName;
  final String sanskritName;
  final String description;
  final String benefits;
  final String imageUrl;

  YogaPose({
    required this.englishName,
    required this.sanskritName,
    required this.description,
    required this.benefits,
    required this.imageUrl,
  });

  factory YogaPose.fromJson(Map<String, dynamic> json) => YogaPose(
    englishName: json['english_name'] as String? ?? '',
    sanskritName: json['sanskrit_name_adapted'] as String? ?? '',
    description: json['pose_description'] as String? ?? '',
    benefits: json['pose_benefits'] as String? ?? '',
    imageUrl: json['url_png'] as String? ?? json['url_svg'] as String? ?? '',
  );

  /// The API returns benefits as one run-on, period-separated sentence
  /// (e.g. "Opens the hips.  Stretches the back.  Calms the mind."). Split
  /// into a clean bullet list for display rather than showing that raw text.
  List<String> get benefitsList => benefits
      .split('.')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Fetches enrichment data for a single pose. This is best-effort: the free
/// hosted API can be slow to wake or may not carry a given pose, so callers
/// should already have complete local content and treat a null result as
/// "nothing extra to show" rather than an error.
class YogaApiService {
  static const _baseUrl = 'https://yoga-api-nzy4.onrender.com/v1/poses';

  static Future<YogaPose?> fetchPoseById(int id) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl?id=$id'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body.containsKey('message')) {
        return null;
      }
      return YogaPose.fromJson(body);
    } catch (_) {
      return null;
    }
  }
}
