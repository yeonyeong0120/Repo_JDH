import 'package:flutter/material.dart';
import '../data/detector.dart';

class DetectionPainter extends CustomPainter {
  final List<DetectionResult> detections;
  DetectionPainter({required this.detections});

  Color _colorForClass(String name) {
    switch (name) {
      case 'can':
        return Colors.red;
      case 'glass':
        return Colors.blue;
      case 'paper':
        return Colors.amber;
      case 'plastic':
        return Colors.green;
      case 'trash':
        return Colors.purple;
      default:
        return Colors.white;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final color = _colorForClass(det.className);

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

      final labelText =
          '${det.className} ${(det.confidence * 100).toStringAsFixed(0)}%';
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