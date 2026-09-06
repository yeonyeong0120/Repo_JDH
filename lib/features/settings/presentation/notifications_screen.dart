import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/news/presentation/news_feed_screen.dart';

/// 알림 종류. 탭 시 이동 대상을 결정한다(F-4).
enum _NotiKind { group, challenge, system }

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
  // 정적 샘플 알림 (실서버 데이터 아님 — 위 주석 참고)
  final List<_Noti> _today = [
    _Noti(
      icon: TablerIcons.usersGroup,
      iconBg: AppColors.lime,
      iconColor: AppColors.limeOn,
      title: "한강 러닝 줍깅에 가입되었어요",
      subtitle: '이제 그룹 활동과 채팅에 참여할 수 있어요',
      time: '방금',
      unread: true,
      kind: _NotiKind.group,
    ),
    _Noti(
      icon: TablerIcons.rosetteDiscountCheck,
      iconBg: AppColors.ink,
      iconColor: AppColors.lime,
      title: "뱃지 '삼십 분의 여유' 획득",
      subtitle: '+100P와 경험치 10을 받았어요',
      time: '2시간 전',
      unread: true,
      kind: _NotiKind.system,
    ),
    _Noti(
      icon: TablerIcons.run,
      iconBg: AppColors.surfaceSoft,
      iconColor: AppColors.ink,
      title: '준호 님이 근처에서 뛰고 있어요',
      subtitle: '망원한강공원 · 620m',
      time: '3시간 전',
      unread: false,
      kind: _NotiKind.system,
    ),
  ];

  final List<_Noti> _thisWeek = [
    _Noti(
      icon: TablerIcons.currencyDollar,
      iconBg: AppColors.surfaceSoft,
      iconColor: AppColors.ink,
      title: '이번 주 420P가 적립되었어요',
      subtitle: null,
      time: '일요일',
      unread: false,
      kind: _NotiKind.system,
    ),
    _Noti(
      icon: TablerIcons.cloudRain,
      iconBg: AppColors.surfaceSoft,
      iconColor: AppColors.ink,
      title: '비 예보 — 우비 챌린지가 열렸어요',
      subtitle: null,
      time: '토요일',
      unread: false,
      kind: _NotiKind.challenge,
    ),
    _Noti(
      icon: TablerIcons.target,
      iconBg: AppColors.surfaceSoft,
      iconColor: AppColors.ink,
      title: '주간 목표 4kg를 달성했어요',
      subtitle: null,
      time: '금요일',
      unread: false,
      kind: _NotiKind.challenge,
    ),
  ];

  // 안읽음 항목이 하나라도 있는지 (모두 읽음 버튼 활성 판단)
  bool get _hasUnread =>
      _today.any((n) => n.unread) || _thisWeek.any((n) => n.unread);

  void _markAllRead() {
    if (!_hasUnread) return;
    setState(() {
      for (final n in _today) {
        n.unread = false;
      }
      for (final n in _thisWeek) {
        n.unread = false;
      }
    });
  }

  // ── 알림 행 탭 (F-4): 종류별 이동 대상으로 분기 ──
  // 그룹/챌린지는 신뢰할 대상 id가 없어 스낵바로 안내하고,
  // 시스템 알림은 실제 대상인 환경 뉴스 목록으로 이동한다.
  void _openNoti(_Noti n) {
    switch (n.kind) {
      case _NotiKind.group:
        AppSnackBar.show(context, '그룹 채팅으로 이동해요');
      case _NotiKind.challenge:
        AppSnackBar.show(context, '챌린지로 이동해요');
      case _NotiKind.system:
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const NewsFeedScreen()),
        );
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
                fontSize: 20,
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _hasUnread ? AppColors.gray700 : AppColors.gray400,
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
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.gray400,
        ),
      ),
    );
  }

  // ── 알림 항목 한 행 ──
  Widget _item(_Noti n) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNoti(n),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.line100, width: 1)),
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
            child: Icon(n.icon, size: 22, color: n.iconColor),
          ),
          const SizedBox(width: 14),
          // 텍스트 영역
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppColors.ink,
                  ),
                ),
                if (n.subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    n.subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  n.time,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray400,
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

/// 알림 항목 정의 (정적 샘플 — 실서버 데이터 아님)
class _Noti {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String time;
  final _NotiKind kind;
  bool unread;

  _Noti({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
    required this.kind,
  });
}
