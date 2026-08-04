import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';

/// 줍다행 공용 팝업.
/// 제목 + 본문 + 버튼(1개 또는 2개). 버튼은 AppButton으로 통일.
class AppDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final bool danger; // 확정 버튼을 파괴적 행동으로 표시
  final bool isInfo; // true면 버튼 1개(확인)만

  /// true면 '취소'를 주 버튼으로 강조.
  /// 실수로 뜰 수 있는 파괴적 팝업(활동 취소 등)에서 안전한 선택을 강조.
  final bool primaryIsCancel;

  const AppDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = '취소',
    this.confirmText = '확인',
    this.danger = false,
    this.isInfo = false,
    this.primaryIsCancel = false,
  });

  /// 확인/취소 2버튼 팝업. 확인=true / 취소·바깥탭=false 또는 null
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    bool danger = false,
    bool primaryIsCancel = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: AppColors.neutral900.withValues(alpha: 0.45),
      builder: (_) => AppDialog(
        title: title,
        message: message,
        cancelText: cancelText,
        confirmText: confirmText,
        danger: danger,
        primaryIsCancel: primaryIsCancel,
      ),
    );
  }

  /// 버튼 1개(확인)짜리 안내 팝업.
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = '확인',
    bool danger = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: AppColors.neutral900.withValues(alpha: 0.45),
      builder: (_) => AppDialog(
        title: title,
        message: message,
        confirmText: buttonText,
        danger: danger,
        isInfo: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confirmType = danger ? AppButtonType.danger : AppButtonType.primary;

    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: Gap.xl3),
      shape: RoundedRectangleBorder(borderRadius: Radii.sheetR),
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppType.title2),
            Gap.h8,
            Text(
              message,
              style: AppType.bodyLarge.copyWith(color: AppColors.textSecondary),
            ),
            Gap.h24,
            if (isInfo)
              AppButton(
                label: confirmText,
                type: confirmType,
                size: AppButtonSize.compact,
                onTap: () => Navigator.pop(context),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: cancelText,
                      type: primaryIsCancel
                          ? AppButtonType.primary
                          : AppButtonType.secondary,
                      size: AppButtonSize.compact,
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: AppButton(
                      label: confirmText,
                      type: primaryIsCancel
                          ? AppButtonType.secondary
                          : confirmType,
                      size: AppButtonSize.compact,
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
