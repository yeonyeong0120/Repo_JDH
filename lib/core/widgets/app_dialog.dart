import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 줍다행 공용 팝업 위젯.
/// 둥근 카드 + 연회색 채움 보조 버튼 + 색 채움 주 버튼(좌우 나란히).
/// 버튼 1개짜리 안내용은 AppDialog.showInfo 사용.
/// 위치 권장: lib/core/widgets/app_dialog.dart
class AppDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final bool danger; // 주 버튼(강조) 색: true 빨강 / false 초록
  final bool isInfo; // true면 버튼 1개(확인)만
  // true면 강조(주 버튼)를 '취소' 쪽에 둠 → 파괴적 확정 버튼을 덜 강조.
  // 실수로 뜰 수 있는 팝업(활동 취소 등)에서 안전한 선택을 강조할 때 사용.
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
    final Color confirmColor = danger ? AppColors.error : AppColors.primary;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                height: 1.75,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            if (isInfo)
              // 버튼 1개 (꽉 찬 주 버튼)
              _button(
                label: confirmText,
                bg: confirmColor,
                fg: Colors.white,
                onTap: () => Navigator.pop(context),
              )
            else
              Builder(
                builder: (context) {
                  // 확인 동작(pop true) / 취소 동작(pop false)
                  final confirmBtn = _button(
                    label: confirmText,
                    bg: primaryIsCancel ? AppColors.appBG : confirmColor,
                    fg: primaryIsCancel
                        ? AppColors.textSecondary
                        : Colors.white,
                    onTap: () => Navigator.pop(context, true),
                  );
                  final cancelBtn = _button(
                    label: cancelText,
                    bg: primaryIsCancel ? AppColors.primary : AppColors.appBG,
                    fg: primaryIsCancel
                        ? Colors.white
                        : AppColors.textSecondary,
                    onTap: () => Navigator.pop(context, false),
                  );
                  // 오른쪽 = 강조(색 채움) 자리 고정.
                  // 기본: 오른쪽 확인 / primaryIsCancel: 오른쪽 취소
                  final left = primaryIsCancel ? confirmBtn : cancelBtn;
                  final right = primaryIsCancel ? cancelBtn : confirmBtn;
                  return Row(
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 10),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _button({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
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
  }
}
