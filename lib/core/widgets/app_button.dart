import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';

/// 줍다행 공용 버튼.
/// 앱 전체 버튼을 이 위젯으로 통일 (primary / secondary / danger / quiet).
enum AppButtonType {
  /// 화면의 주 행동. 화면당 1개.
  primary,

  /// 보조 행동. 선(border)만 있는 버튼.
  secondary,

  /// 파괴적 행동 (종료 · 탈퇴 · 삭제).
  danger,

  /// 배경 없는 텍스트 버튼.
  quiet,
}

enum AppButtonSize {
  /// 높이 52 — 기본
  normal,

  /// 높이 44 — 카드 안, 다이얼로그 안
  compact,
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap; // null이거나 enabled=false면 비활성
  final AppButtonType type;
  final AppButtonSize size;
  final bool enabled;
  final bool expand; // true면 가로 전체 폭
  final bool loading; // true면 스피너 표시 + 입력 차단
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.normal,
    this.enabled = true,
    this.expand = true,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool on = enabled && onTap != null && !loading;
    final double height =
        size == AppButtonSize.normal ? Touch.button : Touch.min - 4;

    late final Color bg;
    late final Color fg;
    late final BorderSide side;

    if (!on && !loading) {
      bg = AppColors.neutral200;
      fg = AppColors.neutral500; // 비활성도 3:1 이상 유지
      side = BorderSide.none;
    } else {
      switch (type) {
        case AppButtonType.primary:
          bg = AppColors.actionPrimary;
          fg = AppColors.textOnBrand;
          side = BorderSide.none;
        case AppButtonType.secondary:
          bg = AppColors.surface;
          fg = AppColors.textPrimary;
          side = const BorderSide(color: AppColors.border);
        case AppButtonType.danger:
          bg = AppColors.actionDanger;
          fg = AppColors.textOnBrand;
          side = BorderSide.none;
        case AppButtonType.quiet:
          bg = Colors.transparent;
          fg = AppColors.actionPrimary;
          side = BorderSide.none;
      }
    }

    final Widget content = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                Gap.w8,
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label.copyWith(color: fg),
                ),
              ),
            ],
          );

    final Widget button = Material(
      color: bg,
      borderRadius: Radii.cardR,
      child: InkWell(
        onTap: on ? onTap : null,
        borderRadius: Radii.cardR,
        splashColor: AppColors.neutral900.withValues(alpha: 0.06),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: Radii.cardR,
            border: side == BorderSide.none ? null : Border.fromBorderSide(side),
          ),
          child: Center(child: content),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
