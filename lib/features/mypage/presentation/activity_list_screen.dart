import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/route_thumbnail.dart';
import 'package:repo_jdh/features/mypage/presentation/activity_detail_screen.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';

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
  int _quick = 1; // 빠른 기간 탭 (0 1주 / 1 1개월 / 2 3개월 / 3 전체). -1 = 직접 선택

  static const List<String> _quickLabels = ['1주', '1개월', '3개월', '전체'];

  // 다른 화면(뱃지 판정·내 변화)과 맞춘 조회 상한.
  // ⚠️ 기간 필터는 클라이언트에서 거르므로, 이 상한을 넘는 과거 기록은
  //    날짜를 지정해도 조회되지 않는다. 필요해지면 startedAt 범위 쿼리로 전환.
  static const int _limit = 500;

  // null = 로딩 중 / [] = 로딩됐고 기록 0건
  List<_Act>? _acts;
  Object? _loadError; // null 이 아니면 에러 발생
  double? _weightKg;

  @override
  void initState() {
    super.initState();
    // 목업 기본값: '1개월' 선택 상태로 진입
    final r = _rangeForQuick(_quick);
    _rangeStart = r.$1;
    _rangeEnd = r.$2;
    _load();
  }

  // 빠른 기간 탭 → 조회 범위 계산 (0 1주 / 1 1개월 / 2 3개월 / 3 전체)
  (DateTime?, DateTime?) _rangeForQuick(int i) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final start = DateTime(now.year, now.month, now.day);
    switch (i) {
      case 0: // 1주
        return (start.subtract(const Duration(days: 7)), today);
      case 1: // 1개월
        return (start.subtract(const Duration(days: 30)), today);
      case 2: // 3개월
        return (start.subtract(const Duration(days: 90)), today);
      default: // 3 전체
        return (null, null);
    }
  }

  Future<void> _load() async {
    try {
      final body = await UserService.loadBodyInfo();
      final list = await ActivityService.getRecentCompleted(limit: _limit);
      if (!mounted) return;
      setState(() {
        _weightKg = body.weightKg;
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
      a.id,
      a.startedAt,
      ActivityMetrics.placeLabel(
        placeName: a.placeDetail ?? a.placeName,
        groupId: a.groupId,
      ),
      ActivityMetrics.estimateSteps(a.distanceMeters),
      ActivityMetrics.weightGrams(a.trashCounts) / 1000.0,
      ActivityMetrics.estimateKcal(
        distanceMeters: a.distanceMeters,
        durationSeconds: a.durationSeconds,
        weightKg: _weightKg,
      ),
      a.distanceMeters / 1000.0,
      a.imageUrls.isNotEmpty,
      a.trashCounts,
      a.imageUrls,
      a.path,
      a.durationSeconds,
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  // '8월 4일' (연도 없는 한글 날짜 — 목업 요약/행)
  String _fmtKor(DateTime d) => '${d.month}월 ${d.day}일';

  static const List<String> _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  // '9월 3일 수요일' (상세 헤드라인)
  String _dateHeadline(DateTime d) =>
      '${d.month}월 ${d.day}일 ${_weekdays[d.weekday - 1]}요일';

  // '오전 9:03' (오전/오후 포함)
  String _ampmTime(DateTime d, {bool withAmpm = true}) {
    final ampm = d.hour < 12 ? '오전' : '오후';
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    return withAmpm ? '$ampm $h12:$mm' : '$h12:$mm';
  }

  // 개별 활동 수거량 — 그램 표기(1000 이상은 kg). 예: 620g / 1.3kg
  String _gramLabel(Map<String, int> counts) {
    final g = ActivityMetrics.weightGrams(counts);
    if (g >= 1000) return '${(g / 1000.0).toStringAsFixed(1)}kg';
    return '${g}g';
  }

  // 활동 소요 시간 — '38분' (분 단위)
  String _minLabel(int durationSeconds) =>
      '${(durationSeconds / 60).round()}분';

  // 수거 개수 합계 — '15개'
  int _itemCount(Map<String, int> counts) =>
      counts.values.fold<int>(0, (s, v) => s + v);

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
      _quick = -1; // 직접 선택 → 빠른 탭 해제
      _rangeStart = DateTime(start.year, start.month, start.day);
      _rangeEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
    });
  }

  // 빠른 기간 탭 선택 → 범위 세팅
  void _setQuick(int i) {
    final r = _rangeForQuick(i);
    setState(() {
      _quick = i;
      _rangeStart = r.$1;
      _rangeEnd = r.$2;
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

    final totalKg = acts.fold<double>(0, (s, a) => s + a.weightKg);
    final bool ranged = _rangeStart != null && _rangeEnd != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단 바 — 제목 + 전체 건수
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        TablerIcons.chevronLeft,
                        size: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      '전체 활동',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_acts != null)
                    Text(
                      '${acts.length}회',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray500,
                      ),
                    ),
                ],
              ),
            ),
            // 빠른 기간 탭
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  for (int i = 0; i < _quickLabels.length; i++) ...[
                    _rangeTab(_quickLabels[i], i),
                    if (i < _quickLabels.length - 1) const SizedBox(width: 7),
                  ],
                ],
              ),
            ),
            // 기간·요약 행 (탭하면 상세 기간 선택)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickDate,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      TablerIcons.calendar,
                      size: 17,
                      color: AppColors.gray700,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        ranged
                            ? '${_fmtKor(_rangeStart!)} ~ ${_fmtKor(_rangeEnd!)}'
                            : '전체 기간',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '수거 ${totalKg.toStringAsFixed(1)}kg',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildBody(acts)),
          ],
        ),
      ),
    );
  }

  // 빠른 기간 탭 pill (선택 시 잉크)
  Widget _rangeTab(String label, int i) {
    final on = _quick == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setQuick(i),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.ink : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: on ? FontWeight.w800 : FontWeight.w600,
              color: on ? AppColors.textOnBrand : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // 로딩 / 에러 / 빈 / 목록
  Widget _buildBody(List<_Act> acts) {
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '기록을 불러오지 못했어요',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_acts == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.progress,
          strokeWidth: 2,
        ),
      );
    }
    if (acts.isEmpty) {
      return const Center(
        child: Text(
          '해당 기간에 활동 기록이 없어요',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        22,
        4,
        22,
        MediaQueryData.fromView(View.of(context)).padding.bottom + 120,
      ),
      itemCount: acts.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, thickness: 1, color: AppColors.line100),
      itemBuilder: (_, i) => _activityCard(context, acts[i]),
    );
  }

  // 목업: 경로 썸네일(54) + 장소 + 날짜·메타 + kg, 행 사이 구분선
  Widget _activityCard(BuildContext context, _Act a) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivityDetailScreen(
            // 헤드라인 = 날짜+요일, 부제 = 시간대 · 장소 (목업 상세 상단)
            dateTime:
                '${_ampmTime(a.date)} ~ '
                '${_ampmTime(a.date.add(Duration(seconds: a.durationSeconds)), withAmpm: false)}'
                ' · ${a.title}',
            title: _dateHeadline(a.date),
            steps: a.steps,
            weight: _gramLabel(a.trashCounts),
            kcal: a.kcal,
            time: _minLabel(a.durationSeconds),
            distance: '${a.distanceKm.toStringAsFixed(1)}km',
            trashCounts: a.trashCounts,
            imageUrls: a.imageUrls,
            activityId: a.id,
            path: a.path,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // 경로 미니 지도 썸네일 (사진 없으면 카메라+ 배지)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: CustomPaint(painter: RoutePainter(path: a.path)),
                  ),
                ),
                if (!a.hasPhoto)
                  Positioned(
                    right: 3,
                    bottom: 3,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        TablerIcons.cameraPlus,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_fmtKor(a.date)} · ${a.distanceKm.toStringAsFixed(1)}km · '
                    '${_minLabel(a.durationSeconds)} · ${_itemCount(a.trashCounts)}개',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _gramLabel(a.trashCounts),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Act {
  final String id;
  final DateTime date;
  final String title;
  final int steps;
  final double weightKg; // 1.2
  final int kcal;
  final double distanceKm; // 2.4
  final bool hasPhoto;

  /// 활동별 수거 개수 (서버 Activity.trashCounts 원본)
  final Map<String, int> trashCounts;

  /// 인증샷 URL (서버 Activity.imageUrls 원본). 상세 화면이 실제 사진을 그린다.
  final List<String> imageUrls;

  /// GPS 경로 ([{lat, lng, t}, ...]). 없으면 썸네일에 '경로 없음' 표시.
  final List<Map<String, dynamic>> path;

  /// 소요 시간(초) — 상세 종료시각·'N분' 표기 계산용
  final int durationSeconds;

  const _Act(
    this.id,
    this.date,
    this.title,
    this.steps,
    this.weightKg,
    this.kcal,
    this.distanceKm,
    this.hasPhoto,
    this.trashCounts,
    this.imageUrls,
    this.path,
    this.durationSeconds,
  );
}
