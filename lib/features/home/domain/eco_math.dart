/// 환경 영향 환산식.
/// ⚠ 계수는 반드시 출처와 함께 확정하고, 화면에는 "추정치"임을 표기할 것.
/// 홈 카드의 "계산 방법" 링크가 이 값들을 설명하는 화면으로 연결된다.
class EcoMath {
  EcoMath._();

  /// 폐기물 1kg 재활용 시 감축되는 CO2 (kg).
  /// TODO: 환경부/한국환경공단 공식 계수로 교체 후 출처 URL 기재.
  static const double co2PerTrashKg = 0.66;

  /// 30년생 소나무 1그루가 1년간 흡수하는 CO2 (kg).
  /// 산림청 기준값. 확정 시 출처 표기.
  static const double co2PerPineTreeYear = 6.6;

  /// 수거량(kg) → 탄소 감축량(kg)
  static double carbonKg(double trashKg) => trashKg * co2PerTrashKg;

  /// 탄소 감축량(kg) → 소나무 그루 수
  static double pineTrees(double carbonKg) => carbonKg / co2PerPineTreeYear;

  /// 30분 활동 시 기대 수거량(kg) — 첫날 화면 문구용.
  /// TODO: 실제 사용자 평균으로 교체.
  static const double avgTrashKgPer30min = 0.3;
}
