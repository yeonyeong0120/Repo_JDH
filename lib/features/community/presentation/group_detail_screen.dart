import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:go_router/go_router.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';

/// Ploggo - 그룹 소개/가입 화면 (다른 동네 그룹 카드 → 이 화면)
/// 목업 Group Detail.dc.html 기준: 초록 헤더 + 소개/기록/멤버 카드 + 하단 고정 가입바.
/// 채팅방(멤버 인증샷)은 가입 전엔 보여주지 않고, 소개 + 가입만.
class GroupDetailScreen extends StatelessWidget {
  final Group group;
  // 이미 다른 그룹에 소속돼 있는지 (1인 1그룹 판단용)
  final bool alreadyInGroup;

  const GroupDetailScreen({
    super.key,
    required this.group,
    this.alreadyInGroup = false,
  });

  // 가입하기 → 확인 팝업 → 예 → (이미 그룹 있으면) 차단 / (없으면) 가입
  Future<void> _join(BuildContext context) async {
    final ok = await AppDialog.show(
      context,
      title: '${group.name}에 가입할까요?',
      message: '가입하면 채팅방에 바로 들어가요. 언제든 탈퇴할 수 있어요.',
      cancelText: '아니오',
      confirmText: '가입하기',
    );
    if (ok != true) return;
    if (alreadyInGroup) {
      if (context.mounted) {
        AppDialog.showInfo(
          context,
          title: '가입할 수 없어요',
          message: '이미 그룹에 가입되어 있어요.\n기존 그룹에서 탈퇴한 뒤 다시 가입해 주세요.',
        );
      }
    } else {
      if (context.mounted) _doJoin(context);
    }
  }

  Future<void> _doJoin(BuildContext context) async {
    try {
      if (group.id.isNotEmpty) await GroupService.joinGroup(group.id);
    } catch (e) {
      if (context.mounted) AppSnackBar.show(context, '가입하지 못했어요');
      return;
    }
    if (!context.mounted) return;
    AppSnackBar.show(context, '가입했어요. 채팅방으로 이동할게요');
    context.push('/group/feed', extra: {'id': group.id, 'name': group.name});
  }

  @override
  Widget build(BuildContext context) {
    final bool active = group.todayActiveCount > 0;
    final String created =
        '${group.createdAt.year}.${group.createdAt.month.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: AppColors.bg,
      // 가입바를 스크롤과 분리(Column)해서, 마지막 안내 문장이 항상 바 위로
      // 스크롤돼 절대 가리지 않게 한다.
      body: Column(
        children: [
          Expanded(
            // 스크롤 없이 한 화면에 고정 (physics 끔).
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, active),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _introCard(),
                        const SizedBox(height: 10),
                        _statsCard(),
                        const SizedBox(height: 10),
                        _memberCard(created),
                        const SizedBox(height: 10),
                        _infoBanner(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _bottomBar(context),
        ],
      ),
    );
  }

  // ── 초록 헤더 ──
  Widget _header(BuildContext context, bool active) {
    final double topPad = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceBrand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 뒤로가기 (40px · 흰색 0.82 · 라운드 14)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/group'),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                TablerIcons.chevronLeft,
                size: 24,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppColors.cardShadow,
                ),
                child: const Icon(
                  TablerIcons.users,
                  size: 34,
                  color: AppColors.neutral400,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1.35,
                        letterSpacing: -0.6,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.region} · 멤버 ${group.memberCount}명',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textOnTint,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.actionPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '오늘 ${group.todayActiveCount}명 활동 중',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textBrandOnLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 흰 카드 공통 ──
  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }

  Widget _cardTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 17,
      height: 1.4,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );

  Widget _introCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('그룹 소개'),
          const SizedBox(height: 8),
          Text(
            group.intro.isEmpty ? '아직 소개가 없어요.' : group.intro,
            style: const TextStyle(
              fontSize: 15,
              height: 1.65,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ⚠️ 함께 만든 기록: 그룹 집계 데이터 소스가 아직 없어 자리만 둔다.
  // TODO: 그룹별 누적 수거량·거리·활동일 집계가 생기면 값 연결.
  Widget _statsCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('함께 만든 기록'),
          const SizedBox(height: 14),
          Row(
            children: [
              _statTile('—', '주운 개수'),
              const SizedBox(width: 8),
              _statTile('—', '함께 걸은 km'),
              const SizedBox(width: 8),
              _statTile('—', '함께한 날'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberCard(String created) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _cardTitle('멤버')),
              Text(
                '${group.memberCount}명',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AvatarRow(count: group.memberCount),
          const SizedBox(height: 8),
          const Text(
            '가입하면 멤버들의 인증샷과 채팅방을 볼 수 있어요.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                TablerIcons.calendarMonth,
                size: 17,
                color: AppColors.neutral400,
              ),
              const SizedBox(width: 6),
              Text(
                '$created 개설',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            TablerIcons.infoCircleFilled,
            size: 19,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              '그룹은 한 번에 하나만 가입할 수 있어요. 다른 그룹으로 옮기려면 지금 그룹에서 먼저 탈퇴해 주세요.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 하단 고정 가입 바 ──
  Widget _bottomBar(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.neutral100)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPad),
      child: alreadyInGroup
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      TablerIcons.alertCircleFilled,
                      size: 18,
                      color: AppColors.actionDanger,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '이미 그룹에 가입되어 있어요',
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: AppColors.actionDanger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _bigButton(
                  label: '가입하기',
                  enabled: false,
                  onTap: () {},
                ),
              ],
            )
          : _bigButton(label: '가입하기', onTap: () => _join(context)),
    );
  }

  Widget _bigButton({
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.actionPrimary : AppColors.border,
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.neutral900.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.textOnBrand : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 겹쳐 놓인 멤버 아바타(최대 6 + 나머지 수). 목업: 40px · DCEDE3 · 겹침 -8.
class _AvatarRow extends StatelessWidget {
  final int count;
  const _AvatarRow({required this.count});

  @override
  Widget build(BuildContext context) {
    const double d = 32;
    const double step = 26; // 32 - 6 겹침
    final int shown = count > 6 ? 6 : count;
    final int extra = count - shown;
    final int chips = shown + (extra > 0 ? 1 : 0);
    if (chips == 0) return const SizedBox.shrink();

    return SizedBox(
      height: d,
      width: d + (chips - 1) * step,
      child: Stack(
        children: [
          for (int i = 0; i < shown; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: d,
                height: d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCEDE3),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: const Icon(
                  TablerIcons.userFilled,
                  size: 21,
                  color: AppColors.textBrandOnLight,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown * step,
              child: Container(
                width: d,
                height: d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
