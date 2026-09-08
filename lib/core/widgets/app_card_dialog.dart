import 'package:flutter/material.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';

/// PLOGGO 공용 센터 카드 팝업 — 디자인 명세 POPUPS.md 의 C형.
///
/// A형(`AppDialog`)과 다른 점: 카드가 더 좁고(좌우 26) 아이콘 원이 크며(62~66)
/// 제목·본문·버튼이 한 단계씩 작다. 결과를 알리거나 획득을 보여주는 자리에 쓴다.
/// (§4 공유 여부 · §5 퀘스트 완료 · §6 뱃지 획득 · §20~22 쿠폰·구매)
///
/// 골격: padding 22 · 아이콘 원 62 · 제목 800 19/1.4 · 본문 500 12.5/1.55 ·
/// 버튼 52 / 라운드 17 / 800 15.5.
class AppCardDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  /// 아이콘 원 배경. 기본은 라임.
  final Color iconBg;

  /// 아이콘 글리프 색·크기.
  final Color iconFg;
  final double iconSize;

  /// 아이콘 원 지름. 퀘스트·뱃지만 66이고 나머지는 62다.
  final double iconCircle;

  /// 아이콘 자리를 원이 아니라 라운드 사각으로 그린다 — §6 뱃지 전용.
  final double? iconRadius;

  /// 카드 라운드. 명세상 26~28 사이에서 팝업마다 다르다.
  final double cardRadius;

  const AppCardDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
    this.iconBg = AppColors.lime,
    this.iconFg = AppColors.ink,
    this.iconSize = 29,
    this.iconCircle = 62,
    this.iconRadius,
    this.cardRadius = 26,
  });

  /// 취소/확인 2버튼 카드 팝업.
  ///
  /// [barrierDismissible] 을 false 로 두면 딤을 눌러도 닫히지 않는다 —
  /// 결과를 반드시 인지시켜야 하는 팝업(§22 구매 완료)에 쓴다.
  static Future<bool?> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    bool barrierDismissible = true,
    Color iconBg = AppColors.lime,
    Color iconFg = AppColors.ink,
    double iconSize = 29,
    double iconCircle = 62,
    double? iconRadius,
    double cardRadius = 26,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: AppColors.barrierDim,
      builder: (ctx) => AppCardDialog(
        icon: icon,
        title: title,
        message: message,
        cancelText: cancelText,
        confirmText: confirmText,
        iconBg: iconBg,
        iconFg: iconFg,
        iconSize: iconSize,
        iconCircle: iconCircle,
        iconRadius: iconRadius,
        cardRadius: cardRadius,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconCircle,
              height: iconCircle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBg,
                shape: iconRadius == null ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: iconRadius == null
                    ? null
                    : BorderRadius.circular(iconRadius!),
              ),
              child: Icon(icon, size: iconSize, color: iconFg),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                height: 1.4,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.textPrimary,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray500,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _btn(
                    cancelText,
                    bg: AppColors.surfaceSoft,
                    fg: AppColors.gray700,
                    onTap: onCancel,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _btn(
                    confirmText,
                    bg: AppColors.ink,
                    fg: Colors.white,
                    onTap: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(
    String label, {
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }
}
