import 'package:flutter_dotenv/flutter_dotenv.dart';

/// FastAPI 서버 주소 (앱 전역 단일 소스).
///
/// 서버 주소는 .env 의 FASTAPI_BASE_URL 하나만 본다.
/// 과거 detector.dart 가 IP 를 따로 하드코딩하고 있어, 서버 IP 가 바뀌면
/// 객체 인식만 조용히 실패했다. 주소 해석은 반드시 이 파일에서만 한다.
class ApiConfig {
  ApiConfig._();

  /// 정규화된 서버 주소. 미설정이면 빈 문자열.
  ///
  /// 호출부는 빈 문자열을 반드시 확인해야 한다 — 그대로 요청하면
  /// 'http:///detect' 같은 잘못된 URL 이 되어 원인을 알기 어려운 실패가 난다.
  static String get baseUrl {
    // dotenv.load() 전에 env 에 접근하면 NotInitializedError 가 난다.
    // 위젯 테스트처럼 load 를 거치지 않는 경로에서도 터지지 않게 막는다.
    if (!dotenv.isInitialized) return '';
    return _normalize(dotenv.env['FASTAPI_BASE_URL']);
  }

  /// 서버 주소 문자열을 유효한 URL 로 보정한다.
  /// - 값에 섞인 따옴표/공백 제거
  /// - http/https 스킴이 없으면 http:// 를 붙인다 (IP만 온 경우 방어)
  /// - 호스트에 포트가 없으면 기본 포트(8000)를 붙인다
  /// 빈 값이면 빈 문자열을 반환한다.
  static String _normalize(String? raw) {
    var v = (raw ?? '').trim().replaceAll('"', '').replaceAll("'", '');
    if (v.isEmpty) return '';

    if (!v.startsWith('http://') && !v.startsWith('https://')) {
      v = 'http://$v';
    }

    final uri = Uri.tryParse(v);
    if (uri != null && uri.host.isNotEmpty && !uri.hasPort) {
      v = '${uri.scheme}://${uri.host}:8000${uri.path}';
    }

    return v;
  }
}
