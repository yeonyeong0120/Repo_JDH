import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:repo_jdh/core/providers/auth_provider.dart';
import 'package:repo_jdh/features/auth/presentation/login_screen.dart';
import 'package:repo_jdh/features/auth/presentation/nickname_setup_screen.dart';
import 'package:repo_jdh/features/auth/data/user_profile_provider.dart';
import 'package:repo_jdh/features/plogging/presentation/plogging_tracking_screen.dart';
import 'package:repo_jdh/features/home/presentation/home_screen.dart';
import 'package:repo_jdh/features/community/presentation/group_screen.dart';
import 'package:repo_jdh/features/mypage/presentation/my_activity_screen.dart';
import 'package:repo_jdh/features/settings/presentation/menu_screen.dart';
import 'package:repo_jdh/features/plogging/presentation/settlement_screen.dart';
import 'package:repo_jdh/features/community/presentation/group_feed_screen.dart';
import 'package:repo_jdh/features/plogging/presentation/route_setup_screen.dart';

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

// 루트 내비게이터 키 — 화면 전환 이후(정산→홈/피드)에도 다이얼로그를 띄우기 위해 공개.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

// 라우트 관찰기 — 홈 위에 다른 화면(플로깅·피드 등)이 덮였다 사라질 때를 감지해
// 홈 마스코트 애니메이션을 다시 재생하기 위해 사용한다. (RouteAware 구독용)
// 셸(탭)은 루트 내비게이터의 한 페이지이므로, 그 위로 풀스크린 화면이 push→pop
// 될 때 셸 페이지가 didPopNext 를 받는다. 이를 셸 래퍼에서 구독한다.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

// 홈으로 되돌아옴 신호 — 셸 래퍼가 didPopNext 를 받을 때마다 증가한다.
// 홈 마스코트가 이 값을 듣고 애니메이션을 처음부터 다시 재생한다.
final ValueNotifier<int> homeReentryTick = ValueNotifier<int>(0);

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

  // 스플래시 최소 노출 시간 — 이미 로그인된 기기 등에서 인증 확인이
  // 순식간에 끝나버리면 로고를 인지할 틈도 없이 다음 화면으로 넘어간다.
  // 인증 여부와 무관하게 최소한 이만큼은 스플래시에 붙잡아둔다.
  bool minSplashElapsed = false;
  Future.delayed(const Duration(milliseconds: 700), () {
    minSplashElapsed = true;
    refresh.ping();
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    // [문제 ②] 스플래시로 시작 — 인증 확인 중 홈이 잠깐 보였다가
    // 로그인으로 밀리는 깜빡임을 막는다. (splash 라우트는 아래에 정의)
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    // 홈 마스코트가 '홈으로 되돌아옴'을 감지하도록 루트 내비게이터에 관찰기 부착.
    observers: [appRouteObserver],

    refreshListenable: refresh,

    redirect: (context, state) {
      // [문제 ①] 기존 맨 위의 'return null;' 을 삭제했다.
      //          (그 아래 로직이 전부 dead code 였던 원인)

      final authStatus = ref.read(authStatusProvider); // watch 아님, read
      final loc = state.matchedLocation;
      final onSplash = loc == AppRoutes.splash;
      final loggingIn = loc == AppRoutes.login;
      final settingNickname = loc == AppRoutes.nicknameSetup;

      // ① 아직 확인 중이거나 스플래시 최소 노출 시간이 안 지났으면 머무른다
      //    (섣불리 이동하지 않음 — 인증이 빨리 끝나도 로고가 잠깐은 보이게)
      if (authStatus == AuthStatus.unknown || !minSplashElapsed) {
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
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.group,
            builder: (context, state) => const GroupScreen(),
          ),
          GoRoute(
            path: AppRoutes.mypage,
            builder: (context, state) => const MyActivityScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const MenuScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.ploggingRoute,
        builder: (context, state) => const RouteSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.ploggingTracking,
        builder: (context, state) => const PloggingTrackingScreen(),
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons/app_icon.png', width: 96, height: 96),
            const SizedBox(height: 16),
            const Text(
              'PLOGO',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _ScaffoldWithBottomNav extends StatefulWidget {
  final Widget child;
  const _ScaffoldWithBottomNav({required this.child});

  @override
  State<_ScaffoldWithBottomNav> createState() => _ScaffoldWithBottomNavState();
}

class _ScaffoldWithBottomNavState extends State<_ScaffoldWithBottomNav>
    with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 셸 페이지(루트 내비게이터)에 관찰기 구독 — 위로 덮였던 화면이 사라질 때 감지.
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  // 셸 위로 push 되었던 풀스크린 화면(플로깅·피드 등)이 pop 되어 셸이 다시 보일 때.
  @override
  void didPopNext() {
    homeReentryTick.value++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: _buildBar(context),
    );
  }

  Widget _buildBar(BuildContext context) {
    final current = _getCurrentIndex(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    // Startline: 가운데 시작버튼 없는 4탭 바. 모서리 둥근 네모(위 라운드) 느낌 유지.
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: AppColors.line100, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14191E24),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            _navItem(context, 0, TablerIcons.smartHome, '홈', current),
            _navItem(context, 1, TablerIcons.heartHandshake, '그룹', current),
            _navItem(context, 2, TablerIcons.activity, '내 활동', current),
            _navItem(context, 3, TablerIcons.dots, '메뉴', current),
          ],
        ),
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
    final color = selected ? AppColors.navActive : AppColors.navInactive;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(context, index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
    if (location.startsWith(AppRoutes.mypage)) return 2;
    if (location.startsWith(AppRoutes.settings)) return 3;
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
        context.go(AppRoutes.mypage);
      case 3:
        context.go(AppRoutes.settings);
    }
  }
}