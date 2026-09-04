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

  // 목업: 오른쪽 정렬 '점 + 라벨' 라디오 (진행 중 / 달성)
  Widget _tabBar() {
    const labels = ['진행 중', '달성'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          _tabDot(labels[i], i),
          if (i < labels.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _tabDot(String label, int i) {
    final on = _tab == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: on ? AppColors.ink : AppColors.gray300,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: on ? FontWeight.w800 : FontWeight.w600,
              color: on ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
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

  // 진행 수치 축약 — 1000 이상은 k 로 (8200 -> 8.2k, 10000 -> 10k)
  static String _fmtCount(int n) {
    if (n < 1000) return '$n';
    final v = n / 1000.0;
    final s = v.toStringAsFixed(1);
    return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}k';
  }

  // 목업: 소프트 그레이 카드 한 줄 — 아이콘 타일 | (이름 + 진행바/달성문구) | %·체크
  Widget _questCard(_Q q) {
    final done = q.done;
    final progress = (q.current / q.total).clamp(0.0, 1.0);

    // 아이콘: 달성은 라임 위 잉크, 진행 중은 카테고리 색
    final Color iconFg = done ? AppColors.limeOn : q.color;
    final Widget iconWidget = q.isCollect
        ? TrashBagIcon(size: 20, color: iconFg)
        : Icon(q.icon, color: iconFg, size: 20);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? AppColors.lime : q.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: iconWidget,
          ),
          const SizedBox(width: 12),
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
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (done)
                  Text(
                    '달성 · ${_comma(q.points)}P 획득',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.line100,
                      color: q.color,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (done)
            const Icon(
              TablerIcons.circleCheckFilled,
              color: AppColors.ink,
              size: 21,
            )
          else
            Text(
              '${_fmtCount(q.current)}/${_fmtCount(q.total)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
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
