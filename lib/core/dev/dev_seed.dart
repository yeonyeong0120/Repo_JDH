import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';

/// ⚠️ 개발용 — 그래프/화면 테스트를 위한 가짜 활동 기록 심기
///
/// 실제 플로깅을 여러 번 하지 않아도, 여러 날짜에 흩어진 활동 기록을
/// Firebase 에 직접 넣어 그래프가 그려지는지 확인할 수 있다.
///
/// 사용법:
///   - DevSeed.seedActivities();  // 가짜 기록 심기
///   - DevSeed.clearActivities(); // 심은 기록 전부 지우기
///
/// 배포 전 이 파일은 삭제할 것.
class DevSeed {
  static final _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? _col() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('activities');
  }

  /// 가짜 완료 활동을 [days]일 범위에 흩뿌려 [count]개 심는다.
  /// 날짜가 다양해야 그래프(요일별/주별)가 의미 있게 그려진다.
  static Future<int> seedActivities({int count = 15, int days = 21}) async {
    final col = _col();
    if (col == null) throw Exception('로그인이 필요합니다');

    final rnd = Random();
    final now = DateTime.now();
    int made = 0;

    // 쓰레기 카테고리 (무게/도넛 계산 대상)
    const categories = ['can', 'glass', 'paper', 'plastic', 'trash'];

    for (int i = 0; i < count; i++) {
      // 최근 [days]일 안에서 랜덤한 날, 랜덤한 시각
      final dayOffset = rnd.nextInt(days);
      final hour = 6 + rnd.nextInt(14); // 6~19시
      final ended = DateTime(now.year, now.month, now.day, hour)
          .subtract(Duration(days: dayOffset));
      final durationSec = 900 + rnd.nextInt(2700); // 15~60분
      final started = ended.subtract(Duration(seconds: durationSec));

      // 거리: 800~4000m
      final distance = 800.0 + rnd.nextInt(3200);

      // 쓰레기: 카테고리별 0~4개 랜덤
      final trashCounts = <String, int>{};
      int totalTrash = 0;
      for (final c in categories) {
        final n = rnd.nextInt(5); // 0~4
        if (n > 0) {
          trashCounts[c] = n;
          totalTrash += n;
        }
      }

      await col.add({
        'startedAt': Timestamp.fromDate(started),
        'endedAt': Timestamp.fromDate(ended),
        'durationSeconds': durationSec,
        'distanceMeters': distance,
        'trashCounts': trashCounts,
        'totalTrash': totalTrash,
        'imageUrls': <String>[],
        'detectionIds': <String>[],
        'path': <Map<String, dynamic>>[],
        'pointsEarned': totalTrash * 10,
        'status': ActivityStatus.completed, // ★ 쿼리에 잡히려면 필수
        'isSeed': true, // ★ 나중에 지우기 위한 표시
      });
      made++;
    }
    return made;
  }

  /// 심은 가짜 기록(isSeed == true)만 전부 삭제
  static Future<int> clearActivities() async {
    final col = _col();
    if (col == null) throw Exception('로그인이 필요합니다');

    final snap = await col.where('isSeed', isEqualTo: true).get();
    int deleted = 0;
    for (final doc in snap.docs) {
      await doc.reference.delete();
      deleted++;
    }
    return deleted;
  }

  // ──────────────── 그룹 시드 ────────────────

  /// '다른 동네 그룹' 목록/검색/가입을 테스트하기 위한 가짜 그룹 심기.
  ///
  /// 내가 만든 그룹이 아니라 남의 그룹이어야 목록에 뜨므로,
  /// ownerUid 를 내 uid 가 아닌 값으로 넣는다.
  static Future<int> seedGroups() async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다');

    // (이름, 지역, 소개, 멤버수)
    const samples = [
      ('한강 같이 걸어요', '서울 영등포구', '주말 아침 한강공원 플로깅 모임이에요.', 12),
      ('동네 한바퀴', '서울 마포구', '퇴근길에 가볍게 줍고 가요.', 8),
      ('청소하는 사람들', '서울 강남구', '매주 토요일 정기 플로깅!', 25),
      ('아침 줍깅단', '서울 송파구', '출근 전 30분, 같이 걸어요.', 6),
    ];

    final batch = _db.batch();
    int made = 0;
    for (final (name, region, intro, members) in samples) {
      final ref = _db.collection('groups').doc();
      batch.set(ref, {
        'name': name,
        'region': region,
        'intro': intro,
        'imageUrl': null,
        'memberCount': members,
        'todayActiveCount': 0,
        'ownerUid': 'seed_owner', // ★ 내 uid 가 아님 → '다른 그룹'으로 표시
        'createdAt': FieldValue.serverTimestamp(),
        'isSeed': true, // ★ 나중에 지우기 위한 표시
      });

      // 멤버 목록도 같이 심는다 (멤버 드로어 확인용)
      const memberNames = ['박서연', '이준호', '최민지', '정우성', '한소희'];
      for (int i = 0; i < memberNames.length; i++) {
        batch.set(ref.collection('members').doc('seed_member_$i'), {
          'joinedAt': FieldValue.serverTimestamp(),
          'role': i == 0 ? 'owner' : 'member',
          'userName': memberNames[i],
          'isSeed': true,
        });
      }
      made++;
    }
    await batch.commit();
    return made;
  }

  /// 심은 가짜 그룹(isSeed == true)만 삭제
  static Future<int> clearGroups() async {
    final snap =
        await _db.collection('groups').where('isSeed', isEqualTo: true).get();
    int deleted = 0;
    for (final doc in snap.docs) {
      await doc.reference.delete();
      deleted++;
    }
    return deleted;
  }

  // ──────────────── 그룹 피드 시드 ────────────────

  /// 내 그룹 피드에 가짜 글 심기.
  ///
  /// 내 글 1개 + 남의 글 여러 개를 섞는다.
  ///   - 내 글  : 오른쪽 정렬 + 하트 숨김 확인용
  ///   - 남의 글 : 좋아요 토글 동작 확인용
  static Future<int> seedPosts(String groupId) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요합니다');

    final now = DateTime.now();
    // (작성자uid, 이름, 거리, 수거개수, 시간, 몇시간 전, 좋아요)
    final samples = <(String, String, String, int, String, int, int)>[
      (uid, '나', '2.1 km', 33, '00:42', 2, 5), // ★ 내 글
      ('seed_user_1', '박서연', '1.4 km', 18, '00:31', 5, 3),
      ('seed_user_2', '이준호', '3.0 km', 41, '00:58', 27, 8),
      ('seed_user_3', '최민지', '0.9 km', 7, '00:18', 50, 1),
    ];

    final col = _db.collection('groups').doc(groupId).collection('posts');
    final batch = _db.batch();
    int made = 0;
    for (final (authorUid, name, dist, trash, dur, hoursAgo, likes)
        in samples) {
      batch.set(col.doc(), {
        'uid': authorUid,
        'userName': name,
        'photoUrl': null,
        'type': 'activity', // 활동 인증 카드
        'text': '',
        'imageUrl': null, // 사진 없음(스킵 활동)으로 표시됨
        'distance': dist,
        'trash': trash,
        'duration': dur,
        'likes': likes,
        'likedBy': <String>[], // 아직 내가 안 누른 상태
        'createdAt': Timestamp.fromDate(
          now.subtract(Duration(hours: hoursAgo)),
        ),
        'isSeed': true, // ★ 나중에 지우기 위한 표시
      });
      made++;
    }

    // 채팅 메시지도 섞어 심는다 (말풍선 UI 확인용)
    // (작성자uid, 이름, 내용, 몇시간 전)
    final chats = <(String, String, String, int)>[
      ('seed_user_1', '박서연', '오늘 날씨 좋네요 ☀️', 4),
      ('seed_user_2', '이준호', '저녁에 한강 나가실 분?', 3),
      (uid, '나', '저요! 7시쯤 갈게요', 2),
      ('seed_user_3', '최민지', '다들 수고하셨습니다 👏', 1),
    ];
    for (final (authorUid, name, text, hoursAgo) in chats) {
      batch.set(col.doc(), {
        'uid': authorUid,
        'userName': name,
        'photoUrl': null,
        'type': 'message', // 채팅 메시지
        'text': text,
        'imageUrl': null,
        'distance': '',
        'trash': 0,
        'duration': '',
        'likes': 0,
        'likedBy': <String>[],
        'createdAt': Timestamp.fromDate(
          now.subtract(Duration(hours: hoursAgo)),
        ),
        'isSeed': true,
      });
      made++;
    }

    // 이 그룹의 멤버도 같이 심는다 (멤버 드로어 확인용)
    // 글 작성자들이 멤버로 보이도록 이름을 맞춰둔다.
    final memberCol =
        _db.collection('groups').doc(groupId).collection('members');
    const seedMembers = ['박서연', '이준호', '최민지', '정우성'];
    for (int i = 0; i < seedMembers.length; i++) {
      batch.set(memberCol.doc('seed_member_$i'), {
        'joinedAt': FieldValue.serverTimestamp(),
        'role': 'member',
        'userName': seedMembers[i],
        'isSeed': true,
      });
    }

    await batch.commit();
    return made;
  }

  /// 심은 가짜 피드 글 + 가짜 멤버 삭제
  static Future<int> clearPosts(String groupId) async {
    final groupRef = _db.collection('groups').doc(groupId);
    int deleted = 0;

    // 피드 글
    final posts =
        await groupRef.collection('posts').where('isSeed', isEqualTo: true).get();
    for (final doc in posts.docs) {
      await doc.reference.delete();
      deleted++;
    }

    // 멤버 (내가 실제로 가입한 문서는 isSeed 가 없어 안전)
    final members = await groupRef
        .collection('members')
        .where('isSeed', isEqualTo: true)
        .get();
    for (final doc in members.docs) {
      await doc.reference.delete();
      deleted++;
    }

    return deleted;
  }
}