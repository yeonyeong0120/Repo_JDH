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

  // 저장(북마크) — 이 화면 내 로컬 표시 상태 (별도 저장소 연동은 추후)
  bool _saved = false;

  void _toggleSave() {
    setState(() => _saved = !_saved);
    AppSnackBar.show(context, _saved ? '저장했어요' : '저장을 해제했어요');
  }

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
            // 상단 바 — 뒤로 + 공유
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    // 규칙 A: 뒤로가기 chevron 24 / 44x44 탭 영역 / 컨테이너 없음
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        TablerIcons.chevronLeft,
                        size: 24,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 저장(북마크) — 규칙 A: 글리프만 44x44, 배경 컨테이너 없음
                  IconButton(
                    icon: Icon(
                      _saved ? TablerIcons.bookmarkFilled : TablerIcons.bookmark,
                      size: 21,
                    ),
                    color: AppColors.ink,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: _toggleSave,
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.share2, size: 21),
                    color: AppColors.ink,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: _share,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 분류 — 라임 pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        article.category.isEmpty ? '환경' : article.category,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.limeOn,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 제목 — 기사 제목처럼 크고 촘촘하게
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        letterSpacing: -1,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 언론사 · 기자 · 날짜 바이라인
                    _byline(),
                    // 대표 이미지 — 있을 때만 렌더, 없으면 히어로 블록(회색 자리)을 통째로 생략
                    if (article.imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _heroImage(),
                    ],
                    const SizedBox(height: 18),
                    // 본문(요약문)
                    if (article.summary.isNotEmpty)
                      Text(
                        article.summary,
                        style: const TextStyle(
                          fontSize: 15.5,
                          height: 1.75,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF3D423F),
                        ),
                      ),
                    // AI 요약 토글 — Gemini 요약이 없으면 통째로 숨긴다.
                    if (article.aiSummary.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _summaryCard(),
                    ],
                    const SizedBox(height: 24),
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

  // 언론사 · 기자 · 날짜 (가운데 구분점)
  Widget _byline() {
    final head = article.sourceName.isEmpty ? '환경뉴스' : article.sourceName;
    final tail = [
      article.reporter,
      article.date,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Row(
      children: [
        Text(
          head,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (tail.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(width: 1, height: 10, color: AppColors.gray200),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.gray500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 대표 이미지 — 없으면 '기사 이미지' 소프트 그레이 자리
  Widget _heroImage() {
    if (article.imageUrl.isEmpty) {
      return Container(
        height: 196,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text(
          '기사 이미지',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.gray350,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Image.network(
        article.imageUrl,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
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
                    decoration: BoxDecoration(
                      color: AppColors.tint(AppColors.lime, 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.limeOn,
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

  // ── 원문 보기 바 (목업 하단 바 스타일) ──
  Widget _sourceBox() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openSource,
      child: Container(
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              TablerIcons.externalLink,
              size: 19,
              color: AppColors.ink,
            ),
            SizedBox(width: 8),
            Text(
              '원문 보기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
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
