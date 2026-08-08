import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/mypage/domain/profile_detail.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/features/mypage/presentation/profile_screen.dart';
import 'package:repo_jdh/features/settings/presentation/notice_screen.dart';
import 'package:repo_jdh/features/settings/presentation/faq_screen.dart';
import 'package:repo_jdh/features/settings/presentation/terms_screen.dart';
import 'package:repo_jdh/features/settings/presentation/licenses_screen.dart';
import 'package:repo_jdh/features/shop/presentation/shop_screen.dart';
import 'package:repo_jdh/features/shop/presentation/coupon_screen.dart';
import 'package:repo_jdh/features/shop/presentation/point_history_screen.dart';

/// 메뉴 화면 — 프로필 카드 · 포인트 · 쿠폰/내역 · 이용 안내.
/// 하단 네비는 ShellRoute 담당. 본문만.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  ProfileDetail _profile = const ProfileDetail();

  // 프로필 카드 통계 (활동 횟수 · 누적 수거량 · 뱃지 수)
  int _activityCount = 0;
  String _weightText = '0kg';
  int _badgeCount = 0;

  // 알림 on/off (기본 켜짐)
  // TODO: 실제 푸시 토큰 등록/해제 및 서버 저장과 연동
  bool _alarmOn = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadStats();
  }

  Future<void> _loadProfile() async {
    try {
      final p = await UserService.loadProfileDetail();
      if (mounted) setState(() => _profile = p);
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      await BadgeService.loadEarned();
      final stats = await BadgeService.loadStats();
      if (!mounted) return;
      setState(() {
        _activityCount = stats.ploggingCount;
        _weightText = '${stats.totalWeightKg.toStringAsFixed(1)}kg';
        _badgeCount = kBadges.where((b) => BadgeRepo.isEarned(b.id)).length;
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

  void _push(Widget screen) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => screen),
  );

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _profileCard(),
              const SizedBox(height: 14),
              _pointsCard(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _smallCard(
                      icon: Icons.confirmation_number_outlined,
                      title: '내 쿠폰함',
                      subtitle: '교환한 쿠폰',
                      onTap: () => _push(const CouponScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _smallCard(
                      icon: Icons.receipt_long_outlined,
                      title: '포인트 내역',
                      subtitle: '적립·사용 기록',
                      onTap: () => _push(const PointHistoryScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const Text(
                '이용 안내',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              _infoGroup(),
              const SizedBox(height: 26),
              _accountActions(),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  '플로고 v1.0.0',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 알림 on/off 벨 — 프로필 카드 안에 위치. 카드 탭(프로필 이동)과 분리된 자체 탭.
  Widget _alarmBell() {
    final on = _alarmOn;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _alarmOn = !_alarmOn);
        AppSnackBar.show(context, _alarmOn ? '알림을 켰어요' : '알림을 껐어요');
      },
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        // 켜짐=초록 배경 / 꺼짐=회색 배경
        decoration: BoxDecoration(
          color: on ? AppColors.green100 : AppColors.neutral100,
          shape: BoxShape.circle,
        ),
        // 켜짐=초록 종 / 꺼짐=회색 종(빗금)
        child: Icon(
          on ? Icons.notifications : Icons.notifications_off,
          size: 21,
          color: on ? AppColors.textBrandOnLight : AppColors.textSecondary,
        ),
      ),
    );
  }

  // ── 프로필 카드 (레벨·XP 바 + 통계) ──
  Widget _profileCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openProfile,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: [
            Row(
              children: [
                _avatar(56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _profile.nickname.isEmpty ? '플로거' : _profile.nickname,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceBrand,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Lv.${_profile.level}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textOnTint,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: _profile.levelProgress,
                                minHeight: 7,
                                backgroundColor: AppColors.neutral200,
                                color: AppColors.actionPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${_profile.xpInLevel} XP',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                _alarmBell(),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _statBox('$_activityCount', '회', '활동'),
                const SizedBox(width: 10),
                _statBox(_weightText.replaceAll('kg', ''), 'kg', '수거'),
                const SizedBox(width: 10),
                _statBox('$_badgeCount', '개', '뱃지'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(double size) {
    final url = _profile.photoUrl;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceBrand,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: (url == null || url.isEmpty)
          ? Icon(Icons.person, size: size * 0.55,
              color: AppColors.textSecondary)
          : Image.network(url, width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.person,
                  size: size * 0.55, color: AppColors.textSecondary)),
    );
  }

  Widget _statBox(String value, String unit, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.green50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text.rich(
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: unit,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 포인트 카드 ──
  Widget _pointsCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShopScreen()),
        );
        _loadProfile();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.green100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '사용 가능한 포인트',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnTint,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      text: _comma(_profile.points),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBrandOnLight,
                      ),
                      children: const [
                        TextSpan(
                          text: ' P',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Text(
              '상점 가기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textBrandOnLight,
              ),
            ),
            const Icon(Icons.chevron_right, size: 20,
                color: AppColors.textBrandOnLight),
          ],
        ),
      ),
    );
  }

  Widget _smallCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.green50,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 20, color: AppColors.textBrandOnLight),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 이용 안내 — 한 덩어리 카드(행 사이 구분선)
  Widget _infoGroup() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          _infoRow(
            Icons.campaign_outlined,
            '공지 사항',
            onTap: () => _push(const NoticeListScreen()),
            dot: true,
            first: true,
          ),
          _infoDivider(),
          _infoRow(
            Icons.help_outline,
            '자주 묻는 질문',
            onTap: () => _push(const FaqScreen()),
          ),
          _infoDivider(),
          _infoRow(
            Icons.description_outlined,
            '이용 약관 및 정책',
            onTap: () => _push(const TermsScreen()),
          ),
          _infoDivider(),
          _infoRow(
            Icons.copyright_outlined,
            '오픈소스 및 출처',
            onTap: () => _push(const LicensesScreen()),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _infoDivider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 18),
    child: Divider(height: 1, thickness: 0.8, color: AppColors.border),
  );

  Widget _infoRow(
    IconData icon,
    String label, {
    required VoidCallback onTap,
    bool dot = false,
    bool first = false,
    bool last = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        // 위/아래 끝 행만 모서리를 카드에 맞춰 라운드 처리
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: first ? const Radius.circular(18) : Radius.zero,
            bottom: last ? const Radius.circular(18) : Radius.zero,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 21, color: AppColors.textSecondary),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (dot)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            const Icon(Icons.chevron_right, size: 20,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _accountActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: _confirmDelete,
          child: const Text(
            '회원 탈퇴',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Container(width: 1, height: 12, color: AppColors.border),
        TextButton(
          onPressed: _confirmSignOut,
          child: const Text(
            '로그아웃',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
