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

    // Uri(...).replace(queryParameters: ...)는 공백을 '+'로 인코딩하는데
    // (application/x-www-form-urlencoded 방식), FastAPI 는 이를 공백으로
    // 되돌리지 않고 문자 그대로 받는다 — "인천 부평구"가 "인천+부평구"로 도착해
    // 시도를 못 찾는 원인이 됐다. Uri.encodeComponent 로 직접 조립해 공백을
    // %20 으로 인코딩한다.
    final params = <String, String>{
      'lat': '$lat',
      'lng': '$lng',
      if (region != null && region.isNotEmpty) 'region': region,
    };
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final uri = Uri.parse('$_baseUrl/weather?$query');

    // TODO: 원인 확인용 임시 로그 — 확인 끝나면 제거
    debugPrint('[날씨] 요청 URL: $uri (region 인자: "$region")');

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
