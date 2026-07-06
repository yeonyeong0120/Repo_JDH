import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 줍다행 공용 스낵바.
/// 하단에서 살짝 떠서 둥근 형태로 나타났다 사라지는 알림.
/// 위치 권장: lib/core/widgets/app_snackbar.dart
///
/// 사용 예:
/// ```dart
/// AppSnackBar.show(context, '그룹에서 탈퇴했어요');           // 기본(초록)
/// AppSnackBar.show(context, '이미지 업로드 중...', neutral: true); // 중립(회색)
/// ```
class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    bool neutral = false, // true면 회색 중립 톤
    Duration duration = const Duration(seconds: 2),
  }) {
    final Color bg = neutral ? AppColors.textPrimary : AppColors.primary;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
  }

  /// 로딩 표시가 필요한 경우 (스피너 + 텍스트, 길게 유지)
  static void showLoading(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          duration: duration,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
  }
}
