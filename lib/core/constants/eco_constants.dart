/// 환경 영향 환산 계수 (앱 전역 단일 소스).
///
/// 이 값들은 home 의 `EcoMath` 와 mypage 의 `ImpactMetrics` 양쪽에서 쓰인다.
/// 과거 두 곳이 각자 리터럴을 들고 있다가 값이 어긋난 적이 있으므로,
/// 계수 자체는 반드시 이 파일에서만 정의한다.
/// 화면에는 "추정치"임을 함께 표기할 것.
class EcoConstants {
  EcoConstants._();

  /// 수거량 1kg 당 CO₂ 감축량 (kg).
  ///
  /// 출처: 한국환경공단 — 폐플라스틱 18만 톤 재활용 시
  /// 온실가스 202,357톤 감축. 202,357 / 180,000 ≈ 1.12 이므로 1.1 로 반올림.
  static const double co2PerTrashKg = 1.1;

  /// 30년생 소나무 1그루가 1년간 흡수하는 CO₂ (kg).
  ///
  /// 출처: 국립산림과학원 표준탄소흡수량.
  static const double co2PerPineTreeYear = 6.6;
}
