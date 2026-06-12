// 트랙 B 연동 점검용 임시 화면.
// 노트북 junggu OD를 고정값으로 넣고 서버에 경로를 요청해 지도에 그린다.
// 정식 경로 화면이 아니라, 앱-서버 연동이 도는지 눈으로 확인하기 위한 용도다.
//
// 사용 전 선결: main.dart에서 dotenv.load 및 FlutterNaverMap().init(clientId: ...)이
// 완료되어 있어야 지도가 렌더링된다(가이드라인 STEP 6·7).

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/route_models.dart';
import '../domain/route_notifier.dart';

class RouteTestScreen extends ConsumerStatefulWidget {
  const RouteTestScreen({super.key});

  @override
  ConsumerState<RouteTestScreen> createState() => _RouteTestScreenState();
}

class _RouteTestScreenState extends ConsumerState<RouteTestScreen> {
  // junggu OD (노트북 OD_CANDIDATES_V2). 기대값: 통과 약 1,243m, hard case.
  static const _origin = NLatLng(37.473565, 126.621778);
  static const _dest = NLatLng(37.474748, 126.603258);

  NaverMapController? _controller;

  @override
  Widget build(BuildContext context) {
    // 추천 결과가 갱신되면 지도에 다시 그린다.
    ref.listen(routeNotifierProvider, (prev, next) {
      next.whenData((result) {
        if (result != null && _controller != null) {
          _drawRoute(_controller!, result);
        }
      });
    });

    final routeState = ref.watch(routeNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('경로 추천 테스트 (junggu)')),
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(target: _origin, zoom: 14),
            ),
            onMapReady: (controller) => _controller = controller,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildPanel(routeState),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(AsyncValue<RouteResult?> state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          loading: () => const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('경로를 받는 중...'),
            ],
          ),
          error: (e, _) => Text(e.toString()),
          data: (result) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (result != null) ...[
                  Text(
                    '통과 ${result.intersectionM}m · swap ${result.nSwaps}회 · '
                    '${result.isHardCase ? "hard case" : "정상"}',
                  ),
                  if (result.isHardCase)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '이 경로는 산업지대 약 ${result.intersectionM}m를 지납니다.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: () => ref.read(routeNotifierProvider.notifier).recommend(
                        originLat: _origin.latitude,
                        originLon: _origin.longitude,
                        destLat: _dest.latitude,
                        destLon: _dest.longitude,
                        district: 'junggu',
                      ),
                  child: Text(result == null ? '경로 받기' : '다시 받기'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 추천 경로(NPathOverlay)와 경유 핫스팟(NMarker)을 지도에 그린다.
  void _drawRoute(NaverMapController controller, RouteResult result) {
    controller.clearOverlays();

    if (result.polyline.length >= 2) {
      final coords = result.polyline.map((p) => NLatLng(p[0], p[1])).toList();
      controller.addOverlay(
        NPathOverlay(
          id: 'route',
          coords: coords,
          width: 6,
          color: const Color(0xFF1D9E75),
          outlineWidth: 2,
          outlineColor: Colors.white,
        ),
      );
    }

    final markers = <NAddableOverlay>{};
    for (final h in result.k3Hotspots) {
      markers.add(
        NMarker(
          id: 'hotspot_${h.hotspotId}',
          position: NLatLng(h.latitude, h.longitude),
          caption: NOverlayCaption(text: 'S_i ${h.sI.toStringAsFixed(1)}'),
        ),
      );
    }
    if (markers.isNotEmpty) {
      controller.addOverlayAll(markers);
    }
  }
}
