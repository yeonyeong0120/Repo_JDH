import 'package:cloud_firestore/cloud_firestore.dart';

/// 그룹 데이터 모델
/// Firestore: groups/{groupId}
class Group {
  final String id;
  final String name;
  final String region; // 그룹 매칭 기준 지역, 예: '인천 남동구' (사용자 region과 같은 형식)
  final String intro;
  final String? imageUrl;
  final int memberCount;
  final int todayActiveCount; // 오늘 활동한 인원
  final String ownerUid;
  final DateTime createdAt;
  // ── 그룹장 편집 필드 (그룹 정보 수정 시트) ──
  final String intensity; // 활동 강도: '산책' | '가볍게 뛰기' | '러닝'
  final List<String> moods; // 분위기 태그 (복수 선택)
  final int goalKg; // 주간 목표 수거량 (5~60, 5단위)
  final bool isPublic; // 공개 설정: true=누구나 가입 / false=승인 후 가입

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
    this.intensity = '산책',
    this.moods = const [],
    this.goalKg = 25,
    this.isPublic = true,
  });

  /// 목록 카드에 쓰는 한 줄 ('12명 · 오늘 활동 인원 3명')
  String get meta => '$memberCount명 · 오늘 활동 인원 $todayActiveCount명';

  /// 그룹 카드 부제 — 홈·더보기·검색 3곳이 같은 문구를 쓴다.
  /// 승인 후 가입 그룹이면 뒤에 잠금 글리프 + '승인'이 붙으므로(카드 위젯이 그림)
  /// 여기서 구분점까지 미리 달아 둔다. 자유 가입 그룹에는 아무 표기도 넣지 않는다.
  String get cardMeta =>
      '$intensity · 멤버 $memberCount명${isPublic ? '' : ' ·'}';

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
      intensity: (json['intensity'] as String?) ?? '산책',
      moods: ((json['moods'] as List?) ?? const []).cast<String>(),
      goalKg: (json['goalKg'] as num?)?.toInt() ?? 25,
      isPublic: (json['isPublic'] as bool?) ?? true,
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
    'intensity': intensity,
    'moods': moods,
    'goalKg': goalKg,
    'isPublic': isPublic,
  };

  static DateTime? _toDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

/// 가입 요청 상태
/// - pending  : 그룹장 확인 대기
/// - approved : 승인됨(멤버로 편입)
/// - rejected : 거절됨
class JoinStatus {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// 승인 후 가입(isPublic:false) 그룹의 가입 요청
/// Firestore: groups/{groupId}/joinRequests/{uid}
///
/// 요청 시점의 프로필 스냅샷(지역·누적 수거량·활동 일수·뱃지 수)을 함께 저장한다.
/// 그룹장이 상대 사용자 문서를 직접 못 읽어도 요청 카드에 통계를 보여주기 위함이다.
class JoinRequest {
  final String uid;
  final String userName;
  final String? photoUrl;
  final String region; // 예: '서울 마포구'
  final double cumulativeKg; // 누적 수거량(kg)
  final int activeDays; // 활동 일수
  final int badgeCount; // 획득 뱃지 수
  final String status; // pending / approved / rejected
  final DateTime requestedAt;

  JoinRequest({
    required this.uid,
    this.userName = '',
    this.photoUrl,
    this.region = '',
    this.cumulativeKg = 0,
    this.activeDays = 0,
    this.badgeCount = 0,
    this.status = JoinStatus.pending,
    required this.requestedAt,
  });

  /// 활동 기록이 있는지 (없으면 카드에 '아직 플로깅 기록이 없어요' 표시)
  bool get hasRecord => cumulativeKg > 0 || activeDays > 0;

  /// 카드 메타 한 줄 ('서울 마포구 · 누적 12.4kg · 뱃지 3개')
  String get meta {
    final parts = <String>[];
    if (region.isNotEmpty) parts.add(region);
    parts.add('누적 ${cumulativeKgText}kg');
    parts.add('뱃지 $badgeCount개');
    return parts.join(' · ');
  }

  /// 요청 시각의 상대 표기 (예: '2시간 전'). 7일이 넘으면 날짜로 떨어뜨린다.
  String get sinceText {
    final d = DateTime.now().difference(requestedAt);
    if (d.inMinutes < 1) return '방금';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    if (d.inHours < 24) return '${d.inHours}시간 전';
    if (d.inDays < 7) return '${d.inDays}일 전';
    return '${requestedAt.month}월 ${requestedAt.day}일';
  }

  /// 전용 화면 카드 메타 ('서울 마포구 · 2시간 전 요청')
  String get screenMeta {
    final parts = <String>[
      if (region.isNotEmpty) region,
      '$sinceText 요청',
    ];
    return parts.join(' · ');
  }

  /// 처리 시트 카드 메타 ('서울 마포구 · 누적 12.4kg · 2시간 전').
  /// 활동 기록이 없으면 누적 대신 '첫 활동 전'을 넣는다.
  String get sheetMeta {
    final parts = <String>[
      if (region.isNotEmpty) region,
      hasRecord ? '누적 ${cumulativeKgText}kg' : '첫 활동 전',
      sinceText,
    ];
    return parts.join(' · ');
  }

  /// 누적 수거량을 소수 첫째 자리까지 (예: 12.4)
  String get cumulativeKgText {
    final v = (cumulativeKg * 10).round() / 10;
    return v.toStringAsFixed(1);
  }

  factory JoinRequest.fromJson(Map<String, dynamic> json, String uid) {
    return JoinRequest(
      uid: uid,
      userName: (json['userName'] as String?) ?? '',
      photoUrl: json['photoUrl'] as String?,
      region: (json['region'] as String?) ?? '',
      cumulativeKg: (json['cumulativeKg'] as num?)?.toDouble() ?? 0,
      activeDays: (json['activeDays'] as num?)?.toInt() ?? 0,
      badgeCount: (json['badgeCount'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? JoinStatus.pending,
      requestedAt: Group._toDateTime(json['requestedAt']) ?? DateTime.now(),
    );
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