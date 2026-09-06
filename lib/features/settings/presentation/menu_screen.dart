import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/mypage/domain/profile_detail.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/features/mypage/presentation/profile_screen.dart';
import 'package:repo_jdh/features/settings/presentation/settings_screen.dart';
import 'package:repo_jdh/features/settings/presentation/notifications_screen.dart';
import 'package:repo_jdh/features/settings/presentation/notice_screen.dart';
import 'package:repo_jdh/features/settings/presentation/faq_screen.dart';
import 'package:repo_jdh/features/settings/presentation/terms_screen.dart';
import 'package:repo_jdh/features/settings/presentation/licenses_screen.dart';
import 'package:repo_jdh/features/shop/presentation/shop_screen.dart';
import 'package:repo_jdh/features/shop/presentation/point_history_screen.dart';
import 'package:repo_jdh/features/mypage/presentation/gallery_screen.dart';
import 'package:repo_jdh/features/news/presentation/news_feed_screen.dart';

/// 메뉴 화면 (Startline 목업 구조)
/// 차콜 프로필 헤더(라임 아바타 + 포인트/수거 타일) → 포인트 샵·내역 카드 → 이용 안내 리스트.
/// 하단 네비는 ShellRoute 담당. 본문만.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  // 마지막으로 불러온 프로필을 화면 간 캐시로 보관 — 메뉴에 다시 들어올 때
  // 빈 프로필이 잠깐 떴다가 바뀌는 깜빡임을 없앤다(배경에서 최신값으로 갱신).
  static ProfileDetail? _cachedProfile;

  ProfileDetail _profile = const ProfileDetail();
  // 프로필 로드 완료 여부 — 로드 전에 '플로거' 같은 임시값을 보여주지 않기 위함.
  bool _profileLoaded = false;

  // 프로필 헤더 통계 (누적 수거량)
  String _weightText = '0.0kg';

  @override
  void initState() {
    super.initState();
    // 캐시가 있으면 즉시 표시하고(깜빡임 방지) 뒤에서 최신값으로 갱신한다.
    if (_cachedProfile != null) {
      _profile = _cachedProfile!;
      _profileLoaded = true;
    }
    _loadProfile();
    _loadStats();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await UserService.loadProfileDetail();
      _cachedProfile = p;
      if (mounted) setState(() {
        _profile = p;
        _profileLoaded = true;
      });
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final stats = await BadgeService.loadStats();
      if (!mounted) return;
      setState(() {
        _weightText = '${stats.totalWeightKg.toStringAsFixed(1)}kg';
      });
    } catch (_) {}
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    _loadProfile();
    _loadStats();
  }

  void _push(Widget screen, {bool rootNavigator = false}) => Navigator.of(
    context,
    rootNavigator: rootNavigator,
  ).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _openShop() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
    _loadProfile();
  }

  static String _comma(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomInset + 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileHeader(),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _actionCards(),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _menuList(),
            ),
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _accountActions(),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                '플로고 v1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.gray300),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 차콜 프로필 헤더 (라임 블롭 + 아바타 + 포인트/수거 타일) ──
  Widget _profileHeader() {
    final topInset = MediaQuery.of(context).padding.top;
    final joined = _profile.joinedAt;
    final levelText = joined == null
        ? '레벨 ${_profile.level}'
        : '레벨 ${_profile.level} · 가입 ${DateTime.now().difference(joined).inDays + 1}일째';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          // 우하단 라임 블롭
          Positioned(
            right: -40,
            bottom: -50,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 130, end: 0),
              duration: const Duration(milliseconds: 2600),
              curve: const Cubic(0.12, 0.72, 0.24, 1),
              builder: (context, dx, child) =>
                  Transform.translate(offset: Offset(dx, 0), child: child),
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lime.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22, topInset + 14, 22, 24),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openProfile,
                  child: Row(
                    children: [
                      _avatar(62),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // 로드 전에는 임시 이름을 보여주지 않는다(플래시 방지).
                              !_profileLoaded
                                  ? ' '
                                  : (_profile.nickname.isEmpty
                                      ? '플로거'
                                      : _profile.nickname),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              levelText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9BA29C),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        TablerIcons.chevronRight,
                        size: 22,
                        color: Color(0xFF6E7873),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _headerTile(
                        '포인트',
                        _comma(_profile.points),
                        AppColors.lime,
                        onTap: _openShop,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _headerTile(
                        '누적 수거',
                        _weightText,
                        Colors.white,
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

  Widget _headerTile(
    String label,
    String value,
    Color valueColor, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: Color(0xFF9BA29C),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(double size) {
    final url = _profile.photoUrl;
    final nick = _profile.nickname;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.lime,
        shape: BoxShape.circle,
      ),
      child: (url != null && url.isNotEmpty)
          ? Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _avatarInitial(nick, size),
            )
          : _avatarInitial(nick, size),
    );
  }

  Widget _avatarInitial(String nick, double size) {
    if (nick.isEmpty) {
      return Icon(TablerIcons.userFilled, size: size * 0.5, color: AppColors.ink);
    }
    return Text(
      nick.substring(0, 1),
      style: TextStyle(
        fontSize: size * 0.36,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    );
  }

  // ── 포인트 샵 / 포인트 내역 큰 액션 카드 ──
  Widget _actionCards() {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            icon: TablerIcons.gift,
            title: '포인트 샵',
            subtitle: '포인트로 교환',
            lime: true,
            onTap: _openShop,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionCard(
            icon: TablerIcons.receipt,
            title: '포인트 내역',
            subtitle: '적립·사용 내역',
            lime: false,
            onTap: () => _push(const PointHistoryScreen()),
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool lime,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lime ? AppColors.lime : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: AppColors.ink),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: lime ? AppColors.limeOn.withValues(alpha: 0.65) : AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 이용 안내 리스트 (아이콘 + 라벨 + 셰브론) ──
  Widget _menuList() {
    final rows = <_MenuRow>[
      _MenuRow(TablerIcons.news, '환경 뉴스',
          () => _push(const NewsFeedScreen(), rootNavigator: true)),
      _MenuRow(TablerIcons.settings, '설정',
          () => _push(const SettingsScreen())),
      _MenuRow(TablerIcons.bell, '알림',
          () => _push(const NotificationsScreen())),
      _MenuRow(TablerIcons.photo, '인증샷 모음집',
          () => _push(const GalleryScreen())),
      _MenuRow(TablerIcons.speakerphone, '공지 사항',
          () => _push(const NoticeListScreen())),
      _MenuRow(TablerIcons.helpCircle, '자주 묻는 질문',
          () => _push(const FaqScreen())),
      _MenuRow(TablerIcons.fileDescription, '이용 약관 및 정책',
          () => _push(const TermsScreen())),
      _MenuRow(TablerIcons.copyright, '오픈소스 및 출처',
          () => _push(const LicensesScreen())),
    ];
    return Column(
      children: [for (final r in rows) _menuRow(r)],
    );
  }

  Widget _menuRow(_MenuRow r) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: r.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.line100, width: 1)),
        ),
        child: Row(
          children: [
            Icon(r.icon, size: 22, color: AppColors.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                r.label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            const Icon(
              TablerIcons.chevronRight,
              size: 20,
              color: AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }

  // ── 로그아웃 / 회원 탈퇴 (밑줄 텍스트 링크) ──
  Widget _accountActions() {
    return Row(
      children: [
        GestureDetector(
          onTap: _confirmSignOut,
          child: const Text(
            '로그아웃',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.gray500,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.gray500,
            ),
          ),
        ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: _confirmDelete,
          child: const Text(
            '회원 탈퇴',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.gray400,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.gray400,
            ),
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
}

/// 이용 안내 리스트 한 행 정의
class _MenuRow {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuRow(this.icon, this.label, this.onTap);
}
