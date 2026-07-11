import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/mypage/presentation/activity_detail_screen.dart';
import 'package:repo_jdh/features/mypage/presentation/activity_list_screen.dart';
import 'package:repo_jdh/features/mypage/presentation/quest_list_screen.dart';

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
  final PageController _pageController = PageController();

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
            Expanded(
              child: PageView(
                controller: _pageController,
                // 좌우 스와이프로 탭 이동 → 토글 pill·그래프 애니메이션도 따라오게
                onPageChanged: (i) => setState(() {
                  _tab = i;
                  if (i == 2) _graphPlay++;
                }),
                children: [
                  const _RecordsTab(),
                  const _BadgesTab(),
                  _GraphTab(playToken: _graphPlay),
                ],
              ),
            ),
          ],
        ),
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

  Widget _tabItem(String label, int index) {
    final selected = _tab == index;
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
class _RecordsTab extends StatelessWidget {
  const _RecordsTab();

  static const List<_Activity> _activities = [
    _Activity('26.02.01 06:15', '석촌호수길', 2000, '70 g', 120, '0:30'),
    _Activity('26.02.01 17:15', '로데오거리', 3000, '40 g', 125, '0:40'),
  ];

  // 퀘스트 색: 걸음수 파랑 / 칼로리 빨강 / 수거량 초록 / 그룹참여 주황 / 시간 보라
  static const List<_Quest> _quests = [
    _Quest(
      '누적 10,000보 걷기',
      6200,
      10000,
      Icons.directions_walk,
      AppColors.categoryBlue,
    ),
    _Quest('수거량 5kg 달성', 3200, 5000, Icons.recycling, AppColors.categoryGreen),
    _Quest('그룹 활동 5회 참여', 3, 5, Icons.groups, AppColors.categoryOrange),
  ];

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
  const _BadgesTab();

  static const List<_Badge> _earned = [
    _Badge('첫 걸음', Icons.directions_walk),
    _Badge('작심 7일', Icons.verified),
    _Badge('사교의 왕', Icons.groups),
    _Badge('스치면 분류 끝', Icons.recycling),
  ];

  static const int _total = 24;

  @override
  Widget build(BuildContext context) {
    final lockedCount = 8; // 잠긴 뱃지 표시 개수 (?? 로 표시)
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
      ),
      children: [
        // 줍댕이 꾸미기 배너
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.cardBG,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: const [
              // TODO: 줍댕이(물개) 캐릭터 이미지로 교체
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
            ],
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
              '${_earned.length} / $_total개 획득',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 18,
          crossAxisSpacing: 12,
          // 오버플로우 방지를 위해 0.78 에서 0.70 으로 비율을 수정하여 세로 공간 확보
          childAspectRatio: 0.70,
          children: [
            ..._earned.map(_earnedBadge),
            ...List.generate(lockedCount, (_) => _lockedBadge()),
          ],
        ),
      ],
    );
  }

  Widget _earnedBadge(_Badge b) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.primaryPale,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(14),
          child: Icon(b.icon, color: AppColors.primary, size: 30),
        ),
        const SizedBox(height: 6),
        Text(
          b.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _lockedBadge() {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '???',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

// ════════════════════════════ 그래프 탭 ════════════════════════════
class _GraphTab extends StatefulWidget {
  final int playToken; // 값이 바뀌면 애니메이션 재생 (탭 재진입마다)
  const _GraphTab({required this.playToken});

  @override
  State<_GraphTab> createState() => _GraphTabState();
}

class _GraphTabState extends State<_GraphTab> with TickerProviderStateMixin {
  late final AnimationController _ac; // 꺾은선(월간)용 900ms
  late final AnimationController _acFast; // 막대·도넛용 800ms

  int _period = 0; // 0:주간 1:월간 2:누적
  int _offset = 0; // 현재 보고 있는 주/월 인덱스 (0=가장 최근)

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

  // 현재 기간의 데이터셋 목록 (누적은 단일)
  List<_GData> get _currentList => _period == 0 ? _weekly : _monthly;

  // 특정 기간 페이지용 데이터 (스와이프 대상 페이지가 자기 기간으로 그리게)
  _GData _dataFor(int period) {
    if (period == 2) return _cumulative;
    final list = period == 0 ? _weekly : _monthly;
    final off = (period == _period) ? _offset : 0; // 현재 페이지만 오프셋 적용
    return list[off.clamp(0, list.length - 1)];
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

  void _changePeriod(int p) {
    setState(() {
      _period = p;
      _offset = 0; // 기간 바꾸면 최근으로 리셋
    });
    _replay(); // 데이터 바뀌면 다시 차오름
  }

  // 화살표: older = 과거로(오프셋+1), newer = 최근으로(오프셋-1)
  void _shift(int delta) {
    if (_period == 2) return; // 누적은 이동 없음
    final max = _currentList.length - 1;
    setState(() => _offset = (_offset + delta).clamp(0, max));
    _replay();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 고정: 기간 토글 (스와이프해도 위에 그대로)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: _periodToggle(),
        ),
        const SizedBox(height: 22),
        // 현재 기간 내용만 표시 (기간 전환은 위 토글 탭).
        // 여기에 PageView를 두면 메인 탭 스와이프가 막혀서 안 씀.
        Expanded(child: _periodBody(_period)),
      ],
    );
  }

  // 기간 페이지 1개 (주간/월간/누적) — 자기 기간으로 그린다
  Widget _periodBody(int period) {
    final d = _dataFor(period);
    final isCumulative = period == 2;
    final off = (period == _period) ? _offset : 0;
    final listLen = period == 0
        ? _weekly.length
        : (period == 1 ? _monthly.length : 1);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
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
            ),
            _summaryStat(
              '칼로리',
              d.kcal,
              AppColors.categoryRed,
              'fire_thick.svg',
              iconBottom: 8,
            ),
            _summaryStat(
              '수거량',
              d.weight,
              AppColors.categoryGreen,
              'garbage_thick.svg',
              iconBottom: 2,
            ),
          ],
        ),
        const SizedBox(height: 22),
        // 주간: 요일별 막대 / 월간: 주별 꺾은선 / 누적: 그래프 없음
        if (period == 0) ...[
          _chartCard(
            '요일별 활동',
            SizedBox(
              height: 130,
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

  Widget _periodToggle() {
    final labels = ['주간', '월간', '누적'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primaryPale,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _period == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changePeriod(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
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

  Widget _summaryStat(
    String label,
    String value,
    Color color,
    String asset, {
    double iconSize = 46,
    double iconBottom = 6,
  }) {
    return Expanded(
      child: SizedBox(
        height: 64,
        child: Stack(
          // 살짝 왼쪽으로 치우치되 오른쪽 배경 아이콘과 겹치게 (-1=완전왼쪽, 0=가운데)
          alignment: const Alignment(-0.3, 0),
          clipBehavior: Clip.hardEdge, // 아이콘이 칸 밖으로 안 나가게
          children: [
            // 배경 아이콘 (아이콘마다 밑변 위치 보정)
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
            // 글자 (왼쪽 정렬 + 폭에 맞춰 축소)
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
          height: 110,
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

class _Badge {
  final String label;
  final IconData icon;
  const _Badge(this.label, this.icon);
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
    const padTop = 12.0;
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
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values ||
      old.peakIndex != peakIndex ||
      old.progress != progress;
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
