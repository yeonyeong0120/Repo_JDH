// 앱 전체에서 사용하는 컬러 시스템
// 변경 시 모든 화면에 영향 가니까 신중하게.
import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // 인스턴스화 방지 (정적 클래스로만 사용)

  // ========================================================
  // PRIMARY - 파스텔 블루 (메인 컬러)
  // ========================================================

  static const Color primary = Color(0xFF27AC88); // 14A57D↔3AB295 중간
  static const Color primaryDeep = Color(0xFF12805F); // 살짝만 연하게
  static const Color primaryLight = Color(0xFF95E4CD);
  static const Color primaryPale = Color(0xFFEAF8F2);

  /// 버튼·팝업 액션 전용 톤다운 primary. 브랜드 primary보다 채도를 낮춰
  /// 실기기에서 색이 덜 튀도록 한 값. 여기 한 줄만 바꾸면 버튼 톤이 조정됨.
  /// (더 차분하게: 0xFF5AA593 쪽 / 더 진하게: primary(0xFF27AC88) 쪽)
  static const Color primaryMuted = Color(0xFF4CA892);

  // ========================================================
  // SECONDARY - 코랄 (액센트 컬러)
  // ========================================================

  /// 코랄 액센트. 좋아요, 알림 뱃지, 마스코트 강조에 사용.
  static const Color coral = Color(0xFFFFB89A);

  /// 진한 코랄. "공감!" 누른 상태, 강한 강조에 사용.
  static const Color coralDeep = Color(0xFFFF8B6B);

  // ========================================================
  // TERTIARY - 민트 (환경 메시지 컬러)
  // ========================================================

  /// 민트. 환경 영향력, "다행이야!" 긍정 메시지에 사용.
  static const Color mint = Color(0xFF7DD3C0);

  /// 진한 민트. 성공 토스트, 완료 상태에 사용.
  static const Color mintDeep = Color(0xFF4FB8A1);

  // ========================================================
  // NEUTRALS - 텍스트 및 배경
  // ========================================================

  /// 본문 메인 텍스트.
  static const Color textPrimary = Color(0xFF1A1A1A);

  /// 부가 텍스트, 캡션.
  static const Color textSecondary = Color(0xFF5C5C5C);

  /// 힌트, 비활성 텍스트.
  static const Color textTertiary = Color(0xFF9A9A9A);

  /// 구분선.
  static const Color divider = Color(0xFFE8E8E8);

  /// 카드 외곽선.
  static const Color cardBorder = Color(0xFFF0F0F0);

  /// 전체 앱 배경 (살짝 푸른빛 도는 흰색).
  static const Color appBG = Color(0xFFFAFBFC);

  /// 카드 배경 (순백).
  static const Color cardBG = Color(0xFFFFFFFF);

  // ========================================================
  // SEMANTIC - 의미를 가진 색
  // ========================================================

  /// 성공 (활동 인증 성공 등).
  static const Color success = Color(0xFF52C896);

  /// 경고 (날씨 안내, 안전 안내).
  static const Color warning = Color(0xFFFFB547);

  /// 오류, 위험 (활동 취소 등).
  static const Color error = Color.fromARGB(255, 224, 60, 60);

  /// 정보 안내 (primary와 동일하지만 의미 구분용).
  static const Color info = primary;

  // ========================================================
  // TRASH CATEGORIES - 5종 쓰레기 분류 색
  // 기존 팔레트 재활용 (별도 색 추가 안 함)
  // PLOG-05 트래킹, PLOG-10 AI 분석, PLOG-11 정산에 사용
  // ========================================================

  // 카테고리 5색 (퀘스트·수거 종류 공용)
  // 도넛 차트·퀘스트용 파스텔 5색 (UI 상태색과 별개)
  static const Color categoryBlue = Color(0xFF7FB3F0); // 플라스틱 · 걸음수
  static const Color categoryRed = Color(0xFFF5928A); // 일반 · 칼로리
  static const Color categoryGreen = Color(0xFF6FCFB0); // 종이 · 수거량
  static const Color categoryOrange = Color(0xFFFFC773); // 캔 · 그룹참여
  static const Color categoryPurple = Color(0xFFA99BD4); // 유리 · 시간

  // 요일별 활동 그래프
  static const Color chartActivity = Color(0xFF8E9BE0); // 요일별 막대 (종합 활동량)
  static const Color chartActivityPeak = Color(0xFF6B78C9); // 오늘/피크 강조

  // ========================================================
  // GRADIENTS - Reflectly 스타일 그라데이션
  // 카드 1~2개에만 사용 (전체 화면의 20% 미만 컬러 원칙 유지)
  // ========================================================

  /// 메인 그라데이션. CTA 버튼, 활성 카드.
  /// "플로깅 시작" 버튼, HOME-01 활동 요약 카드.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primary],
  );

  /// 민트 그라데이션. 환경 영향력 카드.
  /// HOME-02 CO₂ 절감량 도넛 차트 배경.
  static const LinearGradient mintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB8E8DC), mint],
  );

  /// 따뜻한 그라데이션. 보상·뱃지 획득.
  /// ACT-08 뱃지 획득 모달.
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD4C2), coral],
  );

  /// 히어로 그라데이션. 홈 상단 배경 (옵션, 거의 사용 안 함).
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryPale, cardBG],
  );

  /// 강조 그라데이션. 다크 버튼 (옵션, 거의 사용 안 함).
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeep, primary],
  );

  // ========================================================
  // SHADOWS - 클레이모피즘 그림자
  // 카드의 부드러운 입체감 (그림자는 색이 아니므로 20% 원칙 무관)
  // ========================================================

  /// 카드 기본 그림자. 일반 카드에 사용.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: primaryDeep.withValues(alpha: 0.05), // 0.10 → 0.05 (더 연하게)
      blurRadius: 8, // 10 → 8
      offset: const Offset(0, 3), // (0,4) → (0,3)
    ),
  ];

  /// 강조 카드 그림자. 메인 카드 (활동 요약, 환경 영향력)에 사용.
  static List<BoxShadow> get cardShadowStrong => [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.04), // 0.06 → 0.04
      blurRadius: 18, // 24 → 18
      offset: const Offset(0, 5), // (0,8) → (0,5)
    ),
  ];

  /// 버튼 그림자. CTA 버튼에 사용.
  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primary.withValues(alpha: 0.12), // 0.25 → 0.12 (확 연하게)
      blurRadius: 12, // 16 → 12
      offset: const Offset(0, 4), // (0,6) → (0,4)
    ),
  ];

  // ========================================================
  // CLAUDE DESIGN 호환 별칭 (새 컴포넌트/홈이 쓰는 이름)
  // 기존 팔레트에 매핑 — 값 조정은 여기서
  // ========================================================

  // 그린 스케일
  static const Color green50 = primaryPale; // 가장 옅은 배경
  static const Color green200 = primaryLight;
  static const Color green700 = primary;
  static const Color green800 = primaryDeep;

  // 뉴트럴 스케일
  static const Color neutral100 = Color(0xFFF2F3F5); // 옅은 배경/구분
  static const Color neutral400 = textTertiary;
  static const Color neutral500 = Color(0xFF7A7A7A);
  static const Color neutral700 = textSecondary;

  // 표면·경계·배경
  static const Color surface = cardBG; // 카드 표면
  static const Color surfaceBrand = primaryPale; // 브랜드 톤 표면
  static const Color border = divider;
  static const Color bg = appBG;

  /// 주어진 색의 연한 틴트 배경 (아이콘 타일 등)
  static Color tint(Color c) => c.withValues(alpha: 0.12);

  // 브랜드/액션 텍스트
  static const Color textBrand = primaryDeep;
  static const Color actionPrimary = primary;
}
