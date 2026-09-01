import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 활동 경로 미니 지도 — 위경도 좌표를 캔버스 크기에 맞춰 그린다.
/// 목록 카드 썸네일 전용. 상세 화면 헤더는 실제 네이버 지도(_ActivityRouteMap)를 쓴다.
///
/// [path]는 Activity.path 형식 그대로: [{lat, lng, t}, ...].
/// 점이 2개 미만이면 가짜 경로 대신 '경로 없음' 아이콘만 그린다 —
/// 있지도 않은 경로를 있는 것처럼 보이면 데이터 누락을 화면이 가려버린다.
class RoutePainter extends CustomPainter {
  final List<Map<String, dynamic>> path;

  const RoutePainter({required this.path});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE7EFE9),
    );
    _drawGrid(canvas, size);

    final points = _normalizedPoints(size);
    if (points == null) {
      _drawNoRoute(canvas, size);
      return;
    }

    final route = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      route.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      route,
      Paint()
        ..color = AppColors.routeLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(points.first, 4.5, Paint()..color = AppColors.green700);
    canvas.drawCircle(points.last, 5, Paint()..color = Colors.white);
    canvas.drawCircle(points.last, 3, Paint()..color = AppColors.green600);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final grid = Paint()
      ..color = const Color(0xFFF4F8F5)
      ..strokeWidth = 7;
    canvas.drawLine(Offset(0, h * 0.5), Offset(w, h * 0.5), grid);
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), grid);
  }

  // 위경도 min/max 로 바운딩박스를 구해 캔버스 안쪽(여백 제외)에 맞춘다.
  // 위도는 위로 갈수록 커지지만 화면 y좌표는 아래로 갈수록 커지므로 Y축을 뒤집는다.
  List<Offset>? _normalizedPoints(Size size) {
    final lats = <double>[];
    final lngs = <double>[];
    for (final p in path) {
      final lat = (p['lat'] as num?)?.toDouble();
      final lng = (p['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      lats.add(lat);
      lngs.add(lng);
    }
    if (lats.length < 2) return null;

    final minLat = lats.reduce(min), maxLat = lats.reduce(max);
    final minLng = lngs.reduce(min), maxLng = lngs.reduce(max);
    // 제자리에 가까운 짧은 활동은 스팬이 0에 가까워 나눗셈이 불안정해진다.
    final latSpan = max(maxLat - minLat, 0.00001);
    final lngSpan = max(maxLng - minLng, 0.00001);

    const padding = 0.16; // 캔버스 가장자리 여백 비율 — 선이 테두리에 안 닿게
    final drawW = size.width * (1 - padding * 2);
    final drawH = size.height * (1 - padding * 2);
    final offsetX = size.width * padding;
    final offsetY = size.height * padding;

    return List.generate(lats.length, (i) {
      final nx = (lngs[i] - minLng) / lngSpan;
      final ny = (lats[i] - minLat) / latSpan;
      return Offset(offsetX + nx * drawW, offsetY + (1 - ny) * drawH);
    });
  }

  void _drawNoRoute(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(TablerIcons.route.codePoint),
        style: TextStyle(
          fontSize: 20,
          fontFamily: TablerIcons.route.fontFamily,
          package: TablerIcons.route.fontPackage,
          color: AppColors.neutral400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) =>
      oldDelegate.path != path;
}
