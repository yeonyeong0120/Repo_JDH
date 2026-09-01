import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 지도 마커용 핀 — 흰 원 + 초록 아이콘 + 삼각 꼬리.
/// 정산 화면·활동 상세 화면의 경로 지도가 공용으로 쓴다.
class RoutePin extends StatelessWidget {
  final IconData icon;
  const RoutePin({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.neutral900.withValues(alpha: 0.22),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        SizedBox(
          width: 14,
          height: 8,
          child: CustomPaint(painter: _RoutePinTail()),
        ),
      ],
    );
  }
}

class _RoutePinTail extends CustomPainter {
  const _RoutePinTail();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RoutePinTail oldDelegate) => false;
}
