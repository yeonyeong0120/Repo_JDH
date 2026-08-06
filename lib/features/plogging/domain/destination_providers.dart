// 출발지·도착지 좌표 프로바이더.
// 출발지(현재 GPS)와 사용자가 지도를 탭해 고른 도착지를 보관한다.
// 가이드라인: 지도 라이브러리(NLatLng)에 의존하지 않도록 좌표는 순수 Dart 타입으로 둔다.
//            NLatLng 변환은 presentation에서 처리한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:repo_jdh/features/plogging/data/location_repository.dart';

// 현재 GPS 위치(출발지). 화면 진입 시 1회 조회. 실패 시 null({latitude, longitude, address}).
final currentLocationProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>(
  (ref) => LocationRepository().getCurrentLocation(),
);

// 사용자가 지도를 탭해 선택한 도착지 좌표 (위도, 경도). 미선택 시 null.
final destinationProvider =
    StateProvider.autoDispose<(double lat, double lon)?>((ref) => null);
