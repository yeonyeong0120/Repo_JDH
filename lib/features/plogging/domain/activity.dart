import 'package:cloud_firestore/cloud_firestore.dart';

/// 활동 상태
class ActivityStatus {
  static const String ongoing = 'ongoing'; // 진행 중
  static const String completed = 'completed'; // 정상 종료
  static const String canceled = 'canceled'; // 취소됨
}

/// 활동 세션 데이터 모델
/// Firestore: users/{uid}/activities/{activityId}
class Activity {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final double distanceMeters;
  final List<Map<String, dynamic>> path; // [{lat, lng, t}, ...]
  final Map<String, double>? startLocation; // {lat, lng}
  final Map<String, double>? endLocation;
  final Map<String, int> trashCounts; // {can: 3, plastic: 2, ...}
  final int totalTrash;
  final List<String> imageUrls;
  final List<String> detectionIds;
  final String? groupId;

  /// 역지오코딩된 장소명 (startLocation 기준).
  /// 이 필드가 생기기 전에 저장된 문서에는 없으므로 nullable.
  final String? placeName;

  final int pointsEarned;
  final String status;

  Activity({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.distanceMeters = 0.0,
    this.path = const [],
    this.startLocation,
    this.endLocation,
    this.trashCounts = const {},
    this.totalTrash = 0,
    this.imageUrls = const [],
    this.detectionIds = const [],
    this.groupId,
    this.placeName,
    this.pointsEarned = 0,
    this.status = ActivityStatus.ongoing,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      startedAt: _toDateTime(json['startedAt']) ?? DateTime.now(),
      endedAt: _toDateTime(json['endedAt']),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      path: ((json['path'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      startLocation: _toLocationMap(json['startLocation']),
      endLocation: _toLocationMap(json['endLocation']),
      trashCounts: ((json['trashCounts'] as Map?) ?? {}).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      ),
      totalTrash: (json['totalTrash'] as num?)?.toInt() ?? 0,
      imageUrls: ((json['imageUrls'] as List?) ?? const []).cast<String>(),
      detectionIds: ((json['detectionIds'] as List?) ?? const [])
          .cast<String>(),
      groupId: json['groupId'] as String?,
      placeName: json['placeName'] as String?,
      pointsEarned: (json['pointsEarned'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? ActivityStatus.ongoing,
    );
  }

  /// id는 문서 ID이므로 데이터에 포함하지 않음
  Map<String, dynamic> toJson() {
    return {
      'startedAt': Timestamp.fromDate(startedAt),
      if (endedAt != null) 'endedAt': Timestamp.fromDate(endedAt!),
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'path': path,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'trashCounts': trashCounts,
      'totalTrash': totalTrash,
      'imageUrls': imageUrls,
      'detectionIds': detectionIds,
      'groupId': groupId,
      'placeName': placeName,
      'pointsEarned': pointsEarned,
      'status': status,
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static Map<String, double>? _toLocationMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return {
        'lat': (value['lat'] as num?)?.toDouble() ?? 0.0,
        'lng': (value['lng'] as num?)?.toDouble() ?? 0.0,
      };
    }
    return null;
  }
}
