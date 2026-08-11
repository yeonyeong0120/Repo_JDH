import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

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

/// 퀘스트 1개 = 뱃지 1개. 완료 시 뱃지 + 에코 포인트 지급.
/// (줍댕이 꾸미기 기능은 범위에서 제외 — reward/slot 필드 삭제)
class BadgeData {
  final String id;
  final String quest; // 퀘스트명
  final String name; // 뱃지명
  final String condition; // 획득조건 (상세 모달에 그대로 노출)
  final int points; // 에코 포인트
  final BadgeTier tier;
  final IconData icon; // TODO: 실제 2D 뱃지 이미지(assets)로 교체

  const BadgeData({
    required this.id,
    required this.quest,
    required this.name,
    required this.condition,
    required this.points,
    required this.tier,
    required this.icon,
  });
}

/// 전체 뱃지 20개 정의
/// TODO: 뱃지 아트 완성되면 icon → Image.asset 으로 교체
const List<BadgeData> kBadges = [
  // ── 씨앗 (입문) ──
  BadgeData(
    id: 'first_plogging',
    quest: '첫 플로깅 완료',
    name: '첫 발자국',
    condition: '플로깅 1회 완료',
    points: 100,
    tier: BadgeTier.seed,
    icon: Icons.directions_walk,
  ),
  BadgeData(
    id: 'first_verify',
    quest: '첫 수거 인증',
    name: '첫 인증 성공',
    condition: '쓰레기 수거 인증 1회',
    points: 100,
    tier: BadgeTier.seed,
    icon: Icons.verified,
  ),
  BadgeData(
    id: 'first_30min',
    quest: '첫 30분 플로깅',
    name: '삼십 분의 여유',
    condition: '30분 이상 플로깅',
    points: 100,
    tier: BadgeTier.seed,
    icon: Icons.timer,
  ),
  BadgeData(
    id: 'weight_1kg',
    quest: '수거량 1kg 달성',
    name: '한 봉지의 시작',
    condition: '누적 수거량 1kg',
    points: 100,
    tier: BadgeTier.seed,
    icon: Icons.shopping_bag_outlined,
  ),

  // ── 새싹 (걸음·수거·시간) ──
  BadgeData(
    id: 'steps_10k',
    quest: '누적 10,000보 걷기',
    name: '만보 산책러',
    condition: '누적 10,000보',
    points: 300,
    tier: BadgeTier.sprout,
    icon: Icons.directions_run,
  ),
  BadgeData(
    id: 'steps_30k',
    quest: '누적 30,000보 걷기',
    name: '삼만보 개척자',
    condition: '누적 30,000보',
    points: 300,
    tier: BadgeTier.sprout,
    icon: Icons.terrain,
  ),
  BadgeData(
    id: 'distance_10km',
    quest: '누적 10km 플로깅',
    name: '십 킬로 완주',
    condition: '누적 이동거리 10km',
    points: 300,
    tier: BadgeTier.sprout,
    icon: Icons.route,
  ),
  BadgeData(
    id: 'weight_5kg',
    quest: '수거량 5kg 달성',
    name: '우리 동네 청소부',
    condition: '누적 수거량 5kg',
    points: 300,
    tier: BadgeTier.sprout,
    icon: Icons.cleaning_services,
  ),
  BadgeData(
    id: 'weight_20kg',
    quest: '수거량 20kg 달성',
    name: '동네 환경 수호자',
    condition: '누적 수거량 20kg',
    points: 300,
    tier: BadgeTier.sprout,
    icon: Icons.inventory_2_outlined,
  ),
  BadgeData(
    id: 'plastic_50',
    quest: '플라스틱 50개 수거',
    name: '플라스틱 헌터',
    condition: '플라스틱 누적 50개',
    points: 300,
    tier: BadgeTier.sprout,
    icon: Icons.recycling,
  ),
  BadgeData(
    id: 'time_3h',
    quest: '누적 3시간 플로깅',
    name: '세 시간의 정성',
    condition: '누적 활동시간 3시간',
    points: 300,
    tier: BadgeTier.sprout,
    icon: Icons.watch_later_outlined,
  ),
  BadgeData(
    id: 'time_10h',
    quest: '누적 10시간 플로깅',
    name: '열 시간의 뚝심',
    condition: '누적 활동시간 10시간',
    points: 300,
    tier: BadgeTier.sprout,
    icon: Icons.wb_sunny_outlined,
  ),
  BadgeData(
    id: 'kcal_500',
    quest: '칼로리 500kcal 소모',
    name: '불태운 하루',
    condition: '누적 500kcal 소모',
    points: 300,
    tier: BadgeTier.sprout,
    icon: Icons.local_fire_department_outlined,
  ),

  // ── 나무 (그룹·커뮤니티) ──
  BadgeData(
    id: 'group_join',
    quest: '그룹 가입하기',
    name: '함께의 시작',
    condition: '그룹 가입 1회',
    points: 500,
    tier: BadgeTier.tree,
    icon: Icons.handshake_outlined,
  ),
  BadgeData(
    id: 'group_5',
    quest: '그룹 활동 5회 참여',
    name: '든든한 이웃',
    condition: '그룹 활동 5회 참여',
    points: 500,
    tier: BadgeTier.tree,
    icon: Icons.groups,
  ),
  BadgeData(
    id: 'group_10',
    quest: '그룹 활동 10회 참여',
    name: '우리 동네 반장',
    condition: '그룹 활동 10회 참여',
    points: 500,
    tier: BadgeTier.tree,
    icon: Icons.military_tech_outlined,
  ),
  BadgeData(
    id: 'share_10',
    quest: '인증샷 10번 공유',
    name: '자랑쟁이',
    condition: '인증샷 10회 공유',
    points: 500,
    tier: BadgeTier.tree,
    icon: Icons.photo_camera_outlined,
  ),

  // ── 숲 (연속 출석) ──
  BadgeData(
    id: 'streak_3',
    quest: '3일 연속 플로깅',
    name: '삼일의 약속',
    condition: '3일 연속 플로깅',
    points: 800,
    tier: BadgeTier.forest,
    icon: Icons.eco_outlined,
  ),
  BadgeData(
    id: 'streak_7',
    quest: '7일 연속 플로깅',
    name: '일주일 개근',
    condition: '7일 연속 플로깅',
    points: 1500,
    tier: BadgeTier.forest,
    icon: Icons.emoji_events_outlined,
  ),
  BadgeData(
    id: 'streak_30',
    quest: '30일 연속 플로깅',
    name: '한 달의 기적',
    condition: '30일 연속 플로깅',
    points: 3000,
    tier: BadgeTier.forest,
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

  /// 획득한 뱃지만 (등급별 목록 · 정산 화면에서 사용)
  static List<BadgeData> earnedBadges() =>
      kBadges.where((b) => isEarned(b.id)).toList();
}

/// 뱃지 카테고리 색 — 지표 색과 짝을 맞춘다. 타일·링·상세 팝업에서 공통 사용.
///  걸음·거리=파랑 / 수거=초록 / 그룹=주황 / 시간=노랑 / 칼로리=빨강
Color badgeColor(BadgeData b) {
  final id = b.id;
  if (id.startsWith('steps') ||
      id.startsWith('distance') ||
      id == 'first_plogging') {
    return AppColors.dataSteps;
  }
  if (id.startsWith('kcal')) return AppColors.dataCalorie;
  if (id.startsWith('weight') ||
      id.startsWith('plastic') ||
      id == 'first_verify') {
    return AppColors.green600;
  }
  if (id.startsWith('group') || id.startsWith('share')) {
    return AppColors.dataGroup;
  }
  if (id.startsWith('time') || id == 'first_30min') return AppColors.dataTime;
  return AppColors.green600; // 연속(숲) 등 기타
}

/// 뱃지 경험치 = 포인트 / 25 (상세 팝업 표시용)
int badgeXp(BadgeData b) => b.points ~/ 25;

/// 쓰레기봉투 아이콘으로 표시할 뱃지 — 수거 '봉지' 뱃지('한 봉지의 시작') 하나뿐.
/// 같은 아이콘을 여러 뱃지에 중복해서 쓰지 않는다.
bool usesTrashBagIcon(BadgeData b) => b.id == 'weight_1kg';
