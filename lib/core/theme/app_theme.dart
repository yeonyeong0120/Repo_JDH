import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.green600,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.actionPrimary,
          onPrimary: AppColors.textOnBrand,
          primaryContainer: AppColors.surfaceBrand,
          onPrimaryContainer: AppColors.textOnTint,
          secondary: AppColors.accent,
          onSecondary: AppColors.textOnBrand,
          error: AppColors.actionDanger,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          outlineVariant: AppColors.border,
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppType.fontFamily, // pubspec.yaml에 Pretendard 등록 필요
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,

      // ── 타이포 스케일 연결 ──
      // 화면에서 TextStyle을 직접 만들지 말고
      // Theme.of(context).textTheme 또는 AppType.* 를 쓸 것.
      textTheme: const TextTheme(
        displayMedium: AppType.display,
        headlineMedium: AppType.title1,
        titleLarge: AppType.title2,
        titleMedium: AppType.title3,
        bodyLarge: AppType.bodyLarge,
        bodyMedium: AppType.body,
        labelLarge: AppType.label,
        bodySmall: AppType.caption,
        labelSmall: AppType.overline,
      ).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),

      // ── 앱바: 초록 배경 폐기, 흰 배경 + 큰 타이포 ──
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppType.title2,
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: Touch.icon),
      ),

      // ── 카드: v2는 부드러운 그림자 (AppCard가 실제 구현) ──
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.neutral900.withValues(alpha: 0.10),
        elevation: 3,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Radii.cardR),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size: Touch.icon,
      ),

      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 14,
        titleTextStyle: AppType.title3,
        subtitleTextStyle: AppType.caption,
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),

      // ── 버튼 ──
      // 솔리드 초록은 화면당 하나. 보조 버튼은 actionSecondary(틴트) + green700 글씨.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.actionPrimary,
          foregroundColor: AppColors.textOnBrand,
          disabledBackgroundColor: AppColors.neutral200,
          disabledForegroundColor: AppColors.neutral500,
          minimumSize: const Size(0, Touch.button),
          textStyle: AppType.label,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: Radii.innerR),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.actionPrimary,
          foregroundColor: AppColors.textOnBrand,
          disabledBackgroundColor: AppColors.neutral200,
          disabledForegroundColor: AppColors.neutral500,
          minimumSize: const Size(0, Touch.button),
          textStyle: AppType.label,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: Radii.innerR),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(0, Touch.button),
          textStyle: AppType.label,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: Radii.innerR),
        ),
      ),
      // 텍스트 버튼은 카드 밖(배경 위)에 놓이는 경우가 많아 green700.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textBrandOnLight,
          minimumSize: const Size(0, Touch.min),
          textStyle: AppType.label,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.actionPrimary,
        foregroundColor: AppColors.textOnBrand,
        elevation: 4,
      ),

      // ── 바텀 내비 ──
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.actionPrimary,
        unselectedItemColor: AppColors.neutral500,
        selectedLabelStyle: AppType.navLabel,
        unselectedLabelStyle: AppType.navLabel,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── 다이얼로그 · 시트 ──
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppType.title2.copyWith(color: AppColors.textPrimary),
        contentTextStyle: AppType.body.copyWith(color: AppColors.textSecondary),
        shape: RoundedRectangleBorder(borderRadius: Radii.sheetR),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.neutral900,
        contentTextStyle: AppType.body.copyWith(color: AppColors.neutral0),
        actionTextColor: AppColors.green300,
        insetPadding: const EdgeInsets.symmetric(horizontal: Gap.screenPad, vertical: Gap.lg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: Radii.innerR),
      ),

      // ── 입력 ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.neutral50,
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.lg),
        hintStyle: AppType.body.copyWith(color: AppColors.textDisabled),
        labelStyle: AppType.label.copyWith(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: Radii.innerR,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.innerR,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        // 포커스 시 초록 테두리를 쓰지 않는다(공통). enabled 와 동일한 회색 테두리 유지.
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.innerR,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.innerR,
          borderSide: const BorderSide(color: AppColors.actionDanger),
        ),
      ),

      // ── 토글 · 진행바 ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.neutral0
              : AppColors.neutral0,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.actionPrimary
              : AppColors.neutral300,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.progress,
        linearTrackColor: AppColors.neutral100,
        linearMinHeight: 10,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.neutral100,
        selectedColor: AppColors.surfaceBrand,
        labelStyle: AppType.caption.copyWith(color: AppColors.textSecondary),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: Radii.fullR),
      ),

      // ── 날짜 선택 달력 ──
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.surfaceBrand,
        headerForegroundColor: AppColors.textOnTint,
        shape: RoundedRectangleBorder(borderRadius: Radii.sheetR),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.actionPrimary : null,
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.textOnBrand
              : AppColors.textPrimary,
        ),
        todayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.textOnBrand
              : AppColors.actionPrimary,
        ),
        todayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.actionPrimary : null,
        ),
        todayBorder: const BorderSide(color: AppColors.actionPrimary),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.actionPrimary : null,
        ),
        yearForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.textOnBrand
              : AppColors.textPrimary,
        ),
      ),
    );
  }
}
