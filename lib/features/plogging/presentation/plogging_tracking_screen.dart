import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/features/vision/presentation/camera_detection_screen.dart';
import 'package:repo_jdh/core/providers/plogging_provider.dart';
import 'package:repo_jdh/features/plogging/data/storage_repository.dart';
import 'package:repo_jdh/features/plogging/domain/destination_providers.dart';
import 'package:repo_jdh/features/plogging/domain/route_notifier.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/core/router/app_router.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/core/providers/tracking_provider.dart';
import 'package:repo_jdh/features/plogging/data/location_repository.dart';

class PloggingTrackingScreen extends ConsumerStatefulWidget {
  const PloggingTrackingScreen({super.key});

  @override
  ConsumerState<PloggingTrackingScreen> createState() =>
      _PloggingTrackingScreenState();
}

class _PloggingTrackingScreenState
    extends ConsumerState<PloggingTrackingScreen>
    with SingleTickerProviderStateMixin {
  // 실측값은 trackingProvider 가 보관 (경과 시간 · 이동 거리)
  Timer? _ticker;
  StreamSubscription<TrackPoint>? _pointSub;

  // 수거 상세 펼침 애니메이션 (접힌 종이 펼치듯). 열림/닫힘 모두 연속.
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    // 열림/닫힘 동일 시간·대칭 커브 → 닫을 때도 여는 속도와 같게 느껴진다.
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      reverseDuration: const Duration(milliseconds: 340),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    // 트래킹 시작 + 1초마다 경과 시간 갱신
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 이어하기로 들어온 경우엔 이미 복원돼 있으므로 새로 시작하지 않음
      if (!ref.read(trackingProvider).running) {
        ref.read(trackingProvider.notifier).start();
      }
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(trackingProvider.notifier).tick();
    });
    _maybeShowGuide();
    // GPS 좌표를 경로로 쌓으면서 거리도 함께 누적
    // (경로는 정산 화면의 활동 경로 지도에 쓰인다)
    _pointSub = LocationRepository().watchTrackPoints().listen(
      (p) {
        ref.read(trackingProvider.notifier).addTrackPoint(p);
        _updateMyLocation(p.lat, p.lng); // 내 위치 점을 새 좌표로 이동
        _checkOffRoute(p.lat, p.lng); // 경로 이탈 감지 → 자동 재추천
      },
      onError: (_) {}, // 위치 실패해도 시간은 계속 측정
    );
    // 목적지 주소를 역지오코딩해 상단 카드에 표시
    _resolveDestName();
  }

  // 목적지(도착지) 좌표 → 장소명. 상단 목적지 카드에 표시한다.
  // 도착지 좌표는 추천 경로의 끝점(polyline.last)에서 가져온다.
  // (destinationProvider 는 autoDispose 라 트래킹 화면에선 신뢰할 수 없음)
  String? _destName;
  Future<void> _resolveDestName() async {
    if (_destName != null) return;
    final dest = _destLatLng();
    if (dest == null) return;
    // 출발지·도착지와 동일한 기기 내장 geocoding (서버 불필요)
    final name = await LocationRepository().addressOf(dest.$1, dest.$2);
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _destName = name);
    }
  }

  // 추천 경로의 끝점 = 도착지 좌표
  (double, double)? _destLatLng() {
    final result = ref.read(routeNotifierProvider).valueOrNull;
    if (result == null || result.polyline.isEmpty) return null;
    final end = result.polyline.last;
    return (end[0], end[1]);
  }

  String? _selectedButton = 'camera';
  bool _isExpanded = false;

  // 수거 상세 펼침/접힘 (애니메이션 컨트롤러와 함께 구동)
  void _setExpanded(bool v) {
    if (_isExpanded == v) return;
    setState(() => _isExpanded = v);
    v ? _expandCtrl.forward() : _expandCtrl.reverse();
  }

  // 네이버 지도
  NaverMapController? _mapController;
  bool _mapCentered = false;
  static const _fallback = NLatLng(37.5074, 126.7218); // GPS 전 기본 위치
  static const _routeColor = Color(0xFF1D9E75);

  // ── 경로 이탈 자동 재추천 ──
  // 추천 경로에서 100m 이상 벗어난 상태가 30초 이상 지속되면 자동으로 재추천한다.
  static const double _offRouteMeters = 100;
  static const Duration _offRouteHold = Duration(seconds: 30);
  DateTime? _offRouteSince; // 벗어나기 시작한 시각
  bool _rerouting = false; // 재추천 요청 중(중복 트리거 방지)
  bool _showOffRouteCard = false; // 이탈 안내 카드 표시
  Timer? _offRouteCardTimer; // 4초 뒤 카드 자동 숨김

  // PLOG-04 플로깅 활동 규칙 — 사용자의 '제일 첫 플로깅'에만 자동 1회 노출.
  // 기기 로컬(SharedPreferences)로 확실히 게이트하고, Firestore 는 보조 확인.
  static const String _kFirstGuideKey = 'seen_first_plogging_guide';
  Future<void> _maybeShowGuide() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    bool seen = prefs?.getBool(_kFirstGuideKey) ?? false;
    if (!seen) {
      try {
        seen = await UserService.hasSeenPloggingGuide();
      } catch (_) {}
    }
    if (seen || !mounted) return;

    await _showRulesSheet(firstRun: true);
    await prefs?.setBool(_kFirstGuideKey, true);
    try {
      await UserService.markPloggingGuideSeen();
    } catch (_) {
      // 저장 실패해도 진행
    }
  }

  // 활동 규칙 바텀시트(첫 진입 자동 + ? 버튼 공용).
  // firstRun이면 제목 "첫 플로깅을 시작할게요" / 버튼 "시작하기", 아니면 "플로깅 활동 규칙" / "알겠어요".
  Future<void> _showRulesSheet({required bool firstRun}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PloggingRulesSheet(firstRun: firstRun),
    );
  }

  // 지도를 현재 GPS로 최초 1회 이동 + 내 위치 오버레이 갱신
  void _centerOnGps(Map<String, dynamic>? loc) {
    final c = _mapController;
    if (c == null || loc == null) return;
    final lat = (loc['latitude'] as num?)?.toDouble();
    final lon = (loc['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return;
    // 내 위치 점은 트래킹 내내 갱신(카메라 이동은 최초 1회만)
    _updateMyLocation(lat, lon);
    if (_mapCentered) return;
    _mapCentered = true;
    c.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lon), zoom: 16),
    );
  }

  // 내 위치(네이버 내장 위치 오버레이) — 도착지 설정 화면과 같은 아이콘으로 통일.
  // clearOverlays 로도 지워지지 않아 트래킹 중 계속 유지된다.
  void _updateMyLocation(double lat, double lon) {
    final c = _mapController;
    if (c == null) return;
    final overlay = c.getLocationOverlay();
    overlay.setIsVisible(true);
    overlay.setPosition(NLatLng(lat, lon));
  }

  // 현재 위치가 추천 경로에서 100m 이상 벗어났고 30초 이상 지속되면 재추천.
  void _checkOffRoute(double lat, double lon) {
    if (_rerouting) return;
    // 멈춘 동안은 이탈 판정하지 않는다
    if (ref.read(trackingProvider).paused) {
      _offRouteSince = null;
      return;
    }
    final result = ref.read(routeNotifierProvider).valueOrNull;
    if (result == null || result.polyline.length < 2) return;

    final dist = _distanceToPolyline(lat, lon, result.polyline);
    final now = DateTime.now();
    if (dist > _offRouteMeters) {
      _offRouteSince ??= now;
      if (now.difference(_offRouteSince!) >= _offRouteHold) {
        _triggerReroute(lat, lon);
      }
    } else {
      _offRouteSince = null; // 경로로 복귀 → 타이머 리셋
    }
  }

  // 사용자 컨펌 없이 현재 위치→목적지로 새 경로를 자동 요청하고 안내 카드를 띄운다.
  void _triggerReroute(double lat, double lon) {
    final dest = _destLatLng(); // 도착지 = 추천 경로 끝점
    if (dest == null) return;
    _rerouting = true;
    _offRouteSince = null;

    // 이탈 안내 카드 4초 노출
    _offRouteCardTimer?.cancel();
    setState(() => _showOffRouteCard = true);
    _offRouteCardTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showOffRouteCard = false);
    });

    ref.read(routeNotifierProvider.notifier).recommend(
          originLat: lat,
          originLon: lon,
          destLat: dest.$1,
          destLon: dest.$2,
        );
  }

  // 점(lat,lon)에서 폴리라인까지의 최단 거리(m). 짧은 거리라 평면 근사로 충분.
  double _distanceToPolyline(double lat, double lon, List<List<double>> poly) {
    double best = double.infinity;
    for (int i = 0; i < poly.length - 1; i++) {
      final d = _distToSegment(
        lat, lon, poly[i][0], poly[i][1], poly[i + 1][0], poly[i + 1][1],
      );
      if (d < best) best = d;
    }
    return best;
  }

  // 점~선분 최단거리(m). 위경도를 기준 위도로 미터 환산 후 계산.
  double _distToSegment(double plat, double plon, double alat, double alon,
      double blat, double blon) {
    final double latRef = (alat + blat) / 2 * math.pi / 180;
    final double mLon = 111320 * math.cos(latRef); // 경도 1도의 미터
    const double mLat = 110540; // 위도 1도의 미터
    final double px = plon * mLon, py = plat * mLat;
    final double ax = alon * mLon, ay = alat * mLat;
    final double bx = blon * mLon, by = blat * mLat;
    final double dx = bx - ax, dy = by - ay;
    final double len2 = dx * dx + dy * dy;
    double t = len2 == 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final double cx = ax + t * dx, cy = ay + t * dy;
    final double ex = px - cx, ey = py - cy;
    return math.sqrt(ex * ex + ey * ey);
  }

  // 추천 경로(polyline) + 정화 거점(핫스팟) 핀을 그린다.
  Future<void> _renderRoute() async {
    final c = _mapController;
    if (c == null) return;
    final result = ref.read(routeNotifierProvider).valueOrNull;
    if (result == null || result.polyline.length < 2) return;

    final overlays = <NAddableOverlay>{
      NPathOverlay(
        id: 'route',
        coords: result.polyline.map((p) => NLatLng(p[0], p[1])).toList(),
        width: 6,
        color: _routeColor,
        outlineWidth: 2,
        outlineColor: Colors.white,
      ),
    };

    // 정화 거점: 흰 핀 + 초록 재활용 아이콘 (도착지 설정 화면과 동일)
    if (result.k3Hotspots.isNotEmpty) {
      final hotspotIcon = await NOverlayImage.fromWidget(
        context: context,
        size: const Size(34, 42),
        widget: const Directionality(
          textDirection: TextDirection.ltr,
          child: _HotspotPin(),
        ),
      );
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

    c.clearOverlays();
    c.addOverlayAll(overlays);
  }

  void _handleCameraTap() {
    // 일시정지 중에는 촬영 불가 (기록 중에만 촬영하는 규칙과 동일선상)
    if (ref.read(trackingProvider).paused) {
      AppSnackBar.show(context, '일시정지 중에는 촬영할 수 없어요. 먼저 이어하기를 눌러주세요.');
      return;
    }
    if (_selectedButton == 'camera') {
      // 이미 카메라가 선택(armed)된 상태면 탭 한 번으로 바로 촬영 (선택 유지)
      _openCamera();
    } else {
      setState(() => _selectedButton = 'camera');
    }
  }

  void _handleEndTap() {
    if (_selectedButton == 'end') {
      _endPlogging(); // null로 안 만듦 → '아무것도 선택 안 함' 상태 없음
    } else {
      setState(() => _selectedButton = 'end');
    }
  }

  void _showGuide() => _showRulesSheet(firstRun: false);

  Future<void> _openCamera() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (context) => const CameraDetectionScreen()),
    );

    if (result == null) return;

    final Map<String, int> counts = Map<String, int>.from(
      result['counts'] ?? {},
    );
    final String? imagePath = result['imagePath'];
    final Map<String, dynamic>? locationData =
        result['location'] as Map<String, dynamic>?;

    if (counts.isEmpty) return;

    String? imageUrl;
    if (imagePath != null) {
      if (mounted) {
        AppSnackBar.showLoading(context, '이미지 업로드 중...');
      }
      imageUrl = await StorageRepository.uploadImage(File(imagePath));
    }

    try {
      await ref
          .read(firestoreRepositoryProvider)
          .saveDetection(counts, imageUrl: imageUrl, location: locationData);
    } catch (e) {
      debugPrint('Firestore 저장 실패: $e');
    }

    await ref.read(ploggingProvider.notifier).addCounts(counts);

    // 담은 개수만큼 '{N}개 담았어요' (잠시 후 사라지는 스낵바).
    // 담을 때마다 수거 상세를 자동으로 펼치지는 않는다.
    final int added = counts.values.fold<int>(0, (s, v) => s + v);
    if (mounted && added > 0) {
      AppSnackBar.show(context, '$added개 담았어요');
    }
  }

  // PLOG-06 뒤로가기: 나가면 기록 폐기. 계속하기(초록)를 오른쪽 주 버튼으로.
  Future<void> _confirmCancel() async {
    final ok = await AppDialog.show(
      context,
      title: '지금 나가면 기록이 사라져요',
      message: '아직 저장되지 않은 활동이에요. 나가면 처음부터 다시 시작해야 합니다.',
      cancelText: '나가기', // 왼쪽 흰 버튼 → 기록 폐기 후 홈
      confirmText: '계속하기', // 오른쪽 초록 버튼 → 화면 유지
      warn: true, // 아이콘만 경고(빨강), 계속하기 버튼은 초록 유지
    );
    if (ok == false) {
      await ref.read(ploggingProvider.notifier).reset();
      if (mounted) context.go('/home');
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pointSub?.cancel();
    _offRouteCardTimer?.cancel();
    _expandCtrl.dispose();
    super.dispose();
  }

  // PLOG-07 종료 컨펌 → 정산 화면으로
  Future<void> _endPlogging() async {
    final counts = ref.read(ploggingProvider).totalCounts;
    final total = counts.values.fold<int>(0, (s, v) => s + v);
    final ok = await AppDialog.show(
      context,
      title: '오늘의 활동을 마칠까요?',
      message: '지금까지 총 $total개를 주웠어요.',
      cancelText: '계속하기',
      confirmText: '종료',
      danger: true, // 종료는 빨강으로 통일
    );
    if (ok != true || !mounted) return;

    // 트래킹만 정지한다. 값은 stop() 이후에도 남아 정산 화면이 읽는다.
    // 활동 문서 저장은 정산 화면(_saveActivity)이 전담한다 — 여기서도 저장하면
    // 플로깅 1회에 문서가 2건 쌓인다. 정산 쪽이 경로·위치·groupId·인증샷까지
    // 함께 저장하므로 더 완전하다.
    ref.read(trackingProvider.notifier).stop();
    context.push(AppRoutes.ploggingSettlement); // 정산 화면으로
  }

  // 천 단위 콤마 (걸음 수 표시용)
  String _comma(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final ploggingState = ref.watch(ploggingProvider);
    final tracking = ref.watch(trackingProvider);

    // GPS 도착 시 지도 중심 이동, 추천 경로 갱신 시 다시 그림
    ref.listen(currentLocationProvider, (prev, next) {
      next.whenData(_centerOnGps);
    });
    ref.listen(routeNotifierProvider, (prev, next) {
      next.whenData((r) {
        if (r != null) {
          _rerouting = false; // 새 경로 도착 → 재추천 완료
          _renderRoute();
          _resolveDestName(); // 목적지 장소명 (아직 없으면)
        }
      });
    });

    if (ploggingState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totalCounts = ploggingState.totalCounts;
    final bool gpsGood = ref.watch(currentLocationProvider).hasValue;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: NaverMap(
              options: const NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: _fallback,
                  zoom: 15,
                ),
                locationButtonEnable: false,
              ),
              onMapReady: (controller) {
                _mapController = controller;
                _centerOnGps(ref.read(currentLocationProvider).valueOrNull);
                _renderRoute();
              },
            ),
          ),

          // 상단: 뒤로 + 목적지 진행 카드 + 도움말
          Positioned(
            left: 12,
            right: 12,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _glassSquareButton(
                      icon: TablerIcons.chevronLeft,
                      iconSize: 24,
                      onTap: _confirmCancel,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _destProgressCard()),
                    const SizedBox(width: 8),
                    _glassSquareButton(
                      icon: TablerIcons.helpCircle,
                      iconSize: 21,
                      onTap: _showGuide,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 경로 이탈 안내 카드 (상단 카드 아래, 4초 후 자동 사라짐)
          if (_showOffRouteCard)
            Positioned(
              left: 12,
              right: 12,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: _offRouteCard(),
                ),
              ),
            ),

          // 하단: 기록 카드 (GPS 칩 + 타이머 + 타일 + 버튼)
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildRecordCard(tracking, totalCounts, gpsGood),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 상단 목적지 카드 (깃발 + '목적지'만) ────────────────
  Widget _destProgressCard() {
    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.neutral900.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(TablerIcons.flagFilled, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text(
            '목적지',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppColors.textPrimary,
            ),
          ),
          // 역지오코딩으로 얻은 목적지 위치명
          if (_destName != null && _destName!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _destName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 경로 이탈 안내 카드 — 파란 톤, 4초 후 자동 사라짐
  Widget _offRouteCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dataSteps.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(TablerIcons.route, size: 20, color: AppColors.dataSteps),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '경로를 벗어나 새 경로로 다시 안내할게요',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassSquareButton({
    required IconData icon,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: AppColors.neutral900.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutral900.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: iconSize, color: AppColors.textPrimary),
      ),
    );
  }

  // ── 하단 기록 카드 ─────────────────────────────────────
  Widget _buildRecordCard(
    TrackingState tracking,
    Map<String, int> totalCounts,
    bool gpsGood,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 15),
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.neutral900.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '활동 시간',
                style: AppType.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                tracking.durationText,
                style: const TextStyle(
                  fontSize: 44,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: AppColors.textPrimary,
                ).tabular,
              ),
              const SizedBox(height: 18),
              _statTilesArea(tracking, totalCounts),
              const SizedBox(height: 16),
              _actionButtons(),
            ],
          ),
        ),
        // GPS 상태 칩 — 카드 상단 경계에 걸침 (원래 위치 그대로)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: _gpsChip(gpsGood, tracking.paused, tracking.pausedText),
          ),
        ),
        // 일시정지 알약 — 카드 안쪽 오른쪽에 겹쳐 얹어 박스 높이는 그대로 유지
        // 상단 여백(32)은 우측 여백(16)의 2배로 맞춘다.
        Positioned(
          top: 32,
          right: 16,
          child: _pauseChip(tracking.paused),
        ),
      ],
    );
  }

  Widget _gpsChip(bool gpsGood, bool paused, String pausedText) {
    // 멈추면 파란색(dataSteps) 톤으로 '일시정지 중 · mm:ss'
    final Color dot = paused
        ? AppColors.dataSteps
        : (gpsGood ? const Color(0xFF34AE77) : AppColors.neutral400);
    final Color border = paused
        ? AppColors.dataSteps.withValues(alpha: 0.28)
        : const Color(0xFFE0E8E3);
    final Color textColor =
        paused ? AppColors.dataSteps : AppColors.neutral700;
    final String label = paused
        ? '일시정지 중 · $pausedText'
        : (gpsGood ? 'GPS 양호 · 기록 중' : 'GPS 확인 중…');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppType.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // 일시정지 / 이어하기 칩 (GPS 칩 오른쪽) — 지름 51 (기존 34의 1.5배)
  Widget _pauseChip(bool paused) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final n = ref.read(trackingProvider.notifier);
        paused ? n.unpause() : n.pause();
      },
      // 아이콘만 있는 동그란 버튼 (GPS 칩과 겹치지 않게 컴팩트하게)
      child: Container(
        width: 51,
        height: 51,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // 기록 중: 옅은 파랑 면 / 멈춤: 파랑 채움 + 그림자
          color: paused
              ? AppColors.dataSteps
              : AppColors.dataSteps.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          boxShadow: paused
              ? [
                  BoxShadow(
                    color: AppColors.dataSteps.withValues(alpha: 0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Icon(
          paused ? TablerIcons.playerPlayFilled : TablerIcons.playerPauseFilled,
          size: 27,
          color: paused ? Colors.white : AppColors.dataSteps,
        ),
      ),
    );
  }

  // 걸음·km·수거 3타일(항상) + 아래로 접힌 종이처럼 펼쳐지는 수거 상세.
  // 열림/닫힘 모두 SizeTransition 하나로 구동해 끊김 없이 연속으로 움직인다.
  Widget _statTilesArea(TrackingState tracking, Map<String, int> totalCounts) {
    final int collected = totalCounts.values.fold<int>(0, (s, v) => s + v);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 멈춘 동안은 값이 안 쌓이므로 흐리게
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: tracking.paused ? 0.5 : 1,
          child: _threeTiles(tracking, collected),
        ),
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1.0, // 위 경계를 고정하고 아래로 펼쳐짐
          child: FadeTransition(
            opacity: _expandAnim,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _collectedPanel(totalCounts),
            ),
          ),
        ),
      ],
    );
  }

  Widget _threeTiles(TrackingState tracking, int collected) {
    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: TablerIcons.shoe,
            iconColor: AppColors.dataSteps,
            value: _comma(tracking.steps),
            unit: '걸음',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            icon: TablerIcons.route,
            iconColor: AppColors.dataDistance,
            value: tracking.distanceText,
            unit: 'km',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            icon: TablerIcons.trash,
            iconColor: AppColors.green700,
            value: '$collected',
            unit: '개',
            bg: AppColors.green100,
            trailing: RotationTransition(
              turns: Tween<double>(begin: 0, end: 0.5).animate(_expandAnim),
              child: const Icon(
                TablerIcons.chevronDown,
                size: 17,
                color: AppColors.neutral500,
              ),
            ),
            onTap: () => _setExpanded(!_isExpanded),
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    Color? bg,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 13),
            height: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.only(top: 8, left: 6, right: 6),
            decoration: BoxDecoration(
              color: bg ?? const Color(0xFFF3F8F4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        color: AppColors.textPrimary,
                      ).tabular,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 2),
                  trailing,
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(child: _tileBadge(icon, iconColor)),
          ),
        ],
      ),
    );
  }

  Widget _tileBadge(IconData icon, Color color) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          const BoxShadow(
            color: AppColors.surface,
            blurRadius: 0,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _collectedPanel(Map<String, int> totalCounts) {
    // 목업 픽토그램 그대로 (Material Symbols + 지정 색)
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.green100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _catCell(TablerIcons.bottle, const Color(0xFF5F9EE8), '플라스틱',
              totalCounts['plastic'] ?? 0),
          _catCell(TablerIcons.cup, const Color(0xFFE07B2E), '캔',
              totalCounts['can'] ?? 0),
          _catCell(TablerIcons.fileDescription, const Color(0xFF31C88B), '종이',
              totalCounts['paper'] ?? 0),
          _catCell(TablerIcons.glassFull, const Color(0xFF8E7EC4), '유리',
              totalCounts['glass'] ?? 0),
          _catCell(TablerIcons.trash, const Color(0xFF9AA3A0), '일반',
              totalCounts['trash'] ?? 0),
        ],
      ),
    );
  }

  Widget _catCell(IconData icon, Color color, String label, int count) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 3),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ).tabular,
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppType.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 카메라 / 종료 2단 버튼 (커진 쪽 1.85 : 1) ──────────
  Widget _actionButtons() {
    final bool cameraArmed = _selectedButton == 'camera';
    final bool endArmed = _selectedButton == 'end';
    final double cameraRatio = cameraArmed
        ? 1.85 / 2.85
        : (endArmed ? 1 / 2.85 : 0.5);
    return Container(
      height: 64,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F4),
        borderRadius: BorderRadius.circular(32),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          const double gap = 5;
          final double innerW = c.maxWidth;
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: cameraRatio),
            duration: const Duration(milliseconds: 600),
            curve: const Cubic(0.32, 0.72, 0, 1),
            builder: (context, r, _) {
              final double camW = (innerW - gap) * r;
              final double endW = (innerW - gap) - camW;
              return Row(
                children: [
                  SizedBox(
                    width: camW,
                    height: double.infinity,
                    child: _cameraButton(cameraArmed),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: endW,
                    height: double.infinity,
                    child: _endButton(endArmed),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _cameraButton(bool armed) {
    // armed(촬영이 큰 상태): 초록 배경 + 흰 글씨 / 종료가 커지면 반전: 흰 배경 + 초록 글씨·아이콘
    final Color bg = armed ? AppColors.actionPrimary : AppColors.surface;
    final Color fg = armed ? Colors.white : AppColors.actionPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleCameraTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(27),
          boxShadow: armed
              ? [
                  BoxShadow(
                    color: AppColors.actionPrimary.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TablerIcons.cameraFilled, size: 26, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    armed ? '촬영하기' : '촬영',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.1, // 부제와의 간격 최소화
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: fg,
                    ),
                  ),
                  if (armed)
                    Text(
                      '한 개씩 찍기',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.1,
                        color: Colors.white.withValues(alpha: 0.9),
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

  Widget _endButton(bool armed) {
    // 눌리기 전: 흰 배경 + 빨간 글씨 / 한 번 터치되면(armed) 반전: 빨간 배경 + 흰 글씨
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleEndTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: armed ? AppColors.actionDanger : AppColors.surface,
          borderRadius: BorderRadius.circular(27),
          boxShadow: armed
              ? [
                  BoxShadow(
                    color: AppColors.actionDanger.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          armed ? '종료하기' : '종료',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: armed ? Colors.white : AppColors.actionDanger,
          ),
        ),
      ),
    );
  }
}

// 플로깅 활동 규칙 바텀시트 (첫 진입 자동 + ? 버튼 공용).
// 4개 항목: 활동 범위 / 정화 거점과 위험 구간 / 쓰레기 촬영 / 활동 종료 및 포인트 획득.
class _PloggingRulesSheet extends StatelessWidget {
  final bool firstRun;
  const _PloggingRulesSheet({required this.firstRun});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 손잡이
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: AppColors.neutral300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstRun ? '첫 플로깅을 시작할게요' : '플로깅 활동 규칙',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '시작하기 전에 네 가지만 알려드릴게요.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _rule(
                    icon: TablerIcons.map,
                    title: '활동 범위',
                    lines: const [
                      _Span('인천시 안에서만 플로깅할 수 있어요. 목적지는 300km 이내로 정해주세요.'),
                    ],
                  ),
                  _rule(
                    icon: TablerIcons.recycle,
                    title: '정화 거점과 위험 구간',
                    lines: const [
                      _Span('지도의 초록 핀은 정화 거점이에요. 쓰레기가 많이 나오는 곳이라 여기를 지나면 더 많이 주울 수 있어요.'),
                      _Span('위험 구간은 공사장·차도처럼 걷기 위험한 곳이에요. 경로는 이곳을 피해서 그려집니다.'),
                    ],
                  ),
                  _rule(
                    icon: TablerIcons.cameraFilled,
                    title: '쓰레기 촬영',
                    lines: const [
                      _Span('주울 때마다 한 개씩 찍어주세요. 종류는 자동으로 나눠 담깁니다.'),
                      _Span(
                        '주운 쓰레기는 활동 중에만 촬영할 수 있으며, 종료 후에는 활동 인증샷만 촬영이 가능해요.',
                        danger: true,
                      ),
                    ],
                  ),
                  _rule(
                    icon: TablerIcons.flagFilled,
                    title: '활동 종료 및 포인트 획득',
                    lines: const [
                      _Span('활동을 종료하면 걸음·거리·수거량으로 포인트와 경험치를 얻을 수 있어요.'),
                      _Span('정산 화면에서 촬영하는 인증샷은 그룹 채팅방에 올라가며, 선택사항이에요. 나중에 내 활동에서 따로 첨부할 수도 있어요.'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 하단 버튼
          Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              16 + media.padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.actionPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  firstRun ? '시작하기' : '알겠어요',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rule({
    required IconData icon,
    required String title,
    required List<_Span> lines,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: AppColors.green700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                for (int i = 0; i < lines.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 2 : 6),
                    child: Text(
                      lines[i].text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        fontWeight: lines[i].danger
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: lines[i].danger
                            ? AppColors.actionDanger
                            : AppColors.textSecondary,
                      ),
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

// 규칙 본문 한 줄 (danger면 빨강 강조).
class _Span {
  final String text;
  final bool danger;
  const _Span(this.text, {this.danger = false});
}

// 정화 거점 핀: 흰 물방울 + 초록 재활용 아이콘 (도착지 설정 화면과 동일 도형).
class _HotspotPin extends StatelessWidget {
  const _HotspotPin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 42,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _PinShapePainter()),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 9,
            child: Center(
              child: Icon(TablerIcons.recycle,
                  color: AppColors.primary, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// 핀 도형(원 + 아래 삼각형)을 흰색으로 그린다.
class _PinShapePainter extends CustomPainter {
  const _PinShapePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = w / 2;
    final double cy = r;
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