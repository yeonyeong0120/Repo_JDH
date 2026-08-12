import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';

/// 스낵바 종류. 색은 여기서만 결정한다.
enum SnackKind { neutral, success, error }

/// Ploggo 공용 스낵바.
///
/// ```dart
/// AppSnackBar.show(context, '그룹에서 탈퇴했어요');
/// AppSnackBar.show(context, '활동을 저장했어요', kind: SnackKind.success);
/// AppSnackBar.show(context, '업로드에 실패했어요', kind: SnackKind.error);
/// AppSnackBar.showLoading(context, '이미지 업로드 중...');
/// ```
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    SnackKind kind = SnackKind.neutral,
    Duration duration = const Duration(seconds: 3), // 중장년 기준 2초는 짧음
    String? actionLabel,
    VoidCallback? onAction,
    @Deprecated('kind: SnackKind.neutral 이 기본값이므로 그냥 지우면 된다')
    bool neutral = false,
  }) {
    // neutral: true 는 기본값과 같으므로 무시해도 결과가 같다.
    late final Color bg;
    late final IconData? icon;
    switch (kind) {
      case SnackKind.neutral:
        bg = AppColors.neutral900;
        icon = null;
      case SnackKind.success:
        bg = AppColors.green800;
        icon = Icons.check_circle_rounded;
      case SnackKind.error:
        bg = AppColors.actionDanger;
        icon = Icons.error_rounded;
    }

    _show(
      context,
      bg: bg,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: AppColors.neutral0),
            Gap.w12,
          ],
          Expanded(
            child: Text(
              message,
              // 아이콘 없는 안내는 가운데 정렬
              textAlign: icon == null ? TextAlign.center : TextAlign.start,
              style: AppType.label.copyWith(color: AppColors.neutral0),
            ),
          ),
        ],
      ),
    );
  }

  /// 스피너 + 텍스트. 완료되면 hide()로 직접 닫을 것.
  static void showLoading(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 10),
  }) {
    _show(
      context,
      bg: AppColors.neutral900,
      duration: duration,
      content: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.green300),
            ),
          ),
          Gap.w12,
          Expanded(
            child: Text(
              message,
              style: AppType.label.copyWith(color: AppColors.neutral0),
            ),
          ),
        ],
      ),
    );
  }

  static void hide(BuildContext context) =>
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

  static void _show(
    BuildContext context, {
    required Widget content,
    required Color bg,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: content,
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          duration: duration,
          shape: RoundedRectangleBorder(borderRadius: Radii.tileR),
          margin: const EdgeInsets.fromLTRB(
            Gap.lg,
            0,
            Gap.lg,
            Gap.lg,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.lg,
          ),
          action: (actionLabel != null && onAction != null)
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: AppColors.green300,
                  onPressed: onAction,
                )
              : null,
        ),
      );
  }
}
