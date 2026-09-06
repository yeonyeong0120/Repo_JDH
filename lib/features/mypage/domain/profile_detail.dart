import 'package:repo_jdh/features/mypage/domain/level_system.dart';

/// 프로필 화면(메뉴 → 프로필)에서 쓰는 상세 정보
/// Firestore: users/{uid} + FirebaseAuth 계정 정보(email · 가입일)
/// (auth/domain/user_profile.dart 의 UserProfile 과는 별개 — 화면 표시용)
class ProfileDetail {
  final String nickname;
  final String email;
  final String? photoUrl;
  final int? weight; // kg — 칼로리 계산용(성별·나이·키는 쓰지 않아 수집 안 함)
  final String region;
  final double? regionLat;
  final double? regionLng;
  final int points; // 보유 에코 포인트
  final int xp; // 누적 경험치 (활동 1회 = 20 XP)
  final DateTime? joinedAt;

  const ProfileDetail({
    this.nickname = '',
    this.email = '',
    this.photoUrl,
    this.weight,
    this.region = '',
    this.regionLat,
    this.regionLng,
    this.points = 0,
    this.xp = 0,
    this.joinedAt,
  });

  /// 레벨/XP 계산 — LevelSystem 으로 통일 (홈 화면 등 다른 화면과 동일 규칙)
  /// 규칙: 레벨 n → n+1 필요 XP = 100 + (n-1)*50  (100, 150, 200 ...)
  LevelInfo get _levelInfo => LevelSystem.of(xp);

  /// 현재 레벨
  int get level => _levelInfo.level;

  /// 이번 레벨에서 모은 XP (예: 50)
  int get xpInLevel => _levelInfo.currentXp;

  /// 이번 레벨에 필요한 총 XP (예: 200) — 화면에서 '50/200' 처럼 표시
  int get xpNeeded => _levelInfo.neededXp;

  /// 다음 레벨까지 남은 XP
  int get xpRemaining => _levelInfo.remainingXp;

  /// 진행률 0.0~1.0
  double get levelProgress => _levelInfo.progress;

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
    int? weight,
    String? region,
    double? regionLat,
    double? regionLng,
    int? points,
    int? xp,
    DateTime? joinedAt,
  }) {
    return ProfileDetail(
      nickname: nickname ?? this.nickname,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      weight: weight ?? this.weight,
      region: region ?? this.region,
      regionLat: regionLat ?? this.regionLat,
      regionLng: regionLng ?? this.regionLng,
      points: points ?? this.points,
      xp: xp ?? this.xp,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  factory ProfileDetail.fromJson(Map<String, dynamic> json) {
    return ProfileDetail(
      nickname: (json['nickname'] as String?) ?? '',
      photoUrl: json['photoUrl'] as String?,
      weight: (json['weight'] as num?)?.toInt(),
      region: (json['region'] as String?) ?? '',
      regionLat: (json['regionLat'] as num?)?.toDouble(),
      regionLng: (json['regionLng'] as num?)?.toDouble(),
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }

  /// 저장은 프로필 항목만 (points 는 뱃지 적립 쪽에서 증감)
  Map<String, dynamic> toProfileJson() => {
    'nickname': nickname,
    'weight': weight,
    'region': region,
  };
}