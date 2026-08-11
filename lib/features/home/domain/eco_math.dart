import 'package:repo_jdh/core/constants/eco_constants.dart';

/// 환경 영향 환산식.
/// ⚠ 계수는 반드시 출처와 함께 확정하고, 화면에는 "추정치"임을 표기할 것.
/// 홈 카드의 "계산 방법" 링크가 이 값들을 설명하는 화면으로 연결된다.
///
/// 계수 자체는 `EcoConstants` 한 곳에서만 정의한다. 여기서는 재노출만 한다.
class EcoMath {
  EcoMath._();

  /// 폐기물 1kg 재활용 시 감축되는 CO2 (kg).
  /// 출처는 [EcoConstants.co2PerTrashKg] 참조.
  static const double co2PerTrashKg = EcoConstants.co2PerTrashKg;

  /// 30년생 소나무 1그루가 1년간 흡수하는 CO2 (kg).
  /// 출처는 [EcoConstants.co2PerPineTreeYear] 참조.
  static const double co2PerPineTreeYear = EcoConstants.co2PerPineTreeYear;

  /// 수거량(kg) → 탄소 감축량(kg)
  static double carbonKg(double trashKg) => trashKg * co2PerTrashKg;

  /// 탄소 감축량(kg) → 소나무 그루 수
  static double pineTrees(double carbonKg) => carbonKg / co2PerPineTreeYear;

  /// 30분 활동 시 기대 수거량(kg) — 첫날 화면 문구용.
  /// TODO: 실제 사용자 평균으로 교체.
  static const double avgTrashKgPer30min = 0.3;
}
