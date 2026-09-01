import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';

/// 뉴스 기사 데이터 모델 (피드 ↔ 상세 공용)
class NewsArticle {
  final String category; // 분류 (재활용 / 정책 / 캠페인 ...)
  final String title;
  final String summary;
  final String reporter;
  final String date;
  final String emoji; // 썸네일 자리 (실제 이미지 생기면 교체)
  final String sourceName; // 출처 언론사
  final String sourceUrl; // 원문 링크
  final List<String> aiSummary; // AI 3줄 요약 (없으면 요약 박스 자체를 숨김)
  final String imageUrl; // 대표 이미지 URL (없으면 빈 문자열 → 이미지 미표시)

  const NewsArticle({
    required this.category,
    required this.title,
    required this.summary,
    required this.reporter,
    required this.date,
    required this.emoji,
    this.sourceName = '',
    this.sourceUrl = '',
    this.aiSummary = const [],
    this.imageUrl = '',
  });

  /// 관련 뉴스 후보 — 같은 카테고리 우선, 최대 3개.
  /// 진입 경로(피드/홈)가 달라도 같은 기준으로 계산하도록 공용화.
  static List<NewsArticle> relatedFrom(
    List<NewsArticle> pool,
    NewsArticle current,
  ) {
    final sameCategory = pool
        .where((x) => x != current && x.category == current.category)
        .toList();
    final others = pool
        .where((x) => x != current && x.category != current.category)
        .toList();
    return [...sameCategory, ...others].take(3).toList();
  }
}

/// 뉴스 상세 화면
/// 위치 제안: lib/features/news/presentation/news_detail_screen.dart
class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  // 하단 관련 뉴스 추천 — 피드에서 같은 분류 기사들을 넘겨주면 표시됨
  final List<NewsArticle> related;
  const NewsDetailScreen({
    super.key,
    required this.article,
    this.related = const [],
  });

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  NewsArticle get article => widget.article;

  // 원문 보기 — 외부 브라우저로 이동
  Future<void> _openSource() async {
    if (article.sourceUrl.isEmpty) {
      AppSnackBar.show(context, '원문 링크가 없어요');
      return;
    }
    final uri = Uri.tryParse(article.sourceUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '링크를 열지 못했어요');
    }
  }

  // 공유 — 제목 + 원문 링크
  Future<void> _share() async {
    final text = article.sourceUrl.isEmpty
        ? article.title
        : '${article.title}\n${article.sourceUrl}';
    try {
      // share_plus 11 이상에서 deprecated 경고가 뜨면 아래로 교체:
      //   SharePlus.instance.share(ShareParams(text: text))
      await Share.share(text);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '공유하지 못했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
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
                  Expanded(
                    child: Text(
                      article.sourceName.isEmpty ? '환경뉴스' : article.sourceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.share, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: _share,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 언론사 · 분류 (신문 기사 머리)
                    Row(
                      children: [
                        Text(
                          article.sourceName.isEmpty
                              ? '환경뉴스'
                              : article.sourceName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 11,
                          color: AppColors.border,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          article.category,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 제목 — 기사 제목처럼 크고 촘촘하게
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 기자 · 날짜 — 얇은 선 사이에 끼운 바이라인
                    Container(height: 1, color: AppColors.neutral100),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Text(
                            article.reporter,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            article.date,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.neutral500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.neutral100),
                    // 대표 이미지 — 있으면 원본 비율로 보여주고, 없으면 자리 없이 글만.
                    if (article.imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          article.imageUrl,
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // AI 요약 토글 — Gemini 요약이 없으면 원본 발췌를 대신
                    // 보여주지 않고 통째로 숨긴다 (요약인 척하지 않기 위함).
                    if (article.aiSummary.isNotEmpty) ...[
                      _summaryCard(),
                      const SizedBox(height: 20),
                    ],
                    // 출처 · 원문 보기
                    _sourceBox(),
                    if (widget.related.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      _relatedSection(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI 3줄 요약 (접기/펼치기) ──
  // TODO: 요약문은 뉴스 수집 시 서버에서 생성해 Firestore 에 저장해두고 내려받는 방식 권장
  Widget _summaryCard() {
    final lines = article.aiSummary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        // 하양 배경 + 은은한 그림자(테두리 없음)
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                TablerIcons.sparkles,
                size: 18,
                color: AppColors.actionPrimary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI 요약',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < lines.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == lines.length - 1 ? 0 : 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 번호 원형 뱃지 (1 · 2 · 3)
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1, right: 10),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.green200,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green750,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      lines[i],
                      // 본문과 동일한 크기·굵기
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── 출처 · 원문 보기 ──
  Widget _sourceBox() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openSource,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.sourceName.isEmpty ? '출처' : article.sourceName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '원문 보기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              TablerIcons.externalLink,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  // ── 관련 뉴스 추천 ──
  Widget _relatedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '관련 뉴스',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        for (final a in widget.related.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => NewsDetailScreen(
                    article: a,
                    related: widget.related.where((x) => x != a).toList(),
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (a.imageUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          a.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${a.category} · ${a.date}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

}
