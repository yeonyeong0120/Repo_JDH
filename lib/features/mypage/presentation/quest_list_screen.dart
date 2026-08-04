import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';

/// 줍다행 - 전체 퀘스트 (ACT-09)
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
        return _Q(b.quest, cur, total, b.icon, _colorOf(b));
      }).toList();
      _loading = false;
    });
  }

  Color _colorOf(BadgeData b) {
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
    return AppColors.primary; // 첫 인증·연속 출석 등
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

  // 탭별 페이지 (리스트 or 빈 상태) — PageView 의 한 페이지
  Widget _questPage(int tab) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }
    final list = _listFor(tab);
    if (list.isEmpty) {
      return const Center(
        child: Text(
          '해당하는 퀘스트가 없어요',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      );
    }
    return ListView(
      // 하단 네비바가 뜬 채로 열리는 화면 → 바 높이(63+12+혹13+여유)만큼 여백.
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
      ),
      children: list
          .map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _questCard(q),
            ),
          )
          .toList(),
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
                    '전체 퀘스트',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
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

  Widget _tabBar() {
    const labels = ['전체', '진행중', '완료됨'];
    final n = labels.length; // List.length는 const 평가 불가 → final
    return LayoutBuilder(
      builder: (context, c) {
        final innerW = c.maxWidth - 8; // 좌우 padding 4씩 제외
        final segW = innerW / n;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceBrand, // 연한 트랙 (테두리 없이 부드럽게)
            borderRadius: BorderRadius.circular(14),
          ),
          child: SizedBox(
            height: 36,
            child: Stack(
              children: [
                // 슬라이딩 선택 pill — 탭 바뀌면 부드럽게 이동
                AnimatedAlign(
                  alignment: Alignment(-1 + _tab * (2 / (n - 1)), 0),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: segW,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: AppColors.buttonShadow,
                    ),
                  ),
                ),
                Row(
                  children: List.generate(n, (i) {
                    final selected = _tab == i;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pageController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        ),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 240),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            child: Text(labels[i]),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _questCard(_Q q) {
    final done = q.current >= q.total;
    final progress = (q.current / q.total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
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
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (done)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 20,
                      )
                    else
                      Text(
                        '${q.current}/${q.total}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
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
                    backgroundColor: AppColors.border,
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

class _Q {
  final String title;
  final int current;
  final int total;
  final IconData icon;
  final Color color;
  const _Q(this.title, this.current, this.total, this.icon, this.color);
}