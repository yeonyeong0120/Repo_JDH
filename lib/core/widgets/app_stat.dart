import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';

/// 수치 표기 위젯.
/// 앱의 핵심 성취(걸음·수거량·칼로리·포인트)는 반드시 이걸로 그린다.
/// - 고정폭 숫자라 값이 바뀌어도 폭이 흔들리지 않음
/// - 단위는 숫자보다 작고 회색으로 분리
/// - 라벨은 caption
///
/// ```dart
/// StatValue(value: '2,000', label: '걸음')
/// StatValue(value: '1.3', unit: 'kg', label: '수거량')
/// StatValue(value: '5,000', unit: 'P', size: StatSize.large, brand: true)
/// ```
enum StatSize {
  /// 34 — 트래킹 타이머, 총 포인트
  large,

  /// 20 — 카드 안 통계 3분할
  normal,

  /// 17 — 리스트 항목 안 인라인 수치
  small,
}

class StatValue extends StatelessWidget {
  final String value;
  final String? unit;
  final String? label;
  final StatSize size;
  final bool brand; // true면 초록, false면 neutral900
  final CrossAxisAlignment align;

  const StatValue({
    super.key,
    required this.value,
    this.unit,
    this.label,
    this.size = StatSize.normal,
    this.brand = false,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    late final TextStyle numStyle;
    late final double unitSize;
    switch (size) {
      case StatSize.large:
        numStyle = AppType.display;
        unitSize = 16;
      case StatSize.normal:
        numStyle = AppType.title2.copyWith(fontWeight: FontWeight.w800);
        unitSize = 14;
      case StatSize.small:
        numStyle = AppType.title3.copyWith(fontWeight: FontWeight.w800);
        unitSize = 13;
    }

    final Color numColor = brand ? AppColors.textBrand : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            text: value,
            style: numStyle.tabular.copyWith(color: numColor),
            children: [
              if (unit != null)
                TextSpan(
                  text: unit,
                  style: AppType.label.copyWith(
                    fontSize: unitSize,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (label != null) ...[
          Gap.h4,
          Text(
            label!,
            style: AppType.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// 진행 바. 레벨 XP · 퀘스트 달성률 공용.
/// 색을 넘기면 그 색으로(퀘스트 카테고리별), 안 넘기면 브랜드 초록.
class AppProgressBar extends StatelessWidget {
  final double value; // 0.0 ~ 1.0
  final Color? color;
  final double height;

  const AppProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: AppColors.neutral100,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.actionPrimary,
        ),
      ),
    );
  }
}

/// 카드 상단 분류 라벨. 반드시 색과 함께 쓴다.
/// 예) '연속 기록'(reward), '이번 주'(brand)
class AppOverline extends StatelessWidget {
  final String text;
  final Color color;

  const AppOverline(this.text, {super.key, this.color = AppColors.textBrand});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppType.overline.copyWith(color: color));
  }
}
