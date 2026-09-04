import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
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
    // Startline 스낵바: 면은 항상 잉크(다크 알약), 종류는 리딩 아이콘 색으로만 구분.
    late final IconData? icon;
    late final Color? iconColor;
    switch (kind) {
      case SnackKind.neutral:
        icon = null;
        iconColor = null;
      case SnackKind.success:
        icon = TablerIcons.circleCheckFilled;
        iconColor = AppColors.lime; // 다크 면 위 라임 포인트
      case SnackKind.error:
        icon = TablerIcons.alertCircleFilled;
        iconColor = AppColors.actionDanger;
    }

    _show(
      context,
      bg: AppColors.ink,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: iconColor),
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
      bg: AppColors.ink,
      duration: duration,
      content: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            // 로딩 스피너는 라임(다크 면 위 포인트).
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.lime),
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
          // 떠 있는 다크 알약: 완전 둥근 모서리.
          shape: RoundedRectangleBorder(borderRadius: Radii.fullR),
          margin: const EdgeInsets.fromLTRB(
            Gap.lg,
            0,
            Gap.lg,
            Gap.lg,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.xl,
            vertical: Gap.md,
          ),
          action: (actionLabel != null && onAction != null)
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: AppColors.lime,
                  onPressed: onAction,
                )
              : null,
        ),
      );
  }
}
