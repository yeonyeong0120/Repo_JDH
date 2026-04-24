import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:repo_jdh/core/theme/app_theme.dart';
import 'package:repo_jdh/core/router/app_router.dart';
// 나중에 여기다 추가

// main 함수는 async로 변경한다
// Firebase 초기화가 비동기 작업이기 때문에 await이 필요하다
Future<void> main() async {
  // Flutter 엔진과 위젯 바인딩을 먼저 초기화한다
  // Firebase 같은 플랫폼 기능 호출 전에 반드시 선행되어야 한다
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  // android/app/google-services.json 파일을 자동으로 읽어 연결한다
  await Firebase.initializeApp();

  // TODO: STEP 6 완료 후 dotenv 로드 코드를 이곳에 추가한다
  // await dotenv.load(fileName: ".env");

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // appRouterProvider에서 GoRouter 인스턴스를 가져온다
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: '앱 이름은, ploggo!',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
