import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:repo_jdh/core/constants/api_config.dart';

/// 날씨·미세먼지 조회 (FastAPI 서버 /weather 경유). 서버가 30분 캐싱한다.
class WeatherService {
  WeatherService._();

  static String get _baseUrl => ApiConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 5);

  /// 기온(temp)·미세먼지 등급(pm10Grade)만 반환. 실패하면 둘 다 null.
  /// 호출부가 홈 표시 직전에 쓰므로 예외를 던지지 않는다.
  static Future<({int? temp, String? pm10Grade})> fetch({
    required double lat,
    required double lng,
    String? region,
  }) async {
    final data = await _fetchJson(lat: lat, lng: lng, region: region);
    return (
      temp: (data?['temp'] as num?)?.toInt(),
      pm10Grade: _stringField(data, 'pm10Grade'),
    );
  }

  static Future<Map<String, dynamic>?> _fetchJson({
    required double lat,
    required double lng,
    String? region,
  }) async {
    if (_baseUrl.isEmpty) {
      debugPrint('[날씨] FASTAPI_BASE_URL 미설정 — 조회 생략');
      return null;
    }

    final uri = Uri.parse('$_baseUrl/weather').replace(queryParameters: {
      'lat': '$lat',
      'lng': '$lng',
      if (region != null && region.isNotEmpty) 'region': region,
    });

    try {
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) {
        debugPrint('[날씨] 응답 코드 ${resp.statusCode}');
        return null;
      }
      return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[날씨] 실패: $e');
      return null;
    }
  }

  static String? _stringField(Map<String, dynamic>? data, String key) {
    final v = (data?[key] as String?)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }
}
