import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:repo_jdh/core/constants/api_config.dart';

/// 좌표 → 장소명 변환 (FastAPI 서버의 /reverse-geocode 경유).
///
/// 네이버 역지오코딩 키는 서버에만 있고 앱은 모른다 → 앱에 Secret 이 실리지 않는다.
/// (뉴스가 네이버 검색 API 를 서버 경유로 부르는 것과 같은 이유)
class GeocodeService {
  GeocodeService._();

  // 서버 주소는 .env 의 FASTAPI_BASE_URL 사용 (뉴스/detect 와 동일 서버)
  static String get _baseUrl => ApiConfig.baseUrl;

  /// 활동 저장을 막지 않도록 짧게 끊는다. (뉴스는 30초지만 여기는 저장 경로다)
  static const Duration _timeout = Duration(seconds: 3);

  /// 좌표 → 장소명 + 번지 포함 상세 장소명 (활동 저장용). _fetch 한 번으로 둘 다 받는다.
  /// 실패하면 둘 다 null. 호출부가 활동 저장 직전에 쓰므로 예외를 던지지 않는다.
  static Future<({String? placeName, String? placeDetail})> placeInfoOf({
    required double lat,
    required double lng,
  }) async {
    final data = await _fetch(lat: lat, lng: lng);
    return (
      placeName: _stringField(data, 'placeName'),
      placeDetail: _stringField(data, 'placeDetail'),
    );
  }

  /// 좌표에 해당하는 지역(그룹 매칭용, 예: '인천 남동구'). 실패하면 null.
  static Future<String?> regionOf({
    required double lat,
    required double lng,
  }) async {
    final data = await _fetch(lat: lat, lng: lng);
    return _stringField(data, 'region');
  }

  static String? _stringField(Map<String, dynamic>? data, String key) {
    final v = (data?[key] as String?)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// /reverse-geocode 호출 + 파싱. 서버 미설정·타임아웃·비200·파싱 실패를
  /// 모두 null 로 흡수한다 — 예외를 던지지 않는다.
  static Future<Map<String, dynamic>?> _fetch({
    required double lat,
    required double lng,
  }) async {
    if (_baseUrl.isEmpty) {
      debugPrint('[역지오코딩] FASTAPI_BASE_URL 미설정 — 조회 생략');
      return null;
    }

    final uri = Uri.parse(
      '$_baseUrl/reverse-geocode',
    ).replace(queryParameters: {'lat': '$lat', 'lng': '$lng'});

    try {
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) {
        debugPrint('[역지오코딩] 응답 코드 ${resp.statusCode}');
        return null;
      }
      // 한글이 깨지지 않게 UTF-8 로 직접 디코딩 (resp.body 쓰면 깨짐)
      return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[역지오코딩] 실패: $e');
      return null;
    }
  }
}
