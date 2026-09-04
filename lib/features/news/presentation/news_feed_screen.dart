import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'news_detail_screen.dart';
import 'news_service.dart';

/// 환경 뉴스 피드 (Startline 목업 구조)
/// 상단 대표 기사(큰 이미지 + 제목 + 요약) + 아래 목록(제목/메타 + 썸네일).
/// 위치 제안: lib/features/news/presentation/news_feed_screen.dart
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
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 22, 12),
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
          const Expanded(
            child: Text(
              '환경 뉴스',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // 좌측 뒤로 버튼(44)과 균형을 맞춰 제목을 정중앙에 배치
          const SizedBox(width: 44),
        ],
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
    // ④ 데이터 — 대표 기사 + 나머지 목록
    final articles = _articles!;
    final rest = articles.length > 1 ? articles.sublist(1) : <NewsArticle>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      children: [
        _featured(articles.first),
        const SizedBox(height: 8),
        for (final a in rest) _newsRow(a),
      ],
    );
  }

  // 상세로 이동 (관련 뉴스 3개: 같은 카테고리 우선)
  void _openDetail(NewsArticle a) {
    final related = NewsArticle.relatedFrom(_articles!, a);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsDetailScreen(article: a, related: related),
      ),
    );
  }

  // 소스 · 날짜 메타 (소스명이 없으면 카테고리로 대체)
  String _meta(NewsArticle a) {
    final head = a.sourceName.isEmpty ? a.category : a.sourceName;
    if (a.date.isEmpty) return head;
    return head.isEmpty ? a.date : '$head · ${a.date}';
  }

  // ── 대표 기사: 큰 이미지 + 큰 제목 + 요약 + 메타 ──
  Widget _featured(NewsArticle a) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(a),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 없으면 자리 자체를 두지 않고 텍스트만 (빈 회색 박스 금지)
            if (a.imageUrl.isNotEmpty) ...[
              _image(a, 214, 22),
              const SizedBox(height: 18),
            ],
            Text(
              a.title,
              style: const TextStyle(
                fontSize: 25,
                height: 1.35,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.9,
                color: AppColors.textPrimary,
              ),
            ),
            if (a.summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                a.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.65,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _meta(a),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 목록 항목: 썸네일(왼쪽) + 제목/메타(오른쪽) ──
  Widget _newsRow(NewsArticle a) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(a),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line100, width: 1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 있으면 왼쪽 썸네일 유지, 없으면 썸네일과 간격을 통째로 제거해 텍스트가 폭을 채운다
            if (a.imageUrl.isNotEmpty) ...[
              _thumb(a, 66),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _meta(a),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray500,
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

  // 대표 이미지 — 있으면 표시, 없으면 소프트 그레이 플레이스홀더
  Widget _image(NewsArticle a, double height, double radius) {
    if (a.imageUrl.isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: const Text(
          '대표 기사 이미지',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.gray350,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        a.imageUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: height,
          color: AppColors.surfaceSoft,
        ),
      ),
    );
  }

  // 목록 썸네일 (66×66)
  Widget _thumb(NewsArticle a, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: a.imageUrl.isEmpty
          ? Container(
              width: size,
              height: size,
              color: AppColors.surfaceSoft,
            )
          : Image.network(
              a.imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: size,
                height: size,
                color: AppColors.surfaceSoft,
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
