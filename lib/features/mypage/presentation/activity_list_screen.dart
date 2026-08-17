import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/mypage/presentation/activity_detail_screen.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';

/// Ploggo - 전체 활동 기록 (ACT-04)
/// 기록 탭 "최근 활동 전체 보기" → 이 화면. 월별 그룹 + 기간 필터.
class ActivityListScreen extends StatefulWidget {
  const ActivityListScreen({super.key});

  @override
  State<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends State<ActivityListScreen> {
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  // 다른 화면(뱃지 판정·내 변화)과 맞춘 조회 상한.
  // ⚠️ 기간 필터는 클라이언트에서 거르므로, 이 상한을 넘는 과거 기록은
  //    날짜를 지정해도 조회되지 않는다. 필요해지면 startedAt 범위 쿼리로 전환.
  static const int _limit = 500;

  // null = 로딩 중 / [] = 로딩됐고 기록 0건
  List<_Act>? _acts;
  Object? _loadError; // null 이 아니면 에러 발생

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ActivityService.getRecentCompleted(limit: _limit);
      if (!mounted) return;
      setState(() {
        _acts = list.map(_toAct).toList();
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  // 서버 Activity → 화면 _Act
  // (걸음·칼로리·무게는 ActivityMetrics 로 추정, 장소명은 아직 없어 임시 표시)
  _Act _toAct(Activity a) {
    return _Act(
      a.startedAt,
      ActivityMetrics.placeLabel(placeName: a.placeName, groupId: a.groupId),
      ActivityMetrics.estimateSteps(a.distanceMeters),
      ActivityMetrics.durationLabel(a.durationSeconds),
      ActivityMetrics.weightGrams(a.trashCounts) / 1000.0,
      ActivityMetrics.estimateKcal(a.distanceMeters),
      a.distanceMeters / 1000.0,
      a.imageUrls.isNotEmpty,
      a.trashCounts,
      a.imageUrls,
    );
  }

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
                              ? TablerIcons.calendar
                              : TablerIcons.pencil,
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
    final all = _acts ?? const <_Act>[];
    final acts = (_rangeStart == null || _rangeEnd == null)
        ? all
        : all
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
                    icon: const Icon(TablerIcons.chevronLeft, size: 20),
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
                  MediaQueryData.fromView(View.of(context)).padding.bottom +
                      120,
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
                            TablerIcons.calendar,
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
                                TablerIcons.x,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── 로딩 / 에러 / 데이터 ──
                  // 요약(N회·Xkg)도 이 분기 안에 둔다. 밖에 두면 로딩 중
                  // '0회 · 0.0kg' 이 잠깐 보였다가 실제 값으로 바뀐다.
                  if (_loadError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '기록을 불러오지 못했어요',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _load,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_acts == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.progress,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else ...[
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
                  ],
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
            trashCounts: a.trashCounts,
            imageUrls: a.imageUrls,
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
                        TablerIcons.cameraPlus,
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
  final String duration; // '42:30' (분:초) — ActivityMetrics.durationLabel
  final double weightKg; // 1.2
  final int kcal;
  final double distanceKm; // 2.4
  final bool hasPhoto;

  /// 활동별 수거 개수 (서버 Activity.trashCounts 원본)
  final Map<String, int> trashCounts;

  /// 인증샷 URL (서버 Activity.imageUrls 원본). 상세 화면이 실제 사진을 그린다.
  final List<String> imageUrls;

  const _Act(
    this.date,
    this.title,
    this.steps,
    this.duration,
    this.weightKg,
    this.kcal,
    this.distanceKm,
    this.hasPhoto,
    this.trashCounts,
    this.imageUrls,
  );
}
