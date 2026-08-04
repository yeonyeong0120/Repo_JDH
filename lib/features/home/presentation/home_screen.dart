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
                      onMore: () {}, // TODO: 마이 임팩트
                      child: _ImpactCard(v: v),
                    ),
                    // 못 불러왔을 때도 섹션은 남기고 재시도를 제공한다.
                    AppSection(
                      title: '알아두면 좋은 소식',
                      onMore: v.hasNews ? () {} : null, // TODO: 뉴스 목록
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
                      caption:
                          '${v.region} 오늘 ${v.regionActiveTodayCount}명이 활동했어요',
                      onMore: () {}, // TODO: 그룹 탭
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceBrand,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(Radii.sheet),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Gap.screenPad,
        Gap.sm,
        Gap.screenPad,
        Gap.xl2,
      ),
      child: Column(
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
              _PointChip(points: v.points),
              Gap.w8,
              _RoundIconButton(
                icon: Symbols.person,
                filled: true,
                onTap: () {}, // TODO: 마이페이지
              ),
            ],
          ),
          Gap.h16,
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
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
              ),
              Gap.w16,
              const _Mascot(size: 104),
            ],
          ),
        ],
      ),
    );
  }
}

class _PointChip extends StatelessWidget {
  final int points;
  const _PointChip({required this.points});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: Radii.fullR,
      child: InkWell(
        onTap: () {}, // TODO: 에코포인트 상점
        borderRadius: Radii.fullR,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          alignment: Alignment.center,
          child: Text.rich(
            TextSpan(
              text: _comma(points),
              style: AppType.label
                  .copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textBrand, // 흰 배경 위 → green600 OK
                  )
                  .tabular,
              children: [
                TextSpan(
                  text: ' P',
                  style: AppType.overline.copyWith(
                    color: AppColors.textBrand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: Touch.min,
          height: Touch.min,
          child: Icon(
            icon,
            size: Touch.icon,
            fill: filled ? 1 : 0,
            color: AppColors.textBrand,
          ),
        ),
      ),
    );
  }
}

/// 줍댕이. 홈에서는 이미지로만 다룬다(키우기·꾸미기 없음).
class _Mascot extends StatelessWidget {
  final double size;
  const _Mascot({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.green100,
        borderRadius: Radii.cardR,
      ),
      clipBehavior: Clip.antiAlias,
      // 에셋이 없으면 '이미지 들어갈 자리'로 보이게 둔다.
      // (의미 있는 아이콘을 쓰면 기능처럼 오해됨)
      child: Image.asset(
        'assets/images/jupdaengi.png',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Symbols.pets,
          size: 36,
          color: AppColors.green500,
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
              color: AppColors.surface,
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
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: Radii.sheetR),
      title: Text('어떻게 계산했나요?', style: AppType.title3),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('알겠어요'),
        ),
      ],
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
    // Gemini 3줄 요약이 있으면 첫 줄, 없으면 원본 요약.
    final line = item.aiSummary.isNotEmpty ? item.aiSummary.first : item.summary;

    return AppCard(
      onTap: () {}, // TODO: 뉴스 상세로 이동
      padding: const EdgeInsets.all(Gap.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.green100,
              borderRadius: Radii.tileR,
            ),
            child: Text(item.emoji, style: const TextStyle(fontSize: 20)),
          ),
          Gap.w16,
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
                if (line.isNotEmpty) ...[
                  Gap.h4,
                  Text(
                    line,
                    style: AppType.body.copyWith(
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
        for (final g in v.groups.take(2)) ...[
          _GroupCard(group: g),
          if (g != v.groups.take(2).last) Gap.h12,
        ],
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {}, // TODO: 그룹 상세
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
