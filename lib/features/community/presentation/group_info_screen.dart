import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:go_router/go_router.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'group_ranking_screen.dart';

/// 그룹 상세 정보 (멤버용) — 채팅방 상단 ⓘ 아이콘으로 진입.
/// 라임 헤더 + 이번주 그룹 활동량 카드 + 주간 랭킹.
///
/// 그룹장(ownerUid == 내 uid)이면 헤더에 「그룹장」 뱃지 + 연필 아이콘이 뜨고,
/// 연필을 누르면 '그룹 정보 수정' 바텀 시트가 열린다(GROUP_EDIT_SHEET).
/// 일반 멤버는 「내 그룹」 뱃지만 보이고 연필은 렌더하지 않는다.
///
/// 색·좌표·문자열은 그룹 상세 시안(detail-mygroup) 기준. 새 색을 추가하지 않는다.
/// 이번주 활동량·기여·랭킹은 아직 서버 집계 소스가 없어 placeholder 값이다.
class GroupInfoScreen extends StatefulWidget {
  final Group? group;
  final String groupName;
  final int memberCount;
  final int todayActiveCount;

  const GroupInfoScreen({
    super.key,
    required this.group,
    required this.groupName,
    this.memberCount = 0,
    this.todayActiveCount = 0,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  // ── 편집 가능한 로컬 상태 (저장 시 Firestore 반영) ──
  late String _name;
  late String _intro;
  late String _intensity;
  late Set<String> _moods;
  late int _goalKg;
  late bool _isPublic;
  String? _imageUrl;

  /// 그룹장 여부 — 멤버 문서의 role('owner')로 판정한다(권위 소스).
  /// 첫 프레임 깜빡임을 줄이려 ownerUid 비교로 초기값을 잡고, 곧바로 role로 보정한다.
  bool _isLeader = false;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _name = g?.name ?? widget.groupName;
    _intro = g?.intro ?? '';
    _intensity = g?.intensity ?? '산책';
    _moods = {...?g?.moods};
    _goalKg = g?.goalKg ?? 25;
    _isPublic = g?.isPublic ?? true;
    _imageUrl = g?.imageUrl;

    // 초기 힌트: 개설자 uid == 내 uid
    final owner = g?.ownerUid;
    final me = FirebaseAuth.instance.currentUser?.uid;
    _isLeader = owner != null && owner.isNotEmpty && owner == me;
    _resolveLeader();
  }

  /// 멤버 role로 그룹장 여부를 확정한다. 가입한 일반 멤버는 절대 그룹장이 아니다.
  Future<void> _resolveLeader() async {
    final id = widget.group?.id;
    if (id == null || id.isEmpty) return;
    try {
      final leader = await GroupService.isLeaderOf(id);
      if (mounted && leader != _isLeader) setState(() => _isLeader = leader);
    } catch (_) {
      // 조회 실패 시 초기 힌트 유지
    }
  }

  // ── 시안 팔레트 (이 화면 전용 색) ──
  static const Color _lime = AppColors.lime; // #E9FF6A 라임
  // 헤더는 라임이 아니라 페일 세이지 (header-sage 시안)
  static const Color _sageBg = Color(0xFFEAEFE3); // 헤더 배경
  static const Color _sageBlob = Color(0xFFE0E7D6); // 헤더 장식 블롭
  static const Color _titleGreen = Color(0xFF1E2418); // 헤더 위 제목
  static const Color _memberGreen = Color(0xFF4A5A2A); // 헤더 위 보조
  static const Color _charcoal = Color(0xFF3A403C); // 멤버 채움·마커·칩
  static const Color _faint = Color(0xFFB0B6B1); // / 25kg
  static const Color _track = Color(0xFFEDEFEE); // 트랙·2위 이하 아바타
  static const Color _hairline = Color(0xFFF1F3F2); // 랭킹 구분선
  static const Color _rowLime = Color(0xFFF7FBE4); // 1위 로우 배경
  static const Color _thumbBg = Color(0xFFD9DCD4); // 썸네일 미업로드 면
  static const Color _activeDot = Color(0xFF7BC000); // 활동 중 점
  static const Color _activeText = Color(0xFF5C8A00); // 활동 중 글자
  static const Color _crown = Color(0xFFE9C21A); // 1위 왕관

  // ── placeholder 주간 데이터 (실제 수거량은 고정, 목표량만 편집 반영) ──
  static const double _weekKg = 18.4;
  static const double _myKg = 3.7; // 내 기여
  static const List<({int rank, String name, double kg, bool me})> _ranking = [
    (rank: 1, name: '민서', kg: 5.2, me: false),
    (rank: 2, name: '지호 (나)', kg: 3.7, me: true),
    (rank: 3, name: '준호', kg: 3.1, me: false),
    (rank: 4, name: '유진', kg: 2.4, me: false),
  ];

  // 0.0 자리 생략 포맷 (25.0 → 25, 28.2 → 28.2)
  static String _fmt(double v) {
    return v == v.roundToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            // 카드가 라임 헤더 위로 28px 겹치도록 끌어올린다.
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  24 + MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _weeklyCard(),
                    const SizedBox(height: 20),
                    _scheduleStatus(),
                    const SizedBox(height: 26),
                    _rankingSection(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 라임 헤더 + 아주 옅은 잉크 블롭 ──
  Widget _header(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: _sageBg),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // 장식 블롭 — 세이지보다 살짝 진한 세이지
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
          // 상태바(노치) 아래로 안전하게 — 라임 배경은 뒤로 꽉 채우되 내용은 SafeArea 안.
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 뒤로가기 + (그룹장이면 연필) + 공유 — 맨아이콘, 잉크
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 그룹장만 연필 아이콘 (공유 왼쪽, 박스 없는 맨아이콘)
                          if (_isLeader)
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _openEditSheet,
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(TablerIcons.pencil,
                                    size: 21, color: AppColors.ink),
                              ),
                            ),
                          const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(TablerIcons.share2,
                                size: 21, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // 썸네일 + (뱃지·멤버수 / 그룹명)
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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 3),
                                    // 세이지 헤더 위에서는 라임 뱃지가 포인트로 튄다.
                                    decoration: BoxDecoration(
                                      color: AppColors.lime,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    // 그룹장/멤버 모두 같은 스펙, 문자열만 다름
                                    child: Text(
                                      _isLeader ? '그룹장' : '내 그룹',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.limeOn,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    '멤버 ${widget.memberCount}명',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _memberGreen,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                _name,
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
    final url = _imageUrl;
    final bool hasImg = url != null && url.startsWith('http');
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 66,
        height: 80,
        child: hasImg
            ? Image.network(url, width: 66, height: 80, fit: BoxFit.cover)
            // 기본 썸네일(마스코트) — 이미지 없으면 회색 면 + 사진 아이콘
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

  // ── 이번주 그룹 활동량 카드 (흰 카드 + 그림자, 보더 없음) ──
  Widget _weeklyCard() {
    final double goal = _goalKg.toDouble();
    // 실제 수거량(_weekKg)은 고정, 목표량 편집에 따라 비율·퍼센트가 재계산된다.
    final double ratio = _weekKg / goal; // 100% 초과 가능
    final double totalRatio = ratio.clamp(0.0, 1.0);
    final int pctTarget = (ratio * 100).round();
    final bool over = ratio >= 1.0; // 목표 초과 상태
    final double memberKg = _weekKg - _myKg;
    // 라임 채움(내 기여) 비율 = 내 수거량 / 목표량
    final double myRatioOfGoal = (_myKg / goal).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F191E24), // rgba(25,30,36,.12)
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번주 그룹 활동량',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 10),
          // 18.4 kg / 25kg — 하단 정렬 한 줄 (초과면 '목표 초과 Nkg' 라임 배지)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmt(_weekKg),
                style: const TextStyle(
                  fontSize: 38,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.6,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: over
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _lime,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '목표 초과 ${_fmt(_weekKg - goal)}kg',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.limeOn,
                          ),
                        ),
                      )
                    : Text(
                        '/ ${_fmt(goal)}kg',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _faint,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 프로그레스 바 + 퍼센트 칩
          LayoutBuilder(
            builder: (context, c) {
              final double w = c.maxWidth;
              const double barTop = 30; // 칩(-30)이 뜨는 공간
              return SizedBox(
                height: barTop + 20,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1900),
                  curve: const Cubic(0.22, 0.9, 0.26, 1),
                  builder: (context, v, _) {
                    final double limeW = w * myRatioOfGoal * v;
                    final double memberW =
                        w * (totalRatio - myRatioOfGoal).clamp(0.0, 1.0) * v;
                    // 라임과 차콜은 틈 없이 맞닿게(일자)
                    const double gap = 0;
                    final double markerX = (limeW + gap + memberW);
                    final int pct = (pctTarget * v).round();
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 트랙
                        Positioned(
                          top: barTop,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: _track,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        // 채움: 라임 + gap + 차콜
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
                                  // 왼쪽만 둥글게, 차콜과 만나는 오른쪽은 일자
                                  borderRadius: BorderRadius.horizontal(
                                      left: Radius.circular(4)),
                                ),
                              ),
                              SizedBox(width: gap),
                              Container(
                                width: memberW,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _charcoal,
                                  // 라임과 만나는 왼쪽은 일자, 오른쪽 끝은 100% 전엔 각지게
                                  // (세로 마커와 빈틈없이 맞닿음)
                                  borderRadius: over
                                      ? const BorderRadius.horizontal(
                                          right: Radius.circular(4))
                                      : BorderRadius.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 세로 마커 (달성/초과 아니면 표시)
                        if (!over)
                          Positioned(
                            top: barTop - 9,
                            left: (markerX - 1).clamp(0.0, w - 2),
                            child: Container(
                              width: 2,
                              height: 26,
                              decoration: BoxDecoration(
                                color: _charcoal,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        // 퍼센트 칩
                        Positioned(
                          top: 0,
                          left: (markerX - 17).clamp(0.0, w - 34),
                          child: Container(
                            height: 19,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _charcoal,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$pct%',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _lime,
                              ),
                            ),
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
          // 레전드
          Row(
            children: [
              _legend(_lime, '내 기여 ${_fmt(_myKg)}kg',
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
          decoration: BoxDecoration(
            color: swatch,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
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

  // ── 소개 + 활동 인원·강도 + 분위기 키워드 ──
  Widget _scheduleStatus() {
    final String intro = _intro;
    final bool active = widget.todayActiveCount > 0;
    final String intensity = _intensity;
    final List<String> moods = _moods.toList();
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
                intro.isNotEmpty ? AppColors.gray700 : const Color(0xFF9BA09A),
          ),
        ),
        const SizedBox(height: 14),
        // 활동 인원 · 활동 강도 (세로 구분자로 나눔)
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? _activeDot : AppColors.gray400,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              active
                  ? '지금 ${widget.todayActiveCount}명 활동 중'
                  : '오늘 활동한 멤버가 없어요',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? _activeText : AppColors.gray500,
              ),
            ),
            if (intensity.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(width: 1, height: 12, color: const Color(0xFFDFE3E0)),
              const SizedBox(width: 12),
              Icon(_intensityIcon(intensity),
                  size: 15, color: AppColors.gray700),
              const SizedBox(width: 6),
              Text(
                intensity,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray700,
                ),
              ),
            ],
          ],
        ),
        // 분위기 키워드 — 알약 칩으로 나열 (선택된 값이 있을 때만)
        if (moods.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [for (final m in moods) _moodTag(m)],
          ),
        ],
      ],
    );
  }

  // 분위기 표시 칩(읽기 전용) — 텍스트 크기에 딱 맞는 연회색 알약.
  // (alignment 를 주면 Wrap 안에서 가로 전체로 늘어나므로 padding 으로만 크기를 잡는다)
  Widget _moodTag(String label) {
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

  // ── 주간 랭킹 ──
  Widget _rankingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Expanded(
              child: Text(
                '주간 랭킹',
                style: TextStyle(
                  fontSize: 17,
                  letterSpacing: -0.3,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupRankingScreen(groupName: _name),
                ),
              ),
              child: const Text(
                '전체보기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < _ranking.length; i++)
          _rankRow(
            _ranking[i].rank,
            _ranking[i].name,
            _ranking[i].kg,
            top: _ranking[i].rank == 1,
            me: _ranking[i].me,
            showDivider: _ranking[i].rank != 1,
          ),
      ],
    );
  }

  Widget _rankRow(int rank, String name, double kg,
      {bool top = false, bool me = false, bool showDivider = false}) {
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
          // 순위(+왕관)
          SizedBox(
            width: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (top) ...[
                  const Icon(TablerIcons.crownFilled, size: 17, color: _crown),
                  const SizedBox(height: 1),
                ],
                Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: top ? 26 : (rank == 2 ? 16 : 15),
                    fontWeight: FontWeight.w800,
                    color: rank <= 2 ? AppColors.ink : AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // 아바타
          Container(
            width: avatar,
            height: avatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: top ? _lime : _track,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: top ? 21 : 14,
                fontWeight: FontWeight.w700,
                color: top
                    ? AppColors.ink
                    : (rank == 2 ? AppColors.ink : AppColors.gray700),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // 이름
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: top ? 20 : 15.5,
                // 본인(나) 로우는 순위와 무관하게 800
                fontWeight: (top || me) ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          // 수치
          Text(
            '${_fmt(kg)}kg',
            style: TextStyle(
              fontSize: top ? 20 : 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── 그룹 정보 수정 시트 ───────────────────────────

  /// 연필 아이콘 → '그룹 정보 수정' 바텀 시트 (그룹장 전용).
  /// POPUPS 형태 B. 슬라이드 애니메이션 없이 즉시 나타난다(딤 탭으로 닫힘).
  Future<void> _openEditSheet() async {
    final result = await showGeneralDialog<_GroupEditResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '닫기',
      barrierColor: const Color(0x80141816), // rgba(20,24,22,.5)
      transitionDuration: const Duration(milliseconds: 280),
      // 아래에서 위로 미끄러져 올라오는 바텀 시트 애니메이션
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: const Cubic(0.2, 0.8, 0.2, 1),
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      pageBuilder: (_, __, ___) => _GroupEditSheet(
        groupId: widget.group?.id,
        memberCount: widget.memberCount,
        initialName: _name,
        initialIntro: _intro,
        initialIntensity: _intensity,
        initialMoods: _moods,
        initialGoalKg: _goalKg,
        initialPublic: _isPublic,
        initialImageUrl: _imageUrl,
      ),
    );
    if (result == null || !mounted) return;
    // 저장된 값으로 로컬 상태 갱신 → 헤더·활동량 카드가 즉시 재계산된다.
    setState(() {
      _name = result.name;
      _intro = result.intro;
      _intensity = result.intensity;
      _moods = result.moods;
      _goalKg = result.goalKg;
      _isPublic = result.isPublic;
      _imageUrl = result.imageUrl;
    });
    _showSavedToast();
  }

  /// 저장 완료 토스트 — 하단 34px, 잉크 배경 + 라임 체크. 2.6초 후 사라짐.
  void _showSavedToast() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 20,
        right: 20,
        bottom: 34 + MediaQuery.of(ctx).padding.bottom,
        child: const _SavedToast(),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 2600), () {
      entry.remove();
    });
  }
}

/// 저장 결과 — 시트가 저장 후 부모에 돌려주는 값 묶음.
class _GroupEditResult {
  final String name;
  final String intro;
  final String intensity;
  final Set<String> moods;
  final int goalKg;
  final bool isPublic;
  final String? imageUrl;
  const _GroupEditResult({
    required this.name,
    required this.intro,
    required this.intensity,
    required this.moods,
    required this.goalKg,
    required this.isPublic,
    required this.imageUrl,
  });
}

/// 저장 완료 토스트 위젯 (짧게 나타났다 사라짐).
class _SavedToast extends StatelessWidget {
  const _SavedToast();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x47191E24), // rgba(25,30,36,.28)
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TablerIcons.check, size: 19, color: AppColors.lime),
            SizedBox(width: 10),
            Text(
              '그룹 정보를 수정했어요',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// '그룹 정보 수정' 바텀 시트 본문 (그룹장 전용).
/// 임시 편집 상태를 자체적으로 들고 있다가 '저장하기'에서 Firestore에 반영하고
/// _GroupEditResult 를 반환한다. 딤 탭으로 닫으면 저장하지 않는다.
class _GroupEditSheet extends StatefulWidget {
  final String? groupId;
  final int memberCount;
  final String initialName;
  final String initialIntro;
  final String initialIntensity;
  final Set<String> initialMoods;
  final int initialGoalKg;
  final bool initialPublic;
  final String? initialImageUrl;

  const _GroupEditSheet({
    required this.groupId,
    required this.memberCount,
    required this.initialName,
    required this.initialIntro,
    required this.initialIntensity,
    required this.initialMoods,
    required this.initialGoalKg,
    required this.initialPublic,
    required this.initialImageUrl,
  });

  @override
  State<_GroupEditSheet> createState() => _GroupEditSheetState();
}

class _GroupEditSheetState extends State<_GroupEditSheet> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _introCtl;
  late String _intensity;
  late Set<String> _moods;
  late int _goalKg;
  late bool _isPublic;
  String? _imageUrl; // 기존/업로드 완료된 URL
  XFile? _newPhoto; // 새로 고른 사진(저장 시 업로드)
  bool _saving = false;

  static const Color _muted = Color(0xFF8A8F8B);
  static const List<({IconData icon, String label})> _intensities = [
    (icon: TablerIcons.shoe, label: '산책'),
    (icon: TablerIcons.run, label: '가볍게 뛰기'),
    (icon: TablerIcons.flame, label: '러닝'),
  ];
  static const List<String> _moodOptions = [
    '조용히 각자',
    '수다 환영',
    '인증샷 많이',
    '가족·아이 동반',
    '반려견 동반',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.initialName);
    _introCtl = TextEditingController(text: widget.initialIntro);
    _intensity = widget.initialIntensity;
    _moods = {...widget.initialMoods};
    _goalKg = widget.initialGoalKg;
    _isPublic = widget.initialPublic;
    _imageUrl = widget.initialImageUrl;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _introCtl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file != null && mounted) setState(() => _newPhoto = file);
    } catch (_) {
      // 사진 선택 실패는 무시 — 기존 썸네일 유지
    }
  }

  void _goalDown() => setState(() => _goalKg = (_goalKg - 5).clamp(5, 60));
  void _goalUp() => setState(() => _goalKg = (_goalKg + 5).clamp(5, 60));

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return; // 이름은 비울 수 없다(필수)
    setState(() => _saving = true);
    try {
      // 새 사진을 골랐으면 먼저 업로드해 URL 확보
      String? imageUrl = _imageUrl;
      if (_newPhoto != null) {
        final uploaded = await GroupService.uploadGroupPhoto(_newPhoto!);
        if (uploaded != null) imageUrl = uploaded;
      }
      final gid = widget.groupId;
      if (gid != null) {
        await GroupService.updateGroup(
          groupId: gid,
          name: name,
          intro: _introCtl.text.trim(),
          imageUrl: imageUrl,
          intensity: _intensity,
          moods: _moods.toList(),
          goalKg: _goalKg,
          isPublic: _isPublic,
        );
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        _GroupEditResult(
          name: name,
          intro: _introCtl.text.trim(),
          intensity: _intensity,
          moods: {..._moods},
          goalKg: _goalKg,
          isPublic: _isPublic,
          imageUrl: imageUrl,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    // 시트 최대 높이 — 상단 여백(노치+40)만큼 남기고 화면을 넘지 않게 제한.
    // (스크롤 뷰가 무한 높이를 받지 않도록 반드시 상한을 준다)
    final double maxSheetHeight =
        media.size.height - media.padding.top - 40 - bottomInset;
    return Padding(
      padding: EdgeInsets.only(left: 10, right: 10, bottom: 10 + bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxSheetHeight > 240 ? maxSheetHeight : 240,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              // 필드가 많아 작은 화면에서 넘칠 수 있으니 스크롤 처리.
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // (상단 회색 핸들 제거 — 밑에서 올라오는 애니메이션으로 시트임을 알림)
                    const SizedBox(height: 4),
                    // 타이틀 행
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '그룹 정보 수정',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: AppColors.ink,
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.pop(context),
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(TablerIcons.x, size: 21, color: _muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // 썸네일 + 그룹 이름 — 이름 블록을 썸네일과 세로 중앙 정렬.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _thumb(),
                        const SizedBox(width: 14),
                        Expanded(child: _nameField()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _introField(),
                    const SizedBox(height: 12),
                    _intensitySection(),
                    const SizedBox(height: 12),
                    _moodSection(),
                    const SizedBox(height: 12),
                    _goalSection(),
                    const SizedBox(height: 12),
                    _publicToggle(),
                    const SizedBox(height: 14),
                    _saveButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 라벨 — 너무 작다는 피드백 반영해 키움(12→13.5).
  Widget _microLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: _muted,
      ),
    );
  }

  // 60px 썸네일 + 카메라 배지
  Widget _thumb() {
    final url = _imageUrl;
    final bool hasImg = url != null && url.startsWith('http');
    Widget inner;
    if (_newPhoto != null) {
      inner = Image.file(File(_newPhoto!.path),
          width: 60, height: 60, fit: BoxFit.cover);
    } else if (hasImg) {
      inner = Image.network(url, width: 60, height: 60, fit: BoxFit.cover);
    } else {
      inner = Container(
        color: const Color(0xFFD9DCD4),
        alignment: Alignment.center,
        child: const Icon(TablerIcons.photo, size: 22, color: Color(0xFF8E948A)),
      );
    }
    return GestureDetector(
      onTap: _pickPhoto,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(width: 60, height: 60, child: inner),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                // 활동 강도 미선택 카드처럼 연회색 면 + 진회색 아이콘
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(TablerIcons.camera,
                    size: 12, color: AppColors.gray700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 그룹 이름 — 밑줄 2px 잉크 + 우측 카운터
  Widget _nameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _microLabel('그룹 이름'),
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.ink, width: 2),
            ),
          ),
          // 입력 텍스트와 밑줄 간격 축소
          padding: const EdgeInsets.only(top: 5, bottom: 2),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtl,
                  maxLength: 20,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    hintText: '그룹 이름',
                    hintStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gray300,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_nameCtl.text.characters.length}/20',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFA8ADA9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 한 줄 소개 — 밑줄 1.5px 회색
  Widget _introField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _microLabel('한 줄 소개'),
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE3E6E4), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: TextField(
            controller: _introCtl,
            maxLength: 200,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              hintText: '비워두면 \'그룹 소개가 없습니다.\'로 표시돼요',
              hintStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.gray300,
              ),
            ),
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  // 활동 강도 — 3택 카드 (필수)
  Widget _intensitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _microLabel('활동 강도'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 0; i < _intensities.length; i++) ...[
              Expanded(child: _intensityCard(_intensities[i])),
              if (i < _intensities.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _intensityCard(({IconData icon, String label}) item) {
    final selected = _intensity == item.label;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _intensity = item.label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : const Color(0xFFF4F6F5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(
              item.icon,
              size: 19,
              color: selected ? AppColors.lime : AppColors.gray700,
            ),
            const SizedBox(height: 5),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? Colors.white : AppColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 분위기 — 복수 선택 칩 (선택 사항)
  Widget _moodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            _microLabel('분위기'),
            const SizedBox(width: 7),
            const Text(
              '선택',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gray400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final m in _moodOptions) _moodChip(m),
          ],
        ),
      ],
    );
  }

  Widget _moodChip(String label) {
    final selected = _moods.contains(label);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (selected) {
          _moods.remove(label);
        } else {
          _moods.add(label);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : const Color(0xFFF4F6F5),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.gray700,
          ),
        ),
      ),
    );
  }

  // 주간 목표량 — 스테퍼 + 게이지 + 환산 힌트
  Widget _goalSection() {
    // 게이지 채움 = (goalKg - 5) / 55
    final double fill = ((_goalKg - 5) / 55).clamp(0.0, 1.0);
    final int members = widget.memberCount > 0 ? widget.memberCount : 1;
    final String perHead = (_goalKg / members).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _microLabel('주간 목표량'),
            Text(
              '${_goalKg}kg',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _stepBtn(TablerIcons.minus, _goalDown),
            const SizedBox(width: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  return Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEFEE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        height: 8,
                        width: c.maxWidth * fill,
                        decoration: BoxDecoration(
                          color: AppColors.lime,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            _stepBtn(TablerIcons.plus, _goalUp),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          '멤버 $members명 기준 1인당 주 ${perHead}kg',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: _muted,
          ),
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 18, color: AppColors.ink),
      ),
    );
  }

  // 공개 설정 토글
  Widget _publicToggle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _isPublic = !_isPublic),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              _isPublic ? TablerIcons.lockOpen : TablerIcons.lock,
              size: 21,
              color: AppColors.ink,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isPublic ? '누구나 가입 가능' : '승인 후 가입',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isPublic
                        ? '승인 없이 바로 가입할 수 있어요'
                        : '그룹장이 수락해야 가입되어요',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
            _switch(_isPublic),
          ],
        ),
      ),
    );
  }

  Widget _switch(bool on) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      width: 48,
      height: 29,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? AppColors.ink : const Color(0xFFDDE1DE),
        borderRadius: BorderRadius.circular(15),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 23,
        height: 23,
        decoration: BoxDecoration(
          color: on ? AppColors.lime : Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // 저장하기 CTA (흐름 마지막, 하단 고정 아님)
  Widget _saveButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _saving ? null : _save,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _saving ? AppColors.gray400 : AppColors.ink,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _saving ? '저장 중...' : '저장하기',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
