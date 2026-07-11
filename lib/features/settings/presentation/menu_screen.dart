import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 줍다행 - 메뉴 화면 (프로필 / 다크모드 / 알림 / 에코포인트 상점 / 약관 등)
/// 하단 네비는 ShellRoute 가 담당. 본문만.
/// 위치 권장: lib/features/settings/presentation/menu_screen.dart
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _darkMode = false;
  bool _notifications = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SingleChildScrollView(
        // 하단 네비바 클리어런스(바 높이 63+12+혹13+여유)
        padding: EdgeInsets.only(
          bottom: MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
        ),
        child: Column(
          children: [
            // 홈처럼 곡선 파스텔 헤더 + 프로필 카드가 곡선 중간까지 걸침
            _buildHeaderWithProfile(),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _toggleCard(
                    icon: Icons.lightbulb_outline,
                    title: '다크모드',
                    value: _darkMode,
                    onChanged: (v) => setState(() => _darkMode = v),
                    // TODO: 테마 프로바이더에 연결해서 실제 다크모드 적용
                  ),
                  const SizedBox(height: 14),
                  _toggleCard(
                    icon: Icons.notifications_none,
                    title: '실시간 알림 설정',
                    value: _notifications,
                    onChanged: (v) => setState(() => _notifications = v),
                    // TODO: 알림 권한/설정에 연결
                  ),
                  const SizedBox(height: 14),
                  _linkCard(
                    title: '에코포인트 상점',
                    big: true,
                    onTap: () {
                      // TODO: 에코포인트 상점(reward) 화면으로 이동
                    },
                  ),
                  const SizedBox(height: 22),
                  _menuItem(Icons.campaign_outlined, '공지 사항'),
                  const SizedBox(height: 14),
                  _menuItem(Icons.help_outline, '자주 묻는 질문'),
                  const SizedBox(height: 14),
                  _menuItem(Icons.description_outlined, '이용 약관 및 정책'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── 곡선 헤더 + 프로필 카드 (홈 스타일) ───────────────────
  Widget _buildHeaderWithProfile() {
    return Stack(
      children: [
        // 아래가 곡선인 파스텔 헤더 — 프로필 카드 중간쯤까지 내려옴
        ClipPath(
          clipper: _MenuCurveClipper(),
          child: Container(
            // height ↑ = 곡선이 더 아래로(카드 더 많이 덮음) / ↓ = 위로
            height: 168,
            width: double.infinity,
            color: AppColors.primaryPale,
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            // 위 여백 키워서 카드/컨텐츠 전체를 아래로 (숫자 ↑ = 더 내려감)
            padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
            child: _profileCard(),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── 프로필 카드 ─────────────────────────
  Widget _profileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadowStrong,
      ),
      child: Row(
        children: [
          // TODO: 실제 프로필 이미지로 교체
          Container(
            width: 56,
            height: 56,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryPale,
            ),
            child: const Icon(
              Icons.pets,
              color: AppColors.textTertiary,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '가나디',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPale,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Lv.11',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '2,900 ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: 'P',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mintDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const LinearProgressIndicator(
                          value: 0.8,
                          minHeight: 8,
                          backgroundColor: AppColors.divider,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '80/100',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
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

  // ───────────────────────── 토글 카드 ─────────────────────────
  Widget _toggleCard({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? '켜짐' : '꺼짐',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, size: 20, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 에코포인트 상점(큰 링크 카드) ─────────────────────────
  Widget _linkCard({
    required String title,
    required VoidCallback onTap,
    bool big = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: big ? 22 : 18),
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 하단 메뉴 항목 ─────────────────────────
  Widget _menuItem(IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        // TODO: 각 항목 화면으로 이동 (공지/FAQ/약관)
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 헤더 아래쪽 곡선 클리퍼 (가운데가 살짝 더 내려오는 둥근 곡선 — 홈과 동일)
class _MenuCurveClipper extends CustomClipper<Path> {
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
