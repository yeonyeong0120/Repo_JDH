import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
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
                    icon: const Icon(TablerIcons.chevronLeft, size: 20),
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
        icon: TablerIcons.cloudOff,
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
        icon: TablerIcons.article,
        title: '표시할 뉴스가 없어요',
      );
    }
    // ④ 데이터 — 카테고리+이미지+제목 항목을 선으로 구분해 나열
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: _articles!.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, thickness: 0.7, color: AppColors.border),
      itemBuilder: (context, i) => _newsItem(context, _articles![i]),
    );
  }

  // 상세로 이동 (관련 뉴스 3개: 같은 카테고리 우선)
  void _openDetail(BuildContext context, NewsArticle a) {
    final sameCategory =
        _articles!.where((x) => x != a && x.category == a.category).toList();
    final others =
        _articles!.where((x) => x != a && x.category != a.category).toList();
    final related = [...sameCategory, ...others].take(3).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(article: a, related: related),
      ),
    );
  }

  // ── 뉴스 항목: 카테고리 + 제목 (왼쪽) · 이미지(오른쪽) ──
  Widget _newsItem(BuildContext context, NewsArticle a) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(context, a),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 원본 기사 사진이 있으면 왼쪽에 표시, 없으면 생략
            if (a.imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  a.imageUrl,
                  width: 78,
                  height: 78,
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
                  const SizedBox(height: 4),
                  Text(
                    a.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: AppColors.textPrimary,
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