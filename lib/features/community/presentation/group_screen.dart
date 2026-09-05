
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:go_router/go_router.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/core/widgets/group_thumb.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'group_detail_screen.dart';
import 'group_search_screen.dart';
import 'group_create_screen.dart';
import 'group_more_screen.dart';

// ============================================================
// 그룹 (Startline)
//  - 흰 배경 + 상단 타이틀 "그룹" + 검색/만들기 아이콘 버튼
//  - 내 그룹 = 차콜 카드(라임 블롭) → 탭하면 채팅, info 아이콘 → 상세
//  - "이런 그룹 어때요?" = 라인 보더 추천 카드 목록 → 상세
// ============================================================

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  Group? _myGroup;
  List<Group> _others = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    Group? mine;
    List<Group> others = [];
    try {
      mine = await GroupService.myGroup();
      others = await GroupService.otherGroups(limit: 5); // 그룹탭: 최대 5개
    } catch (e) {
      // 네트워크/로그인 문제, 혹은 region 필터 복합 색인 누락(FAILED_PRECONDITION) 등
      // → 화면은 빈 목록으로 조용히 넘어가되, 원인은 로그로 남긴다.
      debugPrint('[그룹] 목록 로드 실패: $e');
    }
    if (!mounted) return;
    // 오늘 활동 많은 순 (같으면 멤버 많은 순)
    others.sort((a, b) {
      final t = b.todayActiveCount.compareTo(a.todayActiveCount);
      return t != 0 ? t : b.memberCount.compareTo(a.memberCount);
    });
    setState(() {
      _myGroup = mine;
      _others = others;
      _loading = false;
    });
  }

  Future<void> _openSearch() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupSearchScreen(alreadyInGroup: _myGroup != null),
      ),
    );
    if (!mounted) return;
    // 채팅방 이동은 GroupDetailScreen 이 가입 성공 시 직접 처리한다(중앙화).
    // 여기서는 목록만 새로고침한다.
    await _load();
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupCreateScreen(alreadyInGroup: _myGroup != null),
      ),
    );
    _load();
  }

  // 내 그룹 카드 탭 → 채팅방(피드)
  Future<void> _openMyChat() async {
    final g = _myGroup;
    if (g == null) return;
    // 피드에서 탈퇴하고 돌아오면 즉시 반영되도록 재로드
    await context.push('/group/feed', extra: {'id': g.id, 'name': g.name});
    if (mounted) _load();
  }

  // 내 그룹 카드의 info 아이콘 → 상세(차콜 헤더)
  Future<void> _openMyDetail() async {
    final g = _myGroup;
    if (g == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(group: g, alreadyInGroup: true),
      ),
    );
    if (mounted) _load();
  }

  // 추천 섹션 '더보기' → 전체 추천 목록 화면
  Future<void> _openMore() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupMoreScreen(alreadyInGroup: _myGroup != null),
      ),
    );
    if (mounted) _load();
  }

  // 추천 그룹 카드 → 상세. 가입 시 채팅방 이동은 상세가 직접 처리한다(중앙화).
  Future<void> _openDetail(Group g) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupDetailScreen(
          group: g,
          alreadyInGroup: _myGroup != null,
        ),
      ),
    );
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface, // 목업 그룹 화면: 흰 배경
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _titleBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.progress,
                        strokeWidth: 2,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.actionPrimary,
                      child: ListView(
                        // 바텀 내비는 extendBody 로 본문 위에 떠 있어 이 여백으로만 피한다.
                        // ⚠️ MediaQuery.padding.bottom 을 쓰면 안 된다 — extendBody 가
                        // 내비 높이로 덮어써 이중 여백이 잡힌다. 원시 시스템 inset 을 직접 읽는다.
                        padding: EdgeInsets.fromLTRB(
                          Gap.screenPad,
                          Gap.lg,
                          Gap.screenPad,
                          MediaQueryData.fromView(
                                View.of(context),
                              ).padding.bottom +
                              92,
                        ),
                        children: [
                          // ── 내 그룹 (차콜 카드) 또는 미가입 안내 ──
                          if (_myGroup == null)
                            _NoGroupCard(onSearch: _openSearch)
                          else
                            _MyGroupCard(
                              group: _myGroup!,
                              onTap: _openMyChat,
                            ),
                          Gap.h24,
                          // ── 이런 그룹 어때요? (헤더 + 더보기) ──
                          Row(
                            children: [
                              Expanded(
                                child: Text('이런 그룹 어때요?',
                                    style: AppType.title3),
                              ),
                              // 더보기 → 추천 그룹 전체 목록 화면
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _openMore,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '더보기',
                                      style: AppType.caption.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      TablerIcons.chevronRight,
                                      size: 16,
                                      color: AppColors.gray400,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Gap.h12,
                          if (_others.isEmpty)
                            _EmptyCard(
                              icon: TablerIcons.users,
                              title: '아직 다른 그룹이 없어요',
                              body: '첫 번째 그룹을 만들어보세요',
                            )
                          else
                            for (final g in _others) ...[
                              _OtherGroupCard(
                                group: g,
                                onTap: () => _openDetail(g),
                              ),
                              if (g != _others.last) Gap.h12,
                            ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 상단 타이틀 바 (그룹 + 검색/만들기) ──
  Widget _titleBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.screenPad, Gap.xl, Gap.screenPad, Gap.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '그룹',
              style: AppType.title1.copyWith(letterSpacing: -0.8),
            ),
          ),
          _SquareIconButton(icon: TablerIcons.search, onTap: _openSearch),
          Gap.w8,
          // 만들기: 라임 면 + 잉크 글리프 (유일 액센트)
          _SquareIconButton(
            icon: TablerIcons.plus,
            onTap: _openCreate,
            filled: true,
          ),
        ],
      ),
    );
  }
}

// ── 상단 아이콘 버튼 (만들기=라임 액션 면 유지, 그 외 네비 아이콘=글리프만) ──
class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// true면 라임 액션 면(만들기 CTA), false면 컨테이너 없는 헤더 네비 아이콘.
  final bool filled;

  const _SquareIconButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    // 만들기(+)는 액션 버튼이므로 라임 면을 유지한다.
    if (filled) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: Radii.tileR,
          ),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      );
    }
    // 헤더 네비/보조 아이콘 — 컨테이너 없이 글리프만, 44×44 탭 영역.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 22, color: AppColors.ink),
      ),
    );
  }
}

// ── 내 그룹 (차콜 카드 + 라임 블롭) ──────────────────────────
class _MyGroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap; // 카드 전체 → 채팅
  const _MyGroupCard({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = group.todayActiveCount > 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(26),
        ),
        clipBehavior: Clip.antiAlias,
        // 패딩을 Container 가 아니라 내용(Column)에만 준다 → 블롭은 카드 모서리
        // 기준으로 배치돼 라운드 끝까지 채워진다(가장자리에서 잘리는 느낌 제거).
        child: Stack(
          children: [
            // 올리브 블롭 (우상단) — 컨테이너 모서리 기준. 밝은 올리브 + 크기 축소.
            Positioned(
              right: -34,
              top: -38,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 130, end: 0),
                duration: const Duration(milliseconds: 2400),
                curve: const Cubic(0.12, 0.72, 0.24, 1),
                builder: (context, dx, child) =>
                    Transform.translate(offset: Offset(dx, 0), child: child),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    color: Color(0xFF515C42), // 잉크 위 밝은 올리브
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // 상단 줄: '내 그룹' 라벨 + 활동 인디케이터 (info 아이콘 없음)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '내 그룹',
                        style: AppType.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                          color: AppColors.gray400,
                        ),
                      ),
                    ),
                    if (active) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.lime,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${group.todayActiveCount}명 활동 중',
                        style: AppType.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.lime,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              // TODO: 실제 이번주 그룹 수거량 집계로 교체(현재 placeholder)
                              const Text(
                                '18.4',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.9,
                                  color: AppColors.lime,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'kg',
                                style: AppType.caption.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.lime,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '이번주 그룹 수거량',
                            style: AppType.caption.copyWith(
                              color: AppColors.gray400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _DarkFaces(count: group.memberCount),
                  ],
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

/// 차콜 카드 위 멤버 아바타(최대 3 겹침 + "+N" 칩, 잉크 보더).
/// 스크린샷: 첫 아바타만 라임 포인트, 나머지는 다크 칩, 초과 인원은 +N.
class _DarkFaces extends StatelessWidget {
  final int count;
  const _DarkFaces({required this.count});

  static const double _d = 34;
  static const double _overlap = 24;

  @override
  Widget build(BuildContext context) {
    final int shown = count < 3 ? (count < 1 ? 1 : count) : 3;
    final int extra = count - shown;
    final int chips = shown + (extra > 0 ? 1 : 0);
    final double width = _d + (chips - 1) * _overlap;
    return SizedBox(
      width: width,
      height: _d,
      child: Stack(
        children: [
          for (int i = 0; i < shown; i++)
            Positioned(
              left: i * _overlap,
              child: Container(
                width: _d,
                height: _d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // 첫 아바타만 라임, 나머지는 다크 칩
                  color: i == 0 ? AppColors.lime : AppColors.darkChip,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: Icon(
                  TablerIcons.userFilled,
                  size: 17,
                  color: i == 0 ? AppColors.limeOn : AppColors.gray400,
                ),
              ),
            ),
          // 초과 인원 "+N" 칩
          if (extra > 0)
            Positioned(
              left: shown * _overlap,
              child: Container(
                width: _d,
                height: _d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.darkChip,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gray300,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 그룹 미가입 — 빈 상자 대신 다음 행동을 준다.
class _NoGroupCard extends StatelessWidget {
  final VoidCallback onSearch;
  const _NoGroupCard({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line100, width: 1.5),
      ),
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  TablerIcons.userPlus,
                  size: 26,
                  color: AppColors.ink,
                ),
              ),
              Gap.w16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('아직 가입한 그룹이 없어요', style: AppType.title3),
                    Gap.h4,
                    Text(
                      '이웃과 함께 걷고 기록을 나눠보세요',
                      style: AppType.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h16,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSearch,
              child: const Text('그룹 찾아보기'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 추천 그룹 카드 (라인 보더) ───────────────────────────────
class _OtherGroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _OtherGroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = group.todayActiveCount > 0;
    // 부제 통일(SEARCH_PACE_FILTER §5): 항상 '강도 · 멤버 N명' (활동 여부는 앞 점으로만).
    final meta = '${group.intensity} · 멤버 ${group.memberCount}명';

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

// ── 빈 상태 ─────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line100, width: 1.5),
      ),
      padding: const EdgeInsets.all(Gap.xl),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.gray400),
          Gap.h12,
          Text(title, style: AppType.title3, textAlign: TextAlign.center),
          Gap.h4,
          Text(
            body,
            style: AppType.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
