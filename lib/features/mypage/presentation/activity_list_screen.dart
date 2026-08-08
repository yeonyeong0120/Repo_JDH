import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/mypage/presentation/activity_detail_screen.dart';

/// 줍다행 - 전체 활동 기록 (ACT-04)
/// 기록 탭 "최근 활동 전체 보기" → 이 화면. 월별 그룹 + 기간 필터.
/// 실제 데이터는 아직 없어 더미 + TODO.
class ActivityListScreen extends StatefulWidget {
  const ActivityListScreen({super.key});

  @override
  State<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends State<ActivityListScreen> {
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  // TODO: 실제 활동 데이터로 교체 (시간 역순)
  static final List<_Act> _acts = [
    _Act(DateTime(2026, 8, 5, 7, 30), '소래습지 생태공원', 3180, '42분', 1.2, 124, 2.4, true),
    _Act(DateTime(2026, 8, 4, 18, 12), '인천대공원 순환길', 2410, '31분', 0.9, 96, 1.7, true),
    _Act(DateTime(2026, 8, 2, 8, 5), '만수천 산책로', 4020, '55분', 1.6, 158, 3.1, false),
    _Act(DateTime(2026, 7, 30, 7, 10), '장수천 벚꽃길', 2860, '38분', 1.1, 112, 2.0, true),
    _Act(DateTime(2026, 7, 28, 19, 40), '구월동 로데오거리', 1940, '26분', 0.7, 78, 1.3, false),
  ];

  static String _comma(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  String _monthLabel(DateTime d) => '${d.year}년 ${d.month}월';

  String _dateTimeLabel(DateTime d) {
    final ampm = d.hour < 12 ? '오전' : '오후';
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.month}월 ${d.day}일 $ampm $h12:$mm';
  }

  String _fmt(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  // 기간(시작~종료) 선택 — 달력/휠, 연필로 전환.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(2024, 1, 1);
    DateTime start = _rangeStart ?? now;
    DateTime end = _rangeEnd ?? now;
    bool editingStart = true;
    bool wheel = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final active = editingStart ? start : end;

          Widget rangeChip(String label, DateTime value, bool isStart) {
            final sel = editingStart == isStart;
            return Expanded(
              child: GestureDetector(
                onTap: () => setLocal(() => editingStart = isStart),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.surfaceBrand : AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fmt(value),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: sel
                              ? AppColors.green800
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      rangeChip('시작일', start, true),
                      const SizedBox(width: 8),
                      rangeChip('종료일', end, false),
                      IconButton(
                        tooltip: wheel ? '달력으로' : '휠로 입력',
                        icon: Icon(
                          wheel
                              ? Icons.calendar_today_outlined
                              : Icons.edit_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setLocal(() => wheel = !wheel),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 300,
                    child: wheel
                        ? CupertinoDatePicker(
                            key: ValueKey('wheel-$editingStart'),
                            mode: CupertinoDatePickerMode.date,
                            initialDateTime: active,
                            minimumDate: first,
                            maximumDate: now,
                            onDateTimeChanged: (dt) => setLocal(() {
                              if (editingStart) {
                                start = dt;
                              } else {
                                end = dt;
                              }
                            }),
                          )
                        : CalendarDatePicker(
                            key: ValueKey('cal-$editingStart'),
                            initialDate: active,
                            firstDate: first,
                            lastDate: now,
                            onDateChanged: (dt) => setLocal(() {
                              if (editingStart) {
                                start = dt;
                                editingStart = false;
                              } else {
                                end = dt;
                              }
                            }),
                          ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          '확인',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok != true) return;
    if (start.isAfter(end)) {
      final t = start;
      start = end;
      end = t;
    }
    setState(() {
      _rangeStart = DateTime(start.year, start.month, start.day);
      _rangeEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
    });
  }

  @override
  Widget build(BuildContext context) {
    final acts = (_rangeStart == null || _rangeEnd == null)
        ? _acts
        : _acts
              .where(
                (a) =>
                    !a.date.isBefore(_rangeStart!) &&
                    !a.date.isAfter(_rangeEnd!),
              )
              .toList();

    // 월별 그룹 (입력이 시간 역순이라고 가정)
    final Map<String, List<_Act>> byMonth = {};
    for (final a in acts) {
      byMonth.putIfAbsent(_monthLabel(a.date), () => []).add(a);
    }

    final totalKg = acts.fold<double>(0, (s, a) => s + a.weightKg);
    final bool ranged = _rangeStart != null && _rangeEnd != null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '활동 기록',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                // 마지막 카드가 하단 네비바에 가리지 않게 넉넉히
                padding: EdgeInsets.fromLTRB(
                  20,
                  6,
                  20,
                  MediaQueryData.fromView(View.of(context)).padding.bottom + 120,
                ),
                children: [
                  // 기간 필터 pill
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _pickDate,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 19,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ranged
                                  ? '${_fmt(_rangeStart!)} ~ ${_fmt(_rangeEnd!)}'
                                  : '기간 전체',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (ranged)
                            GestureDetector(
                              onTap: () => setState(() {
                                _rangeStart = null;
                                _rangeEnd = null;
                              }),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 전체 활동 요약
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '전체 활동',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${acts.length}회 · ${totalKg.toStringAsFixed(1)}kg',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textBrandOnLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (acts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text(
                          '해당 기간에 활동 기록이 없어요',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  for (final entry in byMonth.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 14, 0, 12),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    ...entry.value.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _activityCard(context, a),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityCard(BuildContext context, _Act a) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivityDetailScreen(
            dateTime: _dateTimeLabel(a.date),
            title: a.title,
            steps: a.steps,
            weight: '${a.weightKg.toStringAsFixed(1)}kg',
            kcal: a.kcal,
            time: a.duration,
            distance: '${a.distanceKm.toStringAsFixed(1)}km',
            hasPhoto: a.hasPhoto,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            // 경로 미니 지도 썸네일 (사진 있으면 카메라 배지)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: const SizedBox(
                    width: 84,
                    height: 84,
                    child: CustomPaint(painter: _RouteThumbPainter()),
                  ),
                ),
                // 인증샷을 첨부하지 않은 기록: 카메라+ 배지 (우하단)
                if (!a.hasPhoto)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateTimeLabel(a.date),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_comma(a.steps)}걸음 · ${a.duration} · '
                      '${a.weightKg.toStringAsFixed(1)}kg · ${a.kcal}kcal',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 경로 미니 지도 썸네일 (회색 격자 + 초록 곡선 + 시작·도착 점).
class _RouteThumbPainter extends CustomPainter {
  const _RouteThumbPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE7EFE9),
    );
    final grid = Paint()
      ..color = const Color(0xFFF4F8F5)
      ..strokeWidth = 7;
    canvas.drawLine(Offset(0, h * 0.42), Offset(w, h * 0.42), grid);
    canvas.drawLine(Offset(w * 0.5, 0), Offset(w * 0.5, h), grid);
    final path = Path()
      ..moveTo(w * 0.22, h * 0.78)
      ..cubicTo(w * 0.30, h * 0.55, w * 0.34, h * 0.5, w * 0.5, h * 0.5)
      ..cubicTo(w * 0.66, h * 0.5, w * 0.68, h * 0.34, w * 0.78, h * 0.3);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.routeLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(w * 0.22, h * 0.78),
      4.5,
      Paint()..color = AppColors.green700,
    );
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.3),
      5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.3),
      3,
      Paint()..color = AppColors.green600,
    );
  }

  @override
  bool shouldRepaint(covariant _RouteThumbPainter oldDelegate) => false;
}

class _Act {
  final DateTime date;
  final String title;
  final int steps;
  final String duration; // '42분'
  final double weightKg; // 1.2
  final int kcal;
  final double distanceKm; // 2.4
  final bool hasPhoto;
  const _Act(
    this.date,
    this.title,
    this.steps,
    this.duration,
    this.weightKg,
    this.kcal,
    this.distanceKm,
    this.hasPhoto,
  );
}
