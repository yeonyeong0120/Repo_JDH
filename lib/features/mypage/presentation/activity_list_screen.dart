import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/mypage/presentation/activity_detail_screen.dart';

/// 줍다행 - 전체 활동 기록 (ACT-04)
/// 기록 탭 "최근 활동 →" → 이 화면. 날짜별 리스트(시간 역순).
/// 실제 데이터는 아직 없어 더미 + TODO.
/// 위치 권장: lib/features/mypage/presentation/activity_list_screen.dart
class ActivityListScreen extends StatelessWidget {
  const ActivityListScreen({super.key});

  // TODO: 실제 활동 데이터로 교체 (날짜별, 시간 역순)
  static const List<_Act> _acts = [
    _Act('2026.02.01', '06:15', '석촌호수길', '1.4 km', 2000, '70 g', 120, '0:30'),
    _Act('2026.02.01', '17:15', '로데오거리', '2.1 km', 3000, '40 g', 125, '0:40'),
    _Act('2026.01.28', '08:02', '탄천 산책로', '3.0 km', 4100, '90 g', 210, '0:58'),
    _Act('2026.01.25', '19:30', '중앙공원', '1.1 km', 1600, '30 g', 88, '0:22'),
  ];

  @override
  Widget build(BuildContext context) {
    // 날짜별 그룹 (입력이 이미 시간 역순이라고 가정)
    final Map<String, List<_Act>> byDate = {};
    for (final a in _acts) {
      byDate.putIfAbsent(a.date, () => []).add(a);
    }

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
                  const Expanded(
                    child: Text(
                      '전체 활동 기록',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today_outlined, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () {
                      // TODO: 날짜 검색(달력) 연결
                      AppSnackBar.show(
                        context,
                        '날짜 검색은 준비 중이에요',
                        neutral: true,
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  for (final entry in byDate.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 10),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    ...entry.value.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _activityCard(context, a),
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

  Widget _activityCard(BuildContext context, _Act a) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActivityDetailScreen(
            dateTime: '${a.date} ${a.time}',
            title: a.title,
            steps: a.steps,
            weight: a.weight,
            kcal: a.kcal,
            time: a.duration,
            distance: a.distance,
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
            // TODO: 실제 봉투 인증샷/경로 썸네일로 교체
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
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
                    a.time,
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
                      fontSize: 18,
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
                        _mini(Icons.straighten, a.distance),
                        const SizedBox(width: 10),
                        _mini(Icons.delete_outline, a.weight),
                        const SizedBox(width: 10),
                        _mini(Icons.alarm, a.duration),
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

  Widget _mini(IconData icon, String value) {
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
}

class _Act {
  final String date;
  final String time;
  final String title;
  final String distance;
  final int steps;
  final String weight;
  final int kcal;
  final String duration;
  const _Act(
    this.date,
    this.time,
    this.title,
    this.distance,
    this.steps,
    this.weight,
    this.kcal,
    this.duration,
  );
}
