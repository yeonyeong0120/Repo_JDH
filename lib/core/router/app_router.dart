import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:material_symbols_icons/symbols.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:repo_jdh/core/router/placeholder_screen.dart';
import 'package:repo_jdh/core/providers/auth_provider.dart';
import 'package:repo_jdh/features/auth/presentation/login_screen.dart';
// ✚ 추가: 닉네임 화면 + 프로필 프로바이더
import 'package:repo_jdh/features/auth/presentation/nickname_setup_screen.dart';
import 'package:repo_jdh/features/auth/data/user_profile_provider.dart';
import 'package:repo_jdh/features/vision/presentation/camera_screen.dart';
import 'package:repo_jdh/features/plogging/presentation/plogging_home_screen.dart';
import 'package:repo_jdh/features/home/presentation/home_screen.dart'
    as home_feature;
import 'package:repo_jdh/features/community/presentation/group_screen.dart';
import 'package:repo_jdh/features/mypage/presentation/activity_screen.dart';
import 'package:repo_jdh/features/settings/presentation/menu_screen.dart';
import 'package:repo_jdh/features/plogging/presentation/settlement_screen.dart';
import 'package:repo_jdh/features/community/presentation/group_feed_screen.dart';
import 'package:repo_jdh/features/plogging/presentation/plogging_session_screen.dart';

part 'app_router.g.dart';

class AppRoutes {
  static const login = '/login';
  static const nicknameSetup = '/nickname-setup';
  static const home = '/home';
  static const group = '/group';
  static const mypage = '/mypage';
  static const settings = '/settings';
  static const ploggingRoute = '/plogging/route';
  static const ploggingTracking = '/plogging/tracking';
  static const visionCamera = '/vision/camera';
  static const visionResult = '/vision/result';
  static const reward = '/reward';
  static const news = '/news';
  static const ploggingSettlement = '/plogging/settlement';
  static const groupFeed = '/group/feed';
}

final isLoggedInProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(data: (user) => user != null, orElse: () => false);
});

@riverpod
GoRouter appRouter(Ref ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  final profileAsync = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,

    redirect: (context, state) {
      return null;
      final loggingIn = state.matchedLocation == AppRoutes.login;
      final settingNickname = state.matchedLocation == AppRoutes.nicknameSetup;

      // 로그인 체크
      if (!isLoggedIn) {
        return loggingIn ? null : AppRoutes.login;
      }
      if (loggingIn) return AppRoutes.home;

      // 닉네임 체크
      return profileAsync.maybeWhen(
        data: (profile) {
          final needsNickname =
              profile == null || profile.nickname.trim().isEmpty;
          if (needsNickname && !settingNickname) {
            return AppRoutes.nicknameSetup;
          }
          if (!needsNickname && settingNickname) {
            return AppRoutes.home;
          }
          return null;
        },
        orElse: () => null,
      );
    },

    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.nicknameSetup,
        builder: (context, state) => const NicknameSetupScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return _ScaffoldWithBottomNav(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const home_feature.HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.group,
            builder: (context, state) => const GroupScreen(),
          ),
          GoRoute(
            path: AppRoutes.mypage,
            builder: (context, state) => const ActivityScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const MenuScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.ploggingRoute,
        builder: (context, state) => const PloggingSessionScreen(),
      ),
      GoRoute(
        path: AppRoutes.ploggingTracking,
        builder: (context, state) => const PloggingHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.visionCamera,
        builder: (context, state) => const CameraDetectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.ploggingSettlement,
        builder: (context, state) => const SettlementScreen(),
      ),
      GoRoute(
        path: AppRoutes.groupFeed,
        builder: (context, state) {
          final name = state.extra as String?;
          return GroupFeedScreen(groupName: name ?? '그룹');
        },
      ),
      GoRoute(
        path: AppRoutes.visionResult,
        builder: (context, state) =>
            const PlaceholderScreen(screenName: 'AI 인증 결과'),
      ),
      GoRoute(
        path: AppRoutes.reward,
        builder: (context, state) =>
            const PlaceholderScreen(screenName: '에코포인트'),
      ),
      GoRoute(
        path: AppRoutes.news,
        builder: (context, state) =>
            const PlaceholderScreen(screenName: '환경 뉴스'),
      ),
    ],
  );
}

class _BumpTopArcPainter extends CustomPainter {
  final double bumpRise;
  final Color color;
  const _BumpTopArcPainter({required this.bumpRise, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2; // 혹 반지름
    final dy = bumpRise - r; // 원 중심 기준 바 윗선 위치
    final half = math.sqrt(r * r - dy * dy);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(r - half, bumpRise)
      ..arcToPoint(
        Offset(r + half, bumpRise),
        radius: Radius.circular(r),
        clockwise: true, // ← 만약 곡선이 아래로 패이면 false로 바꾸세요
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScaffoldWithBottomNav extends StatelessWidget {
  final Widget child;
  const _ScaffoldWithBottomNav({required this.child});

  // ▼▼▼ 직접 조절하는 값 ▼▼▼
  static const double _barHeight = 63; // 바 높이(시작버튼 제외)
  static const double _bumpRise = 13; // 시작버튼이 바 위로 튀어나오는 높이(이만큼만 화면 가림)
  static const double _navIconSize = 32; // 홈/그룹/내활동/메뉴 아이콘
  static const double _navLabelSize = 13; // 라벨 글씨
  static const double _navItemWidth = 73; // 각 아이콘 항목 폭
  static const double _itemGap = 0; // 홈-그룹 / 내활동-메뉴 사이 간격
  static const double _centerGap = 86; // 가운데 시작버튼 자리 폭(이걸로 좌우 간격 조절)
  static const double _startBtnSize = 75; // 시작 파란 버튼 크기
  static const double _startIconSize = 33; // 버튼 안 달리기 아이콘 크기
  static const double _startLabelSize = 14; // 버튼 안 '시작' 글씨 크기
  static const double _navBottomPad = 0; // ★ 아이콘 아래 여백 (작을수록 아이콘이 더 아래로)
  static const double _startBumpSize = 88; // 흰 혹(원) 지름 = 버튼 둘레 흰 여백 (높이 아님!)
  static const Color _startBtnColor = Color(0xFF0C7D5E); // 시작 버튼 색
  // ▲▲▲ 직접 조절하는 값 ▲▲▲

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: child, bottomNavigationBar: _buildBar(context));
  }

  Widget _buildBar(BuildContext context) {
    final current = _getCurrentIndex(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _barHeight + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 흰 바 + 회색 테두리 (둥근 모서리까지 그대로 따라감)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: _barHeight + bottomInset,
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border.all(color: AppColors.divider, width: 1),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _navItem(context, 0, Symbols.home, '홈', current),
                        const SizedBox(width: _itemGap),
                        _navItem(
                          context,
                          1,
                          Symbols.diversity_1,
                          '그룹',
                          current,
                        ),
                        const SizedBox(width: _centerGap),
                        _navItem(context, 3, Symbols.person, '내 활동', current),
                        const SizedBox(width: _itemGap),
                        _navItem(context, 4, Symbols.more_horiz, '메뉴', current),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 둥근 흰 혹 + 파란 시작 버튼 (테두리 없음 → 네모 선 안 생김)
          Positioned(
            top: -_bumpRise,
            left: 0,
            right: 0,
            child: Center(
              child: CustomPaint(
                foregroundPainter: _BumpTopArcPainter(
                  bumpRise: _bumpRise,
                  color: AppColors.divider,
                ),
                child: Container(
                  width: _startBumpSize,
                  height: _startBumpSize,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: _startButton(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
    int current,
  ) {
    final selected = current == index;
    final color = selected ? const Color(0xFF8E8E93) : const Color(0xFFD9D9D9);
    return SizedBox(
      width: _navItemWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(context, index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end, // 아래쪽 정렬
          children: [
            Icon(icon, color: color, size: _navIconSize, weight: 400),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: _navLabelSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: _navBottomPad), // 아래 여백
          ],
        ),
      ),
    );
  }

  Widget _startButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context, 2),
      child: Container(
        width: _startBtnSize,
        height: _startBtnSize,
        decoration: const BoxDecoration(
          color: _startBtnColor,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Symbols.directions_run,
              color: Colors.white,
              size: _startIconSize,
              fill: 1,
              weight: 500,
            ),
            const SizedBox(height: 1),
            Text(
              '시작',
              style: TextStyle(
                color: Colors.white,
                fontSize: _startLabelSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.home)) return 0;
    if (location.startsWith(AppRoutes.group)) return 1;
    if (location.startsWith(AppRoutes.mypage)) return 3;
    if (location.startsWith(AppRoutes.settings)) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.group);
      case 2:
        context.push(AppRoutes.ploggingRoute); // 시작 → 플로깅 준비 화면(지도+현재위치+도착지+경로)
      case 3:
        context.go(AppRoutes.mypage);
      case 4:
        context.go(AppRoutes.settings);
    }
  }
}
