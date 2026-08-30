// 경로 추천 데이터 계층.
// FastAPI 서버의 POST /route/recommend를 Dio로 호출하고 RouteResult로 변환한다.
// 가이드라인 9-3: Tmap·Geocoding은 FastAPI 프록시 경유. 앱은 백엔드만 호출한다.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repo_jdh/core/constants/api_config.dart';

import '../domain/route_models.dart';

// FastAPI 클라이언트(Dio) 전역 Provider.
// 주의: core/providers에 공용 Dio Provider가 이미 있다면 그것을 watch하도록 바꾸고
// 아래 정의는 제거한다(전역 Provider 중복 방지).
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ApiConfig.baseUrl;
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      // hard case는 서버가 Tmap을 최대 6회 호출하므로 응답이 길어질 수 있다(최대 약 90초).
      receiveTimeout: const Duration(seconds: 120),
      headers: {'Content-Type': 'application/json'},
    ),
  );
});

// 경로 추천 실패를 사용자 메시지로 감싸는 예외.
class RouteException implements Exception {
  RouteException(this.message);
  final String message;

  @override
  String toString() => message;
}

class RouteRepository {
  RouteRepository(this._dio);
  final Dio _dio;

  // 출발지·도착지를 보내고 추천 경로를 받는다.
  // district는 선택. 주어지면 해당 군구 핫스팟 + 군구별 buffer 사용.
  Future<RouteResult> recommend({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    String? district,
  }) async {
    // 서버 주소가 비어 있으면 명확히 안내(.env 미설정 방어)
    if (_dio.options.baseUrl.isEmpty) {
      throw RouteException('서버 주소가 설정되지 않았어요. (.env의 FASTAPI_BASE_URL 확인)');
    }
    try {
      final res = await _dio.post(
        '/route/recommend',
        data: {
          'origin': {'lat': originLat, 'lon': originLon},
          'destination': {'lat': destLat, 'lon': destLon},
          if (district != null) 'district': district,
        },
      );
      return RouteResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      // 502: 서버가 Tmap 도보 경로를 가져오지 못함. 그 외: 네트워크·서버 오류.
      throw RouteException(
        code == 502
            ? '도보 경로를 가져오지 못했습니다. 잠시 후 다시 시도해 주세요.'
            : '경로를 불러오지 못했습니다. (${code ?? e.type.name})',
      );
    } on RouteException {
      rethrow;
    } catch (e) {
      // DioException이 아닌 예외(잘못된 baseUrl 등)도 안내 메시지로 변환
      throw RouteException('경로를 불러오지 못했습니다. 서버 주소를 확인해 주세요.');
    }
  }
}

final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => RouteRepository(ref.watch(dioProvider)),
);
