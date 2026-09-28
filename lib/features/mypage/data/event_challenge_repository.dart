import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/features/mypage/domain/event_challenge.dart';

/// 이벤트 챌린지 저장소
///
/// 주의: 운영 도구·서버가 아직 없다. 아래 목록은 시안을 재현하기 위한 목업이며
/// 진행률도 고정값이다. 서버가 생기면 이 클래스 안쪽만 교체한다.
class EventChallengeRepository {
  EventChallengeRepository._();

  /// 지금 열려 있는 이벤트 챌린지. 기간은 이번 달 한 달로 잡는다.
  static List<EventChallenge> active() {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final last = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return [
      EventChallenge(
        id: 'rain_${now.year}_${now.month}',
        title: '${now.month}월 우비 챌린지',
        icon: TablerIcons.cloudRain,
        current: 2,
        total: 3,
        points: 300,
        startsAt: first,
        endsAt: last,
      ),
    ].where((e) => e.isActiveOn(now)).toList();
  }
}
