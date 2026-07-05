import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: 'NotoSansKR',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light, // 라이트모드 기준의 명도 채도 적용
      ),
      scaffoldBackgroundColor: AppColors.appBG, // 스캐폴드 위젯 기본 배경색 설정
      useMaterial3: true, // 우리 아이콘 쓸때 이거쓸거야~~
      dialogTheme: const DialogThemeData(
        // ← 추가: 모든 팝업 흰 배경
        backgroundColor: Colors.white,
      ),
    );
  }
}
