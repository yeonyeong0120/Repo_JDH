/// 환경 기여도(임팩트) 환산 유틸.
///
/// 수거량 → 온실가스 감축량 → 나무 그루 수로 환산한다.
///
/// ── 계수 근거 ──
/// • 수거 1kg → CO₂ 1.1kg 감축
///   한국환경공단: 폐플라스틱 18만 톤 재활용 → 온실가스 202,357톤 감축
///   (202,357 / 180,000 ≈ 1.12)
/// • CO₂ 6.6kg → 소나무 1그루
///   국립산림과학원 표준탄소흡수량: 30년생 소나무 1그루 연간 흡수량 6.6kg
/// • 목표: 연간 CO₂ 20kg 감축 (팀 논의로 조정 가능)
///
/// 계수를 바꾸려면 아래 상수만 고치면 전체에 반영된다.
class ImpactMetrics {
  /// 수거량 1kg 당 CO₂ 감축량(kg)
  static const double co2PerKg = 1.1;

  /// 소나무 1그루의 연간 CO₂ 흡수량(kg)
  static const double co2PerTree = 6.6;

  /// 연간 CO₂ 감축 목표(kg)
  static const double goalCo2Kg = 20.0;

  /// 수거 무게(g) → CO₂ 감축량(kg)
  static double co2FromGrams(int grams) {
    return (grams / 1000.0) * co2PerKg;
  }

  /// CO₂ 감축량(kg) → 나무 그루 수
  static double treesFromCo2(double co2Kg) {
    if (co2PerTree <= 0) return 0;
    return co2Kg / co2PerTree;
  }

  /// 목표 달성률 (0.0 ~ 1.0)
  static double goalProgress(double co2Kg) {
    if (goalCo2Kg <= 0) return 0;
    return (co2Kg / goalCo2Kg).clamp(0.0, 1.0);
  }

  /// 소수 1자리 문자열 (예: 9.7)
  static String oneDecimal(double v) => v.toStringAsFixed(1);

  /// 천단위 콤마 (예: 18400 → "18,400")
  static String comma(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}