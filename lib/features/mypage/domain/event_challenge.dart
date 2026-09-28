import 'package:flutter/material.dart';

/// 기간 한정 이벤트 챌린지
///
/// 뱃지에서 파생되는 상시 챌린지와 달리 운영이 기간을 정해 여는 챌린지다.
class EventChallenge {
  final String id;
  final String title;
  final IconData icon;
  final int current;
  final int total;
  final int points;
  final DateTime startsAt;
  final DateTime endsAt;

  const EventChallenge({
    required this.id,
    required this.title,
    required this.icon,
    required this.current,
    required this.total,
    required this.points,
    required this.startsAt,
    required this.endsAt,
  });

  bool get done => current >= total;

  bool isActiveOn(DateTime now) =>
      !now.isBefore(startsAt) && !now.isAfter(endsAt);
}
