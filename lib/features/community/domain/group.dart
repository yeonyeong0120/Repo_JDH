import 'package:cloud_firestore/cloud_firestore.dart';

/// 그룹 데이터 모델
/// Firestore: groups/{groupId}
class Group {
  final String id;
  final String name;
  final String region; // '00구 00동'
  final String intro;
  final String? imageUrl;
  final int memberCount;
  final int todayActiveCount; // 오늘 활동한 인원
  final String ownerUid;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    this.region = '',
    this.intro = '',
    this.imageUrl,
    this.memberCount = 0,
    this.todayActiveCount = 0,
    this.ownerUid = '',
    required this.createdAt,
  });

  /// 목록 카드에 쓰는 한 줄 ('12명 · 오늘 활동 인원 3명')
  String get meta => '$memberCount명 · 오늘 활동 인원 $todayActiveCount명';

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      intro: (json['intro'] as String?) ?? '',
      imageUrl: json['imageUrl'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      todayActiveCount: (json['todayActiveCount'] as num?)?.toInt() ?? 0,
      ownerUid: (json['ownerUid'] as String?) ?? '',
      createdAt: _toDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'region': region,
    'intro': intro,
    'imageUrl': imageUrl,
    'memberCount': memberCount,
    'todayActiveCount': todayActiveCount,
    'ownerUid': ownerUid,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static DateTime? _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

/// 피드 항목 종류
/// - activity : 플로깅 인증 카드 (거리·수거량·시간)
/// - message  : 그룹 채팅 메시지 (텍스트)
class PostType {
  static const String activity = 'activity';
  static const String message = 'message';
  static const String system = 'system'; // 가입 등 시스템 알림
}

/// 그룹 피드 항목 (인증샷 카드 + 채팅 메시지)
/// Firestore: groups/{groupId}/posts/{postId}
///
/// 같은 컬렉션에 두 종류를 담아 시간순으로 자연스럽게 섞이게 한다.
/// (컬렉션을 나누면 조회 후 다시 정렬해야 해서 복잡해진다)
class GroupPost {
  final String id;
  final String uid;
  final String userName;
  final String? photoUrl; // 작성자 프로필 사진
  final String type; // activity / message
  final String text; // 채팅 메시지 내용 (activity 면 빈 문자열)
  final String? imageUrl; // 봉투 인증샷 (없으면 스킵으로 마친 활동)
  final String distance; // '2.1 km'
  final int trash; // 수거 개수
  final String duration; // '00:42'
  final int likes;
  final bool likedByMe;
  final bool isMine;
  final DateTime createdAt;

  GroupPost({
    required this.id,
    required this.uid,
    this.userName = '',
    this.photoUrl,
    this.type = PostType.activity, // 기존 데이터는 전부 활동 카드
    this.text = '',
    this.imageUrl,
    this.distance = '',
    this.trash = 0,
    this.duration = '',
    this.likes = 0,
    this.likedByMe = false,
    this.isMine = false,
    required this.createdAt,
  });

  /// 채팅 메시지인지
  bool get isMessage => type == PostType.message;

  /// 시스템 알림(가입 등)인지
  bool get isSystem => type == PostType.system;

  factory GroupPost.fromJson(Map<String, dynamic> json, String myUid) {
    final likedBy = ((json['likedBy'] as List?) ?? const []).cast<String>();
    return GroupPost(
      id: json['id'] as String,
      uid: (json['uid'] as String?) ?? '',
      userName: (json['userName'] as String?) ?? '',
      photoUrl: json['photoUrl'] as String?,
      // type 이 없는 기존 문서는 활동 카드로 취급
      type: (json['type'] as String?) ?? PostType.activity,
      text: (json['text'] as String?) ?? '',
      imageUrl: json['imageUrl'] as String?,
      distance: (json['distance'] as String?) ?? '',
      trash: (json['trash'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as String?) ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? likedBy.length,
      likedByMe: likedBy.contains(myUid),
      isMine: (json['uid'] as String?) == myUid,
      createdAt: Group._toDateTime(json['createdAt']) ?? DateTime.now(),
    );
  }
}