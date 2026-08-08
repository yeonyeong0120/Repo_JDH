import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/features/home/domain/eco_math.dart';
import 'package:repo_jdh/core/view_models/screen_views.dart';
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
    // 헤더 내용(날짜·인사말·칩)은 한 번만 빌드해 child 로 넘긴다.
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                v.dateLabel,
                style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnTint,
                ),
              ),
            ),
            // 에코 포인트 칩 제거 — 프로필만 크게 + 아래/왼쪽으로 살짝
            Transform.translate(
              offset: const Offset(-6, 10), // 왼쪽 6 · 아래 10 (숫자만 바꾸면 됨)
              child: _RoundIconButton(
                icon: Symbols.person,
                filled: true,
                size: 60,
                iconSize: 34,
                radius: 18, // 둥근 네모
                onTap: () {}, // TODO: 마이페이지
              ),
            ),
          ],
        ),
        Gap.h16,
        // 인사말: 오른쪽 이미지 칸(플레이스홀더) 제거 → 배경만 남기고 전체 폭 사용
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${v.userName} 님,\n오늘도 한 바퀴 어떠세요?',
              // 두 줄 인사말이라 title1(26)보다 한 단계 낮춘다
              style: AppType.title1.copyWith(fontSize: 23),
            ),
            Gap.h8,
            Text(
              v.isFirstDay ? '첫 걸음을 기다리고 있어요' : '${v.streakDays}일 연속 기록 중',
              style: AppType.label.copyWith(
                color: AppColors.textBrandOnLight,
              ),
            ),
          ],
        ),
      ],
    );

    // 진입 애니메이션 (DESIGN_SPEC 01 + 목업 Home.dc.html)
    //  ┌ 물감(pour) : 초록 면이 위→아래로 채워짐  1.9s  Cubic(0.33,0.72,0.24,1)
    //  └ 포커스(focus): 글씨가 1.1s 뒤부터 흐릿·투명 → 선명하게 떠오름  1.7s
    // 하나의 t(0→1, 2.8s)로 두 구간을 각자의 커브로 나눠 구동한다.
    // 오버슈트(튕김) 없이 곧게 멈춘다.
    const totalMs = 1900; // 살짝 빠르게 (기존 2800)
    const pourEnd = 1250 / totalMs; // 물감이 끝나는 지점
    const focusStart = 700 / totalMs; // 글씨가 뜨기 시작하는 지점
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: totalMs),
      curve: Curves.linear, // 구간별 커브는 builder 안에서 직접 적용한다
      child: content,
      builder: (context, t, child) {
        final double pour = const Cubic(0.33, 0.72, 0.24, 1)
            .transform((t / pourEnd).clamp(0.0, 1.0));
        final double focus = const Cubic(0.25, 0.6, 0.3, 1)
            .transform(((t - focusStart) / (1 - focusStart)).clamp(0.0, 1.0));

        // 글씨: 투명→불투명 + 아래에서 살짝 떠오름 + 흐릿→선명(블러)
        Widget faded = Opacity(
          opacity: focus,
          child: Transform.translate(
            offset: Offset(0, (1 - focus) * 12),
            child: child,
          ),
        );
        if (focus < 0.999) {
          final double blur = (1 - focus) * 6;
          faded = ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: faded,
          );
        }

        // 헤더는 자리(높이)를 처음부터 그대로 차지한다. 초록 면만 위→아래로
        // scaleY 로 채워지므로 아래 콘텐츠가 밀리지 않는다 (목업 paintPour 방식).
        // 콘텐츠(faded)는 Opacity 0 일 때도 자리를 지켜 헤더 높이가 고정된다.
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
              padding: const EdgeInsets.fromLTRB(
                Gap.screenPad,
                Gap.sm,
                Gap.screenPad,
                Gap.xl2,
              ),
              child: faded,
            ),
          ],
        );
      },
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  final double? size;
  final double? iconSize;
  final double? radius; // 값이 있으면 둥근 네모, 없으면 원

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.size,
    this.iconSize,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    // 목업: 눌림(잉크) 효과 없음. 흰 판만 (원 또는 둥근 네모).
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size ?? Touch.min,
        height: size ?? Touch.min,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              radius == null ? null : BorderRadius.circular(radius!),
        ),
        child: Icon(
          icon,
          size: iconSize ?? Touch.icon,
          fill: filled ? 1 : 0,
          color: AppColors.textBrand,
        ),
      ),
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
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      decoration: today
          ? BoxDecoration(
              color: AppColors.green100, // 오늘 칸 안은 연한 초록
              borderRadius: Radii.innerR,
              border: Border.all(color: AppColors.actionPrimary, width: 2),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            log.weekdayLabel,
            style: AppType.caption.copyWith(
              fontWeight: today ? FontWeight.w800 : FontWeight.w600,
              color: today
                  ? AppColors.textBrandOnLight
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          // 채움(했음) vs 외곽선(안 함) — 색뿐 아니라 형태로도 구분
          Icon(
            Symbols.potted_plant,
            size: 28,
            fill: log.done ? 1 : 0,
            weight: log.done ? 500 : 400,
            color: log.done ? AppColors.actionPrimary : AppColors.neutral500,
          ),
        ],
      ),
    );
  }
}

// ── 내가 만든 변화 ───────────────────────────────────────

class _ImpactCard extends StatelessWidget {
  final HomeView v;
  const _ImpactCard({required this.v});

  @override
  Widget build(BuildContext context) {
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
          // 계산 근거를 숨기지 않는다 — 눌러서 환산식을 볼 수 있다.
          InkWell(
            onTap: () => _showEcoMathInfo(context),
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
        ],
      ),
    );
  }
}

/// 탄소 환산식 안내. 계수는 EcoMath 한 곳에서만 관리한다.
void _showEcoMathInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(28), // 목업 팝업 바깥 여백
      shape: RoundedRectangleBorder(borderRadius: Radii.cardR),
      child: Padding(
        // 목업: 위 24 · 좌우 22 · 아래 20
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '어떻게 계산했나요?',
              style: AppType.title2.copyWith(fontWeight: FontWeight.w800),
            ),
            Gap.h8,
            Text(
              '주운 쓰레기의 무게로 탄소 감축량을 추정합니다.',
              style: AppType.body.copyWith(color: AppColors.textSecondary),
            ),
            Gap.h16,
            _InfoRow(
              '쓰레기 1kg',
              '탄소 ${EcoMath.co2PerTrashKg}kg 감축',
            ),
            Gap.h8,
            _InfoRow(
              '소나무 1그루',
              '1년에 탄소 ${EcoMath.co2PerPineTreeYear}kg 흡수',
            ),
            Gap.h16,
            Text(
              '실제 감축량은 쓰레기 종류와 재활용 방식에 따라 달라질 수 있어요.',
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
            ),
            Gap.h16,
            // 목업: 가로 꽉 찬 초록 버튼 (텍스트 버튼 X)
            AppButton(
              label: '알겠어요',
              type: AppButtonType.primary,
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.surfaceBrand,
            borderRadius: Radii.fullR,
          ),
          child: Text(
            label,
            style: AppType.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textOnTint,
            ),
          ),
        ),
        Gap.w8,
        Expanded(
          child: Text(
            value,
            style: AppType.caption.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
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
void _showGroupSheet(BuildContext context, Group group) {
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
        _confirmJoin(context, group); // 살아있는 페이지 컨텍스트로 팝업
      },
    ),
  );
}

/// 가입 확인 팝업. "예"를 누르면 토스트로 안내한다(실제 가입 연결은 TODO).
void _confirmJoin(BuildContext context, Group group) {
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
                    onTap: () {
                      Navigator.pop(ctx);
                      // TODO: 실제 그룹 가입 처리(그룹 provider) 연결
                      AppSnackBar.show(context, '그룹에 가입했어요');
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

class _GroupCard extends StatelessWidget {
  final Group group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => _showGroupSheet(context, group),
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
