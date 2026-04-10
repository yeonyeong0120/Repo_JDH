import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repo_jdh/core/theme/app_theme.dart';
// 나중에 여기다 추가

void main() {
  runApp(const ProviderScope(child: MyApp()));  // 미리 providerscope 설정해둠
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '플로깅앱이름정해야함',
      debugShowCheckedModeBanner: false, // 디버그 배너 제거
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: Center(
          child: Text('굿바이 줍다행...'),
        ),
      ),
    );
  }
}
