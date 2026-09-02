import 'dart:math' as math;

/// 위경도 좌표 사이 거리 계산. 짧은 거리(도보 활동 반경)라 평면 근사로 충분하다.
class GeoDistance {
  GeoDistance._();

  static const double _mLat = 110540; // 위도 1도의 미터

  /// 두 좌표 사이 직선 거리(m).
  static double metersBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final refLat = (lat1 + lat2) / 2 * math.pi / 180;
    final mLon = 111320 * math.cos(refLat);
    final dx = (lon2 - lon1) * mLon;
    final dy = (lat2 - lat1) * _mLat;
    return math.sqrt(dx * dx + dy * dy);
  }
}
