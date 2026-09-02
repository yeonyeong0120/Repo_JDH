import 'package:repo_jdh/features/plogging/domain/geo_distance.dart';

/// 활동 완료 시 지급하는 에코 포인트 계산.
/// 정책 상수를 전부 이 파일에 모아 조정 지점을 하나로 둔다.
class ActivityPoints {
  ActivityPoints._();

  static const int base = 100; // 활동 1회 기본 지급
  static const double completionBonusRatio = 0.3; // 완주(목적지 도달) 보너스 = 기본의 30%
  static const int perTrash = 20; // 쓰레기 1개당

  /// 목적지 반경 이 안이면 도착으로 인정 (GPS 오차 허용치)
  static const double arrivalRadiusMeters = 50;

  static int get completionBonus => (base * completionBonusRatio).round(); // 30

  /// 도착 좌표와 목적지 좌표를 비교해 도착 여부 판정.
  /// 둘 중 하나라도 없으면(목적지 정보 없음 등) false.
  static bool reachedDestination({
    double? endLat,
    double? endLng,
    double? destLat,
    double? destLng,
  }) {
    if (endLat == null || endLng == null || destLat == null || destLng == null) {
      return false;
    }
    return GeoDistance.metersBetween(endLat, endLng, destLat, destLng) <=
        arrivalRadiusMeters;
  }

  /// 지급 포인트 계산 (총합 + 내역)
  static ({int total, int base, int trashPoints, int completionBonus}) calculate({
    required int totalTrash,
    required bool reachedDestination,
  }) {
    final trashPoints = totalTrash * perTrash;
    final bonus = reachedDestination ? completionBonus : 0;
    return (
      total: base + trashPoints + bonus,
      base: base,
      trashPoints: trashPoints,
      completionBonus: bonus,
    );
  }
}
