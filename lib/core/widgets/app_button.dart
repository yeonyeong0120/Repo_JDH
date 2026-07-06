import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 줍다행 공용 버튼.
/// 앱 전체 버튼을 이 위젯으로 통일 (primary / secondary / danger).
/// 위치 권장: lib/core/widgets/app_button.dart
enum AppButtonType { primary, secondary, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap; // null이거나 enabled=false면 비활성
  final AppButtonType type;
  final bool enabled;
  final bool expand; // true면 가로 전체 폭

  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.type = AppButtonType.primary,
    this.enabled = true,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool on = enabled && onTap != null;

    late final Color bg;
    late final Color fg;

    if (!on) {
      // 비활성
      bg = AppColors.divider;
      fg = AppColors.textTertiary;
    } else {
      switch (type) {
        case AppButtonType.primary:
          bg = AppColors.primary;
          fg = Colors.white;
          break;
        case AppButtonType.secondary:
          bg = AppColors.appBG;
          fg = AppColors.textSecondary;
          break;
        case AppButtonType.danger:
          bg = AppColors.error;
          fg = Colors.white;
          break;
      }
    }

    final Widget button = GestureDetector(
      onTap: on ? onTap : null,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: (on && type == AppButtonType.primary)
              ? AppColors.buttonShadow
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
