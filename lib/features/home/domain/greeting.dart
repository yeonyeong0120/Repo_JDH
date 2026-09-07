/// 홈 인사 문구의 시간대 구분.
enum GreetingSlot { morning, day, evening, lateNight }

/// 인사 문구 1세트. top/mid/hl 은 헤드라인, slot 은 노출 시간대다.
typedef GreetingSet = ({String top, String mid, String hl, GreetingSlot slot});

extension GreetingSlotLabel on GreetingSlot {
  /// 오버라인 'READY' 우측에 표시하는 한글 라벨.
  String get label => switch (this) {
        GreetingSlot.morning => '아침',
        GreetingSlot.day => '낮',
        GreetingSlot.evening => '저녁',
        GreetingSlot.lateNight => '늦은 밤',
      };
}

/// 기기 로컬 시각을 시간대로 환산한다.
/// 03:00~10:59 아침 / 11:00~16:59 낮 / 17:00~20:59 저녁 / 21:00~02:59 늦은 밤
GreetingSlot greetingSlotOf(DateTime now) {
  final h = now.hour;
  if (h >= 3 && h < 11) return GreetingSlot.morning;
  if (h >= 11 && h < 17) return GreetingSlot.day;
  if (h >= 17 && h < 21) return GreetingSlot.evening;
  return GreetingSlot.lateNight;
}
