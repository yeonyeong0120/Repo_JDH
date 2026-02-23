import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. 하얀 도화지를 깝니다.
    return Scaffold(
      // (나중에 여기에 배경색을 AppColors.appBG로 지정할 거예요)
      backgroundColor: Colors.white,

      // 2. 상태표시줄을 침범하지 않게 안전 구역을 설정합니다.
      body: SafeArea(
        // 3. 위에서 아래로 위젯을 쌓을 기둥을 세웁니다.
        child: Column(
          // crossAxisAlignment: 기둥 안의 요소들을 왼쪽으로 정렬합니다.
          crossAxisAlignment: CrossAxisAlignment.start,

          // children: 이 대괄호 [ ] 안에 들어가는 것들이 실제 화면에 보일 레고 블록들입니다.
          children: [
            // --- 1단계: 맨 위 '줍다행' 타이틀이 들어갈 자리 ---

            // --- 2단계: 주간 달력이 들어갈 자리 ---

            // --- 3단계: 활동 요약 카드가 들어갈 자리 ---
          ],
        ),
      ),
    );
  }
}
