import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';

/// 활동 세션 CRUD
/// Firestore 경로: users/{uid}/activities/{activityId}
class ActivityService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? _activitiesCol() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('activities');
  }

  /// 활동 시작
  /// 반환값: 새로 생성된 activityId
  static Future<String> startActivity({
    Map<String, double>? startLocation,
    String? groupId,
  }) async {
    final col = _activitiesCol();
    if (col == null) throw Exception('로그인이 필요합니다');

    final docRef = await col.add({
      'startedAt': FieldValue.serverTimestamp(),
      'status': ActivityStatus.ongoing,
      'trashCounts': <String, int>{},
      'totalTrash': 0,
      'imageUrls': <String>[],
      'detectionIds': <String>[],
      'path': <Map<String, dynamic>>[],
      'startLocation': startLocation,
      'durationSeconds': 0,
      'distanceMeters': 0.0,
      'pointsEarned': 0,
      if (groupId != null) 'groupId': groupId,
    });

    return docRef.id;
  }

  /// 활동에 검출 결과 1건 추가 (카메라 등록 시마다 호출)
  /// Transaction 으로 카운트/배열을 안전하게 누적
  static Future<void> addDetection({
    required String activityId,
    required String detectionId,
    required String imageUrl,
    required Map<String, int> incrementCounts,
  }) async {
    final col = _activitiesCol();
    if (col == null) return;

    final ref = col.doc(activityId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final counts = Map<String, int>.from(
        (data['trashCounts'] as Map?) ?? const {},
      );

      incrementCounts.forEach((k, v) {
        counts[k] = (counts[k] ?? 0) + v;
      });
      final total = counts.values.fold<int>(0, (a, b) => a + b);

      tx.update(ref, {
        'trashCounts': counts,
        'totalTrash': total,
        'imageUrls': FieldValue.arrayUnion([imageUrl]),
        'detectionIds': FieldValue.arrayUnion([detectionId]),
      });
    });
  }

  /// GPS 경로 포인트 추가 (활동 중 주기적으로 호출)
  static Future<void> appendPathPoint({
    required String activityId,
    required double lat,
    required double lng,
  }) async {
    final col = _activitiesCol();
    if (col == null) return;

    await col.doc(activityId).update({
      'path': FieldValue.arrayUnion([
        {'lat': lat, 'lng': lng, 't': Timestamp.fromDate(DateTime.now())},
      ]),
    });
  }

  /// 완료된 활동에 인증샷 URL을 추가한다 (내 활동 상세에서 나중에 첨부).
  static Future<void> addPhoto({
    required String activityId,
    required String imageUrl,
  }) async {
    final col = _activitiesCol();
    if (col == null) return;

    await col.doc(activityId).update({
      'imageUrls': FieldValue.arrayUnion([imageUrl]),
    });
  }

  /// 활동 종료 (정상 완료)
  static Future<void> endActivity({
    required String activityId,
    required int durationSeconds,
    required double distanceMeters,
    Map<String, double>? endLocation,
    int pointsEarned = 0,
  }) async {
    final col = _activitiesCol();
    if (col == null) return;

    await col.doc(activityId).update({
      'endedAt': FieldValue.serverTimestamp(),
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'endLocation': endLocation,
      'pointsEarned': pointsEarned,
      'status': ActivityStatus.completed,
    });
  }

  /// 활동 취소 (쓰레기 0개 등으로 무효 처리)
  static Future<void> cancelActivity(String activityId) async {
    final col = _activitiesCol();
    if (col == null) return;

    await col.doc(activityId).update({
      'endedAt': FieldValue.serverTimestamp(),
      'status': ActivityStatus.canceled,
    });
  }

  /// 진행 중인 활동 조회 (앱 재시작 후 이어서 하기 용도)
  static Future<Activity?> getOngoingActivity() async {
    final col = _activitiesCol();
    if (col == null) return null;

    final query = await col
        .where('status', isEqualTo: ActivityStatus.ongoing)
        .orderBy('startedAt', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    final data = doc.data();
    data['id'] = doc.id;
    return Activity.fromJson(data);
  }

  /// 단일 활동 조회
  static Future<Activity?> getActivity(String activityId) async {
    final col = _activitiesCol();
    if (col == null) return null;

    final snap = await col.doc(activityId).get();
    if (!snap.exists) return null;
    final data = snap.data()!;
    data['id'] = snap.id;
    return Activity.fromJson(data);
  }

  /// 트래킹 종료 시 완료된 활동을 한 번에 저장 (시작/종료를 나눠 부르지 않는 경우)
  static Future<String?> saveCompleted({
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
    required double distanceMeters,
    Map<String, int> trashCounts = const {},
    String? groupId,
    int pointsEarned = 0,
    List<Map<String, dynamic>> path = const [], // 지나온 경로 [{lat,lng,t}]
    Map<String, double>? startLocation,
    Map<String, double>? endLocation,
    List<String> imageUrls = const [], // 인증샷 URL (없으면 빈 배열)
    String? placeName, // 역지오코딩 결과 (좌표가 없거나 실패했으면 null)
    String? placeDetail, // 번지 포함 상세 장소명 (없으면 null)
  }) async {
    final col = _activitiesCol();
    if (col == null) return null;

    final total = trashCounts.values.fold<int>(0, (a, b) => a + b);
    final doc = await col.add({
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': Timestamp.fromDate(endedAt),
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'trashCounts': trashCounts,
      'totalTrash': total,
      'imageUrls': imageUrls,
      'detectionIds': <String>[],
      'path': path, // 활동 경로 (지도 표시용)
      'startLocation': startLocation,
      'endLocation': endLocation,
      'pointsEarned': pointsEarned,
      'status': ActivityStatus.completed,
      if (groupId != null) 'groupId': groupId,
      if (placeName != null) 'placeName': placeName,
      if (placeDetail != null) 'placeDetail': placeDetail,
    });
    return doc.id;
  }

  /// 완료된 활동 최근 N개 (내 활동 화면용)
  static Future<List<Activity>> getRecentCompleted({int limit = 20}) async {
    final col = _activitiesCol();
    if (col == null) return [];

    final query = await col
        .where('status', isEqualTo: ActivityStatus.completed)
        .orderBy('endedAt', descending: true)
        .limit(limit)
        .get();

    return query.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Activity.fromJson(data);
    }).toList();
  }
}
