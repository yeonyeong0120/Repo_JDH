import 'package:repo_jdh/features/plogging/domain/activity.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';

/// 그래프 한 구간(주/월/누적)의 집계 결과.
/// 화면(_GData)이 필요로 하는 값을 그대로 담는다.
class GraphBucket {
  final String title; // '이번주' / '이번달' / '전체'
  final String range; // '5.24 ~ 5.31' 등
  final int steps; // 총 걸음
  final int kcal; // 총 칼로리
  final int weightG; // 총 수거 무게(g)
  final List<double> bars; // 0~1 비율 (요일별/주별). 누적은 빈 리스트
  final List<String> barLabels; // 막대 라벨
  final int peakIndex; // 가장 높은 막대 인덱스

  const GraphBucket({
    required this.title,
    required this.range,
    required this.steps,
    required this.kcal,
    required this.weightG,
    required this.bars,
    required this.barLabels,
    required this.peakIndex,
  });

  /// 완전히 빈 버킷 (기록 0건일 때)
  factory GraphBucket.empty({
    required String title,
    required String range,
    required List<String> barLabels,
  }) {
    return GraphBucket(
      title: title,
      range: range,
      steps: 0,
      kcal: 0,
      weightG: 0,
      bars: List<double>.filled(barLabels.length, 0.0),
      barLabels: barLabels,
      peakIndex: 0,
    );
  }
}

/// 수거 종류별 집계 (도넛 차트용)
class CategoryStat {
  final String category; // 'can' / 'glass' ...
  final int count;
  const CategoryStat(this.category, this.count);
}

/// 활동 기록 리스트 → 그래프용 데이터로 집계하는 유틸.
///
/// 화면은 이 결과만 받아서 그리면 된다. (집계 계산은 전부 여기 모음)
class ActivityStats {
  static const List<String> dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  /// 주간 버킷 목록 (최근 주부터 과거로 [최근, 지난주, 2주전])
  /// 각 주 안에서 요일별(월~일) 걸음 합계를 막대로.
  static List<GraphBucket> weekly(
    List<Activity> acts, {
    int weeks = 3,
    double? weightKg,
    String? gender,
  }) {
    final now = DateTime.now();
    // 이번 주 월요일 0시
    final thisMonday = _mondayOf(now);

    final buckets = <GraphBucket>[];
    for (int w = 0; w < weeks; w++) {
      final weekStart = thisMonday.subtract(Duration(days: 7 * w));
      final weekEnd = weekStart.add(const Duration(days: 7));

      // 이 주에 속한 활동만
      final inWeek = acts.where((a) {
        final t = a.endedAt ?? a.startedAt;
        return !t.isBefore(weekStart) && t.isBefore(weekEnd);
      }).toList();

      // 요일별 걸음 합계 (월=0 ... 일=6)
      final daySteps = List<int>.filled(7, 0);
      int totalSteps = 0, totalKcal = 0, totalWeight = 0;
      for (final a in inWeek) {
        final t = a.endedAt ?? a.startedAt;
        final dow = t.weekday - 1; // Mon=1 → 0
        final s = ActivityMetrics.estimateSteps(a.distanceMeters);
        daySteps[dow] += s;
        totalSteps += s;
        totalKcal += ActivityMetrics.estimateKcal(
          distanceMeters: a.distanceMeters,
          durationSeconds: a.durationSeconds,
          weightKg: weightKg,
          gender: gender,
        );
        totalWeight += ActivityMetrics.weightGrams(a.trashCounts);
      }

      buckets.add(_toBucket(
        title: w == 0 ? '이번주' : (w == 1 ? '지난주' : '$w주 전'),
        range: '${_md(weekStart)} ~ ${_md(weekEnd.subtract(const Duration(days: 1)))}',
        dayValues: daySteps,
        labels: dayLabels,
        steps: totalSteps,
        kcal: totalKcal,
        weightG: totalWeight,
      ));
    }
    return buckets;
  }

  /// 월간 버킷 목록 (최근 달부터 과거로)
  /// 각 달 안에서 '주차별' 걸음 합계를 막대로.
  static List<GraphBucket> monthly(
    List<Activity> acts, {
    int months = 2,
    double? weightKg,
    String? gender,
  }) {
    final now = DateTime.now();
    final buckets = <GraphBucket>[];

    for (int m = 0; m < months; m++) {
      final month = DateTime(now.year, now.month - m, 1);
      final nextMonth = DateTime(month.year, month.month + 1, 1);

      final inMonth = acts.where((a) {
        final t = a.endedAt ?? a.startedAt;
        return !t.isBefore(month) && t.isBefore(nextMonth);
      }).toList();

      // 주차(1~5) 별 걸음 합계
      final weekSteps = List<int>.filled(5, 0);
      int totalSteps = 0, totalKcal = 0, totalWeight = 0;
      for (final a in inMonth) {
        final t = a.endedAt ?? a.startedAt;
        final weekIdx = ((t.day - 1) ~/ 7).clamp(0, 4);
        final s = ActivityMetrics.estimateSteps(a.distanceMeters);
        weekSteps[weekIdx] += s;
        totalSteps += s;
        totalKcal += ActivityMetrics.estimateKcal(
          distanceMeters: a.distanceMeters,
          durationSeconds: a.durationSeconds,
          weightKg: weightKg,
          gender: gender,
        );
        totalWeight += ActivityMetrics.weightGrams(a.trashCounts);
      }

      buckets.add(_toBucket(
        title: m == 0 ? '이번달' : (m == 1 ? '지난달' : '${month.month}월'),
        range: '${month.year}.${month.month.toString().padLeft(2, '0')}',
        dayValues: weekSteps,
        labels: const ['1주', '2주', '3주', '4주', '5주'],
        steps: totalSteps,
        kcal: totalKcal,
        weightG: totalWeight,
      ));
    }
    return buckets;
  }

  /// 누적 버킷 (가입일부터 전체 합계, 막대 없음)
  static GraphBucket cumulative(
    List<Activity> acts, {
    DateTime? joinedAt,
    double? weightKg,
    String? gender,
  }) {
    int totalSteps = 0, totalKcal = 0, totalWeight = 0;
    for (final a in acts) {
      totalSteps += ActivityMetrics.estimateSteps(a.distanceMeters);
      totalKcal += ActivityMetrics.estimateKcal(
        distanceMeters: a.distanceMeters,
        durationSeconds: a.durationSeconds,
        weightKg: weightKg,
        gender: gender,
      );
      totalWeight += ActivityMetrics.weightGrams(a.trashCounts);
    }
    final rangeText = joinedAt != null
        ? '가입일(${joinedAt.year}.${joinedAt.month.toString().padLeft(2, '0')}.${joinedAt.day.toString().padLeft(2, '0')}~)부터'
        : '전체 기간';
    return GraphBucket(
      title: '전체',
      range: rangeText,
      steps: totalSteps,
      kcal: totalKcal,
      weightG: totalWeight,
      bars: const [],
      barLabels: const [],
      peakIndex: 0,
    );
  }

  /// 수거 종류별 합계 (도넛 차트용) — 전체 활동 기준
  static List<CategoryStat> categoryTotals(List<Activity> acts) {
    final totals = <String, int>{};
    for (final a in acts) {
      a.trashCounts.forEach((k, v) {
        totals[k] = (totals[k] ?? 0) + v;
      });
    }
    return totals.entries.map((e) => CategoryStat(e.key, e.value)).toList();
  }

  /// 총 활동 일수 — 활동한 '날짜'의 개수 (하루에 여러 번 해도 1일)
  ///
  /// 예) 7/28 아침 + 7/28 저녁 + 7/29 → 2일
  static int totalActiveDays(List<Activity> acts) {
    final days = <String>{}; // 중복 제거용 (같은 날은 한 번만)
    for (final a in acts) {
      final t = a.endedAt ?? a.startedAt;
      days.add('${t.year}-${t.month}-${t.day}');
    }
    return days.length;
  }

  /// 특정 '주'에 속한 활동만 거른다.
  /// weekOffset: 0=이번주, 1=지난주 ...
  static List<Activity> inWeek(List<Activity> acts, int weekOffset) {
    final thisMonday = _mondayOf(DateTime.now());
    final start = thisMonday.subtract(Duration(days: 7 * weekOffset));
    final end = start.add(const Duration(days: 7));
    return acts.where((a) {
      final t = a.endedAt ?? a.startedAt;
      return !t.isBefore(start) && t.isBefore(end);
    }).toList();
  }

  /// 특정 '달'에 속한 활동만 거른다.
  /// monthOffset: 0=이번달, 1=지난달 ...
  static List<Activity> inMonth(List<Activity> acts, int monthOffset) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month - monthOffset, 1);
    final next = DateTime(month.year, month.month + 1, 1);
    return acts.where((a) {
      final t = a.endedAt ?? a.startedAt;
      return !t.isBefore(month) && t.isBefore(next);
    }).toList();
  }

  // ── 내부 헬퍼 ──

  // 걸음 합계 리스트 → 0~1 비율 막대 + 최고점 인덱스로 변환
  static GraphBucket _toBucket({
    required String title,
    required String range,
    required List<int> dayValues,
    required List<String> labels,
    required int steps,
    required int kcal,
    required int weightG,
  }) {
    final maxV = dayValues.fold<int>(0, (a, b) => b > a ? b : a);
    // 최댓값이 0이면 모든 막대 0 (0으로 나누기 방지)
    final bars = maxV == 0
        ? List<double>.filled(dayValues.length, 0.0)
        : dayValues.map((v) => v / maxV).toList();
    int peak = 0;
    for (int i = 1; i < dayValues.length; i++) {
      if (dayValues[i] > dayValues[peak]) peak = i;
    }
    return GraphBucket(
      title: title,
      range: range,
      steps: steps,
      kcal: kcal,
      weightG: weightG,
      bars: bars,
      barLabels: labels,
      peakIndex: peak,
    );
  }

  // 그 주의 월요일 0시
  static DateTime _mondayOf(DateTime d) {
    final base = DateTime(d.year, d.month, d.day);
    return base.subtract(Duration(days: base.weekday - 1));
  }

  // "5.24" 형태
  static String _md(DateTime d) => '${d.month}.${d.day}';

  // ── 화면 표시용 포맷 헬퍼 ──

  /// 천단위 콤마 (예: 8240 → "8,240")
  static String comma(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  /// 무게(g) → "1.3kg" 또는 "700g"
  static String weightLabel(int grams) {
    if (grams >= 1000) return '${(grams / 1000.0).toStringAsFixed(1)}kg';
    return '${grams}g';
  }
}