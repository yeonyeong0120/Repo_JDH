import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/settings/domain/app_notification.dart';

/// 알림 저장소
///
/// 주의: 알림 백엔드가 아직 없다. 아래 목록은 시안을 재현하기 위한 정적 목업이며
/// 실제 서버 알림이 아니다. 읽음 상태도 앱이 살아 있는 동안만 유지된다.
/// 백엔드가 생기면 이 클래스 안쪽만 교체하면 된다.
class NotificationRepository {
  NotificationRepository._();

  static final List<AppNotification> _today = [
    AppNotification(
      icon: TablerIcons.usersGroup,
      iconBg: AppColors.lime,
      iconColor: AppColors.ink,
      title: '한강 러닝 줍깅에 가입되었어요',
      subtitle: '이제 그룹 활동과 채팅에 참여할 수 있어요',
      time: '방금',
      unread: true,
      kind: NotificationKind.group,
    ),
    AppNotification(
      icon: TablerIcons.rosetteDiscountCheck,
      iconBg: AppColors.ink,
      iconColor: AppColors.lime,
      title: "뱃지 '삼십 분의 여유' 획득",
      subtitle: '+100P와 경험치 10을 받았어요',
      time: '2시간 전',
      unread: true,
      kind: NotificationKind.system,
    ),
    AppNotification(
      icon: TablerIcons.run,
      iconBg: AppColors.surfaceSoft,
      iconColor: AppColors.ink,
      title: '준호 님이 근처에서 뛰고 있어요',
      subtitle: '망원한강공원 · 620m',
      time: '3시간 전',
      unread: true,
      kind: NotificationKind.system,
    ),
  ];

  static final List<AppNotification> _thisWeek = [
    AppNotification(
      icon: TablerIcons.coin,
      iconBg: AppColors.surfaceSoft,
      iconColor: AppColors.ink,
      title: '이번 주 420P가 적립되었어요',
      subtitle: null,
      time: '일요일',
      unread: false,
      kind: NotificationKind.system,
      muted: true,
    ),
    AppNotification(
      icon: TablerIcons.cloudRain,
      iconBg: AppColors.surfaceSoft,
      iconColor: AppColors.ink,
      title: '비 예보 — 우비 챌린지가 열렸어요',
      subtitle: null,
      time: '토요일',
      unread: false,
      kind: NotificationKind.challenge,
      muted: true,
    ),
    AppNotification(
      icon: TablerIcons.targetArrow,
      iconBg: AppColors.surfaceSoft,
      iconColor: AppColors.ink,
      title: '주간 목표 4kg을 달성했어요',
      subtitle: null,
      time: '금요일',
      unread: false,
      kind: NotificationKind.challenge,
      muted: true,
    ),
  ];

  static List<AppNotification> get today => _today;
  static List<AppNotification> get thisWeek => _thisWeek;

  /// 메뉴 화면 배지에 쓰는 안읽음 개수
  static int get unreadCount =>
      _today.where((n) => n.unread).length +
      _thisWeek.where((n) => n.unread).length;

  static bool get hasUnread => unreadCount > 0;

  static void markAllRead() {
    for (final n in _today) {
      n.unread = false;
    }
    for (final n in _thisWeek) {
      n.unread = false;
    }
  }
}
