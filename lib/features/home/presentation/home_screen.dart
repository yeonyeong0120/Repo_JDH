import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:repo_jdh/core/router/app_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/core/view_models/screen_views.dart';
import 'package:repo_jdh/features/home/domain/greeting.dart';
// NewsArticle 타입 + 뉴스 상세 화면.
import 'package:repo_jdh/features/news/presentation/news_detail_screen.dart';
import 'package:repo_jdh/features/news/presentation/news_feed_screen.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/core/location/region_updater.dart';

// ============================================================
// 홈 (Startline 구조)
//  - 위치칩 + 날씨칩 + 라임 미세 pill
//  - 라임 "뉴스" 티커 (아래→위 롤링)
//  - READY 오버라인 + 28/800 두 줄 인사(라임 하이라이트)
//  - 우측 상단 라임 블롭(진입 드리프트)
//  - 하단 "지금 바로 시작!" 카드 → 목적지 설정
//  - 탭바는 앱 셸(바텀 내비)이 소유하므로 여기서 그리지 않는다.
// ============================================================

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(homeViewProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
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

class _HomeBody extends StatelessWidget {
  final HomeView v;
  const _HomeBody({required this.v});

  @override
  Widget build(BuildContext context) {
    // 바텀 내비는 extendBody 로 본문 위에 떠 있어, 시작 카드가 가리지 않도록
    // 원시 시스템 inset + 내비 높이만큼 아래 여백을 둔다.
    final double bottomInset =
        MediaQueryData.fromView(View.of(context)).padding.bottom + 92;

    return Stack(
      children: [
        // 우측 상단 마스코트 — 진입마다 랜덤, 오른쪽 아래→왼쪽 위 대각선 등장.
        // 도착(정지) 위치를 더 아래로 내려 뉴스 티커 이미지를 가리지 않게 한다.
        const Positioned(
          top: 168,
          right: -6,
          child: _MascotBlob(size: 186),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 위치칩 + 날씨/미세
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.screenPad, 24, Gap.screenPad, 0),
                  child: Row(
                    children: [
                      _LocationChip(district: v.userDistrict),
                      const Spacer(),
                      const _WeatherChip(),
                    ],
                  ),
                ),
                // 뉴스 티커
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.screenPad, Gap.lg, Gap.screenPad, 0),
                  child: _NewsTicker(items: v.news),
                ),
                // 인사 헤드라인
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.screenPad, Gap.xl, Gap.screenPad, 0),
                  child: _Greeting(),
                ),
                const Spacer(),
                // 나의 환경 영향력 (도넛 + 온실가스/나무) — 살짝 위로
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.screenPad, 0, Gap.screenPad, Gap.xl),
                  child: _ImpactSection(v: v),
                ),
                // 지금 바로 시작 카드
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.screenPad, 0, Gap.screenPad, Gap.xl),
                  child: _StartCard(activeCount: v.regionActiveTodayCount),
                ),
              ],
            ),
          ),
        ),
      ],
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

// ── 마스코트(플로고) ─────────────────────────────────────

/// 우측 상단 장식 마스코트. 홈 진입마다 3종 중 랜덤으로 표시되고,
/// 오른쪽 아래에서 왼쪽 위로 대각선으로 미끄러져 들어온다(블롭과 동일 속도·커브).
class _MascotBlob extends StatefulWidget {
  final double size;
  const _MascotBlob({required this.size});

  @override
  State<_MascotBlob> createState() => _MascotBlobState();
}

class _MascotBlobState extends State<_MascotBlob> {
  // 이미지 파일은 assets/images/ 에 넣어주세요(pubspec 등록 불필요 — 이미 디렉터리 등록됨).
  static const List<String> _assets = [
    'assets/images/ploggo_1.png',
    'assets/images/ploggo_2.png',
    'assets/images/ploggo_3.png',
  ];
  // 공용 난수 + 직전 인덱스 기억 — 같은 그림이 연달아 나오지 않게 해
  // 세 캐릭터가 고르게 돌아가도록(ploggo_2 가 안 나오던 문제 방지).
  static final math.Random _rng = math.Random();
  static int _lastIdx = -1;
  static String _pickAsset() {
    int i;
    if (_assets.length <= 1) {
      i = 0;
    } else {
      do {
        i = _rng.nextInt(_assets.length);
      } while (i == _lastIdx);
    }
    _lastIdx = i;
    return _assets[i];
  }

  late String _asset;
  // 재생 회차 — 값이 바뀌면 TweenAnimationBuilder 를 새로 만들어 처음부터 재생한다.
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    _asset = _pickAsset();
    // 다른 화면에서 홈으로 되돌아올 때마다(셸 위 화면 pop) 다시 재생.
    homeReentryTick.addListener(_replay);
  }

  @override
  void dispose() {
    homeReentryTick.removeListener(_replay);
    super.dispose();
  }

  // 마스코트를 다시 랜덤으로 뽑고 애니메이션을 처음부터 재생.
  void _replay() {
    if (!mounted) return;
    setState(() {
      _asset = _pickAsset();
      _runId++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ploggo_3 만 원본이 작게 그려져 있어 1·2와 시각 크기를 맞추려 키운다.
    final double scale = _asset.endsWith('ploggo_3.png') ? 1.18 : 1.0;
    final double w = widget.size * scale;
    // ploggo_1 일 때만 이동 거리와 시간을 길게(더 멀리서 더 오래 미끄러져 들어옴).
    // 홈 화면과 가까운 곳에서 시작하도록 이동 거리를 줄인다.
    // ploggo_1 만 조금 더 멀리·조금 더 오래(하지만 '늦게 시작'하지 않게 곡선은 빠른 시작).
    final bool isFirst = _asset.endsWith('ploggo_1.png');
    final double travelX = isFirst ? 110 : 78;
    final double travelY = isFirst ? 138 : 98;
    final int durMs = isFirst ? 4800 : 3800;
    return TweenAnimationBuilder<double>(
      // 회차가 바뀌면 위젯 정체성이 바뀌어 begin(0)부터 다시 재생된다.
      key: ValueKey(_runId),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: durMs),
      // 초반에 바로 움직이는 ease-out 곡선(‘늦게 시작’ 느낌 제거).
      curve: const Cubic(0.18, 0.9, 0.26, 1),
      builder: (context, t, child) => Transform.translate(
        // 오른쪽 아래 → 왼쪽 위 대각선 이동. 시작을 세로로 살짝 더 아래에서.
        offset: Offset(travelX * (1 - t), travelY * (1 - t)),
        child: child,
      ),
      child: Image.asset(
        _asset,
        width: w,
        height: w * 1.15,
        fit: BoxFit.contain,
        // 이미지가 아직 없으면 아무 것도 표시하지 않는다(빌드 안전).
        errorBuilder: (_, __, ___) => SizedBox(width: w),
      ),
    );
  }
}

// ── 위치칩 ───────────────────────────────────────────────

/// map-pin + 행정구 + 새로고침. 새로고침을 누르면 현재 GPS 로 지역을 다시 잡는다.
class _LocationChip extends ConsumerStatefulWidget {
  final String district;
  const _LocationChip({required this.district});

  @override
  ConsumerState<_LocationChip> createState() => _LocationChipState();
}

class _LocationChipState extends ConsumerState<_LocationChip> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    // 위치 칩을 누르면 조용히 현 위치로 갱신한다(안내 스낵바는 띄우지 않는다).
    final result = await RegionUpdater.refreshFromGps();
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() => _busy = false);
      AppSnackBar.show(context, _errorMessage(result.error));
      return;
    }
    setState(() => _busy = false);
    ref.invalidate(homeViewProvider);
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(TablerIcons.mapPin, size: 18, color: AppColors.ink),
          Gap.w8,
          Text(
            widget.district,
            style: AppType.label.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          Gap.w8,
          _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gray350,
                  ),
                )
              : const Icon(TablerIcons.refresh, size: 14, color: AppColors.gray350),
        ],
      ),
    );
  }
}

// ── 날씨칩 ───────────────────────────────────────────────

/// 날씨 pill(sun + 온도) + 라임 미세먼지 pill.
/// TODO: FastAPI 프록시 경유 날씨/미세먼지 API 연동 시 실제 값으로 교체(현재 표시용 고정값).
class _WeatherChip extends StatelessWidget {
  const _WeatherChip();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: Radii.fullR,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(TablerIcons.sun, size: 15, color: AppColors.ink),
              const SizedBox(width: 5),
              Text(
                '24°',
                style: AppType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        Gap.w8,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: Radii.fullR,
          ),
          child: Text(
            '미세 좋음',
            style: AppType.caption.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.limeOn,
            ),
          ),
        ),
      ],
    );
  }
}

// ── 뉴스 티커 ────────────────────────────────────────────

/// 라임 "뉴스" 태그 + 헤드라인 롤(아래→위) + 셰브론.
/// 몇 초마다 한 줄씩 위로 밀려 올라가며 다음 기사를 보여준다.
/// 탭하면 환경 뉴스 목록으로 이동한다. (뉴스 데이터는 홈 provider 가 공급)
class _NewsTicker extends StatefulWidget {
  final List<NewsArticle> items;
  const _NewsTicker({required this.items});

  @override
  State<_NewsTicker> createState() => _NewsTickerState();
}

class _NewsTickerState extends State<_NewsTicker>
    with SingleTickerProviderStateMixin {
  static const double _lineH = 21;

  int _index = 0;
  late final AnimationController _roll;
  Timer? _dwell;

  @override
  void initState() {
    super.initState();
    _roll = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _index = (_index + 1) % widget.items.length);
          _roll.value = 0;
          _scheduleNext();
        }
      });
    if (widget.items.length >= 2) _scheduleNext();
  }

  void _scheduleNext() {
    _dwell?.cancel();
    _dwell = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) _roll.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _roll.dispose();
    super.dispose();
  }

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NewsFeedScreen()),
    );
  }

  Widget _line(String text) => SizedBox(
        height: _lineH,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppType.fontFamily,
            fontSize: 13.5,
            height: _lineH / 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final items = widget.items;

    Widget rolling;
    if (items.isEmpty) {
      rolling = _line('환경 소식을 준비하고 있어요');
    } else if (items.length < 2) {
      rolling = _line(items.first.title);
    } else {
      rolling = SizedBox(
        height: _lineH,
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _roll,
            builder: (context, _) {
              final double t = Curves.easeInOut.transform(_roll.value);
              final cur = items[_index % items.length];
              final next = items[(_index + 1) % items.length];
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 현재 줄: 위로 빠져나간다.
                  Transform.translate(
                    offset: Offset(0, -_lineH * t),
                    child: _line(cur.title),
                  ),
                  // 다음 줄: 아래에서 올라온다.
                  Transform.translate(
                    offset: Offset(0, _lineH * (1 - t)),
                    child: _line(next.title),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: Radii.innerR,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '뉴스',
                style: AppType.overline.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  color: AppColors.limeOn,
                ),
              ),
            ),
            Gap.w12,
            Expanded(child: rolling),
            Gap.w8,
            const Icon(
              TablerIcons.chevronRight,
              size: 18,
              color: AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 인사 헤드라인 ─────────────────────────────────────────

/// READY 오버라인 + 28/800 두 줄 인사. 핵심 단어에 라임 하이라이트.
/// 시간대에 맞는 문구를 고른다(날씨 조건 문구는 데이터가 없어 제외).
class _Greeting extends StatefulWidget {
  const _Greeting();

  // 목업 GREETS 를 옮긴 문구 세트.
  static const List<GreetingSet> greets = [
    (top: '좋은 아침,', mid: '가볍게 ', hl: '줍죠', slot: GreetingSlot.morning),
    (top: '날씨 좋은데', mid: '한 바퀴 ', hl: '줍죠', slot: GreetingSlot.day),
    (top: '퇴근길에', mid: '슬슬 ', hl: '줍줍', slot: GreetingSlot.evening),
    (top: '딱 십 분만', mid: '동네 ', hl: '주워요', slot: GreetingSlot.lateNight),
  ];

  @override
  State<_Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<_Greeting> {
  // 홈에 들어올 때마다(다른 탭 갔다 와도 화면이 새로 생성됨) 현재 시각에 맞는
  // 문구를 고른다. late final 이라 첫 build 에서 1회만 평가된다.
  late final GreetingSet g = _pickGreeting();

  GreetingSet _pickGreeting() {
    final slot = greetingSlotOf(DateTime.now());
    return _Greeting.greets.firstWhere(
      (e) => e.slot == slot,
      orElse: () => _Greeting.greets.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 여백이 많아 한 단계 키움(28→34). READY/시간대 라벨도 비율 맞춰 키운다.
    const headStyle = TextStyle(
      fontFamily: AppType.fontFamily,
      fontSize: 34,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.4,
      color: AppColors.ink,
    );

    // 마스코트 png와 겹쳐도 글자가 잘 읽히도록, 각 텍스트 뒤를 배경색(흰색)으로
    // 덮는다. 페이지 배경과 같은 색이라 겹친 마스코트만 가려지고 상자는 안 보인다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ColoredBox(
          color: AppColors.surface,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'READY',
                style: AppType.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppColors.gray500,
                ),
              ),
              Gap.w8,
              Text(
                g.slot.label,
                style: AppType.caption.copyWith(
                  fontSize: 13,
                  color: AppColors.gray400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ColoredBox(
          color: AppColors.surface,
          child: Text(g.top, style: headStyle),
        ),
        // 두 번째 줄: 일반 텍스트 + 라임 하이라이트 조각.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ColoredBox(
              color: AppColors.surface,
              child: Text(g.mid, style: headStyle),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              color: AppColors.lime,
              child: Text(
                g.hl,
                style: headStyle.copyWith(color: AppColors.limeOn),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 지금 바로 시작 카드 ───────────────────────────────────

/// 차콜 카드 → 목적지 설정(경로 설정) 화면으로.
class _StartCard extends StatelessWidget {
  final int activeCount;
  const _StartCard({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(AppRoutes.ploggingRoute),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '지금 바로 시작합시다!',
                    style: TextStyle(
                      fontFamily: AppType.fontFamily,
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                      color: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activeCount > 0 ? '현재 $activeCount명이 뛰는 중' : '오늘도 한 바퀴 어때요',
                    style: AppType.caption.copyWith(color: AppColors.gray400),
                  ),
                ],
              ),
            ),
            Gap.w16,
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
              ),
              child: const Icon(TablerIcons.run, size: 31, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 나의 환경 영향력 (틸 미스트 카드 + 반원 게이지 + 온실가스/나무) ──
// HOME_IMPACT_CARD.md 스펙: 면 #EDF4F3, 반원 라임 게이지, 청록기 머금은 다크 텍스트.
class _ImpactSection extends StatelessWidget {
  final HomeView v;
  const _ImpactSection({required this.v});

  // 카드 전용 색(순회색/초록계 대신 청록기 다크)
  static const Color _card = Color(0xFFEDF4F3);
  static const Color _title = Color(0xFF212C2C);
  static const Color _label = Color(0xFF7F8D8C);
  static const Color _body = Color(0xFF536160);

  @override
  Widget build(BuildContext context) {
    // 패딩은 카드가 아니라 '내용(Column)'에만 준다.
    // 카드에 패딩을 주면 블롭 Stack 이 안쪽으로 밀려 카드 모서리에 여백이 생겨
    // 블롭이 코너에 닿지 않고 잘려 보였다. Stack 을 카드 전체에 깔아 블롭을 코너에 붙인다.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: [
          // 우상단 장식 블롭 — 원래대로 솔리드 원(딥 틸 6%). 카드가 코너에서 깔끔히 자른다.
          Positioned(
            right: -40,
            top: -46,
            child: Container(
              width: 150,
              height: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromRGBO(20, 69, 75, 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '나의 환경 영향력',
                style: TextStyle(
                  fontSize: 17,
                  letterSpacing: -0.4,
                  fontWeight: FontWeight.w800,
                  color: _title,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SemiGauge(
                    ratio: v.annualGoalRatio,
                    percent: v.annualGoalPercent,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '온실가스 감축',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                            color: _label,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              v.carbonKg.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 19,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: _title,
                              ),
                            ),
                            const Text(
                              ' kgCO₂eq',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _body,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(TablerIcons.tree,
                                size: 15, color: AppColors.link),
                            const SizedBox(width: 6),
                            Text(
                              '나무 ${v.pineTrees.toStringAsFixed(1)}그루 효과',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: _body,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        ],
      ),
    );
  }
}

// 반원 게이지 — 왼쪽에서 오른쪽으로 라임이 차오른다.
// 홈 진입/재진입마다(캐릭터처럼) 처음부터 다시 차오르게 homeReentryTick 을 듣는다.
class _SemiGauge extends StatefulWidget {
  final double ratio;
  final int percent;
  const _SemiGauge({required this.ratio, required this.percent});

  @override
  State<_SemiGauge> createState() => _SemiGaugeState();
}

class _SemiGaugeState extends State<_SemiGauge> {
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    homeReentryTick.addListener(_replay);
  }

  @override
  void dispose() {
    homeReentryTick.removeListener(_replay);
    super.dispose();
  }

  void _replay() {
    if (mounted) setState(() => _runId++);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(_runId),
            tween: Tween(begin: 0.0, end: widget.ratio.clamp(0.0, 1.0)),
            // 내 활동 도넛차트와 같은 속도·느낌(1250ms, 앞으로 쏠리지 않는 곡선).
            duration: const Duration(milliseconds: 1250),
            curve: Curves.easeInOutCubic,
            builder: (context, r, _) => CustomPaint(
              size: const Size(126, 78),
              painter: _SemiGaugePainter(r),
            ),
          ),
          // 라벨 — 반원 끝(양 끝점) 높이에 맞춰 아래로 내려 앉힌다.
          Positioned(
            left: 0,
            right: 0,
            bottom: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    text: '${widget.percent}',
                    style: const TextStyle(
                      fontFamily: AppType.fontFamily,
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: _ImpactSection._title,
                    ),
                    children: const [
                      TextSpan(text: '%', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  '연간 목표',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _ImpactSection._label,
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

class _SemiGaugePainter extends CustomPainter {
  final double ratio;
  const _SemiGaugePainter(this.ratio);

  @override
  void paint(Canvas canvas, Size size) {
    // 반원(위쪽) — 중심은 하단 중앙, 왼쪽(π)에서 오른쪽(2π)까지 위를 지난다.
    final center = Offset(size.width / 2, size.height - 18);
    final radius = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = const Color(0xFFDCE8E7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(rect, math.pi, math.pi, false, track);

    final r = ratio.clamp(0.0, 1.0);
    if (r > 0) {
      final fill = Paint()
        ..color = AppColors.lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;
      canvas.drawArc(rect, math.pi, math.pi * r, false, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _SemiGaugePainter old) => old.ratio != ratio;
}
