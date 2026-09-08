import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// PLOGGO 공용 팝업 — 디자인 명세 POPUPS.md 의 A형(센터 다이얼로그).
///
/// 라운드 28 · 좌우 inset 30 · padding 26/24/20 · 아이콘 원 58 ·
/// 제목 21/800 · 본문 13.5/500 gray500 · 버튼 54/라운드 18/800 16.
/// 팝업마다 다른 것(아이콘 원 색·글리프 크기·버튼 배치)은 인자로 받는다.
class AppDialog extends StatelessWidget {
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final bool danger; // 확정 버튼을 파괴적 행동으로 표시(빨간 확인 버튼)
  final bool warn; // 아이콘만 경고(빨강)로, 확인 버튼은 초록 유지
  final bool isInfo; // true면 버튼 1개(확인)만

  /// true면 '취소'를 주 버튼으로 강조.
  /// 실수로 뜰 수 있는 파괴적 팝업(활동 취소 등)에서 안전한 선택을 강조.
  final bool primaryIsCancel;

  /// 제목 위 아이콘 원에 쓸 아이콘. 없으면 danger 여부에 따라 기본값.
  final IconData? icon;

  /// 아이콘 원 배경. 팝업마다 다르다(#F7FBE4 · #FDEBE7 · #E9FF6A · #F2F4F3).
  /// 지정하지 않으면 danger/warn 여부로 정한다.
  final Color? iconBg;

  /// 아이콘 글리프 색. 지정하지 않으면 iconBg 와 짝이 되는 기본값.
  final Color? iconFg;

  /// 아이콘 글리프 크기. 명세상 26~29 사이로 팝업마다 다르다.
  final double iconSize;

  /// true 면 아이콘 원을 그리지 않는다 — 로그아웃 팝업(§17) 전용.
  final bool hideIcon;

  /// true 면 버튼을 세로로 쌓는다. 되돌릴 수 없는 선택에서 안전한 쪽을
  /// 위·다크로 올리기 위한 배치다(§2 활동 취소 · §7.2 그룹장 위임).
  final bool verticalButtons;

  /// 파괴적 확인 버튼을 연회색 면 + 빨강 글자로 낮춘다.
  /// 명세의 파괴적 실행은 두 형태가 있다 — 빨강 면(#E4573D)과 이 형태.
  /// 세로 배치에서는 아래쪽 파괴 버튼이 이 형태다.
  final bool softDanger;

  /// 본문과 버튼 사이에 끼우는 위젯. 명세에서 이 자리에 카드가 붙는
  /// 팝업이 있다(§10 내 그룹 카드 · §7.2 승계자 카드).
  final Widget? extra;

  const AppDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelText = '취소',
    this.confirmText = '확인',
    this.danger = false,
    this.warn = false,
    this.isInfo = false,
    this.primaryIsCancel = false,
    this.icon,
    this.iconBg,
    this.iconFg,
    this.iconSize = 27,
    this.hideIcon = false,
    this.verticalButtons = false,
    this.softDanger = false,
    this.extra,
  });

  /// 확인/취소 2버튼 팝업. 확인=true / 취소·바깥탭=false 또는 null
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    bool danger = false,
    bool warn = false,
    bool primaryIsCancel = false,
    bool barrierDismissible = true,
    IconData? icon,
    Color? iconBg,
    Color? iconFg,
    double iconSize = 27,
    bool hideIcon = false,
    bool verticalButtons = false,
    bool softDanger = false,
    Color? barrierColor,
    Widget? extra,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      // 트래킹 팝업만 지도 위라 더 어두운 딤을 넘겨 받는다.
      barrierColor: barrierColor ?? _barrier,
      builder: (_) => AppDialog(
        title: title,
        message: message,
        cancelText: cancelText,
        confirmText: confirmText,
        danger: danger,
        warn: warn,
        primaryIsCancel: primaryIsCancel,
        icon: icon,
        iconBg: iconBg,
        iconFg: iconFg,
        iconSize: iconSize,
        hideIcon: hideIcon,
        verticalButtons: verticalButtons,
        softDanger: softDanger,
        extra: extra,
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
    IconData? icon,
    Color? iconBg,
    Color? iconFg,
    double iconSize = 27,
    Widget? extra,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: _barrier,
      builder: (_) => AppDialog(
        title: title,
        message: message,
        confirmText: buttonText,
        danger: danger,
        isInfo: true,
        icon: icon,
        iconBg: iconBg,
        iconFg: iconFg,
        iconSize: iconSize,
        extra: extra,
      ),
    );
  }

  /// 딤 — 명세 공통값 rgba(20,24,22,.5).
  static const Color _barrier = Color(0x80141816);

  // 명세 §0.4 버튼 색
  static const Color _btnPrimaryBg = Color(0xFF2A2F2C);
  static const Color _btnSecondaryBg = Color(0xFFF4F6F5);
  static const Color _btnSecondaryFg = Color(0xFF5A5F5B);
  static const Color _btnDangerBg = Color(0xFFE4573D);

  @override
  Widget build(BuildContext context) {
    // 경고(빨강) 아이콘: danger(파괴 확인) 또는 warn(아이콘만 경고)일 때.
    final bool alarm = danger || warn;

    // 아이콘 원 58 — 명세 §0.2. 팝업이 색을 직접 주면 그것을 쓰고,
    // 주지 않으면 일반=라임 면, 경고=연빨강 면으로 떨어진다.
    final Color tileBg =
        iconBg ?? (alarm ? const Color(0xFFFDEBE7) : AppColors.lime);
    final Color tileFg =
        iconFg ?? (alarm ? _btnDangerBg : AppColors.limeOn);
    final IconData tileIcon =
        icon ?? (alarm ? TablerIcons.alertTriangle : TablerIcons.leaf);

    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      // 명세: left/right 30, 라운드 28
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        // 명세 §0.2: padding 26px 24px 20px
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!hideIcon) ...[
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tileBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(tileIcon, size: iconSize, color: tileFg),
              ),
              const SizedBox(height: 16),
            ],
            // 제목 21/800/1.4, letter-spacing -0.5
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                height: 1.4,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 10),
              // 본문 13.5/500/1.6, gray500
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray500,
                ),
              ),
            ],
            if (extra != null) ...[
              const SizedBox(height: 18),
              extra!,
            ],
            const SizedBox(height: 20),
            if (isInfo)
              // 안내(1버튼): 가로 전체 폭
              _btn(
                label: confirmText,
                bg: danger ? _btnDangerBg : _btnPrimaryBg,
                fg: Colors.white,
                onTap: () => Navigator.pop(context),
              )
            else if (verticalButtons)
              // 세로 배치: 위=안전(다크), 아래=파괴(연회색 면 + 빨강 글자).
              // 되돌릴 수 없는 선택이라 가로로 바꾸지 않는다.
              Column(
                children: [
                  _btn(
                    label: cancelText,
                    bg: _btnPrimaryBg,
                    fg: Colors.white,
                    onTap: () => Navigator.pop(context, false),
                  ),
                  const SizedBox(height: 9),
                  _btn(
                    label: confirmText,
                    bg: _btnSecondaryBg,
                    fg: _btnDangerBg,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _btn(
                      label: cancelText,
                      bg: primaryIsCancel ? _btnPrimaryBg : _btnSecondaryBg,
                      fg: primaryIsCancel ? Colors.white : _btnSecondaryFg,
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _btn(
                      label: confirmText,
                      bg: primaryIsCancel
                          ? _btnSecondaryBg
                          : (danger
                              ? (softDanger ? _btnSecondaryBg : _btnDangerBg)
                              : _btnPrimaryBg),
                      fg: primaryIsCancel
                          ? _btnSecondaryFg
                          : (danger && softDanger ? _btnDangerBg : Colors.white),
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

  /// 팝업 버튼 — 명세 §0.2: height 54, radius 18, font 800 16.
  /// AppButton 을 쓰지 않는 이유: 그쪽은 앱 전역 규격(높이 52·흰 면 보조 버튼)이라
  /// 팝업 규격과 다르고, 맞추려 고치면 화면 전체 버튼이 함께 바뀐다.
  Widget _btn({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }
}
