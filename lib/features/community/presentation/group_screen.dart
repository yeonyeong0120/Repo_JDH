import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 줍다행 - 그룹 화면 (그룹 목록 / 메인 홈)
/// 카드 탭 → 그룹 세부 피드(/group/feed)로 이동.
/// 위치 권장: lib/features/community/presentation/group_screen.dart
class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  static const List<_Group> _myGroups = [_Group('00동 같이 주워봐요')];

  static const List<_Group> _otherGroups = [
    _Group('00동 모여랏'),
    _Group('활동 가치해윱'),
    _Group('14년생만 ><'),
    _Group('00중학교 0학년 0반'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                children: [
                  _sectionLabel('내 그룹'),
                  const SizedBox(height: 12),
                  ..._myGroups.map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _groupCard(context, g),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionLabel('다른 동네 그룹'),
                  const SizedBox(height: 12),
                  ..._otherGroups.map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _groupCard(context, g),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primaryPale,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '그룹',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '같이 쓰레기 줍고 포인트 받아가자!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _iconButton(Icons.search),
              const SizedBox(width: 8),
              _iconButton(Icons.add),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon) {
    // TODO: onTap 연결 (검색 / 그룹 만들기)
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
      ),
      child: Icon(icon, color: AppColors.textSecondary, size: 22),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _groupCard(BuildContext context, _Group g) {
    return GestureDetector(
      onTap: () => context.push('/group/feed', extra: g.name),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            // TODO: 실제 그룹 대표 이미지로 교체
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    g.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    g.region,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    g.meta,
                    style: const TextStyle(
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
    );
  }
}

class _Group {
  final String name;
  final String region;
  final String meta;
  const _Group(
    this.name, {
    this.region = '00구 00동',
    this.meta = '00명 · 오늘 활동 인원 0명',
  });
}
