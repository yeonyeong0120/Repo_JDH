import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/mypage/domain/profile_detail.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/features/mypage/presentation/profile_screen.dart';
import 'package:repo_jdh/features/settings/presentation/notice_screen.dart';
import 'package:repo_jdh/features/settings/presentation/faq_screen.dart';
import 'package:repo_jdh/features/settings/presentation/terms_screen.dart';
import 'package:repo_jdh/features/settings/presentation/licenses_screen.dart';
import 'package:repo_jdh/features/shop/presentation/shop_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';

/// 줍다행 - 메뉴 화면 (프로필 / 알림 / 에코포인트 상점 / 약관 등)
/// 하단 네비는 ShellRoute 가 담당. 본문만.
/// 위치 권장: lib/features/settings/presentation/menu_screen.dart
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _notifications = false;

  ProfileDetail _profile = const ProfileDetail();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await UserService.loadProfileDetail();
      if (mounted) setState(() => _profile = p);
    } catch (_) {
      // 실패 시 기본값 유지
    }
  }

  // 프로필 카드 → 수정 화면 (돌아오면 갱신)
  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    _loadProfile();
  }

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
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ShopScreen()),
                      );
                      _loadProfile(); // 포인트 사용했을 수 있으니 갱신
                    },
                  ),
                  const SizedBox(height: 22),
                  _menuItem(
                    Icons.campaign_outlined,
                    '공지 사항',
                    const NoticeListScreen(),
                  ),
                  const SizedBox(height: 14),
                  _menuItem(Icons.help_outline, '자주 묻는 질문', const FaqScreen()),
                  const SizedBox(height: 14),
                  _menuItem(
                    Icons.description_outlined,
                    '이용 약관 및 정책',
                    const TermsScreen(),
                  ),
                  const SizedBox(height: 14),
                  _menuItem(
                    Icons.copyright_outlined,
                    '오픈소스 및 출처',
                    const LicensesScreen(),
                  ),
                  const SizedBox(height: 26),
                  _accountActions(),
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
    return GestureDetector(
      onTap: _openProfile,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadowStrong,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryPale,
              ),
              child: (_profile.photoUrl == null || _profile.photoUrl!.isEmpty)
                  ? const Icon(
                      Icons.pets,
                      color: AppColors.textTertiary,
                      size: 30,
                    )
                  : Image.network(
                      _profile.photoUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.pets,
                        color: AppColors.textTertiary,
                        size: 30,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _profile.nickname.isEmpty ? '플로거' : _profile.nickname,
                        style: const TextStyle(
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
                        child: Text(
                          'Lv.${_profile.level}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDeep,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${_formatPoints(_profile.points)} ',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const TextSpan(
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
                          child: LinearProgressIndicator(
                            value: _profile.levelProgress,
                            minHeight: 8,
                            backgroundColor: AppColors.divider,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${_profile.xpInLevel}/${_profile.xpNeeded}',
                        style: const TextStyle(
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
      ),
    );
  }

  // 1234 → '1,234'
  String _formatPoints(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
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
          _iconSwitch(icon: icon, value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // 아이콘이 썸(움직이는 원) 안에 들어간 커스텀 스위치.
  // OFF: 검정 썸(아이콘 흰색) / ON: 노랑 썸(아이콘 검정).
  Widget _iconSwitch({
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    const dur = Duration(milliseconds: 240); // ← 애니메이션 속도(작을수록 빠름)
    const w = 56.0, h = 32.0, thumb = 26.0;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: dur,
        curve: Curves.easeInOut,
        width: w,
        height: h,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          // 트랙: OFF 연회색 / ON 연한 크림(톤다운)
          color: value ? const Color(0xFFF7EBC9) : AppColors.divider,
          borderRadius: BorderRadius.circular(h / 2),
        ),
        child: AnimatedAlign(
          duration: dur,
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: dur,
            curve: Curves.easeInOut,
            width: thumb,
            height: thumb,
            decoration: BoxDecoration(
              // 썸: OFF 차콜 그레이 / ON 부드러운 골드 (원색 톤다운)
              color: value ? const Color(0xFFFFEA76) : const Color(0xFF4D4D4D),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 15,
              color: value ? const Color(0xFF4D4D4D) : const Color(0xFFF5F5F5),
            ),
          ),
        ),
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

  // ───────────────────────── 탈퇴 / 로그아웃 ─────────────────────────
  Widget _accountActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: _confirmDelete,
          child: const Text(
            '탈퇴하기',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ),
        Container(width: 1, height: 12, color: AppColors.divider),
        TextButton(
          onPressed: _confirmSignOut,
          child: const Text(
            '로그아웃',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut() async {
    final ok = await AppDialog.show(
      context,
      title: '로그아웃',
      message: '로그아웃 하시겠습니까?',
      cancelText: '아니오',
      confirmText: '로그아웃',
    );
    if (ok != true || !mounted) return;
    await UserService.signOut();
    if (mounted) context.go('/login');
  }

  Future<void> _confirmDelete() async {
    final ok = await AppDialog.show(
      context,
      title: '회원 탈퇴',
      message: '정말 탈퇴하시겠습니까?\n\n활동 기록과 뱃지, 포인트가 모두 사라지며 되돌릴 수 없어요.',
      cancelText: '아니오',
      confirmText: '탈퇴',
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await UserService.deleteAccount();
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, '탈퇴하지 못했어요. 다시 로그인 후 시도해주세요');
      }
      return;
    }
    if (mounted) context.go('/login');
  }

  // ───────────────────────── 하단 메뉴 항목 ─────────────────────────
  Widget _menuItem(IconData icon, String label, Widget screen) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
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