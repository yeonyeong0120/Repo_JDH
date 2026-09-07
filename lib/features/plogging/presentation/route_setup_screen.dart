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
import 'package:repo_jdh/features/plogging/data/location_repository.dart';
import 'package:repo_jdh/features/plogging/presentation/destination_search_screen.dart';
import 'package:repo_jdh/features/plogging/domain/route_models.dart';
import 'package:repo_jdh/features/plogging/domain/route_notifier.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';

class RouteSetupScreen extends ConsumerStatefulWidget {
  const RouteSetupScreen({super.key});

  @override
  ConsumerState<RouteSetupScreen> createState() => _RouteSetupScreenState();
}

class _RouteSetupScreenState extends ConsumerState<RouteSetupScreen>
    with SingleTickerProviderStateMixin {
  // 코스 변경 아이콘 회전(반시계) — 재추천 중에만 돈다.
  late final AnimationController _spinCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  // PLOG-10 트래킹 중단 복구 — 중단된 세션이 있으면 이어할지 묻는다.
  // 기기 뒤로가기로 트래킹 화면을 빠져나오면 provider 는 여전히 running 이므로
  // 메모리 상태를 먼저 확인하고(항상 잡힘), 없을 때만 디스크(강제 종료 대비)를 본다.
  Future<void> _checkInterrupted() async {
    TrackingState? saved;
    final live = ref.read(trackingProvider);
    if (live.running) {
      saved = live;
    } else {
      try {
        saved = await TrackingNotifier.loadSaved();
      } catch (_) {
        return;
      }
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
      // 종료 선택 → 디스크·메모리 세션 모두 폐기(다시 물어보지 않게)
      await TrackingNotifier.clearSaved();
      ref.read(trackingProvider.notifier).reset();
    }
  }

  // GPS를 아직 못 받았을 때 보여줄 기본 카메라 위치(인천 부평구청 부근).
  static const _fallback = NLatLng(37.5074, 126.7218);

  // 경로 색상.
  static const _routeColor = AppColors.routeLine;

  NaverMapController? _controller;
  // GPS 위치를 받아 지도를 처음 한 번만 출발지로 이동시키기 위한 플래그.
  bool _centeredOnOrigin = false;

  // 현재 도착지(탭 지점)의 실제 주소 — 역지오코딩 결과. 최신 요청만 반영.
  String? _destAddress;
  int _geoReq = 0;

  // 탭한 도착지 좌표를 실제 주소로 변환해 카드에 표시한다.
  // 출발지와 동일한 기기 내장 geocoding 을 쓴다(서버 불필요).
  Future<void> _resolveDestAddress(double lat, double lon) async {
    final int req = ++_geoReq;
    final name = await LocationRepository().addressOf(lat, lon);
    // 그 사이 다시 움직였으면(더 최신 요청 존재) 무시
    if (!mounted || req != _geoReq) return;
    setState(() => _destAddress = name);
  }

  @override
  void initState() {
    super.initState();
    // 화면에 다시 들어올 때 이전 추천 결과가 남지 않도록 초기화한다.
    // (routeNotifierProvider는 autoDispose가 아니라서 수동 초기화가 필요하다.)
    Future.microtask(() {
      if (!mounted) return;
      // 활동을 마치고 다시 들어와도 이전 도착지 핀·주소·경로가 남지 않게 모두 초기화한다.
      ref.read(destinationProvider.notifier).state = null;
      ref.read(routeNotifierProvider.notifier).reset();
      setState(() => _destAddress = null);
    });
    // 강제 종료된 활동이 있으면 이어할지 묻는다
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInterrupted());
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
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
        if (result == null) return;
        _render();
      });
    });

    // 도착지 미설정 시에만 '지도를 눌러 선택' 힌트를 띄운다.
    final bool showHint = destination == null;

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
            // 지도를 탭한 지점을 도착지로 확정한다(중앙 조준이 아니라 탭 선택).
            onMapTapped: _onMapTapped,
          ),

          // 상단: 뒤로가기 + 검색창 + 내 위치
          Positioned(
            left: 18,
            right: 18,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    _iconButton(
                      icon: TablerIcons.chevronLeft,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: _searchField(destination)),
                  ],
                ),
              ),
            ),
          ),

          // 하단: 힌트 + 카드
          Positioned(
            left: 18,
            right: 18,
            // 3버튼 내비 바에 카드가 가리지 않도록 시스템 하단 인셋을 더한다.
            bottom: 32 + MediaQuery.of(context).padding.bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 내 위치로 복귀 — 하얀 바탕 없이 아이콘만.
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _recenter,
                    child: const SizedBox(
                      width: 46,
                      height: 46,
                      child: Center(
                        child: Icon(
                          TablerIcons.currentLocation,
                          size: 26,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (showHint) ...[
                  Center(child: _hintChip()),
                  const SizedBox(height: 9),
                ],
                _buildCard(originAsync, destination, routeState),
              ],
            ),
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

  // 지도를 탭하면 그 지점을 도착지로 확정한다.
  // 이전 추천 경로는 새 도착지 기준으로 무효이므로 초기화하고, 탭 지점을 핀으로 그린다.
  void _onMapTapped(NPoint point, NLatLng latLng) {
    ref.read(destinationProvider.notifier).state = (
      latLng.latitude,
      latLng.longitude,
    );
    // 새 도착지 → 이전 경로/핫스팟 무효화(버튼을 눌러야 새로 계산한다).
    ref.read(routeNotifierProvider.notifier).reset();
    // 탭 지점(도착지)의 실제 주소를 역지오코딩해 표시
    _resolveDestAddress(latLng.latitude, latLng.longitude);
    _render();
  }

  // 목적지 지우기 — 검색창 × 버튼. 도착지·경로를 초기화한다.
  void _clearDest() {
    ref.read(destinationProvider.notifier).state = null;
    ref.read(routeNotifierProvider.notifier).reset();
    if (!mounted) return;
    setState(() {
      _destAddress = null;
    });
    _render();
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
    // 스크린샷 말풍선 포맷: 거리 먼저, 그다음 시간 (예: 2.4km · 38분).
    return '${km}km · ${min < 1 ? 1 : min}분';
  }

  // 힌트 pill — 목적지 미설정. 탭 안내(라임 아이콘 + 문구).
  Widget _hintChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.90),
        borderRadius: Radii.fullR,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TablerIcons.handClick, size: 16, color: AppColors.lime),
          SizedBox(width: 7),
          Text(
            '지도를 눌러 도착지를 선택하세요',
            style: TextStyle(
              fontFamily: AppType.fontFamily,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // 상단 흰 아이콘 버튼(뒤로가기 · 내 위치). 46×46 radius16 + 그림자.
  // 규칙 A: 헤더 아이콘은 글리프만(컨테이너 없음) · 44x44 탭 영역 · 잉크색.
  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Icon(icon, size: 24, color: AppColors.ink),
        ),
      ),
    );
  }

  // 상단 검색창. 목적지가 잡히면 역지오코딩 주소를 보여주고 × 로 지운다.
  // 탭하면 목적지 검색 화면으로 이동한다(지도 탭으로도 선택 가능).
  Widget _searchField((double, double)? destination) {
    final bool set = destination != null && _destAddress != null;
    final String text = _destAddress ?? '장소 · 지하철역 · 주소 검색';
    // 검색창을 누르면 목적지 검색 화면(07)으로 이동한다.
    // 코드젠 라우터(app_router.g.dart)를 건드리지 않도록 MaterialPageRoute로 push 한다.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const DestinationSearchScreen(),
        ),
      ),
      child: Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Radii.innerR,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(TablerIcons.search, size: 19, color: AppColors.gray500),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.label.copyWith(
                fontWeight: FontWeight.w600,
                color: set ? AppColors.ink : AppColors.gray350,
              ),
            ),
          ),
          if (destination != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _clearDest,
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.line100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(TablerIcons.x, size: 15, color: AppColors.gray700),
              ),
            ),
          ],
        ],
      ),
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

    // 출발지(내 위치) — 네이버 내장 위치 오버레이로 표시 (플로깅 화면과 아이콘 통일)
    final origin = ref.read(currentLocationProvider).valueOrNull;
    final originLat = (origin?['latitude'] as num?)?.toDouble();
    final originLon = (origin?['longitude'] as num?)?.toDouble();
    if (originLat != null && originLon != null) {
      final overlay = controller.getLocationOverlay();
      overlay.setIsVisible(true);
      overlay.setPosition(NLatLng(originLat, originLon));
      // 네이버 기본 파란 점 대신 검정 방향 포인터로 교체한다(네이버 지도 느낌).
      await _styleMyLocationOverlay(overlay);
    }

    // 도착지 핀 — 사용자가 탭한 지점에 깃발 마커로 박는다. 지도를 움직여도 남는다.
    // 경로가 계산되면 핀 위 말풍선에 ETA(거리·시간)를 함께 그린다(스크린샷).
    final dest = ref.read(destinationProvider);
    if (dest != null) {
      final etaLabel = _etaLabel(ref.read(routeNotifierProvider));
      final destIcon = await _buildDestIcon(etaLabel);
      if (!mounted) return;
      overlays.add(
        NMarker(
          id: 'dest',
          position: NLatLng(dest.$1, dest.$2),
          icon: destIcon,
          size: const NSize(160, 96),
          anchor: const NPoint(0.5, 1.0), // 핀 꼬리 끝(하단 중앙)이 좌표를 가리킨다
        ),
      );
    }

    // 추천 경로 + 정화 거점(핫스팟) 마커
    final result = ref.read(routeNotifierProvider).valueOrNull;
    if (result != null) {
      if (result.polyline.length >= 2) {
        final coords = result.polyline
            .map((p) => NLatLng(p[0], p[1]))
            .toList();
        // 추천 경로: 깔끔한 검정(ink) 단일 라인. 파랑/초록을 쓰지 않는다.
        // flutter_naver_map 1.4.4 의 NPathOverlay 에는 점선(dash) 속성이 없고
        // patternImage/patternInterval(반복 이미지)만 있어 깔끔한 점선이 되지
        // 않으므로, 디자인의 점선 대신 클린 솔리드 검정 라인으로 처리한다.
        overlays.add(
          NPathOverlay(
            id: 'route',
            coords: coords,
            width: 6,
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
  // 경로가 걸린 도착지 핀: 중앙 깃발과 같은 도형.

  // 도착지 핀(깃발 + 선택 시 ETA 말풍선)을 위젯 이미지로 그려 마커 아이콘으로 쓴다.
  Future<NOverlayImage> _buildDestIcon(String? etaLabel) {
    return NOverlayImage.fromWidget(
      context: context,
      size: const Size(160, 96),
      widget: Directionality(
        textDirection: TextDirection.ltr,
        child: _DestFlagPin(etaLabel: etaLabel),
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

  // 내 위치 오버레이를 네이버 기본 파란 점에서 검정 방향 포인터로 바꾼다.
  // getLocationOverlay / setIcon / setIconSize / setAnchor / setCircleColor /
  // setCircleRadius 는 flutter_naver_map 의 NLocationOverlay 실제 API다.
  // heading 은 currentLocationProvider(위도·경도·주소)에 없으므로 setBearing 은
  // 쓰지 않고, 위쪽을 가리키는 뾰족한 검정 포인터(고정 방향)로 그린다.
  Future<void> _styleMyLocationOverlay(NLocationOverlay overlay) async {
    final icon = await NOverlayImage.fromWidget(
      context: context,
      size: const Size(34, 36),
      widget: const Directionality(
        textDirection: TextDirection.ltr,
        child: _MyLocationPuck(),
      ),
    );
    if (!mounted) return;
    overlay.setIcon(icon);
    overlay.setIconSize(const Size(34, 36));
    // 삼각형 끝(아래)이 실제 좌표에 오도록 앵커를 하단 뾰족점으로.
    overlay.setAnchor(const NPoint(0.5, 0.944));
    // 정확도 원: 파랑 대신 은은한 검정으로.
    overlay.setCircleColor(AppColors.ink.withValues(alpha: 0.10));
    overlay.setCircleRadius(0);
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

  // 하단 카드(목업 구조): 목적지명 + 코스 변경 + 메타(거리/시간/정화지역) + '여기로 출발'.
  Widget _buildCard(
    AsyncValue<Map<String, dynamic>?> originAsync,
    (double, double)? destination,
    AsyncValue<RouteResult?> routeState,
  ) {
    // 도착지 미설정: 카드 없이 힌트만 보인다.
    if (destination == null) return const SizedBox.shrink();

    final result = routeState.valueOrNull;
    final bool loading = routeState.isLoading;
    final bool hasError = routeState.hasError && !loading;
    // 이전 결과가 있으면(코스 변경 재추천 중이라도) 준비 카드를 유지한다.
    // → 박스 전체 로딩 대신 '코스 변경' 아이콘만 반시계로 돈다.
    final bool ready = result != null;

    // 목적지명(역지오코딩 주소). 주소를 아직 못 받았으면 안내 문구.
    final String destName = _destAddress ?? '지도에서 선택한 지점';

    // 목적지명 텍스트 스타일(준비/비준비 공용).
    const destNameStyle = TextStyle(
      fontFamily: AppType.fontFamily,
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      color: AppColors.ink,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Radii.cardR,
        boxShadow: AppColors.sheetShadow,
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      // 준비 완료: 좌측(목적지명 + 코스 변경 · 메타) + 우측 컴팩트 '출발' 버튼(스크린샷).
      // 그 외 상태(이동 중·계산 중·미계산): 세로 배치 + 폭을 채운 상태 버튼.
      child: ready
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 상단 줄: 메타(정화지역·공장지대) 좌측 + 코스 변경 우측
                Row(
                  children: [
                    Expanded(
                      child: _cardMeta(
                        ready: true,
                        loading: false,
                        hasError: false,
                        result: result,
                      ),
                    ),
                    const SizedBox(width: 9),
                    _courseChangeChip(loading),
                  ],
                ),
                const SizedBox(height: 10),
                // 목적지명
                Text(
                  destName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: destNameStyle,
                ),
                const SizedBox(height: 16),
                // 전체 폭 '출발' 버튼(잉크 + 라임 러닝 아이콘)
                _startButton(loading: false, ready: true),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        destName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: destNameStyle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                _cardMeta(
                  ready: false,
                  loading: loading,
                  hasError: hasError,
                  result: result,
                ),
                const SizedBox(height: 16),
                _startButton(loading: loading, ready: false),
              ],
            ),
    );
  }

  // 코스 변경 칩 — 같은 목적지로 코스를 다시 추천받는다.
  // 재추천 중(spinning)엔 아이콘만 반시계로 회전하고 텍스트·박스는 그대로.
  Widget _courseChangeChip(bool spinning) {
    const refreshIcon =
        Icon(TablerIcons.refresh, size: 15, color: AppColors.gray700);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: spinning ? null : _requestRoute,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          spinning
              ? RotationTransition(
                  turns: Tween<double>(begin: 0, end: -1).animate(_spinCtrl),
                  child: refreshIcon,
                )
              : refreshIcon,
          const SizedBox(width: 4),
          const Text(
            '코스 변경',
            style: TextStyle(
              fontFamily: AppType.fontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.gray700,
            ),
          ),
        ],
      ),
    );
  }

  // 카드 메타 줄: 준비되면 거리·시간·정화지역, 그 외엔 상태 문구.
  Widget _cardMeta({
    required bool ready,
    required bool loading,
    required bool hasError,
    required RouteResult? result,
  }) {
    if (ready && result != null) {
      // 거리·시간은 지도 중앙 핀 말풍선(2.4km · 38분)이 보여준다.
      // 카드 메타는 정화지역·공장지대 개수만 노출한다(스크린샷).
      // 공장지대(회피구역) 수는 서버 응답의 crossed_uqa_codes 길이를 그대로 쓴다.
      return Row(
        children: [
          _metaItem(TablerIcons.recycle, '정화지역 ${result.k3Hotspots.length}곳'),
          _metaDot(),
          _metaItem(
            TablerIcons.buildingFactory2,
            '공장지대 ${result.crossedUqaCodes.length}곳',
          ),
        ],
      );
    }
    final String text = loading
        ? '코스를 계산하고 있어요'
        : hasError
            ? '코스를 계산하지 못했어요. 도착지를 다시 선택해 주세요'
            : '버튼을 누르면 코스를 계산해요';
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppType.caption.copyWith(
        color: hasError ? AppColors.actionDanger : AppColors.gray500,
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.gray700),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            fontFamily: AppType.fontFamily,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.gray700,
          ),
        ),
      ],
    );
  }

  Widget _metaDot() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 9),
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: AppColors.gray300,
          shape: BoxShape.circle,
        ),
      );

  // 단계별 하단 버튼:
  //  - (도착지 확정) '코스 확인하기' → 경로 계산 요청
  //  - 계산 중 → '코스를 계산하고 있어요' 잠금(스피너)
  //  - 계산 완료 → '여기로 출발' → 트래킹 화면
  Widget _startButton({required bool loading, required bool ready}) {
    late final String label;
    late final IconData icon;
    late final bool enabled;
    late final VoidCallback? onTap;

    if (loading) {
      label = '코스를 계산하고 있어요';
      icon = TablerIcons.route;
      enabled = false;
      onTap = null;
    } else if (ready) {
      label = '출발';
      icon = TablerIcons.run;
      enabled = true;
      onTap = () => context.push(AppRoutes.ploggingTracking);
    } else {
      label = '코스 확인하기';
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
                color: ready
                    ? AppColors.lime
                    : (enabled ? AppColors.textOnBrand : AppColors.textDisabled),
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

// 내 위치 퍽: 검정 방향 포인터(위쪽을 가리키는 뾰족한 검정 원). 네이버 지도 느낌.
// 네이버 내장 위치 오버레이의 setIcon 으로 붙는다(기본 파란 점 대체).
class _MyLocationPuck extends StatelessWidget {
  const _MyLocationPuck();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 34,
      height: 36,
      child: CustomPaint(painter: _MyLocationPainter()),
    );
  }
}

// 검정 원 + 위쪽으로 뾰족한 포인터를 union 으로 합친 방향 표식.
// 흰 외곽선으로 지도 위에서 또렷하게 보이게 하고 검정(ink)으로 채운다.
class _MyLocationPainter extends CustomPainter {
  const _MyLocationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 아래로 뾰족한 짧은 삼각형 꼬리 + 위쪽 원. 원에 부드러운 그림자로 지도와 구분.
    final double cx = size.width / 2;
    final double r = 9; // 동그라미 크기
    final double cy = r + 4; // 원 중심(위쪽) = 13
    final double tipY = size.height - 2; // 삼각형 끝(아래, 실제 좌표점)

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final ink = Paint()
      ..color = AppColors.ink
      ..isAntiAlias = true;
    // 캡처 이미지에서도 보이는 부드러운 그림자(원 밑)
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      ..isAntiAlias = true;

    // 짧은 삼각형(폭·길이 축소)
    final tri = Path()
      ..moveTo(cx - r * 0.5, cy + r * 0.5)
      ..lineTo(cx + r * 0.5, cy + r * 0.5)
      ..lineTo(cx, tipY)
      ..close();
    final circle = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    canvas.drawCircle(Offset(cx, cy + 2), r, shadow); // 원 그림자
    canvas.drawPath(tri, ink); // 삼각형 채움
    canvas.drawPath(circle, ink); // 원 채움
    canvas.drawPath(circle, white); // 원 흰 테두리
  }

  @override
  bool shouldRepaint(covariant _MyLocationPainter oldDelegate) => false;
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
              child: Icon(TablerIcons.recycle, color: AppColors.lime, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// 지도에 박히는 도착지 핀: 흰 원 + 초록 깃발 + 아래 삼각 꼬리.
// 마커 아이콘(160×96 캔버스)으로 렌더링하며, 꼬리 끝이 캔버스 하단 중앙에 오도록
// 아래 정렬한다(마커 anchor 0.5,1.0 과 맞물려 탭 좌표를 정확히 가리킨다).
// 경로가 계산되면 핀 위에 검은 ETA 말풍선을 띄운다(레이아웃 밀림 방지용 고정 슬롯).
class _DestFlagPin extends StatelessWidget {
  final String? etaLabel; // '2.4km · 38분' (경로 결과 있을 때만)
  const _DestFlagPin({this.etaLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 96,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
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
                        color: AppColors.lime,
                        size: 23,
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
}

// 도착지·정화 거점 핀: 둥근 사각(스퀘어클) 본체 + 아래 삼각 꼬리를
// union 으로 합쳐 이음새 없이 그린다. 다크(ink) 채움 위에 라임 글리프를 얹는다(스크린샷).
class _PinShapePainter extends CustomPainter {
  const _PinShapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double bodyH = w; // 정사각형 본체(둥근 모서리)
    final double radius = w * 0.30; // 둥근 모서리 반경
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, bodyH),
          Radius.circular(radius),
        ),
      );
    // 아래 중앙 꼬리(본체와 살짝 겹쳐 이음새를 없앤다)
    final double tailHalf = w * 0.16;
    final tail = Path()
      ..moveTo(w / 2 - tailHalf, bodyH - 2)
      ..lineTo(w / 2 + tailHalf, bodyH - 2)
      ..lineTo(w / 2, h)
      ..close();
    final pin = Path.combine(PathOperation.union, body, tail);
    canvas.drawShadow(pin, Colors.black.withValues(alpha: 0.35), 4, false);
    canvas.drawPath(pin, Paint()..color = AppColors.ink..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _PinShapePainter oldDelegate) => false;
}
