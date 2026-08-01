import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/providers/shared_group_provider.dart';
import 'package:repo_jdh/features/auth/data/user_profile_provider.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';
import 'package:repo_jdh/features/plogging/domain/activity_stats.dart';
import 'package:repo_jdh/features/mypage/domain/level_system.dart';
import 'package:repo_jdh/features/plogging/data/attendance_service.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/features/news/presentation/news_feed_screen.dart';
import 'package:repo_jdh/features/news/presentation/news_service.dart';
import 'package:repo_jdh/features/news/presentation/news_detail_screen.dart';
import 'package:repo_jdh/features/mypage/presentation/my_impact_screen.dart';
import 'package:repo_jdh/features/community/presentation/group_detail_screen.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';

/// 줍다행 - 홈 탭 화면 (본문만)
/// 하단 네비 / '시작' 버튼은 app_router.dart 의 ShellRoute(_ScaffoldWithBottomNav)가
/// 공통으로 담당하므로 여기엔 넣지 않습니다.
/// 위치: lib/features/home/presentation/home_screen.dart
///
/// ※ 아이콘 패키지 필요: flutter pub add material_symbols_icons
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  OverlayEntry? _popupEntry;
  Timer? _popupTimer;

  // 이번주 플로깅 활동 요약 (걸음·수거량·칼로리). null = 로딩 중
  int _weekSteps = 0;
  int _weekWeightG = 0;
  int _weekKcal = 0;
  int _totalXp = 0; // 전체 활동 기반 XP (활동 1회 = 20 XP)
  int _activeDays = 0; // 총 활동 일수 (하루에 여러 번 해도 1일)

  // 홈 카드에 보여줄 최신 뉴스 1개 (null = 아직 못 불러옴)
  NewsArticle? _latestNews;

  // '지금 우리 동네는' — 내가 속하지 않은 다른 그룹들
  List<Group> _neighborGroups = [];
  bool _inGroup = false; // 내가 이미 그룹에 속해 있는지 (가입 화면에 전달)

  @override
  void initState() {
    super.initState();
    _loadWeekStats(); // 이번주 활동 통계 불러오기
    _loadAttendance(); // 오늘 출석 찍고 이번주 출석 불러오기
    _loadLatestNews(); // 홈 카드용 최신 뉴스 1개
    _loadNeighborGroups(); // '지금 우리 동네는' 그룹 목록
    // 홈 진입 시점에 이미 공유 신호가 있으면 (정산 → 홈 이동 케이스)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final g = ref.read(sharedGroupProvider.notifier).consume();
      if (g != null) _showAutoShare(g);
    });
  }

  // '지금 우리 동네는' — 내 그룹을 뺀 다른 그룹들
  Future<void> _loadNeighborGroups() async {
    try {
      final others = await GroupService.otherGroups(limit: 10);
      final mine = await GroupService.myGroupId();
      if (!mounted) return;
      setState(() {
        _neighborGroups = others;
        _inGroup = mine != null;
      });
    } catch (_) {
      // 실패해도 홈은 안 깨지게 — 섹션이 비어 보일 뿐
    }
  }

  // 홈 뉴스 카드용 — 서버에서 최신 뉴스 1개만 가져옴
  Future<void> _loadLatestNews() async {
    try {
      final list = await NewsService.fetchNews(display: 1);
      if (!mounted || list.isEmpty) return;
      setState(() => _latestNews = list.first);
    } catch (_) {
      // 실패해도 홈은 안 깨지게 — 카드가 안내 문구를 보여줌
    }
  }

  // 활동 기록 → 이번주 통계 + 전체 XP 계산
  Future<void> _loadWeekStats() async {
    try {
      final acts = await ActivityService.getRecentCompleted(limit: 200);
      final thisWeek = ActivityStats.inWeek(acts, 0); // 0 = 이번주
      int steps = 0, weight = 0, kcal = 0;
      for (final a in thisWeek) {
        steps += ActivityMetrics.estimateSteps(a.distanceMeters);
        kcal += ActivityMetrics.estimateKcal(a.distanceMeters);
        weight += ActivityMetrics.weightGrams(a.trashCounts);
      }
      if (!mounted) return;
      setState(() {
        _weekSteps = steps;
        _weekWeightG = weight;
        _weekKcal = kcal;
        // XP: 전체 활동 횟수 × 20 (UserService 와 동일 규칙)
        _totalXp = acts.length * 20;
        // 총 활동 일수 (스트릭 카드용)
        _activeDays = ActivityStats.totalActiveDays(acts);
      });
    } catch (_) {
      // 실패해도 0으로 표시 (홈은 안 깨지는 게 우선)
    }
  }

  @override
  void dispose() {
    _popupTimer?.cancel();
    _popupEntry?.remove();
    super.dispose();
  }

  // AUTO-02 공유 완료 팝업 (하단 카드, 4초 후 자동 사라짐)
  void _showAutoShare(String groupName) {
    _dismissPopup(); // 기존 팝업 있으면 정리
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 16,
        right: 16,
        bottom: 20 + MediaQuery.of(ctx).padding.bottom,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.cardBG,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: groupName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                      const TextSpan(
                        text: '에 공유되었어요',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '닫기',
                        onTap: _dismissPopup,
                        type: AppButtonType.secondary,
                        expand: false,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: '그룹으로 보러가기',
                        type: AppButtonType.primary,
                        expand: false,
                        onTap: () async {
                          _dismissPopup();
                          // 피드 화면은 groupId 가 있어야 실제 데이터를 불러온다.
                          // (이름만 넘기면 더미 모드로 표시됨)
                          String? id;
                          try {
                            id = await GroupService.myGroupId();
                          } catch (_) {
                            // 조회 실패 시 이름만으로 이동
                          }
                          if (!mounted) return;
                          // TODO: 방금 올린 내 활동 카드로 자동 스크롤
                          context.push(
                            '/group/feed',
                            extra: {'id': id ?? '', 'name': groupName},
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    _popupEntry = entry;
    _popupTimer = Timer(const Duration(seconds: 4), _dismissPopup);
  }

  void _dismissPopup() {
    _popupTimer?.cancel();
    _popupTimer = null;
    _popupEntry?.remove();
    _popupEntry = null;
  }

  // 주간 출석 스트립 (이번 주 월~일 + 출석 여부)
  // _loadAttendance() 에서 실제 날짜·출석으로 채운다.
  List<_Day> _days = _thisWeekDays({});

  // 이번 주(월~일) 날짜 목록을 만든다. attended: 출석한 요일 인덱스 집합
  static List<_Day> _thisWeekDays(Set<int> attended) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final monday = base.subtract(Duration(days: base.weekday - 1));
    final todayIdx = base.weekday - 1; // 오늘 요일 (월=0)

    return List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      return _Day(
        d.day,
        active: attended.contains(i), // 출석하면 초록 화분
        today: i == todayIdx, // 오늘 강조
      );
    });
  }

  // 출석 기록: 오늘 출석 찍고 → 이번 주 출석 불러와서 화분 갱신
  Future<void> _loadAttendance() async {
    try {
      await AttendanceService.markToday(); // 홈 진입 = 오늘 출석
      final attended = await AttendanceService.weekAttendance();
      if (!mounted) return;
      setState(() => _days = _thisWeekDays(attended));
    } catch (_) {
      // 실패해도 날짜 스트립은 보이게 (출석만 회색으로)
    }
  }

  @override
  Widget build(BuildContext context) {
    // 홈이 이미 떠 있는 상태에서 공유가 발생한 경우
    ref.listen<String?>(sharedGroupProvider, (prev, next) {
      if (next != null) {
        final g = ref.read(sharedGroupProvider.notifier).consume();
        if (g != null) _showAutoShare(g);
      }
    });

    // 실제 로그인 사용자의 프로필(닉네임 포함)을 불러온다.
    // 불러오는 중이거나 프로필이 없으면 '플로거'로 임시 표시 (빈 화면 방지).
    final profileAsync = ref.watch(userProfileProvider);
    final nickname = profileAsync.valueOrNull?.nickname ?? '플로거';

    return Scaffold(
      backgroundColor: AppColors.appBG,
      // bottomNavigationBar 없음 — ShellRoute 가 처리
      body: SingleChildScrollView(
        // 마지막 컨텐츠가 바에 안 가리게: 실제 시스템바 인셋 + 바 높이(63+12+혹13+여유)
        padding: EdgeInsets.only(
          bottom: MediaQueryData.fromView(View.of(context)).padding.bottom + 92,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderWithCard(nickname),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildTwoCards(),
            ),
            const SizedBox(height: 26),
            _buildNeighborhood(context),
          ],
        ),
      ),
    );
  }

  // ───────── 곡선 헤더 + 현재활동 카드 (헤더가 카드 중간까지 내려옴) ─────────
  Widget _buildHeaderWithCard(String nickname) {
    return Stack(
      children: [
        // 배경: 아래가 곡선인 헤더 (현재활동 카드 중간까지)
        ClipPath(
          clipper: _BottomCurveClipper(),
          child: Container(
            height: 310, // 내용 살짝 올린 만큼 곡선도(330→285→290→316→310)
            width: double.infinity,
            color: AppColors.primaryPale,
          ),
        ),
        // 앞쪽: 인사 + 주간 스트립 + 현재활동 카드
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _days.map(_dayCell).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildActivityCard(nickname),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayCell(_Day d) {
    final numberColor = d.danger
        ? const Color.fromARGB(255, 243, 111, 102)
        : const Color.fromARGB(255, 49, 49, 49);
    final sproutColor = d.active
        ? AppColors.primary
        : const Color.fromARGB(255, 151, 151, 151);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: d.today
          ? BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${d.date}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: numberColor,
            ),
          ),
          const SizedBox(height: 6),
          // 새싹 화분 (potted_plant: 이것만 weight 400)
          Icon(Symbols.potted_plant, size: 26, weight: 500, color: sproutColor),
        ],
      ),
    );
  }

  // ───────────────────────── 현재 활동 카드 ─────────────────────────
  Widget _buildActivityCard(String nickname) {
    // 전체 XP → 레벨 정보(레벨/진행률/남은 XP) 계산
    final lv = LevelSystem.of(_totalXp);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // const 제거: nickname 이 사람마다 바뀌는 값이라 고정(const)할 수 없다.
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                    children: [
                      // 박아둔 '김연영' → 실제 로그인 사용자 닉네임
                      TextSpan(text: nickname),
                      const TextSpan(
                        text: ' 님의',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const TextSpan(
                        text: '\n현재 활동',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 프로필 아이콘 (크게)
              // TODO: 실제 사용자 프로필 이미지로 교체
              Container(
                width: 74,
                height: 74,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPale,
                ),
                child: const Icon(
                  Symbols.person,
                  color: AppColors.textTertiary,
                  size: 46,
                  weight: 300,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 현재 레벨 박스 (소프트 그린 + 그림자)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryPale,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '현재 레벨 ${lv.level}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    // 남은 XP 안내는 제거 — 오른쪽 '현재/필요' 수치로 이미 알 수 있음
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${lv.currentXp}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                          TextSpan(
                            text: '/${lv.neededXp}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: lv.progress, // 실제 진행률 (currentXp / neededXp)
                    minHeight: 8,
                    backgroundColor: AppColors.cardBG,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                // 라벨을 윗줄로 빼고 스탯을 아랫줄 전체 폭으로 → 글자 안 쪼그라들고 커짐
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이번주 플로깅 활동',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            // 활동 화면과 순서 통일: 걸음 → 칼로리 → 수거량
                            _stat(Symbols.steps,
                                '${ActivityStats.comma(_weekSteps)} 보'),
                            const SizedBox(width: 18),
                            _stat(Symbols.local_fire_department,
                                '${ActivityStats.comma(_weekKcal)} kcal'),
                            const SizedBox(width: 18),
                            _stat(Symbols.delete,
                                ActivityStats.weightLabel(_weekWeightG)),
                          ],
                        ),
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

  Widget _stat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, weight: 300, color: const Color(0xFF777777)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── 가운데 두 카드 ─────────────────────────
  Widget _buildTwoCards() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Builder(
              builder: (context) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyImpactScreen()),
                ),
                child: _streakCard(),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Builder(
              builder: (context) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewsFeedScreen()),
                ),
                child: _tipCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _streakCard() {
    // 총 활동 일수 기준 (연속이 아니라 누적 — 하루에 여러 번 해도 1일)
    final days = _activeDays;
    // 활동이 없을 때는 시작을 권하는 문구로
    final cheer = days == 0
        ? '첫 플로깅을 시작해볼까요?'
        : '대단해요! 꾸준함이 지구를 바꾸는 중이에요';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$days일 활동',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '플로깅 중',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(width: 8),
              // TODO: 줍댕이(물개) 캐릭터 이미지로 교체
              Text('🦭', style: TextStyle(fontSize: 40)),
            ],
          ),
          // 이 값으로 "대단해요!"를 팁 카드 "올바른..." 높이에 맞춤 (미세조정)
          const SizedBox(height: 20),
          Text(
            cheer,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(), // CTA를 바닥으로 → 고냐니 기자와 수평
          Row(
            children: const [
              Expanded(
                child: Text(
                  '변화 확인하기',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Symbols.chevron_right,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tipCard() {
    // 설계서 NEWS-01 기준 — 홈 카드는 최신 기사 1개를 보여준다 (서버에서 로드)
    final latest = _latestNews;
    // 아직 못 불러왔으면 안내 문구 (로딩 중이거나 실패)
    final title = latest?.title ?? '환경 뉴스를 불러오는 중…';
    final summary = latest?.summary ?? '잠시 후 최신 소식이 표시돼요.';
    final reporter = latest?.reporter ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 뉴스 썸네일 (종이 뉴스 아이콘)
          Align(
            alignment: Alignment.centerRight,
            child: const Text(
              '📰',
              style: TextStyle(fontSize: 32),
            ), // 44 → 32 축소
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          const Spacer(), // 바이라인을 카드 바닥으로 → 스트릭 CTA와 수평
          Row(
            children: [
              const CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.primaryPale,
                child: Icon(
                  Symbols.person,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reporter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const Icon(
                Symbols.chevron_right,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 지금 우리 동네는 (HOME-03) ─────────────────────────
  Widget _buildNeighborhood(BuildContext context) {
    // 내 그룹을 제외한 다른 그룹들 (GroupService 실연동)
    final groups = _neighborGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '지금 우리 동네는',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        // 그룹이 없을 때는 안내 문구 (아직 로딩 중이거나 실제로 없음)
        if (groups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '아직 우리 동네 그룹이 없어요',
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          )
        else
          SizedBox(
            height: 174,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _neighborCard(context, groups[i]),
            ),
          ),
      ],
    );
  }

  Widget _neighborCard(BuildContext context, Group g) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 내가 안 속한 동네 그룹 → 소개/가입 화면 (검색 결과와 동일)
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(
              groupId: g.id,
              name: g.name,
              region: g.region,
              meta: g.meta,
              alreadyInGroup: _inGroup, // 실제 소속 여부
            ),
          ),
        );
        _loadNeighborGroups(); // 가입했을 수 있으니 갱신
      },
      child: Container(
        width: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 봉투 인증샷 (그 그룹의 가장 최근 사진)
            // TODO: 실제 사진(Image.network)으로 교체
            Container(
              height: 110,
              width: double.infinity,
              color: AppColors.primaryPale,
              alignment: Alignment.center,
              child: const Icon(
                Symbols.image,
                color: AppColors.textTertiary,
                size: 30,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Row(
                children: [
                  // 그룹 대표 이미지 (작은 아이콘)
                  // TODO: 실제 그룹 대표 이미지로 교체
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryPale,
                    ),
                    child: const Icon(
                      Symbols.groups,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
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

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.cardBG,
    borderRadius: BorderRadius.circular(20),
    boxShadow: AppColors.cardShadow,
  );
}

/// 헤더 아래쪽 곡선 클리퍼 (가운데가 살짝 더 내려오는 둥근 곡선)
class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    p.lineTo(0, size.height - 36);
    p.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 36,
    );
    p.lineTo(size.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// 주간 스트립 1칸 데이터
class _Day {
  final int date;
  final bool active; // 그날 활동 여부(새싹 진하게)
  final bool today; // 오늘(회색 박스 강조)
  final bool danger; // 빨간 숫자
  const _Day(
    this.date, {
    this.active = false,
    this.today = false,
    this.danger = false,
  });
}