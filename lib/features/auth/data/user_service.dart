import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repo_jdh/features/auth/domain/user_profile.dart';

/// 사용자 프로필 CRUD
/// Firestore 경로: users/{uid}
class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// 현재 로그인 사용자의 프로필 조회
  static Future<UserProfile?> getCurrentProfile() async {
    final uid = _uid;
    if (uid == null) return null;

    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;

    final data = snap.data()!;
    data['uid'] = uid;
    return UserProfile.fromJson(data);
  }

  /// 프로필 존재 여부
  static Future<bool> profileExists() async {
    final uid = _uid;
    if (uid == null) return false;
    final snap = await _db.collection('users').doc(uid).get();
    return snap.exists;
  }

  /// 새 프로필 생성 (회원가입 직후 1회)
  /// 이미 있으면 merge로 누락된 필드만 보완
  static Future<void> createProfile({
    required String email,
    required String nickname,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다');

    final now = DateTime.now();
    final profile = UserProfile(
      uid: uid,
      email: email,
      nickname: nickname,
      createdAt: now,
      lastActiveAt: now,
    );

    await _db
        .collection('users')
        .doc(uid)
        .set(profile.toJson(), SetOptions(merge: true));
  }

  /// 닉네임만 업데이트
  static Future<void> updateNickname(String nickname) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다');

    await _db.collection('users').doc(uid).update({
      'nickname': nickname,
      'lastActiveAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// 닉네임 중복 확인 (대소문자 구분)
  /// 정확히 같은 닉네임이 이미 있으면 true
  static Future<bool> isNicknameTaken(String nickname) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) return false;

    final query = await _db
        .collection('users')
        .where('nickname', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;

    // 본인이 이미 그 닉네임을 쓰고 있는 경우는 사용 가능
    return query.docs.first.id != _uid;
  }

  /// 지역 정보 업데이트
  static Future<void> updateRegion({
    required String region,
    double? lat,
    double? lng,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    await _db.collection('users').doc(uid).update({
      'region': region,
      if (lat != null) 'regionLat': lat,
      if (lng != null) 'regionLng': lng,
    });
  }

  /// 마지막 활동 시각 갱신 (홈 진입 시 호출 권장)
  static Future<void> touchLastActive() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'lastActiveAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (_) {
      // 실패해도 무시 (네트워크 일시 오류 등)
    }
  }
}