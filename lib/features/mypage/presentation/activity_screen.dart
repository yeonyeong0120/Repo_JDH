import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/mypage/presentation/activity_detail_screen.dart';
import 'package:repo_jdh/features/mypage/presentation/activity_list_screen.dart';
import 'package:repo_jdh/features/mypage/presentation/quest_list_screen.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/mypage/presentation/badge_dialog.dart';
import 'package:repo_jdh/features/mypage/presentation/character_screen.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';

/// 줍다행 - 내 활동 화면 (기록 / 뱃지 / 그래프 탭)
/// 하단 네비는 ShellRoute 가 담당. 본문만.
/// 위치 권장: lib/features/mypage/presentation/activity_screen.dart
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _tab = 0; // 0:기록 1:뱃지 2:그래프
  int _graphPlay = 0; // 그래프 탭 진입 때마다 +1 → 애니메이션 재생 트리거
  int _badgeVersion = 0; // 획득 현황 로드되면 +1 → 뱃지 탭 갱신
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadBadges();
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
      backgroundColor: AppColors.appBG,
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
                  _GraphTab(period: 0, playToken: _graphPlay),
                  _GraphTab(period: 1, playToken: _graphPlay),
                  _GraphTab(period: 2, playToken: _graphPlay),
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
  Widget _periodToggleBar() {
    const labels = ['주간', '월간', '누적'];
    final cur = _tab >= 2 ? _tab - 2 : 0;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primaryPale,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = cur == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _goPeriod(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primaryPale,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      // 상단바 넉넉하게 + 토글을 헤더 하단에 앉힘(위 여백 크게, 아래 작게).
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 큰 제목 '내 활동' 제거(요청).
          Row(
            children: [
              _tabItem('기록', 0),
              const SizedBox(width: 8),
              _tabItem('뱃지', 1),
              const SizedBox(width: 8),
              _tabItem('그래프', 2),
            ],
          ),
        ],
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

  Widget _tabItem(String label, int index) {
    // '그래프'(2)는 주간/월간/누적(page 2~4) 어디에 있어도 선택 표시
    final selected = index == 2 ? _tab >= 2 : _tab == index;
    return GestureDetector(
      onTap: () => _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.cardBG : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected ? AppColors.cardShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
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
  static const List<_Activity> _activities = [
    _Activity('26.02.01 06:15', '석촌호수길', 2000, '70 g', 120, '0:30'),
    _Activity('26.02.01 17:15', '로데오거리', 3000, '40 g', 125, '0:40'),
  ];

  // 진행 중인 퀘스트 (달성률 높은 순 3개)
  List<_Quest> _quests = [];

  @override
  void initState() {
    super.initState();
    _loadQuests();
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
      list.add(_Quest(b.quest, cur, total, b.icon, _questColor(b)));
    }
    list.sort((a, b) => (b.current / b.total).compareTo(a.current / a.total));
    setState(() => _quests = list.take(3).toList());
  }

  Color _questColor(BadgeData b) {
    final id = b.id;
    if (id.startsWith('steps') || id.startsWith('distance')) {
      return AppColors.categoryBlue;
    }
    if (id.startsWith('kcal')) return AppColors.categoryRed;
    if (id.startsWith('weight') || id.startsWith('plastic')) {
      return AppColors.categoryGreen;
    }
    if (id.startsWith('group') || id.startsWith('share')) {
      return AppColors.categoryOrange;
    }
    if (id.startsWith('time') || id == 'first_30min') {
      return AppColors.categoryPurple;
    }
    return AppColors.primary;
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
        ..._activities.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _activityCard(context, a),
          ),
        ),
        const SizedBox(height: 22),
        _sectionHeader(
          '진행 중인 퀘스트',
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
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
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
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            // TODO: 실제 경로 지도 썸네일로 교체
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primaryPale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.map, color: AppColors.primaryLight),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.dateTime,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        _miniStat(Icons.directions_walk, '${a.steps}'),
                        const SizedBox(width: 10),
                        _miniStat(Icons.delete_outline, a.weight),
                        const SizedBox(width: 10),
                        _miniStat(Icons.local_fire_department, '${a.kcal}'),
                        const SizedBox(width: 10),
                        _miniStat(Icons.alarm, a.time),
                      ],
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

  Widget _miniStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textTertiary),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _questCard(_Quest q) {
    final progress = (q.current / q.total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: q.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(q.icon, color: q.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        q.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${q.current}/${q.total}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.divider,
                    color: q.color,
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

// ════════════════════════════ 뱃지 탭 ════════════════════════════
class _BadgesTab extends StatelessWidget {
  const _BadgesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final earnedCount = kBadges.where((b) => BadgeRepo.isEarned(b.id)).length;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
      ),
      children: [
        // 줍댕이 꾸미기 배너 → 꾸미기 화면
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CharacterScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.cardBG,
              borderRadius: BorderRadius.circular(18),
              boxShadow: AppColors.cardShadow,
            ),
            child: Row(
              children: const [
                // TODO: 줍댕이(물개) 2D 캐릭터 이미지로 교체
                Text('🦭', style: TextStyle(fontSize: 44)),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '줍댕이 꾸미기',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '획득한 아이템으로 나만의 캐릭터를 만들어요',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              '내 뱃지',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '$earnedCount / ${kBadges.length}개 획득',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 획득/미획득 모두 탭 → 상세 모달(획득조건 항상 노출)
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 18,
          crossAxisSpacing: 12,
          childAspectRatio: 0.70,
          children: [for (final b in kBadges) _badgeTile(context, b)],
        ),
      ],
    );
  }

  Widget _badgeTile(BuildContext context, BadgeData b) {
    final earned = BadgeRepo.isEarned(b.id);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showBadgeDetail(context, b),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: earned ? AppColors.primaryPale : AppColors.divider,
                borderRadius: BorderRadius.circular(18),
              ),
              // TODO: 실제 2D 뱃지 이미지로 교체
              child: Icon(
                earned ? b.icon : Icons.lock_outline,
                color: earned ? AppColors.primary : AppColors.textTertiary,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            earned ? b.name : '???',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: earned ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════ 그래프 탭 ════════════════════════════
class _GraphTab extends StatefulWidget {
  final int period; // 이 페이지가 담당하는 기간 (0:주간 1:월간 2:누적)
  final int playToken; // 값이 바뀌면 애니메이션 재생
  const _GraphTab({required this.period, required this.playToken});

  @override
  State<_GraphTab> createState() => _GraphTabState();
}

class _GraphTabState extends State<_GraphTab> with TickerProviderStateMixin {
  late final AnimationController _ac; // 꺾은선(월간)용 900ms
  late final AnimationController _acFast; // 막대·도넛용 800ms

  int _offset = 0; // 이 기간 안에서 보고 있는 주/월 인덱스 (0=가장 최근)

  // TODO: 실제 기간별 데이터로 교체 (지금은 더미)
  // 주간: 요일별(월~일) 막대
  static const List<_GData> _weekly = [
    _GData(
      '이번주',
      '5.24 ~ 5.31',
      '8,240',
      '1,089',
      '1.3kg',
      [0.5, 0.72, 0.4, 0.66, 0.46, 1.0, 0.6],
      _dayLabels,
      5,
    ),
    _GData(
      '지난주',
      '5.17 ~ 5.23',
      '6,110',
      '842',
      '0.9kg',
      [0.3, 0.55, 0.7, 0.4, 0.85, 0.5, 0.35],
      _dayLabels,
      4,
    ),
    _GData(
      '2주 전',
      '5.10 ~ 5.16',
      '9,530',
      '1,240',
      '1.6kg',
      [0.8, 0.6, 0.5, 0.9, 0.7, 0.65, 1.0],
      _dayLabels,
      6,
    ),
  ];

  // 월간: 1~5주 단위 막대
  static const List<String> _weekLabels = ['1주', '2주', '3주', '4주', '5주'];
  static const List<_GData> _monthly = [
    _GData(
      '이번달',
      '2026.05',
      '32,600',
      '4,210',
      '5.2kg',
      [0.6, 0.8, 0.5, 1.0, 0.4],
      _weekLabels,
      3,
    ),
    _GData(
      '지난달',
      '2026.04',
      '28,140',
      '3,690',
      '4.4kg',
      [0.5, 0.7, 0.9, 0.6, 0.3],
      _weekLabels,
      2,
    ),
  ];

  // 누적: 가입일부터 현재까지 (막대 없음, 큰 숫자)
  // TODO: 가입일은 실제 프로필 가입일로 교체
  static const _GData _cumulative = _GData(
    '전체',
    '가입일(2024.03.15~)부터',
    '184,320',
    '24,860',
    '31.5kg',
    [],
    [],
    0,
  );

  static const List<String> _dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  // 수거 종류 색: 플라스틱 파랑 / 일반 빨강 / 종이 초록 / 캔 주황 / 유리 보라
  final List<_Segment> _segments = const [
    _Segment('플라스틱', 11, AppColors.categoryBlue),
    _Segment('일반', 10, AppColors.categoryRed),
    _Segment('종이', 9, AppColors.categoryGreen),
    _Segment('캔', 5, AppColors.categoryOrange),
    _Segment('유리', 3, AppColors.categoryPurple),
  ];

  // 이 페이지 기간의 데이터셋 목록 (누적은 단일)
  List<_GData> get _currentList => widget.period == 0 ? _weekly : _monthly;

  // 이 페이지 기간의 데이터 (오프셋만큼 과거로)
  _GData _dataFor(int period) {
    if (period == 2) return _cumulative;
    final list = period == 0 ? _weekly : _monthly;
    return list[_offset.clamp(0, list.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _acFast = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _GraphTab old) {
    super.didUpdateWidget(old);
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
    // 기간 토글은 부모(_ActivityScreenState)가 헤더 아래 고정으로 그린다.
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  d.range,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            // 누적은 기간 이동 없음
            if (!isCumulative)
              Row(
                children: [
                  _arrow(
                    Icons.chevron_left,
                    off < listLen - 1,
                    () => _shift(1),
                  ),
                  const SizedBox(width: 16),
                  _arrow(Icons.chevron_right, off > 0, () => _shift(-1)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _summaryStat(
              '걸음수',
              d.steps,
              AppColors.categoryBlue,
              'track_thick.svg',
              iconSize: 58,
              iconBottom: 2,
              dx: 8, // 가운데쪽으로(오른쪽), 아이콘도 같이
            ),
            _summaryStat(
              '칼로리',
              d.kcal,
              AppColors.categoryRed,
              'fire_thick.svg',
              iconBottom: 8,
              dx: 0, // 정중앙 (기준)
            ),
            _summaryStat(
              '수거량',
              d.weight,
              AppColors.categoryGreen,
              'garbage_thick.svg',
              iconBottom: 4, // 아이콘마다 투명배경 여백이 달라 개별 보정(사용자 조정값)
              dx: -8, // 가운데쪽으로(왼쪽), 걸음수와 대칭
              textY: -0.35, // 수거량 글씨만 미세하게 위로
            ),
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
          ),
          const SizedBox(height: 16),
        ],
        // 누적은 그래프가 없어 요약과 도넛이 붙으니 공백 추가
        if (isCumulative) const SizedBox(height: 12),
        _chartCard(
          '수거 종류',
          AnimatedBuilder(
            animation: _acFast,
            builder: (_, __) => _trashDonut(_acFast.value),
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
        color: enabled ? AppColors.textSecondary : AppColors.divider,
      ),
    );
  }

  Widget _summaryStat(
    String label,
    String value,
    Color color,
    String asset, {
    double iconSize = 46,
    double iconBottom = 6,
    double dx = 0, // 묶음(글씨+아이콘)을 통째로 좌우 이동(px) — 둘이 항상 같은 픽셀로 이동
    double textY = 0, // 글씨 세로 위치 (0=가운데, 음수=위)
  }) {
    return Expanded(
      child: SizedBox(
        height: 64,
        child: Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: SizedBox(
              // ★ 고정 폭 묶음: 글씨(왼쪽) + 아이콘(오른쪽)이 한 덩어리로 같이 이동
              width: 92,
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 배경 흑백 아이콘 — 묶음 오른쪽에 peek (글씨 뒤에 안 묻힘)
                  Positioned(
                    right: 0,
                    bottom: iconBottom,
                    child: SvgPicture.asset(
                      'assets/icons/$asset',
                      width: iconSize,
                      height: iconSize,
                      colorFilter: ColorFilter.mode(
                        AppColors.textTertiary.withValues(alpha: 0.18),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  // 글씨 — 묶음 왼쪽
                  Align(
                    alignment: Alignment(-1, textY),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          height: 32,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 26,
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
    );
  }

  Widget _chartCard(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(bars.length, (i) {
        final peak = i == peakIndex;
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 최다 활동 막대 위에 2D 왕관 (도형, 차트 색과 맞춤)
              if (peak) ...[
                CustomPaint(
                  size: const Size(18, 13),
                  painter: _CrownPainter(const Color(0xFFFFEA76)),
                ),
                const SizedBox(height: 3),
              ],
              Container(
                width: 16,
                height: 90 * bars[i] * t,
                decoration: BoxDecoration(
                  color: peak
                      ? const Color(0xFF4C58AE) // 최다 활동 막대: 더 진한 인디고로 강조
                      : AppColors.chartActivity,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: peak ? FontWeight.w700 : FontWeight.w500,
                  color: peak
                      ? AppColors.chartActivityPeak
                      : AppColors.textTertiary,
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
    return Column(
      children: [
        SizedBox(
          height: 128, // 왕관 얹을 여유 포함(원래 110)
          width: double.infinity,
          child: CustomPaint(painter: _LinePainter(values, peakIndex, t)),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(labels.length, (i) {
            final peak = i == peakIndex;
            return Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: peak ? FontWeight.w700 : FontWeight.w500,
                  color: peak
                      ? AppColors.chartActivityPeak
                      : AppColors.textTertiary,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _trashDonut(double t) {
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
                painter: _DonutPainter(_segments, t),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '40개',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '총 수거',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(children: _segments.map(_legendRow).toList())),
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
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${s.value}',
            style: const TextStyle(
              fontSize: 14,
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
      ..color = AppColors.divider;

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
class _Activity {
  final String dateTime;
  final String title;
  final int steps;
  final String weight;
  final int kcal;
  final String time;
  const _Activity(
    this.dateTime,
    this.title,
    this.steps,
    this.weight,
    this.kcal,
    this.time,
  );
}

class _Quest {
  final String title;
  final int current;
  final int total;
  final IconData icon;
  final Color color;
  const _Quest(this.title, this.current, this.total, this.icon, this.color);
}

// 월간 주별 활동 꺾은선 차트
class _LinePainter extends CustomPainter {
  final List<double> values; // 0~1 비율
  final int peakIndex;
  final double progress; // 0~1, 선 그려짐 진행도
  _LinePainter(this.values, this.peakIndex, this.progress);

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
        ..color = AppColors.chartActivity.withValues(alpha: 0.12 * progress)
        ..style = PaintingStyle.fill,
    );

    // 선 (progress 만큼만 그림 = 왼→오로 그려짐)
    final linePaint = Paint()
      ..color = AppColors.chartActivity
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
        Paint()
          ..color = peak
              ? AppColors.chartActivityPeak
              : AppColors.chartActivity,
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

    // 최고 지점 위에 왕관 (주간 막대와 동일 톤)
    final peakFrac = n == 1 ? 0.0 : peakIndex / (n - 1);
    if (peakIndex >= 0 && peakIndex < n && peakFrac <= progress) {
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
      old.progress != progress;
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
