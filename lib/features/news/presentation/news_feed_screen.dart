import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'news_detail_screen.dart';
import 'news_service.dart';

/// 정보 & 뉴스 피드 화면 (환경뉴스 목록)
/// 위치 제안: lib/features/news/presentation/news_feed_screen.dart
/// 홈의 환경뉴스 카드 → 이 화면 → 뉴스 상세
///
/// 서버(FastAPI /news)에서 네이버 환경 뉴스를 실제로 불러온다.
class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  // null: 로딩 중 / []: 로딩됐고 0건 / [..]: 데이터 있음
  List<NewsArticle>? _articles;
  Object? _error; // null 아니면 에러

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _articles = null; // 로딩 상태로
      _error = null;
    });
    try {
      final list = await NewsService.fetchNews();
      if (!mounted) return;
      setState(() => _articles = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // 4가지 상태 처리: 로딩 / 에러 / 빈 목록 / 데이터
  Widget _buildBody() {
    // ① 에러
    if (_error != null) {
      return _CenterMessage(
        icon: Icons.cloud_off,
        title: '뉴스를 불러오지 못했어요',
        actionLabel: '다시 시도',
        onAction: _load,
      );
    }
    // ② 로딩 중
    if (_articles == null) {
      return const Center(child: CircularProgressIndicator());
    }
    // ③ 빈 목록
    if (_articles!.isEmpty) {
      return const _CenterMessage(
        icon: Icons.article_outlined,
        title: '표시할 뉴스가 없어요',
      );
    }
    // ④ 데이터
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: _articles!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) => _newsCard(context, _articles![i]),
    );
  }

  Widget _newsCard(BuildContext context, NewsArticle a) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 관련 뉴스: 같은 카테고리 기사를 우선, 부족하면 나머지로 채워 3개
        final sameCategory = _articles!
            .where((x) => x != a && x.category == a.category)
            .toList();
        final others = _articles!
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 원본 기사 사진이 있으면 왼쪽에 표시, 없으면 생략
            if (a.imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  a.imageUrl,
                  width: 66,
                  height: 66,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.category,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    a.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          a.reporter,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        a.date,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
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

// 로딩/에러/빈 상태 공용 중앙 메시지
class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _CenterMessage({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}