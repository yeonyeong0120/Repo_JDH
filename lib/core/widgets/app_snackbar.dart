import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';

/// 스낵바 종류. 색은 여기서만 결정한다.
enum SnackKind { neutral, success, error }

/// 토스트 면 색 — 디자인 명세 POPUPS.md Ⅴ.
/// 화면마다 다르다: 홈·쿠폰함은 라임, 나머지는 잉크.
enum SnackTone { dark, lime }

/// PLOGGO 공용 스낵바.
///
/// ```dart
/// AppSnackBar.show(context, '그룹에서 탈퇴했어요');
/// AppSnackBar.show(context, '활동을 저장했어요', kind: SnackKind.success);
/// AppSnackBar.show(context, '업로드에 실패했어요', kind: SnackKind.error);
/// AppSnackBar.showLoading(context, '이미지 업로드 중...');
/// ```
class AppSnackBar {
  AppSnackBar._();

  /// 하단에 잉크 CTA 버튼이 있는 화면에서 쓰는 bottom 값.
  ///
  /// 기본값(34)으로 띄우면 토스트가 버튼 위에 그대로 겹친다. 둘 다 잉크 면이라
  /// 겹치면 경계가 사라져 무엇이 버튼인지 구분되지 않는다. CTA 높이(64) +
  /// 아래 여백(8) + SafeArea 최소치(12) + 간격을 더한 값이다.
  static const double aboveCta = 100;

  static void show(
    BuildContext context,
    String message, {
    SnackKind kind = SnackKind.neutral,
    Duration duration = const Duration(milliseconds: 2600),
    String? actionLabel,
    VoidCallback? onAction,
    IconData? icon,
    double? iconSize,
    SnackTone tone = SnackTone.dark,
    double bottom = 34,
    @Deprecated('kind: SnackKind.neutral 이 기본값이므로 그냥 지우면 된다')
    bool neutral = false,
  }) {
    // neutral: true 는 기본값과 같으므로 무시해도 결과가 같다.
    // Startline 스낵바: 면은 항상 잉크(다크 알약), 종류는 리딩 아이콘 색으로만 구분.
    final bool onLime = tone == SnackTone.lime;
    final Color bg = onLime ? AppColors.lime : AppColors.ink;
    final Color fg = onLime ? AppColors.limeOn : AppColors.neutral0;

    // 호출부가 아이콘을 지정하면 그것을 쓰고, 아니면 kind 로 떨어진다.
    late final IconData? glyph;
    late final Color glyphColor;
    if (icon != null) {
      glyph = icon;
      // 잉크 면 위에서는 라임 글리프, 라임 면 위에서는 잉크 글리프.
      glyphColor = onLime ? AppColors.limeOn : AppColors.lime;
    } else {
      switch (kind) {
        case SnackKind.neutral:
          glyph = null;
          glyphColor = fg;
        case SnackKind.success:
          glyph = TablerIcons.circleCheckFilled;
          glyphColor = onLime ? AppColors.limeOn : AppColors.lime;
        case SnackKind.error:
          glyph = TablerIcons.alertCircleFilled;
          glyphColor = AppColors.actionDanger;
      }
    }

    _show(
      context,
      bg: bg,
      // 잉크 면 토스트가 잉크 버튼과 맞닿아도 경계가 보이도록 얇은 테두리를 둔다.
      borderColor: onLime
          ? AppColors.limeOn.withValues(alpha: 0.14)
          : AppColors.neutral0.withValues(alpha: 0.22),
      duration: duration,
      bottom: bottom,
      actionLabel: actionLabel,
      onAction: onAction,
      content: Row(
        children: [
          if (glyph != null) ...[
            Icon(glyph, size: iconSize ?? 19, color: glyphColor),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              // 아이콘 없는 안내는 가운데 정렬
              textAlign: glyph == null ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
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
    double bottom = 34,
    Color? borderColor,
  }) {
    ScaffoldMessenger.of(context)
      // 앞 토스트를 걷어내지 않으면 그쪽 타이머가 뒤 토스트를 지운다.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: content,
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          // 명세: box-shadow 0 12px 30px rgba(25,30,36,.22~.28)
          elevation: 10,
          duration: duration,
          // 알약(999)이 아니라 라운드 18. 같은 색 면과 겹칠 때를 위해 얇은
          // 테두리를 둔다(지정 없으면 테두리 없음).
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor, width: 1),
          ),
          // 명세: left/right 20, 화면별 bottom
          margin: EdgeInsets.fromLTRB(20, 0, 20, bottom),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
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
