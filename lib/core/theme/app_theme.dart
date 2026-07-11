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

      // ── 버튼 톤다운 ──
      // 브랜드 primary는 그대로 두고, 버튼/팝업 액션만 채도 낮춘 primaryMuted 사용.
      // 주의: 화면에서 color/backgroundColor를 직접 지정한 버튼엔 적용되지 않음
      //       (그런 버튼은 해당 화면 파일에서 AppColors.primaryMuted로 바꿔야 함).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryMuted,
          foregroundColor: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryMuted,
          foregroundColor: Colors.white,
        ),
      ),
      // 팝업의 "확인/취소" 같은 텍스트 버튼 색도 함께 톤다운.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryMuted),
      ),
    );
  }
}
