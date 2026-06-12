import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:repo_jdh/core/theme/app_theme.dart';
import 'package:repo_jdh/core/router/app_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';          // 추가
import 'package:flutter_naver_map/flutter_naver_map.dart';    // 추가


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

  // .env 로드 (아래 네이버 init이 .env 값을 쓰므로 먼저 호출)
  await dotenv.load(fileName: ".env");

  // 네이버 지도 초기화
  await FlutterNaverMap().init(
    clientId: dotenv.env['NAVER_MAP_CLIENT_ID']!,
    onAuthFailed: (ex) => debugPrint('네이버 지도 인증 실패: $ex'),
  );

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
