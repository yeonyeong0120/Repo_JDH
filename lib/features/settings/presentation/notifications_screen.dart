import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/news/presentation/news_feed_screen.dart';
import 'package:repo_jdh/features/settings/data/notification_repository.dart';
import 'package:repo_jdh/features/settings/domain/app_notification.dart';

/// 알림 화면 (Startline 목업 33 — 메뉴 → 알림)
/// 오늘 / 이번 주 로 그룹된 알림 피드. 각 항목은 아이콘 타일 + 제목 + 부제 + 시간,
/// 안읽음 도트. 우상단 "모두 읽음" 으로 도트 일괄 제거.
///
/// 데이터 주의: 알림 백엔드(provider/service)가 아직 없다. 아래 목록은
/// 목업 재현을 위한 정적 샘플이며 실제 서버 알림이 아니다. 백엔드가 생기면
/// 이 정적 목록을 provider 로 교체한다.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // 목록은 NotificationRepository 가 들고 있다(백엔드 생기면 그쪽만 교체).
  List<AppNotification> get _today => NotificationRepository.today;
  List<AppNotification> get _thisWeek => NotificationRepository.thisWeek;

  // 안읽음 항목이 하나라도 있는지 (모두 읽음 버튼 활성 판단)
  bool get _hasUnread => NotificationRepository.hasUnread;

  void _markAllRead() {
    if (!_hasUnread) return;
    setState(NotificationRepository.markAllRead);
  }

  // ── 알림 행 탭 (F-4): 종류별 이동 대상으로 분기 ──
  // 그룹/챌린지는 신뢰할 대상 id가 없어 스낵바로 안내하고,
  // 시스템 알림은 실제 대상인 환경 뉴스 목록으로 이동한다.
  void _openNoti(AppNotification n) {
    switch (n.kind) {
      case NotificationKind.group:
        AppSnackBar.show(context, '그룹 채팅으로 이동해요');
      case NotificationKind.challenge:
        AppSnackBar.show(context, '챌린지로 이동해요');
      case NotificationKind.system:
        Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute<void>(builder: (_) => const NewsFeedScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _sectionLabel('오늘'),
                  for (final n in _today) _item(n),
                  const SizedBox(height: 24),
                  _sectionLabel('이번 주'),
                  for (final n in _thisWeek) _item(n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 상단 바 (뒤로 + 중앙 제목 + 모두 읽음) ──
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                TablerIcons.chevronLeft,
                size: 24,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '알림',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _markAllRead,
            child: Text(
              '모두 읽음',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _hasUnread ? AppColors.gray500 : AppColors.gray400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 섹션 라벨 ──
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 0, 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: AppColors.gray500,
        ),
      ),
    );
  }

  // ── 알림 항목 한 행 ──
  Widget _item(AppNotification n) {
    final muted = n.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNoti(n),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.line100, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘 타일
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: n.iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                n.icon,
                size: 22,
                color: muted ? AppColors.gray500 : n.iconColor,
              ),
            ),
            const SizedBox(width: 14),
            // 텍스트 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: muted ? FontWeight.w600 : FontWeight.w700,
                      height: 1.45,
                      color: muted ? AppColors.gray700 : AppColors.ink,
                    ),
                  ),
                  if (n.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      n.subtitle!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.55,
                        color: AppColors.gray600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    n.time,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray350,
                    ),
                  ),
                ],
              ),
            ),
            // 안읽음 도트
            if (n.unread)
              Container(
                margin: const EdgeInsets.only(top: 4, left: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.ink,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
