import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';
import 'package:repo_jdh/features/mypage/domain/profile_detail.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';
import 'package:repo_jdh/features/shop/domain/shop_item.dart';

/// ⚠️ 개발용 로컬 더미 데이터 — 배포 전 [enabled] 를 false 로
///
/// Firestore 연동(권한·로그인)이 막혀 있는 동안 화면을 확인하기 위한 가짜 데이터.
/// 서비스들이 이 값을 대신 읽고 쓴다. 앱을 껐다 켜면 초기값으로 돌아간다.
///
/// 실제 연동을 켤 때: enabled = false 로 바꾸기만 하면 원래 Firestore 경로로 돌아감.
/// 위치 권장: lib/core/dev/dev_data.dart
class DevData {
  static const bool enabled = false;

  static final DateTime _now = DateTime.now();

  // ───────────────────────── 프로필 ─────────────────────────
  static ProfileDetail profile = ProfileDetail(
    nickname: '김연영',
    email: 'ploggo@example.com',
    gender: '여',
    age: 27,
    height: 162,
    weight: 57,
    region: '인천 부평구',
    points: 5000,
    xp: 100, // 활동 5회 × 20 → Lv.2
    joinedAt: DateTime(2026, 2, 5),
  );

  // ───────────────────────── 퀘스트·뱃지 ─────────────────────────
  static UserStats stats = const UserStats(
    ploggingCount: 5,
    verifyCount: 12,
    maxSessionMinutes: 58,
    totalSteps: 13160,
    totalDistanceKm: 9.4,
    totalMinutes: 188,
    totalKcal: 564,
    totalWeightKg: 12.0,
    plasticCount: 36,
    groupActivityCount: 3,
    shareCount: 3,
    joinedGroup: true,
    streakDays: 3,
  );

  /// 획득한 뱃지 (id → 달성일)
  static Map<String, String> earnedBadges = {
    'first_plogging': '2026.01.25',
    'first_verify': '2026.01.25',
    'first_30min': '2026.01.28',
    'weight_1kg': '2026.02.01',
    'weight_5kg': '2026.02.03',
    'group_join': '2026.02.04',
    'streak_3': '2026.02.06',
    'time_3h': '2026.02.06',
  };

  // ───────────────────────── 활동 기록 ─────────────────────────
  static List<Activity> activities = [
    Activity(
      id: 'a1',
      startedAt: _now.subtract(const Duration(hours: 3)),
      endedAt: _now.subtract(const Duration(hours: 2, minutes: 18)),
      durationSeconds: 42 * 60,
      distanceMeters: 2100,
      trashCounts: const {'plastic': 12, 'can': 8, 'paper': 7, 'trash': 6},
      totalTrash: 33,
      status: ActivityStatus.completed,
    ),
    Activity(
      id: 'a2',
      startedAt: _now.subtract(const Duration(days: 1, hours: 5)),
      endedAt: _now.subtract(const Duration(days: 1, hours: 4, minutes: 29)),
      durationSeconds: 31 * 60,
      distanceMeters: 1400,
      trashCounts: const {'plastic': 8, 'can': 4, 'paper': 6},
      totalTrash: 18,
      status: ActivityStatus.completed,
    ),
    Activity(
      id: 'a3',
      startedAt: _now.subtract(const Duration(days: 2, hours: 2)),
      endedAt: _now.subtract(const Duration(days: 2, hours: 1, minutes: 2)),
      durationSeconds: 58 * 60,
      distanceMeters: 3000,
      trashCounts: const {'plastic': 16, 'can': 10, 'glass': 5, 'trash': 10},
      totalTrash: 41,
      status: ActivityStatus.completed,
    ),
    Activity(
      id: 'a4',
      startedAt: _now.subtract(const Duration(days: 6)),
      endedAt: _now.subtract(const Duration(days: 6)),
      durationSeconds: 22 * 60,
      distanceMeters: 1100,
      trashCounts: const {'plastic': 5, 'paper': 4},
      totalTrash: 9,
      status: ActivityStatus.completed,
    ),
    Activity(
      id: 'a5',
      startedAt: _now.subtract(const Duration(days: 9)),
      endedAt: _now.subtract(const Duration(days: 9)),
      durationSeconds: 35 * 60,
      distanceMeters: 1800,
      trashCounts: const {'plastic': 7, 'can': 5},
      totalTrash: 12,
      status: ActivityStatus.completed,
    ),
  ];

  // ───────────────────────── 그룹 ─────────────────────────
  static Group? myGroup = Group(
    id: 'g_mine',
    name: '부평 같이 주워봐요',
    region: '인천 부평구',
    intro: '가볍게 걷고 주우며 동네를 깨끗하게 만드는 모임이에요. 누구나 편하게 참여할 수 있어요!',
    memberCount: 12,
    todayActiveCount: 3,
    ownerUid: 'dev_user',
    createdAt: DateTime(2026, 1, 10),
  );

  static List<Group> otherGroups = [
    Group(
      id: 'g1',
      name: '부평 새벽 조깅',
      region: '인천 부평구',
      intro: '아침 6시에 만나 함께 걸어요.',
      memberCount: 8,
      todayActiveCount: 1,
      createdAt: DateTime(2026, 1, 20),
    ),
    Group(
      id: 'g2',
      name: '삼산동 플로깅 크루',
      region: '인천 부평구',
      intro: '주말마다 삼산동 일대를 정리합니다.',
      memberCount: 15,
      todayActiveCount: 2,
      createdAt: DateTime(2026, 1, 18),
    ),
    Group(
      id: 'g3',
      name: '굴포천 지킴이',
      region: '인천 부평구',
      intro: '굴포천 산책로를 지키는 사람들.',
      memberCount: 21,
      todayActiveCount: 5,
      createdAt: DateTime(2026, 1, 5),
    ),
  ];

  static List<String> memberNames = [
    '김연영',
    '박서연',
    '이준호',
    '최민지',
    '정우성',
    '한소희',
    '오정환',
    '유가을',
  ];

  // ───────────────────────── 그룹 피드 ─────────────────────────
  static List<GroupPost> posts = [
    GroupPost(
      id: 'p1',
      uid: 'dev_user',
      userName: '김연영',
      imageUrl: 'dummy://photo', // 인증샷 있는 글
      distance: '2.1 km',
      trash: 33,
      duration: '00:42',
      likes: 5,
      isMine: true,
      createdAt: _now.subtract(const Duration(hours: 2)),
    ),
    GroupPost(
      id: 'p2',
      uid: 'u2',
      userName: '박서연',
      distance: '1.4 km',
      trash: 18,
      duration: '00:31',
      likes: 3,
      createdAt: _now.subtract(const Duration(hours: 5)),
    ),
    GroupPost(
      id: 'p3',
      uid: 'u3',
      userName: '이준호',
      imageUrl: 'dummy://photo', // 인증샷 있는 글
      distance: '3.0 km',
      trash: 41,
      duration: '00:58',
      likes: 8,
      createdAt: _now.subtract(const Duration(days: 1, hours: 3)),
    ),
  ];

  // ───────────────────────── 쿠폰 ─────────────────────────
  static List<Coupon> coupons = [
    Coupon(
      id: 'c1',
      itemId: 'eco_bag',
      brand: '인천 에코',
      name: '지구 지킴이 에코백',
      code: '221234567895',
      expiresAt: DateTime(_now.year + 1, 12, 31),
      createdAt: _now.subtract(const Duration(days: 3)),
    ),
    Coupon(
      id: 'c2',
      itemId: 'bamboo_brush',
      brand: '녹색 생활',
      name: '대나무 칫솔 4입',
      code: '883021447761',
      expiresAt: DateTime(_now.year - 1, 12, 31),
      used: true,
      createdAt: _now.subtract(const Duration(days: 200)),
    ),
  ];

  /// 쿠폰 사용/취소 (목록에서 해당 항목 교체)
  static void setCouponUsed(String id, bool used) {
    final i = coupons.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final c = coupons[i];
    coupons[i] = Coupon(
      id: c.id,
      itemId: c.itemId,
      brand: c.brand,
      name: c.name,
      imageUrl: c.imageUrl,
      code: c.code,
      expiresAt: c.expiresAt,
      used: used,
      createdAt: c.createdAt,
    );
  }

  /// 상품 교환 (포인트 차감 + 쿠폰 추가)
  static void exchange(ShopItem item) {
    profile = profile.copyWith(points: profile.points - item.price);
    coupons.insert(
      0,
      Coupon(
        id: 'c${DateTime.now().millisecondsSinceEpoch}',
        itemId: item.id,
        brand: item.brand,
        name: item.name,
        code: '${DateTime.now().millisecondsSinceEpoch}'.substring(0, 12),
        expiresAt: DateTime(DateTime.now().year + 1, 12, 31),
        createdAt: DateTime.now(),
      ),
    );
  }
}
