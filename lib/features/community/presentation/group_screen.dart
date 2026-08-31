
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:go_router/go_router.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/core/widgets/app_card.dart';
import 'package:repo_jdh/core/widgets/app_section.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:repo_jdh/core/dev/dev_seed.dart'; // ⚠️ 개발용 — 배포 전 이 줄과 버튼 삭제
import 'group_detail_screen.dart';
import 'group_search_screen.dart';
import 'group_create_screen.dart';

// ============================================================
// 그룹 (v2)
//  - 홈과 같은 어휘: 틴트 헤더 + 밝은 배경 + 흰 라운드 카드
//  - 내 그룹은 '들어가기', 다른 그룹은 '오늘 활동'을 앞세운다
//  - 오늘 활동 인원이 많은 그룹이 위로 (참여 유도)
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
  // 헤더 문구는 새로고침할 때마다 5개 중 하나가 무작위로 뽑힌다.

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
    } catch (_) {
      // 네트워크/로그인 문제 → 빈 목록으로 표시
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

  /// 동네 전체에서 오늘 활동한 인원 (내 그룹 포함)
  int get _todayTotal =>
      (_myGroup?.todayActiveCount ?? 0) +
      _others.fold<int>(0, (a, g) => a + g.todayActiveCount);

  // ⚠️ 개발용 더미 — 아직 실제로 활동한 사람이 없을 때도 프로필 미리보기를
  // 보여주기 위한 값. 실데이터 연동되면 이 상수와 아래 사용처를 삭제한다.
  static const int _demoTodayTotal = 7;
  int get _todayTotalOrDemo => _todayTotal > 0 ? _todayTotal : _demoTodayTotal;

  // ⚠️ 개발용 — 가짜 그룹 심기/지우기 (배포 전 삭제)
  Future<void> _runSeed({required bool seed}) async {
    try {
      final n = seed ? await DevSeed.seedGroups() : await DevSeed.clearGroups();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${seed ? "심기" : "삭제"} $n건 완료')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('실패: $e')));
    }
  }

  Future<void> _openSearch() async {
    final joined = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupSearchScreen(alreadyInGroup: _myGroup != null),
      ),
    );
    if (!mounted) return;
    await _load();
    // 검색→상세에서 가입했다면 그룹 홈을 백스택에 두고 채팅방으로 이동
    if (joined == true && mounted && _myGroup != null) {
      context.push('/group/feed',
          extra: {'id': _myGroup!.id, 'name': _myGroup!.name});
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              todayTotal: _todayTotalOrDemo, // ⚠️ 개발용 더미 포함
              region: _myGroup?.region ?? '',
              loading: _loading,
              onSearch: _openSearch,
              onCreate: _openCreate,
              onSeed: () => _runSeed(seed: true),
              onClear: () => _runSeed(seed: false),
            ),
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
                        // 바텀 내비는 extendBody 로 본문 위에 떠 있어 이 여백으로만
                        // 피한다. Gap.navSafe(96) 고정만으로는 제스처 내비 기기에서
                        // 모자라 마지막 카드가 잘린다.
                        // ⚠️ MediaQuery.of(context).padding.bottom 을 쓰면 안 된다 —
                        // Scaffold(extendBody: true) 가 body 의 padding.bottom 을
                        // 내비 높이로 덮어써서 여백이 이중으로 잡힌다.
                        // 원시 시스템 inset 을 직접 읽는다 (홈·뱃지 탭과 동일한 식).
                        padding: EdgeInsets.fromLTRB(
                          Gap.screenPad,
                          Gap.xl,
                          Gap.screenPad,
                          MediaQueryData.fromView(
                                View.of(context),
                              ).padding.bottom +
                              92,
                        ),
                        children: [
                          AppSection(
                            title: '내 그룹',
                            child: _myGroup == null
                                ? _NoGroupCard(onSearch: _openSearch)
                                : _MyGroupCard(
                                    group: _myGroup!,
                                    onTap: () async {
                                      // 피드에서 탈퇴하고 돌아오면 즉시 반영되도록 재로드
                                      await context.push(
                                        '/group/feed',
                                        extra: {
                                          'id': _myGroup!.id,
                                          'name': _myGroup!.name,
                                        },
                                      );
                                      if (mounted) _load();
                                    },
                                  ),
                          ),
                          AppSection(
                            title: '이런 그룹 어때요?',
                            caption: _others.isEmpty ? null : '최근 활동순 정렬',
                            captionInline: true,
                            last: true,
                            child: _others.isEmpty
                                ? _EmptyCard(
                                    icon: TablerIcons.users,
                                    title: '아직 다른 그룹이 없어요',
                                    body: '첫 번째 그룹을 만들어보세요',
                                  )
                                : Column(
                                    children: [
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
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(Group g) async {
    final joined = await Navigator.push<bool>(
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
    // 가입 직후엔 그룹 홈(여기)을 백스택에 두고 채팅방으로 이동
    // → 채팅방에서 뒤로가기 시 그룹 홈으로 나온다.
    if (joined == true) {
      context.push('/group/feed', extra: {'id': g.id, 'name': g.name});
    }
  }
}

// ── 헤더 ────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int todayTotal;
  final String region;
  final bool loading;
  final VoidCallback onSearch;
  final VoidCallback onCreate;
  final VoidCallback onSeed;
  final VoidCallback onClear;

  const _Header({
    required this.todayTotal,
    required this.region,
    required this.loading,
    required this.onSearch,
    required this.onCreate,
    required this.onSeed,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    // 로딩 중에는 0명이라고 단정하지 않는다.
    final subtitle = loading
        ? '동네 활동을 불러오는 중이에요'
        : (todayTotal > 0
            ? '현재 $todayTotal명이 활동중이에요'
            : '지금 나가면 오늘의 1등이에요');

    // 초록 워시는 홈처럼 위→아래로 차오르고(HeaderWashPour), 안쪽 글자는 떠오른다.
    return HeaderWashPour(
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        Gap.screenPad,
        Gap.lg, // 검색·만들기 버튼이 너무 위에 붙지 않게 아래로
        Gap.screenPad,
        Gap.xl4, // 워시가 아바타 줄 아래까지 내려오도록 헤더를 키운다
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 위치줄 — 위치 좌표/버튼 모두 애니메이션 제외(정적).
          Row(
            children: [
              const Icon(
                TablerIcons.mapPinFilled,
                size: 15,
                color: AppColors.neutral500,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  region.isEmpty ? '위치 좌표가 불명확합니다' : region,
                  style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral500,
                  ),
                ),
              ),
              _IconButton(icon: TablerIcons.search, onTap: onSearch),
              Gap.w8,
              _IconButton(icon: TablerIcons.plus, onTap: onCreate),
              // ⚠️ 개발용 임시 버튼 — 배포 전 이 두 개와 dev_seed import 삭제
              Gap.w8,
              _IconButton(icon: TablerIcons.flask, onTap: onSeed, dev: true),
              Gap.w8,
              _IconButton(icon: TablerIcons.trash, onTap: onClear, dev: true),
            ],
          ),
          Gap.h16,
          Row(
            // 프로필을 제목 두 줄 사이 높이에 맞춘다(윗쪽 정렬 + 소폭 내림).
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목·서브텍스트만 떠오름/커짐 애니메이션 (프로필은 제외)
              Expanded(
                child: HeaderRise(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('같이 주우면\n두 배로 재밌어요', style: AppType.title1),
                      Gap.h8,
                      Text(
                        subtitle,
                        style: AppType.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 프로필 나열 — 애니메이션 적용 안 함. 제목 두 줄 사이 높이로 올림.
              if (!loading && todayTotal > 0) ...[
                Gap.w12,
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _TodayFaces(count: todayTotal),
                ),
              ],
            ],
          ),
        ],
      ),
      ),
    );
  }
}

/// 오늘 우리 동에서 활동한 사람들의 프로필. 최대 3명 겹쳐 보이고, 나머지는 +N.
class _TodayFaces extends StatelessWidget {
  final int count;
  const _TodayFaces({required this.count});

  static const double _d = 46; // 원 지름(조금 더 크게)
  static const double _overlap = 30; // 겹쳐 놓을 때 다음 원까지의 간격
  static const List<Color> _tones = [
    AppColors.green500,
    AppColors.dataDistance,
    AppColors.dataCan,
  ];

  @override
  Widget build(BuildContext context) {
    final int faces = count < 3 ? count : 3;
    final int extra = count - faces;
    final int circles = faces + (extra > 0 ? 1 : 0);
    final double width = _d + (circles - 1) * _overlap;
    return SizedBox(
      width: width,
      height: _d,
      child: Stack(
        children: [
          for (int i = 0; i < faces; i++)
            Positioned(
              left: i * _overlap,
              child: _face(_tones[i % _tones.length]),
            ),
          // 나머지 인원 — 마지막 원에 '+N' (단위는 넣지 않는다: 두 자리부터 넘침)
          if (extra > 0)
            Positioned(
              left: faces * _overlap,
              child: Container(
                width: _d,
                height: _d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _face(Color tone) {
    return Container(
      width: _d,
      height: _d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.tint(tone, 0.30),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: Icon(TablerIcons.userFilled, size: 25,  color: tone),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dev;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.dev = false,
  });

  @override
  Widget build(BuildContext context) {
    // 배경색 헤더 위 40px 판 · 흰 배경 · 라운드 13 · 잉크 없음.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          size: 21,
          color: dev ? AppColors.neutral400 : AppColors.textBrandOnLight,
        ),
      ),
    );
  }
}

// ── 내 그룹 ──────────────────────────────────────────────

class _MyGroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _MyGroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = group.todayActiveCount > 0;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _GroupThumb(group: group, size: 64),
              Gap.w16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: AppType.title2),
                    Gap.h4,
                    Text(
                      '${group.region} · 멤버 ${group.memberCount}명',
                      style: AppType.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h16,
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.md,
            ),
            decoration: BoxDecoration(
              color: active ? AppColors.surfaceBrand : AppColors.neutral75,
              borderRadius: Radii.innerR,
            ),
            child: Row(
              children: [
                Icon(
                  active ? TablerIcons.walk : TablerIcons.clock,
                  size: 20,
                  color: active
                      ? AppColors.textBrandOnLight
                      : AppColors.neutral500,
                ),
                Gap.w8,
                Expanded(
                  child: Text(
                    active
                        ? '오늘 ${group.todayActiveCount}명이 활동했어요'
                        : '오늘 활동한 멤버가 없어요',
                    style: AppType.label.copyWith(
                      color: active
                          ? AppColors.textOnTint
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '피드 보기',
                  style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBrandOnLight,
                  ),
                ),
                const Icon(
                  TablerIcons.chevronRight,
                  size: 20,
                  color: AppColors.textBrandOnLight,
                ),
              ],
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
    return AppCard(
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
                  color: AppColors.green100,
                  borderRadius: Radii.tileR,
                ),
                child: const Icon(
                  TablerIcons.userPlus,
                  size: 26,
                  color: AppColors.textBrandOnLight,
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

// ── 다른 동네 그룹 ───────────────────────────────────────

class _OtherGroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _OtherGroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = group.todayActiveCount > 0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        children: [
          _GroupThumb(group: group, size: 56),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: AppType.title3),
                Gap.h4,
                Text(
                  group.region,
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Gap.h8,
                Row(
                  children: [
                    if (active) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.actionPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      active
                          ? '오늘 ${group.todayActiveCount}명 활동 중'
                          : '멤버 ${group.memberCount}명',
                      style: AppType.caption.copyWith(
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active
                            ? AppColors.textBrand
                            : AppColors.textSecondary,
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
            size: Touch.icon,
            color: AppColors.neutral400,
          ),
        ],
      ),
    );
  }
}

class _GroupThumb extends StatelessWidget {
  final Group group;
  final double size;
  const _GroupThumb({required this.group, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: Radii.tileR,
      ),
      clipBehavior: Clip.antiAlias,
      child: group.imageUrl == null
          ? Icon(TablerIcons.users, size: size * 0.42, color: AppColors.neutral400)
          : Image.network(group.imageUrl!, fit: BoxFit.cover),
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
    return AppCard(
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.neutral400),
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
