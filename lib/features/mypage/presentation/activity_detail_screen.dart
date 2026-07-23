import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';

/// 줍다행 - 개별 활동 상세 (ACT-05)
/// 기록 탭 활동 카드 → 이 화면. 실제 데이터는 아직 없어 더미 + TODO.
/// 위치 권장: lib/features/mypage/presentation/activity_detail_screen.dart
class ActivityDetailScreen extends StatelessWidget {
  final String dateTime;
  final String title;
  final int steps;
  final String weight;
  final int kcal;
  final String time;
  final String distance;
  final bool hasPhoto;

  const ActivityDetailScreen({
    super.key,
    required this.dateTime,
    required this.title,
    this.steps = 0,
    this.weight = '0 g',
    this.kcal = 0,
    this.time = '0:00',
    this.distance = '0 km',
    this.hasPhoto = true,
  });

  @override
  Widget build(BuildContext context) {
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
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    color: AppColors.textSecondary,
                    onPressed: () => _showMenu(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                // 하단 네비바 가림 방지
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
                ),
                children: [
                  Text(
                    dateTime,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 활동 경로 지도
                  _card(
                    title: '활동 경로',
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryPale,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      // TODO: 실제 경로 지도(Polyline + 거점 마커)로 교체
                      child: const Icon(
                        Icons.map_outlined,
                        size: 34,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 봉투 인증샷 (있는 경우)
                  if (hasPhoto)
                    _card(
                      title: '봉투 인증샷',
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryPale,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        // TODO: 실제 사진(Image.network)으로 교체
                        child: const Icon(
                          Icons.photo_camera_outlined,
                          size: 32,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  if (hasPhoto) const SizedBox(height: 14),
                  // 통계
                  _card(
                    title: '활동 기록',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _stat('거리', distance),
                            const SizedBox(width: 10),
                            _stat('시간', time),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _stat('걸음', '$steps'),
                            const SizedBox(width: 10),
                            _stat('칼로리', '$kcal'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(children: [_stat('수거 무게', weight)]),
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

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.groups, color: AppColors.textPrimary),
              title: const Text('그룹에 공유'),
              onTap: () {
                Navigator.pop(ctx);
                // TODO: 실제 그룹 공유 로직 (그룹 피드에 활동 카드 push)
                //   주의: 정산에서 찍기/갤러리로 이미 공유된 활동은
                //         중복 공유되지 않도록 처리 필요
                AppSnackBar.show(context, '그룹에 공유했어요');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                '활동 삭제',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await AppDialog.show(
                  context,
                  title: '활동 삭제',
                  message: '이 활동 기록을 삭제할까요?\n\n삭제하면 되돌릴 수 없어요.',
                  cancelText: '취소',
                  confirmText: '삭제',
                  danger: true,
                );
                if (ok == true && context.mounted) {
                  // TODO: 실제 삭제 로직 연결
                  AppSnackBar.show(context, '활동을 삭제했어요');
                  Navigator.pop(context); // 상세 화면 닫기
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryPale,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
