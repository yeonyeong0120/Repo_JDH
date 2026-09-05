import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:repo_jdh/features/auth/domain/user_profile.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/mypage/domain/profile_detail.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';

/// 사용자 프로필 CRUD
/// Firestore 경로: users/{uid}
class UserService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static User? get _user => FirebaseAuth.instance.currentUser;

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
  ///
  /// [문제 ④] update() → set(merge:true) 로 변경.
  ///   update() 는 문서가 없으면 not-found 예외를 던진다.
  ///   신규 가입자는 닉네임 설정 시점에 아직 users/{uid} 문서가 없을 수 있고,
  ///   이 앱은 '닉네임 설정'이 회원가입 직후 필수 관문이라 반드시 이 경로를 지난다.
  ///   set(merge:true) 는 없으면 생성, 있으면 해당 필드만 덮어써 안전하다.
  static Future<void> updateNickname(String nickname) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다');

    await _db.collection('users').doc(uid).set({
      'nickname': nickname,
      // 기기 시계 대신 서버 시각 — 사용자가 기기 시간을 바꿔도 순서가 안 꼬인다
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 닉네임은 계정 표시명에도 반영 (그룹 피드 작성자명 등에 쓰임)
    await _user?.updateDisplayName(nickname);
  }

  /// 닉네임 중복 확인 (대소문자 구분)
  ///
  /// ⚠️ 주의: 이 메서드는 '다른 사람의' users 문서를 조회한다.
  ///   Firestore 보안 규칙이 본인 문서만 읽도록 돼 있으면 permission-denied 가 뜬다.
  ///   그 경우 nicknames/{nickname} 같은 공개 컬렉션을 따로 두는 방식으로 바꿔야 한다.
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

    await _db.collection('users').doc(uid).set({
      'region': region,
      if (lat != null) 'regionLat': lat,
      if (lng != null) 'regionLng': lng,
    }, SetOptions(merge: true)); // update→set(merge) 로 통일 (문서 없어도 안전)
  }

  /// 마지막 활동 시각 갱신 (홈 진입 시 호출 권장)
  static Future<void> touchLastActive() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // 실패해도 무시 (네트워크 일시 오류 등)
    }
  }

  // ─────────────── 프로필 화면(메뉴 → 프로필)용 ───────────────

  /// 프로필 상세 (Firestore + 계정 정보 + 활동 기반 XP)
  static Future<ProfileDetail> loadProfileDetail() async {
    final uid = _uid;
    // [문제 ③ 관련] 조용히 빈 값을 반환하면 UI 가 "데이터 없음"인지
    //   "로그인 안 됨"인지 구분 못 한다. 예외를 던지고 UI 에서 처리하게 한다.
    if (uid == null) throw StateError('로그인이 필요합니다');

    final user = _user;

    final snap = await _db.collection('users').doc(uid).get();
    final base = ProfileDetail.fromJson(snap.data() ?? {});

    // 활동 횟수 → XP (1회 = 20 XP). 별도 저장 없이 기록에서 계산.
    // ⚠️ [멘토 팁 ③] 이 방식은 프로필 열 때마다 활동 문서를 최대 500건 읽는다.
    //    Firestore 무료 읽기 할당량을 빠르게 소모하므로, 활동 저장 시점에
    //    users/{uid}.xp 를 FieldValue.increment(20) 로 누적해두고
    //    여기선 필드 하나만 읽도록 바꾸는 것을 권장. (아래 TODO)
    // TODO: XP 를 users/{uid}.xp 필드로 이전하여 매 조회 시 500 reads 제거
    int xp = 0;
    try {
      final acts = await ActivityService.getRecentCompleted(limit: 500);
      xp = acts.length * 20;
    } catch (_) {
      // 실패 시 0
    }

    return base.copyWith(
      nickname: base.nickname.isEmpty
          ? (user?.displayName ?? '플로거')
          : base.nickname,
      photoUrl: base.photoUrl ?? user?.photoURL,
      email: user?.email ?? '',
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
    final uid = _uid;
    if (uid == null) return true; // 비로그인 상태면 굳이 띄우지 않음
    final snap = await _db.collection('users').doc(uid).get();
    return (snap.data()?['seenPloggingGuide'] as bool?) ?? false;
  }

  static Future<void> markPloggingGuideSeen() async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'seenPloggingGuide': true,
    }, SetOptions(merge: true));
  }

  /// 체중·성별만 가볍게 조회 (칼로리 계산용). loadProfileDetail() 과 달리
  /// 활동 기록을 다시 읽지 않는다 — 문서 1건 조회로 끝난다.
  static Future<({double? weightKg, String? gender})> loadBodyInfo() async {
    final uid = _uid;
    if (uid == null) return (weightKg: null, gender: null);
    final data = (await _db.collection('users').doc(uid).get()).data();
    return (
      weightKg: (data?['weight'] as num?)?.toDouble(),
      gender: data?['gender'] as String?,
    );
  }

  static Future<void> signOut() {
    BadgeRepo.clear();
    return FirebaseAuth.instance.signOut();
  }

  /// 포인트 적립 (뱃지·활동 등 여러 출처가 공통으로 씀). amount 는 항상 양수로 호출한다.
  static Future<void> addPoints(int amount) async {
    if (amount <= 0) return;
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'points': FieldValue.increment(amount),
    }, SetOptions(merge: true));
  }

  /// 회원 탈퇴 — 프로필 문서 삭제 후 계정 삭제
  /// 마지막 로그인이 오래됐으면 재인증이 필요해 실패할 수 있음
  /// TODO: 하위 컬렉션(activities/detections/badges)은 Cloud Functions 로 정리
  static Future<void> deleteAccount() async {
    final uid = _uid;
    if (uid != null) await _db.collection('users').doc(uid).delete();
    await _user?.delete();
  }
}