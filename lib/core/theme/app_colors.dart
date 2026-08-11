// 앱 전체에서 사용하는 컬러 시스템 (v5 — v2 밝은 톤으로 되돌림 + 신규 토큰 유지)
//
// v4 에서 낮췄던 채도를 v2 값으로 되돌렸다.
// 다만 v4 에서 새로 만든 토큰(green150 / actionSoft / dataXxx / routeLine)은
// 화면들이 이미 참조하고 있어 그대로 둔다.
//
// 60 : 30 : 10 비율 규칙은 유지
//   60% 메인      bg(#F4F8F5) + surface(#FFFFFF)
//   30% 세컨더리  surfaceBrand(#C7EDD5) · green150(#E4F6EB)
//   10% 포인트    actionPrimary(#17855A) — 주 버튼·핵심 수치에만
//   dataXxx(카테고리·지표)는 데이터 전용이라 이 비율 밖.
// 변경 시 모든 화면에 영향 가니까 신중하게.
//
// 규칙 3가지만 기억하면 됩니다.
//  1. 화면 코드에서는 SEMANTIC 섹션의 이름만 씁니다. green600 같은 스케일 값 직접 참조 금지.
//  2. textBrand(초록 글씨)는 흰 카드 위에서만. 배경·틴트 위에서는 textBrandOnLight.
//  3. actionPrimary(꽉 찬 초록)는 화면당 하나. 두 번째 버튼은 actionSecondary.
import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // 인스턴스화 방지 (정적 클래스로만 사용)

  // ========================================================
  // GREEN — 브랜드 스케일 (hue 157)
  // v1의 primary / mint / success / categoryGreen 을 하나로 통합
  // ========================================================

  static const Color green50 = Color(0xFFF3FBF6);
  static const Color green100 = Color(0xFFE4F6EB);
  static const Color green150 = Color(0xFFDCF2E5); // 세컨더리 면 (카드·칩·내 말풍선)
  static const Color green200 = Color(0xFFC7EDD5);
  static const Color green300 = Color(0xFF9CDDB6);
  static const Color green400 = Color(0xFF64C795);
  static const Color green500 = Color(0xFF34AE77);
  static const Color green600 = Color(0xFF17855A); // ★ 브랜드. 흰 글씨 4.63:1
  static const Color green700 = Color(0xFF106B49);
  static const Color green750 = Color(0xFF0B5238); // 초록 면 위 글자·아이콘 (green200 위 7.4:1)
  static const Color green800 = Color(0xFF0B5238);
  static const Color green900 = Color(0xFF073725);

  // ========================================================
  // NEUTRAL — 차가운 라이트 그레이(쿨 뉴트럴). 초록기·따뜻함 모두 제거.
  // (초록은 SEMANTIC 의 accent/action 에만 남긴다 — 지운 게 아님)
  // ========================================================

  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFFBFCFD);
  static const Color neutral75 = Color(0xFFF6F8F9); // 앱 배경 전용 (밝은 쿨 오프화이트)
  static const Color neutral100 = Color(0xFFF0F3F4);
  static const Color neutral200 = Color(0xFFE6E9EC);
  static const Color neutral300 = Color(0xFFCDD1D5);
  static const Color neutral400 = Color(0xFF979CA1);
  static const Color neutral500 = Color(0xFF747A7E);
  static const Color neutral600 = Color(0xFF565B5F); // 텍스트 하한 (흰 위 6.4:1)
  static const Color neutral700 = Color(0xFF3C4145);
  static const Color neutral900 = Color(0xFF212528);

  // ========================================================
  // CORAL — 유일한 액센트 (연속 기록, 수거 핫스팟)
  // ========================================================

  static const Color coral50 = Color(0xFFFFF4F0);
  static const Color coral100 = Color(0xFFFFDFD5);
  static const Color coral300 = Color(0xFFF5A78C); // 일러스트·장식 전용
  static const Color coral600 = Color(0xFFC74A32); // 텍스트·아이콘 4.70:1
  static const Color coral800 = Color(0xFF992F1C);

  // ========================================================
  // SEMANTIC — 화면 코드에서는 아래 이름만 사용
  // ========================================================

  static const Color bg = neutral75;
  static const Color surface = neutral0;
  static const Color surfaceBrand = green200; // 틴트 헤더. 화면당 1곳
  // green100 은 흰 배경에서 거의 안 보여 배경으로 쓰지 않는다 (테두리·구분용만)
  static const Color border = neutral200;

  static const Color textPrimary = neutral900; // 13.7:1
  static const Color textSecondary = neutral600; // 5.7:1 (하한)
  static const Color textOnTint = neutral700; // green100 위 본문 8.1:1
  static const Color textBrand = green600; // 흰 카드 위에서만 4.63:1
  static const Color textBrandOnLight = green700; // bg·틴트 위 5.4:1
  static const Color textDisabled = neutral400; // 실제 정보에는 금지
  static const Color textOnBrand = neutral0; // 초록 배경 위는 순백만

  static const Color actionPrimary = green600; // 화면당 1개
  static const Color actionSecondary = green100; // 보조 버튼 배경 (초록 글씨와 함께)
  /// 연초록으로 채운 아이콘 버튼(채팅 보내기 등). 글리프는 textBrandOnLight.
  static const Color actionSoft = Color(0xFFB4E5C9);

  /// 내 채팅 말풍선. 꽉 찬 초록이 답답해 연초록 + 진한 글씨로.
  static const Color bubbleMine = green150;
  static const Color textOnBubbleMine = Color(0xFF153A2B);

  static const Color actionPressed = green700;
  static const Color actionDanger = Color(0xFFC4342E);

  static const Color progress = green500; // 진행 바·게이지·차트 막대
  static const Color success = green600;
  static const Color warning = Color(0xFFB0770A); // 3.8:1 — 아이콘·테두리 전용
  static const Color warningBg = Color(0xFFFDF5E6);
  static const Color accent = coral600;

  // ========================================================
  // DATA — 쓰레기 5분류. 전부 흰 배경 4.5:1 이상이라 라벨로도 사용 가능
  // ========================================================

  static const Color dataPlastic = Color(0xFF3A75AE); // 4.71:1
  static const Color dataGeneral = neutral500; // 5.02:1
  static const Color dataPaper = green600; // 4.63:1
  static const Color dataCan = Color(0xFFC97A17); // 5.25:1
  static const Color dataGlass = Color(0xFF7A63BC); // 4.84:1

  // 지표(퀘스트·기록) 색 — 카테고리 색과 짝을 맞춘다.
  //  걸음수=파랑 / 거리=보라 / 수거량=초록 / 그룹참여=주황 / 칼로리=빨강 / 시간=노랑
  static const Color dataSteps = Color(0xFF2F6FB0);
  static const Color dataDistance = Color(0xFF5F51A0);
  static const Color dataCollect = green700;
  static const Color dataGroup = dataCan;
  static const Color dataCalorie = Color(0xFFE5392E); // 원색에 가까운 빨강
  static const Color dataTime = Color(0xFFF2B705); // 원색에 가까운 노랑
  static const Color dataTimeFill = Color(0xFFF5C400); // 면으로 깔 때(샛노랑)

  /// 지도 경로선. 트래킹·정산·도착지 설정이 같은 값을 쓴다.
  static const Color routeLine = Color(0xFF1D9E75);

  /// 분류색을 흰 배경 위 옅은 면으로 바꾼다.
  /// 차트 조각, 아이콘 타일 배경 등 "색은 유지하되 넓게 깔 때" 사용.
  /// 원색은 선·범례 도트·라벨 텍스트에만.
  static Color tint(Color c, [double amount = 0.15]) =>
      Color.alphaBlend(c.withValues(alpha: amount), neutral0);

  // ========================================================
  // ELEVATION — 2단계뿐. 카드는 선, 떠 있는 것만 그림자
  // 초록기를 뺀 중성 회색 (v1 그림자가 화면 전체를 물들였음)
  // ========================================================

  /// 카드 기본. border 1px 과 함께 사용.
  static List<BoxShadow> get cardShadow => const [
    BoxShadow(
      color: Color(0x0F24302B),
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ];

  /// 떠 있는 것 — 바텀시트, 모달, FAB.
  static List<BoxShadow> get sheetShadow => const [
    BoxShadow(
      color: Color(0x2924302B),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  // ========================================================
  // LEGACY — 기존 화면이 참조하는 이름들.
  // 값만 v2로 바뀌므로 마이그레이션 안 한 화면도 함께 밝아진다.
  // 화면을 하나씩 새 이름으로 고치면서 이 블록을 지워 나갈 것.
  // ========================================================

  @Deprecated('actionPrimary 사용') static const Color primary = green600;
  @Deprecated('green800 사용') static const Color primaryDeep = green800;
  @Deprecated('green300 사용') static const Color primaryLight = green300;
  @Deprecated('surfaceBrand 사용') static const Color primaryPale = green100;
  @Deprecated('actionPrimary 사용') static const Color primaryMuted = green600;

  @Deprecated('coral100 사용') static const Color coral = coral100;
  @Deprecated('accent 사용') static const Color coralDeep = coral600;

  @Deprecated('green300 사용') static const Color mint = green300;
  @Deprecated('green600 사용') static const Color mintDeep = green600;

  @Deprecated('textSecondary 사용 — 대비 미달로 폐기')
  static const Color textTertiary = neutral600;
  @Deprecated('border 사용') static const Color divider = neutral200;
  @Deprecated('border 사용') static const Color cardBorder = neutral200;
  @Deprecated('bg 사용') static const Color appBG = bg;
  @Deprecated('surface 사용') static const Color cardBG = neutral0;

  @Deprecated('actionDanger 사용') static const Color error = actionDanger;
  @Deprecated('textBrand 사용') static const Color info = green600;

  @Deprecated('dataPlastic 사용') static const Color categoryBlue = dataPlastic;
  @Deprecated('dataGeneral 사용') static const Color categoryRed = dataGeneral;
  @Deprecated('dataPaper 사용') static const Color categoryGreen = dataPaper;
  @Deprecated('dataCan 사용') static const Color categoryOrange = dataCan;
  @Deprecated('dataGlass 사용') static const Color categoryPurple = dataGlass;

  @Deprecated('dataPlastic 사용') static const Color chartActivity = dataPlastic;
  @Deprecated('progress 사용') static const Color chartActivityPeak = green600;

  @Deprecated('cardShadow 사용')
  static List<BoxShadow> get cardShadowStrong => sheetShadow;
  @Deprecated('그림자 없는 솔리드 버튼 사용')
  static List<BoxShadow> get buttonShadow => const [
    BoxShadow(
      color: Color(0x1F24302B),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  // ── 그라데이션: 뱃지 획득 모달의 warmGradient 1종만 유지 ──
  // 나머지는 넓은 면을 색으로 채우지 않는다는 v2 원칙과 충돌하므로
  // 별칭으로만 남긴다. 참조처를 정리한 뒤 삭제할 것.

  /// 뱃지 획득 모달 전용. v2에서 유일하게 살아남은 그라데이션.
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [coral100, coral300],
  );

  @Deprecated('솔리드 actionPrimary 사용')
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green500, green600],
  );
  @Deprecated('surfaceBrand 단색 사용')
  static const LinearGradient mintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green100, green200],
  );
  @Deprecated('흰 배경 + 큰 타이포로 대체')
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [green100, neutral0],
  );
  @Deprecated('솔리드 green800 사용')
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green800, green700],
  );
}
