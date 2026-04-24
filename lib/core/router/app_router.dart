import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:repo_jdh/core/router/placeholder_screen.dart';

part 'app_router.g.dart';

// ============================================================
// 경로 상수 정의
// 문자열을 직접 쓰면 오타 발생 위험이 있으므로 상수로 관리한다
// ============================================================
class AppRoutes {
  static const login = '/login';
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
}

// ============================================================
// 로그인 상태 임시 Provider
// Firebase 연결 완료 후 실제 Auth 상태를 반환하는 Provider로 교체한다
// ============================================================
final isLoggedInProvider = Provider<bool>((ref) {
  // Firebase 연결 완료 후 아래 값을 실제 인증 상태로 교체
  // 예: ref.watch(authNotifierProvider).value?.uid != null
  return false; // false = 로그인 화면으로 진입 / true = 홈 화면으로 진입
});

// ============================================================
// 라우터 Provider
// ============================================================
@riverpod
GoRouter appRouter(Ref ref) {
  // 로그인 상태를 감지하여 redirect에 활용한다
  final isLoggedIn = ref.watch(isLoggedInProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true, // 개발 중 화면 이동 로그 출력, 배포 시 false로 변경

    // --------------------------------------------------------
    // redirect: 모든 화면 이동 전에 로그인 상태를 검사한다
    // --------------------------------------------------------
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == AppRoutes.login;

      // 로그인 안 된 상태에서 로그인 화면이 아닌 곳으로 가려 하면 로그인 화면으로 보낸다
      if (!isLoggedIn && !loggingIn) return AppRoutes.login;

      // 로그인 된 상태에서 로그인 화면으로 오면 홈으로 보낸다
      if (isLoggedIn && loggingIn) return AppRoutes.home;

      // 그 외에는 원래 목적지로 이동한다
      return null;
    },

    routes: [
      // --------------------------------------------------------
      // 로그인 화면 (바텀내비 없음)
      // --------------------------------------------------------
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) =>
            const PlaceholderScreen(screenName: '로그인'),
        // TODO// 실제 화면으로 교체
        // builder: (context, state) => const LoginScreen(),
      ),

      // --------------------------------------------------------
      // 바텀내비게이션바가 포함된 화면들 (ShellRoute로 묶음)
      // ShellRoute: 탭 전환 시 바텀내비바가 유지되는 구조
      // --------------------------------------------------------
      ShellRoute(
        builder: (context, state, child) {
          return _ScaffoldWithBottomNav(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) =>
                const PlaceholderScreen(screenName: '홈'),
            // TODO: builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.group,
            builder: (context, state) =>
                const PlaceholderScreen(screenName: '그룹'),
            // TODO: builder: (context, state) => const GroupScreen(),
          ),
          GoRoute(
            path: AppRoutes.mypage,
            builder: (context, state) =>
                const PlaceholderScreen(screenName: '마이페이지'),
            // TODO: builder: (context, state) => const MypageScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) =>
                const PlaceholderScreen(screenName: '설정'),
            // TODO: builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),

      // --------------------------------------------------------
      // 바텀내비 밖 화면들 (플로깅 진행 흐름)
      // --------------------------------------------------------
      GoRoute(
        path: AppRoutes.ploggingRoute,
        builder: (context, state) =>
            const PlaceholderScreen(screenName: '경로 추천'),
        // TODO: builder: (context, state) => const RouteScreen(),
      ),
      GoRoute(
        path: AppRoutes.ploggingTracking,
        builder: (context, state) =>
            const PlaceholderScreen(screenName: '플로깅 트래킹'),
        // TODO: builder: (context, state) => const TrackingScreen(),
      ),
      GoRoute(
        path: AppRoutes.visionCamera,
        builder: (context, state) =>
            const PlaceholderScreen(screenName: '카메라 촬영'),
        // TODO: builder: (context, state) => const CameraScreen(),
      ),
      GoRoute(
        path: AppRoutes.visionResult,
        builder: (context, state) =>
            const PlaceholderScreen(screenName: 'AI 인증 결과'),
        // TODO: builder: (context, state) => const VisionResultScreen(),
      ),
      GoRoute(
        path: AppRoutes.reward,
        builder: (context, state) =>
            const PlaceholderScreen(screenName: '에코포인트'),
        // TODO: builder: (context, state) => const RewardScreen(),
      ),
      GoRoute(
        path: AppRoutes.news,
        builder: (context, state) =>
            const PlaceholderScreen(screenName: '환경 뉴스'),
        // TODO: builder: (context, state) => const NewsScreen(),
      ),
    ],
  );
}

// ============================================================
// 바텀내비게이션바 포함 Scaffold
// ShellRoute의 child가 각 탭 화면으로 교체된다
// ============================================================
class _ScaffoldWithBottomNav extends StatelessWidget {
  final Widget child;

  const _ScaffoldWithBottomNav({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _getCurrentIndex(context),
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: '그룹'),
          // 중앙 플로깅 버튼은 별도 push 방식으로 동작한다
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle, size: 40), label: '플로깅'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내정보'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }

  // 현재 경로를 기준으로 바텀내비 활성 탭 인덱스를 반환한다
  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.home)) return 0;
    if (location.startsWith(AppRoutes.group)) return 1;
    if (location.startsWith(AppRoutes.mypage)) return 3;
    if (location.startsWith(AppRoutes.settings)) return 4;
    return 0;
  }

  // 탭 인덱스에 따라 해당 경로로 이동한다
  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.group);
      case 2:
        // 플로깅 버튼은 탭 전환이 아닌 별도 화면 push 방식으로 동작한다
        context.push(AppRoutes.ploggingRoute);
      case 3:
        context.go(AppRoutes.mypage);
      case 4:
        context.go(AppRoutes.settings);
    }
  }
}