import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart'; // 추가: SystemChrome
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:repo_jdh/core/theme/app_theme.dart';
import 'package:repo_jdh/core/router/app_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 추가
import 'package:flutter_naver_map/flutter_naver_map.dart'; // 추가

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

  // 시스템 상태바/하단 네비게이션바 색 지정.
  // 하단 시스템 바는 흰색으로 맞춰 흰 네비 바와 톤을 통일한다(칙칙함 방지).
  // 아이콘 밝기는 dark(밝은 배경 위 어두운 아이콘)로 둬서 3버튼 내비도 보이게 한다.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.white,
    ),
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
      // 모든 폰에 자동으로 맞추기 — 화면 폭(390 기준)에 비례해 글자·간격을
      // 자동 확대/축소한다. 작은 폰은 줄여 넘침을 막고, 큰 폰은 소폭 키운다.
      // 넘침 위험을 막기 위해 0.88~1.08 로 제한한다.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scale = (mq.size.width / 390).clamp(0.88, 1.08);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      // 한글 로케일 — 달력·날짜 선택 등 Material 위젯을 한국어로
      locale: const Locale('ko'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko')],
    );
  }
}
