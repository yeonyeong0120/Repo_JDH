import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';

/// 줍다행 - 그룹 소개/가입 화면 (다른 동네 그룹 카드 → 이 화면)
/// 채팅방(멤버 인증샷)은 가입 전엔 보여주지 않고, 소개 + 가입만.
/// 위치 권장: lib/features/community/presentation/group_detail_screen.dart
class GroupDetailScreen extends StatelessWidget {
  final String name;
  final String region;
  final String meta;
  // 이미 다른 그룹에 소속돼 있는지 (1인 1그룹 판단용)
  // TODO: 실제 데이터로 교체 — 지금은 group_screen에서 _myGroups.isNotEmpty 를 넘김
  final bool alreadyInGroup;
  const GroupDetailScreen({
    super.key,
    required this.name,
    required this.region,
    required this.meta,
    this.alreadyInGroup = false,
  });

  // 가입하기 → 확인 팝업 → 예 → (이미 그룹 있으면) 차단 / (없으면) 가입 성공
  Future<void> _join(BuildContext context) async {
    final ok = await AppDialog.show(
      context,
      title: '그룹 가입',
      message: '$name 그룹에 가입하시겠습니까?',
      cancelText: '아니오',
      confirmText: '예',
    );
    if (ok != true) return;
    if (alreadyInGroup) {
      if (context.mounted) _showAlreadyJoined(context); // GRP-04 차단
    } else {
      if (context.mounted) _doJoin(context); // 실제 가입 처리
    }
  }

  // GRP-04: 이미 그룹 가입된 상태 → 차단 모달 (자동 탈퇴 없음, 안내만)
  void _showAlreadyJoined(BuildContext context) {
    AppDialog.showInfo(
      context,
      title: '가입 불가',
      message: '이미 그룹에 가입되어 있습니다.\n\n기존 그룹에서 탈퇴한 뒤 다시 가입해 주세요.',
    );
  }

  void _doJoin(BuildContext context) {
    // TODO: 실제 가입 로직 연결 (그룹 소속 Firestore 저장)
    //       지금은 임시로 가입 성공 처리 → 그 그룹 채팅방으로 이동.
    AppSnackBar.show(context, '$name 그룹에 가입했어요');
    context.push('/group/feed', extra: name);
  }

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
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/group'),
                  ),
                  const Text(
                    '그룹 소개',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    // 그룹 대표 이미지 (placeholder)
                    Container(
                      width: 96,
                      height: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryPale,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text('🌱', style: TextStyle(fontSize: 44)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      region,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 그룹 소개
                    _card(
                      title: '그룹 소개',
                      child: const Text(
                        // TODO: 실제 그룹 소개글로 교체
                        '우리 동네를 함께 깨끗하게! 가볍게 걷고 주우며 포인트도 받아가요. '
                        '누구나 편하게 참여할 수 있는 동네 플로깅 모임이에요.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 멤버 미리보기 (아이콘만)
                    _card(
                      title: '멤버',
                      child: Row(
                        children: [
                          for (int i = 0; i < 4; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primaryPale,
                                child: const Icon(
                                  Icons.person,
                                  size: 20,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Text(
                            '외 여러 명',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 가입 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
              child: AppButton(
                label: '가입하기',
                onTap: () => _join(context),
                type: AppButtonType.primary,
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
