// 플로깅 세션 화면(실제 흐름).
// 1) 현재 GPS 위치를 출발지로 지도 중심에 둔다.
// 2) 지도를 탭하면 그 지점을 도착지로 마커 표시한다(다시 탭하면 갱신).
// 3) "경로 받기"를 누르면 출발=현재GPS, 도착=탭지점으로 경로를 추천받는다.
// 4) 추천 결과의 polyline은 NPathOverlay, k3 핫스팟은 NMarker로 그린다. hard case면 안내.
// 5) 하단 카메라 버튼으로 기존 YOLO 카메라 화면으로 이동한다.
//
// 가이드라인 준수: setState 미사용(Riverpod 상태로 관리), AsyncValue.when, withValues(alpha:),
//                 package: 절대경로 import, 한국어 주석.
//
// 선결: main.dart에서 dotenv.load 및 FlutterNaverMap().init(clientId: ...) 완료 상태여야
//       지도가 렌더링된다. 경로 추천은 백엔드 /route/recommend 배포 시 실제 응답한다.

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:repo_jdh/core/router/app_router.dart';
import 'package:repo_jdh/features/plogging/domain/plogging_session_providers.dart';
import 'package:repo_jdh/features/plogging/domain/route_models.dart';
import 'package:repo_jdh/features/plogging/domain/route_notifier.dart';

class PloggingSessionScreen extends ConsumerStatefulWidget {
  const PloggingSessionScreen({super.key});

  @override
  ConsumerState<PloggingSessionScreen> createState() =>
      _PloggingSessionScreenState();
}

class _PloggingSessionScreenState extends ConsumerState<PloggingSessionScreen> {
  // GPS를 아직 못 받았을 때 보여줄 기본 카메라 위치(인천 부평구청 부근).
  static const _fallback = NLatLng(37.5074, 126.7218);

  // 경로 색상.
  static const _routeColor = Color(0xFF1D9E75);

  NaverMapController? _controller;
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

    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(target: _fallback, zoom: 14),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _controller = controller;
              // 지도가 준비된 시점에 이미 GPS를 받았다면 즉시 이동한다.
              _centerOnOrigin(originAsync.valueOrNull);
              _render();
            },
            onMapTapped: _onMapTapped,
          ),
          // 상단 뒤로가기
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topLeft,
                child: _circleButton(
                  icon: Icons.arrow_back_ios_new,
                  onPressed: () => context.pop(),
                ),
              ),
            ),
          ),
          // 하단 패널(안내 + 경로 받기 + 카메라)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildPanel(originAsync, destination, routeState),
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

  // 지도 탭 → 도착지 설정/갱신 → 경로 자동 추천.
  void _onMapTapped(NPoint point, NLatLng latLng) {
    ref.read(destinationProvider.notifier).state =
        (latLng.latitude, latLng.longitude);
    // 새 요청 시작 전에 이전 추천 경로를 비워 stale 폴리라인이 남지 않게 한다.
    ref.read(routeNotifierProvider.notifier).reset();
    _render(); // 이 시점엔 출발·도착 마커만 그려진다(경로 없음).
    // 도착지를 설정/이동하면 경로를 자동으로 다시 추천한다.
    // TODO(추후 디바운스 검토): 짧은 시간 연속 탭 시 요청이 몰리므로 디바운스 적용 검토.
    _requestRoute();
  }

  // 현재 상태(출발지·도착지·추천 결과)를 지도에 통째로 다시 그린다.
  // clearOverlays로 비운 뒤 필요한 오버레이만 재구성해 stale 오버레이를 방지한다.
  void _render() {
    final controller = _controller;
    if (controller == null) return;

    controller.clearOverlays();

    final overlays = <NAddableOverlay>{};

    // 출발지 마커
    final origin = ref.read(currentLocationProvider).valueOrNull;
    final originLat = (origin?['latitude'] as num?)?.toDouble();
    final originLon = (origin?['longitude'] as num?)?.toDouble();
    if (originLat != null && originLon != null) {
      overlays.add(
        NMarker(
          id: 'origin',
          position: NLatLng(originLat, originLon),
          caption: const NOverlayCaption(text: '출발'),
        ),
      );
    }

    // 도착지 마커
    final dest = ref.read(destinationProvider);
    if (dest != null) {
      overlays.add(
        NMarker(
          id: 'dest',
          position: NLatLng(dest.$1, dest.$2),
          caption: const NOverlayCaption(text: '도착'),
        ),
      );
    }

    // 추천 경로 + 핫스팟
    final result = ref.read(routeNotifierProvider).valueOrNull;
    if (result != null) {
      if (result.polyline.length >= 2) {
        overlays.add(
          NPathOverlay(
            id: 'route',
            coords: result.polyline.map((p) => NLatLng(p[0], p[1])).toList(),
            width: 6,
            color: _routeColor,
            outlineWidth: 2,
            outlineColor: Colors.white,
          ),
        );
      }
      // k3 핫스팟은 지도에 마커로 표시하지 않는다(경로 폴리라인만 노출).
    }

    if (overlays.isNotEmpty) controller.addOverlayAll(overlays);
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

    ref.read(routeNotifierProvider.notifier).recommend(
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

  // 하단 패널: 추천 상태(AsyncValue.when)에 따른 안내 + 경로 받기 + 카메라 버튼.
  Widget _buildPanel(
    AsyncValue<Map<String, dynamic>?> originAsync,
    (double, double)? destination,
    AsyncValue<RouteResult?> routeState,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 안내 문구 / 추천 결과
            routeState.when(
              loading: () => const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('경로를 받는 중...'),
                ],
              ),
              error: (e, _) => Text(
                e.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (result) => _buildStatusText(originAsync, destination, result),
            ),
            const SizedBox(height: 12),
            // 플로깅 시작: 도착지가 설정돼야 활성화한다(준비 → 시작 흐름).
            // 도착지·경로는 Riverpod provider로 공유되므로 추적 화면이 동일 상태를 watch한다.
            // TODO(정식 출시): '경로 추천 성공 시에만 시작 가능'으로 조이기 검토.
            FilledButton.icon(
              onPressed: destination == null
                  ? null
                  : () => context.push(AppRoutes.ploggingTracking),
              icon: const Icon(Icons.directions_run),
              label: const Text('플로깅 시작'),
            ),
          ],
        ),
      ),
    );
  }

  // 추천 전/후 안내 문구.
  Widget _buildStatusText(
    AsyncValue<Map<String, dynamic>?> originAsync,
    (double, double)? destination,
    RouteResult? result,
  ) {
    // 추천 결과가 있으면 통과 정보 + hard case 안내.
    if (result != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '거리 ${result.distanceM}m · 통과 ${result.intersectionM}m · '
            '${result.isHardCase ? "hard case" : "정상"}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (result.isHardCase)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '산업지대 약 ${result.intersectionM}m 통과',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
    }

    // 추천 전: GPS·도착지 선택 안내.
    return originAsync.when(
      loading: () => const Text('현재 위치를 확인하는 중...'),
      error: (_, __) => const Text('현재 위치를 가져오지 못했습니다. 위치 권한을 확인해 주세요.'),
      data: (_) => Text(
        destination == null ? '지도를 탭해 도착지를 선택하세요.' : '도착지가 설정되었습니다.',
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: Icon(icon),
        color: Colors.black87,
        onPressed: onPressed,
      ),
    );
  }
}
