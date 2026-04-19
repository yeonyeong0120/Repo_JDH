import 'package:flutter/material.dart';

// 각 feature 화면이 완성되기 전까지 임시로 사용하는 플레이스홀더 위젯
// 팀원이 실제 화면을 완성하면 app_router.dart의 import를 교체한다
class PlaceholderScreen extends StatelessWidget {
  final String screenName;

  const PlaceholderScreen({super.key, required this.screenName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(screenName)),
      body: Center(
        child: Text(
          '$screenName\n(개발 예정)',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}