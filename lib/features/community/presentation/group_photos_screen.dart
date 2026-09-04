import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'photo_detail_screen.dart';

// ============================================================
// 그룹 활동 사진 (Startline 17 — 인증샷 그리드)
//  - 그룹 채팅 → 햄버거 메뉴 → 활동 사진 으로 진입.
//  - 실데이터: GroupService.posts(groupId) 중 인증샷(imageUrl 있는 활동)만 모은다.
//    작성자 이름·사진·시각·내 사진 여부는 모두 실데이터.
//  - 필터(전체 / 이번 주 / 내 사진)는 실제 필드(createdAt, isMine)로 동작.
//  - 목업의 사진별 kg 배지는 앱 데이터에 없어 표시하지 않는다.
//  - 타일 탭 → PhotoDetailScreen(한 컷).
// ============================================================

enum _PhotoFilter { all, week, mine }

class GroupPhotosScreen extends StatefulWidget {
  final String groupId;

  const GroupPhotosScreen({super.key, required this.groupId});

  @override
  State<GroupPhotosScreen> createState() => _GroupPhotosScreenState();
}

class _GroupPhotosScreenState extends State<GroupPhotosScreen> {
  List<GroupPost> _photos = [];
  bool _loading = true;
  _PhotoFilter _filter = _PhotoFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.groupId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    List<GroupPost> photos = [];
    try {
      final posts = await GroupService.posts(widget.groupId, limit: 100);
      // 인증샷만: 활동 카드 중 이미지가 있는 것.
      photos = posts
          .where((p) => !p.isMessage && !p.isSystem && p.imageUrl != null)
          .toList();
    } catch (e) {
      debugPrint('[그룹 사진] 목록 로드 실패: $e');
    }
    if (!mounted) return;
    setState(() {
      _photos = photos;
      _loading = false;
    });
  }

  // 현재 필터가 적용된 사진 목록.
  List<GroupPost> get _visible {
    switch (_filter) {
      case _PhotoFilter.mine:
        return _photos.where((p) => p.isMine).toList();
      case _PhotoFilter.week:
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        return _photos.where((p) => p.createdAt.isAfter(weekAgo)).toList();
      case _PhotoFilter.all:
        return _photos;
    }
  }

  Future<void> _openDetail(GroupPost p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoDetailScreen(post: p)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar('활동 사진 ${_photos.length}장'),
            // 필터 칩
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.screenPad,
                Gap.sm,
                Gap.screenPad,
                Gap.md,
              ),
              child: Row(
                children: [
                  _chip('전체', _PhotoFilter.all),
                  Gap.w8,
                  _chip('이번 주', _PhotoFilter.week),
                  Gap.w8,
                  _chip('내 사진', _PhotoFilter.mine),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.progress,
                        strokeWidth: 2,
                      ),
                    )
                  : list.isEmpty
                      ? _empty()
                      : GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            Gap.screenPad,
                            Gap.xs,
                            Gap.screenPad,
                            MediaQueryData.fromView(
                                  View.of(context),
                                ).padding.bottom +
                                24,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.86,
                          ),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _PhotoTile(
                            post: list[i],
                            onTap: () => _openDetail(list[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, Gap.sm, Gap.screenPad, 0),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
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
          Text(title, style: AppType.title2),
        ],
      ),
    );
  }

  // 필터 칩 — 선택 시 잉크 면 + 흰 글씨, 미선택은 소프트 그레이.
  Widget _chip(String label, _PhotoFilter value) {
    final selected = _filter == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.surface : AppColors.gray700,
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              TablerIcons.photo,
              size: 40,
              color: AppColors.gray400,
            ),
            Gap.h12,
            Text('아직 활동 사진이 없어요', style: AppType.title3),
            Gap.h4,
            Text(
              '플로깅 인증샷을 공유하면 여기에 모여요',
              style: AppType.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 사진 타일 (인증샷 + 하단 작성자 이름) ──
class _PhotoTile extends StatelessWidget {
  final GroupPost post;
  final VoidCallback onTap;
  const _PhotoTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = post.imageUrl;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: Radii.tileR,
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: (url != null && url.startsWith('http'))
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const Icon(
                        TablerIcons.photo,
                        size: 26,
                        color: AppColors.gray400,
                      ),
                    )
                  : const Icon(
                      TablerIcons.photo,
                      size: 26,
                      color: AppColors.gray400,
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            post.userName.isEmpty ? '플로거' : post.userName,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
