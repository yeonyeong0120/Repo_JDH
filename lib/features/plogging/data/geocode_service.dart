import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// 좌표 → 장소명 변환 (FastAPI 서버의 /reverse-geocode 경유).
///
/// 네이버 역지오코딩 키는 서버에만 있고 앱은 모른다 → 앱에 Secret 이 실리지 않는다.
/// (뉴스가 네이버 검색 API 를 서버 경유로 부르는 것과 같은 이유)
class GeocodeService {
  GeocodeService._();

  // 서버 주소는 .env 의 FASTAPI_BASE_URL 사용 (뉴스/detect 와 동일 서버)
  static String get _baseUrl => dotenv.env['FASTAPI_BASE_URL'] ?? '';

  /// 활동 저장을 막지 않도록 짧게 끊는다. (뉴스는 30초지만 여기는 저장 경로다)
  static const Duration _timeout = Duration(seconds: 3);

  /// 좌표에 해당하는 장소명. 실패하면 null — 예외를 던지지 않는다.
  ///
  /// 호출부가 활동 저장 직전에 쓰므로 여기서 던지면 저장까지 막힌다.
  /// 서버 미설정·타임아웃·비200·파싱 실패를 모두 null 로 흡수한다.
  static Future<String?> placeNameOf({
    required double lat,
    required double lng,
  }) async {
    if (_baseUrl.isEmpty) {
      debugPrint('[역지오코딩] FASTAPI_BASE_URL 미설정 — 장소명 생략');
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
      // 한글 장소명이 깨지지 않게 UTF-8 로 직접 디코딩 (resp.body 쓰면 깨짐)
      final data =
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final name = (data['placeName'] as String?)?.trim();
      return (name == null || name.isEmpty) ? null : name;
    } catch (e) {
      debugPrint('[역지오코딩] 실패: $e');
      return null;
    }
  }
}
