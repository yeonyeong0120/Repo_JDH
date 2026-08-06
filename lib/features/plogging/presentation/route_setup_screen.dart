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
  static const _routeColor = Color(0xFF1D9E75);

  // 핀 마커 크기(출발: 핀만 / 도착: 핀 + 라벨). 아래는 이미지를 굽는 원본 해상도.
  static const double _pinW = 46;
  static const double _pinH = 58;
  static const double _markerW = 180;
  static const double _markerH = 58;

  // 지도에 실제로 표시되는 마커 배율. 원본 해상도는 그대로 두고 표시 크기만 줄여
  // 핀·아이콘·라벨이 통째로 균일하게 축소된다(잘림 없음). 1.0 = 원본, 작을수록 작아짐.
  static const double _markerScale = 0.8;

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

    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: _fallback,
                zoom: 14,
              ),
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
    ref.read(destinationProvider.notifier).state = (
      latLng.latitude,
      latLng.longitude,
    );
    // 새 요청 시작 전에 이전 추천 경로를 비워 stale 폴리라인이 남지 않게 한다.
    ref.read(routeNotifierProvider.notifier).reset();
    _render(); // 이 시점엔 출발·도착 마커만 그려진다(경로 없음).
    // 도착지를 설정/이동하면 경로를 자동으로 다시 추천한다.
    // TODO(추후 디바운스 검토): 짧은 시간 연속 탭 시 요청이 몰리므로 디바운스 적용 검토.
    _requestRoute();
  }

  // 현재 상태(출발지·도착지·추천 결과)를 지도에 통째로 다시 그린다.
  // clearOverlays로 비운 뒤 필요한 오버레이만 재구성해 stale 오버레이를 방지한다.
  // 도착 마커는 깃발+예상시간 라벨을 위젯 이미지로 그려 붙인다(비동기).
  Future<void> _render() async {
    final controller = _controller;
    if (controller == null) return;

    final overlays = <NAddableOverlay>{};

    // 출발지 마커 (원 안 사람 핀)
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
          size: const NSize(_pinW * _markerScale, _pinH * _markerScale),
          anchor: const NPoint(0.5, 1.0),
        ),
      );
    }

    // 도착지 마커 (깃발 핀 + "약 N분" 라벨, 결과 없으면 라벨 없음)
    final dest = ref.read(destinationProvider);
    if (dest != null) {
      final label = _destLabel(ref.read(routeNotifierProvider));
      final icon = await _buildDestMarkerIcon(label);
      if (!mounted) return;
      overlays.add(
        NMarker(
          id: 'dest',
          position: NLatLng(dest.$1, dest.$2),
          icon: icon,
          size: const NSize(_markerW * _markerScale, _markerH * _markerScale),
          // 핀 끝(좌측 핀 하단 중앙)이 좌표를 가리키도록 앵커 지정(비율이라 배율과 무관)
          anchor: const NPoint(_pinW / 2 / _markerW, 1.0),
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

    controller.clearOverlays();
    if (overlays.isNotEmpty) controller.addOverlayAll(overlays);
  }

  // 도착 마커 라벨: 경로 결과가 있으면 "약 N분", 아직 없으면(로딩/실패) 라벨 없음.
  String? _destLabel(AsyncValue<RouteResult?> routeState) {
    final result = routeState.valueOrNull;
    if (result != null && result.durationMs > 0) {
      final min = (result.durationMs / 60000).round();
      return '약 ${min < 1 ? 1 : min}분';
    }
    return null;
  }

  // 깃발+라벨 위젯을 도착 마커용 이미지로 변환한다.
  Future<NOverlayImage> _buildDestMarkerIcon(String? label) {
    return NOverlayImage.fromWidget(
      context: context,
      size: const Size(_markerW, _markerH),
      widget: _PinMarker(
        head: const Icon(Icons.flag, color: Colors.white, size: 28),
        label: label,
      ),
    );
  }

  // 출발 마커용 이미지(원 안 사람 핀).
  Future<NOverlayImage> _buildOriginMarkerIcon() {
    return NOverlayImage.fromWidget(
      context: context,
      size: const Size(_pinW, _pinH),
      widget: _PinMarker(
        head: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: AppColors.primary, size: 16),
        ),
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

  // 하단 패널: 추천 상태(AsyncValue.when)에 따른 안내 + 경로 받기 + 카메라 버튼.
  Widget _buildPanel(
    AsyncValue<Map<String, dynamic>?> originAsync,
    (double, double)? destination,
    AsyncValue<RouteResult?> routeState,
  ) {
    return Card(
      elevation: 4,
      color: Colors.white,
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('경로를 받는 중...'),
                ],
              ),
              error: (e, _) => Text(
                e.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (result) =>
                  _buildStatusText(originAsync, destination, result),
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
      data: (_) =>
          Text(destination == null ? '지도를 탭해 도착지를 선택하세요.' : '도착지가 설정되었습니다.'),
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

// 지도 마커 공통 핀: 부드러운 물방울 형태 + 가운데 아이콘(+오른쪽 라벨).
// NOverlayImage.fromWidget 으로 이미지 변환되어 마커 아이콘이 된다.
class _PinMarker extends StatelessWidget {
  final Widget head; // 핀 머리 안에 들어갈 위젯(깃발/사람 등)
  final String? label; // null이면 핀만
  const _PinMarker({required this.head, this.label});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 물방울 핀 + 머리 아이콘
          SizedBox(
            width: 46,
            height: 58,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _PinPainter(AppColors.primary)),
                ),
                // 머리 중심(대략 y=22)에 아이콘 배치
                Positioned(
                  left: 0,
                  right: 0,
                  top: 10,
                  child: Center(child: head),
                ),
              ],
            ),
          ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// 부드러운 물방울(핀) 모양을 그린다. 하단 끝점이 좌표를 가리킨다.
class _PinPainter extends CustomPainter {
  final Color color;
  const _PinPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 50;
    final sy = size.height / 60;
    final path = Path()
      ..moveTo(25 * sx, 0)
      ..cubicTo(11 * sx, 0, 0, 11 * sy, 0, 24 * sy)
      ..cubicTo(0, 40 * sy, 25 * sx, 60 * sy, 25 * sx, 60 * sy)
      ..cubicTo(25 * sx, 60 * sy, 50 * sx, 40 * sy, 50 * sx, 24 * sy)
      ..cubicTo(50 * sx, 11 * sy, 39 * sx, 0, 25 * sx, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PinPainter old) => old.color != color;
}
