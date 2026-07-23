import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:repo_jdh/features/auth/domain/user_profile.dart';
import 'package:repo_jdh/features/mypage/domain/profile_detail.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/core/dev/dev_user.dart';
import 'package:repo_jdh/core/dev/dev_data.dart';

/// 사용자 프로필 CRUD
/// Firestore 경로: users/{uid}
class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 로그인 전이면 개발용 uid 사용 (DevUser.enabled=false 로 끄기)
  static String? get _uid => DevUser.resolve();

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

  // ─────────────── 프로필 화면(메뉴 → 프로필)용 ───────────────

  static User? get _user => FirebaseAuth.instance.currentUser;

  /// 프로필 상세 (Firestore + 계정 정보 + 활동 기반 XP)
  static Future<ProfileDetail> loadProfileDetail() async {
    if (DevData.enabled) return DevData.profile; // 개발용 로컬 더미
    final uid = _uid;
    if (uid == null) return const ProfileDetail();
    final user = _user; // 로그인 전이면 null 일 수 있음

    final snap = await _db.collection('users').doc(uid).get();
    final base = ProfileDetail.fromJson(snap.data() ?? {});

    // 활동 횟수 → XP (1회 = 20 XP). 별도 저장 없이 기록에서 계산.
    // TODO: 활동 외 보상으로도 XP 를 주게 되면 users/{uid}.xp 로 옮길 것
    int xp = 0;
    try {
      final acts = await ActivityService.getRecentCompleted(limit: 500);
      xp = acts.length * 20;
    } catch (_) {
      // 실패 시 0
    }

    return base.copyWith(
      nickname: base.nickname.isEmpty ? DevUser.displayName : base.nickname,
      photoUrl: base.photoUrl ?? user?.photoURL,
      email: DevUser.email,
      xp: xp,
      joinedAt: user?.metadata.creationTime,
    );
  }

  /// 프로필 항목 부분 수정 (넘긴 값만 갱신)
  /// 회원가입 선택 정보 저장에도 사용
  static Future<void> updateProfileFields({
    String? nickname,
    String? gender,
    int? age,
    int? height,
    int? weight,
    String? region,
  }) async {
    if (DevData.enabled) {
      DevData.profile = DevData.profile.copyWith(
        nickname: nickname,
        gender: gender,
        age: age,
        height: height,
        weight: weight,
        region: region,
      );
      return;
    }
    final uid = _uid;
    if (uid == null) return;

    final data = <String, dynamic>{};
    if (nickname != null) data['nickname'] = nickname;
    if (gender != null) data['gender'] = gender;
    if (age != null) data['age'] = age;
    if (height != null) data['height'] = height;
    if (weight != null) data['weight'] = weight;
    if (region != null) data['region'] = region;
    if (data.isEmpty) return;

    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));

    // 닉네임은 계정 표시명에도 반영 (그룹 피드 작성자명 등에 쓰임)
    if (nickname != null) await _user?.updateDisplayName(nickname);
  }

  /// 프로필 사진 업로드 → Storage 저장 후 photoUrl 반영
  /// 반환값: 저장된 이미지 URL (실패 시 null)
  static Future<String?> uploadProfilePhoto(File file) async {
    final uid = _uid;
    if (uid == null) return null;

    final ref = FirebaseStorage.instance.ref('profiles/$uid.jpg');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await _db.collection('users').doc(uid).set({
      'photoUrl': url,
    }, SetOptions(merge: true));
    await _user?.updatePhotoURL(url);
    return url;
  }

  /// 플로깅 가이드 모달을 이미 봤는지 (첫 1회만 노출)
  static Future<bool> hasSeenPloggingGuide() async {
    if (DevData.enabled) return false; // 더미 모드에서는 매번 확인 가능
    final uid = _uid;
    if (uid == null) return true; // 비로그인 상태면 굳이 띄우지 않음
    final snap = await _db.collection('users').doc(uid).get();
    return (snap.data()?['seenPloggingGuide'] as bool?) ?? false;
  }

  static Future<void> markPloggingGuideSeen() async {
    if (DevData.enabled) return;
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'seenPloggingGuide': true,
    }, SetOptions(merge: true));
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();

  /// 회원 탈퇴 — 프로필 문서 삭제 후 계정 삭제
  /// 마지막 로그인이 오래됐으면 재인증이 필요해 실패할 수 있음
  /// TODO: 하위 컬렉션(activities/detections/badges)은 Cloud Functions 로 정리
  static Future<void> deleteAccount() async {
    final uid = _uid;
    if (uid != null) await _db.collection('users').doc(uid).delete();
    await _user?.delete();
  }
}
