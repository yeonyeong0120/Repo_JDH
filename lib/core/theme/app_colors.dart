// 앱 전체 컬러 시스템 (v6 — "Startline" 리디자인)
//
// 초록 기반(v5)에서 차콜(#2A2F2C) 잉크 + 라임(#E9FF6A) 단일 액센트의
// 단색 계열 시스템으로 전면 교체했다. 규칙은 셋이다.
//   1. 잉크(ink)와 회색계로 화면을 구성한다. 색은 라임 하나만 "포인트"로 얹는다.
//   2. 라임은 흰 배경 위 글씨로 쓰지 않는다(대비 미달). 면·아바타·하이라이트·다크 위에만.
//   3. 버튼·주요 텍스트·선택 상태는 잉크. 데이터(쓰레기 5색)는 이 규칙 밖의 고정 매핑.
//
// 화면 코드에서는 SEMANTIC / STARTLINE 섹션 이름만 쓴다.
// 스케일 값(neutral300 등)을 직접 참조하지 않는다.
// 값이 바뀌면 모든 화면에 영향 가니 신중히.
import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // 정적 클래스 (인스턴스화 금지)

  // ========================================================
  // STARTLINE — 리디자인 핵심 토큰 (신규 화면은 이 이름을 우선 사용)
  // ========================================================

  /// 기본 텍스트·주요 버튼 배경·선택 상태. 디자인 시스템의 "잉크".
  static const Color ink = Color(0xFF2A2F2C);

  /// 유일한 액센트. 액션 강조·아바타·하이라이트·아이콘 포인트.
  /// 흰 배경 위 글씨 금지(대비 미달) — 면/다크 위에만.
  static const Color lime = Color(0xFFEEFF77);

  /// 라임 면 위에 얹는 텍스트/아이콘.
  static const Color limeOn = Color(0xFF151A0B);
  static const Color textOnLime = limeOn;

  /// 하이퍼링크·링크성 강조(호버).
  static const Color link = Color(0xFF17855A);

  // 회색 계열 (Startline 그레이 스케일 — 살짝 초록기 도는 중립)
  static const Color gray700 = Color(0xFF5A5F5B); // 보조 텍스트·아이콘
  static const Color gray500 = Color(0xFF8A8F8B); // 메타 텍스트·라벨
  static const Color gray400 = Color(0xFFB7BEB9); // 비활성 텍스트
  static const Color gray350 = Color(0xFFA8ADA9); // 플레이스홀더
  static const Color gray300 = Color(0xFFC8CFCB); // 셰브론·미선택 아이콘
  static const Color gray250 = Color(0xFFD6DAD8); // 미선택 라디오
  static const Color gray200 = Color(0xFFE3E6E4); // 밑줄·보더·비활성 버튼 면
  static const Color line100 = Color(0xFFEFF1F0); // 구분선·카드 보더
  static const Color surfaceSoft = Color(0xFFF4F6F5); // 보조 배경·고스트 버튼

  // 다크 화면(플로깅 중·촬영·사진 상세)
  static const Color darkBg = Color(0xFF242926);
  static const Color darkSurface = Color(0xFF313733); // 다크 상단·다크 칩
  static const Color darkChip = Color(0xFF363C38); // 비활성 인식 칩

  // ========================================================
  // GREEN — 레거시 스케일. 단색 전환에 맞춰 잉크/회색 램프로 중화한다.
  // (직접 참조하는 옛 화면이 자동으로 단색으로 degrade 되도록)
  // ========================================================

  static const Color green50 = surfaceSoft;
  static const Color green100 = line100;
  static const Color green150 = line100;
  static const Color green200 = gray200;
  static const Color green300 = gray300;
  static const Color green400 = gray350;
  static const Color green500 = gray500;
  static const Color green600 = ink; // 옛 브랜드 → 잉크
  static const Color green700 = ink;
  static const Color green750 = ink;
  static const Color green800 = ink;
  static const Color green900 = limeOn;

  // ========================================================
  // NEUTRAL — Startline 그레이로 재매핑
  // ========================================================

  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFAFBFA);
  static const Color neutral75 = surfaceSoft; // 앱 보조 배경
  static const Color neutral100 = line100;
  static const Color neutral200 = gray200;
  static const Color neutral300 = gray300;
  static const Color neutral400 = gray400;
  static const Color neutral500 = gray500;
  static const Color neutral600 = gray700; // 보조 텍스트 하한
  static const Color neutral700 = Color(0xFF4A4F4B); // 진회색
  static const Color neutral900 = ink;

  // ========================================================
  // CORAL — 오류·좋아요·차감(accent/like)로 재매핑
  // ========================================================

  static const Color coral50 = Color(0xFFFCEEEB);
  static const Color coral100 = Color(0xFFF8D5CD);
  static const Color coral300 = Color(0xFFEE9583);
  static const Color coral600 = Color(0xFFE4573D); // accent/like
  static const Color coral800 = Color(0xFFB23A24);

  // ========================================================
  // SEMANTIC — 화면 코드에서 쓰는 이름
  // ========================================================

  static const Color bg = surfaceSoft;
  static const Color surface = neutral0;
  static const Color surfaceBrand = surfaceSoft; // 옛 초록 틴트 헤더 → 소프트 그레이
  static const Color surfaceMuted = line100; // 아이콘 타일·칩 면

  // ── 헤더 페이드 워시 (초록 제거, 그레이로 중화) ──
  static const Color washTop = line100;
  static const Color washMid = surfaceSoft;
  static const Color washEnd = surfaceSoft;

  // ── 하단 네비게이션 ──
  static const Color navActive = ink;
  static const Color navInactive = gray300;

  // ── 서브 포인트(챌린지 필터 칩 등) — 앰버 계열 유지 ──
  static const Color subPoint = Color(0xFFC97A17);
  static const Color subPointBg = Color(0xFFF6ECDC);
  static const Color subPointText = Color(0xFF8A5510);

  // ── 날씨 아이콘 (채도 낮춘 4색 유지) ──
  static const Color wxSunny = Color(0xFFE8A33D);
  static const Color wxCloudy = Color(0xFF8A93A0);
  static const Color wxOvercast = Color(0xFF6E7681);
  static const Color wxRain = Color(0xFF4A81B8);

  static const Color border = gray200;

  static const Color textPrimary = ink; // 기본 텍스트
  static const Color textSecondary = gray700; // 보조 텍스트
  static const Color textOnTint = gray700;
  static const Color textBrand = ink; // 단색 — 옛 초록 강조 텍스트 → 잉크
  static const Color textBrandOnLight = ink;
  static const Color textDisabled = gray400;
  static const Color textOnBrand = neutral0; // 잉크 버튼 위 흰 글씨

  static const Color actionPrimary = ink; // 주 버튼 = 차콜 (화면당 1개)
  static const Color actionSecondary = surfaceSoft; // 고스트 보조 버튼 면
  static const Color actionSoft = line100; // 중립 아이콘 버튼 면(글리프는 ink)

  /// 내 채팅 말풍선 — 라임으로 포인트.
  static const Color bubbleMine = lime;
  static const Color textOnBubbleMine = limeOn;

  static const Color actionPressed = Color(0xFF1F231F);
  static const Color actionDanger = coral600;

  static const Color progress = ink; // 라이트 화면 진행 바(다크 화면은 라임을 직접 지정)
  static const Color success = ink; // 검증 통과 체크 = 잉크(Startline)
  static const Color warning = Color(0xFFC97A17); // 앰버 — 아이콘·테두리
  static const Color warningBg = Color(0xFFF6ECDC);
  static const Color accent = coral600;

  // ========================================================
  // DATA — 쓰레기 5분류 (앱 전역 고정 매핑, 다른 용도 재사용 금지)
  // ========================================================

  static const Color dataPlastic = Color(0xFF3A75AE);
  static const Color dataGeneral = Color(0xFF7D8783);
  static const Color dataPaper = Color(0xFF12784F);
  static const Color dataCan = Color(0xFFC97A17);
  static const Color dataGlass = Color(0xFF7A63BC);

  // 지표(퀘스트·기록) 색 — 분류색과 짝을 맞춘다.
  static const Color dataSteps = dataPlastic;
  static const Color dataDistance = dataGlass;
  static const Color dataCollect = dataPaper;
  static const Color dataGroup = dataCan;
  static const Color dataCalorie = coral600;
  static const Color dataTime = Color(0xFFC97A17);
  static const Color dataTimeFill = Color(0xFFE0A94A);

  /// 지도 경로선(도착지 설정의 실선). 다크 플로깅 화면은 라임을 직접 지정.
  static const Color routeLine = ink;

  /// 분류색을 흰 배경 위 옅은 면으로. 원색은 선·도트·라벨에만.
  static Color tint(Color c, [double amount = 0.15]) =>
      Color.alphaBlend(c.withValues(alpha: amount), neutral0);

  // ========================================================
  // ELEVATION — 그림자 색은 모두 rgba(25,30,36,α)
  // ========================================================

  /// 카드 기본. 0 12px 30px / 16%
  static List<BoxShadow> get cardShadow => const [
    BoxShadow(
      color: Color(0x29191E24),
      blurRadius: 30,
      offset: Offset(0, 12),
    ),
  ];

  /// 떠 있는 것 — 바텀시트·모달·FAB. 0 10px 26px / 20%
  static List<BoxShadow> get sheetShadow => const [
    BoxShadow(
      color: Color(0x33191E24),
      blurRadius: 26,
      offset: Offset(0, 10),
    ),
  ];

  // ========================================================
  // LEGACY — 기존 화면이 참조하는 이름들. 값만 Startline으로 바뀐다.
  // ========================================================

  @Deprecated('actionPrimary 사용') static const Color primary = ink;
  @Deprecated('ink 사용') static const Color primaryDeep = ink;
  @Deprecated('gray300 사용') static const Color primaryLight = gray300;
  @Deprecated('surfaceBrand 사용') static const Color primaryPale = line100;
  @Deprecated('actionPrimary 사용') static const Color primaryMuted = ink;

  @Deprecated('coral100 사용') static const Color coral = coral100;
  @Deprecated('accent 사용') static const Color coralDeep = coral600;

  @Deprecated('gray300 사용') static const Color mint = gray300;
  @Deprecated('ink 사용') static const Color mintDeep = ink;

  @Deprecated('textSecondary 사용') static const Color textTertiary = gray700;
  @Deprecated('border 사용') static const Color divider = gray200;
  @Deprecated('border 사용') static const Color cardBorder = gray200;
  @Deprecated('bg 사용') static const Color appBG = bg;
  @Deprecated('surface 사용') static const Color cardBG = neutral0;

  @Deprecated('actionDanger 사용') static const Color error = actionDanger;
  @Deprecated('textBrand 사용') static const Color info = ink;

  @Deprecated('dataPlastic 사용') static const Color categoryBlue = dataPlastic;
  @Deprecated('dataGeneral 사용') static const Color categoryRed = dataGeneral;
  @Deprecated('dataPaper 사용') static const Color categoryGreen = dataPaper;
  @Deprecated('dataCan 사용') static const Color categoryOrange = dataCan;
  @Deprecated('dataGlass 사용') static const Color categoryPurple = dataGlass;

  @Deprecated('dataPlastic 사용') static const Color chartActivity = dataPlastic;
  @Deprecated('progress 사용') static const Color chartActivityPeak = ink;

  @Deprecated('cardShadow 사용')
  static List<BoxShadow> get cardShadowStrong => sheetShadow;
  @Deprecated('그림자 없는 솔리드 버튼 사용')
  static List<BoxShadow> get buttonShadow => const [
    BoxShadow(
      color: Color(0x1F191E24),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// 뱃지 획득 모달 전용 그라데이션(액센트).
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [coral100, coral300],
  );

  @Deprecated('솔리드 actionPrimary 사용')
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gray500, ink],
  );
  @Deprecated('surfaceBrand 단색 사용')
  static const LinearGradient mintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [line100, gray200],
  );
  @Deprecated('흰 배경 + 큰 타이포로 대체')
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [line100, neutral0],
  );
  @Deprecated('솔리드 ink 사용')
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkSurface, darkBg],
  );
}
