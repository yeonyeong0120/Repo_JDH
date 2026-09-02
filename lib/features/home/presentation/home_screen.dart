
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/features/home/domain/eco_math.dart';
import 'package:repo_jdh/core/view_models/screen_views.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';
// NewsArticle 타입. screen_views.dart 의 import 와 같은 경로를 쓴다.
import 'package:repo_jdh/features/news/presentation/news_detail_screen.dart';
import 'package:repo_jdh/features/news/presentation/news_feed_screen.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/core/widgets/app_card.dart';
import 'package:repo_jdh/core/widgets/app_section.dart';
import 'package:repo_jdh/core/widgets/app_stat.dart';
import 'package:repo_jdh/core/location/region_updater.dart';

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
                // 바텀 내비는 extendBody 로 본문 위에 떠 있어 이 여백으로만 피한다.
                // ⚠️ MediaQuery.of(context).padding.bottom 을 쓰면 안 된다 —
                // Scaffold(extendBody: true) 가 body 의 padding.bottom 을
                // 내비 높이로 덮어써서 여백이 이중으로 잡힌다.
                // 원시 시스템 inset 을 직접 읽는다 (뱃지 탭과 동일한 식).
                padding: EdgeInsets.fromLTRB(
                  Gap.screenPad,
                  Gap.lg,
                  Gap.screenPad,
                  MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
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
                      moreColor: AppColors.textPrimary, // 더보기 검정
                      onMore: v.hasNews
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const NewsFeedScreen(),
                                ),
                              )
                          : null,
                      child: v.hasNews
                          ? _NewsPreview(items: v.news)
                          : _NewsUnavailable(
                              onRetry: () => ref.invalidate(homeViewProvider),
                            ),
                    ),
                    AppSection(
                      title: '인증샷 모음집',
                      last: true,
                      child: _TodayShots(photos: v.photos),
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
              TablerIcons.cloudOff,
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
    // 인사말과 날씨를 같은 줄(Row)에 나란히 둔다.
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${v.userName} 님,\n오늘도 한 바퀴 어떠세요?',
                // 사진 위라 흰 글씨 + 얇은 그림자로 대비를 잡는다.
                style: AppType.title1.copyWith(
                  fontSize: 23,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Color(0x73000000),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            Gap.w12,
            _weatherBlock(),
          ],
        ),
        Gap.h12,
        _streakChip(),
      ],
    );

    // 진입: 사진 헤더가 커튼처럼 위→아래로 잘려 내려오고(pour), 글씨는 뒤이어 떠오른다(focus).
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
              // 커튼: 사진을 찌그러뜨리지 않고 위에서부터 잘라 내려온다.
              child: ClipRect(
                clipper: _HeaderCurtain(pour),
                child: const ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(Radii.sheet),
                  ),
                  // 사진 위에 초록 스크림. 스크림 없이 쓰면 인사말(진한 회색)이
                  // 아스팔트 사진과 대비가 안 나 읽히지 않는다.
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: AssetImage('assets/images/home_header.png'),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                      // 사진 위 흰 글씨(로고·인사말·날씨) 대비 4.5:1 확보용 그늘.
                      // 사진에 흰 비닐봉투(휘도 255) 구간이 있어 52% 이하로는
                      // 글씨가 사라진다 — 아래로 갈수록 조금 더 진해진다.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x85000000), // 52%
                              Color(0x80000000), // 50%
                              Color(0xA8000000), // 66%
                            ],
                            stops: [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              // 텍스트를 상단바 하단쪽으로 (위 여백 크게 · 아래 작게)
              padding: const EdgeInsets.fromLTRB(
                Gap.screenPad,
                66, // 텍스트를 위로 (상단바가 그만큼 짧아짐)
                Gap.screenPad,
                20,
              ),
              child: faded,
            ),
            // 워드마크 로고 — 헤더 맨 위 왼쪽
            Positioned(
              top: 16,
              left: Gap.screenPad,
              child: Opacity(
                opacity: focus,
                // 사진 위에서는 컬러 로고가 묻혀, 흰 단색 로고(logo_white)를 그림자와 함께 얹는다.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neutral900.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo_white.png',
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            // 위치 새로고침 — 헤더 맨 위 오른쪽
            Positioned(
              top: 10,
              right: Gap.screenPad,
              child: Opacity(
                opacity: focus,
                child: const _LocationRefreshButton(),
              ),
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
        // 사진 상단바 위에서는 흰 알약이 가장 잘 읽힌다.
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            TablerIcons.flame,
            size: 16,
            color: AppColors.subPoint,
          ),
          Gap.w4,
          Text(
            v.isFirstDay ? '첫 걸음을 기다리고 있어요' : '${v.streakDays}일 연속 기록 중',
            style: AppType.label.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // 날씨·온도 (헤더 오른쪽) — 타이포만.
  // TODO: FastAPI 프록시 경유 날씨 API 연동 시 실제 값으로 교체 (지금은 표시용 고정값).
    // 날씨 상태값. API 연동 시 이 상수만 갈아끼우면 아이콘·색·문구가 함께 바뀐다.
  static const String _wx = 'cloudy'; // sunny / cloudy / overcast / rain

  IconData get _wxIcon => switch (_wx) {
    'sunny' => TablerIcons.sun,
    'overcast' => TablerIcons.cloudFilled,
    'rain' => TablerIcons.cloudRain,
    _ => TablerIcons.cloud,
  };

  Color get _wxColor => switch (_wx) {
    'sunny' => AppColors.wxSunny,
    'overcast' => AppColors.wxOvercast,
    'rain' => AppColors.wxRain,
    _ => AppColors.wxCloudy,
  };

  String get _wxLabel => switch (_wx) {
    'sunny' => '맑음',
    'overcast' => '흐림',
    'rain' => '비',
    _ => '구름 조금',
  };

  Widget _weatherBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              TablerIcons.cloud,
              size: 30,
              color: Colors.white,
            ),
            Gap.w4,
            Text(
              '24°',
              style: AppType.title1.copyWith(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.0,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Color(0x73000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _wxLabel,
          style: AppType.body.copyWith(color: Colors.white),
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
              style: AppType.body.copyWith(color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}

/// 상단바 커튼 등장용 클리퍼 — 위에서부터 t 비율만큼만 보여준다(사진 왜곡 없음).
class _HeaderCurtain extends CustomClipper<Rect> {
  final double t; // 0~1
  const _HeaderCurtain(this.t);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * t.clamp(0.0001, 1.0));

  @override
  bool shouldReclip(_HeaderCurtain old) => old.t != t;
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
      // 오늘 칸은 채우지 않고 초록 테두리로만 구분한다 (꽉 찬 초록은 너무 강함)
      padding: EdgeInsets.symmetric(vertical: today ? 12 : 6),
      decoration: today
          ? BoxDecoration(
              border: Border.all(color: AppColors.actionPrimary, width: 1.5),
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
              // 오늘도 글씨는 검정(테두리·화분만 초록)
              color: today ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          // 채움(했음/오늘) vs 외곽선(안 함) — 색·형태로 구분
          Icon(
            TablerIcons.plant,
            size: 28,
            color: (today || log.done)
                ? AppColors.actionPrimary
                : AppColors.neutral500,
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
            TablerIcons.infoCircle,
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
              child: Icon(TablerIcons.x, size: 16, color: Colors.white54),
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
                fallback: TablerIcons.trees,
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
                      TablerIcons.infoCircle,
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
            fallback: TablerIcons.leaf,
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
          color: AppColors.green500,
        ),
      ),
    );
  }
}

// ── 뉴스 ────────────────────────────────────────────────

/// 홈 환경뉴스 미리보기 — 한 칸씩 자동으로 롤링되는 뉴스.
/// 대표기사(이미지 + 굵고 큰 제목)를 강조하고, 아래에 다음 기사 제목을 얹는다.
/// 몇 초마다 한 칸씩 위로 밀려 올라가며 다음 기사를 보여준다.
class _NewsPreview extends StatefulWidget {
  final List<NewsArticle> items;
  const _NewsPreview({required this.items});

  @override
  State<_NewsPreview> createState() => _NewsPreviewState();
}

class _NewsPreviewState extends State<_NewsPreview>
    with SingleTickerProviderStateMixin {
  // 각 줄은 넉넉한 밴드로 잡고 내용은 상하 가운데 정렬한다.
  // → 텍스트가 밴드 중앙에 오고, 남는 높이가 위아래로 나뉘어 기사 사이 여백이 된다.
  static const double _leadH = 104; // 대표 줄(사진+제목) 밴드 높이
  static const double _hlH = 74; // 헤드라인 줄 밴드 높이

  int _page = 0;
  late final AnimationController _shift;
  Timer? _dwell;

  @override
  void initState() {
    super.initState();
    _shift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _page = (_page + 1) % widget.items.length);
          _shift.value = 0;
          _scheduleNext();
        }
      });
    if (widget.items.length >= 4) _scheduleNext();
  }

  void _scheduleNext() {
    _dwell?.cancel();
    _dwell = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) _shift.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _shift.dispose();
    super.dispose();
  }

  NewsArticle _art(int k) => widget.items[(_page + k) % widget.items.length];

  void _open(NewsArticle a) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NewsDetailScreen(
            article: a,
            related: NewsArticle.relatedFrom(widget.items, a),
          ),
        ),
      );

  Widget _divider() => Container(height: 0.7, color: AppColors.border);

  // 고정 높이 슬롯 (내용이 넘쳐도 오버플로우 에러 없이 잘라냄)
  Widget _staticSlot(double height, Widget child) => SizedBox(
        height: height,
        child: ClipRect(
          child: OverflowBox(
            minHeight: 0,
            maxHeight: double.infinity,
            alignment: Alignment.center, // 슬롯 안에서 상하 가운데
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    if (n < 4) {
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _staticSlot(_leadH, _row(_art(0), 1)),
            for (int k = 1; k < n; k++) ...[
              _divider(),
              _staticSlot(_hlH, _row(_art(k), 0)),
            ],
          ],
        ),
      );
    }

    final double h = _leadH + 2 * _hlH; // 대표 + 헤드라인 2줄
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      child: SizedBox(
        height: h,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _shift,
            builder: (context, _) {
              final double t = Curves.easeInOut.transform(_shift.value);
              double lerp(double a, double b) => a + (b - a) * t;

              final a0 = _art(0);
              final a1 = _art(1);
              final a2 = _art(2);
              final a3 = _art(3);

              // 고정 높이 슬롯. 내용은 상하 가운데 정렬, 넘치면 잘라낸다.
              Widget slot(double top, double height, Widget child) => Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    height: height,
                    child: ClipRect(
                      child: OverflowBox(
                        minHeight: 0,
                        maxHeight: double.infinity,
                        alignment: Alignment.center,
                        child: child,
                      ),
                    ),
                  );

              return Stack(
                children: [
                  // 슬롯 사이 구분선 (기본 위치)
                  Positioned(top: _leadH, left: 0, right: 0, child: _divider()),
                  Positioned(
                      top: _leadH + _hlH, left: 0, right: 0, child: _divider()),
                  // 대표 → 위로 사라짐
                  slot(lerp(0, -_leadH), _leadH, _row(a0, 1)),
                  // 헤드라인1 → 대표로 승격 (높이·글씨가 함께 커짐)
                  slot(lerp(_leadH, 0), lerp(_hlH, _leadH), _row(a1, t)),
                  // 헤드라인2 → 헤드라인1
                  slot(lerp(_leadH + _hlH, _leadH), _hlH, _row(a2, 0)),
                  // 대기 → 헤드라인2 진입
                  slot(lerp(_leadH + 2 * _hlH, _leadH + _hlH), _hlH,
                      Opacity(opacity: t, child: _row(a3, 0))),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // 한 줄. prominence(0~1): 0=헤드라인, 1=대표(사진+굵은 큰 제목).
  // 글자는 대표 크기로 그리고 Transform.scale 로 부드럽게 줄여 카테고리·제목이 함께 커진다.
  static const double _imgCol = 76; // 대표 사진 크기
  static const double _indent = 12; // 사진 없는 기사(헤드라인)의 살짝 들여쓰기

  Widget _row(NewsArticle a, double prom) {
    prom = prom.clamp(0.0, 1.0);
    final double scale = 0.9 + 0.1 * prom; // 0.9(헤드라인) → 1.0(대표)
    final bool showImg = a.imageUrl.isNotEmpty && prom > 0.02;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(a),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 사진이 있으면 사진(크기는 prominence에 비례), 없으면 작은 들여쓰기만
          if (showImg) ...[
            Opacity(
              opacity: prom,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  a.imageUrl,
                  width: _imgCol * prom,
                  height: _imgCol * prom,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            SizedBox(width: 2 + 12 * prom),
          ] else
            const SizedBox(width: _indent),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.category,
                      style: const TextStyle(
                        fontSize: 13.5,
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
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimary,
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
              TablerIcons.cloudOff,
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

// ── 인증샷 모음집 (사진 있는 내 최근 활동 가로 갤러리) ─────────────
class _TodayShots extends StatelessWidget {
  final List<Activity> photos;
  const _TodayShots({required this.photos});

  @override
  Widget build(BuildContext context) {
    // 인증샷이 없으면 안내 카드
    if (photos.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.green50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                TablerIcons.photo,
                size: 22,
                color: AppColors.textBrandOnLight,
              ),
            ),
            Gap.w16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('아직 인증샷이 없어요', style: AppType.title3),
                  Gap.h4,
                  Text(
                    '첫 인증샷을 남겨보세요',
                    style: AppType.body.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 가로로 넘기는 인증샷 (최대 5개)
    return SizedBox(
      height: 174,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: photos.length,
        separatorBuilder: (_, __) => Gap.w12,
        itemBuilder: (context, i) => _shot(photos[i]),
      ),
    );
  }

  Widget _shot(Activity a) {
    // 장소가 있으면 장소, 없으면(역지오코딩 이전 활동) 날짜로 대체
    final place = a.placeName;
    final date = a.endedAt ?? a.startedAt;
    final caption = (place != null && place.isNotEmpty)
        ? place
        : '${date.month}월 ${date.day}일';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 130,
        height: 174,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              a.imageUrls.first,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.neutral200,
                alignment: Alignment.center,
                child: const Icon(
                  TablerIcons.photo,
                  color: AppColors.neutral400,
                ),
              ),
            ),
            // 하단 어둠 그라데이션 (글씨 대비)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                  stops: [0.45, 1],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        TablerIcons.trash,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${a.totalTrash}개',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
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

String _comma(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);


/// 위치 새로고침 — 현재 GPS 로 지역을 다시 잡고 홈을 갱신한다.
/// 헤더 오른쪽 맨 위. 실패해도 화면은 그대로 두고 안내만 띄운다.
class _LocationRefreshButton extends ConsumerStatefulWidget {
  const _LocationRefreshButton();

  @override
  ConsumerState<_LocationRefreshButton> createState() =>
      _LocationRefreshButtonState();
}

class _LocationRefreshButtonState
    extends ConsumerState<_LocationRefreshButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await RegionUpdater.refreshFromGps();
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() => _busy = false);
      AppSnackBar.show(context, _errorMessage(result.error));
      return;
    }
    setState(() => _busy = false);
    ref.invalidate(homeViewProvider);
    AppSnackBar.show(context, '현재 위치로 새로 잡았어요');
  }

  String _errorMessage(RegionRefreshError? error) {
    switch (error) {
      case RegionRefreshError.locationUnavailable:
        return '위치를 가져오지 못했어요. 위치 권한을 확인해 주세요';
      case RegionRefreshError.geocodeUnavailable:
        return '지역 이름을 가져오지 못했어요. 잠시 후 다시 시도해 주세요';
      case RegionRefreshError.saveFailed:
        return '위치를 저장하지 못했어요';
      case null:
        return '위치를 갱신하지 못했어요';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _run,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(14),
        ),
        child: _busy
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.actionPrimary,
                ),
              )
            : const Icon(
                TablerIcons.currentLocation,
                size: 21,
                color: AppColors.textBrandOnLight,
              ),
      ),
    );
  }
}
