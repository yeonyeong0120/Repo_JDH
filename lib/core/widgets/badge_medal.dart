import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';

/// 뱃지 메달 (시안 9b) — 원형 코인 + 흰 이너 링 + 아래 짧은 리본 꼬리 두 갈래.
///
/// 입체감은 "조금만": 위→아래 3단 톤 + 상단 밝은 호 + 하단 그늘 + 바닥 그림자까지.
/// 반사·유광 하이라이트는 넣지 않는다.
///
/// 미획득은 흰 코인 + 회색 트랙 위에 달성률만큼 채우는 둥근 링 (기존 동작 유지).
class BadgeMedal extends StatelessWidget {
  final double size; // 코인 지름
  final Color color; // 카테고리 색 (badgeColor)
  final bool earned;
  final double progress; // 0~1 — 미획득 링 채움
  final Widget icon; // 가운데 아이콘 (색·크기는 호출부에서)

  const BadgeMedal({
    super.key,
    required this.size,
    required this.color,
    required this.icon,
    this.earned = true,
    this.progress = 0,
  });

  /// 코인 + 꼬리를 합친 전체 높이. 그리드 칸 높이를 잡을 때 쓴다.
  static double heightFor(double size) => size * 1.42;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: heightFor(size),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MedalPainter(
                color: color,
                earned: earned,
                progress: progress.clamp(0.0, 1.0),
              ),
            ),
          ),
          // 아이콘은 코인(위쪽 정사각형) 가운데
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: size,
            child: Center(child: icon),
          ),
        ],
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  final Color color;
  final bool earned;
  final double progress;

  const _MedalPainter({
    required this.color,
    required this.earned,
    required this.progress,
  });

  Color _shift(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double d = size.width;
    final double r = d / 2;
    final double cx = d / 2;
    final Offset center = Offset(cx, r);

    // ── 꼬리: 좌우로 확실히 떨어진 '두 개'의 리본. 각 리본 끝은 제비꼬리(V 갈라짐) ──
    final double tw = d * 0.17;
    final double th = d * 0.72;
    final double notch = tw * 0.55; // 끝 V 갈라짐 깊이
    final double headY = d * 0.6;
    final Color tailTop = earned ? color : AppColors.neutral300;
    final Color tailBottom = earned ? _shift(color, -0.06) : AppColors.neutral200;

    void tail(double dx, double deg) {
      canvas.save();
      canvas.translate(cx + dx, headY);
      canvas.rotate(deg * math.pi / 180);
      final path = Path()
        ..moveTo(-tw / 2, 0)
        ..lineTo(tw / 2, 0)
        ..lineTo(tw / 2, th)
        ..lineTo(0, th - notch) // 안쪽으로 파인 V
        ..lineTo(-tw / 2, th)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tailTop, tailBottom],
          ).createShader(Rect.fromLTWH(-tw / 2, 0, tw, th)),
      );
      canvas.restore();
    }

    // 위(아이콘 쪽)는 모이고, 끝으로 갈수록 바깥으로 벌어지는 두 갈래
    tail(-d * 0.10, 15);
    tail(d * 0.10, -15);

    final Rect coin = Rect.fromCircle(center: center, radius: r);

    if (!earned) {
      // 미획득: 흰 코인 + 회색 트랙 + 달성률만큼 채우는 링
      canvas.drawCircle(center, r, Paint()..color = AppColors.surface);
      final double stroke = d * 0.1;
      final Rect ring = Rect.fromCircle(center: center, radius: r - stroke / 2);
      canvas.drawArc(
        ring,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = AppColors.neutral200,
      );
      if (progress > 0) {
        canvas.drawArc(
          ring,
          -math.pi / 2,
          math.pi * 2 * progress,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = AppColors.neutral400,
        );
      }
      return;
    }

    // ── 코인: 굵은 컬러 테두리(링) + 흰 원(면). 아이콘은 호출부가 카테고리 색으로 얹는다. ──
    canvas.drawShadow(
      Path()..addOval(coin),
      AppColors.neutral900.withValues(alpha: 0.28),
      d * 0.04,
      false,
    );
    // 바깥 원 = 굵은 컬러 링
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..isAntiAlias = true
        ..color = color,
    );
    // 안쪽 흰 원(면) — 링 두께 d*0.15
    canvas.drawCircle(
      center,
      r - d * 0.15,
      Paint()
        ..isAntiAlias = true
        ..color = AppColors.surface,
    );
  }

  @override
  bool shouldRepaint(covariant _MedalPainter old) =>
      old.color != color || old.earned != earned || old.progress != progress;
}
