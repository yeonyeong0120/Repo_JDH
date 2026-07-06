import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 줍다행 - 전체 퀘스트 (ACT-09)
/// 기록 탭 "진행 중인 퀘스트 →" → 이 화면. 실제 데이터는 더미 + TODO.
/// 위치 권장: lib/features/mypage/presentation/quest_list_screen.dart
class QuestListScreen extends StatelessWidget {
  const QuestListScreen({super.key});

  // TODO: 실제 퀘스트 데이터로 교체
  static const List<_Q> _quests = [
    _Q('10일 연속 출석', 5, 10, Icons.verified, AppColors.primary),
    _Q('플라스틱 50개 수거', 32, 50, Icons.recycling, AppColors.coralDeep),
    _Q('그룹 활동 5회 참여', 3, 5, Icons.groups, AppColors.mintDeep),
    _Q('누적 10km 걷기', 6, 10, Icons.directions_walk, AppColors.primaryDeep),
    _Q('첫 봉투 인증샷', 1, 1, Icons.photo_camera, AppColors.warning),
    _Q('주말 플로깅 3회', 1, 3, Icons.weekend, AppColors.trashGeneral),
  ];

  @override
  Widget build(BuildContext context) {
    final ongoing = _quests.where((q) => q.current < q.total).toList();
    final done = _quests.where((q) => q.current >= q.total).toList();

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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _sectionLabel('진행 중 ${ongoing.length}'),
                  const SizedBox(height: 12),
                  ...ongoing.map(
                    (q) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _questCard(q),
                    ),
                  ),
                  if (done.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionLabel('완료 ${done.length}'),
                    const SizedBox(height: 12),
                    ...done.map(
                      (q) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _questCard(q),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
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
                    color: done ? AppColors.primary : q.color,
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
