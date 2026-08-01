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
  static const splash = '/splash'; // ✚ 인증 확인 중 보여줄 로딩 화면
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

// ─────────────────────────────────────────────────────────────
// [문제 ②] 인증 상태 3분법
// ─────────────────────────────────────────────────────────────
// 기존 isLoggedInProvider 는 true/false 2가지뿐이라,
// Firebase 가 로그인 정보를 복원하는 "확인 중(loading)" 순간을
// false(비로그인)로 뭉개버렸다. → 로그인한 사용자도 켤 때마다
// 로그인 화면이 번쩍 스쳐 지나가는 버그의 원인.
//
// 그래서 "아직 모름(unknown)" 상태를 별도로 둔다.
enum AuthStatus { unknown, signedIn, signedOut }

final authStatusProvider = Provider<AuthStatus>((ref) {
  final async = ref.watch(authStateProvider);
  // ▼ 디버그: Firebase 인증 스트림이 실제로 어떤 상태를 뱉는지 눈으로 확인
  //   (원인 파악 후 이 debugPrint 줄은 지워도 된다)
  debugPrint('[AUTH] asyncValue=$async');
  return async.when(
    // 핵심: loading 을 signedOut 으로 뭉개지 않는다.
    loading: () => AuthStatus.unknown,
    error: (e, __) {
      debugPrint('[AUTH] ❌ 인증 스트림 에러: $e');
      return AuthStatus.signedOut; // 조회 실패 = 비로그인 취급
    },
    data: (user) =>
        user != null ? AuthStatus.signedIn : AuthStatus.signedOut,
  );
});

// 하단 네비 셸(탭 화면들)이 쓰는 내비게이터 키.
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

@riverpod
GoRouter appRouter(Ref ref) {
  // ─────────────────────────────────────────────────────────
  // [문제 ⑤ + 로딩 멈춤] 라우터 통째 재생성 방지 + 알림 통로 통일
  // ─────────────────────────────────────────────────────────
  // 기존엔 여기서 ref.watch(...) 를 했다. 그러면 로그인/프로필이
  // 바뀔 때마다 GoRouter '객체 자체'가 새로 만들어져서 스택이 날아간다.
  //
  // 또한 기존 refreshListenable 은 FirebaseAuth 스트림을 직접 감시했는데,
  // 정작 redirect 는 authStatusProvider(Riverpod) 값을 읽는다.
  // 두 통로가 어긋나면 상태가 바뀌어도 라우터가 redirect 를 다시 계산하지
  // 않아, 스플래시(unknown)에서 영영 멈춘다.  → 알림 통로를 Riverpod 으로 통일.
  final refresh = _RouterRefresh();
  // authStatusProvider 값이 바뀔 때마다 라우터에 '다시 계산해' 알림을 보낸다.
  ref.listen(authStatusProvider, (_, __) => refresh.ping());
  // 프로필(닉네임 여부)도 라우팅에 영향을 주므로 같이 감시.
  ref.listen(userProfileProvider, (_, __) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    // [문제 ②] 스플래시로 시작 — 인증 확인 중 홈이 잠깐 보였다가
    // 로그인으로 밀리는 깜빡임을 막는다. (splash 라우트는 아래에 정의)
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,

    refreshListenable: refresh,

    redirect: (context, state) {
      // [문제 ①] 기존 맨 위의 'return null;' 을 삭제했다.
      //          (그 아래 로직이 전부 dead code 였던 원인)

      final authStatus = ref.read(authStatusProvider); // watch 아님, read
      final loc = state.matchedLocation;
      final onSplash = loc == AppRoutes.splash;
      final loggingIn = loc == AppRoutes.login;
      final settingNickname = loc == AppRoutes.nicknameSetup;

      // ① 아직 확인 중 → 스플래시에 머무른다 (섣불리 이동하지 않음)
      if (authStatus == AuthStatus.unknown) {
        return onSplash ? null : AppRoutes.splash;
      }

      // ② 비로그인 → 로그인 화면으로
      if (authStatus == AuthStatus.signedOut) {
        return loggingIn ? null : AppRoutes.login;
      }

      // ── 여기부터는 로그인된 상태 ──

      // ③ 로그인 상태인데 로그인/스플래시 화면에 있으면 홈으로
      if (loggingIn || onSplash) return AppRoutes.home;

      // ④ 닉네임 미설정 체크
      final profileAsync = ref.read(userProfileProvider);
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
        // 프로필 로딩 중엔 이동 없음 — 성급히 닉네임 화면으로 보내지 않는다
        orElse: () => null,
      );
    },

    routes: [
      // [문제 ②] 스플래시 라우트: 인증 확인이 끝날 때까지 보여줄 로딩 화면
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.nicknameSetup,
        builder: (context, state) => const NicknameSetupScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
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
          final extra = state.extra;
          if (extra is Map) {
            return GroupFeedScreen(
              groupId: (extra['id'] as String?) ?? '',
              groupName: (extra['name'] as String?) ?? '그룹',
            );
          }
          return GroupFeedScreen(groupName: (extra as String?) ?? '그룹');
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

// ─────────────────────────────────────────────────────────────
// 라우터 새로고침 알림기
// ─────────────────────────────────────────────────────────────
// ping() 이 불릴 때마다 notifyListeners() 를 호출해, GoRouter 가
// redirect 를 다시 계산하게 한다. 위에서 ref.listen 으로
// authStatusProvider / userProfileProvider 변화를 여기에 연결한다.
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

// 스플래시(로딩) 화면 — 로고/스피너만 있으면 충분하다.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
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
        clockwise: true,
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
  static const double _barHeight = 63;
  static const double _bumpRise = 13;
  static const double _navIconSize = 32;
  static const double _navLabelSize = 13;
  static const double _navItemWidth = 73;
  static const double _itemGap = 0;
  static const double _centerGap = 86;
  static const double _startBtnSize = 75;
  static const double _startIconSize = 33;
  static const double _startLabelSize = 14;
  static const double _navBottomPad = 0;
  static const double _barLift = 12;
  static const double _startBumpSize = 88;
  static const Color _startBtnColor = Color(0xFF0C7D5E);
  // ▲▲▲ 직접 조절하는 값 ▲▲▲

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: _buildBar(context),
    );
  }

  Widget _buildBar(BuildContext context) {
    final current = _getCurrentIndex(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _barHeight + bottomInset + _barLift,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: _barHeight + bottomInset + _barLift,
              padding: EdgeInsets.only(bottom: bottomInset + _barLift),
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
          mainAxisAlignment: MainAxisAlignment.end,
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
            const SizedBox(height: _navBottomPad),
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
        _shellNavigatorKey.currentState?.popUntil((route) => route.isFirst);
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.group);
      case 2:
        context.push(AppRoutes.ploggingRoute);
      case 3:
        context.go(AppRoutes.mypage);
      case 4:
        context.go(AppRoutes.settings);
    }
  }
}