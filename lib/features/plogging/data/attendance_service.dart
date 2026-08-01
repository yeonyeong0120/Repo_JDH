import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 출석 기록 서비스
/// 경로: users/{uid}/attendance/{yyyy-MM-dd}
///
/// 날짜를 문서 ID 로 쓰기 때문에, 같은 날 여러 번 홈에 들어와도
/// 문서가 하나만 생긴다(덮어쓰기 → 중복 없음).
class AttendanceService {
  static final _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? _col() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('attendance');
  }

  // DateTime → "2026-07-30" (문서 ID 용)
  static String _dateId(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// 오늘 출석 기록 (홈 진입 시 호출)
  static Future<void> markToday() async {
    final col = _col();
    if (col == null) return; // 비로그인이면 조용히 넘어감

    final today = DateTime.now();
    // set(merge) 로 오늘 문서 생성/갱신. 이미 있으면 시각만 갱신.
    await col.doc(_dateId(today)).set({
      'date': _dateId(today),
      'at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 이번 주(월~일) 출석한 '요일 인덱스' 집합 반환.
  /// 반환 예: {0, 2, 4} → 월·수·금 출석 (월=0 ... 일=6)
  static Future<Set<int>> weekAttendance() async {
    final col = _col();
    if (col == null) return {};

    // 이번 주 월요일 0시 ~ 다음 주 월요일
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final monday = base.subtract(Duration(days: base.weekday - 1));
    final nextMonday = monday.add(const Duration(days: 7));

    final snap = await col
        .where('date',
            isGreaterThanOrEqualTo: _dateId(monday),
            isLessThan: _dateId(nextMonday))
        .get();

    final result = <int>{};
    for (final doc in snap.docs) {
      final dateStr = doc.data()['date'] as String?;
      if (dateStr == null) continue;
      final parts = dateStr.split('-');
      if (parts.length != 3) continue;
      final d = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      result.add(d.weekday - 1); // 월=1 → 0
    }
    return result;
  }
}