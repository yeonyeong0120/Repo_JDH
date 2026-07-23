import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 진행 중인 플로깅 세션의 실측값
/// 트래킹 화면에서 갱신 → 정산 화면 / 뱃지 판정에서 사용
class TrackingState {
  final bool running;
  final DateTime? startedAt;
  final int elapsedSeconds; // 경과 시간(초)
  final double distanceMeters; // 누적 이동 거리(m)

  const TrackingState({
    this.running = false,
    this.startedAt,
    this.elapsedSeconds = 0,
    this.distanceMeters = 0,
  });

  TrackingState copyWith({
    bool? running,
    DateTime? startedAt,
    int? elapsedSeconds,
    double? distanceMeters,
  }) {
    return TrackingState(
      running: running ?? this.running,
      startedAt: startedAt ?? this.startedAt,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
    );
  }

  double get distanceKm => distanceMeters / 1000;

  /// TODO: 만보기(pedometer) 붙이면 실제 걸음수로 교체. 지금은 거리 환산.
  int get steps => (distanceKm * 1400).round();

  /// TODO: 체중 기반 계산으로 교체. 지금은 거리 환산(1km ≈ 60kcal).
  int get kcal => (distanceKm * 60).round();

  /// '06:12' 형식 (분:초) — 1시간 넘으면 '1:02:33'
  String get durationText {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  String get distanceText => distanceKm.toStringAsFixed(2);
}

class TrackingNotifier extends StateNotifier<TrackingState> {
  TrackingNotifier() : super(const TrackingState());

  // 로컬 저장 키 (강제 종료 대비 — Firestore 는 활동 종료 시에만 기록)
  static const _kRunning = 'tracking_running';
  static const _kStartedAt = 'tracking_started_at';
  static const _kSeconds = 'tracking_seconds';
  static const _kMeters = 'tracking_meters';

  int _ticksSinceSave = 0;

  /// 트래킹 시작 (기존 값 초기화)
  void start() {
    state = TrackingState(running: true, startedAt: DateTime.now());
    _persist();
  }

  /// 강제 종료 후 이어하기 — 저장된 값으로 복원
  void resume(TrackingState saved) {
    state = saved.copyWith(running: true);
    _persist();
  }

  /// 저장된 진행 중 세션 불러오기 (없으면 null)
  static Future<TrackingState?> loadSaved() async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_kRunning) ?? false)) return null;
    final startedMs = p.getInt(_kStartedAt);
    return TrackingState(
      running: false, // 이어할지는 사용자가 선택
      startedAt: startedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startedMs),
      elapsedSeconds: p.getInt(_kSeconds) ?? 0,
      distanceMeters: p.getDouble(_kMeters) ?? 0,
    );
  }

  /// 저장된 세션 삭제 (정상 종료 · 이어하기 거절 시)
  static Future<void> clearSaved() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kRunning);
    await p.remove(_kStartedAt);
    await p.remove(_kSeconds);
    await p.remove(_kMeters);
  }

  Future<void> _persist() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kRunning, state.running);
      await p.setInt(
        _kStartedAt,
        (state.startedAt ?? DateTime.now()).millisecondsSinceEpoch,
      );
      await p.setInt(_kSeconds, state.elapsedSeconds);
      await p.setDouble(_kMeters, state.distanceMeters);
    } catch (_) {
      // 저장 실패해도 트래킹은 계속
    }
  }

  /// 1초마다 호출 — 경과 시간 갱신
  void tick() {
    if (!state.running) return;
    state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    // 매초 디스크에 쓰면 부담이라 10초에 한 번만 저장
    if (++_ticksSinceSave >= 10) {
      _ticksSinceSave = 0;
      _persist();
    }
  }

  /// 위치 이동분 누적 (m)
  void addDistance(double meters) {
    if (!state.running || meters <= 0) return;
    state = state.copyWith(distanceMeters: state.distanceMeters + meters);
    _persist();
  }

  /// 트래킹 종료 (값은 정산 화면에서 읽을 수 있게 유지)
  void stop() {
    state = state.copyWith(running: false);
    clearSaved(); // 정상 종료 → 복구 대상 아님
  }

  /// 정산까지 끝난 뒤 초기화
  void reset() {
    state = const TrackingState();
    clearSaved();
  }
}

final trackingProvider = StateNotifierProvider<TrackingNotifier, TrackingState>(
  (ref) {
    return TrackingNotifier();
  },
);
