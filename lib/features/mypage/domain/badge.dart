import 'package:flutter/material.dart';

/// 뱃지 등급 (씨앗 → 새싹 → 나무 → 숲)
enum BadgeTier { seed, sprout, tree, forest }

extension BadgeTierX on BadgeTier {
  String get label => switch (this) {
    BadgeTier.seed => '씨앗',
    BadgeTier.sprout => '새싹',
    BadgeTier.tree => '나무',
    BadgeTier.forest => '숲',
  };
}

/// 보상 아이템 착용 부위 (줍댕이 꾸미기)
enum ItemSlot { hat, face, body, hand }

extension ItemSlotX on ItemSlot {
  String get label => switch (this) {
    ItemSlot.hat => '모자',
    ItemSlot.face => '얼굴',
    ItemSlot.body => '몸',
    ItemSlot.hand => '손',
  };
}

/// 퀘스트 1개 = 뱃지 1개. 완료 시 뱃지 + 꾸미기 아이템 + 에코 포인트 지급.
class BadgeData {
  final String id;
  final String quest; // 퀘스트명
  final String name; // 뱃지명
  final String condition; // 획득조건 (상세 모달에 그대로 노출)
  final String reward; // 보상 아이템명
  final int points; // 에코 포인트
  final BadgeTier tier;
  final ItemSlot slot; // 보상 아이템 착용 부위
  final IconData icon; // TODO: 실제 2D 뱃지 이미지(assets)로 교체

  const BadgeData({
    required this.id,
    required this.quest,
    required this.name,
    required this.condition,
    required this.reward,
    required this.points,
    required this.tier,
    required this.slot,
    required this.icon,
  });
}

/// 전체 뱃지 20개 정의
/// TODO: 뱃지/아이템 아트 완성되면 icon → Image.asset 으로 교체
const List<BadgeData> kBadges = [
  // ── 씨앗 (입문) ──
  BadgeData(
    id: 'first_plogging',
    quest: '첫 플로깅 완료',
    name: '첫 발자국',
    condition: '플로깅 1회 완료',
    reward: '기본 모자',
    points: 100,
    tier: BadgeTier.seed,
    slot: ItemSlot.hat,
    icon: Icons.directions_walk,
  ),
  BadgeData(
    id: 'first_verify',
    quest: '첫 수거 인증',
    name: '첫 인증 성공',
    condition: '쓰레기 수거 인증 1회',
    reward: '노란 장갑',
    points: 100,
    tier: BadgeTier.seed,
    slot: ItemSlot.hand,
    icon: Icons.verified,
  ),
  BadgeData(
    id: 'first_30min',
    quest: '첫 30분 플로깅',
    name: '삼십 분의 여유',
    condition: '30분 이상 플로깅',
    reward: '손목 밴드',
    points: 100,
    tier: BadgeTier.seed,
    slot: ItemSlot.hand,
    icon: Icons.timer,
  ),
  BadgeData(
    id: 'weight_1kg',
    quest: '수거량 1kg 달성',
    name: '한 봉지의 시작',
    condition: '누적 수거량 1kg',
    reward: '작은 가방',
    points: 100,
    tier: BadgeTier.seed,
    slot: ItemSlot.body,
    icon: Icons.shopping_bag_outlined,
  ),

  // ── 새싹 (걸음·수거·시간) ──
  BadgeData(
    id: 'steps_10k',
    quest: '누적 10,000보 걷기',
    name: '만보 산책러',
    condition: '누적 10,000보',
    reward: '운동화',
    points: 300,
    tier: BadgeTier.sprout,
    slot: ItemSlot.body,
    icon: Icons.directions_run,
  ),
  BadgeData(
    id: 'steps_30k',
    quest: '누적 30,000보 걷기',
    name: '삼만보 개척자',
    condition: '누적 30,000보',
    reward: '등산 모자',
    points: 300,
    tier: BadgeTier.sprout,
    slot: ItemSlot.hat,
    icon: Icons.terrain,
  ),
  BadgeData(
    id: 'distance_10km',
    quest: '누적 10km 플로깅',
    name: '십 킬로 완주',
    condition: '누적 이동거리 10km',
    reward: '스포츠 고글',
    points: 300,
    tier: BadgeTier.sprout,
    slot: ItemSlot.face,
    icon: Icons.route,
  ),
  BadgeData(
    id: 'weight_5kg',
    quest: '수거량 5kg 달성',
    name: '우리 동네 청소부',
    condition: '누적 수거량 5kg',
    reward: '빗자루',
    points: 300,
    tier: BadgeTier.sprout,
    slot: ItemSlot.hand,
    icon: Icons.cleaning_services,
  ),
  BadgeData(
    id: 'weight_20kg',
    quest: '수거량 20kg 달성',
    name: '동네 환경 수호자',
    condition: '누적 수거량 20kg',
    reward: '망토',
    points: 300,
    tier: BadgeTier.sprout,
    slot: ItemSlot.body,
    icon: Icons.shield_outlined,
  ),
  BadgeData(
    id: 'plastic_50',
    quest: '플라스틱 50개 수거',
    name: '플라스틱 헌터',
    condition: '플라스틱 누적 50개',
    reward: '리사이클 배지',
    points: 300,
    tier: BadgeTier.sprout,
    slot: ItemSlot.body,
    icon: Icons.recycling,
  ),
  BadgeData(
    id: 'time_3h',
    quest: '누적 3시간 플로깅',
    name: '세 시간의 정성',
    condition: '누적 활동시간 3시간',
    reward: '손목시계',
    points: 300,
    tier: BadgeTier.sprout,
    slot: ItemSlot.hand,
    icon: Icons.watch_later_outlined,
  ),
  BadgeData(
    id: 'time_10h',
    quest: '누적 10시간 플로깅',
    name: '열 시간의 뚝심',
    condition: '누적 활동시간 10시간',
    reward: '챙 넓은 모자',
    points: 300,
    tier: BadgeTier.sprout,
    slot: ItemSlot.hat,
    icon: Icons.wb_sunny_outlined,
  ),
  BadgeData(
    id: 'kcal_500',
    quest: '칼로리 500kcal 소모',
    name: '불태운 하루',
    condition: '누적 500kcal 소모',
    reward: '헤드밴드',
    points: 300,
    tier: BadgeTier.sprout,
    slot: ItemSlot.hat,
    icon: Icons.local_fire_department_outlined,
  ),

  // ── 나무 (그룹·커뮤니티) ──
  BadgeData(
    id: 'group_join',
    quest: '그룹 가입하기',
    name: '함께의 시작',
    condition: '그룹 가입 1회',
    reward: '우정 목도리',
    points: 500,
    tier: BadgeTier.tree,
    slot: ItemSlot.body,
    icon: Icons.handshake_outlined,
  ),
  BadgeData(
    id: 'group_5',
    quest: '그룹 활동 5회 참여',
    name: '든든한 이웃',
    condition: '그룹 활동 5회 참여',
    reward: '그룹 유니폼',
    points: 500,
    tier: BadgeTier.tree,
    slot: ItemSlot.body,
    icon: Icons.groups,
  ),
  BadgeData(
    id: 'group_10',
    quest: '그룹 활동 10회 참여',
    name: '우리 동네 반장',
    condition: '그룹 활동 10회 참여',
    reward: '반장 완장',
    points: 500,
    tier: BadgeTier.tree,
    slot: ItemSlot.body,
    icon: Icons.military_tech_outlined,
  ),
  BadgeData(
    id: 'share_10',
    quest: '인증샷 10번 공유',
    name: '자랑쟁이',
    condition: '인증샷 10회 공유',
    reward: '카메라',
    points: 500,
    tier: BadgeTier.tree,
    slot: ItemSlot.hand,
    icon: Icons.photo_camera_outlined,
  ),

  // ── 숲 (연속 출석) ──
  BadgeData(
    id: 'streak_3',
    quest: '3일 연속 플로고',
    name: '삼일의 약속',
    condition: '3일 연속 플로깅',
    reward: '새싹 화분',
    points: 800,
    tier: BadgeTier.forest,
    slot: ItemSlot.hand,
    icon: Icons.eco_outlined,
  ),
  BadgeData(
    id: 'streak_7',
    quest: '7일 연속 플로고',
    name: '일주일 개근',
    condition: '7일 연속 플로깅',
    reward: '개근 리본',
    points: 1500,
    tier: BadgeTier.forest,
    slot: ItemSlot.body,
    icon: Icons.emoji_events_outlined,
  ),
  BadgeData(
    id: 'streak_30',
    quest: '30일 연속 플로고',
    name: '한 달의 기적',
    condition: '30일 연속 플로깅',
    reward: '왕관',
    points: 3000,
    tier: BadgeTier.forest,
    slot: ItemSlot.hat,
    icon: Icons.workspace_premium_outlined,
  ),
];

/// 획득 현황
/// BadgeService.loadEarned() 가 Firestore 값으로 채운다.
/// (아직 연동 전이면 아래 더미가 그대로 쓰임)
class BadgeRepo {
  /// 획득한 뱃지 id → 달성 일자
  static Map<String, String> earned = {};

  static bool isEarned(String id) => earned.containsKey(id);
  static String? dateOf(String id) => earned[id];

  static BadgeData byId(String id) => kBadges.firstWhere((b) => b.id == id);

  /// 착용 가능한(= 획득한) 아이템만
  static List<BadgeData> ownedItems() =>
      kBadges.where((b) => isEarned(b.id)).toList();
}
