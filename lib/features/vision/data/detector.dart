import 'dart:convert';
// Uint8List·debugPrint 를 함께 제공하므로 dart:typed_data 는 따로 import 하지 않는다
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:repo_jdh/core/constants/api_config.dart';

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
    final countsMap = (json['counts'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    return DetectionResponse(
      success: json['success'] as bool,
      detections: detList,
      counts: countsMap,
      total: (json['total'] as num).toInt(),
    );
  }
}

class GarbageDetector {
  // 서버 주소는 .env 의 FASTAPI_BASE_URL 사용 (뉴스·역지오코딩과 동일 서버)
  static String get _baseUrl => ApiConfig.baseUrl;

  Future<DetectionResponse> detect(Uint8List imageBytes) async {
    // 하드코딩 시절과 달리 주소가 비어 있을 수 있다.
    // 그대로 두면 잘못된 URL 로 요청이 나가 원인을 알기 어려운 실패가 된다.
    if (_baseUrl.isEmpty) {
      throw Exception('서버 주소(FASTAPI_BASE_URL)가 설정되지 않았습니다');
    }
    final uri = Uri.parse('$_baseUrl/detect');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      http.MultipartFile.fromBytes('file', imageBytes, filename: 'image.jpg'),
    );
    final streamed = await request.send().timeout(const Duration(seconds: 10));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('서버 오류: ${response.statusCode}');
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return DetectionResponse.fromJson(json);
  }

  Future<bool> healthCheck() async {
    if (_baseUrl.isEmpty) {
      debugPrint('[객체인식] FASTAPI_BASE_URL 미설정 — 서버 연결 안 됨으로 처리');
      return false;
    }
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
