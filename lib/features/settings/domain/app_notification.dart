import 'package:flutter/material.dart';

/// 알림 종류. 탭 시 이동 대상을 결정한다(F-4).
enum NotificationKind { group, challenge, system }

/// 알림 한 건
class AppNotification {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String time;
  final NotificationKind kind;

  /// 이번 주 묶음처럼 한 단계 죽여 보여줄지 여부
  final bool muted;

  bool unread;

  AppNotification({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
    required this.kind,
    this.muted = false,
  });
}
