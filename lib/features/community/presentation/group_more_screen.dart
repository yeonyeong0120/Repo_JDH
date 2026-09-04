import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/core/widgets/group_thumb.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'group_detail_screen.dart';

// ============================================================
// 그룹 더보기 (Startline 13 — "이런 그룹 어때요?" 전체 목록)
//  - 그룹 홈의 추천 섹션 '더보기'로 진입.
//  - 실데이터: GroupService.otherGroups() 로 내 그룹 제외 목록을 받아온다.
//  - 상단 서브헤더에 내 지역 + 개수, 우측에 정렬 토글(활동순/멤버순).
//  - 카드 탭 → GroupDetailScreen. 가입 성공 시 채팅방으로 이동.
// ============================================================

class GroupMoreScreen extends StatefulWidget {
  /// 이미 그룹에 소속됐는지 힌트 (상세 화면에 그대로 전달).
  final bool alreadyInGroup;

  const GroupMoreScreen({super.key, this.alreadyInGroup = false});

  @override
  State<GroupMoreScreen> createState() => _GroupMoreScreenState();
}

class _GroupMoreScreenState extends State<GroupMoreScreen> {
  List<Group> _groups = [];
  String _region = '';
  bool _loading = true;
  // 정렬 — 그룹검색과 동일하게 '박스(바텀시트)'에서 고른다.
  int _sort = 0; // 0 활동순 / 1 멤버순 / 2 최신순
  static const List<String> _sortLabels = ['활동순', '멤버순', '최신순'];
  static const List<String> _sortHints = ['오늘 활동 많은 순', '멤버 많은 순', '개설 최신순'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    List<Group> list = [];
    String region = '';
    try {
      // 그룹 홈은 5개만 보여주지만, 더보기에서는 넉넉히 가져온다.
      list = await GroupService.otherGroups(limit: 50);
      region = await GroupService.myRegion();
    } catch (e) {
      debugPrint('[그룹 더보기] 목록 로드 실패: $e');
    }
    if (!mounted) return;
    setState(() {
      _groups = list;
      _region = region;
      _loading = false;
    });
    _applySort();
  }

  // 현재 정렬 기준으로 목록을 정렬한다.
  void _applySort() {
    setState(() {
      _groups.sort((a, b) {
        switch (_sort) {
          case 1: // 멤버순
            return b.memberCount.compareTo(a.memberCount);
          case 2: // 최신순
            return b.createdAt.compareTo(a.createdAt);
          default: // 활동순 (같으면 멤버 많은 순)
            final t = b.todayActiveCount.compareTo(a.todayActiveCount);
            return t != 0 ? t : b.memberCount.compareTo(a.memberCount);
        }
      });
    });
  }

  // 정렬 바텀시트(박스) — 그룹검색과 동일한 방식.
  void _openSort() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.gray200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 10, 6),
                child: Text(
                  '정렬',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              for (int i = 0; i < _sortLabels.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _sort = i);
                    _applySort();
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 15),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.line100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _sortLabels[i],
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: _sort == i
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _sortHints[i],
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.gray350,
                          ),
                        ),
                        if (_sort == i) ...[
                          const SizedBox(width: 10),
                          const Icon(TablerIcons.check,
                              size: 20, color: AppColors.ink),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    '닫기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 추천 그룹 카드 → 상세. 가입 성공 시 채팅방 이동은 상세가 직접 처리한다(중앙화).
  Future<void> _openDetail(Group g) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(
          group: g,
          alreadyInGroup: widget.alreadyInGroup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (_region.isNotEmpty) _region,
      '${_groups.length}개',
    ].join(' · ');

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(),
            // 서브헤더: 지역·개수 + 정렬 토글
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.screenPad,
                Gap.sm,
                Gap.screenPad,
                Gap.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      style: AppType.caption.copyWith(color: AppColors.gray500),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openSort,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          TablerIcons.arrowsSort,
                          size: 16,
                          color: AppColors.gray700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _sortLabels[_sort],
                          style: AppType.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.gray700,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  : _groups.isEmpty
                      ? _empty()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.actionPrimary,
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              Gap.screenPad,
                              Gap.xs,
                              Gap.screenPad,
                              MediaQueryData.fromView(
                                    View.of(context),
                                  ).padding.bottom +
                                  24,
                            ),
                            itemCount: _groups.length,
                            separatorBuilder: (_, __) => Gap.h12,
                            itemBuilder: (_, i) => _GroupRow(
                              group: _groups[i],
                              onTap: () => _openDetail(_groups[i]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // 상단 바 — 뒤로 / 가운데 타이틀 / 검색(그룹 홈으로 위임)
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, Gap.sm, 4, 0),
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
          Expanded(
            child: Text(
              '이런 그룹 어때요?',
              textAlign: TextAlign.center,
              style: AppType.title3,
            ),
          ),
          // 검색(돋보기) 제거 — 대칭용 빈 공간
          const SizedBox(width: 44, height: 44),
        ],
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
            const Icon(TablerIcons.users, size: 40, color: AppColors.gray400),
            Gap.h12,
            Text('아직 추천할 그룹이 없어요', style: AppType.title3),
            Gap.h4,
            Text(
              '첫 번째 그룹을 만들어보세요',
              style: AppType.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 추천 그룹 카드 (라인 보더) — 그룹 홈의 카드와 같은 톤 ──
class _GroupRow extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _GroupRow({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = group.todayActiveCount > 0;
    // 활동 중이면 '지금 N명 활동 중 · 멤버 N명', 아니면 멤버·지역.
    final meta = active
        ? '지금 ${group.todayActiveCount}명 활동 중 · 멤버 ${group.memberCount}명'
        : '멤버 ${group.memberCount}명${group.region.isEmpty ? '' : ' · ${group.region}'}';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line100, width: 1.5),
        ),
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            GroupThumb(imageUrl: group.imageUrl, size: 50),
            Gap.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Gap.h4,
                  Row(
                    children: [
                      if (active) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          meta,
                          style: AppType.caption.copyWith(
                            color: AppColors.gray500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Gap.w8,
            const Icon(
              TablerIcons.chevronRight,
              size: 22,
              color: AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }
}
