import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/core/widgets/app_section.dart';
import 'package:repo_jdh/core/widgets/app_card.dart';
import 'package:repo_jdh/core/widgets/trash_bag_icon.dart';
import 'package:repo_jdh/core/widgets/badge_medal.dart';
import 'package:repo_jdh/core/widgets/route_thumbnail.dart';
import 'package:repo_jdh/features/mypage/presentation/activity_detail_screen.dart';
import 'package:repo_jdh/features/mypage/presentation/activity_list_screen.dart';
import 'package:repo_jdh/features/mypage/presentation/quest_list_screen.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/mypage/presentation/badge_dialog.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';
import 'package:repo_jdh/features/plogging/domain/activity_stats.dart';
import 'package:repo_jdh/core/dev/dev_seed.dart'; // ⚠️ 개발용 — 배포 전 이 줄과 버튼 삭제

/// Ploggo - 내 활동 화면 (기록 / 뱃지 / 그래프 탭)
/// 하단 네비는 ShellRoute 가 담당. 본문만.
/// 위치 권장: lib/features/mypage/presentation/my_activity_screen.dart
class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  int _tab = 0; // 0:기록 1:뱃지 2:그래프
  int _graphPlay = 0; // 그래프 탭 진입 때마다 +1 → 애니메이션 재생 트리거
  int _badgeVersion = 0; // 획득 현황 로드되면 +1 → 뱃지 탭 갱신
  final PageController _pageController = PageController();

  // 그래프용 활동 기록 (집계 대상). null = 로딩 중
  List<Activity>? _graphActivities;

  @override
  void initState() {
    super.initState();
    _loadBadges();
    _loadGraphActivities();
  }

  // 그래프용 활동 기록 불러오기 (집계하려면 넉넉히)
  Future<void> _loadGraphActivities() async {
    try {
      final list = await ActivityService.getRecentCompleted(limit: 200);
      if (mounted) setState(() => _graphActivities = list);
    } catch (_) {
      if (mounted) setState(() => _graphActivities = []); // 실패 시 빈 목록
    }
  }

  // Firestore 획득 현황 → BadgeRepo 채우고 뱃지 탭 갱신
  Future<void> _loadBadges() async {
    try {
      await BadgeService.loadEarned();
    } catch (_) {
      return; // 실패 시 더미 유지
    }
    if (mounted) setState(() => _badgeVersion++);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            // 그래프 영역(주간/월간/누적)일 때만 기간 토글이 헤더 아래 고정으로 나타남.
            // 기간 스와이프 시 이 토글은 그대로 있고 아래 내용만 슬라이드된다.
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _tab >= 2
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
                      child: _periodToggleBar(),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                // 기록·뱃지·주간·월간·누적을 한 줄로 → 모든 탭이 공평하게 스와이프됨
                onPageChanged: (i) => setState(() {
                  _tab = i;
                  if (i >= 2) _graphPlay++; // 그래프 영역 진입 → 애니메이션 재생
                }),
                children: [
                  const _RecordsTab(),
                  _BadgesTab(key: ValueKey(_badgeVersion)),
                  _GraphTab(
                    period: 0,
                    playToken: _graphPlay,
                    activities: _graphActivities,
                  ),
                  _GraphTab(
                    period: 1,
                    playToken: _graphPlay,
                    activities: _graphActivities,
                  ),
                  _GraphTab(
                    period: 2,
                    playToken: _graphPlay,
                    activities: _graphActivities,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 그래프 기간 토글 (주간/월간/누적) — 그래프 영역에서만 헤더 아래 고정 표시.
  // 탭하면 해당 기간 페이지로 슬라이드(_goPeriod).
  // 목업: 알약이 아니라 오른쪽 정렬된 '점 + 라벨' 라디오.
  Widget _periodToggleBar() {
    const labels = ['주간', '월간', '누적'];
    final cur = _tab >= 2 ? _tab - 2 : 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _goPeriod(i),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cur == i
                        ? AppColors.actionPrimary
                        : AppColors.neutral300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: cur == i ? FontWeight.w800 : FontWeight.w600,
                    color: cur == i
                        ? AppColors.textBrandOnLight
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    // 초록 워시는 홈처럼 위→아래로 차오르고(HeaderWashPour), 제목은 떠오른다 (탭은 고정).
    return HeaderWashPour(
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 큰 제목 (내 활동 → 발자취 확인 문구) + 개발용 버튼
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: HeaderRise(
                  child: Text(
                    '지금까지의 발자취를\n확인해볼까요?',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      height: 1.28,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              // ⚠️ 개발용 임시 버튼 — 배포 전 _DevSeedButtons() 삭제
              const _DevSeedButtons(),
            ],
          ),
          const SizedBox(height: 16),
          // 3분할 세그먼트 — 둥근 네모 트랙 + 부드럽게 미끄러지는 흰 알약
          _SegmentedTabs(
            labels: const ['기록', '뱃지', '그래프'],
            selected: _tab >= 2 ? 2 : _tab,
            onSelect: _goTab,
          ),
        ],
      ),
      ),
    );
  }

  // 그래프 기간(주간/월간/누적) 토글 → 해당 페이지(2+p)로 슬라이드
  void _goPeriod(int p) {
    _pageController.animateToPage(
      2 + p,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  // 기록(0)/뱃지(1)/그래프(2) 로 부드럽게 이동
  void _goTab(int i) {
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }
}

/// 둥근 네모 트랙 위에서 흰 알약이 미끄러지는 세그먼트 컨트롤.
class _SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  const _SegmentedTabs({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const pad = 4.0;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.neutral200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final n = labels.length;
          final w = c.maxWidth / n;
          return Stack(
            alignment: Alignment.center,
            children: [
              // 미끄러지는 흰 알약
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: selected * w,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neutral900.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List.generate(n, (i) {
                  final on = selected == i;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                            color: on
                                ? AppColors.textPrimary
                                : AppColors.textOnTint,
                          ),
                          child: Text(labels[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ════════════════════════════ 기록 탭 ════════════════════════════
class _RecordsTab extends StatefulWidget {
  const _RecordsTab();

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  // 기록 탭에 보여줄 최근 활동 개수.
  // TODO: 팀 논의 후 조정 가능 (심는 개수(dev_seed)와는 별개)
  static const int _displayLimit = 3;

  // ── 실제 활동 기록 ──
  // null: 아직 로딩 중 / []: 로딩됐고 기록 0건 / [.. ]: 기록 있음
  List<_Activity>? _activities; // null = 로딩 중
  Object? _loadError; // null 이 아니면 에러 발생

  // 진행 중인 퀘스트 (달성률 높은 순 3개)
  List<_Quest> _quests = [];

  @override
  void initState() {
    super.initState();
    _loadActivities(); // 실제 활동 기록 불러오기
    _loadQuests();
  }

  // 활동 기록 불러오기 (서버 Activity → 화면 _Activity 로 변환)
  Future<void> _loadActivities() async {
    try {
      final list = await ActivityService.getRecentCompleted(
        limit: _displayLimit,
      );
      // 서버 데이터(Activity)를 화면용(_Activity)으로 변환
      final mapped = list.map(_toDisplay).toList();
      if (!mounted) return;
      setState(() {
        _activities = mapped;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e; // 에러 화면에서 사용
      });
    }
  }

  // 서버 Activity → 화면 _Activity 변환
  // (걸음·칼로리·무게는 ActivityMetrics 로 계산, 장소명은 아직 없어 임시 표시)
  _Activity _toDisplay(Activity a) {
    return _Activity(
      a.id,
      ActivityMetrics.dateTimeLabel(a.startedAt),
      ActivityMetrics.placeLabel(placeName: a.placeName, groupId: a.groupId),
      ActivityMetrics.estimateSteps(a.distanceMeters),
      ActivityMetrics.weightLabel(a.trashCounts),
      ActivityMetrics.estimateKcal(a.distanceMeters),
      ActivityMetrics.durationLabel(a.durationSeconds),
      a.trashCounts, // 상세 화면에서 활동별 수거 개수를 그대로 쓴다
      a.imageUrls, // 인증샷도 원본 그대로 (없으면 빈 목록)
      a.path, // 경로 썸네일용 원본 좌표
    );
  }

  Future<void> _loadQuests() async {
    UserStats stats = const UserStats();
    try {
      stats = await BadgeService.loadStats();
    } catch (_) {
      // 실패 시 빈 목록
    }
    if (!mounted) return;
    final list = <_Quest>[];
    for (final b in kBadges) {
      final (cur, total) = BadgeService.progressOf(b, stats);
      if (cur >= total) continue; // 완료된 건 제외
      // 퀘스트 아이콘 = 연계된 뱃지 아이콘. 쓰레기봉투는 '한 봉지의 시작' 하나만.
      final collect = usesTrashBagIcon(b);
      list.add(
        _Quest(b.quest, cur, total, b.icon, _questColor(b), b.points, collect),
      );
    }
    list.sort((a, b) => (b.current / b.total).compareTo(a.current / a.total));
    setState(() => _quests = list.take(3).toList());
  }

  // 5색: 걸음·거리(파랑)/수거(초록)/그룹(주황)/시간(노랑)/칼로리(빨강)
  // 전체 퀘스트 화면의 _colorOf 와 동일하게 맞춘다.
  Color _questColor(BadgeData b) {
    final id = b.id;
    if (id.startsWith('steps') ||
        id.startsWith('distance') ||
        id == 'first_plogging') {
      return AppColors.dataSteps;
    }
    if (id.startsWith('kcal')) return AppColors.dataCalorie;
    if (id.startsWith('weight') ||
        id.startsWith('plastic') ||
        id == 'first_verify') {
      return AppColors.green600;
    }
    if (id.startsWith('group') || id.startsWith('share')) {
      return AppColors.dataGroup;
    }
    return AppColors.dataTime;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
      ),
      children: [
        _sectionHeader(
          '최근 활동',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActivityListScreen()),
          ),
        ),
        const SizedBox(height: 12),
        // ── 4가지 상태 처리: 로딩 / 에러 / 빈 기록 / 데이터 ──
        ..._buildRecordsSection(context),
        const SizedBox(height: 22),
        _sectionHeader(
          '진행 중인 챌린지',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QuestListScreen()),
          ),
        ),
        const SizedBox(height: 12),
        ..._quests.map(
          (q) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _questCard(q),
          ),
        ),
      ],
    );
  }

  // 최근 활동 섹션: 상태에 따라 다른 위젯 목록을 반환
  List<Widget> _buildRecordsSection(BuildContext context) {
    // ① 에러
    if (_loadError != null) {
      return [
        _ErrorBox(
          onRetry: () {
            setState(() {
              _loadError = null;
              _activities = null; // 다시 로딩 상태로
            });
            _loadActivities();
          },
        ),
      ];
    }
    // ② 로딩 중 (아직 null)
    if (_activities == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    // ③ 로딩 완료 & 기록 0건 → 빈 화면
    if (_activities!.isEmpty) {
      return const [_EmptyRecords()];
    }
    // ④ 데이터 있음
    return _activities!
        .map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _activityCard(context, a),
          ),
        )
        .toList();
  }

  Widget _sectionHeader(String text, {required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Icon(TablerIcons.chevronRight, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _activityCard(BuildContext context, _Activity a) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivityDetailScreen(
            dateTime: a.dateTime,
            title: a.title,
            steps: a.steps,
            weight: a.weight,
            kcal: a.kcal,
            time: a.time,
            trashCounts: a.trashCounts,
            imageUrls: a.imageUrls,
            activityId: a.id,
            path: a.path,
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
            // 경로 미니 지도 썸네일
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 84,
                height: 84,
                child: CustomPaint(painter: RoutePainter(path: a.path)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.dateTime,
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
                  // 걸음 · 분 · kg · kcal (아이콘 없이 텍스트)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_comma(a.steps)}걸음 · ${a.time} · ${a.weight} · ${a.kcal}kcal',
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

  // 천 단위 콤마
  static String _comma(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  Widget _questCard(_Quest q) {
    final progress = (q.current / q.total).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: q.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: q.isCollect
                    ? TrashBagIcon(size: 24, color: q.color)
                    : Icon(q.icon, color: q.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      q.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_comma(q.current)} / ${_comma(q.total)} · 달성 시 ${q.points}P',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: q.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AppColors.neutral200, // 진행 배경 회색 통일
              color: q.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════ 뱃지 탭 ════════════════════════════
class _BadgesTab extends StatefulWidget {
  const _BadgesTab({super.key});

  @override
  State<_BadgesTab> createState() => _BadgesTabState();
}

class _BadgesTabState extends State<_BadgesTab> {
  int _filter = 0; // 0 전체 / 1 걸음·거리 / 2 수거 / 3 그룹 / 4 시간 / 5 칼로리
  UserStats? _stats; // 미획득 뱃지 달성률 링 계산용
  // 진행률 카드 문구를 5개 중 하나로 (탭 진입 시 한 번 뽑음)
  final int _phraseIndex = Random().nextInt(5);

  static const List<String> _filters = [
    '전체',
    '걸음·거리',
    '수거',
    '그룹',
    '시간',
    '칼로리',
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final s = await BadgeService.loadStats();
      if (mounted) setState(() => _stats = s);
    } catch (_) {
      if (mounted) setState(() => _stats = const UserStats());
    }
  }

  bool _inFilter(BadgeData b) {
    if (_filter == 0) return true;
    final id = b.id;
    switch (_filter) {
      case 1:
        return id.startsWith('steps') ||
            id.startsWith('distance') ||
            id == 'first_plogging';
      case 2:
        return id.startsWith('weight') ||
            id.startsWith('plastic') ||
            id == 'first_verify';
      case 3:
        return id.startsWith('group') || id.startsWith('share');
      case 4:
        return id.startsWith('time') || id == 'first_30min';
      case 5:
        return id.startsWith('kcal');
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final earnedCount = kBadges.where((b) => BadgeRepo.isEarned(b.id)).length;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        Gap.screenPad,
        Gap.xl,
        Gap.screenPad,
        MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
      ),
      children: [
        _ProgressCard(
          earned: earnedCount,
          total: kBadges.length,
          phraseIndex: _phraseIndex,
        ),
        const SizedBox(height: Gap.xl2),
        // 카테고리 필터 알약
        _filterPills(),
        const SizedBox(height: Gap.xl),
        // 등급 구분 없이 필터된 뱃지를 한 그리드에 (획득한 것 앞으로).
        _badgeGrid(),
      ],
    );
  }

  // 필터된 뱃지 평면 그리드 (등급 헤더 없음)
  Widget _badgeGrid() {
    final list = kBadges.where(_inFilter).toList()
      ..sort((a, b) {
        final ae = BadgeRepo.isEarned(a.id) ? 0 : 1;
        final be = BadgeRepo.isEarned(b.id) ? 0 : 1;
        return ae.compareTo(be);
      });
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(
          child: Text(
            '해당하는 뱃지가 없어요',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Gap.sm,
      crossAxisSpacing: Gap.md,
      childAspectRatio: 0.78, // 메달 꼬리가 들어와 칸이 조금 높아졌다
      children: [
        for (final b in list) _BadgeTile(badge: b, stats: _stats),
      ],
    );
  }

  Widget _filterPills() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final on = _filter == i;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _filter = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: on ? AppColors.actionPrimary : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: on ? AppColors.actionPrimary : AppColors.border,
                ),
              ),
              child: Text(
                _filters[i],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: on ? AppColors.textOnBrand : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 전체 진행률 — 뱃지 탭 최상단 도넛 카드.
class _ProgressCard extends StatelessWidget {
  final int earned;
  final int total;
  final int phraseIndex;
  const _ProgressCard({
    required this.earned,
    required this.total,
    required this.phraseIndex,
  });

  // 진행률 안내 문구 5종 ({earned}·{remain}·{total} 치환)
  static const List<String> _phrases = [
    '다음 뱃지까지 조금만 더! 전체 {total}개 중 {remain}개가 남았어요.',
    '벌써 {earned}개나 모았어요. {remain}개만 더 채워볼까요?',
    '{remain}개를 더 모으면 전부 완성이에요.',
    '{total}개 중 {earned}개 획득! 다음 뱃지가 기다려요.',
    '한 걸음씩 {earned}개. 남은 {remain}개도 곧이에요.',
  ];

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : earned / total;
    final remain = total - earned;
    final subtitle = remain <= 0
        ? '축하해요! 모든 뱃지를 다 모았어요.'
        : _phrases[phraseIndex % _phrases.length]
              .replaceAll('{earned}', '$earned')
              .replaceAll('{remain}', '$remain')
              .replaceAll('{total}', '$total');

    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 66,
            height: 66,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 66,
                  height: 66,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 8,
                    backgroundColor: AppColors.neutral200,
                    color: AppColors.actionPrimary,
                  ),
                ),
                // 숫자 사이 여백 최소화 (13 / 20 바짝)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$earned',
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '/$total',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('뱃지 $earned개 획득', style: AppType.title3),
                Gap.h4,
                Text(
                  subtitle,
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
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

class _BadgeTile extends StatelessWidget {
  final BadgeData badge;
  final UserStats? stats;
  const _BadgeTile({required this.badge, required this.stats});

  @override
  Widget build(BuildContext context) {
    final earned = BadgeRepo.isEarned(badge.id);
    final color = badgeColor(badge);
    final collect = usesTrashBagIcon(badge);
    final (cur, tot) = BadgeService.progressOf(badge, stats ?? const UserStats());
    final progress = tot == 0 ? 0.0 : (cur / tot).clamp(0.0, 1.0);

    // 수거 계열은 쓰레기봉투 아이콘으로 통일
    Widget iconOf(Color c, double size) => collect
        ? TrashBagIcon(size: size, color: c)
        : Icon(badge.icon, color: c, size: size);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showBadgeDetail(context, badge, current: cur, total: tot),
      // 아이콘 + 이름 + 설명 전체를 하얀 라운드 카드로 감싼다.
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 메달 뱃지 — 획득: 카테고리 색 코인 + 꼬리 / 미획득: 달성률 링
            BadgeMedal(
              size: 44,
              color: color,
              earned: earned,
              progress: progress,
              // 파스텔 코인 위에서 보이도록 획득 아이콘은 카테고리 색
              icon: iconOf(earned ? color : AppColors.neutral400, 22),
            ),
            const SizedBox(height: 8),
            Text(
              badge.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: earned ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              earned ? badge.condition : '${badge.points}P',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════ 그래프 탭 ════════════════════════════
class _GraphTab extends StatefulWidget {
  final int period; // 이 페이지가 담당하는 기간 (0:주간 1:월간 2:누적)
  final int playToken; // 값이 바뀌면 애니메이션 재생
  final List<Activity>? activities; // 집계 대상 (null = 로딩 중)
  const _GraphTab({
    required this.period,
    required this.playToken,
    required this.activities,
  });

  @override
  State<_GraphTab> createState() => _GraphTabState();
}

class _GraphTabState extends State<_GraphTab> with TickerProviderStateMixin {
  late final AnimationController _ac; // 꺾은선(월간)용 900ms
  late final AnimationController _acFast; // 막대·도넛용 800ms

  int _offset = 0; // 이 기간 안에서 보고 있는 주/월 인덱스 (0=가장 최근)

  static const List<String> _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  // ── 실제 집계 결과 (widget.activities 로부터 계산) ──
  // 매 build 마다 다시 계산하지 않도록 캐시. activities 가 바뀌면 갱신.
  List<_GData> _weekly = const [];
  List<_GData> _monthly = const [];
  _GData _cumulative = const _GData('전체', '', '0', '0', '0g', [], [], 0);

  // 도넛 색·한글 라벨 매핑 — 정산/기록 상세의 쓰레기 카테고리 색과 동일하게.
  static const Map<String, (String, Color)> _catMeta = {
    'plastic': ('플라스틱', Color(0xFF5F9EE8)), // 밝은 파랑
    'can': ('캔', Color(0xFFE07B2E)), // 밝은 주황
    'paper': ('종이', Color(0xFF31C88B)), // 밝은 초록
    'glass': ('유리', Color(0xFF8E7EC4)), // 보라
    'trash': ('일반', Color(0xFF9AA3A0)), // 회색
  };

  // 집계 실행 — activities 로 _weekly/_monthly/_cumulative 채움
  // (도넛 _segments 는 '지금 보는 기간' 기준이라 _segmentsFor 에서 따로 계산)
  void _recompute() {
    final acts = widget.activities ?? const [];

    _weekly = ActivityStats.weekly(acts).map((b) => _bucketToGData(b)).toList();
    _monthly = ActivityStats.monthly(
      acts,
    ).map((b) => _bucketToGData(b)).toList();
    _cumulative = _bucketToGData(ActivityStats.cumulative(acts));
  }

  // 지금 보고 있는 기간의 활동만 골라 도넛 세그먼트 생성
  List<_Segment> _segmentsFor(int period) {
    final acts = widget.activities ?? const [];
    // 기간에 맞는 활동만 필터 (누적은 전체)
    final List<Activity> scoped;
    if (period == 0) {
      scoped = ActivityStats.inWeek(acts, _offset); // 주간: 보고 있는 주
    } else if (period == 1) {
      scoped = ActivityStats.inMonth(acts, _offset); // 월간: 보고 있는 달
    } else {
      scoped = acts; // 누적: 전체
    }

    final cats = ActivityStats.categoryTotals(scoped)
      ..sort((a, b) => b.count.compareTo(a.count));
    return cats.map((c) {
      final meta = _catMeta[c.category] ?? (c.category, AppColors.textSecondary);
      return _Segment(meta.$1, c.count, meta.$2);
    }).toList();
  }

  // 집계 결과(GraphBucket) → 화면 데이터(_GData) 변환
  _GData _bucketToGData(GraphBucket b) {
    return _GData(
      b.title,
      b.range,
      ActivityStats.comma(b.steps),
      ActivityStats.comma(b.kcal),
      ActivityStats.weightLabel(b.weightG),
      b.bars,
      b.barLabels,
      b.peakIndex,
    );
  }

  // 이 페이지 기간의 데이터셋 목록 (누적은 단일)
  List<_GData> get _currentList => widget.period == 0 ? _weekly : _monthly;

  // 이 페이지 기간의 데이터 (오프셋만큼 과거로)
  _GData _dataFor(int period) {
    if (period == 2) return _cumulative;
    final list = period == 0 ? _weekly : _monthly;
    if (list.isEmpty) {
      // 데이터 없을 때 빈 그래프
      return _GData(
        period == 0 ? '이번주' : '이번달',
        '기록 없음',
        '0',
        '0',
        '0g',
        List<double>.filled(period == 0 ? 7 : 5, 0.0),
        period == 0 ? _dayLabels : const ['1주', '2주', '3주', '4주', '5주'],
        0,
      );
    }
    return list[_offset.clamp(0, list.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400), // 꺾은선: 왼→오
    )..forward();
    _acFast = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250), // 막대·도넛
    )..forward();
    _recompute(); // 초기 집계
  }

  @override
  void didUpdateWidget(covariant _GraphTab old) {
    super.didUpdateWidget(old);
    // 부모가 활동 데이터를 (늦게) 전달/갱신하면 다시 집계
    if (old.activities != widget.activities) {
      _recompute();
    }
    // 그래프 탭 재진입 → 처음부터 다시 재생
    if (old.playToken != widget.playToken) {
      _replay();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    _acFast.dispose();
    super.dispose();
  }

  void _replay() {
    _ac.forward(from: 0);
    _acFast.forward(from: 0);
  }

  // 화살표: older = 과거로(오프셋+1), newer = 최근으로(오프셋-1)
  void _shift(int delta) {
    if (widget.period == 2) return; // 누적은 이동 없음
    final max = _currentList.length - 1;
    setState(() => _offset = (_offset + delta).clamp(0, max));
    _replay();
  }

  @override
  Widget build(BuildContext context) {
    // 기간 토글은 부모(_MyActivityScreenState)가 헤더 아래 고정으로 그린다.
    // 이 페이지는 내용만 → 기간 스와이프 시 내용만 슬라이드된다.
    return _periodBody(widget.period);
  }

  // 이 페이지의 기간 내용 (주간/월간/누적)
  Widget _periodBody(int period) {
    final d = _dataFor(period);
    final isCumulative = period == 2;
    final off = _offset;
    final listLen = period == 0
        ? _weekly.length
        : (period == 1 ? _monthly.length : 1);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  d.range,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            // 누적은 기간 이동 없음
            if (!isCumulative)
              Row(
                children: [
                  _arrow(
                    TablerIcons.chevronLeft,
                    off < listLen - 1,
                    () => _shift(1),
                  ),
                  const SizedBox(width: 16),
                  _arrow(TablerIcons.chevronRight, off > 0, () => _shift(-1)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _summaryStat('걸음수', d.steps, AppColors.dataSteps, 'track_thick.svg'),
            _summaryStat('칼로리', d.kcal, AppColors.dataCalorie, 'fire_thick.svg'),
            _summaryStat('수거량', d.weight, AppColors.dataCollect,
                'garbage_thick.svg'),
          ],
        ),
        const SizedBox(height: 22),
        // 주간: 요일별 막대 / 월간: 주별 꺾은선 / 누적: 그래프 없음
        if (period == 0) ...[
          _chartCard(
            '요일별 활동',
            SizedBox(
              height: 145, // 왕관 얹을 여유 포함(원래 130)
              child: AnimatedBuilder(
                animation: _acFast,
                builder: (_, __) =>
                    _barChart(d.bars, d.barLabels, d.peakIndex, _acFast.value),
              ),
            ),
            note: '활동 시간을 산출하여 나타낸 결과예요',
          ),
          const SizedBox(height: 16),
        ],
        if (period == 1) ...[
          _chartCard(
            '주별 활동',
            AnimatedBuilder(
              animation: _ac,
              builder: (_, __) =>
                  _lineChart(d.bars, d.barLabels, d.peakIndex, _ac.value),
            ),
            note: '활동 시간을 산출하여 나타낸 결과예요',
          ),
          const SizedBox(height: 16),
        ],
        // 누적은 그래프가 없어 요약과 도넛이 붙으니 공백 추가
        if (isCumulative) const SizedBox(height: 12),
        _chartCard(
          '수거 종류',
          AnimatedBuilder(
            animation: _acFast,
            builder: (_, __) => _trashDonut(_acFast.value, period),
          ),
        ),
      ],
    );
  }

  Widget _arrow(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Icon(
        icon,
        color: enabled ? AppColors.textSecondary : AppColors.border,
      ),
    );
  }

  // 상단 요약(걸음수·칼로리·수거량).
  // 배경 픽토그램 + 라벨 + 숫자를 '한 덩어리'로 묶고, 그 덩어리를 셀 안에서
  // 가운데보다 살짝 왼쪽에 둔다 (아이콘이 오른쪽에 붙어 있어 시각 중심을 보정).
  // 라벨 크기는 고정, 숫자만 길어지면 축소된다.
  // 라벨 위 / 숫자 아래, 그 오른쪽 끝에 픽토그램이 살짝 겹쳐 시작한다.
  // 숫자는 최대폭 안에서만 커지고 길어지면 축소 → 오버플로우 없음.
  Widget _summaryStat(
    String label,
    String value,
    Color color,
    String asset, {
    double iconDy = 0, // 픽토그램 세로 미세조정
  }) {
    return Expanded(
      child: SizedBox(
        height: 64,
        child: Align(
          alignment: const Alignment(-0.16, 0), // 가운데→살짝 왼쪽
          // 덩어리 전체를 오른쪽으로 1px 이동 + 셀에 맞춰 축소(오버플로우 방지)
          child: Transform.translate(
            offset: const Offset(1, 0), // ← 오른쪽 1px (숫자만 바꾸면 됨)
            child: FittedBox(
              fit: BoxFit.scaleDown,
              // 고정 폭 박스: 픽토그램은 오른쪽 끝에 못 박고, 숫자는 왼쪽에서
              // (숫자가 길어져도 픽토그램은 안 움직이고 그 위로 겹친다)
              child: SizedBox(
                width: 96,
                height: 54,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 배경 픽토그램 — 오른쪽 끝 고정 (숫자 길이와 무관)
                    Positioned(
                      right: 0,
                      top: 2 + iconDy,
                      child: SvgPicture.asset(
                        'assets/icons/$asset',
                        width: 50,
                        height: 50,
                        colorFilter: ColorFilter.mode(
                          AppColors.textSecondary.withValues(alpha: 0.20),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    // 라벨 + 숫자 (왼쪽 고정, 픽토그램과 겹쳐도 OK)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 라벨은 항상 그대로
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 0), // 라벨-숫자 여백 최소화
                          // 숫자: base 크기 고정(짧아도 안 커짐), 길면 축소
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 90),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                value,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
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
      ),
    );
  }

  Widget _chartCard(String title, Widget child, {String? note}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 + ⓘ + 산출 기준 설명 (한 줄)
          if (note == null)
            Text(title, style: AppType.title3)
          else
            Row(
              children: [
                Text(title, style: AppType.title3),
                const SizedBox(width: 6),
                const Icon(TablerIcons.infoCircle, size: 15,
                    color: AppColors.neutral400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: Gap.lg),
          child,
        ],
      ),
    );
  }

  Widget _barChart(
    List<double> bars,
    List<String> labels,
    int peakIndex,
    double t,
  ) {
    // 데이터가 하나도 없으면 왕관을 씌우지 않는다.
    final hasData = bars.any((b) => b > 0.001);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(bars.length, (i) {
        final peak = hasData && i == peakIndex;
        final v = bars[i];
        // 활동이 거의 없는 날은 전부 동일한 회색 찔끔으로 통일
        // (아주 짧은 막대가 회색 스텁보다 더 작게 보이는 것 방지)
        final empty = v < 0.08;
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 최다 활동 막대 위에 2D 왕관 (데이터 있을 때만)
              if (peak) ...[
                CustomPaint(
                  size: const Size(18, 13),
                  painter: _CrownPainter(const Color(0xFFFFEA76)),
                ),
                const SizedBox(height: 3),
              ],
              // 활동 없는 날은 회색으로 찔끔 (주간 한정 — 비어 보이지 않게)
              empty
                  ? Container(
                      width: 16,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.neutral300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )
                  : Container(
                      width: 16,
                      height: 90 * v * t,
                      decoration: BoxDecoration(
                        color: peak ? _kBarPeak : _kBarColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
              const SizedBox(height: 8),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: peak ? FontWeight.w700 : FontWeight.w500,
                  // 최다 활동 날 글씨는 진한 파랑
                  color: peak ? _kBarPeak : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _lineChart(
    List<double> values,
    List<String> labels,
    int peakIndex,
    double t,
  ) {
    final hasData = values.any((v) => v > 0.001);
    return Column(
      children: [
        SizedBox(
          height: 128, // 왕관 얹을 여유 포함(원래 110)
          width: double.infinity,
          child: CustomPaint(
            painter: _LinePainter(values, peakIndex, t, hasData),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(labels.length, (i) {
            final peak = hasData && i == peakIndex;
            return Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: peak ? FontWeight.w700 : FontWeight.w500,
                  // 최다 활동 주 글씨는 진한 파랑
                  color: peak ? _kBarPeak : AppColors.textSecondary,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _trashDonut(double t, int period) {
    final segments = _segmentsFor(period); // 지금 보는 기간의 수거 종류
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(120, 120),
                painter: _DonutPainter(segments, t),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${segments.fold<int>(0, (a, s) => a + s.value)}개',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(children: segments.map(_legendRow).toList())),
      ],
    );
  }

  Widget _legendRow(_Segment s) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: s.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${s.value}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// 도넛 차트 페인터
class _DonutPainter extends CustomPainter {
  final List<_Segment> segments;
  final double progress; // 0~1, 시계방향 채움 진행도
  final double strokeWidth;
  const _DonutPainter(this.segments, this.progress) : strokeWidth = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (size.shortestSide - strokeWidth) / 2,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.border;

    // 배경 트랙 (항상)
    canvas.drawArc(rect, 0, 2 * pi, false, track);
    if (total <= 0) return;

    final drawn = 2 * pi * progress.clamp(0.0, 1.0); // 그릴 총 각도
    double acc = 0; // 12시부터 누적된 각도
    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweep = (seg.value / total) * 2 * pi;
      if (acc < drawn) {
        final drawEnd = (acc + sweep) < drawn ? (acc + sweep) : drawn;
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt
          ..color = seg.color;
        canvas.drawArc(rect, -pi / 2 + acc, drawEnd - acc, false, p);
      }
      acc += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.segments != segments || old.progress != progress;
}

// ──────────────── 데이터 모델 ────────────────

// ⚠️ 개발용 임시 버튼 — 배포 전 삭제
// 가짜 활동 심기 / 지우기. 결과는 스낵바로 알림.
class _DevSeedButtons extends StatefulWidget {
  const _DevSeedButtons();

  @override
  State<_DevSeedButtons> createState() => _DevSeedButtonsState();
}

class _DevSeedButtonsState extends State<_DevSeedButtons> {
  bool _busy = false; // 중복 탭 방지

  Future<void> _run(Future<int> Function() action, String verb) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final n = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$verb $n건 완료 — 앱을 다시 열면 반영돼요')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '가짜 데이터 심기',
          icon: const Icon(TablerIcons.circlePlus, size: 22),
          color: AppColors.textSecondary,
          onPressed: () => _run(() => DevSeed.seedActivities(), '심기'),
        ),
        IconButton(
          tooltip: '가짜 데이터 지우기',
          icon: const Icon(TablerIcons.trash, size: 22),
          color: AppColors.textSecondary,
          onPressed: () => _run(() => DevSeed.clearActivities(), '삭제'),
        ),
        // 뱃지 판정 실행 — 조건 충족한 뱃지를 저장하고 포인트를 적립한다.
        // (원래는 플로깅 정산 화면에서 자동 호출됨)
        IconButton(
          tooltip: '뱃지 판정 실행',
          icon: const Icon(TablerIcons.medal, size: 22),
          color: AppColors.textSecondary,
          onPressed: () => _run(() async {
            final fresh = await BadgeService.checkAndSave();
            return fresh.length; // 새로 딴 뱃지 개수
          }, '뱃지 획득'),
        ),
      ],
    );
  }
}

// 기록이 0건일 때 보여주는 빈 화면
class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: const [
          Icon(TablerIcons.walk, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text(
            '아직 플로깅 기록이 없어요',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '첫 플로깅을 시작해볼까요?',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// 불러오기 실패 시 보여주는 에러 박스 (재시도 버튼 포함)
class _ErrorBox extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBox({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(TablerIcons.cloudOff, size: 44, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text(
            '기록을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _Activity {
  final String id;
  final String dateTime;
  final String title;
  final int steps;
  final String weight;
  final int kcal;
  final String time;

  /// 활동별 수거 개수 (서버 Activity.trashCounts 원본).
  /// 무게로 환산만 하고 버리면 상세 화면이 활동을 구분하지 못한다.
  final Map<String, int> trashCounts;

  /// 인증샷 URL (서버 Activity.imageUrls 원본). 상세 화면이 실제 사진을 그린다.
  final List<String> imageUrls;

  /// GPS 경로 ([{lat, lng, t}, ...]). 없으면 썸네일에 '경로 없음' 표시.
  final List<Map<String, dynamic>> path;

  const _Activity(
    this.id,
    this.dateTime,
    this.title,
    this.steps,
    this.weight,
    this.kcal,
    this.time,
    this.trashCounts,
    this.imageUrls,
    this.path,
  );
}

class _Quest {
  final String title;
  final int current;
  final int total;
  final IconData icon;
  final Color color;
  final int points; // 달성 시 지급 포인트
  final bool isCollect; // 수거량 계열 → 쓰레기봉투 아이콘
  const _Quest(
    this.title,
    this.current,
    this.total,
    this.icon,
    this.color,
    this.points,
    this.isCollect,
  );
}

// 월간 주별 활동 꺾은선 차트
// 활동 막대·꺾은선 색 — 보라(인디고) 계열. 최다 활동(peak)은 더 진하게.
const Color _kBarColor = Color(0xFF6E77D0);
const Color _kBarPeak = Color(0xFF4C58AE);

class _LinePainter extends CustomPainter {
  final List<double> values; // 0~1 비율
  final int peakIndex;
  final double progress; // 0~1, 선 그려짐 진행도
  final bool hasData; // 데이터 없으면 왕관 생략
  _LinePainter(this.values, this.peakIndex, this.progress, this.hasData);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final n = values.length;
    const padTop = 26.0; // 최고점 위 왕관 자리
    const padBottom = 6.0;
    final chartH = size.height - padTop - padBottom;
    double xOf(int i) => ((i + 0.5) / n) * size.width;
    double yOf(double v) => padTop + (1 - v) * chartH;

    final line = Path();
    for (int i = 0; i < n; i++) {
      final x = xOf(i);
      final y = yOf(values[i]);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    // 선 아래 영역 (진행도에 따라 서서히 진하게)
    final area = Path.from(line)
      ..lineTo(xOf(n - 1), size.height)
      ..lineTo(xOf(0), size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..color = _kBarColor.withValues(alpha: 0.12 * progress)
        ..style = PaintingStyle.fill,
    );

    // 선 (progress 만큼만 그림 = 왼→오로 그려짐)
    final linePaint = Paint()
      ..color = _kBarColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (final m in line.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * progress), linePaint);
    }

    // 점 (선이 도달한 지점까지 순차 등장)
    for (int i = 0; i < n; i++) {
      final frac = n == 1 ? 0.0 : i / (n - 1);
      if (frac > progress) break;
      final c = Offset(xOf(i), yOf(values[i]));
      final peak = i == peakIndex;
      canvas.drawCircle(
        c,
        peak ? 5.5 : 4,
        Paint()..color = peak ? _kBarPeak : _kBarColor,
      );
      canvas.drawCircle(
        c,
        peak ? 5.5 : 4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // 최고 지점 위에 왕관 (데이터 있을 때만)
    final peakFrac = n == 1 ? 0.0 : peakIndex / (n - 1);
    if (hasData && peakIndex >= 0 && peakIndex < n && peakFrac <= progress) {
      _drawCrown(
        canvas,
        Offset(xOf(peakIndex), yOf(values[peakIndex])),
        const Color(0xFFFFEA76),
      );
    }
  }

  // 주어진 지점 위에 2D 왕관 (_CrownPainter와 동일 모양)
  void _drawCrown(Canvas canvas, Offset point, Color color) {
    const cw = 18.0;
    const ch = 13.0;
    final left = point.dx - cw / 2;
    final top = point.dy - 5.5 - 4 - ch; // 점 반지름+간격 위
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round;
    final body = Path()
      ..moveTo(left, top + ch)
      ..lineTo(left, top + ch * 0.35)
      ..lineTo(left + cw * 0.28, top + ch * 0.62)
      ..lineTo(left + cw * 0.5, top + ch * 0.06)
      ..lineTo(left + cw * 0.72, top + ch * 0.62)
      ..lineTo(left + cw, top + ch * 0.35)
      ..lineTo(left + cw, top + ch)
      ..close();
    canvas.drawPath(body, paint);
    final r = ch * 0.12;
    canvas.drawCircle(Offset(left + cw * 0.05, top + ch * 0.32), r, paint);
    canvas.drawCircle(Offset(left + cw * 0.5, top + ch * 0.10), r, paint);
    canvas.drawCircle(Offset(left + cw * 0.95, top + ch * 0.32), r, paint);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values ||
      old.peakIndex != peakIndex ||
      old.progress != progress ||
      old.hasData != hasData;
}

// 2D 심플 왕관 (3봉우리 납작한 도형 — 그래프 톤에 맞춘 단색)
class _CrownPainter extends CustomPainter {
  final Color color;
  _CrownPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round;

    final body = Path()
      ..moveTo(0, h) // 왼쪽 아래
      ..lineTo(0, h * 0.35) // 왼쪽 뿔
      ..lineTo(w * 0.28, h * 0.62) // 골
      ..lineTo(w * 0.5, h * 0.06) // 가운데 뿔(제일 높음)
      ..lineTo(w * 0.72, h * 0.62) // 골
      ..lineTo(w, h * 0.35) // 오른쪽 뿔
      ..lineTo(w, h) // 오른쪽 아래
      ..close(); // 아래 밑변
    canvas.drawPath(body, paint);

    // 뿔 끝 동그란 보석(귀엽게)
    final r = h * 0.12;
    canvas.drawCircle(Offset(w * 0.05, h * 0.32), r, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.10), r, paint);
    canvas.drawCircle(Offset(w * 0.95, h * 0.32), r, paint);
  }

  @override
  bool shouldRepaint(covariant _CrownPainter old) => old.color != color;
}

class _Segment {
  final String label;
  final int value;
  final Color color;
  const _Segment(this.label, this.value, this.color);
}

// 그래프 기간별 데이터셋 (주간/월간/누적)
class _GData {
  final String title; // 이번주 / 이번달 / 전체
  final String range; // 5.24 ~ 5.31 / 2026.05 / 가입일부터
  final String steps;
  final String kcal;
  final String weight;
  final List<double> bars; // 0~1 비율 (누적은 빈 리스트)
  final List<String> barLabels;
  final int peakIndex;
  const _GData(
    this.title,
    this.range,
    this.steps,
    this.kcal,
    this.weight,
    this.bars,
    this.barLabels,
    this.peakIndex,
  );
}
