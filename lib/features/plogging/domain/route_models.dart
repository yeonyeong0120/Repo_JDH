// 경로 추천 도메인 모델.
// 서버 POST /route/recommend 응답(인계 문서 3-1절)과 1:1 대응한다.
// 지도 라이브러리에 의존하지 않는 순수 Dart 모델로 둔다. NLatLng 변환은 화면(presentation)에서 한다.

// 선정된 경유 핫스팟 1곳.
class RouteHotspot {
  final String hotspotId;
  final double latitude;
  final double longitude;
  final double sI; // 감시 밀도 점수 S_i
  final double avoidPenalty;

  const RouteHotspot({
    required this.hotspotId,
    required this.latitude,
    required this.longitude,
    required this.sI,
    required this.avoidPenalty,
  });

  factory RouteHotspot.fromJson(Map<String, dynamic> json) {
    return RouteHotspot(
      hotspotId: json['hotspot_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      sI: (json['S_i'] as num).toDouble(),
      avoidPenalty: (json['avoid_penalty'] as num).toDouble(),
    );
  }
}

// 경로 추천 결과 전체.
class RouteResult {
  final bool success;
  final bool isHardCase; // true면 회피 영역을 완전히 피하지 못한 경로
  final int intersectionM; // 회피 영역 통과 길이(m) — hard case 알림에 사용
  final double intersectionRatio;
  final List<String> crossedUqaCodes;
  final List<List<double>> polyline; // 각 원소 [lat, lon]
  final int distanceM;
  final int durationMs;
  final int nSwaps;
  final int? bestFromAttempt;
  final List<RouteHotspot> k3Hotspots; // 방문 순서 = 배열 순서

  const RouteResult({
    required this.success,
    required this.isHardCase,
    required this.intersectionM,
    required this.intersectionRatio,
    required this.crossedUqaCodes,
    required this.polyline,
    required this.distanceM,
    required this.durationMs,
    required this.nSwaps,
    required this.bestFromAttempt,
    required this.k3Hotspots,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    return RouteResult(
      success: json['success'] as bool? ?? false,
      isHardCase: json['is_hard_case'] as bool? ?? false,
      intersectionM: (json['intersection_m'] as num?)?.toInt() ?? 0,
      intersectionRatio: (json['intersection_ratio'] as num?)?.toDouble() ?? 0.0,
      crossedUqaCodes: (json['crossed_uqa_codes'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      polyline: (json['polyline'] as List<dynamic>? ?? const [])
          .map((p) => (p as List<dynamic>).map((c) => (c as num).toDouble()).toList())
          .toList(),
      distanceM: (json['distance_m'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      nSwaps: (json['n_swaps'] as num?)?.toInt() ?? 0,
      bestFromAttempt: (json['best_from_attempt'] as num?)?.toInt(),
      k3Hotspots: (json['k3_hotspots'] as List<dynamic>? ?? const [])
          .map((e) => RouteHotspot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
