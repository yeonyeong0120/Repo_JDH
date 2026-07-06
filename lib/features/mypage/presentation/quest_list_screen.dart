import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 줍다행 - 전체 퀘스트 (ACT-09)
/// 기록 탭 "진행 중인 퀘스트 →" → 이 화면. 실제 데이터는 더미 + TODO.
/// 상단 [전체 / 진행중 / 완료됨] 탭으로 분류.
/// 위치 권장: lib/features/mypage/presentation/quest_list_screen.dart
class QuestListScreen extends StatefulWidget {
  const QuestListScreen({super.key});

  @override
  State<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends State<QuestListScreen> {
  int _tab = 0; // 0 전체 / 1 진행중 / 2 완료됨

  // 퀘스트 색: 걸음수 파랑 / 칼로리 빨강 / 수거량 초록 / 그룹참여 주황 / 시간 보라
  // TODO: 실제 퀘스트 데이터로 교체
  static const List<_Q> _quests = [
    _Q(
      '누적 10,000보 걷기',
      6200,
      10000,
      Icons.directions_walk,
      AppColors.categoryBlue,
    ),
    _Q(
      '누적 30,000보 걷기',
      0,
      30000,
      Icons.directions_walk,
      AppColors.categoryBlue,
    ),
    _Q(
      '칼로리 500kcal 소모',
      500,
      500,
      Icons.local_fire_department,
      AppColors.categoryRed,
    ),
    _Q('수거량 5kg 달성', 3200, 5000, Icons.recycling, AppColors.categoryGreen),
    _Q('수거량 1kg 달성', 1000, 1000, Icons.recycling, AppColors.categoryGreen),
    _Q('그룹 활동 5회 참여', 3, 5, Icons.groups, AppColors.categoryOrange),
    _Q('그룹 활동 10회 참여', 0, 10, Icons.groups, AppColors.categoryOrange),
    _Q('누적 3시간 플로깅', 90, 180, Icons.timer, AppColors.categoryPurple),
    _Q('첫 30분 플로깅', 30, 30, Icons.timer, AppColors.categoryPurple),
  ];

  @override
  Widget build(BuildContext context) {
    // 탭 필터: 진행중 = 0<현재<목표 / 완료됨 = 현재>=목표 / 전체 = 모두(미착수 포함)
    final list = _quests.where((q) {
      if (_tab == 1) return q.current > 0 && q.current < q.total;
      if (_tab == 2) return q.current >= q.total;
      return true;
    }).toList();
    // 진행률 오름차순 정렬 (미착수 → 덜 진행 → 더 진행 → 완료)
    list.sort((a, b) => (a.current / a.total).compareTo(b.current / b.total));

    return Scaffold(
      backgroundColor: AppColors.appBG,
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
                      fontSize: 18,
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
              child: list.isEmpty
                  ? const Center(
                      child: Text(
                        '해당하는 퀘스트가 없어요',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      children: list
                          .map(
                            (q) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _questCard(q),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBar() {
    const labels = ['전체', '진행중', '완료됨'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.appBG,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _tab == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 14,
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

  Widget _questCard(_Q q) {
    final done = q.current >= q.total;
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
                          fontSize: 16,
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

class _Q {
  final String title;
  final int current;
  final int total;
  final IconData icon;
  final Color color;
  const _Q(this.title, this.current, this.total, this.icon, this.color);
}
