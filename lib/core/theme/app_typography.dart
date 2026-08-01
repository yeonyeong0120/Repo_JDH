// 타이포 스케일.
// 굵기는 400/500/600/700/800 다섯 단계만 사용하고,
// 800(display·title1)은 화면당 1~2회로 제한한다.
// 중장년 사용자 기준: 본문 하한 15sp, 행간 1.6 이상.
import 'package:flutter/material.dart';

class AppType {
  AppType._();

  static const String fontFamily = 'Pretendard';

  /// 메인 수치, 총 포인트, 트래킹 타이머. 34 / 800 / −2.5% / 1.25
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.85,
    height: 1.25,
  );

  /// 화면 제목 (화면당 1개). 26 / 800 / −2% / 1.3
  static const TextStyle title1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.52,
    height: 1.3,
  );

  /// 섹션 헤더. 20 / 700 / −1.5% / 1.35
  static const TextStyle title2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.35,
  );

  /// 카드 · 리스트 항목 제목. 17 / 700 / −1% / 1.4
  static const TextStyle title3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.17,
    height: 1.4,
  );

  /// 읽어야 하는 본문 · 안내문. 17 / 400 / 1.6
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  /// 설명 · 부가 정보. 15 / 400 / 1.6 — 본문 하한선
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  /// 버튼 · 탭 · 폼 라벨. 15 / 600 / 1.45
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.45,
  );

  /// 타임스탬프 · 메타. 13 / 500 / 1.5 — 최소 크기
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  /// 카드 상단 분류 라벨 (색 지정 필수). 12 / 700 / +6% / 1.4
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.72,
    height: 1.4,
  );

  /// 바텀 내비 라벨. 12 / 600
  static const TextStyle navLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
}

/// 수치 전용 조판.
/// 고정폭 숫자(tabular)로 자릿수가 바뀌어도 폭이 흔들리지 않게 한다.
/// 예) Text('2,000', style: AppType.title1.tabular)
extension TabularStyle on TextStyle {
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

/// 시스템 글꼴 확대 대응.
/// 중장년 사용자는 기기 글꼴을 키워 쓰는 비율이 높지만,
/// 무제한 확대는 레이아웃을 깨뜨리므로 1.0~1.3으로 제한한다.
/// MaterialApp의 builder에서 감싸 사용.
class TextScaleClamp extends StatelessWidget {
  final Widget child;
  final double min;
  final double max;

  const TextScaleClamp({
    super.key,
    required this.child,
    this.min = 1.0,
    this.max = 1.3,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(
          minScaleFactor: min,
          maxScaleFactor: max,
        ),
      ),
      child: child,
    );
  }
}
