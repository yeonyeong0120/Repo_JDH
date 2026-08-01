// 간격 · 모서리 · 터치 타깃 토큰.
// 4의 배수 8단계만 사용한다. 여기 없는 값(14, 18, 22 등)은 쓰지 않는다.
import 'package:flutter/material.dart';

class Gap {
  Gap._();

  // ── 기본 스케일 ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xl2 = 24;
  static const double xl3 = 32;
  static const double xl4 = 40;

  // ── 레이아웃 ──
  /// 화면 좌우 여백
  static const double screenPad = 20;

  /// 카드 내부 패딩
  static const double cardPad = 20;

  /// 섹션과 섹션 사이
  static const double section = 32;

  /// 섹션 헤더 → 첫 항목
  static const double sectionHead = 12;

  /// 리스트 항목 사이
  static const double listItem = 12;

  /// 스크롤 하단 여백 (바텀 내비 회피)
  static const double navSafe = 96;

  // ── 자주 쓰는 EdgeInsets ──
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: screenPad);
  static const EdgeInsets card = EdgeInsets.all(cardPad);
  static const EdgeInsets listPage = EdgeInsets.fromLTRB(
    screenPad,
    lg,
    screenPad,
    navSafe,
  );

  // ── 간격 위젯 (Column/Row 사이에 끼워 쓰기) ──
  static const Widget h4 = SizedBox(height: xs);
  static const Widget h8 = SizedBox(height: sm);
  static const Widget h12 = SizedBox(height: md);
  static const Widget h16 = SizedBox(height: lg);
  static const Widget h20 = SizedBox(height: xl);
  static const Widget h24 = SizedBox(height: xl2);
  static const Widget h32 = SizedBox(height: xl3);

  static const Widget w4 = SizedBox(width: xs);
  static const Widget w8 = SizedBox(width: sm);
  static const Widget w12 = SizedBox(width: md);
  static const Widget w16 = SizedBox(width: lg);
}

class Radii {
  Radii._();

  /// 아이콘 타일 · 썸네일
  static const double tile = 10;

  /// 카드
  static const double card = 16;

  /// 바텀시트 · 모달
  static const double sheet = 20;

  /// 칩 · FAB
  static const double full = 999;

  static final BorderRadius tileR = BorderRadius.circular(tile);
  static final BorderRadius cardR = BorderRadius.circular(card);
  static final BorderRadius sheetR = BorderRadius.circular(sheet);
  static final BorderRadius fullR = BorderRadius.circular(full);
}

class Touch {
  Touch._();

  /// 최소 터치 타깃. 중장년 기준이라 44가 아닌 48.
  static const double min = 48;

  /// 아이콘 실제 크기 (나머지는 투명 히트영역)
  static const double icon = 24;

  /// 버튼 높이
  static const double button = 52;

  /// 탭 가능한 요소를 48×48 이상으로 보장.
  static Widget target({required Widget child, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.tileR,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: min, minHeight: min),
        child: Center(child: child),
      ),
    );
  }
}
