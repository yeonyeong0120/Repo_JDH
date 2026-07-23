import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/providers/shared_group_provider.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/features/news/presentation/news_feed_screen.dart';
import 'package:repo_jdh/features/mypage/presentation/my_impact_screen.dart';
import 'package:repo_jdh/features/community/presentation/group_detail_screen.dart';

/// 줍다행 - 홈 탭 화면 (본문만)
/// 하단 네비 / '시작' 버튼은 app_router.dart 의 ShellRoute(_ScaffoldWithBottomNav)가
/// 공통으로 담당하므로 여기엔 넣지 않습니다.
/// 위치: lib/features/home/presentation/home_screen.dart
///
/// ※ 아이콘 패키지 필요: flutter pub add material_symbols_icons
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  OverlayEntry? _popupEntry;
  Timer? _popupTimer;

  @override
  void initState() {
    super.initState();
    // 홈 진입 시점에 이미 공유 신호가 있으면 (정산 → 홈 이동 케이스)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final g = ref.read(sharedGroupProvider.notifier).consume();
      if (g != null) _showAutoShare(g);
    });
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    _popupEntry?.remove();
    super.dispose();
  }

  // AUTO-02 공유 완료 팝업 (하단 카드, 4초 후 자동 사라짐)
  void _showAutoShare(String groupName) {
    _dismissPopup(); // 기존 팝업 있으면 정리
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 16,
        right: 16,
        bottom: 20 + MediaQuery.of(ctx).padding.bottom,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.cardBG,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: groupName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                      const TextSpan(
                        text: '에 공유되었어요',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '닫기',
                        onTap: _dismissPopup,
                        type: AppButtonType.secondary,
                        expand: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: '그룹으로 보러가기',
                        type: AppButtonType.primary,
                        expand: false,
                        onTap: () {
                          _dismissPopup();
                          // TODO: 방금 올린 내 활동 카드로 자동 스크롤
                          context.push('/group/feed', extra: groupName);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    _popupEntry = entry;
    _popupTimer = Timer(const Duration(seconds: 4), _dismissPopup);
  }

  void _dismissPopup() {
    _popupTimer?.cancel();
    _popupTimer = null;
    _popupEntry?.remove();
    _popupEntry = null;
  }

  // 주간 활동 스트립 (날짜 / 활동함 / 오늘 / 빨강표시)
  static const List<_Day> _days = [
    _Day(4, active: true, danger: true),
    _Day(5, active: true),
    _Day(6),
    _Day(7),
    _Day(8, active: true, today: true),
    _Day(9),
    _Day(10, active: true),
  ];

  @override
  Widget build(BuildContext context) {
    // 홈이 이미 떠 있는 상태에서 공유가 발생한 경우
    ref.listen<String?>(sharedGroupProvider, (prev, next) {
      if (next != null) {
        final g = ref.read(sharedGroupProvider.notifier).consume();
        if (g != null) _showAutoShare(g);
      }
    });
    return Scaffold(
      backgroundColor: AppColors.appBG,
      // bottomNavigationBar 없음 — ShellRoute 가 처리
      body: SingleChildScrollView(
        // 마지막 컨텐츠가 바에 안 가리게: 실제 시스템바 인셋 + 바 높이(63+12+혹13+여유)
        padding: EdgeInsets.only(
          bottom: MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderWithCard(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildTwoCards(),
            ),
            const SizedBox(height: 26),
            _buildNeighborhood(context),
          ],
        ),
      ),
    );
  }

  // ───────── 곡선 헤더 + 현재활동 카드 (헤더가 카드 중간까지 내려옴) ─────────
  Widget _buildHeaderWithCard() {
    return Stack(
      children: [
        // 배경: 아래가 곡선인 헤더 (현재활동 카드 중간까지)
        ClipPath(
          clipper: _BottomCurveClipper(),
          child: Container(
            height: 310, // 내용 살짝 올린 만큼 곡선도(330→285→290→316→310)
            width: double.infinity,
            color: AppColors.primaryPale,
          ),
        ),
        // 앞쪽: 인사 + 주간 스트립 + 현재활동 카드
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _days.map(_dayCell).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildActivityCard(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayCell(_Day d) {
    final numberColor = d.danger
        ? const Color.fromARGB(255, 243, 111, 102)
        : const Color.fromARGB(255, 49, 49, 49);
    final sproutColor = d.active
        ? AppColors.primary
        : const Color.fromARGB(255, 151, 151, 151);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: d.today
          ? BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${d.date}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: numberColor,
            ),
          ),
          const SizedBox(height: 6),
          // 새싹 화분 (potted_plant: 이것만 weight 400)
          Icon(Symbols.potted_plant, size: 26, weight: 500, color: sproutColor),
        ],
      ),
    );
  }

  // ───────────────────────── 현재 활동 카드 ─────────────────────────
  Widget _buildActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                    children: [
                      TextSpan(text: '김연영'),
                      TextSpan(
                        text: ' 님의',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      TextSpan(
                        text: '\n현재 활동',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 프로필 아이콘 (크게)
              // TODO: 실제 사용자 프로필 이미지로 교체
              Container(
                width: 74,
                height: 74,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPale,
                ),
                child: const Icon(
                  Symbols.person,
                  color: AppColors.textTertiary,
                  size: 46,
                  weight: 300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 현재 레벨 박스 (소프트 그린 + 그림자)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryPale,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      '현재 레벨 11',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '(다음 레벨까지 20 XP)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '80',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                          TextSpan(
                            text: '/100',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const LinearProgressIndicator(
                    value: 0.8, // 80 / 100
                    minHeight: 8,
                    backgroundColor: AppColors.cardBG,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                // 라벨을 윗줄로 빼고 스탯을 아랫줄 전체 폭으로 → 글자 안 쪼그라들고 커짐
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이번주 플로깅 활동',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            _stat(Symbols.steps, '2000 보'),
                            const SizedBox(width: 18),
                            _stat(Symbols.delete, '1.3 kg'),
                            const SizedBox(width: 18),
                            _stat(Symbols.local_fire_department, '3012 kcal'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, weight: 300, color: const Color(0xFF777777)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── 가운데 두 카드 ─────────────────────────
  Widget _buildTwoCards() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Builder(
              builder: (context) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyImpactScreen()),
                ),
                child: _streakCard(),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Builder(
              builder: (context) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewsFeedScreen()),
                ),
                child: _tipCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _streakCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '5일 연속',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '플로깅 중',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 8),
              // TODO: 줍댕이(물개) 캐릭터 이미지로 교체
              Text('🦭', style: TextStyle(fontSize: 40)),
            ],
          ),
          // 이 값으로 "대단해요!"를 팁 카드 "올바른..." 높이에 맞춤 (미세조정)
          const SizedBox(height: 20),
          const Text(
            '대단해요! 꾸준함이 지구를 바꾸는 중이에요',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Spacer(), // CTA를 바닥으로 → 고냐니 기자와 수평
          Row(
            children: const [
              Expanded(
                child: Text(
                  '변화 확인하기',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Symbols.chevron_right,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tipCard() {
    // 설계서 NEWS-01 기준 — 홈 카드는 최신 기사 1개를 보여준다
    final latest = NewsFeedScreen.articles.first;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 뉴스 썸네일 (종이 뉴스 아이콘)
          Align(
            alignment: Alignment.centerRight,
            child: const Text(
              '📰',
              style: TextStyle(fontSize: 32),
            ), // 44 → 32 축소
          ),
          const SizedBox(height: 10),
          Text(
            latest.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            latest.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          const Spacer(), // 바이라인을 카드 바닥으로 → 스트릭 CTA와 수평
          Row(
            children: [
              const CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.primaryPale,
                child: Icon(
                  Symbols.person,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  latest.reporter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Icon(
                Symbols.chevron_right,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 지금 우리 동네는 (HOME-03) ─────────────────────────
  Widget _buildNeighborhood(BuildContext context) {
    // 우리 지역 · 최근 7일 활동 · 내 그룹 제외 · 최신순
    // TODO: 실제 동네 그룹 데이터로 교체 (placeholder)
    const groups = ['00동 모여랏', '한강 같이 걸어요', '주말 플로깅 크루', '활동 가치해윱'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '지금 우리 동네는',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 174,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _neighborCard(context, groups[i]),
          ),
        ),
      ],
    );
  }

  Widget _neighborCard(BuildContext context, String name) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 내가 안 속한 동네 그룹 → 소개/가입 화면 (검색 결과와 동일)
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(
            name: name,
            region: '00구 00동', // TODO: 실제 그룹 지역
            meta: '00명 · 오늘 활동 인원 0명', // TODO: 실제 인원 데이터
            // TODO: 실제 "내 그룹 소속 여부"로 교체
            alreadyInGroup: false,
          ),
        ),
      ),
      child: Container(
        width: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 봉투 인증샷 (그 그룹의 가장 최근 사진)
            // TODO: 실제 사진(Image.network)으로 교체
            Container(
              height: 110,
              width: double.infinity,
              color: AppColors.primaryPale,
              alignment: Alignment.center,
              child: const Icon(
                Symbols.image,
                color: AppColors.textTertiary,
                size: 30,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Row(
                children: [
                  // 그룹 대표 이미지 (작은 아이콘)
                  // TODO: 실제 그룹 대표 이미지로 교체
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryPale,
                    ),
                    child: const Icon(
                      Symbols.groups,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
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

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.cardBG,
    borderRadius: BorderRadius.circular(20),
    boxShadow: AppColors.cardShadow,
  );
}

/// 헤더 아래쪽 곡선 클리퍼 (가운데가 살짝 더 내려오는 둥근 곡선)
class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, size.height - 36);
    p.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 36,
    );
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// 주간 스트립 1칸 데이터
class _Day {
  final int date;
  final bool active; // 그날 활동 여부(새싹 진하게)
  final bool today; // 오늘(회색 박스 강조)
  final bool danger; // 빨간 숫자
  const _Day(
    this.date, {
    this.active = false,
    this.today = false,
    this.danger = false,
  });
}
