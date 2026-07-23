import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/core/dev/dev_user.dart';
import 'package:repo_jdh/core/dev/dev_data.dart';

/// 그룹 CRUD + 피드
/// Firestore 구조
///   groups/{groupId}                 그룹 정보
///   groups/{groupId}/members/{uid}   멤버
///   groups/{groupId}/posts/{postId}  피드 글(인증샷)
///   users/{uid}.groupId              내 그룹 (1인 1그룹)
///   users/{uid}.shareCount           인증샷 공유 누적 횟수 (뱃지 판정용)
class GroupService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get _uid => DevUser.resolve();
  static String get _userName => DevUser.displayName;
  static String? get _userPhoto => FirebaseAuth.instance.currentUser?.photoURL;

  static CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');
  static DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = _uid;
    return uid == null ? null : _db.collection('users').doc(uid);
  }

  // ───────────────────────── 소속 조회 ─────────────────────────

  /// 내가 속한 그룹 id (없으면 null) — 1인 1그룹
  static Future<String?> myGroupId() async {
    if (DevData.enabled) return DevData.myGroup?.id;
    final doc = _userDoc();
    if (doc == null) return null;
    final snap = await doc.get();
    return snap.data()?['groupId'] as String?;
  }

  static Future<bool> isInGroup() async => (await myGroupId()) != null;

  /// 내 그룹 정보
  static Future<Group?> myGroup() async {
    if (DevData.enabled) return DevData.myGroup;
    final id = await myGroupId();
    if (id == null) return null;
    return getGroup(id);
  }

  static Future<Group?> getGroup(String groupId) async {
    if (DevData.enabled) {
      if (DevData.myGroup?.id == groupId) return DevData.myGroup;
      for (final x in DevData.otherGroups) {
        if (x.id == groupId) return x;
      }
      return null;
    }
    final snap = await _groups.doc(groupId).get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    data['id'] = snap.id;
    return Group.fromJson(data);
  }

  // ───────────────────────── 목록 / 검색 ─────────────────────────

  /// 내 그룹을 제외한 다른 그룹들 (최신순)
  static Future<List<Group>> otherGroups({int limit = 20}) async {
    if (DevData.enabled) return DevData.otherGroups;
    final mine = await myGroupId();
    final query = await _groups
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return query.docs.where((d) => d.id != mine).map((d) {
      final data = d.data();
      data['id'] = d.id;
      return Group.fromJson(data);
    }).toList();
  }

  /// 이름으로 검색 (접두 일치)
  /// TODO: 부분 검색이 필요해지면 검색 색인(Algolia 등) 또는 name 소문자 필드 추가
  static Future<List<Group>> search(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return [];
    if (DevData.enabled) {
      return DevData.otherGroups.where((x) => x.name.contains(k)).toList();
    }
    final query = await _groups
        .orderBy('name')
        .startAt([k])
        .endAt(['$k\uf8ff'])
        .limit(20)
        .get();

    return query.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return Group.fromJson(data);
    }).toList();
  }

  // ───────────────────────── 생성 / 가입 / 탈퇴 ─────────────────────────

  /// 그룹 생성 + 자동 가입. 이미 그룹이 있으면 예외.
  static Future<String> createGroup({
    required String name,
    String region = '',
    String intro = '',
    String? imageUrl,
  }) async {
    if (DevData.enabled) {
      DevData.myGroup = Group(
        id: 'g_new',
        name: name,
        region: region,
        intro: intro,
        memberCount: 1,
        ownerUid: 'dev_user',
        createdAt: DateTime.now(),
      );
      return 'g_new';
    }
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다');
    if (await isInGroup()) throw Exception('이미 그룹에 가입되어 있습니다');

    final ref = await _groups.add({
      'name': name,
      'region': region,
      'intro': intro,
      'imageUrl': imageUrl,
      'memberCount': 1,
      'todayActiveCount': 0,
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await ref.collection('members').doc(uid).set({
      'joinedAt': FieldValue.serverTimestamp(),
      'role': 'owner',
      'userName': _userName,
    });
    await _userDoc()!.set({'groupId': ref.id}, SetOptions(merge: true));

    return ref.id;
  }

  /// 그룹 가입. 이미 다른 그룹 소속이면 예외 (GRP-04 차단과 동일 규칙).
  static Future<void> joinGroup(String groupId) async {
    if (DevData.enabled) {
      final i = DevData.otherGroups.indexWhere((x) => x.id == groupId);
      if (i >= 0) {
        DevData.myGroup = DevData.otherGroups.removeAt(i);
      }
      return;
    }
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다');
    if (await isInGroup()) throw Exception('이미 그룹에 가입되어 있습니다');

    final ref = _groups.doc(groupId);
    final batch = _db.batch();
    batch.set(ref.collection('members').doc(uid), {
      'joinedAt': FieldValue.serverTimestamp(),
      'role': 'member',
      'userName': _userName,
    });
    batch.update(ref, {'memberCount': FieldValue.increment(1)});
    batch.set(_userDoc()!, {'groupId': groupId}, SetOptions(merge: true));
    await batch.commit();
  }

  /// 그룹 탈퇴
  static Future<void> leaveGroup(String groupId) async {
    if (DevData.enabled) {
      final g = DevData.myGroup;
      if (g != null) DevData.otherGroups.insert(0, g);
      DevData.myGroup = null;
      return;
    }
    final uid = _uid;
    if (uid == null) return;

    final ref = _groups.doc(groupId);
    final batch = _db.batch();
    batch.delete(ref.collection('members').doc(uid));
    batch.update(ref, {'memberCount': FieldValue.increment(-1)});
    batch.set(_userDoc()!, {'groupId': null}, SetOptions(merge: true));
    await batch.commit();
  }

  /// 멤버 목록 (미리보기용)
  static Future<List<String>> memberNames(
    String groupId, {
    int limit = 8,
  }) async {
    if (DevData.enabled) return DevData.memberNames;
    final snap = await _groups
        .doc(groupId)
        .collection('members')
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => (d.data()['userName'] as String?) ?? '')
        .toList();
  }

  // ───────────────────────── 피드 ─────────────────────────

  /// 피드 글 목록 (최신순)
  static Future<List<GroupPost>> posts(String groupId, {int limit = 30}) async {
    if (DevData.enabled) return DevData.posts;
    final uid = _uid ?? '';
    final snap = await _groups
        .doc(groupId)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return GroupPost.fromJson(data, uid);
    }).toList();
  }

  /// 실시간 피드 (채팅방처럼 바로 반영하고 싶을 때)
  static Stream<List<GroupPost>> watchPosts(String groupId) {
    final uid = _uid ?? '';
    return _groups
        .doc(groupId)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return GroupPost.fromJson(data, uid);
          }).toList(),
        );
  }

  /// 인증샷 공유 (정산 → 찍기/갤러리에서 호출)
  /// 공유 횟수를 users/{uid}.shareCount 에 누적 → 뱃지 'share_10' 판정에 사용
  static Future<void> addPost({
    required String groupId,
    String? imageUrl,
    required String distance,
    required int trash,
    required String duration,
  }) async {
    if (DevData.enabled) return;
    final uid = _uid;
    if (uid == null) return;

    final batch = _db.batch();
    batch.set(_groups.doc(groupId).collection('posts').doc(), {
      'uid': uid,
      'userName': _userName,
      'photoUrl': _userPhoto,
      'imageUrl': imageUrl,
      'distance': distance,
      'trash': trash,
      'duration': duration,
      'likes': 0,
      'likedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_userDoc()!, {
      'shareCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// 좋아요 토글 (내 글에는 사용하지 않음)
  static Future<void> toggleLike({
    required String groupId,
    required String postId,
    required bool liked, // 현재 상태
  }) async {
    if (DevData.enabled) return; // 화면 상태만 바뀜
    final uid = _uid;
    if (uid == null) return;

    await _groups.doc(groupId).collection('posts').doc(postId).update({
      'likedBy': liked
          ? FieldValue.arrayRemove([uid])
          : FieldValue.arrayUnion([uid]),
      'likes': FieldValue.increment(liked ? -1 : 1),
    });
  }

  // ───────────────────────── 뱃지 판정용 카운터 ─────────────────────────

  /// (그룹 가입 여부, 인증샷 공유 횟수)
  static Future<({bool joined, int shareCount})> badgeCounters() async {
    if (DevData.enabled) {
      return (joined: DevData.myGroup != null, shareCount: 3);
    }
    final doc = _userDoc();
    if (doc == null) return (joined: false, shareCount: 0);
    final data = (await doc.get()).data() ?? {};
    return (
      joined: data['groupId'] != null,
      shareCount: (data['shareCount'] as num?)?.toInt() ?? 0,
    );
  }
}
