// 쓰레기봉투 아이콘 — Material Symbols 에 없어 직접 그린 것.
// 정산 화면 '무게' 칸에 사용. 파일(assets) 없이 코드만으로 쓴다.
//   TrashBagIcon(size: 20, color: AppColors.dataCollect)

import 'package:flutter/material.dart';

class TrashBagIcon extends StatelessWidget {
  final double size;
  final Color color;
  const TrashBagIcon({super.key, this.size = 24, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _TrashBagPainter(color)),
  );
}

class _TrashBagPainter extends CustomPainter {
  final Color color;
  _TrashBagPainter(this.color);

  // 24x24 기준 좌표를 실제 크기로 늘려 그린다.
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.save();
    canvas.scale(k);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 봉투 몸통
    final body = Path()
      ..moveTo(14.1, 9.8)
      ..cubicTo(17.0, 11.7, 19.4, 15.5, 19.4, 18.3)
      ..cubicTo(19.4, 21.0, 17.3, 22.7, 14.3, 22.7)
      ..lineTo(9.7, 22.7)
      ..cubicTo(6.7, 22.7, 4.6, 21.0, 4.6, 18.3)
      ..cubicTo(4.6, 15.5, 7.0, 11.7, 9.9, 9.8)
      ..cubicTo(10.8, 10.1, 11.8, 10.3, 12.0, 10.3)
      ..cubicTo(12.2, 10.3, 13.2, 10.1, 14.1, 9.8)
      ..close();
    canvas.drawPath(body, paint);

    // 묶인 목
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(12, 8.5), width: 5.8, height: 2.6),
      paint,
    );

    // 매듭 (오른쪽으로 접힌 끈)
    final knot = Path()
      ..moveTo(9.4, 2.3)
      ..cubicTo(9.6, 2.1, 9.9, 2.1, 10.1, 2.3)
      ..cubicTo(11.0, 3.3, 12.0, 3.5, 13.1, 2.8)
      ..cubicTo(13.6, 2.5, 14.2, 2.8, 14.3, 3.4)
      ..lineTo(14.6, 5.1)
      ..lineTo(16.8, 5.5)
      ..cubicTo(17.5, 5.6, 17.7, 6.5, 17.1, 6.9)
      ..lineTo(14.0, 8.8)
      ..cubicTo(13.5, 9.1, 12.9, 8.9, 12.6, 8.4)
      ..cubicTo(12.3, 7.9, 12.5, 7.3, 13.0, 7.0)
      ..lineTo(14.1, 6.3)
      ..lineTo(13.1, 6.1)
      ..cubicTo(12.7, 6.0, 12.3, 5.7, 12.3, 5.2)
      ..lineTo(12.2, 4.6)
      ..cubicTo(11.3, 4.8, 10.4, 4.8, 9.6, 4.5)
      ..cubicTo(9.6, 5.1, 9.7, 5.7, 9.9, 6.3)
      ..cubicTo(10.1, 6.8, 9.8, 7.4, 9.2, 7.6)
      ..cubicTo(8.7, 7.8, 8.1, 7.5, 7.9, 6.9)
      ..cubicTo(7.5, 5.5, 7.5, 4.0, 8.0, 2.6)
      ..cubicTo(8.0, 2.5, 8.1, 2.4, 8.2, 2.3)
      ..close();
    canvas.drawPath(knot, paint);

    // 목에서 내려오는 주름
    final fold = Path()
      ..moveTo(10.9, 8.6)
      ..lineTo(8.5, 5.2)
      ..lineTo(10.1, 4.0)
      ..lineTo(12.5, 7.4)
      ..close();
    canvas.drawPath(fold, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrashBagPainter old) => old.color != color;
}
