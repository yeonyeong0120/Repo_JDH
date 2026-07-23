import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 공지사항 목록 (EXTRA-03) → 카드 탭 → 상세 (EXTRA-04)
/// 위치 권장: lib/features/settings/presentation/notice_screen.dart
class NoticeListScreen extends StatelessWidget {
  const NoticeListScreen({super.key});

  // TODO: Firestore notices 컬렉션으로 교체 (제목/본문/작성일)
  static final List<Notice> _notices = [
    Notice(
      title: '플로고 정식 오픈 안내',
      date: DateTime(2026, 2, 1),
      body:
          '안녕하세요, 플로고입니다.\n\n'
          '우리 동네를 함께 깨끗하게 만드는 플로깅 앱 플로고가 정식으로 문을 열었습니다.\n\n'
          '걷고 주우면 활동이 기록되고, 퀘스트를 달성하면 뱃지와 에코 포인트를 드려요. '
          '모은 포인트는 에코포인트 상점에서 사용할 수 있습니다.\n\n'
          '앞으로도 더 나은 서비스로 찾아뵙겠습니다. 감사합니다.',
    ),
    Notice(
      title: '뱃지 시스템 업데이트',
      date: DateTime(2026, 1, 28),
      body:
          '퀘스트와 뱃지가 새롭게 추가되었습니다.\n\n'
          '· 총 20개의 퀘스트와 뱃지\n'
          '· 퀘스트 달성 시 줍댕이 꾸미기 아이템 지급\n'
          '· 연속 활동 시 추가 포인트 지급\n\n'
          '내 활동 > 뱃지 탭에서 확인해보세요.',
    ),
    Notice(
      title: '개인정보 처리방침 개정 안내',
      date: DateTime(2026, 1, 15),
      body:
          '개인정보 처리방침이 일부 개정되었습니다.\n\n'
          '주요 변경 사항은 위치정보 수집 항목의 명확화이며, '
          '자세한 내용은 메뉴 > 이용 약관 및 정책에서 확인하실 수 있습니다.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(title: '공지사항'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                itemCount: _notices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _card(context, _notices[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Notice n) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoticeDetailScreen(notice: n)),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // 최근 7일 이내면 새글 표시
                      if (n.isNew) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPale,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.dateText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class NoticeDetailScreen extends StatelessWidget {
  final Notice notice;
  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(title: '공지사항'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  Text(
                    notice.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notice.dateText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: 18),
                  Text(
                    notice.body,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Notice {
  final String title;
  final DateTime date;
  final String body;
  Notice({required this.title, required this.date, required this.body});

  String get dateText =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}'
      '.${date.day.toString().padLeft(2, '0')}';

  bool get isNew => DateTime.now().difference(date).inDays <= 7;
}

/// 공지/FAQ/약관 공통 상단 바
class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
