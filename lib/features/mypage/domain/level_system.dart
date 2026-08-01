/// 레벨/XP 계산 유틸 (등차 방식).
///
/// 규칙:
///   - XP 는 '활동 1회 = 20 XP' (기존 UserService 계산과 동일)
///   - 레벨 n → n+1 에 필요한 XP = _baseXp + (n-1) * _stepXp
///     예) 1→2: 100, 2→3: 150, 3→4: 200 ...
///
/// 숫자를 바꾸려면 아래 두 상수만 고치면 된다. (팀 논의 후 조정 가능)
class LevelSystem {
  // 레벨 1→2 에 필요한 XP
  static const int _baseXp = 100;
  // 레벨이 오를 때마다 필요 XP 증가폭
  static const int _stepXp = 50;

  /// 특정 레벨(n)에서 다음 레벨(n+1)로 가는 데 필요한 XP
  static int xpToNext(int level) => _baseXp + (level - 1) * _stepXp;

  /// 총 XP → 레벨 정보로 변환
  ///
  /// 계단을 하나씩 올라가며 남은 XP 를 깎는다.
  ///   현재레벨 / 이번 레벨에서 모은 XP / 이번 레벨에 필요한 XP
  static LevelInfo of(int totalXp) {
    int level = 1;
    int remaining = totalXp < 0 ? 0 : totalXp;

    // 다음 레벨 필요량보다 많이 가지고 있으면 레벨업하며 깎아나감
    while (remaining >= xpToNext(level)) {
      remaining -= xpToNext(level);
      level++;
    }

    final need = xpToNext(level); // 이번 레벨 → 다음 레벨 필요량
    return LevelInfo(
      level: level,
      currentXp: remaining, // 이번 레벨에서 모은 양 (예: 80)
      neededXp: need, // 이번 레벨에서 필요한 양 (예: 100)
      remainingXp: need - remaining, // 다음 레벨까지 남은 양 (예: 20)
    );
  }
}

/// 레벨 계산 결과
class LevelInfo {
  final int level; // 현재 레벨
  final int currentXp; // 이번 레벨에서 모은 XP (예: 80)
  final int neededXp; // 이번 레벨에 필요한 총 XP (예: 100)
  final int remainingXp; // 다음 레벨까지 남은 XP (예: 20)

  const LevelInfo({
    required this.level,
    required this.currentXp,
    required this.neededXp,
    required this.remainingXp,
  });

  /// 진행률 0.0~1.0 (진행바용)
  double get progress => neededXp == 0 ? 0.0 : currentXp / neededXp;
}