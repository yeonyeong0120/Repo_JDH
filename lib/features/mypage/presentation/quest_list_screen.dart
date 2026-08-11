import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/trash_bag_icon.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';

/// Ploggo - 전체 퀘스트 (ACT-09)
/// 기록 탭 "진행 중인 퀘스트 →" → 이 화면.
/// 진행률은 BadgeService.loadStats() 의 실제 누적 통계로 계산된다.
/// (걸음·칼로리·무게 계수는 ActivityMetrics 와 통일)
/// 상단 [전체 / 진행중 / 완료됨] 탭으로 분류.
/// 위치 권장: lib/features/mypage/presentation/quest_list_screen.dart
class QuestListScreen extends StatefulWidget {
  const QuestListScreen({super.key});

  @override
  State<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends State<QuestListScreen> {
  int _tab = 0; // 0 전체 / 1 진행중 / 2 완료됨
  final PageController _pageController = PageController();

  // 퀘스트 색: 걸음수 파랑 / 칼로리 빨강 / 수거량 초록 / 그룹참여 주황 / 시간 보라
  List<_Q> _quests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 누적 통계 → 퀘스트 20개 진행률
  Future<void> _load() async {
    UserStats stats = const UserStats();
    try {
      stats = await BadgeService.loadStats();
    } catch (_) {
      // 실패 시 진행률 0으로 표시
    }
    if (!mounted) return;
    setState(() {
      _quests = kBadges.map((b) {
        final (cur, total) = BadgeService.progressOf(b, stats);
        // 퀘스트 아이콘 = 연계 뱃지 아이콘. 쓰레기봉투는 '한 봉지의 시작' 하나만.
        final collect = usesTrashBagIcon(b);
        return _Q(
          b.quest,
          cur,
          total,
          b.icon,
          _colorOf(b),
          b.points,
          b.tier,
          collect,
        );
      }).toList();
      _loading = false;
    });
  }

  // 5색 카테고리: 걸음·거리(파랑) / 수거(초록) / 그룹(주황) / 시간(노랑) / 칼로리(빨강)
  Color _colorOf(BadgeData b) {
    final id = b.id;
    if (id.startsWith('steps') ||
        id.startsWith('distance') ||
        id == 'first_plogging') {
      return AppColors.dataSteps; // 파랑
    }
    if (id.startsWith('kcal')) return AppColors.dataCalorie; // 빨강
    if (id.startsWith('weight') ||
        id.startsWith('plastic') ||
        id == 'first_verify') {
      return AppColors.green600; // 초록 (수거)
    }
    if (id.startsWith('group') || id.startsWith('share')) {
      return AppColors.dataGroup; // 주황
    }
    return AppColors.dataTime; // 노랑 (시간·연속 등)
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 탭별 퀘스트 목록 (필터 + 진행률 오름차순 정렬)
  // 진행중 = 0<현재<목표 / 완료됨 = 현재>=목표 / 전체 = 모두(미착수 포함)
  List<_Q> _listFor(int tab) {
    final list = _quests.where((q) {
      if (tab == 1) return q.current > 0 && q.current < q.total;
      if (tab == 2) return q.current >= q.total;
      return true;
    }).toList();
    list.sort((a, b) => (a.current / a.total).compareTo(b.current / b.total));
    return list;
  }

  static const List<BadgeTier> _tierOrder = [
    BadgeTier.seed,
    BadgeTier.sprout,
    BadgeTier.tree,
    BadgeTier.forest,
  ];

  IconData _tierIcon(BadgeTier t) => switch (t) {
    BadgeTier.seed => Icons.spa,
    BadgeTier.sprout => Icons.eco,
    BadgeTier.tree => Icons.park,
    BadgeTier.forest => Icons.forest,
  };

  Color _tierColor(BadgeTier t) => switch (t) {
    BadgeTier.seed => AppColors.green400,
    BadgeTier.sprout => AppColors.green500,
    BadgeTier.tree => AppColors.green600,
    BadgeTier.forest => AppColors.green700,
  };

  // 탭별 페이지 — 등급(씨앗→새싹→나무→숲)별로 묶어서 표시.
  Widget _questPage(int tab) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }
    final full = _quests;
    final list = _listFor(tab);

    final children = <Widget>[];
    if (tab == 0) {
      final doneAll = full.where((q) => q.done).length;
      children
        ..add(_summaryCard(doneAll, full.length))
        ..add(const SizedBox(height: 10))
        ..add(_legend())
        ..add(const SizedBox(height: 4));
    }

    bool any = false;
    for (final t in _tierOrder) {
      final inTier = list.where((q) => q.tier == t).toList();
      if (inTier.isEmpty) continue;
      any = true;
      final tierTotal = full.where((q) => q.tier == t).length;
      final tierDone = full.where((q) => q.tier == t && q.done).length;
      children.add(_tierHeader(t, tierDone, tierTotal));
      for (final q in inTier) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _questCard(q),
          ),
        );
      }
    }

    if (!any) {
      return const Center(
        child: Text(
          '해당하는 퀘스트가 없어요',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
      ),
      children: children,
    );
  }

  Widget _summaryCard(int done, int total) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          const Text(
            '달성한 퀘스트',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '$done / $total',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textBrandOnLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend() {
    const items = [
      (AppColors.dataSteps, '걸음·거리'),
      (AppColors.green600, '수거'),
      (AppColors.dataGroup, '그룹'),
      (AppColors.dataTime, '시간'),
      (AppColors.dataCalorie, '칼로리'),
    ];
    return Wrap(
      spacing: 9,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        for (final it in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: it.$1, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                it.$2,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _tierHeader(BadgeTier t, int done, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 12),
      child: Row(
        children: [
          Icon(_tierIcon(t), size: 20, color: _tierColor(t)),
          const SizedBox(width: 8),
          Text(
            '${t.label} 등급',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            '$done / $total',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '퀘스트',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // 분류 탭
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _tabBar(),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                // 스와이프로도 탭 전환 → 토글 pill 이 따라오도록 _tab 갱신
                onPageChanged: (i) => setState(() => _tab = i),
                children: [_questPage(0), _questPage(1), _questPage(2)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 둥근 알약 3개 (전체=초록 채움 / 나머지=흰 테두리). 왼쪽 정렬.
  Widget _tabBar() {
    const labels = ['전체', '진행 중', '달성'];
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          _pill(labels[i], i),
          if (i < labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _pill(String label, int i) {
    final selected = _tab == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.actionPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
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

  Widget _questCard(_Q q) {
    final done = q.done;
    final progress = (q.current / q.total).clamp(0.0, 1.0);
    final pct = (progress * 100).round();

    // 완료된 퀘스트는 전체적으로 흐리게 (체크는 선명 유지).
    final Widget iconWidget = q.isCollect
        ? TrashBagIcon(size: 24, color: q.color)
        : Icon(q.icon, color: q.color, size: 24);

    final header = Row(
      children: [
        Opacity(
          opacity: done ? 0.45 : 1,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: q.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: iconWidget,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Opacity(
            opacity: done ? 0.5 : 1,
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
                  done
                      ? '달성 · ${q.title} 뱃지 획득'
                      : '${_comma(q.current)} / ${_comma(q.total)} · 달성 시 ${q.points}P',
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
        ),
        const SizedBox(width: 10),
        if (done)
          const Icon(Icons.check_circle, color: AppColors.green500, size: 24)
        else
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: q.color,
            ),
          ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: done
          ? header
          : Column(
              children: [
                header,
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

class _Q {
  final String title;
  final int current;
  final int total;
  final IconData icon;
  final Color color;
  final int points;
  final BadgeTier tier;
  final bool isCollect; // 수거량 계열 → 쓰레기봉투 아이콘
  const _Q(
    this.title,
    this.current,
    this.total,
    this.icon,
    this.color,
    this.points,
    this.tier,
    this.isCollect,
  );

  bool get done => current >= total;
}