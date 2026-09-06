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

  // ── 칼로리 추정 (MET 공식: kcal = MET × 체중(kg) × 시간(h)) ──
  // 플로깅은 쓰레기를 줍느라 자주 멈춰(카메라 인증 중엔 트래킹이 멈추지 않음)
  // 일반 도보 기준보다 평균 속도가 낮게 나온다. 경계값을 도보 기준보다 낮춰뒀다.
  // 실사용 데이터가 쌓이면 재조정 필요 — 현재는 추정치.
  static const double _metSlow = 2.8; // 평균 속도가 낮은(정지 구간이 많은) 세션
  static const double _metModerate = 3.3; // 전형적인 플로깅 페이스
  static const double _metFast = 3.8; // 정지가 적은 세션
  static const double _slowSpeedKmh = 2.5;
  static const double _fastSpeedKmh = 4.0;

  // 체중 폴백(kg) — 프로필에 체중이 없을 때 쓰는 표준체중.
  // 근거: 국민건강보험공단 건강검진통계 평균신장 165.22cm(KOSIS 100대지표) 기준
  //   표준체중 = 키(m)^2 × 22 → 1.652^2 × 22 ≈ 60kg.
  //   '평균'은 성별 차가 커 단일값으로 말할 수 없고(플로고는 성별을 받지 않음),
  //   표준체중은 산식 근거가 명확해 폴백값으로 채택.
  static const double _standardWeightKg = 60;

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

  /// 칼로리 추정 — MET × 체중 × 시간. 속도(거리÷시간)로 MET 구간을 고른다.
  /// weightKg 가 없으면(프로필 미입력) 표준체중 60kg 으로 대체한다.
  /// TODO: Health Connect 연동 시 실측 칼로리로 교체
  static int estimateKcal({
    required double distanceMeters,
    required int durationSeconds,
    double? weightKg,
  }) {
    if (distanceMeters <= 0 || durationSeconds <= 0) return 0;
    final hours = durationSeconds / 3600.0;
    final speedKmh = (distanceMeters / 1000.0) / hours;
    final met = speedKmh < _slowSpeedKmh
        ? _metSlow
        : (speedKmh <= _fastSpeedKmh ? _metModerate : _metFast);
    final weight = weightKg ?? _standardWeightKg;
    return (met * weight * hours).round();
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
