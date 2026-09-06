import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';

/// 뉴스 기사 데이터 모델 (피드 ↔ 상세 공용)
class NewsArticle {
  final String category; // 분류 (재활용 / 정책 / 캠페인 ...)
  final String title;
  final String summary; // 한 줄 요약
  final String reporter; // (미사용 — 기자명 표시 안 함)
  final String date;
  final String emoji; // 썸네일 자리 (실제 이미지 생기면 교체)
  final String sourceName; // 출처 언론사
  final String sourceUrl; // 원문 링크(공유에만 사용)
  final List<String> aiSummary; // AI 요약(리드 + 불릿). 없으면 summary 로 대체
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

/// 뉴스 상세 화면 — 원문 없이 AI 요약만 제공한다.
///  헤더 → 카테고리 칩 + 메타 → 제목 → AI 요약(리드+불릿) → 이어서 볼 요약
///  → (하단 고정) 요약 피드백 + AI 고지
class NewsDetailScreen extends StatefulWidget {
  final NewsArticle article;
  // 하단 "이어서 볼 요약" — 피드에서 같은 분류 기사들을 넘겨주면 표시됨
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

  // 요약 피드백 — 0 도움됨 / 1 안됨 / null 미선택
  int? _feedback;

  // 공유 — 제목 + 원문 링크
  Future<void> _share() async {
    final text = article.sourceUrl.isEmpty
        ? article.title
        : '${article.title}\n${article.sourceUrl}';
    try {
      await Share.share(text);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '공유하지 못했어요');
    }
  }

  // AI 요약 소스 — aiSummary 우선, 없으면 한 줄 요약을 리드로.
  List<String> get _summaryLines {
    if (article.aiSummary.isNotEmpty) return article.aiSummary;
    if (article.summary.isNotEmpty) return [article.summary];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 카테고리 칩 + 메타(언론사 · 시간)
                    _chipAndMeta(),
                    const SizedBox(height: 14),
                    // 제목
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        letterSpacing: -1,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    // AI 요약(3c: 리드 문장 + 불릿) — 요약이 있을 때만
                    if (_summaryLines.isNotEmpty) _aiSummary(),
                    // 이어서 볼 요약
                    if (widget.related.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _moreSection(),
                    ],
                  ],
                ),
              ),
            ),
            // 하단 고정 — 요약 피드백 + AI 고지
            _footer(),
          ],
        ),
      ),
    );
  }

  // ── 상단 바 — 뒤로 + 공유 (북마크는 사용자 요청으로 제거됨) ──
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
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
                color: AppColors.ink,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(TablerIcons.share2, size: 21),
            color: AppColors.ink,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.zero,
            onPressed: _share,
          ),
        ],
      ),
    );
  }

  // 카테고리 라임 칩 + 언론사 · 시간
  Widget _chipAndMeta() {
    final meta = [
      article.sourceName.isEmpty ? '환경뉴스' : article.sourceName,
      article.date,
    ].where((s) => s.isNotEmpty).join(' · ');
    return Row(
      children: [
        Container(
          height: 24,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(8),
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
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            meta,
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
    );
  }

  // ── AI 요약 (3c) — 박스 없음. 오버라인 + 리드 문장 + 불릿 ──
  Widget _aiSummary() {
    final lines = _summaryLines;
    final lead = lines.first;
    final bullets = lines.length > 1 ? lines.sublist(1) : const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 오버라인 ✨ AI 요약 (딥 틸)
        Row(
          children: const [
            Icon(TablerIcons.sparkles, size: 15, color: AppColors.newsAiAccent),
            SizedBox(width: 7),
            Text(
              'AI 요약',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppColors.newsAiAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 리드 문장
        Text(
          lead,
          style: const TextStyle(
            fontSize: 18,
            height: 1.55,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        if (bullets.isNotEmpty) const SizedBox(height: 14),
        for (int i = 0; i < bullets.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == bullets.length - 1 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(top: 9, right: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.newsAiAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    bullets[i],
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.65,
                      fontWeight: FontWeight.w500,
                      color: AppColors.newsBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── 이어서 볼 요약 — 제목 행 + chevron ──
  Widget _moreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이어서 볼 요약',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: AppColors.gray500,
          ),
        ),
        const SizedBox(height: 6),
        for (final a in widget.related.take(3))
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                Navigator.of(context, rootNavigator: true).pushReplacement(
              MaterialPageRoute(
                builder: (_) => NewsDetailScreen(
                  article: a,
                  related: widget.related.where((x) => x != a).toList(),
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.line100, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      a.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    TablerIcons.chevronRight,
                    size: 18,
                    color: AppColors.gray300,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── 하단 고정 — 요약 피드백 + AI 고지 ──
  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '요약이 도움이 됐나요?',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _feedbackBtn(TablerIcons.thumbUp, 0),
                const SizedBox(width: 8),
                _feedbackBtn(TablerIcons.thumbDown, 1),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'AI가 요약한 내용이라 원문과 다를 수 있어요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: AppColors.gray350,
            ),
          ),
        ],
      ),
    );
  }

  // 흰 버튼 38×38 radius13 — 선택 시 딥 틸 강조
  Widget _feedbackBtn(IconData icon, int value) {
    final on = _feedback == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _feedback = value);
        AppSnackBar.show(context, '의견 고마워요');
      },
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.newsAiAccent : AppColors.surface,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          size: 19,
          color: on ? Colors.white : AppColors.gray700,
        ),
      ),
    );
  }
}
