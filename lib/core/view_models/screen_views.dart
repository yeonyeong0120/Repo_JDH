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

import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';
import 'package:repo_jdh/features/mypage/domain/level_system.dart';
import 'package:repo_jdh/features/mypage/domain/profile_detail.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';
import 'package:repo_jdh/features/home/domain/eco_math.dart';

import 'package:repo_jdh/features/auth/data/user_service.dart';
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

  const HomeView({
    required this.profile,
    required this.stats,
    required this.week,
    required this.groups,
    required this.news,
  });

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

  // ── 레벨 (LevelSystem 이 유일한 계산 주체) ──
  LevelInfo get levelInfo => LevelSystem.of(profile.xp);
  int get level => levelInfo.level;
  double get xpRatio => levelInfo.progress;
  int get xpRemaining => levelInfo.remainingXp;

  // ── 동네 ──
  /// 그룹들의 오늘 활동 인원 합.
  int get regionActiveTodayCount =>
      groups.fold<int>(0, (a, g) => a + g.todayActiveCount);

  bool get hasNews => news.isNotEmpty;
  bool get hasGroups => groups.isNotEmpty;
}

/// 홈이 watch 하는 단 하나의 provider.
///
/// 서비스들이 static async 함수라 FutureProvider 로 감싼다.
/// 5개를 병렬로 불러 첫 페인트를 늦추지 않는다.
///
/// 뉴스는 실패해도 화면 전체를 막지 않는다 — 빈 목록으로 넘긴다.
/// (FastAPI 서버가 Gemini 요약까지 하므로 최대 30초까지 걸릴 수 있음)
// ⚠️ 임시 뉴스 데이터 — FastAPI/Gemini 서버 없이 뉴스 화면을 확인하기 위한 용도.
// 실데이터가 비었을 때만 쓰이며, 서버가 붙으면 자동으로 사라진다. 배포 전 삭제.
const List<NewsArticle> _devNews = [
  NewsArticle(
    category: '재활용',
    title: '투명 페트병 분리배출, 이렇게만 하면 됩니다',
    summary: '라벨을 떼고 압착해 뚜껑을 닫으면 재활용률이 크게 올라갑니다.',
    reporter: '김세연 기자',
    date: '8월 4일',
    emoji: '♻️',
    sourceName: '환경일보',
    // 이미지 있는 뉴스 확인용 샘플(첫 기사만). 나머지는 이미지 없이 글만.
    imageUrl: 'https://picsum.photos/seed/ploggo-news/800/500',
    aiSummary: [
      '라벨을 떼고 압착한 뒤 뚜껑을 닫아 배출하면 재활용 등급이 올라갑니다.',
      '투명 페트병만 따로 모으는 전용 수거함이 아파트 단지 위주로 늘고 있습니다.',
      '내용물을 비우고 물로 한 번 헹구는 것만으로도 선별 비용이 크게 줄어듭니다.',
    ],
    body: [
      '환경부가 발표한 자료에 따르면 투명 페트병 별도 배출 제도가 시행된 이후 고품질 재생 원료 확보량이 꾸준히 늘고 있다. 다만 라벨이 붙은 채로 배출되는 비율이 여전히 높아 선별장에서 추가 작업이 필요한 상황이다.',
      '전문가들은 배출 단계에서의 간단한 처리만으로도 재활용 품질이 크게 달라진다고 설명한다. 내용물을 비우고 라벨을 제거한 뒤 압착해 뚜껑을 닫는 네 단계면 충분하다는 것이다.',
      '지자체들도 전용 수거함 설치를 늘리고 있다. 인천시는 올해 아파트 단지와 주요 공원을 중심으로 투명 페트병 전용 수거함을 추가 설치할 계획이라고 밝혔다.',
    ],
  ),
  NewsArticle(
    category: '정책',
    title: '인천시, 하천 정화 거점 40곳으로 확대',
    summary: '남동구·연수구 중심으로 수거함과 집게 대여소를 늘립니다.',
    reporter: '인천시 환경국',
    date: '8월 2일',
    emoji: '🏞️',
    sourceName: '인천시',
    aiSummary: [
      '인천시가 하천 정화 거점을 기존 24곳에서 40곳으로 늘립니다.',
      '거점마다 수거 봉투와 집게를 무료로 대여할 수 있습니다.',
      '남동구·연수구 하천 산책로에 우선 설치될 예정입니다.',
    ],
    body: [
      '인천시는 시민 참여형 하천 정화 활동을 지원하기 위해 정화 거점을 대폭 확대한다고 밝혔다. 거점에는 수거 봉투와 집게가 상시 구비되며 별도 신청 없이 사용할 수 있다.',
      '시는 특히 산책 인구가 많은 만수천, 승기천, 장수천 구간을 우선 대상으로 삼았다. 걷기와 정화 활동을 함께하는 시민이 늘고 있다는 판단에서다.',
      '거점 위치는 시 환경국 누리집과 플로깅 앱에서 확인할 수 있다.',
    ],
  ),
  NewsArticle(
    category: '생활',
    title: '장바구니 하나로 줄이는 연간 비닐 300장',
    summary: '한 사람이 1년에 쓰는 비닐봉지는 평균 320장으로 집계됐습니다.',
    reporter: '이도현 기자',
    date: '8월 1일',
    emoji: '🛍️',
    sourceName: '그린포스트',
    aiSummary: [
      '국내 1인당 연간 비닐봉지 사용량은 평균 320장으로 조사됐습니다.',
      '장바구니를 상시 휴대하면 대부분을 대체할 수 있습니다.',
      '접이식 장바구니는 무게가 60g 안팎으로 부담이 적습니다.',
    ],
    body: [
      '한 소비자 단체 조사에서 국내 1인당 연간 비닐봉지 사용량이 평균 320장으로 나타났다. 이 가운데 상당수는 장바구니로 충분히 대체할 수 있는 용도였다.',
      '조사를 진행한 관계자는 습관의 문제라고 지적했다. 접이식 장바구니는 무게가 60g 안팎으로 가방에 상시 넣어둘 수 있다는 것이다.',
      '지자체들도 장바구니 보급 사업을 이어가고 있다.',
    ],
  ),
];

final homeViewProvider = FutureProvider<HomeView>((ref) async {
  final results = await Future.wait([
    UserService.loadProfileDetail(),
    BadgeService.loadStats(),
    GroupService.myGroup(),
    GroupService.otherGroups(limit: 3), // 홈 '지금 우리 동네는': 최대 3개
    ActivityService.getRecentCompleted(limit: 30),
    NewsService.fetchNews(display: 5).catchError(
      (_) => <NewsArticle>[], // 뉴스 실패는 홈을 막지 않는다
    ),
  ]);

  final profile = results[0] as ProfileDetail;
  final stats = results[1] as UserStats;
  // results[2] = 내 그룹. 홈 '지금 우리 동네는'에는 쓰지 않으므로 받지 않는다.
  final others = results[3] as List<Group>;
  final activities = results[4] as List<Activity>;
  final news = results[5] as List<NewsArticle>;

  final sorted = [...others]
    ..sort((a, b) => b.todayActiveCount.compareTo(a.todayActiveCount));

  return HomeView(
    profile: profile,
    stats: stats,
    week: weekFromActivities(activities),
    // '지금 우리 동네는'은 내 그룹을 빼고 다른 동네 그룹만 보여준다.
    groups: sorted,
    // ⚠️ 임시: 서버(FastAPI/Gemini)에서 뉴스를 못 받으면 확인용 임시 데이터를 쓴다.
    // 서버가 붙으면 자동으로 실데이터로 대체된다. 배포 전 _devNews 와 이 분기 삭제.
    news: news.isEmpty ? _devNews : news,
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
