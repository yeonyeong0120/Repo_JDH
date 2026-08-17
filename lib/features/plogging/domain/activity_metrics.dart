/// 활동 데이터 → 화면 표시값 변환 유틸.
///
/// 서버(Activity)에는 거리·시간·수거 개수만 있고,
/// 화면이 원하는 '걸음 수 / 칼로리 / 무게(g)'는 없다.
/// → 여기서 거리·개수를 기반으로 추정 계산한다.
///
/// ⚠️ 걸음·칼로리는 '추정값'이다.
///    나중에 Health Connect 를 연동하면, 아래 estimateSteps / estimateKcal 을
///    실제 측정값으로 교체하면 된다. (계산 로직이 이 파일에만 모여 있으므로 교체 쉬움)
class ActivityMetrics {
  // ── 카테고리별 개당 평균 무게(g) ──
  // TODO: 실측 데이터가 쌓이면 실제 평균으로 보정
  static const Map<String, int> _avgWeightG = {
    'can': 15, // 음료 캔
    'glass': 200, // 유리병
    'paper': 10, // 종이류
    'plastic': 30, // 페트병·비닐
    'trash': 20, // 일반 쓰레기
  };

  // 무게표에 없는 종류가 들어와도 앱이 안 깨지게 하는 기본값
  static const int _defaultWeightG = 20;

  // 평균 보폭(m). 걸음 수 = 거리 ÷ 보폭
  static const double _strideMeters = 0.75;

  // 칼로리 추정 계수: 1km 당 약 50kcal (평균 성인 걷기 대략치)
  static const double _kcalPerKm = 50.0;

  /// 수거 무게(g) — 카테고리별 (개수 × 평균무게) 합산
  ///
  /// 예) 캔3 + 유리1 + 종이5 = 15*3 + 200*1 + 10*5 = 295g
  static int weightGrams(Map<String, int> trashCounts) {
    int total = 0;
    trashCounts.forEach((category, count) {
      final perItem = _avgWeightG[category] ?? _defaultWeightG;
      total += perItem * count;
    });
    return total;
  }

  /// 걸음 수 추정 — 거리(m) ÷ 보폭
  /// TODO: Health Connect 연동 시 실측 걸음 수로 교체
  static int estimateSteps(double distanceMeters) {
    if (distanceMeters <= 0) return 0;
    return (distanceMeters / _strideMeters).round();
  }

  /// 칼로리 추정 — 거리(km) × 계수
  /// TODO: Health Connect 연동 시 실측 칼로리로 교체
  static int estimateKcal(double distanceMeters) {
    if (distanceMeters <= 0) return 0;
    return (distanceMeters / 1000.0 * _kcalPerKm).round();
  }

  /// 소요 시간(초) → "분:초" 문자열 (예: 1830초 → "30:30")
  static String durationLabel(int durationSeconds) {
    if (durationSeconds <= 0) return '0:00';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// 무게 라벨 — g 이 1000 넘으면 kg 으로 (예: 295 → "295 g", 1300 → "1.3 kg")
  static String weightLabel(Map<String, int> trashCounts) {
    final g = weightGrams(trashCounts);
    if (g >= 1000) {
      final kg = g / 1000.0;
      return '${kg.toStringAsFixed(1)} kg';
    }
    return '$g g';
  }

  /// 활동 제목 — 역지오코딩된 장소명이 있으면 그것, 없으면 그룹 여부로 폴백.
  ///
  /// 기록 탭·전체 활동 기록 어디서 열든 같은 문구가 나오도록
  /// 폴백 규칙을 여기 한 곳에서만 정한다 (화면마다 복제하면 어긋난다).
  static String placeLabel({String? placeName, String? groupId}) {
    final name = placeName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return groupId != null ? '그룹 플로깅' : '플로깅 기록';
  }

  /// 날짜 라벨 — DateTime → "26.02.01 06:15"
  static String dateTimeLabel(DateTime dt) {
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$yy.$mm.$dd $hh:$min';
  }
}
