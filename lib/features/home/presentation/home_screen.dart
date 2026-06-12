import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 줍다행 - 홈 탭 화면 (본문만)
/// 하단 네비 / '시작' 버튼은 app_router.dart 의 ShellRoute(_ScaffoldWithBottomNav)가
/// 공통으로 담당하므로 여기엔 넣지 않습니다.
/// 위치: lib/features/home/presentation/home_screen.dart
///
/// ※ 아이콘 패키지 필요: flutter pub add material_symbols_icons
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
    return Scaffold(
      backgroundColor: AppColors.appBG,
      // bottomNavigationBar 없음 — ShellRoute 가 처리
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 28),
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
            _buildNeighborhood(),
          ],
        ),
      ),
    );
  }

  // ───────── 곡선 파란 헤더 + 현재활동 카드 (헤더가 카드 중간까지 내려옴) ─────────
  Widget _buildHeaderWithCard() {
    return Stack(
      children: [
        // 배경: 아래가 곡선인 파란 헤더 (현재활동 카드 중간까지)
        ClipPath(
          clipper: _BottomCurveClipper(),
          child: Container(
            height: 330,
            width: double.infinity,
            color: AppColors.primaryPale,
          ),
        ),
        // 앞쪽: 제목 + 주간 스트립 + 현재활동 카드
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
                    const Text(
                      '줍다행',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _days.map(_dayCell).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
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
        ? AppColors.error
        : (d.today ? AppColors.textPrimary : AppColors.textTertiary);
    final sproutColor = d.active ? AppColors.primary : AppColors.primaryLight;
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
          Icon(Symbols.potted_plant, size: 26, weight: 400, color: sproutColor),
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
                      TextSpan(text: '\n현재 활동'),
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
          // 현재 레벨 박스 (회색 + 그림자)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F2F4),
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
                Row(
                  children: [
                    const Text(
                      '이번주 플로깅 활동',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerRight,
                        fit: BoxFit.scaleDown,
                        child: Row(
                          children: [
                            _stat(Symbols.directions_walk, '2000 보'),
                            const SizedBox(width: 14),
                            _stat(Symbols.delete, '1.3 kg'),
                            const SizedBox(width: 14),
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
        Icon(icon, size: 16, weight: 300, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
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
          Expanded(child: _streakCard()),
          const SizedBox(width: 14),
          Expanded(child: _tipCard()),
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
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '5일 연속\n',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: '줍다행 중!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '나의 기록을\n확인해볼까요?',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          // TODO: 줍댕이(물개) 캐릭터 이미지로 교체 (assets/images/jupdaengi.png)
          const Align(
            alignment: Alignment.centerRight,
            child: Text('🦭', style: TextStyle(fontSize: 44)),
          ),
        ],
      ),
    );
  }

  Widget _tipCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 뉴스 썸네일 (종이 뉴스 아이콘)
          // TODO: 실제 기사 썸네일 이미지로 교체
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 54,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryPale,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Symbols.newspaper,
                size: 22,
                weight: 300,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '페트병 라벨,\n이렇게 떼세요!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '올바른 분리배출 꿀팁 알아보기',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.primaryPale,
                child: Icon(
                  Symbols.person,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              SizedBox(width: 6),
              Text(
                '고냐니 기자',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              Spacer(),
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

  // ───────────────────────── 우리동네는 지금 ─────────────────────────
  Widget _buildNeighborhood() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '우리동네는 지금',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            // TODO: 실제 동네 활동 사진으로 교체 (Image.network 등)
            itemBuilder: (_, i) => Container(
              width: 130,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.primaryPale,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.cardShadow,
              ),
              child: const Icon(
                Symbols.image,
                color: AppColors.textTertiary,
                size: 32,
              ),
            ),
          ),
        ),
      ],
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
