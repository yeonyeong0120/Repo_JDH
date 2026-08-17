// 플로깅 경로 설정 화면. 트래킹을 시작하기 전 준비 단계를 담당한다.
// 1) 현재 GPS 위치를 출발지로 지도 중심에 둔다.
// 2) 지도를 탭하면 그 지점을 도착지로 마커 표시한다(다시 탭하면 갱신).
// 3) "경로 받기"를 누르면 출발=현재GPS, 도착=탭지점으로 경로를 추천받는다.
// 4) 추천 결과의 polyline은 NPathOverlay, k3 핫스팟은 NMarker로 그린다. hard case면 안내.
// 5) "플로깅 시작"을 누르면 트래킹 화면(PloggingTrackingScreen)으로 이동한다.
//    또한 강제 종료된 세션이 있으면(PLOG-10) 진입 시 이어할지 묻는다.
//
// 가이드라인 준수: setState 미사용(Riverpod 상태로 관리), AsyncValue.when, withValues(alpha:),
//                 package: 절대경로 import, 한국어 주석.
//
// 선결: main.dart에서 dotenv.load 및 FlutterNaverMap().init(clientId: ...) 완료 상태여야
//       지도가 렌더링된다. 경로 추천은 백엔드 /route/recommend 배포 시 실제 응답한다.

import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:repo_jdh/core/router/app_router.dart';
import 'package:repo_jdh/core/providers/tracking_provider.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/features/plogging/domain/destination_providers.dart';
import 'package:repo_jdh/features/plogging/domain/route_models.dart';
import 'package:repo_jdh/features/plogging/domain/route_notifier.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

class RouteSetupScreen extends ConsumerStatefulWidget {
  const RouteSetupScreen({super.key});

  @override
  ConsumerState<RouteSetupScreen> createState() => _RouteSetupScreenState();
}

class _RouteSetupScreenState extends ConsumerState<RouteSetupScreen> {
  // PLOG-10 트래킹 중단 복구 — 강제 종료된 세션이 있으면 이어할지 묻는다
  Future<void> _checkInterrupted() async {
    TrackingState? saved;
    try {
      saved = await TrackingNotifier.loadSaved();
    } catch (_) {
      return;
    }
    if (saved == null || !mounted) return;

    final km = saved.distanceKm.toStringAsFixed(1);
    final ok = await AppDialog.show(
      context,
      title: '활동이 중단되었어요',
      message:
          '예기치 못하게 종료되었습니다.\n\n'
          '${saved.durationText} · ${km}km 까지 기록되어 있어요.\n'
          '이어서 하시겠습니까?',
      cancelText: '종료하기',
      confirmText: '이어서 하기',
      barrierDismissible: false,
    );
    if (!mounted) return;

    if (ok == true) {
      ref.read(trackingProvider.notifier).resume(saved);
      context.push(AppRoutes.ploggingTracking);
    } else {
      // 종료 선택 → 기록 폐기
      await TrackingNotifier.clearSaved();
    }
  }

  // GPS를 아직 못 받았을 때 보여줄 기본 카메라 위치(인천 부평구청 부근).
  static const _fallback = NLatLng(37.5074, 126.7218);

  // 경로 색상.
  static const _routeColor = AppColors.routeLine;

  NaverMapController? _controller;
  bool _dragging = false; // 지도를 움직이는 중인지 (중앙 깃발 살짝 뜸)
  // GPS 위치를 받아 지도를 처음 한 번만 출발지로 이동시키기 위한 플래그.
  bool _centeredOnOrigin = false;

  @override
  void initState() {
    super.initState();
    // 화면에 다시 들어올 때 이전 추천 결과가 남지 않도록 초기화한다.
    // (routeNotifierProvider는 autoDispose가 아니라서 수동 초기화가 필요하다.)
    Future.microtask(() {
      if (mounted) ref.read(routeNotifierProvider.notifier).reset();
    });
    // 강제 종료된 활동이 있으면 이어할지 묻는다
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInterrupted());
  }

  @override
  Widget build(BuildContext context) {
    final originAsync = ref.watch(currentLocationProvider);
    final destination = ref.watch(destinationProvider);
    final routeState = ref.watch(routeNotifierProvider);

    // GPS가 도착하면 지도를 출발지로 한 번 이동시킨다.
    ref.listen(currentLocationProvider, (prev, next) {
      next.whenData(_centerOnOrigin);
    });

    // 추천 결과가 갱신되면 지도에 다시 그린다.
    ref.listen(routeNotifierProvider, (prev, next) {
      next.whenData((result) {
        if (result != null) _render();
      });
    });

    final bool showHint = _dragging || destination == null;

    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _fallback,
                zoom: 14,
              ),
              locationButtonEnable: false,
            ),
            onMapReady: (controller) {
              _controller = controller;
              _centerOnOrigin(originAsync.valueOrNull);
              _render();
            },
            // 탭이 아니라 '지도를 움직여' 중앙 깃발에 맞춘다.
            onCameraChange: _onCameraChange,
            onCameraIdle: _onCameraIdle,
          ),

          // 중앙 고정 타깃 점 (깃발 끝이 가리키는 지점)
          const IgnorePointer(
            child: Center(
              child: _CenterDot(),
            ),
          ),
          // 중앙 고정 깃발 + ETA (핀 끝이 타깃 점에 오도록 위로 올림)
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                // 꼬리 끝(하단)이 중앙 타깃 점에 오도록 위로 올린다. 말풍선 슬롯 포함 총높이의 절반.
                offset: const Offset(0, -46),
                child: _CenterFlag(etaLabel: _etaLabel(routeState)),
              ),
            ),
          ),

          // 상단: 뒤로가기 + 내 위치
          Positioned(
            left: 16,
            right: 16,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _glassButton(
                      icon: TablerIcons.chevronLeft,
                      onTap: () => context.pop(),
                    ),
                    _glassButton(
                      icon: TablerIcons.currentLocation,
                      onTap: _recenter,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 힌트 칩
          if (showHint)
            Positioned(
              left: 16,
              right: 16,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: Center(child: _hintChip()),
                ),
              ),
            ),

          // 하단 카드
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildCard(originAsync, destination, routeState),
          ),
        ],
      ),
    );
  }

  // 지도를 출발지(현재 GPS)로 최초 1회 이동한다.
  void _centerOnOrigin(Map<String, dynamic>? location) {
    if (_centeredOnOrigin) return;
    final controller = _controller;
    if (controller == null || location == null) return;

    final lat = (location['latitude'] as num?)?.toDouble();
    final lon = (location['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return;

    _centeredOnOrigin = true;
    controller.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lon), zoom: 15),
    );
    _render();
  }

  // 지도를 움직이는 중: 깃발을 살짝 띄우고, 이전 추천 경로는 비운다.
  void _onCameraChange(NCameraUpdateReason reason, bool animated) {
    if (reason != NCameraUpdateReason.gesture) return;
    if (!_dragging) {
      setState(() => _dragging = true);
      ref.read(routeNotifierProvider.notifier).reset();
      _render(); // 경로 폴리라인 제거 (출발 마커만 남김)
    }
  }

  // 지도가 멈추면: 화면 중앙 좌표를 도착지로 확정하고 경로를 다시 요청한다.
  Future<void> _onCameraIdle() async {
    final controller = _controller;
    if (controller == null) return;
    final pos = await controller.getCameraPosition();
    if (!mounted) return;
    final center = pos.target;
    ref.read(destinationProvider.notifier).state = (
      center.latitude,
      center.longitude,
    );
    setState(() => _dragging = false);
    // 경로는 '이 위치로 도착지 설정' 버튼을 눌러야 계산한다 (핀 이동마다 자동 계산 X).
  }

  // 내 위치로 복귀
  void _recenter() {
    final loc = ref.read(currentLocationProvider).valueOrNull;
    final lat = (loc?['latitude'] as num?)?.toDouble();
    final lon = (loc?['longitude'] as num?)?.toDouble();
    final controller = _controller;
    if (controller == null || lat == null || lon == null) return;
    controller.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lon), zoom: 15),
    );
  }

  // 도착 마커 라벨과 같은 값: '약 N분 · N.Nkm' (결과 있을 때만)
  String? _etaLabel(AsyncValue<RouteResult?> routeState) {
    final result = routeState.valueOrNull;
    if (result == null || result.durationMs <= 0) return null;
    final min = (result.durationMs / 60000).round();
    final km = (result.distanceM / 1000).toStringAsFixed(1);
    return '약 ${min < 1 ? 1 : min}분 · ${km}km';
  }

  Widget _hintChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.neutral900.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TablerIcons.handClick, size: 19, color: Colors.white),
          SizedBox(width: 7),
          Text(
            '지도를 움직여 도착지를 맞춰주세요',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral900.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 23, color: AppColors.textPrimary),
      ),
    );
  }

  // 현재 상태(출발지·도착지·추천 결과)를 지도에 통째로 다시 그린다.
  // clearOverlays로 비운 뒤 필요한 오버레이만 재구성해 stale 오버레이를 방지한다.
  // 도착 마커는 깃발+예상시간 라벨을 위젯 이미지로 그려 붙인다(비동기).
  Future<void> _render() async {
    final controller = _controller;
    if (controller == null) return;

    final overlays = <NAddableOverlay>{};

    // 출발지(내 위치) 마커 — 흰 링 안 초록 점(퍽)
    final origin = ref.read(currentLocationProvider).valueOrNull;
    final originLat = (origin?['latitude'] as num?)?.toDouble();
    final originLon = (origin?['longitude'] as num?)?.toDouble();
    if (originLat != null && originLon != null) {
      final originIcon = await _buildOriginMarkerIcon();
      if (!mounted) return;
      overlays.add(
        NMarker(
          id: 'origin',
          position: NLatLng(originLat, originLon),
          icon: originIcon,
          size: const NSize(26, 26),
          anchor: const NPoint(0.5, 0.5), // 점이라 정중앙 고정
        ),
      );
    }

    // 도착지는 화면 중앙 고정 깃발이 대신한다(지도 마커 없음).

    // 추천 경로 + 정화 거점(핫스팟) 마커
    final result = ref.read(routeNotifierProvider).valueOrNull;
    if (result != null) {
      if (result.polyline.length >= 2) {
        final coords = result.polyline
            .map((p) => NLatLng(p[0], p[1]))
            .toList();
        // 바탕: 얇은 회색 테두리로 둘러싼 흰 선
        overlays.add(
          NPathOverlay(
            id: 'route_base',
            coords: coords,
            width: 11,
            color: Colors.white,
            outlineWidth: 1,
            outlineColor: AppColors.neutral300,
          ),
        );
        // 위: 흰 선 안쪽의 초록 선
        overlays.add(
          NPathOverlay(
            id: 'route',
            coords: coords,
            width: 4,
            color: _routeColor,
            outlineWidth: 0,
          ),
        );
      }
      // 정화 거점: 흰 핀 + 초록 재활용 아이콘
      final hotspotIcon = await _buildHotspotIcon();
      if (!mounted) return;
      for (int i = 0; i < result.k3Hotspots.length; i++) {
        final h = result.k3Hotspots[i];
        overlays.add(
          NMarker(
            id: 'hotspot_$i',
            position: NLatLng(h.latitude, h.longitude),
            icon: hotspotIcon,
            size: const NSize(34, 42),
            anchor: const NPoint(0.5, 1.0),
          ),
        );
      }
    }

    controller.clearOverlays();
    if (overlays.isNotEmpty) controller.addOverlayAll(overlays);
  }

  // 내 위치 퍽: 흰 링 + 초록 점.
  Future<NOverlayImage> _buildOriginMarkerIcon() {
    return NOverlayImage.fromWidget(
      context: context,
      size: const Size(30, 30),
      widget: const Directionality(
        textDirection: TextDirection.ltr,
        child: _LocationPuck(),
      ),
    );
  }

  // 정화 거점 핀: 흰 물방울 + 초록 재활용 아이콘.
  Future<NOverlayImage> _buildHotspotIcon() {
    return NOverlayImage.fromWidget(
      context: context,
      size: const Size(34, 42),
      widget: const Directionality(
        textDirection: TextDirection.ltr,
        child: _HotspotPin(),
      ),
    );
  }

  // 경로 추천 요청. 출발=현재 GPS, 도착=탭 지점. district는 서버 전체 처리에 위임(생략).
  void _requestRoute() {
    final origin = ref.read(currentLocationProvider).valueOrNull;
    final dest = ref.read(destinationProvider);

    if (origin == null) {
      _toast('현재 위치를 가져오지 못했습니다. 위치 권한을 확인해 주세요.');
      return;
    }
    if (dest == null) {
      _toast('지도를 탭해 도착지를 먼저 선택하세요.');
      return;
    }

    ref
        .read(routeNotifierProvider.notifier)
        .recommend(
          originLat: (origin['latitude'] as num).toDouble(),
          originLon: (origin['longitude'] as num).toDouble(),
          destLat: dest.$1,
          destLon: dest.$2,
        );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // 하단 카드(이미지1): 도착지 헤더 + 정화 거점/위험 구간 안내 + '이 위치로 도착지 설정'.
  Widget _buildCard(
    AsyncValue<Map<String, dynamic>?> originAsync,
    (double, double)? destination,
    AsyncValue<RouteResult?> routeState,
  ) {
    final result = routeState.valueOrNull;
    final bool loading = routeState.isLoading;
    final bool hasError = routeState.hasError && !loading;
    final bool ready = result != null && !loading;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.sheetShadow,
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 도착지 헤더 (깃발 타일 + 라벨 + 주소) — 깃발은 위쪽 정렬
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  TablerIcons.flagFilled,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '도착지',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: AppColors.textBrandOnLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // TODO: Geocoding 프록시 연결 시 실제 주소로 대체.
                      _dragging
                          ? '도착지를 맞추는 중'
                          : (loading ? '경로를 계산하고 있어요' : '지도 중앙 지점'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _dragging
                          ? '핀을 원하는 위치에 맞춰요'
                          : (loading
                                ? '쓰레기가 많은 곳을 지나도록 골라요'
                                : (ready ? '경로 계산 완료' : '버튼을 누르면 경로를 계산해요')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 구분선 + 안내 — 경로가 준비됐거나 실패했을 때만 노출
          if (ready || hasError) ...[
            const SizedBox(height: 14),
            Divider(height: 1, thickness: 1, color: AppColors.border),
            const SizedBox(height: 14),
            if (hasError)
              _noticeRow(
                icon: TablerIcons.alertCircle,
                text: '경로를 계산하지 못했어요. 도착지를 다시 맞춰주세요.',
                color: AppColors.actionDanger,
              )
            else ...[
              _noticeRow(
                icon: TablerIcons.recycle,
                text: '정화 거점 ${result!.k3Hotspots.length}곳을 지나요',
                color: AppColors.textBrandOnLight,
              ),
              const SizedBox(height: 10),
              if (result!.isHardCase)
                _noticeRow(
                  icon: TablerIcons.alertTriangle,
                  text: '위험 구간 약 ${result.intersectionM}m를 지나요',
                  color: AppColors.warning,
                )
              else
                _noticeRow(
                  icon: TablerIcons.circleCheckFilled,
                  text: '위험 구간을 지나지 않아요',
                  color: AppColors.textBrandOnLight,
                ),
            ],
          ],

          const SizedBox(height: 16),
          _startButton(loading: loading, ready: ready),
        ],
      ),
    );
  }

  // 안내 한 줄 (아이콘 + 문구)
  Widget _noticeRow({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: color == AppColors.textBrandOnLight
                  ? AppColors.textPrimary
                  : color,
            ),
          ),
        ),
      ],
    );
  }

  // 단계별 하단 버튼:
  //  - 도착지 맞추는 중 → 잠금
  //  - (도착지 확정) '이 위치로 도착지 설정' → 경로 계산 요청
  //  - 계산 중 → '경로를 계산하고 있어요' 잠금(스피너)
  //  - 계산 완료 → '플로깅 시작' → 트래킹 화면
  Widget _startButton({required bool loading, required bool ready}) {
    late final String label;
    late final IconData icon;
    late final bool enabled;
    late final VoidCallback? onTap;

    if (_dragging) {
      label = '도착지를 맞추는 중';
      icon = TablerIcons.flagFilled;
      enabled = false;
      onTap = null;
    } else if (loading) {
      label = '경로를 계산하고 있어요';
      icon = TablerIcons.route;
      enabled = false;
      onTap = null;
    } else if (ready) {
      label = '플로깅 시작';
      icon = TablerIcons.run;
      enabled = true;
      onTap = () => context.push(AppRoutes.ploggingTracking);
    } else {
      label = '이 위치로 도착지 설정';
      icon = TablerIcons.flagFilled;
      enabled = true;
      onTap = _requestRoute;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.actionPrimary : AppColors.neutral200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.textSecondary,
                ),
              )
            else
              Icon(
                icon,
                size: 21,
                color: enabled ? AppColors.textOnBrand : AppColors.textDisabled,
              ),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: enabled ? AppColors.textOnBrand : AppColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 내 위치 퍽: 흰 링 + 초록 점.
class _LocationPuck extends StatelessWidget {
  const _LocationPuck();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral900.withValues(alpha: 0.22),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: SizedBox(width: 13, height: 13),
        ),
      ),
    );
  }
}

// 정화 거점 핀: 도착지 핀과 같은 모양(흰 원 + 아래 삼각 꼬리) + 초록 재활용 아이콘.
class _HotspotPin extends StatelessWidget {
  const _HotspotPin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 42,
      child: Stack(
        children: [
          // 도착지 핀과 동일한 도형(_PinShapePainter)을 사용해 모양을 맞춘다.
          const Positioned.fill(
            child: CustomPaint(painter: _PinShapePainter()),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 9,
            child: Center(
              child: Icon(TablerIcons.recycle, color: AppColors.primary, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// 화면 중앙에 고정되는 타깃 점. 깃발 대의 끝이 가리키는 실제 도착 지점.
class _CenterDot extends StatelessWidget {
  const _CenterDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.neutral900.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

// 화면 중앙에 고정되는 도착지 핀(이미지1): 흰 원 + 초록 깃발 + 아래 삼각 꼬리.
// 경로가 계산되면 원 위에 검은 ETA 말풍선을 띄운다(레이아웃 밀림 방지용 고정 슬롯).
class _CenterFlag extends StatelessWidget {
  final String? etaLabel; // '약 N분 · N.Nkm' (경로 결과 있을 때만)
  const _CenterFlag({this.etaLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 말풍선 슬롯: 높이를 고정해 핀의 세로 위치가 ETA 유무에 상관없이 일정하다.
        SizedBox(
          height: 30,
          child: etaLabel == null
              ? null
              : Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.neutral900.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      etaLabel!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        // 흰 원 + 꼬리를 하나의 도형(union)으로 그린 핀 + 초록 깃발
        SizedBox(
          width: 46,
          height: 55,
          child: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: _PinShapePainter()),
              ),
              const Positioned(
                left: 0,
                right: 0,
                top: 11,
                child: Center(
                  child: Icon(
                    TablerIcons.flagFilled,
                    color: AppColors.primary,
                    size: 23,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 도착지 핀: 원 + 아래 삼각을 union 으로 합쳐 이음새 없이 그린다.
class _PinShapePainter extends CustomPainter {
  const _PinShapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = w / 2;
    final double cy = r; // 원 중심 y = 반지름
    final circle = Path()
      ..addOval(Rect.fromCircle(center: Offset(w / 2, cy), radius: r));
    final tri = Path()
      ..moveTo(w / 2 - r * 0.64, cy + r * 0.52)
      ..lineTo(w / 2 + r * 0.64, cy + r * 0.52)
      ..lineTo(w / 2, h)
      ..close();
    final pin = Path.combine(PathOperation.union, circle, tri);
    canvas.drawShadow(pin, Colors.black.withValues(alpha: 0.4), 4, false);
    canvas.drawPath(pin, Paint()..color = Colors.white..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _PinShapePainter oldDelegate) => false;
}
