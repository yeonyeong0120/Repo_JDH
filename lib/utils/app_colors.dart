// 앱 전체에 적용될 테마(색상, 폰트) 관리
import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF244EA2);
  static const Color secondary = Color(0xFF70BBF8);
  static const Color neutralsStandard = Color(0xFF272727);
  static const Color appBG = Color(0xFFFCFCFC);
  
  // 만약 투명도가 필요한 경우 이전의 withOpacity 대신 withValues를 사용
  // static Color primaryWithAlpha = const Color(0xFF244EA2).withValues(alpha: 0.8);
}