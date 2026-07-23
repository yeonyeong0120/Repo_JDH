import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:repo_jdh/features/plogging/data/firestore_repository.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:repo_jdh/core/dev/dev_user.dart';
import 'package:repo_jdh/core/dev/dev_data.dart';

/// 뱃지 판정에 쓰는 누적 통계
class UserStats {
  final int ploggingCount; // 완료한 플로깅 횟수
  final int verifyCount; // 수거 인증(사진 등록) 횟수
  final int maxSessionMinutes; // 단일 활동 최長 시간(분)
  final int totalSteps; // 누적 걸음
  final double totalDistanceKm; // 누적 거리(km)
  final int totalMinutes; // 누적 활동시간(분)
  final int totalKcal; // 누적 칼로리
  final double totalWeightKg; // 누적 수거 무게(kg)
  final int plasticCount; // 누적 플라스틱 개수
  final int groupActivityCount; // 그룹 활동 참여 횟수
  final int shareCount; // 인증샷 공유 횟수
  final bool joinedGroup; // 그룹 가입 여부
  final int streakDays; // 연속 플로깅 일수

  const UserStats({
    this.ploggingCount = 0,
    this.verifyCount = 0,
    this.maxSessionMinutes = 0,
    this.totalSteps = 0,
    this.totalDistanceKm = 0,
    this.totalMinutes = 0,
    this.totalKcal = 0,
    this.totalWeightKg = 0,
    this.plasticCount = 0,
    this.groupActivityCount = 0,
    this.shareCount = 0,
    this.joinedGroup = false,
    this.streakDays = 0,
  });
}

/// 뱃지 획득 판정 · 저장
class BadgeService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static String? get _uid => DevUser.resolve();

  static CollectionReference<Map<String, dynamic>>? _badgeCol() {
    final uid = _uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('badges');
  }

  // ───────────────────────── 조건 판정 ─────────────────────────

  /// 조건을 만족하는 뱃지 id 전부 (획득 여부와 무관)
  static Set<String> satisfied(UserStats s) {
    final ok = <String>{};
    void add(String id, bool cond) {
      if (cond) ok.add(id);
    }

    // 씨앗
    add('first_plogging', s.ploggingCount >= 1);
    add('first_verify', s.verifyCount >= 1);
    add('first_30min', s.maxSessionMinutes >= 30);
    add('weight_1kg', s.totalWeightKg >= 1);
    // 새싹
    add('steps_10k', s.totalSteps >= 10000);
    add('steps_30k', s.totalSteps >= 30000);
    add('distance_10km', s.totalDistanceKm >= 10);
    add('weight_5kg', s.totalWeightKg >= 5);
    add('weight_20kg', s.totalWeightKg >= 20);
    add('plastic_50', s.plasticCount >= 50);
    add('time_3h', s.totalMinutes >= 180);
    add('time_10h', s.totalMinutes >= 600);
    add('kcal_500', s.totalKcal >= 500);
    // 나무
    add('group_join', s.joinedGroup);
    add('group_5', s.groupActivityCount >= 5);
    add('group_10', s.groupActivityCount >= 10);
    add('share_10', s.shareCount >= 10);
    // 숲
    add('streak_3', s.streakDays >= 3);
    add('streak_7', s.streakDays >= 7);
    add('streak_30', s.streakDays >= 30);

    return ok;
  }

  /// 이번에 새로 딴 뱃지 (조건 만족 - 이미 획득) — 정의 순서 유지
  static List<BadgeData> newlyEarned(UserStats s) {
    final ok = satisfied(s);
    return kBadges
        .where((b) => ok.contains(b.id) && !BadgeRepo.isEarned(b.id))
        .toList();
  }

  // ───────────────────────── 통계 집계 ─────────────────────────

  /// 누적 통계 계산 — 두 소스를 합침
  ///   detections : 인증 1건마다 시각 + 종류별 개수 → 수거량 · 플라스틱 · 인증 횟수
  ///   activities : 활동 1건마다 시간 · 거리        → 시간 · 거리 · 걸음 · 칼로리
  /// (totals/main 은 정산 때 reset 되는 세션값이라 누적에는 쓰지 않음)
  static Future<UserStats> loadStats() async {
    if (DevData.enabled) return DevData.stats; // 개발용 로컬 더미
    final counters = await GroupService.badgeCounters();
    final rows = await FirestoreRepository().getAllDetections();
    final acts = await ActivityService.getRecentCompleted(limit: 500);

    // ── 인증 기록 → 수거량 · 플라스틱 · 인증 횟수 ──
    int plastic = 0;
    int trashTotal = 0;
    final days = <DateTime>{};

    for (final r in rows) {
      plastic += (r['plastic'] as num?)?.toInt() ?? 0;
      for (final k in ['plastic', 'can', 'paper', 'glass', 'trash']) {
        trashTotal += (r[k] as num?)?.toInt() ?? 0;
      }
      final t = r['timestamp'];
      final d = t is Timestamp ? t.toDate() : null;
      if (d != null) days.add(DateTime(d.year, d.month, d.day));
    }

    // ── 활동 기록 → 시간 · 거리 ──
    int totalSeconds = 0;
    int maxSeconds = 0;
    double totalMeters = 0;
    int groupCount = 0;

    for (final a in acts) {
      totalSeconds += a.durationSeconds;
      totalMeters += a.distanceMeters;
      if (a.durationSeconds > maxSeconds) maxSeconds = a.durationSeconds;
      if (a.groupId != null) groupCount++;
      final d = a.endedAt ?? a.startedAt;
      days.add(DateTime(d.year, d.month, d.day));
    }

    final km = totalMeters / 1000;
    return UserStats(
      // 활동 기록이 있으면 그 횟수, 없으면 인증한 날짜 수로 대체
      ploggingCount: acts.isNotEmpty ? acts.length : days.length,
      verifyCount: rows.length,
      maxSessionMinutes: maxSeconds ~/ 60,
      // TODO: 만보기 붙이면 실제 걸음수로 교체 (지금은 거리 환산)
      totalSteps: (km * 1400).round(),
      totalDistanceKm: km,
      totalMinutes: totalSeconds ~/ 60,
      // TODO: 체중 기반 계산으로 교체 (지금은 거리 환산)
      totalKcal: (km * 60).round(),
      // TODO: 개당 100g 가정. 실제 무게 추정 로직 생기면 교체.
      totalWeightKg: trashTotal * 0.1,
      plasticCount: plastic,
      groupActivityCount: groupCount,
      shareCount: counters.shareCount,
      joinedGroup: counters.joined,
      streakDays: _streakDays(days),
    );
  }

  /// 오늘(또는 어제)부터 거꾸로 이어지는 연속 활동 일수
  static int _streakDays(Set<DateTime> daySet) {
    final days = daySet.toList()..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (today.difference(days.first).inDays > 1) return 0; // 연속 끊김

    int streak = 1;
    for (int i = 0; i < days.length - 1; i++) {
      if (days[i].difference(days[i + 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// 퀘스트 진행률 (현재값, 목표값) — 퀘스트 목록 화면에서 사용
  static (int current, int total) progressOf(BadgeData b, UserStats s) {
    switch (b.id) {
      case 'first_plogging':
        return (s.ploggingCount.clamp(0, 1), 1);
      case 'first_verify':
        return (s.verifyCount.clamp(0, 1), 1);
      case 'first_30min':
        return (s.maxSessionMinutes.clamp(0, 30), 30);
      case 'weight_1kg':
        return (s.totalWeightKg.round().clamp(0, 1), 1);
      case 'steps_10k':
        return (s.totalSteps.clamp(0, 10000), 10000);
      case 'steps_30k':
        return (s.totalSteps.clamp(0, 30000), 30000);
      case 'distance_10km':
        return (s.totalDistanceKm.round().clamp(0, 10), 10);
      case 'weight_5kg':
        return (s.totalWeightKg.round().clamp(0, 5), 5);
      case 'weight_20kg':
        return (s.totalWeightKg.round().clamp(0, 20), 20);
      case 'plastic_50':
        return (s.plasticCount.clamp(0, 50), 50);
      case 'time_3h':
        return (s.totalMinutes.clamp(0, 180), 180);
      case 'time_10h':
        return (s.totalMinutes.clamp(0, 600), 600);
      case 'kcal_500':
        return (s.totalKcal.clamp(0, 500), 500);
      case 'group_join':
        return (s.joinedGroup ? 1 : 0, 1);
      case 'group_5':
        return (s.groupActivityCount.clamp(0, 5), 5);
      case 'group_10':
        return (s.groupActivityCount.clamp(0, 10), 10);
      case 'share_10':
        return (s.shareCount.clamp(0, 10), 10);
      case 'streak_3':
        return (s.streakDays.clamp(0, 3), 3);
      case 'streak_7':
        return (s.streakDays.clamp(0, 7), 7);
      case 'streak_30':
        return (s.streakDays.clamp(0, 30), 30);
    }
    return (0, 1);
  }

  // ───────────────────────── 저장 / 불러오기 ─────────────────────────

  /// 획득 현황을 Firestore 에서 읽어 BadgeRepo 에 채움 (앱 시작/내 활동 진입 시)
  static Future<void> loadEarned() async {
    if (DevData.enabled) {
      BadgeRepo.earned = Map.of(DevData.earnedBadges);
      return;
    }
    final col = _badgeCol();
    if (col == null) return;
    final snap = await col.get();
    if (snap.docs.isEmpty) return;
    BadgeRepo.earned = {
      for (final d in snap.docs) d.id: (d.data()['earnedAt'] as String?) ?? '',
    };
  }

  /// 새로 딴 뱃지 저장 + 포인트 적립
  static Future<void> saveEarned(List<BadgeData> badges) async {
    if (DevData.enabled) {
      for (final x in badges) {
        DevData.earnedBadges[x.id] = '오늘';
        BadgeRepo.earned[x.id] = '오늘';
      }
      return;
    }
    final col = _badgeCol();
    if (col == null || badges.isEmpty) return;

    final now = DateTime.now();
    final date =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    final batch = _db.batch();
    for (final b in badges) {
      batch.set(col.doc(b.id), {
        'earnedAt': date,
        'createdAt': FieldValue.serverTimestamp(),
        'reward': b.reward,
        'points': b.points,
      });
    }
    // 에코 포인트 합산 적립
    final total = badges.fold<int>(0, (acc, b) => acc + b.points);
    batch.set(_db.collection('users').doc(_uid), {
      'points': FieldValue.increment(total),
    }, SetOptions(merge: true));

    await batch.commit();

    // 로컬 상태도 갱신 (UI 즉시 반영)
    for (final b in badges) {
      BadgeRepo.earned[b.id] = date;
    }
  }

  /// 정산 화면에서 한 번에 호출: 통계 → 판정 → 저장 → 새 뱃지 반환
  static Future<List<BadgeData>> checkAndSave() async {
    await loadEarned();
    final stats = await loadStats();
    final fresh = newlyEarned(stats);
    if (fresh.isNotEmpty) await saveEarned(fresh);
    return fresh;
  }
}
