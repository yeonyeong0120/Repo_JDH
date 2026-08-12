import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:repo_jdh/core/router/app_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/trash_bag_icon.dart';
import 'package:repo_jdh/core/providers/plogging_provider.dart';
import 'package:repo_jdh/core/providers/tracking_provider.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/mypage/presentation/reward_dialogs.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:repo_jdh/features/plogging/data/photo_service.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/data/location_repository.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';

/// Ploggo - 활동 정산 화면 (플로깅 종료 후 결과 요약 + 보상 + 기록/공유)
class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  // 사진 업로드 진행 중 여부 (버튼 중복 탭 방지 + 진행 표시)
  bool _uploading = false;

  // 경로선 색 (트래킹 화면과 동일)
  static const Color _routeColor = AppColors.routeLine;

  // 보상 카운트업: 획득 보상 카드가 스크롤로 처음 보일 때 1회만 숫자가 올라간다.
  static const int _rewardPoints = 330;
  static const int _rewardXp = 20;
  final ScrollController _scroll = ScrollController();
  bool _rewardShown = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // 보상 카드(맨 아래)가 보이면 카운트업 시작.
  // 스크롤이 바닥 근처거나, 스크롤이 필요 없을 만큼 짧은 화면이면 보인 것으로 본다.
  void _maybeStartReward() {
    if (_rewardShown) return;
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent <= 0 || pos.pixels >= pos.maxScrollExtent - 160) {
      setState(() => _rewardShown = true);
    }
  }

  // 쓰레기 종류 정의 (라벨, 목업 아이콘, 화사한 카테고리 색, ploggingProvider의 키)
  static const List<_TrashDef> _trashDefs = [
    _TrashDef('플라스틱', Symbols.water_bottle, Color(0xFF5F9EE8), 'plastic'),
    _TrashDef('캔', Symbols.local_drink, Color(0xFFE07B2E), 'can'),
    _TrashDef('종이', Symbols.description, Color(0xFF31C88B), 'paper'),
    _TrashDef('유리', Symbols.wine_bar, Color(0xFF8E7EC4), 'glass'),
    _TrashDef('일반', Symbols.delete, Color(0xFF9AA3A0), 'trash'),
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

      await ActivityService.saveCompleted(
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: t.elapsedSeconds,
        distanceMeters: t.distanceMeters,
        trashCounts: trashCounts,
        groupId: null, // 그룹 활동 구분이 생기면 여기에 전달
        path: t.pathJson, // 활동 경로 (나중에 기록 상세에서 지도 표시)
        startLocation: t.startLocation,
        endLocation: t.endLocation,
        // 그룹 피드뿐 아니라 활동 기록에도 인증샷을 남긴다
        imageUrls: imageUrl == null ? const [] : [imageUrl],
      );
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
    String myGroupName = '우리 동네 그룹';
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
    // ④ 공유 완료 시트 (홈으로 / 피드 보기) → 선택 후 이동
    final goFeed = await _showSharedSheet(myGroupName);
    ref.read(trackingProvider.notifier).reset();
    if (!mounted) return;
    if (goFeed == true) {
      context.go(
        AppRoutes.groupFeed,
        extra: {'id': myGroupId ?? '', 'name': myGroupName},
      );
    } else {
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
                  Symbols.groups,
                  size: 26,
                  fill: 1,
                  color: AppColors.textBrandOnLight,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$groupName에 올렸어요',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '오늘 활동이 그룹 피드에 공유됐어요. 멤버들이 좋아요를 눌러줄 거예요.',
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

  @override
  Widget build(BuildContext context) {
    // 실제 수거 데이터 읽기
    final state = ref.watch(ploggingProvider);
    final counts = state.totalCounts;
    final totalTrash = counts.values.fold<int>(0, (s, v) => s + v);

    // 스크롤 없이도 보상 카드가 보이면(짧은 화면) 카운트업 시작
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartReward());

    // 정산은 되돌아갈 수 없음 — 기기 뒤로가기로 트래킹/지도에 복귀하지 않게 막는다
    // 상단바(축하)·하단바(버튼)도 고정하지 않고 내용과 함께 스크롤된다.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _maybeStartReward();
            return false;
          },
          child: SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                _buildHero(totalTrash),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    children: [
                      _mapCard(),
                      const SizedBox(height: 14),
                      _recordCard(totalTrash),
                      const SizedBox(height: 14),
                      _trashCard(counts, totalTrash),
                      const SizedBox(height: 14),
                      _rewardCard(),
                      const SizedBox(height: 14),
                      _bottomButtons(),
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

  // ───────────────────────── 상단 축하 영역 (연초록 틴트) ─────────────────────────
  // 물개 이미지 없이 가운데 정렬, 아래로 넉넉하게 내려온다.
  Widget _buildHero(int totalTrash) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        // 다른 화면과 톤 통일: 쿨 뉴트럴 블록 + 초록은 포인트(제목)로만.
        color: AppColors.neutral100,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24 + topPad, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '플로깅 완료!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textBrandOnLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalTrash개를 주웠어요. 오늘도 고생했어요!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 활동 경로 지도 ─────────────────────────
  Widget _mapCard() {
    final path = ref.watch(trackingProvider).path;

    return _card(
      title: '활동 경로',
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          // 경로가 없으면(위치 못 받음 / 너무 짧음) 안내만 표시
          child: path.length < 2
              ? Container(
                  color: AppColors.surfaceBrand,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.map_outlined,
                        size: 32,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 6),
                      Text(
                        '기록된 경로가 없어요',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : NaverMap(
                  options: NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: NLatLng(path.first.lat, path.first.lng),
                      zoom: 15,
                    ),
                    // 정산 화면에서는 보기만 — 조작 최소화
                    scrollGesturesEnable: false,
                    zoomGesturesEnable: false,
                    rotationGesturesEnable: false,
                    tiltGesturesEnable: false,
                    logoClickEnable: false,
                  ),
                  onMapReady: (controller) => _drawRoute(controller, path),
                ),
        ),
      ),
    );
  }

  // 지도에 경로선 + 시작/도착 마커 그리기
  Future<void> _drawRoute(
    NaverMapController controller,
    List<TrackPoint> path,
  ) async {
    try {
      final coords = path.map((p) => NLatLng(p.lat, p.lng)).toList();

      // 경로선 (초록 곡선)
      await controller.addOverlay(
        NPolylineOverlay(
          id: 'activity_route',
          coords: coords,
          color: _routeColor,
          width: 6,
        ),
      );

      // 시작(사람) · 도착(깃발) 커스텀 핀
      if (!mounted) return;
      final startIcon = await _pinIcon(Icons.person);
      final endIcon = await _pinIcon(Icons.flag_rounded);
      if (!mounted) return;
      await controller.addOverlay(
        NMarker(
          id: 'route_start',
          position: coords.first,
          icon: startIcon,
          size: const NSize(40, 50),
          anchor: const NPoint(0.5, 1.0),
        ),
      );
      await controller.addOverlay(
        NMarker(
          id: 'route_end',
          position: coords.last,
          icon: endIcon,
          size: const NSize(40, 50),
          anchor: const NPoint(0.5, 1.0),
        ),
      );

      // 경로 전체가 보이도록 카메라 이동
      final bounds = NLatLngBounds.from(coords);
      await controller.updateCamera(
        NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(32)),
      );
    } catch (e) {
      debugPrint('[정산] 경로 지도 그리기 실패: $e');
    }
  }

  // 지도 핀 아이콘(흰 원 + 초록 아이콘 + 삼각 꼬리) 이미지 생성.
  Future<NOverlayImage> _pinIcon(IconData icon) {
    return NOverlayImage.fromWidget(
      context: context,
      size: const Size(40, 50),
      widget: Directionality(
        textDirection: TextDirection.ltr,
        child: _SettlePin(icon: icon),
      ),
    );
  }

  // ───────────────────────── 오늘의 기록 (트래킹 실측값) ─────────────────────────
  Widget _recordCard(int totalTrash) {
    final t = ref.watch(trackingProvider);
    // 무게는 카테고리별 평균으로 계산 (다른 화면과 통일)
    final counts = ref.watch(ploggingProvider).totalCounts;
    final weight = ActivityMetrics.weightLabel(counts);
    return _card(
      title: '오늘의 기록',
      child: Column(
        children: [
          Row(
            children: [
              _metricTile(
                const Icon(Symbols.schedule,
                    size: 20, fill: 1, color: AppColors.dataTime),
                '시간',
                t.durationText,
              ),
              const SizedBox(width: 10),
              _metricTile(
                const Icon(Symbols.route,
                    size: 20, fill: 1, color: AppColors.dataDistance),
                '거리',
                '${t.distanceText} km',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metricTile(
                const Icon(Symbols.footprint,
                    size: 20, fill: 1, color: AppColors.dataSteps),
                '걸음',
                _comma(t.steps),
              ),
              const SizedBox(width: 10),
              _metricTile(
                const TrashBagIcon(size: 20, color: AppColors.green600),
                '무게',
                weight,
              ),
            ],
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

  Widget _metricTile(Widget icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.neutral100, // 쿨 뉴트럴 타일 (다른 화면과 통일)
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // 흰 라운드 사각 배경 + 색 아이콘
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: icon,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
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

  // ───────────────────────── 수거한 쓰레기 (실제 데이터 + 컬러 아이콘) ─────────────────────────
  Widget _trashCard(Map<String, int> counts, int total) {
    return _card(
      title: '수거한 쓰레기',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
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
      // 오늘의 기록 타일과 동일한 박스 + 원형 아이콘 배지로 통일
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _trashDefs.map((d) {
          final int c = counts[d.key] ?? 0;
          final bool active = c > 0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
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
                      child: Icon(d.icon, size: 20, fill: 1, color: d.color),
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
    );
  }

  // ───────────────────────── 획득 보상 (스크롤 진입 시 카운트업) ─────────────────────────
  // TODO: 포인트/경험치 값은 보상 로직 생기면 provider 값으로 교체.
  // 획득 보상 — '획득 보상' 라벨 오른쪽에 작은 알약 두 개(포인트/경험치).
  // 스크롤로 처음 보일 때 숫자가 카운트업된다.
  Widget _rewardCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          const Text(
            '획득 보상',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          // 포인트는 느리게, 경험치는 빠르게 올라간다.
          _rewardPill(Symbols.eco, 'P', _rewardPoints, AppColors.dataDistance, 2000),
          const SizedBox(width: 8),
          _rewardPill(Symbols.star, 'XP', _rewardXp, AppColors.dataTime, 1100),
        ],
      ),
    );
  }

  Widget _rewardPill(
    IconData icon,
    String unit,
    int target,
    Color color,
    int ms,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _rewardShown ? 1 : 0),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final int v = (target * t).round();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.tint(color, 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, fill: 1, color: color),
              const SizedBox(width: 5),
              Text(
                '+$v $unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────── 하단 버튼 (인증샷 찍기 / 활동 마치기) ───────────────
  //
  // 갤러리 선택은 없다 — 현장에서 직접 찍어야 인증이 된다는 취지.
  //
  // SafeArea 로 감싸 시스템 네비게이션 바(홈·뒤로가기)와 겹치지 않게 한다.
  // 폰마다 네비바 높이가 달라 고정 여백으로는 대응할 수 없다.
  Widget _bottomButtons() {
    // 하단 버튼 영역은 흰 바 위에 얹는다 (목업 2번째 이미지).
    Widget inner;
    if (_uploading) {
      inner = const Padding(
        padding: EdgeInsets.fromLTRB(0, 12, 0, 6),
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
    } else {
      // 인증샷 찍기(선택·테두리) + 활동 마치기(초록). 갤러리 선택 없음(현장 인증 취지).
      inner = Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                label: '인증샷 찍기',
                icon: Icons.photo_camera,
                onTap: _takePhoto,
                type: AppButtonType.secondary,
                expand: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: '활동 마치기',
                onTap: _skip,
                type: AppButtonType.primary,
                expand: false,
              ),
            ),
          ],
        ),
      );
    }
    // 내용과 함께 스크롤되므로 고정 흰 바 대신 하단 안전영역만 확보한다.
    return SafeArea(top: false, child: inner);
  }

  // 공통 카드 래퍼
  Widget _card({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
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

// 활동 경로 지도 핀: 흰 원 + 초록 아이콘 + 아래 삼각 꼬리.
class _SettlePin extends StatelessWidget {
  final IconData icon;
  const _SettlePin({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.neutral900.withValues(alpha: 0.22),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        SizedBox(
          width: 14,
          height: 8,
          child: CustomPaint(painter: _PinTailPainter()),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  const _PinTailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _PinTailPainter oldDelegate) => false;
}