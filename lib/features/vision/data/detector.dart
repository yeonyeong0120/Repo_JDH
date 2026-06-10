import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class DetectionResult {
  final String className;
  final double confidence;
  final double x1, y1, x2, y2;

  DetectionResult({
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    final box = json['box'] as Map<String, dynamic>;
    return DetectionResult(
      className: json['class_name'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      x1: (box['x1'] as num).toDouble(),
      y1: (box['y1'] as num).toDouble(),
      x2: (box['x2'] as num).toDouble(),
      y2: (box['y2'] as num).toDouble(),
    );
  }
}

class DetectionResponse {
  final bool success;
  final List<DetectionResult> detections;
  final Map<String, int> counts;
  final int total;

  DetectionResponse({
    required this.success,
    required this.detections,
    required this.counts,
    required this.total,
  });

  factory DetectionResponse.fromJson(Map<String, dynamic> json) {
    final detList = (json['detections'] as List)
        .map((e) => DetectionResult.fromJson(e as Map<String, dynamic>))
        .toList();
    final countsMap = (json['counts'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toInt()));
    return DetectionResponse(
      success: json['success'] as bool,
      detections: detList,
      counts: countsMap,
      total: (json['total'] as num).toInt(),
    );
  }
}

class GarbageDetector {
  static const String SERVER_URL = 'http://16.146.251.126:8000';

  Future<DetectionResponse> detect(Uint8List imageBytes) async {
    final uri = Uri.parse('$SERVER_URL/detect');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      imageBytes,
      filename: 'image.jpg',
    ));
    final streamed = await request.send().timeout(
      const Duration(seconds: 10),
    );
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('서버 오류: ${response.statusCode}');
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return DetectionResponse.fromJson(json);
  }

  Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$SERVER_URL/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}