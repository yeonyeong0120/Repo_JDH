import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/trash_bag_icon.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';

/// Ploggo - 챌린지 목록 (ACT-09)
/// 기록 탭 "진행 중인 챌린지 →" → 이 화면.
/// 진행률은 BadgeService.loadStats() 의 실제 누적 통계로 계산된다.
/// 상단 [진행 중 / 달성] 탭으로 분류. (전체 탭·등급 구분 없음)
class QuestListScreen extends StatefulWidget {
  const QuestListScreen({super.key});

  @override
  State<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends State<QuestListScreen> {
  int _tab = 0; // 0 진행 중 / 1 달성
  final PageController _pageController = PageController();

  List<_Q> _quests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 누적 통계 → 챌린지 진행률
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
        // 챌린지 아이콘 = 연계 뱃지 아이콘. 수거 계열은 쓰레기봉투 아이콘.
        final collect = usesTrashBagIcon(b);
        return _Q(b.quest, cur, total, b.icon, _colorOf(b), b.points, collect);
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

  // 탭별 목록 — 진행 중(미달성) / 달성. 진행률 오름차순.
  List<_Q> _listFor(int tab) {
    final list = _quests.where((q) {
      if (tab == 0) return q.current < q.total; // 진행 중(미착수 포함)
      return q.current >= q.total; // 달성
    }).toList();
    list.sort((a, b) => (a.current / a.total).compareTo(b.current / b.total));
    return list;
  }

  // 등급 구분 없이 평평하게 나열.
  Widget _questPage(int tab) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.actionPrimary,
          strokeWidth: 2,
        ),
      );
    }
    final list = _listFor(tab);
    if (list.isEmpty) {
      return Center(
        child: Text(
          tab == 0 ? '진행 중인 챌린지가 없어요' : '아직 달성한 챌린지가 없어요',
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
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
      children: [
        for (final q in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _questCard(q),
          ),
      ],
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
                    icon: const Icon(TablerIcons.chevronLeft, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '챌린지',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // 분류 탭 (진행 중 / 달성)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _tabBar(),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _tab = i),
                children: [_questPage(0), _questPage(1)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBar() {
    const labels = ['진행 중', '달성'];
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
          color: selected ? AppColors.subPoint : AppColors.surface,
          borderRadius: BorderRadius.circular(13),
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
          const Icon(TablerIcons.circleCheckFilled, color: AppColors.subPoint, size: 24)
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
                    backgroundColor: AppColors.neutral200,
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
  final bool isCollect; // 수거량 계열 → 쓰레기봉투 아이콘
  const _Q(
    this.title,
    this.current,
    this.total,
    this.icon,
    this.color,
    this.points,
    this.isCollect,
  );

  bool get done => current >= total;
}
