import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AUTO-02 공유 완료 팝업용 "방금 공유한 그룹명" 전달자.
/// 정산에서 찍기/갤러리로 공유하면 여기에 그룹명을 담고 홈으로 이동.
/// 홈이 이 값을 읽어 하단 카드 팝업을 1회 띄운 뒤 즉시 비운다(중복 방지).
class SharedGroupNotifier extends StateNotifier<String?> {
  SharedGroupNotifier() : super(null);

  /// 공유 완료 신호 저장 (그룹명)
  void set(String groupName) => state = groupName;

  /// 소비 후 비우기 — 값을 반환하고 null로 리셋
  String? consume() {
    final v = state;
    state = null;
    return v;
  }

  void clear() => state = null;
}

final sharedGroupProvider = StateNotifierProvider<SharedGroupNotifier, String?>(
  (ref) => SharedGroupNotifier(),
);
