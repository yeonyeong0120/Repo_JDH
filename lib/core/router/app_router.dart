import 'package:flutter/material.dart';
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
import 'package:repo_jdh/features/plogging/presentation/home_screen.dart';

part 'app_router.g.dart';

class AppRoutes {
  static const login = '/login';
  // ✚ 추가: 닉네임 설정 경로
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
}

final isLoggedInProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});

@riverpod
GoRouter appRouter(Ref ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  // ✚ 추가: 프로필 상태 감시 (닉네임 분기용)
  final profileAsync = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,

    redirect: (context, state) {
      final loggingIn = state.matchedLocation == AppRoutes.login;
      // ✚ 추가
      final settingNickname =
          state.matchedLocation == AppRoutes.nicknameSetup;

      // 1) 로그인 체크
      if (!isLoggedIn) {
        return loggingIn ? null : AppRoutes.login;
      }
      if (loggingIn) return AppRoutes.home;

      // ✚ 추가: 2) 닉네임 체크
      //   - 프로필 없거나 닉네임 비어있음 → 닉네임 설정 화면
      //   - 이미 닉네임 있음 → 닉네임 화면 접근 시 홈으로
      //   - 로딩/에러 시에는 보류 (null 반환 = 현재 위치 유지)
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

      // ✚ 추가: 닉네임 설정 라우트 (ShellRoute 바깥에 배치 — 바텀네비 없음)
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
            builder: (context, state) =>
                const PlaceholderScreen(screenName: '홈'),
          ),
          GoRoute(
            path: AppRoutes.group,
            builder: (context, state) =>
                const PlaceholderScreen(screenName: '그룹'),
          ),
          GoRoute(
            path: AppRoutes.mypage,
            builder: (context, state) =>
                const PlaceholderScreen(screenName: '마이페이지'),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) =>
                const PlaceholderScreen(screenName: '설정'),
          ),
        ],
      ),

      GoRoute(
        path: AppRoutes.ploggingRoute,
        builder: (context, state) =>
            const PlaceholderScreen(screenName: '경로 추천'),
      ),
      // ← HomeScreen 연결
      GoRoute(
        path: AppRoutes.ploggingTracking,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.visionCamera,
        builder: (context, state) => const CameraDetectionScreen(),
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
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle, size: 40), label: '플로깅'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '내정보'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: '설정'),
        ],
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
        context.push(AppRoutes.ploggingTracking); // ← route → tracking으로 변경
      case 3:
        context.go(AppRoutes.mypage);
      case 4:
        context.go(AppRoutes.settings);
    }
  }
}