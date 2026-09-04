import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:go_router/go_router.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';

/// Ploggo - 그룹 소개/가입 화면 (다른 동네 그룹 카드 → 이 화면)
/// 그룹 상세 시안(detail-othergroup) 기준: 라임 헤더 + 활동량 카드 + 주간 랭킹.
/// 미가입 상태이므로 랭킹 하단이 페이드되고 '가입하기' CTA가 고정된다.
class GroupDetailScreen extends StatefulWidget {
  final Group group;
  final bool alreadyInGroup;

  const GroupDetailScreen({
    super.key,
    required this.group,
    this.alreadyInGroup = false,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  bool? _inGroup;

  Group get group => widget.group;
  bool get alreadyInGroup => _inGroup ?? widget.alreadyInGroup;

  // ── 시안 팔레트 ──
  static const Color _lime = AppColors.lime;
  // 헤더는 라임이 아니라 페일 세이지 (header-sage 시안)
  static const Color _sageBg = Color(0xFFEAEFE3);
  static const Color _sageBlob = Color(0xFFE0E7D6);
  static const Color _titleGreen = Color(0xFF1E2418);
  static const Color _memberGreen = Color(0xFF4A5A2A);
  static const Color _charcoal = Color(0xFF3A403C);
  static const Color _faint = Color(0xFFB0B6B1);
  static const Color _track = Color(0xFFEDEFEE);
  static const Color _hairline = Color(0xFFF1F3F2);
  static const Color _rowLime = Color(0xFFF7FBE4);
  static const Color _thumbBg = Color(0xFFD9DCD4);
  static const Color _activeDot = Color(0xFF7BC000);
  static const Color _activeText = Color(0xFF5C8A00);
  static const Color _crown = Color(0xFFE9C21A);

  // ── placeholder 주간 데이터 (미가입: 라임 채움 = 1인 평균) ──
  static const double _weekKg = 18.4;
  static const double _goalKg = 25.0;
  static const double _avgKg = 0.8; // 1인 평균
  static const double _limeRatioOfGoal = 0.04; // 라임 채움 비율(미가입)
  // 미가입자는 이 그룹의 랭킹에 존재하지 않는다 → "(나)" 표기·본인 굵기 없음.
  static const List<({int rank, String name, double kg})> _ranking = [
    (rank: 1, name: '민서', kg: 5.2),
    (rank: 2, name: '지호', kg: 3.7),
    (rank: 3, name: '준호', kg: 3.1),
    (rank: 4, name: '유진', kg: 2.4),
  ];

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _resolveMembership();
  }

  Future<void> _resolveMembership() async {
    try {
      final id = await GroupService.myGroupId();
      if (!mounted) return;
      setState(() => _inGroup = id != null && id != widget.group.id);
    } catch (_) {}
  }

  // 가입하기 → 확인 팝업 → 예 → (이미 그룹 있으면) 차단 / (없으면) 가입
  Future<void> _join() async {
    final ok = await _confirmJoin();
    if (ok != true) return;
    bool blocked = alreadyInGroup;
    try {
      final mineId = await GroupService.myGroupId();
      blocked = mineId != null && mineId != group.id;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _inGroup = blocked);
    if (blocked) {
      if (mounted) {
        AppSnackBar.show(context, '이미 그룹에 가입되어 있어요');
      }
    } else {
      _doJoin();
    }
  }

  Future<void> _doJoin() async {
    try {
      if (group.id.isNotEmpty) await GroupService.joinGroup(group.id);
    } catch (e) {
      if (mounted) AppSnackBar.show(context, '가입하지 못했어요');
      return;
    }
    if (!mounted) return;
    // 진입 경로(추천·검색·더보기)와 무관하게 여기서 직접 채팅방으로 이동한다.
    // 상세·검색 등 위에 쌓인 화면을 그룹 홈까지 모두 닫은 뒤(=탭 화면 상태),
    // 채팅방을 push 한다. 이 순서가 '내 그룹 카드 → 채팅방' 동작과 동일해 안정적이다.
    final router = GoRouter.of(context);
    final gid = group.id;
    final gname = group.name;
    Navigator.of(context).popUntil((r) => r.isFirst); // 그룹 홈으로 복귀
    if (gid.isNotEmpty) {
      router.push('/group/feed', extra: {'id': gid, 'name': gname});
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.surface,
      // 가입하기 버튼도 스크롤에 포함(고정 아님).
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _weeklyCard(),
                    const SizedBox(height: 20),
                    _scheduleStatus(),
                    const SizedBox(height: 26),
                    _rankingSection(context),
                    const SizedBox(height: 22),
                    _joinButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 가입하기 CTA (스크롤 내부). 이미 다른 그룹 소속이면 탭 시 안내(_join).
  Widget _joinButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _join,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TablerIcons.plus, size: 21, color: _lime),
            SizedBox(width: 9),
            Text(
              '가입하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 라임 헤더 (미가입: 내 그룹 뱃지 없음) ──
  Widget _header(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: _sageBg),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -40,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 120, end: 0),
              duration: const Duration(milliseconds: 4000),
              curve: const Cubic(0.12, 0.72, 0.24, 1),
              builder: (context, dx, child) =>
                  Transform.translate(offset: Offset(dx, 0), child: child),
              child: Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  color: _sageBlob,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 46),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/group'),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(TablerIcons.chevronLeft,
                            size: 27, color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(TablerIcons.share2,
                          size: 24, color: AppColors.ink),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _headerThumb(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '멤버 ${group.memberCount}명',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _memberGreen,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              group.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 23,
                                height: 1.25,
                                letterSpacing: -0.8,
                                fontWeight: FontWeight.w800,
                                color: _titleGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _headerThumb() {
    final url = group.imageUrl;
    final bool hasImg = url != null && url.startsWith('http');
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 66,
        height: 80,
        child: hasImg
            ? Image.network(url, width: 66, height: 80, fit: BoxFit.cover)
            : Image.asset(
                'assets/images/ploggo_default.png',
                width: 66,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _thumbBg,
                  alignment: Alignment.center,
                  child: const Icon(TablerIcons.photo,
                      size: 22, color: Color(0xFF8E948A)),
                ),
              ),
      ),
    );
  }

  // ── 이번주 그룹 활동량 카드 (미가입: 1인 평균 레전드) ──
  Widget _weeklyCard() {
    final double totalRatio = (_weekKg / _goalKg).clamp(0.0, 1.0);
    final double memberKg = _weekKg - _avgKg;
    final int pctTarget = (totalRatio * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F191E24), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이번주 그룹 활동량',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray500)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmt(_weekKg),
                  style: const TextStyle(
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.6,
                      color: AppColors.ink)),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text('kg',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('/ ${_fmt(_goalKg)}kg',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _faint)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final double w = c.maxWidth;
              const double barTop = 30;
              return SizedBox(
                height: barTop + 20,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1900),
                  curve: const Cubic(0.22, 0.9, 0.26, 1),
                  builder: (context, v, _) {
                    final double limeW = w * _limeRatioOfGoal * v;
                    final double memberW =
                        w * (totalRatio - _limeRatioOfGoal).clamp(0.0, 1.0) * v;
                    const double gap = 0; // 라임·차콜 틈 없이 맞닿게
                    final double markerX = limeW + gap + memberW;
                    final int pct = (pctTarget * v).round();
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: barTop,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                                color: _track,
                                borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        Positioned(
                          top: barTop,
                          left: 0,
                          child: Row(
                            children: [
                              Container(
                                  width: limeW,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: _lime,
                                      // 오른쪽(차콜과 만나는 곳)은 일자
                                      borderRadius: BorderRadius.horizontal(
                                          left: Radius.circular(4)))),
                              SizedBox(width: gap),
                              Container(
                                  width: memberW,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: _charcoal,
                                      // 왼쪽 일자, 오른쪽 끝은 100% 전엔 각지게(마커 맞닿음)
                                      borderRadius: totalRatio >= 1.0
                                          ? const BorderRadius.horizontal(
                                              right: Radius.circular(4))
                                          : BorderRadius.zero)),
                            ],
                          ),
                        ),
                        if (totalRatio < 1.0)
                          Positioned(
                            top: barTop - 9,
                            left: (markerX - 1).clamp(0.0, w - 2),
                            child: Container(
                                width: 2,
                                height: 26,
                                decoration: BoxDecoration(
                                    color: _charcoal,
                                    borderRadius: BorderRadius.circular(1))),
                          ),
                        Positioned(
                          top: 0,
                          left: (markerX - 17).clamp(0.0, w - 34),
                          child: Container(
                            height: 19,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: _charcoal,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text('$pct%',
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: _lime)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _legend(_lime, '1인 평균 ${_fmt(_avgKg)}kg',
                  bold: true, color: AppColors.ink),
              const SizedBox(width: 16),
              _legend(_charcoal, '멤버 ${_fmt(memberKg)}kg',
                  bold: false, color: _charcoal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color swatch, String text,
      {required bool bold, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 선 대신 점(토글 느낌)으로 — 자리 차지 최소화
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: swatch, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: color)),
      ],
    );
  }

  // 활동 강도 라벨 → 아이콘 (산책/가볍게 뛰기/러닝)
  static IconData _intensityIcon(String intensity) {
    switch (intensity) {
      case '러닝':
        return TablerIcons.flame;
      case '가볍게 뛰기':
        return TablerIcons.run;
      case '산책':
      default:
        return TablerIcons.shoe;
    }
  }

  Widget _scheduleStatus() {
    final String intro = group.intro;
    final bool active = group.todayActiveCount > 0;
    final String intensity = group.intensity;
    final List<String> moods = group.moods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          intro.isNotEmpty ? intro : '그룹 소개가 없습니다.',
          style: TextStyle(
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color:
                  intro.isNotEmpty ? AppColors.gray700 : const Color(0xFF9BA09A)),
        ),
        const SizedBox(height: 14),
        // 활동 인원 · 활동 강도 — 세로 구분자로 나눔 (미가입자의 가입 판단 근거)
        Row(
          children: [
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: active ? _activeDot : AppColors.gray400,
                    shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(
                active
                    ? '지금 ${group.todayActiveCount}명 활동 중'
                    : '오늘 활동한 멤버가 없어요',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? _activeText : AppColors.gray500)),
            if (intensity.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                  width: 1,
                  height: 12,
                  color: const Color(0xFFDFE3E0)),
              const SizedBox(width: 12),
              Icon(_intensityIcon(intensity),
                  size: 15, color: AppColors.gray700),
              const SizedBox(width: 6),
              Text(intensity,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gray700)),
            ],
          ],
        ),
        // 분위기 태그 — 선택된 값이 있을 때만 렌더(미선택 시 행 자체 미표시)
        if (moods.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final m in moods) _moodChip(m),
            ],
          ),
        ],
      ],
    );
  }

  // 분위기 표시 칩 (읽기 전용) — 텍스트 크기에 딱 맞는 연회색 알약.
  // (alignment 를 주면 Wrap 안에서 가로 전체로 늘어난다 → padding 으로만 크기 지정)
  Widget _moodChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.gray700,
        ),
      ),
    );
  }

  Widget _rankingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 미가입 화면에는 '전체보기'가 없다(랭킹은 하단 페이드로 잘리며 가입 유도).
        const Text('주간 랭킹',
            style: TextStyle(
                fontSize: 17,
                letterSpacing: -0.3,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 12),
        // 3등까지는 선명, 4등부터는 흰색으로 흐려지며 사라진다(미가입 유도).
        for (int i = 0; i < _ranking.length; i++)
          if (_ranking[i].rank <= 3)
            _rankRow(_ranking[i].rank, _ranking[i].name, _ranking[i].kg,
                top: _ranking[i].rank == 1,
                showDivider: _ranking[i].rank != 1)
          else
            Stack(
              children: [
                _rankRow(_ranking[i].rank, _ranking[i].name, _ranking[i].kg,
                    showDivider: true),
                // 4위부터 흰 그라디언트로 흐려지며 사라짐
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x66FFFFFF),
                            Color(0xF2FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      ],
    );
  }

  Widget _rankRow(int rank, String name, double kg,
      {bool top = false, bool showDivider = false}) {
    final initial = name.isEmpty ? '?' : name.substring(0, 1);
    final double avatar = top ? 56 : 38;
    return Container(
      // 음수 margin 은 Container assert 위반(빨간 화면) → 사용하지 않는다.
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: top ? 16 : 13),
      decoration: BoxDecoration(
        color: top ? _rowLime : Colors.transparent,
        borderRadius: top ? BorderRadius.circular(18) : BorderRadius.zero,
        border: showDivider
            ? const Border(top: BorderSide(color: _hairline, width: 1))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (top) ...[
                  const Icon(TablerIcons.crownFilled, size: 17, color: _crown),
                  const SizedBox(height: 1),
                ],
                Text('$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: top ? 26 : (rank == 2 ? 16 : 15),
                        fontWeight: FontWeight.w800,
                        color: rank <= 2 ? AppColors.ink : AppColors.gray500)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: avatar,
            height: avatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: top ? _lime : _track, shape: BoxShape.circle),
            child: Text(initial,
                style: TextStyle(
                    fontSize: top ? 21 : 14,
                    fontWeight: FontWeight.w700,
                    color: top
                        ? AppColors.ink
                        : (rank == 2 ? AppColors.ink : AppColors.gray700))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontSize: top ? 20 : 15.5,
                    fontWeight: top ? FontWeight.w800 : FontWeight.w600,
                    color: AppColors.ink)),
          ),
          Text('${_fmt(kg)}kg',
              style: TextStyle(
                  fontSize: top ? 20 : 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
        ],
      ),
    );
  }

  // ── 가입 확인 팝업 (시안 §6.3) ──
  Future<bool?> _confirmJoin() {
    return showDialog<bool>(
      context: context,
      barrierColor: const Color(0x80141816),
      builder: (dctx) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: _lime, shape: BoxShape.circle),
                child: const Icon(TablerIcons.heartHandshake,
                    size: 28, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              const Text(
                // 그룹 이름을 노출하지 않고 '그룹'으로 통일
                '그룹에\n가입하시겠습니까?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 21,
                    height: 1.4,
                    letterSpacing: -0.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
              const SizedBox(height: 10),
              const Text(
                '가입하면 그룹 채팅과 주간 랭킹에\n바로 참여할 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray500),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(dctx, false),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(18)),
                        child: const Text('아니요',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.gray700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(dctx, true),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(18)),
                        child: const Text('가입하기',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
