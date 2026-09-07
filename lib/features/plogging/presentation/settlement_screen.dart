import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/router/app_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_typography.dart'; // .tabular 확장
import 'package:repo_jdh/core/providers/plogging_provider.dart';
import 'package:repo_jdh/core/providers/tracking_provider.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/mypage/presentation/reward_dialogs.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:repo_jdh/features/plogging/data/photo_service.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/data/geocode_service.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';
import 'package:repo_jdh/features/plogging/domain/activity_points.dart';
import 'package:repo_jdh/features/plogging/domain/route_notifier.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';

/// Ploggo - 활동 정산 화면 (플로깅 종료 후 결과 요약 + 보상 + 기록/공유)
class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen>
    with SingleTickerProviderStateMixin {
  // 사진 업로드 진행 중 여부 (버튼 중복 탭 방지 + 진행 표시)
  bool _uploading = false;

  // 획득 경험치 (고정)
  static const int _rewardXp = 20;

  // 진입 연출: 화면 흔들림 · 컨페티 낙하 · 도장 임팩트 · 확산 링 · 보상 카드 stagger
  late final AnimationController _intro;
  late final List<_Confetti> _confetti;

  // 실제 계산된 포인트. 표시(_rewardCards)와 저장(_saveActivity)이 같은 값을 쓴다.
  late final ({int total, int base, int trashPoints, int completionBonus}) _points =
      _computePoints();

  ({int total, int base, int trashPoints, int completionBonus}) _computePoints() {
    final counts = ref.read(ploggingProvider).totalCounts;
    final totalTrash = counts.values.fold<int>(0, (s, v) => s + v);
    final t = ref.read(trackingProvider);
    final end = t.endLocation;
    final polyline = ref.read(routeNotifierProvider).valueOrNull?.polyline;
    final dest = (polyline != null && polyline.isNotEmpty) ? polyline.last : null;
    final reached = ActivityPoints.reachedDestination(
      endLat: end?['lat'],
      endLng: end?['lng'],
      destLat: dest?[0],
      destLng: dest?[1],
    );
    return ActivityPoints.calculate(totalTrash: totalTrash, reachedDestination: reached);
  }

  @override
  void initState() {
    super.initState();
    // 진입 연출 컨트롤러 (흔들림 0.9s + 도장/링/컨페티/보상 stagger 를 하나로 구동)
    // 보상 카드가 더 느긋하게 떠오르도록 전체 연출 시간을 늘림
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    // 컨페티 16조각 — 위치·크기·색·지연을 고정 시드로 생성해 매 프레임 동일하게.
    final rnd = math.Random(7);
    const palette = [
      AppColors.lime,
      AppColors.dataPlastic,
      AppColors.dataCan,
      AppColors.dataPaper,
      AppColors.dataGlass,
    ];
    _confetti = List.generate(16, (i) {
      return _Confetti(
        left: rnd.nextDouble(),
        w: 6 + rnd.nextDouble() * 6,
        h: 9 + rnd.nextDouble() * 9,
        color: palette[i % palette.length],
        delay: rnd.nextDouble() * 0.22,
        rotate: (rnd.nextDouble() * 2 - 1) * math.pi,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  // 쓰레기 종류 정의 (라벨, 목업 아이콘, 화사한 카테고리 색, ploggingProvider의 키)
  static const List<_TrashDef> _trashDefs = [
    _TrashDef('플라스틱', TablerIcons.bottle, AppColors.dataPlastic, 'plastic'),
    _TrashDef('캔', TablerIcons.cup, AppColors.dataCan, 'can'),
    _TrashDef('종이', TablerIcons.fileDescription, AppColors.dataPaper, 'paper'),
    _TrashDef('유리', TablerIcons.glassFull, AppColors.dataGlass, 'glass'),
    _TrashDef('일반', TablerIcons.trash, AppColors.dataGeneral, 'trash'),
  ];

  // 활동 기록 저장 — 반드시 뱃지 판정보다 먼저 실행해야 한다.
  // (뱃지 판정이 activities 를 읽어 통계를 내므로, 이번 활동이 빠지면 안 됨)
  /// [imageUrl] 은 인증샷 업로드 결과. 없거나 업로드에 실패했으면 null 이고,
  /// 그때는 사진 없는 활동으로 저장한다.
  Future<void> _saveActivity({String? imageUrl}) async {
    try {
      final t = ref.read(trackingProvider);
      final counts = ref.read(ploggingProvider).totalCounts;

      // 수거 개수가 0이면 저장하지 않음 (무의미한 기록 방지)
      final total = counts.values.fold<int>(0, (s, v) => s + v);
      if (total == 0 && t.distanceMeters <= 0) return;

      final endedAt = DateTime.now();
      // startedAt 이 없으면 경과 시간으로 역산
      final startedAt =
          t.startedAt ?? endedAt.subtract(Duration(seconds: t.elapsedSeconds));

      // 0인 항목은 빼고 저장 (문서 크기 절약)
      final trashCounts = <String, int>{};
      counts.forEach((k, v) {
        if (v > 0) trashCounts[k] = v;
      });

      // 좌표 → 장소명(도착지 기준). GeocodeService 가 실패를 null 로 흡수하므로
      // 서버가 죽어 있거나 느려도 아래 저장은 그대로 진행된다.
      // GPS 를 못 잡아 endLocation 이 없으면 서버를 아예 부르지 않는다.
      final end = t.endLocation;
      final lat = end?['lat'];
      final lng = end?['lng'];
      String? placeName;
      String? placeDetail;
      if (lat != null && lng != null) {
        final info = await GeocodeService.placeInfoOf(lat: lat, lng: lng);
        placeName = info.placeName;
        placeDetail = info.placeDetail;
      }

      final activityId = await ActivityService.saveCompleted(
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: t.elapsedSeconds,
        distanceMeters: t.distanceMeters,
        trashCounts: trashCounts,
        groupId: null, // 그룹 활동 구분이 생기면 여기에 전달
        path: t.pathJson, // 활동 경로 (나중에 기록 상세에서 지도 표시)
        startLocation: t.startLocation,
        endLocation: t.endLocation,
        placeName: placeName, // 역지오코딩된 장소명 (없으면 null)
        placeDetail: placeDetail, // 번지 포함 상세 (없으면 null)
        // 그룹 피드뿐 아니라 활동 기록에도 인증샷을 남긴다
        imageUrls: imageUrl == null ? const [] : [imageUrl],
        pointsEarned: _points.total,
      );

      // 포인트 적립은 활동 저장과 분리 — 실패해도 활동 저장 자체는 막지 않는다.
      if (activityId != null) {
        try {
          await UserService.addPoints(_points.total);
        } catch (e) {
          debugPrint('[정산] 포인트 적립 실패: $e');
        }
      }
    } catch (e) {
      debugPrint('[정산] 활동 저장 실패: $e');
      // 저장 실패해도 화면 흐름은 계속 (사용자를 가두지 않음)
    }
  }

  // ACT-09 이번 활동으로 새로 획득한 뱃지(=완료한 퀘스트) 목록. 없으면 빈 리스트.
  Future<List<BadgeData>> _earnedBadges() async {
    List<BadgeData> badges = const [];
    try {
      badges = await BadgeService.checkAndSave();
    } catch (_) {
      // 판정 실패해도 계속
    }
    return badges;
  }

  // 화면 전환 이후(홈/피드) 루트 컨텍스트에서 보상 팝업을 띄운다.
  void _scheduleRewardAfterNav(List<BadgeData> badges) {
    if (badges.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null) showRewardFlow(ctx, badges);
    });
  }

  // 찍기 → 봉투 인증샷 촬영 → 자동 그룹 공유 → 홈 + AUTO-02 팝업
  Future<void> _takePhoto() async {
    final file = await PhotoService.takePhoto();
    if (file == null) return; // 촬영 취소 → 정산 화면에 머무름
    await _uploadAndShare(file);
  }

  // 사진 업로드 후 공유 (업로드 중에는 진행 표시)
  Future<void> _uploadAndShare(XFile file) async {
    if (!mounted) return;
    setState(() => _uploading = true);
    String? url;
    try {
      url = await PhotoService.uploadActivityPhoto(file);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
    // 업로드 실패해도(url == null) 사진 없는 활동으로 계속 진행
    await _shareAndHome(imageUrl: url);
  }

  // 활동 마치기(인증샷 X) → 완료 퀘스트 있으면 팝업 바로 노출, 없으면 곧장 홈.
  Future<void> _skip() async {
    await _saveActivity(); // ① 활동 저장 (뱃지 판정보다 먼저)
    await ref.read(ploggingProvider.notifier).reset();
    if (!mounted) return;
    final badges = await _earnedBadges(); // ② 판정·저장
    ref.read(trackingProvider.notifier).reset();
    if (!mounted) return;
    final navigated = await showRewardFlow(context, badges); // ③ 바로 팝업
    if (!mounted || navigated) return; // 뱃지함 보기로 이동했으면 끝
    context.go('/home');
  }

  // 사진 결정(찍기) 공통: 자동 그룹 공유 → '올렸어요' 시트 → 홈 or 피드
  Future<void> _shareAndHome({String? imageUrl}) async {
    // ① 활동 저장 (reset 전에 해야 데이터가 살아있음). 인증샷도 함께 남긴다.
    await _saveActivity(imageUrl: imageUrl);

    // ② 내 그룹 피드에 활동 카드 게시 (공유 횟수도 누적 → 'share_10' 뱃지)
    //    가입한 그룹이 없으면 어디에도 공유하지 않는다.
    String? myGroupName;
    String? myGroupId;
    try {
      final myGroup = await GroupService.myGroup();
      if (myGroup != null) {
        myGroupName = myGroup.name;
        myGroupId = myGroup.id;
        final t = ref.read(trackingProvider);
        final total = ref
            .read(ploggingProvider)
            .totalCounts
            .values
            .fold<int>(0, (s, v) => s + v);
        await GroupService.addPost(
          groupId: myGroup.id,
          imageUrl: imageUrl, // 업로드한 인증샷 (없으면 null)
          distance: '${t.distanceText} km',
          trash: total,
          duration: t.durationText,
        );
      }
    } catch (_) {
      // 공유 실패해도 이동은 계속
    }
    await ref.read(ploggingProvider.notifier).reset();
    if (!mounted) return;

    // ③ 뱃지 판정·저장 (팝업은 화면 이동 뒤에 띄운다)
    final badges = await _earnedBadges();
    if (!mounted) return;

    final bool shared = myGroupId != null;
    ref.read(trackingProvider.notifier).reset();

    if (shared) {
      // ④ 그룹이 있을 때만 공유 완료 시트 (홈으로 / 피드 보기)
      final goFeed = await _showSharedSheet(myGroupName!);
      if (!mounted) return;
      if (goFeed == true) {
        // 그룹 홈을 스택 맨 아래에 두고 그 위에 피드를 push 한다.
        // → 채팅방에서 기기 뒤로가기 시 홈이 아니라 그룹 홈으로 나온다.
        context.go('/group');
        context.push(
          AppRoutes.groupFeed,
          extra: {'id': myGroupId, 'name': myGroupName},
        );
      } else {
        context.go('/home');
      }
    } else {
      // 그룹이 없으면 공유 없이 곧장 홈으로 — 대신 저장됐다는 안내 토스트
      if (imageUrl != null) {
        AppSnackBar.show(
          context,
          '인증샷을 기록에 저장했습니다',
          kind: SnackKind.success,
        );
      }
      context.go('/home');
    }
    // ⑤ 이동한 화면(홈/피드) 위에 퀘스트·뱃지 팝업을 띄운다
    _scheduleRewardAfterNav(badges);
  }

  // AUTO-02 공유 완료 시트: '{그룹}에 올렸어요' + 홈으로 / 피드 보기
  Future<bool?> _showSharedSheet(String groupName) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(22, 22, 22, 16 + media.padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  TablerIcons.users,
                  size: 26,
                  color: AppColors.textBrandOnLight,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '인증샷을 그룹에 자동 공유했어요',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '이번 활동이 그룹 피드에 올라갔어요. 멤버들의 반응을 확인하러 가요.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: '홈으로',
                      onTap: () => Navigator.pop(ctx, false),
                      type: AppButtonType.secondary,
                      expand: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: '피드 보기',
                      onTap: () => Navigator.pop(ctx, true),
                      type: AppButtonType.primary,
                      expand: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 진입 연출 구간별 진행도 (0~1 클램프) ──
  double _seg(double start, double end) =>
      ((_intro.value - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    // 실제 수거 데이터 읽기
    final state = ref.watch(ploggingProvider);
    final counts = state.totalCounts;
    final totalTrash = counts.values.fold<int>(0, (s, v) => s + v);
    final t = ref.watch(trackingProvider);
    final topPad = MediaQuery.of(context).padding.top;
    // 3버튼 내비게이션 바(48dp 안팎)에 하단 버튼이 가려지지 않게 확보한다.
    // 이 화면은 ShellRoute 밖이라 extendBody 영향이 없어 MediaQuery 값이 그대로 정확하다.
    // 제스처 내비는 인셋이 작아 기존 여백과 거의 같은 모습을 유지한다.
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // 정산은 되돌아갈 수 없음 — 기기 뒤로가기로 트래킹/지도에 복귀하지 않게 막는다
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(
          children: [
            // 본문 (진입 시 화면 흔들림 + 도장/링/보상 stagger 를 매 프레임 갱신)
            // 주의: 애니메이션이 걸린 위젯(_stamp·_rewardCards)은 반드시 builder 안에서
            // 다시 만들어야 한다. child 로 넘기면 한 번만 빌드돼 _seg 값이 0에 고정되고
            // 도장/카드가 투명한 채로 멈춰 "아무것도 안 움직이는" 버그가 된다.
            AnimatedBuilder(
              animation: _intro,
              builder: (context, _) {
                // 스탬프가 꽝 찍히는 순간 화면 전체가 흔들린다(screenShake, 스탬프와 싱크).
                return Transform.translate(
                  offset: _shakeOffset(),
                  child: Transform.rotate(
                    angle: _shakeRot(),
                    child: SingleChildScrollView(
                      // 인증샷 업로드 로딩 중엔 스크롤(바운스)을 막는다.
                      physics: _uploading
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          22,
                          20 + topPad,
                          22,
                          30 + bottomPad,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 수거 결과 요약이 첫 화면을 채우게 하여, 보상 박스는
                            // 스크롤해야 나타나되(맨 밑에 살짝 걸쳐 보임) 요약과
                            // 보상 사이 여백은 과하지 않게 딱 한 화면만큼만 둔다.
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: MediaQuery.of(context).size.height -
                                    topPad -
                                    150,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _headline(),
                                  const SizedBox(height: 20),
                                  Center(child: _stamp(totalTrash, counts)),
                                  const SizedBox(height: 24),
                                  _statCards(t),
                                  const SizedBox(height: 14),
                                  _breakdownCard(counts, totalTrash),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _rewardCards(),
                            const SizedBox(height: 18),
                            _bottomButtons(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // 컨페티 낙하 (본문 위)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) => _confettiLayer(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 스탬프 착지 순간의 화면 흔들림(screenShake). 스탬프 낙하와 같은 구간에서
  // 감쇠 진동한다 — 도장이 꽝 찍히는 임팩트를 화면 전체로 전달한다.
  Offset _shakeOffset() {
    final s = _seg(0.20, 0.42); // 도장이 쿵 찍히는 순간(0.20)부터 감쇠 진동
    if (s <= 0 || s >= 1) return Offset.zero;
    final decay = 1 - s;
    final amp = 11.0 * decay;
    return Offset(
      math.sin(s * math.pi * 6) * amp,
      math.cos(s * math.pi * 5) * amp * 0.55,
    );
  }

  // 흔들림에 미세 회전(±0.5°)을 더해 임팩트를 강화한다.
  double _shakeRot() {
    final s = _seg(0.20, 0.42);
    if (s <= 0 || s >= 1) return 0;
    return math.sin(s * math.pi * 6) * (0.5 * math.pi / 180) * (1 - s);
  }

  // ── FINISH 오버라인 + 헤드라인 ──
  Widget _headline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FINISH',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: AppColors.gray500,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '한 바퀴 완주!\n수고했어요',
          style: TextStyle(
            fontSize: 34,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.3,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  // ── 라임 도장 임팩트 (stampBig: 낙하 + 회전 + 찌그러짐, 확산 링 없음) ──
  Widget _stamp(int totalTrash, Map<String, int> counts) {
    final weight = ActivityMetrics.weightLabel(counts);
    // 슉 하고 빠르게 내려와 쿵 찍힌다: 낙하 구간을 짧게 + 가속 커브(easeIn).
    final double drop = Curves.easeInCubic.transform(_seg(0.06, 0.20));
    final double baseScale = 2.6 - 1.6 * drop; // 2.6 → 1.0 (빠른 낙하)
    final double rot = (-12 + 12 * drop) * math.pi / 180; // -12° → 0°
    // 착지(0.20) 직후 짧은 찌그러짐(스쿼시)
    final double land = _seg(0.20, 0.40);
    final double squash = math.sin(land * math.pi * 3) * 0.07 * (1 - land);
    final double sx = baseScale * (1 + squash);
    final double sy = baseScale * (1 - squash);
    final stampOpacity = _seg(0.06, 0.12);

    return SizedBox(
      width: 220,
      height: 220,
      child: Center(
        child: Opacity(
          opacity: stampOpacity,
          child: Transform.rotate(
            angle: rot,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                sx <= 0 ? 0.001 : sx,
                sy <= 0 ? 0.001 : sy,
                1,
              ),
              child: Container(
                width: 200,
                height: 200,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lime,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '오늘 수거',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: AppColors.limeOn.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$totalTrash',
                          style: const TextStyle(
                            fontSize: 56,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -2.4,
                            color: AppColors.ink,
                          ).tabular,
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 5),
                          child: Text(
                            '개',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$weight 수거',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.limeOn.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 통계 3카드 (시간 / 거리 / 걸음) ──
  Widget _statCards(TrackingState t) {
    return Row(
      children: [
        Expanded(child: _statCard('시간', t.durationText)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('거리', '${t.distanceText}km')),
        const SizedBox(width: 10),
        Expanded(child: _statCard('걸음', _comma(t.steps))),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
                color: AppColors.ink,
              ).tabular,
            ),
          ),
        ],
      ),
    );
  }

  // 천 단위 콤마
  String _comma(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  // ── 수거 내역 (종류별 5색) ──
  Widget _breakdownCard(Map<String, int> counts, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '수거한 쓰레기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '총 $total개',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _trashDefs.map((d) {
              final int c = counts[d.key] ?? 0;
              final bool active = c > 0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(d.icon, size: 20, color: d.color),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$c',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: active
                                ? AppColors.textPrimary
                                : AppColors.neutral400,
                          ),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            d.label,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 획득 보상 카드 (120ms 간격으로 순차 등장) ──
  // 08 목업 대응: 포인트는 다크 카드(굵은 +P 적립 + 이번 활동 요약),
  // 경험치는 라임 계열 카드. 완주 보너스는 있을 때만 소프트 카드로 추가.
  Widget _rewardCards() {
    // 포인트 카드 서브텍스트용 이번 활동 요약 (실측 수거량·거리)
    final counts = ref.read(ploggingProvider).totalCounts;
    final totalTrash = counts.values.fold<int>(0, (s, v) => s + v);
    final t = ref.read(trackingProvider);

    final items = <_RewardItem>[
      // 포인트 — 다크 카드
      _RewardItem(
        icon: TablerIcons.coin,
        iconColor: AppColors.lime,
        iconBg: AppColors.lime.withValues(alpha: 0.18),
        bg: AppColors.ink,
        title: '+${_points.total}P 적립',
        titleColor: Colors.white,
        body: '이번 활동 수거 $totalTrash개 · ${t.distanceText}km',
        bodyColor: AppColors.gray400,
      ),
      // 경험치 — 올리브(라임 계열) 카드
      _RewardItem(
        icon: TablerIcons.starFilled,
        iconColor: AppColors.ink,
        iconBg: Colors.white.withValues(alpha: 0.45),
        bg: AppColors.lime,
        title: '+$_rewardXp XP 획득',
        titleColor: AppColors.ink,
        body: '활동할수록 레벨이 올라가요',
        bodyColor: AppColors.ink.withValues(alpha: 0.62),
      ),
      if (_points.completionBonus > 0)
        _RewardItem(
          icon: TablerIcons.flagFilled,
          iconColor: AppColors.ink,
          iconBg: AppColors.surface,
          bg: AppColors.surfaceSoft,
          title: '완주 보너스 +${_points.completionBonus}P',
          titleColor: AppColors.textPrimary,
          body: '목적지까지 완주했어요',
          bodyColor: AppColors.textSecondary,
        ),
    ];
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 9),
          _rewardCard(items[i], i),
        ],
      ],
    );
  }

  Widget _rewardCard(_RewardItem r, int index) {
    // rewardUp: 카드당 등장 ~1.15s, 카드마다 시차. 전체 2.8s 기준으로
    // 천천히 떠오르게 한다(이전엔 너무 빨랐음). 커브는 튀어나오는 Cubic(.16,.85,.2,1).
    const _riseCurve = Cubic(0.16, 0.85, 0.2, 1.0);
    final start = 0.30 + index * 0.06;
    // 카드가 더 천천히 떠오르도록 등장 구간을 넉넉히
    final t = _riseCurve.transform(_seg(start, start + 0.50));
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(0, 22 * (1 - t)),
        child: Transform.scale(
          scale: 0.97 + 0.03 * t,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: r.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: r.iconBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(r.icon, size: 20, color: r.iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        r.title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: r.titleColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        r.body,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: r.bodyColor,
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
    );
  }

  // ── 하단 버튼 (그룹에 공유 / 기록만 하기) ──
  Widget _bottomButtons() {
    if (_uploading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '인증샷 올리는 중…',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    // 인증샷 촬영 = 촬영 후 자동 그룹 공유(_takePhoto) / 활동 종료 = 저장만(_skip)
    return Row(
      children: [
        Expanded(
          child: AppButton(
            label: '인증샷 촬영',
            icon: TablerIcons.camera,
            onTap: _takePhoto,
            type: AppButtonType.secondary,
            expand: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppButton(
            label: '활동 종료',
            onTap: _skip,
            type: AppButtonType.primary,
            expand: false,
          ),
        ),
      ],
    );
  }

  // ── 컨페티 레이어 ──
  Widget _confettiLayer() {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        for (final c in _confetti) _confettiPiece(c, size),
      ],
    );
  }

  Widget _confettiPiece(_Confetti c, Size size) {
    final t = _seg(c.delay, c.delay + 0.6);
    if (t <= 0) return const SizedBox.shrink();
    final y = -40 + (size.height + 60) * t;
    final opacity = t >= 1 ? 0.0 : (t < 0.12 ? t / 0.12 : 1.0);
    return Positioned(
      left: c.left * (size.width - c.w),
      top: y,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: c.rotate * t * 3.4,
          child: Container(
            width: c.w,
            height: c.h,
            decoration: BoxDecoration(
              color: c.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrashDef {
  final String label;
  final IconData icon; // 목업 Material Symbols 아이콘
  final Color color; // 카테고리 색
  final String key; // ploggingProvider totalCounts 키
  const _TrashDef(this.label, this.icon, this.color, this.key);
}

// 획득 보상 카드 한 장 정의 (카드마다 배경·아이콘·글씨색을 개별 지정)
class _RewardItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color bg;
  final String title;
  final Color titleColor;
  final String body;
  final Color bodyColor;
  const _RewardItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.bg,
    required this.title,
    required this.titleColor,
    required this.body,
    required this.bodyColor,
  });
}

// 컨페티 한 조각 (진입 연출)
class _Confetti {
  final double left; // 0~1 (가로 위치 비율)
  final double w;
  final double h;
  final Color color;
  final double delay; // 낙하 시작 지연(진행도 기준)
  final double rotate; // 회전 방향/세기
  const _Confetti({
    required this.left,
    required this.w,
    required this.h,
    required this.color,
    required this.delay,
    required this.rotate,
  });
}
