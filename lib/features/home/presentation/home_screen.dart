import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

// 실연동 데이터 소스 (팀원 홈과 동일)
import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/domain/activity_stats.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';
import 'package:repo_jdh/features/plogging/data/attendance_service.dart';
import 'package:repo_jdh/features/mypage/domain/level_system.dart';
import 'package:repo_jdh/features/news/presentation/news_service.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:repo_jdh/features/community/domain/group.dart' as gm;

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/core/widgets/app_card.dart';
import 'package:repo_jdh/core/widgets/app_section.dart';
import 'package:repo_jdh/core/widgets/app_stat.dart';
import 'package:repo_jdh/features/home/domain/eco_math.dart';

// ============================================================
// 화면이 필요로 하는 데이터 (뷰 모델)
// 실제 provider들(auth / plogging / group / news)에서 조립해 넘길 것.
// ============================================================

class DayLog {
  final DateTime date;
  final bool done;
  final bool isToday;
  const DayLog({required this.date, required this.done, this.isToday = false});
}

class NewsItem {
  final String title;
  final String summary;
  final String source;
  final String timeAgo;
  final String? thumbnailUrl;
  final String url;
  const NewsItem({
    required this.title,
    required this.summary,
    required this.source,
    required this.timeAgo,
    required this.url,
    this.thumbnailUrl,
  });
}

class NeighborGroup {
  final String id;
  final String name;
  final int memberCount;
  final int activeTodayCount;
  final String? imageUrl;
  const NeighborGroup({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.activeTodayCount,
    this.imageUrl,
  });
}

class HomeView {
  final String userName;
  final String dateLabel; // "2월 1일 일요일"
  final String region; // "인천 부평구"
  final int points;

  final List<DayLog> week; // 월~일 7개
  final int streakDays;

  final double totalTrashKg; // 가입 이후 누적
  final int totalSteps;
  final int level;
  final int xp;
  final int xpMax;

  final List<NewsItem> news;
  final List<NeighborGroup> groups;
  final int regionActiveTodayCount;

  const HomeView({
    required this.userName,
    required this.dateLabel,
    required this.region,
    required this.points,
    required this.week,
    required this.streakDays,
    required this.totalTrashKg,
    required this.totalSteps,
    required this.level,
    required this.xp,
    required this.xpMax,
    required this.news,
    required this.groups,
    required this.regionActiveTodayCount,
  });

  /// 활동이 한 번도 없으면 상단 두 블록을 '첫날' 문구로 바꾼다.
  bool get isFirstDay => totalTrashKg == 0 && streakDays == 0;

  int get weekDoneCount => week.where((d) => d.done).length;
  double get carbonKg => EcoMath.carbonKg(totalTrashKg);
}

/// 홈 화면 데이터 조립 — 각 서비스(실연동)에서 모아 HomeView 로 만든다.
/// autoDispose: 홈을 벗어나면 폐기, 다시 들어오면 새로 로드(최신 반영).
final homeViewProvider = FutureProvider.autoDispose<HomeView>((ref) async {
  // 프로필(닉네임·지역·포인트) — Firestore (ProfileDetail: points·region 포함)
  final profile = await UserService.loadProfileDetail();
  final nickname = profile.nickname.isEmpty ? '플로거' : profile.nickname;
  final region = profile.region;
  final points = profile.points;

  // 활동 기록 → 이번주 통계 + 전체 XP + 활동 일수
  final acts = await ActivityService.getRecentCompleted(limit: 200);
  final thisWeek = ActivityStats.inWeek(acts, 0);
  int weekSteps = 0, weekKcal = 0, weekWeightG = 0;
  for (final a in thisWeek) {
    weekSteps += ActivityMetrics.estimateSteps(a.distanceMeters);
    weekKcal += ActivityMetrics.estimateKcal(a.distanceMeters);
    weekWeightG += ActivityMetrics.weightGrams(a.trashCounts);
  }
  final totalXp = acts.length * 20; // 활동 1회 = 20 XP
  final lv = LevelSystem.of(totalXp);
  final activeDays = ActivityStats.totalActiveDays(acts);

  // 누적 수거 무게(kg) — 전체 활동 기준
  int totalWeightG = 0;
  int totalSteps = 0;
  for (final a in acts) {
    totalWeightG += ActivityMetrics.weightGrams(a.trashCounts);
    totalSteps += ActivityMetrics.estimateSteps(a.distanceMeters);
  }

  // 출석(화분) — 오늘 출석 찍고 이번주 출석 요일 집합
  Set<int> attended = {};
  try {
    await AttendanceService.markToday();
    attended = await AttendanceService.weekAttendance();
  } catch (_) {
    // 실패해도 홈은 뜨게
  }
  final now = DateTime.now();
  final base = DateTime(now.year, now.month, now.day);
  final monday = base.subtract(Duration(days: base.weekday - 1));
  final week = <DayLog>[
    for (int i = 0; i < 7; i++)
      DayLog(
        date: monday.add(Duration(days: i)),
        done: attended.contains(i),
        isToday: i == base.weekday - 1,
      ),
  ];

  // 뉴스 — 서버에서 최신 3개
  final news = <NewsItem>[];
  try {
    final list = await NewsService.fetchNews(display: 3);
    for (final a in list) {
      news.add(
        NewsItem(
          title: a.title,
          summary: a.summary,
          source: a.reporter,
          timeAgo: a.date,
          url: a.sourceUrl,
        ),
      );
    }
  } catch (_) {
    // 실패 시 빈 목록 (카드가 안내 문구 표시)
  }

  // 동네 그룹 — 내 그룹 제외
  final groups = <NeighborGroup>[];
  try {
    final others = await GroupService.otherGroups(limit: 10);
    for (final gm.Group g in others) {
      groups.add(
        NeighborGroup(
          id: g.id,
          name: g.name,
          memberCount: g.memberCount,
          activeTodayCount: g.todayActiveCount,
        ),
      );
    }
  } catch (_) {
    // 실패 시 빈 목록
  }

  final dateLabel = '${now.month}월 ${now.day}일 ${_weekdayKo(now.weekday)}';

  return HomeView(
    userName: nickname,
    dateLabel: dateLabel,
    region: region,
    points: points,
    week: week,
    streakDays: activeDays, // '연속'이 아니라 누적 활동일수 (팀원 홈과 동일 기준)
    totalTrashKg: totalWeightG / 1000.0,
    totalSteps: totalSteps,
    level: lv.level,
    xp: lv.currentXp,
    xpMax: lv.neededXp,
    news: news,
    groups: groups,
    regionActiveTodayCount: groups.fold<int>(
      0,
      (a, g) => a + g.activeTodayCount,
    ),
  );
});

String _weekdayKo(int weekday) {
  const names = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
  return names[(weekday - 1) % 7];
}

// ============================================================
// 화면
// ============================================================

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeViewProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '홈을 불러오지 못했어요\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
        data: (v) => SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(homeViewProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Greeting(v: v),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.screenPad,
                      Gap.xl,
                      Gap.screenPad,
                      Gap.navSafe,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WeekCard(v: v),
                        const SizedBox(height: Gap.section),
                        AppSection(
                          title: '내가 만든 변화',
                          caption: '가입 이후 누적',
                          onMore: () {}, // TODO: 마이 임팩트 화면
                          child: _ImpactCard(v: v),
                        ),
                        AppSection(
                          title: '알아두면 좋은 소식',
                          onMore: () {}, // TODO: 뉴스 피드
                          child: Column(
                            children: [
                              for (final n in v.news.take(2)) ...[
                                _NewsCard(item: n),
                                if (n != v.news.take(2).last) Gap.h12,
                              ],
                            ],
                          ),
                        ),
                        AppSection(
                          title: '지금 우리 동네는',
                          caption:
                              '${v.region}에서 오늘 ${v.regionActiveTodayCount}명이 활동했어요',
                          onMore: () {}, // TODO: 그룹 탭
                          last: true,
                          child: Column(
                            children: [
                              for (final g in v.groups.take(2)) ...[
                                _GroupCard(group: g),
                                if (g != v.groups.take(2).last) Gap.h12,
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 인사 ──────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  final HomeView v;
  const _Greeting({required this.v});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        Gap.screenPad,
        Gap.sm,
        Gap.screenPad,
        Gap.xl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${v.dateLabel} · ${v.region}',
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Gap.h8,
                Text('${v.userName} 님,\n오늘도 한 바퀴 어때요?', style: AppType.title1),
              ],
            ),
          ),
          Gap.w16,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {}, // TODO: 마이페이지
                borderRadius: Radii.fullR,
                child: Container(
                  width: Touch.min,
                  height: Touch.min,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceBrand,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Symbols.person,
                    size: Touch.icon,
                    color: AppColors.green700,
                  ),
                ),
              ),
              Gap.h8,
              InkWell(
                onTap: () {}, // TODO: 에코포인트 상점
                borderRadius: Radii.fullR,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.green50,
                    borderRadius: Radii.fullR,
                    border: Border.all(color: AppColors.green200),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: _comma(v.points),
                      style: AppType.label
                          .copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textBrand,
                          )
                          .tabular,
                      children: [
                        TextSpan(
                          text: ' P',
                          style: AppType.overline.copyWith(
                            color: AppColors.textBrand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 이번 주 기록 (화분 스트립 + 연속 기록) ─────────────────

class _WeekCard extends StatelessWidget {
  final HomeView v;
  const _WeekCard({required this.v});

  @override
  Widget build(BuildContext context) {
    final first = v.isFirstDay;

    return AppCard(
      tone: CardTone.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const AppOverline('이번 주 기록', color: AppColors.green800),
              const Spacer(),
              Text(
                first ? '오늘부터 시작' : '7일 중 ${v.weekDoneCount}일 완료',
                style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.green800,
                ),
              ),
            ],
          ),
          Gap.h16,
          Row(
            children: [
              for (final d in v.week) Expanded(child: _PotDay(log: d)),
            ],
          ),
          Gap.h12,
          const _PotLegend(),
          Gap.h16,
          const Divider(color: AppColors.green200),
          Gap.h16,
          Row(
            children: [
              // 줍댕이. TODO: 실제 에셋 경로로 교체
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: Radii.tileR,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/jupdaengi.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              Gap.w16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first ? '첫 화분에 물을 줄 시간이에요' : '${v.streakDays}일 연속 플로깅 중',
                      style: AppType.title3,
                    ),
                    Text(
                      first
                          ? '오늘 나가면 첫 화분이 자라요'
                          : '오늘 나가면 ${v.streakDays + 1}일째예요',
                      style: AppType.body.copyWith(color: AppColors.neutral700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PotDay extends StatelessWidget {
  final DayLog log;
  const _PotDay({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: log.isToday
          ? BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.actionPrimary, width: 2),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${log.date.day}',
            style: AppType.caption
                .copyWith(
                  fontSize: 14,
                  fontWeight: log.done || log.isToday
                      ? FontWeight.w700
                      : FontWeight.w600,
                  color: log.isToday
                      ? AppColors.actionPrimary
                      : log.done
                      ? AppColors.green800
                      : AppColors.textSecondary,
                )
                .tabular,
          ),
          const SizedBox(height: 6),
          // 채움(했음) vs 외곽선(안 함) — 색뿐 아니라 형태로도 구분
          Icon(
            Symbols.potted_plant,
            size: 30,
            fill: log.done ? 1 : 0,
            weight: log.done ? 500 : 400,
            color: log.done ? AppColors.actionPrimary : AppColors.neutral500,
          ),
        ],
      ),
    );
  }
}

class _PotLegend extends StatelessWidget {
  const _PotLegend();

  @override
  Widget build(BuildContext context) {
    final style = AppType.caption.copyWith(color: AppColors.green800);
    return Row(
      children: [
        const Icon(
          Symbols.potted_plant,
          size: 18,
          fill: 1,
          color: AppColors.actionPrimary,
        ),
        const SizedBox(width: 6),
        Text('플로깅한 날', style: style),
        Gap.w16,
        const Icon(
          Symbols.potted_plant,
          size: 18,
          fill: 0,
          color: AppColors.neutral500,
        ),
        const SizedBox(width: 6),
        Text('쉰 날', style: style),
      ],
    );
  }
}

// ── 내가 만든 변화 ────────────────────────────────────────

class _ImpactCard extends StatelessWidget {
  final HomeView v;
  const _ImpactCard({required this.v});

  @override
  Widget build(BuildContext context) {
    if (v.isFirstDay) return const _ImpactFirstDayCard();

    final trees = EcoMath.pineTrees(v.carbonKg);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: StatValue(
                    value: v.totalTrashKg.toStringAsFixed(1),
                    unit: 'kg',
                    label: '모은 쓰레기',
                  ),
                ),
                const VerticalDivider(
                  color: AppColors.neutral100,
                  width: Gap.lg,
                ),
                Expanded(
                  child: StatValue(
                    value: v.carbonKg.toStringAsFixed(1),
                    unit: 'kg',
                    label: '줄인 탄소',
                    brand: true,
                  ),
                ),
                const VerticalDivider(
                  color: AppColors.neutral100,
                  width: Gap.lg,
                ),
                Expanded(
                  child: StatValue(value: _comma(v.totalSteps), label: '걸음'),
                ),
              ],
            ),
          ),
          Gap.h16,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: Radii.tileR,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: '소나무 ',
                    children: [
                      TextSpan(
                        text: '${trees.toStringAsFixed(1)}그루',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '가 1년 동안\n빨아들이는 만큼의 탄소예요'),
                    ],
                  ),
                  style: AppType.body.copyWith(color: AppColors.green800),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () {}, // TODO: 계산 방법 안내 화면
                  child: Text(
                    '수거량으로 계산한 추정치예요  계산 방법',
                    style: AppType.caption.copyWith(
                      color: AppColors.neutral700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Gap.h16,
          const Divider(color: AppColors.neutral100),
          Gap.h16,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '레벨 ${v.level}',
                style: AppType.label.copyWith(color: AppColors.neutral700),
              ),
              const Spacer(),
              Text.rich(
                TextSpan(
                  text: '${v.xp}',
                  style: AppType.title3
                      .copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBrand,
                      )
                      .tabular,
                  children: [
                    TextSpan(
                      text: '/${v.xpMax}',
                      style: AppType.label.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h8,
          AppProgressBar(value: v.xp / v.xpMax),
          Gap.h8,
          Text(
            '다음 레벨까지 ${v.xpMax - v.xp} XP',
            style: AppType.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 활동 기록이 0건일 때. 0을 보여주는 대신 앞으로 생길 일을 보여준다.
class _ImpactFirstDayCard extends StatelessWidget {
  const _ImpactFirstDayCard();

  @override
  Widget build(BuildContext context) {
    final trash = EcoMath.avgTrashKgPer30min;
    final carbon = EcoMath.carbonKg(trash);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('30분만 걸어도', style: AppType.title3),
          Gap.h8,
          Text.rich(
            TextSpan(
              text: '평균 ',
              children: [
                TextSpan(
                  text: '${(trash * 1000).toStringAsFixed(0)}g',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBrand,
                  ),
                ),
                const TextSpan(text: '의 쓰레기를 줍고\n탄소 '),
                TextSpan(
                  text: '${(carbon * 1000).toStringAsFixed(0)}g',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBrand,
                  ),
                ),
                const TextSpan(text: '을 줄일 수 있어요'),
              ],
            ),
            style: AppType.body.copyWith(color: AppColors.textSecondary),
          ),
          Gap.h12,
          Text(
            '첫 활동을 마치면 내 기록으로 바뀝니다',
            style: AppType.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── 뉴스 ─────────────────────────────────────────────────

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {}, // TODO: 뉴스 상세
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: Radii.tileR,
            child: Container(
              width: 76,
              height: 76,
              color: AppColors.neutral100,
              child: item.thumbnailUrl == null
                  ? null
                  : Image.network(item.thumbnailUrl!, fit: BoxFit.cover),
            ),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppType.title3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  item.summary,
                  style: AppType.body.copyWith(
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.source} · ${item.timeAgo}',
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 동네 그룹 ─────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final NeighborGroup group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {}, // TODO: 그룹 상세로 이동
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: Radii.tileR,
            child: Container(
              width: 48,
              height: 48,
              color: AppColors.neutral100,
              child: group.imageUrl == null
                  ? null
                  : Image.network(group.imageUrl!, fit: BoxFit.cover),
            ),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: AppType.title3),
                Gap.h4,
                Text.rich(
                  TextSpan(
                    text: '멤버 ${group.memberCount}명 · ',
                    children: [
                      TextSpan(
                        text: '오늘 ${group.activeTodayCount}명 활동 중',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBrand,
                        ),
                      ),
                    ],
                  ),
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Gap.w8,
          // 목적지가 상세 화면이므로 문구는 '참여'가 아니라 '보러가기'
          Container(
            height: 36,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: Radii.fullR,
              border: Border.all(color: AppColors.green200),
            ),
            child: Text(
              '보러가기',
              style: AppType.label.copyWith(
                fontSize: 14,
                color: AppColors.textBrand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _comma(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);
