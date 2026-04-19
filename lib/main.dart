import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repo_jdh/core/theme/app_theme.dart';
import 'package:repo_jdh/core/router/app_router.dart';
// 나중에 여기다 추가

void main() {
  runApp(const ProviderScope(child: MyApp()));  // 미리 providerscope 설정해둠
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // appRouterProvider에서 GoRouter 인스턴스를 가져온다
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: '플로깅앱이름정해야함',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
