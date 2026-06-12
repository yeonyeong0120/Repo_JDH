// 경로 추천 도메인 계층.
// 사용자가 목적지를 정하고 추천을 요청하면 상태가 loading → data/error로 흐른다.
// 가이드라인 3-1: setState 금지, AsyncNotifier + AsyncValue.guard 사용.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/route_repository.dart';
import 'route_models.dart';

class RouteNotifier extends AsyncNotifier<RouteResult?> {
  @override
  Future<RouteResult?> build() async => null; // 초기엔 추천 결과 없음

  // 경로 추천 요청. 결과는 state(AsyncValue)로 노출된다.
  Future<void> recommend({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    String? district,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(routeRepositoryProvider).recommend(
            originLat: originLat,
            originLon: originLon,
            destLat: destLat,
            destLon: destLon,
            district: district,
          ),
    );
  }

  // 결과 초기화(화면을 떠날 때 등).
  void reset() => state = const AsyncData(null);
}

final routeNotifierProvider =
    AsyncNotifierProvider<RouteNotifier, RouteResult?>(RouteNotifier.new);
