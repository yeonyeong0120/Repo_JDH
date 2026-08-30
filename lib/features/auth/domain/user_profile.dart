import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 프로필 데이터 모델
/// Firestore: users/{uid}
class UserProfile {
  final String uid;
  final String email;
  final String nickname;
  final String? profileImageUrl;
  final String? region;
  final double? regionLat;
  final double? regionLng;
  final int ecoPoints;
  final List<String> badges;
  final bool darkMode;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.nickname,
    this.profileImageUrl,
    this.region,
    this.regionLat,
    this.regionLng,
    this.ecoPoints = 0,
    this.badges = const [],
    this.darkMode = false,
    this.fcmToken,
    required this.createdAt,
    required this.lastActiveAt,
  });

  /// Firestore 문서 → UserProfile
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      email: (json['email'] as String?) ?? '',
      nickname: (json['nickname'] as String?) ?? '',
      profileImageUrl: json['profileImageUrl'] as String?,
      region: json['region'] as String?,
      regionLat: (json['regionLat'] as num?)?.toDouble(),
      regionLng: (json['regionLng'] as num?)?.toDouble(),
      ecoPoints: (json['ecoPoints'] as num?)?.toInt() ?? 0,
      badges: (json['badges'] as List?)?.cast<String>() ?? const [],
      darkMode: (json['darkMode'] as bool?) ?? false,
      fcmToken: json['fcmToken'] as String?,
      createdAt: _toDateTime(json['createdAt']) ?? DateTime.now(),
      lastActiveAt: _toDateTime(json['lastActiveAt']) ?? DateTime.now(),
    );
  }

  /// UserProfile → Firestore에 저장할 Map
  /// uid는 문서 ID이므로 데이터에 포함하지 않음
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'nickname': nickname,
      'profileImageUrl': profileImageUrl,
      'region': region,
      'regionLat': regionLat,
      'regionLng': regionLng,
      'ecoPoints': ecoPoints,
      'badges': badges,
      // 그룹 소속은 users/{uid}.groupId 가 단일 기준이다 (GroupService 가 관리).
      // 예전에 있던 joinedGroupId 는 쓰는 곳이 없어 제거했다.
      'darkMode': darkMode,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
    };
  }

  /// 필드 일부만 바꿔 새 객체 만들기 (불변 객체 업데이트용)
  UserProfile copyWith({
    String? nickname,
    String? profileImageUrl,
    String? region,
    double? regionLat,
    double? regionLng,
    int? ecoPoints,
    List<String>? badges,
    bool? darkMode,
    String? fcmToken,
    DateTime? lastActiveAt,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      nickname: nickname ?? this.nickname,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      region: region ?? this.region,
      regionLat: regionLat ?? this.regionLat,
      regionLng: regionLng ?? this.regionLng,
      ecoPoints: ecoPoints ?? this.ecoPoints,
      badges: badges ?? this.badges,
      darkMode: darkMode ?? this.darkMode,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}