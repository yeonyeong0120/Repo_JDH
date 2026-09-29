import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
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

/// 뱃지 분류 — 시안의 판 모양·색과 짝을 이룬다.
///   blue=걸음·장소(원) / green=수거(방패) / amber=그룹·시간(육각) / coral=연속 기록(원)
enum BadgeGroup { blue, green, amber, coral }

/// 퀘스트 1개 = 뱃지 1개. 완료 시 뱃지 + 에코 포인트 지급.
class BadgeData {
  final String id;
  final String quest; // 퀘스트명
  final String name; // 뱃지명
  final String condition; // 획득조건 (상세 모달에 그대로 노출)
  final int points; // 에코 포인트
  final BadgeTier tier;
  final IconData icon; // 챌린지 목록용 아이콘
  final String art; // 뱃지 아트 파일명 (assets/badges/)
  final BadgeGroup group;

  const BadgeData({
    required this.id,
    required this.quest,
    required this.name,
    required this.condition,
    required this.points,
    required this.tier,
    required this.icon,
    required this.art,
    required this.group,
  });

  /// 획득 뱃지 아트 경로
  String get artPath => 'assets/badges/$art.png';

  /// 미획득 자리는 분류별 빈 판을 쓴다
  String get lockedArtPath => switch (group) {
    BadgeGroup.green => 'assets/badges/locked_shield.png',
    BadgeGroup.amber => 'assets/badges/locked_hex.png',
    BadgeGroup.blue || BadgeGroup.coral => 'assets/badges/locked_circle.png',
  };
}

/// 전체 뱃지 33개 정의 (시안 badges-final 과 1:1)
const List<BadgeData> kBadges = [
  BadgeData(
    id: 'first_plogging',
    quest: '첫 플로깅 완료',
    name: '걸음마 성공',
    condition: '플로깅 1회 완료',
    points: 100,
    tier: BadgeTier.seed,
    icon: TablerIcons.walk,
    art: '01_running_shoe',
    group: BadgeGroup.blue,
  ),
  BadgeData(
    id: 'group_join',
    quest: '첫 그룹 가입',
    name: '첫 그룹 가입',
    condition: '그룹 가입 1회',
    points: 100,
    tier: BadgeTier.seed,
    icon: TablerIcons.usersGroup,
    art: '02_handshake',
    group: BadgeGroup.amber,
  ),
  BadgeData(
    id: 'first_verify',
    quest: '첫 수거 인증',
    name: '첫 인증샷',
    condition: '쓰레기 수거 인증 1회',
    points: 100,
    tier: BadgeTier.seed,
    icon: TablerIcons.camera,
    art: '03_camera_with_flash',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'first_30min',
    quest: '첫 30분 플로깅',
    name: '삼십 분의 여유',
    condition: '30분 이상 플로깅',
    points: 100,
    tier: BadgeTier.seed,
    icon: TablerIcons.clock,
    art: '04_stopwatch',
    group: BadgeGroup.amber,
  ),
  BadgeData(
    id: 'steps_10k',
    quest: '누적 10,000보',
    name: '만보 산책러',
    condition: '누적 10,000보',
    points: 200,
    tier: BadgeTier.sprout,
    icon: TablerIcons.shoe,
    art: '05_person_walking',
    group: BadgeGroup.blue,
  ),
  BadgeData(
    id: 'plastic_50',
    quest: '플라스틱 50개 수거',
    name: '플라스틱 헌터',
    condition: '플라스틱 누적 50개',
    points: 200,
    tier: BadgeTier.sprout,
    icon: TablerIcons.recycle,
    art: '06_recycling_symbol',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'rain_day',
    quest: '비 오는 날 플로깅',
    name: '비 오는 날 전사',
    condition: '비 오는 날 플로깅 1회',
    points: 200,
    tier: BadgeTier.sprout,
    icon: TablerIcons.umbrella,
    art: '07_umbrella_with_rain_drops',
    group: BadgeGroup.amber,
  ),
  BadgeData(
    id: 'streak_7',
    quest: '7일 연속 플로깅',
    name: '연속 7일',
    condition: '7일 연속 플로깅',
    points: 300,
    tier: BadgeTier.forest,
    icon: TablerIcons.flame,
    art: '08_fire',
    group: BadgeGroup.coral,
  ),
  BadgeData(
    id: 'can_100',
    quest: '캔 100개 수거',
    name: '캔 백 개',
    condition: '캔 누적 100개',
    points: 300,
    tier: BadgeTier.sprout,
    icon: TablerIcons.bottle,
    art: '09_canned_food',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'glass_30',
    quest: '유리 30개 수거',
    name: '유리 수집가',
    condition: '유리 누적 30개',
    points: 300,
    tier: BadgeTier.sprout,
    icon: TablerIcons.glassFull,
    art: '10_wine_glass',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'paper_100',
    quest: '종이 100개 수거',
    name: '종이 지킴이',
    condition: '종이 누적 100개',
    points: 300,
    tier: BadgeTier.sprout,
    icon: TablerIcons.news,
    art: '11_newspaper',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'weight_10kg',
    quest: '수거량 10kg 달성',
    name: '십 킬로 달성',
    condition: '누적 수거량 10kg',
    points: 300,
    tier: BadgeTier.sprout,
    icon: TablerIcons.package,
    art: '12_package',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'distance_10km',
    quest: '누적 10km 이동',
    name: '동네 한 바퀴',
    condition: '누적 이동거리 10km',
    points: 200,
    tier: BadgeTier.sprout,
    icon: TablerIcons.map,
    art: '13_world_map',
    group: BadgeGroup.blue,
  ),
  BadgeData(
    id: 'course_repeat',
    quest: '같은 코스 5회',
    name: '단골 코스',
    condition: '같은 코스 5회 방문',
    points: 300,
    tier: BadgeTier.tree,
    icon: TablerIcons.pin,
    art: '14_pushpin',
    group: BadgeGroup.blue,
  ),
  BadgeData(
    id: 'river_master',
    quest: '한강에서 10회',
    name: '한강 마스터',
    condition: '한강 코스 10회 활동',
    points: 400,
    tier: BadgeTier.tree,
    icon: TablerIcons.ripple,
    art: '15_water_wave',
    group: BadgeGroup.blue,
  ),
  BadgeData(
    id: 'early_bird',
    quest: '새벽 플로깅',
    name: '새벽 플로거',
    condition: '오전 6시 이전 활동 5회',
    points: 300,
    tier: BadgeTier.tree,
    icon: TablerIcons.sunrise,
    art: '16_sunrise',
    group: BadgeGroup.amber,
  ),
  BadgeData(
    id: 'night_owl',
    quest: '야간 플로깅',
    name: '야간 플로거',
    condition: '오후 9시 이후 활동 5회',
    points: 300,
    tier: BadgeTier.tree,
    icon: TablerIcons.moon,
    art: '17_crescent_moon',
    group: BadgeGroup.amber,
  ),
  BadgeData(
    id: 'group_leader',
    quest: '그룹 만들기',
    name: '그룹 리더',
    condition: '그룹장으로 그룹 운영',
    points: 400,
    tier: BadgeTier.tree,
    icon: TablerIcons.speakerphone,
    art: '18_megaphone',
    group: BadgeGroup.amber,
  ),
  BadgeData(
    id: 'invite_5',
    quest: '멤버 5명 초대',
    name: '멤버 초대왕',
    condition: '그룹에 멤버 5명 초대',
    points: 400,
    tier: BadgeTier.tree,
    icon: TablerIcons.mail,
    art: '19_love_letter',
    group: BadgeGroup.amber,
  ),
  BadgeData(
    id: 'streak_30',
    quest: '30일 연속 플로깅',
    name: '연속 30일',
    condition: '30일 연속 플로깅',
    points: 500,
    tier: BadgeTier.forest,
    icon: TablerIcons.calendar,
    art: '20_calendar',
    group: BadgeGroup.coral,
  ),
  BadgeData(
    id: 'weight_50kg',
    quest: '수거량 50kg 달성',
    name: '오십 킬로 달성',
    condition: '누적 수거량 50kg',
    points: 500,
    tier: BadgeTier.tree,
    icon: TablerIcons.medal,
    art: '21_sports_medal',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'weight_100kg',
    quest: '수거량 100kg 달성',
    name: '백 킬로 달성',
    condition: '누적 수거량 100kg',
    points: 700,
    tier: BadgeTier.forest,
    icon: TablerIcons.trophy,
    art: '22_trophy',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'tumbler_30',
    quest: '텀블러 30일',
    name: '텀블러 30일',
    condition: '텀블러 사용 30일',
    points: 400,
    tier: BadgeTier.tree,
    icon: TablerIcons.cup,
    art: '23_hot_beverage',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'market_clean',
    quest: '시장 청소',
    name: '시장 청소단',
    condition: '시장 코스 5회 활동',
    points: 300,
    tier: BadgeTier.tree,
    icon: TablerIcons.shoppingCart,
    art: '24_shopping_cart',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'park_keeper',
    quest: '공원 청소',
    name: '공원 지킴이',
    condition: '공원 코스 5회 활동',
    points: 300,
    tier: BadgeTier.tree,
    icon: TablerIcons.tree,
    art: '25_deciduous_tree',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'school_road',
    quest: '학교길 청소',
    name: '학교길 안전',
    condition: '학교 주변 5회 활동',
    points: 300,
    tier: BadgeTier.tree,
    icon: TablerIcons.school,
    art: '26_school',
    group: BadgeGroup.blue,
  ),
  BadgeData(
    id: 'station_clean',
    quest: '역 주변 청소',
    name: '역세권 청소',
    condition: '역 주변 5회 활동',
    points: 300,
    tier: BadgeTier.tree,
    icon: TablerIcons.train,
    art: '27_station',
    group: BadgeGroup.blue,
  ),
  BadgeData(
    id: 'weekend_5',
    quest: '주말 플로깅',
    name: '주말 개근',
    condition: '주말 활동 5회',
    points: 300,
    tier: BadgeTier.tree,
    icon: TablerIcons.sun,
    art: '28_sun',
    group: BadgeGroup.amber,
  ),
  BadgeData(
    id: 'point_5000',
    quest: '포인트 5,000P',
    name: '포인트 부자',
    condition: '포인트 5,000P 보유',
    points: 500,
    tier: BadgeTier.forest,
    icon: TablerIcons.coin,
    art: '29_coin',
    group: BadgeGroup.amber,
  ),
  BadgeData(
    id: 'rank_1',
    quest: '랭킹 1위',
    name: '랭킹 1위',
    condition: '그룹 랭킹 1위 달성',
    points: 700,
    tier: BadgeTier.forest,
    icon: TablerIcons.crown,
    art: '30_crown',
    group: BadgeGroup.amber,
  ),
  BadgeData(
    id: 'trash_1000',
    quest: '1,000개 수거',
    name: '천 개 수거',
    condition: '누적 수거 1,000개',
    points: 700,
    tier: BadgeTier.forest,
    icon: TablerIcons.trash,
    art: '31_wastebasket',
    group: BadgeGroup.green,
  ),
  BadgeData(
    id: 'four_seasons',
    quest: '사계절 플로깅',
    name: '사계절 플로거',
    condition: '네 계절 모두 활동',
    points: 700,
    tier: BadgeTier.forest,
    icon: TablerIcons.snowflake,
    art: '32_snowflake',
    group: BadgeGroup.amber,
  ),
  BadgeData(
    id: 'recommend_10',
    quest: '이웃 추천 10회',
    name: '이웃 추천왕',
    condition: '이웃에게 추천 10회',
    points: 500,
    tier: BadgeTier.forest,
    icon: TablerIcons.thumbUp,
    art: '33_thumbs_up',
    group: BadgeGroup.amber,
  ),
];

/// 획득 현황
/// BadgeService.loadEarned() 가 Firestore 값으로 채운다.
class BadgeRepo {
  /// 획득한 뱃지 id → 달성 일자
  static Map<String, String> earned = {};

  static bool isEarned(String id) => earned.containsKey(id);
  static String? dateOf(String id) => earned[id];

  /// 로그아웃 시 이전 계정의 획득 현황이 남지 않도록 비운다
  static void clear() => earned = {};

  static BadgeData byId(String id) => kBadges.firstWhere((b) => b.id == id);

  /// 획득한 뱃지만 (등급별 목록 · 정산 화면에서 사용)
  static List<BadgeData> earnedBadges() =>
      kBadges.where((b) => isEarned(b.id)).toList();
}

/// 뱃지 분류 색 — 타일 링·챌린지 아이콘에서 공통 사용.
Color badgeColor(BadgeData b) => switch (b.group) {
  BadgeGroup.blue => AppColors.dataSteps,
  BadgeGroup.green => AppColors.dataCollect,
  BadgeGroup.amber => AppColors.dataGroup,
  BadgeGroup.coral => AppColors.dataCalorie,
};

/// 뱃지 경험치 = 포인트 / 25 (상세 팝업 표시용)
int badgeXp(BadgeData b) => b.points ~/ 25;

/// 쓰레기봉투 아이콘으로 표시할 뱃지 — 수거 개수 뱃지 하나뿐.
/// 같은 아이콘을 여러 뱃지에 중복해서 쓰지 않는다.
bool usesTrashBagIcon(BadgeData b) => b.id == 'trash_1000';
