
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/features/home/domain/eco_math.dart';
import 'package:repo_jdh/core/view_models/screen_views.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
// NewsArticle 타입. screen_views.dart 의 import 와 같은 경로를 쓴다.
import 'package:repo_jdh/features/news/presentation/news_detail_screen.dart';
import 'package:repo_jdh/features/news/presentation/news_feed_screen.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/core/widgets/app_card.dart';
import 'package:repo_jdh/core/widgets/app_section.dart';
import 'package:repo_jdh/core/widgets/app_stat.dart';

// ============================================================
// 홈 (v2)
//  - 상단 틴트 색면이 헤더 겸 인사말
//  - 그 아래는 밝은 배경 + 흰 라운드 카드
//  - 솔리드 초록은 이 화면에 없음 (FAB은 바텀 내비 소유)
// ============================================================

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeViewProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.progress),
        ),
        error: (e, _) => _ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(homeViewProvider),
        ),
        data: (v) => _HomeBody(v: v),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  final HomeView v;
  const _HomeBody({required this.v});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TintHeader(v: v),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.screenPad,
                  Gap.lg,
                  Gap.screenPad,
                  Gap.navSafe,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WeekStrip(v: v),
                    const SizedBox(height: Gap.section),
                    AppSection(
                      title: '내가 만든 변화',
                      caption: '가입 이후 누적',
                      captionInline: true, // 목업: 제목 오른쪽에 나란히
                      // 목업엔 더보기가 없다.
                      child: _ImpactCard(v: v),
                    ),
                    // 못 불러왔을 때도 섹션은 남기고 재시도를 제공한다.
                    AppSection(
                      title: '오늘의 환경 뉴스',
                      onMore: v.hasNews
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const NewsFeedScreen(),
                                ),
                              )
                          : null,
                      child: v.hasNews
                          ? Column(
                              children: [
                                for (final n in v.news.take(2)) ...[
                                  _NewsCard(item: n),
                                  if (n != v.news.take(2).last) Gap.h12,
                                ],
                              ],
                            )
                          : _NewsUnavailable(
                              onRetry: () => ref.invalidate(homeViewProvider),
                            ),
                    ),
                    AppSection(
                      title: '지금 우리 동네는',
                      // 지역명 없이 오늘 활동 인원만. 제목 오른쪽에 나란히. 더보기 없음.
                      caption: '오늘 ${v.regionActiveTodayCount}명이 활동했어요',
                      captionInline: true,
                      last: true,
                      child: _NeighborBlock(v: v),
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

/// 로그인 안 됨 · 네트워크 실패. 조용히 빈 화면을 보여주지 않는다.
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Symbols.cloud_off,
              size: 44,
              color: AppColors.neutral400,
            ),
            Gap.h16,
            Text(
              '정보를 불러오지 못했어요',
              style: AppType.title3,
              textAlign: TextAlign.center,
            ),
            Gap.h8,
            Text(
              message,
              style: AppType.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            Gap.h16,
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}

// ── 틴트 헤더 ────────────────────────────────────────────

class _TintHeader extends StatelessWidget {
  final HomeView v;
  const _TintHeader({required this.v});

  @override
  Widget build(BuildContext context) {
    // 인사말(하단) — 날씨는 헤더 상단 오른쪽에 별도 배치.
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${v.userName} 님,\n오늘도 한 바퀴 어떠세요?',
          style: AppType.title1.copyWith(fontSize: 23),
        ),
        Gap.h12,
        _streakChip(),
      ],
    );

    // 진입: 초록 면이 위→아래로 채워지고(pour), 글씨는 뒤이어 떠오른다(focus).
    const totalMs = 2600;
    const pourEnd = 0.62;
    const focusStart = 0.36;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: totalMs),
      curve: Curves.linear,
      child: content,
      builder: (context, t, child) {
        final double pour = const Cubic(0.33, 0.72, 0.24, 1)
            .transform((t / pourEnd).clamp(0.0, 1.0));
        final double focus = Curves.easeOutCubic
            .transform(((t - focusStart) / (1 - focusStart)).clamp(0.0, 1.0));

        final Widget faded = Opacity(
          opacity: focus,
          child: Transform.translate(
            offset: Offset(0, (1 - focus) * 10),
            child: child,
          ),
        );

        return Stack(
          children: [
            Positioned.fill(
              child: Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.diagonal3Values(1, pour.clamp(0.0001, 1.0), 1),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBrand,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(Radii.sheet),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              // 텍스트를 상단바 하단쪽으로 (위 여백 크게 · 아래 작게)
              padding: const EdgeInsets.fromLTRB(
                Gap.screenPad,
                130,
                Gap.screenPad,
                28,
              ),
              child: faded,
            ),
            // 날씨·온도 — 헤더 상단 오른쪽(인사말보다 위)
            Positioned(
              top: 34,
              right: Gap.screenPad,
              child: Opacity(opacity: focus, child: _weatherBlock()),
            ),
          ],
        );
      },
    );
  }

  // 연속 기록 칩 (초록 상단바 위 — 흰 pill 로 대비)
  Widget _streakChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Symbols.local_fire_department,
            size: 16,
            fill: 1,
            color: AppColors.textBrandOnLight,
          ),
          Gap.w4,
          Text(
            v.isFirstDay ? '첫 걸음을 기다리고 있어요' : '${v.streakDays}일 연속 기록 중',
            style: AppType.label.copyWith(
              color: AppColors.textBrandOnLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // 날씨·온도 (헤더 오른쪽) — 타이포만.
  // TODO: FastAPI 프록시 경유 날씨 API 연동 시 실제 값으로 교체 (지금은 표시용 고정값).
  Widget _weatherBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Symbols.partly_cloudy_day,
              size: 30,
              fill: 1,
              color: AppColors.dataCan,
            ),
            Gap.w4,
            Text(
              '24°',
              style: AppType.title1.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '구름 조금',
          style: AppType.body.copyWith(color: AppColors.textOnTint),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.green600,
                shape: BoxShape.circle,
              ),
            ),
            Gap.w4,
            Text(
              '미세 좋음',
              style: AppType.body.copyWith(color: AppColors.textOnTint),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 이번 주 화분 ─────────────────────────────────────────

class _WeekStrip extends StatelessWidget {
  final HomeView v;
  const _WeekStrip({required this.v});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.md,
        vertical: Gap.lg,
      ),
      child: Row(
        children: [for (final d in v.week) Expanded(child: _PotDay(log: d))],
      ),
    );
  }
}

class _PotDay extends StatelessWidget {
  final DayLog log;
  const _PotDay({required this.log});

  @override
  Widget build(BuildContext context) {
    final today = log.isToday;

    return Container(
      // 오늘 칸은 배경 전체를 초록으로 (다른 칸보다 살짝 크게)
      padding: EdgeInsets.symmetric(vertical: today ? 12 : 6),
      decoration: today
          ? BoxDecoration(
              color: AppColors.actionPrimary,
              borderRadius: Radii.innerR,
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            log.weekdayLabel,
            style: AppType.caption.copyWith(
              fontWeight: today ? FontWeight.w800 : FontWeight.w600,
              color: today ? Colors.white : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          // 채움(했음/오늘) vs 외곽선(안 함) — 색·형태로 구분
          Icon(
            Symbols.potted_plant,
            size: 28,
            fill: (today || log.done) ? 1 : 0,
            weight: (today || log.done) ? 500 : 400,
            color: today
                ? Colors.white
                : (log.done ? AppColors.actionPrimary : AppColors.neutral500),
          ),
        ],
      ),
    );
  }
}

// ── 내가 만든 변화 ───────────────────────────────────────

class _ImpactCard extends StatefulWidget {
  final HomeView v;
  const _ImpactCard({required this.v});

  @override
  State<_ImpactCard> createState() => _ImpactCardState();
}

class _ImpactCardState extends State<_ImpactCard> {
  final LayerLink _calcLink = LayerLink();
  final GlobalKey _infoKey = GlobalKey();
  OverlayEntry? _calcEntry;

  @override
  void dispose() {
    _calcEntry?.remove();
    _calcEntry = null;
    super.dispose();
  }

  void _removeCalc() {
    _calcEntry?.remove();
    _calcEntry = null;
    if (mounted) setState(() {});
  }

  // '어떻게 계산했나요?' 바로 아래에 뜨는 오버레이(카드 위에 겹침, 카드 크기 불변).
  void _toggleCalc() {
    if (_calcEntry != null) {
      _removeCalc();
      return;
    }
    final w = _infoKey.currentContext?.size?.width ?? 240;
    _calcEntry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _removeCalc,
            ),
          ),
          CompositedTransformFollower(
            link: _calcLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 8),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(width: w, child: _calcBox()),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_calcEntry!);
    setState(() {});
  }

  Widget _calcBox() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: Radii.innerR,
        boxShadow: AppColors.sheetShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.green300,
          ),
          Gap.w8,
          Expanded(
            child: Text(
              '쓰레기 1kg은 탄소 ${EcoMath.co2PerTrashKg}kg을 줄여요.\n'
              '소나무 한 그루가 1년에 흡수하는 양이 ${EcoMath.co2PerPineTreeYear}kg이에요.',
              style: AppType.caption.copyWith(color: Colors.white, height: 1.5),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _removeCalc,
            child: const Padding(
              padding: EdgeInsets.only(left: 4, top: 1),
              child: Icon(Icons.close, size: 16, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    if (v.isFirstDay) return const _ImpactFirstDay();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _IllustrationSlot(
                size: 80,
                // TODO: 나무 일러스트로 교체
                asset: 'assets/images/tree.png',
                fallback: Symbols.forest,
              ),
              Gap.w16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatValue(
                      value: v.carbonKg.toStringAsFixed(1),
                      unit: 'kg',
                      size: StatSize.large,
                      brand: true,
                    ),
                    Gap.h4,
                    Text(
                      '소나무 ${v.pineTrees.toStringAsFixed(1)}그루가\n1년간 마실 탄소를 줄였어요',
                      style: AppType.body.copyWith(
                        color: AppColors.neutral700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h16,
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  value: v.totalTrashKg.toStringAsFixed(1),
                  unit: 'kg',
                  label: '쓰레기',
                ),
              ),
              Gap.w8,
              Expanded(
                child: _MiniStat(
                  value: _comma(v.totalSteps),
                  label: '걸음',
                ),
              ),
              Gap.w8,
              Expanded(
                child: _MiniStat(value: '${v.level}', label: '레벨'),
              ),
            ],
          ),
          Gap.h12,
          // 계산 근거 — 눌러서 바로 아래에 뜨는 오버레이(카드 위에 겹침, 카드 불변).
          CompositedTransformTarget(
            link: _calcLink,
            child: InkWell(
              key: _infoKey,
              onTap: _toggleCalc,
              borderRadius: Radii.innerR,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: AppColors.neutral500,
                    ),
                    Gap.w4,
                    Text(
                      '어떻게 계산했나요?',
                      style: AppType.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _MiniStat extends StatelessWidget {
  final String value;
  final String? unit;
  final String label;

  const _MiniStat({required this.value, required this.label, this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.md),
      decoration: BoxDecoration(
        color: AppColors.neutral75,
        borderRadius: Radii.innerR,
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              text: value,
              style: AppType.title3
                  .copyWith(fontWeight: FontWeight.w800)
                  .tabular,
              children: [
                if (unit != null)
                  TextSpan(
                    text: unit,
                    style: AppType.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Gap.h4,
          Text(
            label,
            style: AppType.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 활동 0건 — 0을 보여주는 대신 앞으로 생길 일을 보여준다.
class _ImpactFirstDay extends StatelessWidget {
  const _ImpactFirstDay();

  @override
  Widget build(BuildContext context) {
    // 하드코딩 금지 — 계수는 EcoMath 한 곳에서만 관리한다.
    final trashG = (EcoMath.avgTrashKgPer30min * 1000).round();
    final carbonG = (EcoMath.carbonKg(EcoMath.avgTrashKgPer30min) * 1000).round();

    return AppCard(
      child: Row(
        children: [
          _IllustrationSlot(
            size: 72,
            asset: 'assets/images/tree.png',
            fallback: Symbols.eco,
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('30분만 걸어도', style: AppType.title3),
                Gap.h4,
                Text(
                  '평균 ${trashG}g의 쓰레기를 줍고\n탄소 ${carbonG}g을 줄일 수 있어요',
                  style: AppType.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IllustrationSlot extends StatelessWidget {
  final double size;
  final String asset;
  final IconData fallback;

  const _IllustrationSlot({
    required this.size,
    required this.asset,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.green100,
        borderRadius: Radii.innerR,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          fallback,
          size: size * 0.42,
          fill: 1,
          color: AppColors.green500,
        ),
      ),
    );
  }
}

// ── 뉴스 ────────────────────────────────────────────────

/// 뉴스 서버는 썸네일을 주지 않는다(네이버 검색 API에 이미지가 없음).
/// 그래서 이미지 자리를 비우는 대신 카테고리 배지로 시각적 구분을 준다.
class _NewsCard extends StatelessWidget {
  final NewsArticle item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NewsDetailScreen(article: item),
        ),
      ),
      padding: const EdgeInsets.all(Gap.lg),
      // 원본 기사 사진이 있으면 왼쪽에 표시, 없으면 줄글만
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (item.imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: Radii.tileR,
              child: Image.network(
                item.imageUrl,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Gap.w16,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppType.title3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Gap.h8,
                Text(
                  [
                    item.category,
                    item.sourceName,
                    if (item.date.isNotEmpty) item.date,
                  ].join(' · '),
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 뉴스 서버(FastAPI)에 닿지 못했을 때. 조용히 사라지지 않게 자리를 지킨다.
class _NewsUnavailable extends StatelessWidget {
  final VoidCallback onRetry;
  const _NewsUnavailable({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: Radii.tileR,
            ),
            child: const Icon(
              Symbols.cloud_off,
              size: 22,
              color: AppColors.neutral500,
            ),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('환경 소식을 불러오지 못했어요', style: AppType.title3),
                Gap.h4,
                Text(
                  '잠시 후 다시 시도해 주세요',
                  style: AppType.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Gap.w8,
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

// ── 지금 우리 동네는 ─────────────────────────────────────

class _NeighborBlock extends StatelessWidget {
  final HomeView v;
  const _NeighborBlock({required this.v});

  @override
  Widget build(BuildContext context) {
    if (!v.hasGroups) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('아직 우리 동네 그룹이 없어요', style: AppType.title3),
            Gap.h4,
            Text(
              '그룹을 만들면 이웃과 함께 걸을 수 있어요',
              style: AppType.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in v.groups.take(3)) ...[
          _GroupCard(group: g),
          if (g != v.groups.take(3).last) Gap.h12,
        ],
      ],
    );
  }
}

// ── 그룹 소개 시트 · 가입 팝업 (목업 Home.dc.html groupOpen / joinOpen) ──

/// 그룹 카드를 누르면 아래에서 올라오는 소개 시트.
void _showGroupSheet(BuildContext context, WidgetRef ref, Group group) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
    ),
    builder: (ctx) => _GroupSheet(
      group: group,
      onClose: () => Navigator.pop(ctx),
      onJoin: () {
        Navigator.pop(ctx); // 시트 닫고 (시트 컨텍스트로 pop)
        _confirmJoin(context, ref, group); // 살아있는 페이지 컨텍스트로 팝업
      },
    ),
  );
}

/// 가입 실패 사유를 사용자 문구로 바꾼다.
/// GroupService.joinGroup 이 던지는, 그대로 보여줘도 되는 메시지만 통과시킨다.
/// 그 외(Firebase 예외 등)는 내부 메시지가 새지 않도록 일반 문구로 덮는다.
String _joinErrorMessage(Object e) {
  const prefix = 'Exception: ';
  const shown = {'이미 그룹에 가입되어 있습니다', '로그인이 필요합니다'};
  final raw = e.toString();
  if (!raw.startsWith(prefix)) return '가입하지 못했어요';
  final msg = raw.substring(prefix.length).trim();
  return shown.contains(msg) ? msg : '가입하지 못했어요';
}

/// 가입 확인 팝업. "가입하기"를 누르면 실제로 GroupService.joinGroup 을 호출한다.
void _confirmJoin(BuildContext context, WidgetRef ref, Group group) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: Radii.cardR),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFDCEDE3), // 목업 아이콘 타일
                borderRadius: BorderRadius.circular(Radii.inner),
              ),
              child: const Icon(
                Symbols.handshake,
                size: 24,
                fill: 1,
                color: AppColors.textBrand,
              ),
            ),
            Gap.h16,
            Text(
              '${group.name}에 가입할까요?',
              style: AppType.title2.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap.h8,
            Text(
              '가입하면 채팅방에 바로 들어가요. 한 번에 한 그룹만 가입할 수 있어요.',
              style: AppType.body.copyWith(color: AppColors.textSecondary),
            ),
            Gap.h24,
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '아니오',
                    type: AppButtonType.secondary,
                    onTap: () => Navigator.pop(ctx),
                  ),
                ),
                Gap.w8,
                Expanded(
                  child: AppButton(
                    label: '가입하기',
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (group.id.isEmpty) {
                        AppSnackBar.show(
                          context,
                          '가입하지 못했어요',
                          kind: SnackKind.error,
                        );
                        return;
                      }
                      try {
                        await GroupService.joinGroup(group.id);
                      } catch (e) {
                        if (!context.mounted) return;
                        AppSnackBar.show(
                          context,
                          _joinErrorMessage(e),
                          kind: SnackKind.error,
                        );
                        return;
                      }
                      if (!context.mounted) return;
                      AppSnackBar.show(
                        context,
                        '그룹에 가입했어요',
                        kind: SnackKind.success,
                      );
                      // 홈의 '지금 우리 동네는' 목록에서 가입한 그룹이 빠지도록
                      // 새로고침한다. 스낵바보다 뒤에 둬야 한다 — 이 호출로
                      // _GroupCard 가 사라지면서 context 가 unmount 되기 때문.
                      ref.invalidate(homeViewProvider);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _GroupSheet extends StatelessWidget {
  final Group group;
  final VoidCallback onClose;
  final VoidCallback onJoin;
  const _GroupSheet({
    required this.group,
    required this.onClose,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final bool activeToday = group.todayActiveCount > 0;
    final String created =
        '${group.createdAt.year}.${group.createdAt.month.toString().padLeft(2, '0')}';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.xl, Gap.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 손잡이 바
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: Gap.lg),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: Radii.innerR,
                  ),
                  child: const Icon(
                    Symbols.groups,
                    size: 27,
                    fill: 1,
                    color: AppColors.neutral400,
                  ),
                ),
                Gap.w16,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: AppType.title2.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Gap.h4,
                      Text(
                        group.region,
                        style: AppType.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (group.intro.isNotEmpty) ...[
              Gap.h16,
              Text(
                group.intro,
                style: AppType.body.copyWith(
                  height: 1.6,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
            Gap.h16,
            // 멤버 요약 박스
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.md,
              ),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: Radii.innerR,
              ),
              child: Row(
                children: [
                  _AvatarStack(count: group.memberCount),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '멤버 ${group.memberCount}명',
                          style: AppType.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Gap.h4,
                        Text(
                          activeToday
                              ? '오늘 ${group.todayActiveCount}명이 활동했어요'
                              : '오늘은 아직 활동이 없어요',
                          style: AppType.caption.copyWith(
                            color: activeToday
                                ? AppColors.textBrandOnLight
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Gap.h12,
            Row(
              children: [
                const Icon(
                  Symbols.calendar_month,
                  size: 17,
                  color: AppColors.neutral400,
                ),
                Gap.w4,
                Text(
                  '$created 개설',
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Gap.h20,
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '닫기',
                    type: AppButtonType.secondary,
                    onTap: onClose,
                  ),
                ),
                Gap.w8,
                Expanded(
                  child: AppButton(
                    label: '가입하기',
                    onTap: onJoin,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 겹쳐 놓인 멤버 아바타(최대 5 + 나머지 수).
class _AvatarStack extends StatelessWidget {
  final int count;
  const _AvatarStack({required this.count});

  @override
  Widget build(BuildContext context) {
    const double d = 34; // 지름
    const double step = 25; // 겹침 간격
    final int shown = count > 5 ? 5 : count;
    final int extra = count - shown;
    final int chips = shown + (extra > 0 ? 1 : 0);
    if (chips == 0) return const SizedBox.shrink();

    return SizedBox(
      width: d + (chips - 1) * step,
      height: d,
      child: Stack(
        children: [
          for (int i = 0; i < shown; i++)
            Positioned(
              left: i * step,
              child: Container(
                width: d,
                height: d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBrand,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 2),
                ),
                child: const Icon(
                  Symbols.person,
                  size: 19,
                  fill: 1,
                  color: AppColors.textBrandOnLight,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown * step,
              child: Container(
                width: d,
                height: d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg, width: 2),
                ),
                child: Text(
                  '+$extra',
                  style: AppType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 가입 처리 후 홈을 새로고침해야 해서 ref 가 필요하다.
class _GroupCard extends ConsumerWidget {
  final Group group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      onTap: () => _showGroupSheet(context, ref, group),
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: Radii.tileR,
            ),
            clipBehavior: Clip.antiAlias,
            child: group.imageUrl == null
                ? const Icon(
                    Symbols.group,
                    size: Touch.icon,
                    color: AppColors.neutral400,
                  )
                : Image.network(group.imageUrl!, fit: BoxFit.cover),
          ),
          Gap.w16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.name, style: AppType.title3),
                Gap.h4,
                Text.rich(
                  TextSpan(
                    text: '멤버 ${group.memberCount}명 · ',
                    children: [
                      TextSpan(
                        text: (group.todayActiveCount > 0)
                            ? '오늘 ${group.todayActiveCount}명'
                            : '오늘 활동 없음',
                        style: TextStyle(
                          fontWeight: (group.todayActiveCount > 0)
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: (group.todayActiveCount > 0)
                              ? AppColors.textBrand
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Gap.w8,
          const Icon(
            Icons.chevron_right_rounded,
            size: Touch.icon,
            color: AppColors.neutral400,
          ),
        ],
      ),
    );
  }
}

String _comma(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);
