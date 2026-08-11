// 활동 종료 → (퀘스트 완료 시에만) 두 팝업이 순서대로 뜬다.
//  1) 퀘스트 완료: 빵빠레(색종이)가 뿌려지고 파티 이모지가 떠오른다. (빠름)
//  2) 뱃지 획득: 뱃지가 먼저 떠오른 뒤, 글자가 문장 순서대로 따다닥 떠오른다. (느림)
// 퀘스트가 없으면 두 팝업 모두 뜨지 않는다(호출부에서 판단).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/router/app_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/core/widgets/trash_bag_icon.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';

/// 획득 뱃지들에 대해 퀘스트 완료 → 뱃지 획득 팝업을 순서대로 띄운다.
/// '뱃지함 보기'를 누르면 내 활동(/mypage)으로 이동한다.
/// 화면 전환(정산→홈/피드) 이후에도 rootNavigatorKey.currentContext 로 호출 가능.
/// 반환값: '뱃지함 보기'로 /mypage 로 이동했으면 true.
Future<bool> showRewardFlow(BuildContext context, List<BadgeData> badges) async {
  for (final b in badges) {
    if (!context.mounted) return false;
    await showQuestComplete(
      context,
      quest: b.quest,
      desc: '${b.quest} 챌린지를 완료했어요.',
    );
    if (!context.mounted) return false;
    final goBadges = await showBadgeEarnedAnimated(context, badge: b);
    if (goBadges == true) {
      if (context.mounted) context.go(AppRoutes.mypage);
      return true;
    }
  }
  return false;
}

// ─────────────────────────── 퀘스트 완료 팝업 ───────────────────────────
Future<void> showQuestComplete(
  BuildContext context, {
  required String quest,
  required String desc,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.neutral900.withValues(alpha: 0.45),
    builder: (_) => _QuestCompleteDialog(quest: quest, desc: desc),
  );
}

class _QuestCompleteDialog extends StatefulWidget {
  final String quest;
  final String desc;
  const _QuestCompleteDialog({required this.quest, required this.desc});

  @override
  State<_QuestCompleteDialog> createState() => _QuestCompleteDialogState();
}

class _QuestCompleteDialogState extends State<_QuestCompleteDialog>
    with TickerProviderStateMixin {
  late final AnimationController _confetti;
  late final AnimationController _pop;
  final List<_Confetto> _pieces = [];

  static const List<Color> _confettiColors = [
    Color(0xFF34AE77),
    Color(0xFFF5C400),
    Color(0xFFF5A78C),
    Color(0xFF5F9EE8),
    Color(0xFF8E7EC4),
    Color(0xFFE07B2E),
  ];

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    for (int i = 0; i < 46; i++) {
      _pieces.add(_Confetto(
        x: rnd.nextDouble(),
        delay: rnd.nextDouble(),
        speed: 0.7 + rnd.nextDouble() * 0.7,
        size: 5 + rnd.nextDouble() * 6,
        color: _confettiColors[rnd.nextInt(_confettiColors.length)],
        rot: rnd.nextDouble() * math.pi,
        rotSpeed: (rnd.nextDouble() - 0.5) * 8,
        sway: rnd.nextDouble() * 2 * math.pi,
      ));
    }
    _confetti = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    )..forward();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 빵빠레(색종이)
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(_pieces, _confetti.value),
              ),
            ),
          ),
        ),
        // 카드
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 파티 이모지 (떠오르며 팝인)
                    AnimatedBuilder(
                      animation: _pop,
                      builder: (context, child) {
                        final t = Curves.easeOutBack.transform(_pop.value);
                        return Opacity(
                          opacity: _pop.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * 16),
                            child: Transform.scale(
                              scale: 0.6 + t * 0.4,
                              child: child,
                            ),
                          ),
                        );
                      },
                      // 파티 아이콘: 이미지 에셋을 우선 사용, 없으면 Material 아이콘.
                      // assets/icons/celebration.png 에 넣으면 그 이미지로 교체됨.
                      child: Image.asset(
                        'assets/icons/celebration.png',
                        width: 60,
                        height: 60,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.celebration,
                          size: 56,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '챌린지 완료',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBrandOnLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.quest,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.desc,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppButton(
                      label: '확인',
                      onTap: () => Navigator.pop(context),
                      type: AppButtonType.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Confetto {
  final double x, delay, speed, size, rot, rotSpeed, sway;
  final Color color;
  const _Confetto({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.color,
    required this.rot,
    required this.rotSpeed,
    required this.sway,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Confetto> pieces;
  final double t; // 0..1 반복
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final prog = (t * p.speed + p.delay) % 1.0;
      final y = prog * (size.height + 40) - 20;
      final x = p.x * size.width + math.sin(p.sway + prog * 6) * 16;
      final paint = Paint()..color = p.color.withValues(alpha: 1 - prog * 0.4);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + prog * p.rotSpeed);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

// ─────────────────────────── 뱃지 획득 팝업 ───────────────────────────
// 반환값: true = 뱃지함 보기 / null·false = 확인
Future<bool?> showBadgeEarnedAnimated(
  BuildContext context, {
  required BadgeData badge,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.neutral900.withValues(alpha: 0.45),
    builder: (_) => _BadgeEarnedDialog(badge: badge),
  );
}

class _BadgeEarnedDialog extends StatefulWidget {
  final BadgeData badge;
  const _BadgeEarnedDialog({required this.badge});

  @override
  State<_BadgeEarnedDialog> createState() => _BadgeEarnedDialogState();
}

class _BadgeEarnedDialogState extends State<_BadgeEarnedDialog>
    with SingleTickerProviderStateMixin {
  // 퀘스트 팝업보다 느리게. 뱃지가 먼저, 그다음 글자 순서대로.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // [a,b] 구간을 0..1 로 정규화
  double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  Widget _rise(double v, Widget child, {double dy = 12}) {
    return Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, (1 - v) * dy), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badge;
    final desc = '${b.quest} 챌린지를 달성해 받은 뱃지예요.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value;
                // 뱃지: 먼저 떠오름(살짝 회전)
                final badgeV = Curves.easeOutBack.transform(_seg(t, 0.0, 0.38));
                final labelV = _seg(t, 0.42, 0.54);
                final nameV = _seg(t, 0.56, 0.7);
                final btnV = _seg(t, 0.9, 1.0);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: badgeV.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, (1 - badgeV) * 22),
                        child: Transform.rotate(
                          angle: (1 - badgeV) * -0.12,
                          child: _badgeTile(b),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _rise(
                      labelV,
                      const Text(
                        '새 뱃지 획득',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBrandOnLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _rise(
                      nameV,
                      Text(
                        b.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 설명: 단어가 문장 순서대로 따다닥 떠오름
                    _StaggerWords(
                      text: desc,
                      progress: t,
                      start: 0.72,
                      span: 0.2,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _rise(
                      btnV,
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: '뱃지함 보기',
                              onTap: () => Navigator.pop(context, true),
                              type: AppButtonType.secondary,
                              expand: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppButton(
                              label: '확인',
                              onTap: () => Navigator.pop(context, false),
                              type: AppButtonType.primary,
                              expand: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _badgeTile(BadgeData b) {
    return Container(
      width: 84,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.green100, AppColors.green300],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: usesTrashBagIcon(b)
          ? const TrashBagIcon(size: 40, color: AppColors.green750)
          : Icon(b.icon, size: 40, color: AppColors.green750), // 봉지 뱃지는 쓰레기봉투
    );
  }
}

// 단어를 문장 순서대로 스태거로 떠오르게 (따다닥).
class _StaggerWords extends StatelessWidget {
  final String text;
  final double progress; // 0..1
  final double start; // 시작 지점
  final double span; // 전체 구간 길이
  final TextStyle style;
  const _StaggerWords({
    required this.text,
    required this.progress,
    required this.start,
    required this.span,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final words = text.split(' ');
    final n = words.length;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < n; i++)
          () {
            final wStart = start + span * (i / n);
            final v = ((progress - wStart) / (span / n * 1.8)).clamp(0.0, 1.0);
            return Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, (1 - v) * 8),
                child: Text('${words[i]} ', style: style),
              ),
            );
          }(),
      ],
    );
  }
}
