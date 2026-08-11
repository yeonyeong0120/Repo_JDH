import 'package:repo_jdh/core/constants/eco_constants.dart';

/// 환경 기여도(임팩트) 환산 유틸.
///
/// 수거량 → 온실가스 감축량 → 나무 그루 수로 환산한다.
///
/// CO₂·소나무 계수는 근거와 함께 `EcoConstants` 한 곳에서만 정의한다.
/// 계수를 바꾸려면 그 파일을 고친다. 여기서 리터럴을 다시 쓰지 않는다.
/// 목표치(`goalCo2Kg`)는 mypage 화면 전용이라 이 파일에 남긴다.
class ImpactMetrics {
  /// 수거량 1kg 당 CO₂ 감축량(kg)
  static const double co2PerKg = EcoConstants.co2PerTrashKg;

  /// 소나무 1그루의 연간 CO₂ 흡수량(kg)
  static const double co2PerTree = EcoConstants.co2PerPineTreeYear;

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