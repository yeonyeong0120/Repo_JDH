import 'package:flutter/material.dart';
import '../data/detector.dart';

/// 쓰레기 종류별 화면 표시 정보 (한국어 라벨 + 박스 색)
///
/// 서버가 주는 class_name 은 영어(can, glass ...)라 그대로 보여주면
/// 사용자가 알아보기 어렵다. 여기서 한 번에 한국어로 매핑한다.
/// 종류가 늘어나면 이 표에 한 줄만 추가하면 된다.
class TrashLabel {
  static const Map<String, (String label, Color color)> _meta = {
    'can': ('캔', Colors.red),
    'glass': ('유리', Colors.blue),
    'paper': ('종이', Colors.amber),
    'plastic': ('플라스틱', Colors.green),
    'trash': ('일반쓰레기', Colors.purple),
  };

  /// 한국어 라벨 (모르는 종류면 원문 그대로)
  static String labelOf(String className) =>
      _meta[className]?.$1 ?? className;

  /// 박스 색 (모르는 종류면 흰색)
  static Color colorOf(String className) =>
      _meta[className]?.$2 ?? Colors.white;
}

class DetectionPainter extends CustomPainter {
  final List<DetectionResult> detections;
  DetectionPainter({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final color = TrashLabel.colorOf(det.className);

      final left = det.x1 * size.width;
      final top = det.y1 * size.height;
      final right = det.x2 * size.width;
      final bottom = det.y2 * size.height;
      final rect = Rect.fromLTRB(left, top, right, bottom);

      final boxPaint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawRect(rect, boxPaint);

      // 라벨은 한국어 종류명만 표시 (신뢰도 % 는 사용자에게 불필요)
      final labelText = TrashLabel.labelOf(det.className);
      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelBgRect = Rect.fromLTWH(
        left,
        top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );
      canvas.drawRect(labelBgRect, Paint()..color = color);
      textPainter.paint(
        canvas,
        Offset(left + 4, top - textPainter.height - 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DetectionPainter oldDelegate) => true;
}