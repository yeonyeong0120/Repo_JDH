/// 화면이 필요로 하는 데이터를 화면별 뷰모델 하나로 모아둔 파일.
///
/// ⚠ 도메인 타입을 새로 만들지 않는다.
///   ProfileDetail / UserStats / Group / Activity / NewsArticle 을 그대로 담고,
///   화면이 매번 계산하던 파생값만 getter로 노출한다.
///   레벨 환산도 LevelSystem 을 쓴다 (자체 계산 금지).
///
/// 규칙
///  1. 화면은 provider 하나만 watch 한다 → `xxxViewProvider`
///  2. 위젯 안에서 계산하지 않는다.
///  3. 뷰모델은 불변. Firestore를 모른다.
///  4. "없을 수도 있는" 상태에는 이름을 붙인다 (isFirstDay 등).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:repo_jdh/core/providers/auth_provider.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';
import 'package:repo_jdh/features/mypage/domain/level_system.dart';
import 'package:repo_jdh/features/mypage/domain/profile_detail.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';
import 'package:repo_jdh/features/home/domain/eco_math.dart';

import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/features/home/data/weather_service.dart';
import 'package:repo_jdh/features/news/presentation/news_service.dart';
import 'package:repo_jdh/features/news/presentation/news_detail_screen.dart';

// ════════════════════════════════════════════════════════════
// 홈에서만 쓰는 값 타입
// ════════════════════════════════════════════════════════════

/// 화분 스트립 한 칸. Activity 목록에서 파생시킨다.
class DayLog {
  final DateTime date;
  final bool done;
  final bool isToday;
  const DayLog({required this.date, required this.done, this.isToday = false});

  String get weekdayLabel =>
      const ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1];
}

// ════════════════════════════════════════════════════════════
// 홈
// ════════════════════════════════════════════════════════════

class HomeView {
  final ProfileDetail profile;
  final UserStats stats;

  /// 월~일 7칸. 활동 기록에서 만든다.
  final List<DayLog> week;

  /// '지금 우리 동네는'에 보여줄 동네(다른) 그룹. 오늘 활동 많은 순.
  /// 내 그룹은 여기에 포함하지 않는다.
  final List<Group> groups;

  final List<NewsArticle> news;

  /// '인증샷 모음집' — 사진이 있는 내 최근 활동 최대 5개. 그룹 가입 여부와 무관.
  final List<Activity> photos;

  final int? weatherTemp;
  final String? weatherPm10Grade;

  const HomeView({
    required this.profile,
    required this.stats,
    required this.week,
    required this.groups,
    required this.news,
    this.photos = const [],
    this.weatherTemp,
    this.weatherPm10Grade,
  });

  // 값 없으면 '-' — 가짜 값으로 채우지 않는다.
  String get tempLabel => weatherTemp != null ? '$weatherTemp°' : '-';
  String get pmGradeLabel => weatherPm10Grade ?? '-';

  // ── 인사 영역 ──
  String get userName => profile.nickname;
  String get region => profile.region;
  int get points => profile.points;

  /// '2월 4일 화요일'
  String get dateLabel {
    final n = DateTime.now();
    const w = ['월', '화', '수', '목', '금', '토', '일'];
    return '${n.month}월 ${n.day}일 ${w[n.weekday - 1]}요일';
  }

  // ── 상태 분기 ──
  /// 활동이 한 번도 없으면 성과 대신 '앞으로 생길 일'을 보여준다.
  bool get isFirstDay => stats.ploggingCount == 0;

  int get streakDays => stats.streakDays;
  int get weekDoneCount => week.where((d) => d.done).length;

  // ── 성과 (가입 이후 누적) ──
  double get totalTrashKg => stats.totalWeightKg;
  int get totalSteps => stats.totalSteps;
  double get carbonKg => EcoMath.carbonKg(totalTrashKg);
  double get pineTrees => EcoMath.pineTrees(carbonKg);

  // ── 연간 탄소 감축 목표 대비 진행률 (홈 '나의 환경 영향력' 도넛) ──
  // 목표 10kgCO2eq/년 기준. (예: 2.1kg → 21%)
  static const double annualCarbonGoalKg = 10.0;
  double get annualGoalRatio => (carbonKg / annualCarbonGoalKg).clamp(0.0, 1.0);
  int get annualGoalPercent => (annualGoalRatio * 100).round();

  // ── 레벨 (LevelSystem 이 유일한 계산 주체) ──
  LevelInfo get levelInfo => LevelSystem.of(profile.xp);
  int get level => levelInfo.level;
  double get xpRatio => levelInfo.progress;
  int get xpRemaining => levelInfo.remainingXp;

  // ── 동네 ──
  /// 사용자 프로필의 행정구(예: '남동구'). 홈 섹션 제목에 쓴다.
  /// 주소가 비어 있으면 '우리 동네'로 대체한다.
  String get userDistrict {
    final region = profile.region.trim();
    if (region.isEmpty) return '우리 동네';
    final gu = RegExp(r'([가-힣]+구)').firstMatch(region)?.group(1);
    return gu ?? region.split(' ').last;
  }

  /// 그룹들의 오늘 활동 인원 합.
  int get regionActiveTodayCount =>
      groups.fold<int>(0, (a, g) => a + g.todayActiveCount);

  bool get hasNews => news.isNotEmpty;
  bool get hasGroups => groups.isNotEmpty;
  bool get hasPhotos => photos.isNotEmpty;
}

/// 홈이 watch 하는 단 하나의 provider.
///
/// 서비스들이 static async 함수라 FutureProvider 로 감싼다.
/// 5개를 병렬로 불러 첫 페인트를 늦추지 않는다.
///
/// 뉴스는 실패해도 화면 전체를 막지 않는다 — 빈 목록으로 넘긴다.
/// (FastAPI 서버가 Gemini 요약까지 하므로 최대 30초까지 걸릴 수 있음)
final homeViewProvider = FutureProvider<HomeView>((ref) async {
  // 로그인 사용자(uid)가 바뀌면 홈을 처음부터 다시 로드한다.
  // (안 그러면 이전 사용자 프로필이 캐시돼 닉네임이 '가나디' 등으로 고정된다)
  ref.watch(authStateProvider.select((s) => s.valueOrNull?.uid));

  // 프로필·통계는 홈의 뼈대라 실패하면 에러 상태를 보여준다.
  // 나머지(동네 그룹·최근 활동·뉴스)는 부가 섹션이라 하나가 실패해도
  // 빈 값으로 넘겨 홈 전체가 "불러오지 못했어요"로 빠지지 않게 한다.
  // 날씨는 프로필의 저장된 좌표(regionLat/regionLng)가 있어야 부를 수 있다.
  // 프로필 로드에 체이닝해서, 다른 병렬 작업(특히 최대 30초 걸리는 뉴스)을
  // 막지 않으면서 의존 관계만 지킨다.
  final profileFuture = UserService.loadProfileDetail();
  final weatherFuture = profileFuture.then((p) async {
    final lat = p.regionLat, lng = p.regionLng;
    // 좌표가 없으면 호출 자체를 생략한다 — (0,0)으로 부르면 엉뚱한(아프리카
    // 앞바다) 날씨가 오는데, 그게 자기 동네 날씨인 줄 알면 더 나쁘다.
    if (lat == null || lng == null) return null;
    return WeatherService.fetch(lat: lat, lng: lng, region: p.region);
  }).catchError((_) => null);

  final results = await Future.wait([
    profileFuture,
    BadgeService.loadStats(),
    GroupService.otherGroups(limit: 3).catchError(
      (_) => <Group>[],
    ), // 홈 '지금 우리 동네는': 최대 3개
    ActivityService.getRecentCompleted(limit: 30).catchError(
      (_) => <Activity>[],
    ),
    NewsService.fetchNews(display: 5).catchError(
      (_) => <NewsArticle>[], // 뉴스 실패는 홈을 막지 않는다
    ),
    weatherFuture,
  ]);

  final profile = results[0] as ProfileDetail;
  final stats = results[1] as UserStats;
  final others = results[2] as List<Group>;
  final activities = results[3] as List<Activity>;
  final news = results[4] as List<NewsArticle>;
  final weather = results[5] as ({int? temp, String? pm10Grade})?;

  final sorted = [...others]
    ..sort((a, b) => b.todayActiveCount.compareTo(a.todayActiveCount));

  // '인증샷 모음집' — getRecentCompleted 가 이미 최신순이라 별도 정렬 불필요.
  final photos = activities.where((a) => a.imageUrls.isNotEmpty).take(5).toList();

  return HomeView(
    profile: profile,
    stats: stats,
    week: weekFromActivities(activities),
    // '지금 우리 동네는'은 내 그룹을 빼고 다른 동네 그룹만 보여준다.
    groups: sorted,
    news: news,
    photos: photos,
    weatherTemp: weather?.temp,
    weatherPm10Grade: weather?.pm10Grade,
  );
});

/// 활동 기록 → 이번 주 화분 7칸.
/// 월요일 시작. 아직 오지 않은 날도 자리는 만든다(빈 화분).
List<DayLog> weekFromActivities(List<Activity> activities) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - 1));

  final doneDays = activities
      .where((a) => a.status == ActivityStatus.completed)
      .map((a) {
        final d = a.endedAt ?? a.startedAt;
        return DateTime(d.year, d.month, d.day);
      })
      .toSet();

  return List.generate(7, (i) {
    final d = monday.add(Duration(days: i));
    return DayLog(date: d, done: doneDays.contains(d), isToday: d == today);
  });
}
