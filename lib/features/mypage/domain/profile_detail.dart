/// 프로필 화면(메뉴 → 프로필)에서 쓰는 상세 정보
/// Firestore: users/{uid} + FirebaseAuth 계정 정보(email · 가입일)
/// (auth/domain/user_profile.dart 의 UserProfile 과는 별개 — 화면 표시용)
class ProfileDetail {
  final String nickname;
  final String email;
  final String? photoUrl;
  final String? gender; // '남' / '여' / null
  final int? age;
  final int? height; // cm
  final int? weight; // kg
  final String region;
  final int points; // 보유 에코 포인트
  final int xp; // 누적 경험치 (활동 1회 = 20 XP)
  final DateTime? joinedAt;

  const ProfileDetail({
    this.nickname = '',
    this.email = '',
    this.photoUrl,
    this.gender,
    this.age,
    this.height,
    this.weight,
    this.region = '',
    this.points = 0,
    this.xp = 0,
    this.joinedAt,
  });

  /// 100 XP 마다 레벨업
  int get level => xp ~/ 100 + 1;
  int get xpInLevel => xp % 100;
  double get levelProgress => xpInLevel / 100;

  /// '2026년 2월 5일'
  String get joinedText {
    final d = joinedAt;
    if (d == null) return '-';
    return '${d.year}년 ${d.month}월 ${d.day}일';
  }

  ProfileDetail copyWith({
    String? nickname,
    String? email,
    String? photoUrl,
    String? gender,
    int? age,
    int? height,
    int? weight,
    String? region,
    int? points,
    int? xp,
    DateTime? joinedAt,
  }) {
    return ProfileDetail(
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      region: region ?? this.region,
      points: points ?? this.points,
      xp: xp ?? this.xp,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  factory ProfileDetail.fromJson(Map<String, dynamic> json) {
    return ProfileDetail(
      nickname: (json['nickname'] as String?) ?? '',
      photoUrl: json['photoUrl'] as String?,
      gender: json['gender'] as String?,
      age: (json['age'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      weight: (json['weight'] as num?)?.toInt(),
      region: (json['region'] as String?) ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }

  /// 저장은 프로필 항목만 (points 는 뱃지 적립 쪽에서 증감)
  Map<String, dynamic> toProfileJson() => {
    'nickname': nickname,
    'gender': gender,
    'age': age,
    'height': height,
    'weight': weight,
    'region': region,
  };
}
