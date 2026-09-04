import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/route_thumbnail.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';

/// 플로고 - 자주 가는 코스 (MYPAGE-25)
/// 진입: 내 활동 기록 탭 → 자주 가는 코스.
///
/// 별도의 '코스' 데이터 모델은 서버에 없다. 완료된 활동을 장소명 기준으로
/// 묶어(같은 장소 = 같은 코스) 방문 횟수·평균 거리/시간·누적 수거량을
/// 화면에서 집계해 보여준다. 장소명이 없는 활동은 폴백 라벨로 묶인다.
/// → 새 모델/서비스를 만들지 않고 실제 활동 기록만으로 구성한다.
class FrequentCoursesScreen extends StatefulWidget {
  const FrequentCoursesScreen({super.key});

  @override
  State<FrequentCoursesScreen> createState() => _FrequentCoursesScreenState();
}

class _FrequentCoursesScreenState extends State<FrequentCoursesScreen> {
  // 집계용 조회 상한 (다른 활동 화면과 맞춤)
  static const int _limit = 500;

  // null = 로딩 중 / [] = 로딩됐고 코스 0개
  List<_Course>? _courses;
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
        _courses = _aggregate(list);
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  // 완료된 활동을 장소 라벨로 묶어 코스 집계. 방문 많은 순으로 정렬.
  List<_Course> _aggregate(List<Activity> activities) {
    final map = <String, _CourseAccum>{};
    for (final a in activities) {
      final label = ActivityMetrics.placeLabel(
        placeName: a.placeDetail ?? a.placeName,
        groupId: a.groupId,
      );
      final acc = map.putIfAbsent(label, () => _CourseAccum(label));
      acc.visits += 1;
      acc.totalDistanceMeters += a.distanceMeters;
      acc.totalDurationSeconds += a.durationSeconds;
      acc.totalWeightGrams += ActivityMetrics.weightGrams(a.trashCounts);
      // 대표 경로: 최근(목록이 최신순) 활동 중 경로가 있는 첫 번째를 채택
      if (acc.path.isEmpty && a.path.length >= 2) {
        acc.path = a.path;
      }
    }
    final result = map.values.map((e) => e.toCourse()).toList();
    // 방문 횟수 내림차순, 동률이면 누적 수거량 내림차순
    result.sort((a, b) {
      final byVisits = b.visits.compareTo(a.visits);
      if (byVisits != 0) return byVisits;
      return b.totalWeightGrams.compareTo(a.totalWeightGrams);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단 바 — 뒤로 + 제목
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
                      '자주 가는 코스',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_courses != null && _courses!.isNotEmpty)
                    Text(
                      '${_courses!.length}곳',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray500,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // 로딩 / 에러 / 빈 / 목록
  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '코스를 불러오지 못했어요',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_courses == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.progress,
          strokeWidth: 2,
        ),
      );
    }
    if (_courses!.isEmpty) {
      return const _EmptyCourses();
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        22,
        4,
        22,
        MediaQueryData.fromView(View.of(context)).padding.bottom + 24,
      ),
      itemCount: _courses!.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, thickness: 1, color: AppColors.line100),
      itemBuilder: (_, i) => _courseRow(_courses![i]),
    );
  }

  // 목업: 경로 미니 지도 썸네일(54) + 코스명(핀) + 평균 거리·시간 + 방문·누적
  Widget _courseRow(_Course c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // 코스 대표 경로 썸네일 (경로 없으면 '경로 없음' 표시)
          ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: SizedBox(
              width: 54,
              height: 54,
              child: CustomPaint(painter: RoutePainter(path: c.path)),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      TablerIcons.mapPin,
                      size: 14,
                      color: AppColors.gray400,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_kmLabel(c.avgDistanceMeters)} · ${_minLabel(c.avgDurationSeconds)} 예상',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${c.visits}회 방문 · 누적 ${_weightLabel(c.totalWeightGrams)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // '2.4km' (평균 거리)
  String _kmLabel(double meters) => '${(meters / 1000.0).toStringAsFixed(1)}km';

  // '38분' (평균 소요 시간)
  String _minLabel(int seconds) => '${(seconds / 60).round()}분';

  // 누적 수거량 — 1000g 이상은 kg, 미만은 g
  String _weightLabel(int grams) {
    if (grams >= 1000) return '${(grams / 1000.0).toStringAsFixed(1)}kg';
    return '${grams}g';
  }
}

// 코스가 하나도 없을 때 보여주는 정직한 빈 화면
class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TablerIcons.route, size: 48, color: AppColors.gray400),
            SizedBox(height: 14),
            Text(
              '아직 자주 가는 코스가 없어요',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '같은 장소에서 플로깅을 반복하면\n자주 가는 코스가 여기에 모여요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 집계 누적기 — 장소 라벨별로 활동을 합산하는 임시 버킷
class _CourseAccum {
  final String name;
  int visits = 0;
  double totalDistanceMeters = 0;
  int totalDurationSeconds = 0;
  int totalWeightGrams = 0;
  List<Map<String, dynamic>> path = const [];

  _CourseAccum(this.name);

  _Course toCourse() {
    final safeVisits = visits == 0 ? 1 : visits;
    return _Course(
      name: name,
      visits: visits,
      avgDistanceMeters: totalDistanceMeters / safeVisits,
      avgDurationSeconds: (totalDurationSeconds / safeVisits).round(),
      totalWeightGrams: totalWeightGrams,
      path: path,
    );
  }
}

// 화면에 그릴 코스 한 건 (집계 결과)
class _Course {
  final String name;
  final int visits;
  final double avgDistanceMeters;
  final int avgDurationSeconds;
  final int totalWeightGrams;
  final List<Map<String, dynamic>> path;

  const _Course({
    required this.name,
    required this.visits,
    required this.avgDistanceMeters,
    required this.avgDurationSeconds,
    required this.totalWeightGrams,
    required this.path,
  });
}
