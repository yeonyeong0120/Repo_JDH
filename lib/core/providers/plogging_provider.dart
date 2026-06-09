import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/plogging/data/firestore_repository.dart';

/// FirestoreRepository 인스턴스 Provider
final firestoreRepositoryProvider = Provider<FirestoreRepository>((ref) {
  return FirestoreRepository();
});

/// 플로깅 상태 데이터 클래스
class PloggingState {
  final Map<String, int> totalCounts;
  final int registerCount;
  final bool isLoading;

  const PloggingState({
    this.totalCounts = const {
      'plastic': 0,
      'can': 0,
      'paper': 0,
      'glass': 0,
      'trash': 0,
    },
    this.registerCount = 0,
    this.isLoading = true,
  });

  PloggingState copyWith({
    Map<String, int>? totalCounts,
    int? registerCount,
    bool? isLoading,
  }) {
    return PloggingState(
      totalCounts: totalCounts ?? this.totalCounts,
      registerCount: registerCount ?? this.registerCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 플로깅 상태 관리 Notifier
class PloggingNotifier extends StateNotifier<PloggingState> {
  final FirestoreRepository _firestoreRepository;

  PloggingNotifier(this._firestoreRepository) : super(const PloggingState()) {
    load();
  }

  /// Firestore에서 누적 데이터 불러오기
  Future<void> load() async {
    final data = await _firestoreRepository.getTotalCounts();
    if (data != null) {
      state = state.copyWith(
        totalCounts: {
          'plastic': data['plastic'] ?? 0,
          'can': data['can'] ?? 0,
          'paper': data['paper'] ?? 0,
          'glass': data['glass'] ?? 0,
          'trash': data['trash'] ?? 0,
        },
        registerCount: data['register_count'] ?? 0,
        isLoading: false,
      );
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 새 쓰레기 카운트 추가 + Firestore 업데이트
  Future<void> addCounts(Map<String, int> newCounts) async {
    final updated = Map<String, int>.from(state.totalCounts);
    newCounts.forEach((key, value) {
      if (updated.containsKey(key)) {
        updated[key] = (updated[key] ?? 0) + value;
      }
    });
    final newRegisterCount = state.registerCount + 1;

    state = state.copyWith(
      totalCounts: updated,
      registerCount: newRegisterCount,
    );

    await _firestoreRepository.updateTotalCounts(updated, newRegisterCount);
  }

  /// 누적 카운트 초기화
  Future<void> reset() async {
    await _firestoreRepository.resetTotalCounts();
    state = state.copyWith(
      totalCounts: {
        'plastic': 0,
        'can': 0,
        'paper': 0,
        'glass': 0,
        'trash': 0,
      },
      registerCount: 0,
    );
  }
}

/// 플로깅 상태 Provider
final ploggingProvider =
    StateNotifierProvider<PloggingNotifier, PloggingState>((ref) {
  return PloggingNotifier(ref.read(firestoreRepositoryProvider));
});