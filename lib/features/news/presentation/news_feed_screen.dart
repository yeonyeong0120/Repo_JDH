import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'news_detail_screen.dart';

/// 정보 & 뉴스 피드 화면 (환경뉴스 목록)
/// 위치 제안: lib/features/news/presentation/news_feed_screen.dart
/// 홈의 환경뉴스 카드 → 이 화면 → 뉴스 상세
class NewsFeedScreen extends StatelessWidget {
  const NewsFeedScreen({super.key});

  // TODO: 실제 기사 데이터로 교체 (API / Firestore 등)
  //       최신순으로 정렬해서 넣을 것 — 홈 카드가 첫 번째를 최신 기사로 사용한다.
  static const List<NewsArticle> articles = [
    NewsArticle(
      category: '재활용',
      title: '페트병 라벨, 이렇게 떼세요!',
      summary: '올바른 분리배출 꿀팁, 라벨부터 뚜껑까지 한 번에 정리했어요.',
      reporter: '고냐니 기자',
      date: '2시간 전',
      emoji: '♻️',
      body: [
        '투명 페트병은 라벨을 완전히 제거한 뒤 내용물을 비우고 압착해 배출해야 재활용 가치가 높아집니다.',
        '라벨은 절취선을 따라 뜯거나, 절취선이 없다면 칼집을 내 벗겨내면 쉽게 분리할 수 있어요. 뚜껑은 따로 모아 배출합니다.',
        '작은 습관이 모여 재활용률을 크게 끌어올립니다. 오늘 배출하는 페트병부터 라벨을 떼어보세요.',
      ],
    ),
    NewsArticle(
      category: '정책',
      title: '내년부터 일회용컵 보증금제 확대',
      summary: '카페 일회용컵에 보증금이 붙습니다. 반납하면 돌려받아요.',
      reporter: '박지구 기자',
      date: '5시간 전',
      emoji: '🥤',
      body: [
        '일회용컵 보증금제가 내년부터 더 많은 지역으로 확대 시행됩니다.',
        '음료 구매 시 보증금이 부과되고, 컵을 반납하면 전액 돌려받는 구조입니다. 텀블러 사용이 더욱 권장됩니다.',
      ],
    ),
    NewsArticle(
      category: '캠페인',
      title: '이번 주말, 우리 동네 플로깅 챌린지',
      summary: '동네 이웃들과 함께 걷고 주우며 포인트도 받아가세요.',
      reporter: '이초록 기자',
      date: '어제',
      emoji: '🚶',
      body: [
        '주말마다 동네 곳곳에서 플로깅 챌린지가 열립니다.',
        '참여하고 인증하면 포인트와 뱃지를 받을 수 있어요. 가벼운 마음으로 함께해요.',
      ],
    ),
    NewsArticle(
      category: '생활',
      title: '음식물 쓰레기 줄이는 냉장고 정리법',
      summary: '버려지는 식재료를 줄이는 작은 배치의 기술.',
      reporter: '고냐니 기자',
      date: '2일 전',
      emoji: '🥬',
      body: [
        '냉장고 속 식재료를 보이는 곳에 배치하면 유통기한 내 소비율이 올라갑니다.',
        '먼저 먹어야 할 것을 앞쪽에 두는 습관만으로도 음식물 쓰레기를 크게 줄일 수 있어요.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '환경뉴스',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                itemCount: articles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) => _newsCard(context, articles[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newsCard(BuildContext context, NewsArticle a) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 같은 분류 기사를 관련 뉴스로 전달 (부족하면 나머지 기사로 채움)
        final sameCategory = articles
            .where((x) => x != a && x.category == a.category)
            .toList();
        final others = articles
            .where((x) => x != a && x.category != a.category)
            .toList();
        final related = [...sameCategory, ...others].take(3).toList();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailScreen(article: a, related: related),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 (이모지 placeholder → 실제 이미지로 교체)
            Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryPale,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(a.emoji, style: const TextStyle(fontSize: 34)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.category,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        a.reporter,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        a.date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
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
