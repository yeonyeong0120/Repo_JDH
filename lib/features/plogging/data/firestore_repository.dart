import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repo_jdh/core/dev/dev_user.dart';
import 'package:repo_jdh/core/dev/dev_data.dart';

class FirestoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _currentUid => DevUser.resolve();

  CollectionReference<Map<String, dynamic>>? get _detectionsRef {
    final uid = _currentUid;
    if (uid == null) {
      print('⚠️ [Firestore] 로그인된 사용자가 없습니다');
      return null;
    }
    return _firestore.collection('users').doc(uid).collection('detections');
  }

  DocumentReference<Map<String, dynamic>>? get _totalsDocRef {
    final uid = _currentUid;
    if (uid == null) {
      print('⚠️ [Firestore] 로그인된 사용자가 없습니다');
      return null;
    }
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('totals')
        .doc('main');
  }

  /// 1. 등록 기록 저장
  Future<void> saveDetection(
    Map<String, int> counts, {
    String? imageUrl,
    Map<String, dynamic>? location,
  }) async {
    if (DevData.enabled) return; // 더미 모드에서는 저장 생략
    final detectionsRef = _detectionsRef;
    if (detectionsRef == null) {
      print('❌ 로그인 안 됨 — 등록 기록 저장 스킵');
      return;
    }

    try {
      await detectionsRef.add({
        'timestamp': FieldValue.serverTimestamp(),
        'plastic': counts['plastic'] ?? 0,
        'can': counts['can'] ?? 0,
        'paper': counts['paper'] ?? 0,
        'glass': counts['glass'] ?? 0,
        'trash': counts['trash'] ?? 0,
        'imageUrl': imageUrl ?? '',
        'latitude': location?['latitude'],
        'longitude': location?['longitude'],
        'address': location?['address'] ?? '',
      });
      print('✅ 등록 기록 저장 완료 (user: ${_currentUid?.substring(0, 6)}...)');
    } catch (e) {
      print('❌ 등록 기록 저장 실패: $e');
      rethrow;
    }
  }

  /// 2. 누적 카운트 업데이트
  Future<void> updateTotalCounts(
    Map<String, int> totalCounts,
    int registerCount,
  ) async {
    final totalsDoc = _totalsDocRef;
    if (totalsDoc == null) {
      print('❌ 로그인 안 됨 — 누적 카운트 업데이트 스킵');
      return;
    }

    try {
      await totalsDoc.set({
        'plastic': totalCounts['plastic'] ?? 0,
        'can': totalCounts['can'] ?? 0,
        'paper': totalCounts['paper'] ?? 0,
        'glass': totalCounts['glass'] ?? 0,
        'trash': totalCounts['trash'] ?? 0,
        'register_count': registerCount,
        'last_updated': FieldValue.serverTimestamp(),
      });
      print('✅ 누적 카운트 업데이트 완료');
    } catch (e) {
      print('❌ 누적 카운트 업데이트 실패: $e');
      rethrow;
    }
  }

  /// 3. 누적 카운트 불러오기
  Future<Map<String, dynamic>?> getTotalCounts() async {
    final totalsDoc = _totalsDocRef;
    if (totalsDoc == null) {
      print('❌ 로그인 안 됨 — 누적 카운트 조회 불가');
      return null;
    }

    try {
      final doc = await totalsDoc.get();
      if (doc.exists) {
        final data = doc.data();
        print('✅ 누적 카운트 불러오기 완료: $data');
        return data;
      } else {
        print('ℹ️ 저장된 데이터 없음 (첫 실행 또는 신규 사용자)');
        return null;
      }
    } catch (e) {
      print('❌ 누적 카운트 불러오기 실패: $e');
      return null;
    }
  }

  /// 4. 등록 기록 모두 가져오기
  Future<List<Map<String, dynamic>>> getAllDetections() async {
    final detectionsRef = _detectionsRef;
    if (detectionsRef == null) {
      print('❌ 로그인 안 됨 — 등록 기록 조회 불가');
      return [];
    }

    try {
      final snapshot = await detectionsRef
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('❌ 등록 기록 불러오기 실패: $e');
      return [];
    }
  }

  /// 5. 누적 카운트 초기화
  Future<void> resetTotalCounts() async {
    final totalsDoc = _totalsDocRef;
    if (totalsDoc == null) {
      print('❌ 로그인 안 됨 — 초기화 불가');
      return;
    }

    try {
      await totalsDoc.set({
        'plastic': 0,
        'can': 0,
        'paper': 0,
        'glass': 0,
        'trash': 0,
        'register_count': 0,
        'last_updated': FieldValue.serverTimestamp(),
      });
      print('✅ 누적 카운트 초기화 완료');
    } catch (e) {
      print('❌ 누적 카운트 초기화 실패: $e');
      rethrow;
    }
  }
}
