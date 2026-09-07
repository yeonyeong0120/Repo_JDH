import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:repo_jdh/features/community/domain/group.dart';

/// 그룹 CRUD + 피드
/// Firestore 구조
///   groups/{groupId}                 그룹 정보
///   groups/{groupId}/members/{uid}   멤버
///   groups/{groupId}/posts/{postId}  피드 글(인증샷)
///   users/{uid}.groupId              내 그룹 (1인 1그룹)
///   users/{uid}.shareCount           인증샷 공유 누적 횟수 (뱃지 판정용)
class GroupService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  static String? get _userPhoto => FirebaseAuth.instance.currentUser?.photoURL;

  /// 표시 이름 — Firestore 의 실제 닉네임을 우선 사용한다.
  ///
  /// FirebaseAuth 의 displayName 은 이메일 가입 시 비어 있을 수 있어,
  /// 그 값만 쓰면 멤버 목록에 이름이 빈칸으로 저장된다.
  /// (users/{uid}.nickname 이 앱에서 실제로 쓰는 닉네임)
  static Future<String> _resolveUserName() async {
    final doc = _userDoc();
    if (doc != null) {
      try {
        final nickname = (await doc.get()).data()?['nickname'] as String?;
        if (nickname != null && nickname.trim().isNotEmpty) return nickname;
      } catch (_) {
        // 읽기 실패 시 아래 대체값 사용
      }
    }
    final authName = FirebaseAuth.instance.currentUser?.displayName;
    if (authName != null && authName.trim().isNotEmpty) return authName;
    return '플로거'; // 최후 대체값 (빈칸으로 저장되지 않게)
  }

  /// 생성자/조회자의 지역 — Firestore users/{uid}.region 을 그대로 쓴다.
  /// (그룹 region과 같은 형식이어야 매칭되므로 별도로 가공하지 않는다)
  static Future<String> _resolveUserRegion() async {
    final doc = _userDoc();
    if (doc == null) return '';
    try {
      final region = (await doc.get()).data()?['region'] as String?;
      return region?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 내(로그인된 사용자)의 지역 — users/{uid}.region.
  /// 프레젠테이션 레이어(그룹 만들기 미리보기 등)에서 쓰기 위한 공개 래퍼.
  static Future<String> myRegion() => _resolveUserRegion();

  static CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');
  static DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = _uid;
    return uid == null ? null : _db.collection('users').doc(uid);
  }

  // ───────────────────────── 소속 조회 ─────────────────────────

  /// 내가 속한 그룹 id (없으면 null) — 1인 1그룹
  ///
  /// users/{uid}.groupId 가 이미 삭제된 그룹을 가리키는 경우(유령 groupId)가 있다.
  /// 값만 보고 판단하면 화면은 '미가입'인데 가입·생성은 막히는 상태가 된다.
  /// 그룹 문서가 실제로 있는지까지 확인하고, 유령이면 그 자리에서 값을 비운다.
  static Future<String?> myGroupId() async {
    final doc = _userDoc();
    if (doc == null) return null;
    final snap = await doc.get();
    final id = snap.data()?['groupId'] as String?;
    if (id == null) return null;

    if ((await _groups.doc(id).get()).exists) return id;

    // 가리키는 그룹이 없다 → 미가입으로 보고 유령 값을 정리한다.
    // 정리에 실패해도 '미가입' 판단은 그대로 유지한다.
    debugPrint('[그룹] 유령 groupId 정리: $id');
    try {
      await doc.set({'groupId': null}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[그룹] 유령 groupId 정리 실패: $e');
    }
    return null;
  }

  static Future<bool> isInGroup() async => (await myGroupId()) != null;

  /// 현재 사용자의 이 그룹 내 역할 ('owner' | 'member' | null).
  ///
  /// 그룹장 판정의 권위 소스 — 생성 시 'owner', 가입 시 'member'로 기록된다.
  /// ownerUid 비교보다 안전하다(과거 데이터·엣지에서 ownerUid가 비어 있을 수 있음).
  static Future<String?> myRole(String groupId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _groups
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .get();
      return doc.data()?['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 현재 사용자가 이 그룹의 그룹장인지 (role == 'owner').
  static Future<bool> isLeaderOf(String groupId) async =>
      (await myRole(groupId)) == 'owner';

  /// 내 그룹 정보
  static Future<Group?> myGroup() async {
    final id = await myGroupId();
    if (id == null) return null;
    return getGroup(id);
  }

  static Future<Group?> getGroup(String groupId) async {
    final snap = await _groups.doc(groupId).get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    data['id'] = snap.id;
    return Group.fromJson(data);
  }

  // ───────────────────────── 목록 / 검색 ─────────────────────────

  /// 내 그룹을 제외한 다른 그룹들 (최신순)
  /// 내 region이 있으면 같은 region 그룹만, 없으면(미설정) 전체를 보여준다.
  static Future<List<Group>> otherGroups({int limit = 20}) async {
    final mine = await myGroupId();
    final myRegion = await _resolveUserRegion();

    // where('region')+orderBy('createdAt') 조합은 Firestore 복합 색인이 필요해
    // 색인이 없으면 failed-precondition 예외로 홈이 통째로 안 뜬다.
    // createdAt 단일 정렬(자동 색인)로만 받고, region 일치와 내 그룹 제외는
    // 클라이언트에서 거른다. 필터로 줄어드는 만큼 넉넉히 받아 둔다.
    final query = await _groups
        .orderBy('createdAt', descending: true)
        .limit((limit + 1) * 4)
        .get();

    return query.docs
        .where((d) => d.id != mine)
        .where((d) => myRegion.isEmpty || d.data()['region'] == myRegion)
        .take(limit)
        .map((d) {
          final data = d.data();
          data['id'] = d.id;
          return Group.fromJson(data);
        })
        .toList();
  }

  /// 이름으로 검색 (접두 일치)
  /// TODO: 부분 검색이 필요해지면 검색 색인(Algolia 등) 또는 name 소문자 필드 추가
  static Future<List<Group>> search(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return [];
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

  /// 그룹 대표 사진 업로드. 실패해도 null만 반환 — 그룹 생성을 막지 않는다.
  /// 생성 시점엔 아직 groupId가 없어 activity_photos와 같은 방식으로
  /// 생성자 uid를 키로 쓴다. 경로: group_photos/{uid}/{fileName}
  static Future<String?> uploadGroupPhoto(XFile file) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('group_photos')
          .child(uid)
          .child(name);
      await ref.putFile(
        File(file.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('[그룹] 대표 사진 업로드 실패: $e');
      return null;
    }
  }

  /// 그룹 생성 + 자동 가입. 이미 그룹이 있으면 예외.
  static Future<String> createGroup({
    required String name,
    String region = '',
    String intro = '',
    String? imageUrl,
    String intensity = '가볍게 뛰기',
    List<String> moods = const ['조용히 각자'],
    int goalKg = 25,
    bool isPublic = true,
  }) async {
    final resolvedRegion =
        region.isNotEmpty ? region : await _resolveUserRegion();
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다');
    if (await isInGroup()) throw Exception('이미 그룹에 가입되어 있습니다');

    final ref = await _groups.add({
      'name': name,
      'region': resolvedRegion,
      'intro': intro,
      'imageUrl': imageUrl,
      'memberCount': 1,
      'todayActiveCount': 0,
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      // 그룹 만들기에서 함께 받는 값 (그룹 정보 수정 시트에서 이어서 편집)
      'intensity': intensity,
      'moods': moods,
      'goalKg': goalKg, // 그룹 만들기에서 설정(수정 시트에서 이어서 변경 가능)
      'isPublic': isPublic,
    });

    await ref.collection('members').doc(uid).set({
      'joinedAt': FieldValue.serverTimestamp(),
      'role': 'owner', // 개설자
      'userName': await _resolveUserName(),
    });
    await _userDoc()!.set({'groupId': ref.id}, SetOptions(merge: true));

    return ref.id;
  }

  /// 그룹 정보 수정 (그룹장 전용) — 그룹 정보 수정 시트에서 호출.
  ///
  /// null 인 필드는 건드리지 않는다(부분 업데이트). 권한(그룹장) 판정은
  /// 프레젠테이션에서 ownerUid 로 이미 걸러지고, Firestore 규칙에서도 막는다.
  static Future<void> updateGroup({
    required String groupId,
    String? name,
    String? intro,
    String? imageUrl,
    String? intensity,
    List<String>? moods,
    int? goalKg,
    bool? isPublic,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다');

    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (intro != null) data['intro'] = intro;
    if (imageUrl != null) data['imageUrl'] = imageUrl;
    if (intensity != null) data['intensity'] = intensity;
    if (moods != null) data['moods'] = moods;
    if (goalKg != null) data['goalKg'] = goalKg;
    if (isPublic != null) data['isPublic'] = isPublic;
    if (data.isEmpty) return;

    await _groups.doc(groupId).update(data);
  }

  /// 그룹 가입. 이미 다른 그룹 소속이면 예외 (GRP-04 차단과 동일 규칙).
  static Future<void> joinGroup(String groupId) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다');
    if (await isInGroup()) throw Exception('이미 그룹에 가입되어 있습니다');

    final userName = await _resolveUserName(); // batch 전에 미리 읽어둠
    final ref = _groups.doc(groupId);
    final batch = _db.batch();
    batch.set(ref.collection('members').doc(uid), {
      'joinedAt': FieldValue.serverTimestamp(),
      'role': 'member',
      'userName': userName,
    });
    batch.update(ref, {'memberCount': FieldValue.increment(1)});
    batch.set(_userDoc()!, {'groupId': groupId}, SetOptions(merge: true));
    // 채팅방에 '가입' 시스템 알림 남기기 (내가 가입할 때뿐 아니라 남이 가입해도
    // 각자 이 코드가 실행되므로 모두의 채팅에 뜬다).
    batch.set(ref.collection('posts').doc(), {
      'uid': uid,
      'userName': userName,
      'type': PostType.system,
      'text': '$userName님이 그룹에 가입하셨습니다',
      'imageUrl': null,
      'distance': '',
      'trash': 0,
      'duration': '',
      'likes': 0,
      'likedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// 그룹 탈퇴
  ///
  /// 마지막 멤버가 나가면 빈 그룹이 남지 않도록 그룹까지 정리한다.
  /// 그룹 정리에 실패하더라도 내 소속은 반드시 비운다 — 실패로 인해
  /// 사용자가 유령 그룹에 갇히는 상황을 만들지 않기 위해서다.
  static Future<void> leaveGroup(String groupId) async {
    final uid = _uid;
    if (uid == null) return;

    final ref = _groups.doc(groupId);
    try {
      await ref.collection('members').doc(uid).delete();

      // 그룹 문서가 이미 없으면(유령) 더 볼 것이 없다.
      // 예전 코드는 여기서 batch.update 가 실패해 탈퇴 자체가 막혔다.
      if ((await ref.get()).exists) {
        final remaining = await ref.collection('members').limit(1).get();
        if (remaining.docs.isEmpty) {
          await deleteGroupDeep(ref); // 마지막 멤버 → 그룹째 정리
        } else {
          await ref.update({'memberCount': FieldValue.increment(-1)});
        }
      }
    } catch (e) {
      debugPrint('[그룹] 탈퇴 중 그룹 정리 실패: $e');
    }

    await _userDoc()!.set({'groupId': null}, SetOptions(merge: true));
  }

  /// 그룹 문서 + 하위 컬렉션(members/posts) 삭제
  ///
  /// Firestore 는 문서를 지워도 하위 컬렉션이 남아, '존재하지 않는 문서' 아래에
  /// 데이터만 떠 있는 상태가 된다. 하위부터 비우고 마지막에 문서를 지운다.
  static Future<void> deleteGroupDeep(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    await _deleteCollection(ref.collection('members'));
    await _deleteCollection(ref.collection('posts'));
    await ref.delete();
  }

  /// 컬렉션을 300건씩 끊어 비운다 (배치 상한 500 아래로 여유를 둔다)
  static Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    while (true) {
      final snap = await col.limit(300).get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < 300) return;
    }
  }

  /// 멤버 목록 (미리보기용)
  static Future<List<String>> memberNames(
    String groupId, {
    int limit = 8,
  }) async {
    final snap = await _groups
        .doc(groupId)
        .collection('members')
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => (d.data()['userName'] as String?) ?? '')
        .toList();
  }

  /// 현재 사용자가 이 그룹에 가입한 시각 (members/{uid}.joinedAt).
  ///
  /// 재가입(탈퇴 후 다시 가입) 시에도 members 문서가 새로 쓰이므로 항상 최신
  /// 가입 시각을 가리킨다. 이 값을 기준으로 채팅 피드를 잘라, 가입 이전 대화는
  /// 보이지 않게 한다. 가입 정보를 못 읽으면 null (전체 표시로 fallback).
  static Future<DateTime?> myJoinedAt(String groupId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _groups
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .get();
      final ts = doc.data()?['joinedAt'];
      if (ts is Timestamp) return ts.toDate();
    } catch (_) {
      // 실패 시 null → 필터 없이 전체 표시
    }
    return null;
  }

  // ───────────────────────── 피드 ─────────────────────────

  /// 피드 글 목록 (최신순)
  static Future<List<GroupPost>> posts(String groupId, {int limit = 30}) async {
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
    final uid = _uid;
    if (uid == null) return;

    final userName = await _resolveUserName(); // batch 전에 미리 읽어둠
    final batch = _db.batch();
    batch.set(_groups.doc(groupId).collection('posts').doc(), {
      'uid': uid,
      'userName': userName,
      'type': PostType.activity, // 활동 인증 카드
      'text': '',
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

  /// 그룹 채팅 메시지 전송
  ///
  /// 인증샷(activity)과 같은 posts 컬렉션에 저장한다.
  /// → 시간순으로 자연스럽게 섞여서 표시된다.
  static Future<void> sendMessage({
    required String groupId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return; // 빈 메시지 방지

    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다');

    final userName = await _resolveUserName();
    await _groups.doc(groupId).collection('posts').add({
      'uid': uid,
      'userName': userName,
      'photoUrl': _userPhoto,
      'type': PostType.message, // 채팅 메시지
      'text': trimmed,
      // 활동 카드 필드는 비워둠 (모델 기본값으로 처리됨)
      'imageUrl': null,
      'distance': '',
      'trash': 0,
      'duration': '',
      'likes': 0,
      'likedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 좋아요 토글 (내 글에는 사용하지 않음)
  static Future<void> toggleLike({
    required String groupId,
    required String postId,
    required bool liked, // 현재 상태
  }) async {
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
    final doc = _userDoc();
    if (doc == null) return (joined: false, shareCount: 0);
    final data = (await doc.get()).data() ?? {};
    return (
      // 값 존재가 아니라 실제 소속 여부로 판정 (유령 groupId 제외)
      joined: (await myGroupId()) != null,
      shareCount: (data['shareCount'] as num?)?.toInt() ?? 0,
    );
  }
}