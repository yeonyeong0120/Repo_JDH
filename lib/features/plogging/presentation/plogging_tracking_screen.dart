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
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';
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

class _PloggingTrackingScreenState extends ConsumerState<PloggingTrackingScreen>
    with TickerProviderStateMixin {
  // 실측값은 trackingProvider 가 보관 (경과 시간 · 이동 거리)
  Timer? _ticker;
  StreamSubscription<TrackPoint>? _pointSub;

  // 수거 상세 펼침 애니메이션 (접힌 종이 펼치듯). 열림/닫힘 모두 연속.
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  // 하단 패널 접힘 — 접으면 경과 시간만 남긴다(핸들 드래그/탭으로 토글).
  bool _panelCollapsed = false;

  // 종료 롱프레스: 버튼 내부 채움이 0 → 1.2s 동안 차오르면 종료 확인으로 넘어간다.
  late final AnimationController _holdCtrl;

  // 채움 수면의 '바다 출렁' 위상 — 누르는 동안 계속 반복해 물결이 흐른다.
  late final AnimationController _waveCtrl;

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
    // 종료 롱프레스 채움(1.2s). 다 차면 종료 확인 다이얼로그로 이어진다.
    _holdCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _holdCtrl.reset();
          _endPlogging();
        }
      });
    // 물결 위상: 계속 반복 재생(누르지 않을 땐 화면에 안 보이므로 부담 없음).
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    // 트래킹 시작 + 1초마다 경과 시간 갱신
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 이어하기로 들어온 경우엔 이미 복원돼 있으므로 새로 시작하지 않음
      if (!ref.read(trackingProvider).running) {
        ref.read(trackingProvider.notifier).start();
      }
      _resolveDestName(); // 이미 로드된 경로가 있으면 도착지명 해석
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
  }

  // 추천 경로의 끝점 = 도착지 좌표 (경로 이탈 재추천의 목적지로 쓰인다)
  // (destinationProvider 는 autoDispose 라 트래킹 화면에선 신뢰할 수 없음)
  (double, double)? _destLatLng() {
    final result = ref.read(routeNotifierProvider).valueOrNull;
    if (result == null || result.polyline.isEmpty) return null;
    final end = result.polyline.last;
    return (end[0], end[1]);
  }

  bool _isExpanded = false;

  // 도착지 장소명(역지오코딩 결과) — 상단 도착지 표시에 쓴다. 최초 1회만 해석.
  String? _destName;

  // 추천 경로 끝점(도착지) 좌표를 장소명으로 변환해 상단 표시에 반영한다.
  Future<void> _resolveDestName() async {
    if (_destName != null) return;
    final dest = _destLatLng();
    if (dest == null) return;
    final name = await LocationRepository().addressOf(dest.$1, dest.$2);
    if (!mounted || name == null || name.isEmpty) return;
    setState(() => _destName = name);
  }

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
  // 계획 경로선(추천 경로) — 연한 회색. 도착지 설정 화면과 톤을 맞춘다.
  static const _routeColor = AppColors.gray300;
  // 지나온(걸은) 경로선 — 차콜(ink). 계획 라인 위에 얹어 '걸은 부분'을 보여준다.
  static const _traveledColor = AppColors.ink;

  // 내 위치 오버레이 아이콘을 최초 1회만 스타일링하기 위한 가드(매 GPS 틱마다
  // 아이콘을 다시 만들지 않도록 한다).
  bool _locStyled = false;
  // 정화 거점 핀 아이콘 캐시 — 매 렌더마다 위젯 이미지를 새로 굽지 않는다.
  NOverlayImage? _hotspotIcon;
  // 도착지 핀 아이콘 캐시.
  NOverlayImage? _destIcon;

  // ── 경로 이탈 자동 재추천 ──
  // 추천 경로에서 100m 이상 벗어난 상태가 30초 이상 지속되면 자동으로 재추천한다.
  static const double _offRouteMeters = 100;
  static const Duration _offRouteHold = Duration(seconds: 30);
  DateTime? _offRouteSince; // 벗어나기 시작한 시각
  bool _rerouting = false; // 재추천 요청 중(중복 트리거 방지)
  bool _showOffRouteCard = false; // 이탈 안내 카드 표시
  Timer? _offRouteCardTimer; // 4초 뒤 카드 자동 숨김

  // PLOG-04 플로깅 활동 규칙 — 매 세션 시작 시 자동 노출.
  // '봤는지' 여부는 이제 표시를 막는 게 아니라, 첫 세션인지에 따라 문구(firstRun)만 바꾸는 데 쓴다.
  static const String _kFirstGuideKey = 'seen_first_plogging_guide';
  Future<void> _maybeShowGuide() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    bool seenBefore = prefs?.getBool(_kFirstGuideKey) ?? false;
    if (!seenBefore) {
      try {
        seenBefore = await UserService.hasSeenPloggingGuide();
      } catch (_) {}
    }
    if (!mounted) return;

    await _showRulesSheet(firstRun: !seenBefore);
    if (!seenBefore) {
      await prefs?.setBool(_kFirstGuideKey, true);
      try {
        await UserService.markPloggingGuideSeen();
      } catch (_) {
        // 저장 실패해도 진행
      }
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
    // 네이버 기본 파란 점 대신, 도착지 설정 화면과 같은 검정 방향 퍽으로 최초 1회만 교체.
    if (!_locStyled) {
      _locStyled = true;
      _styleMyLocationOverlay(overlay);
    }
    // 지나온 경로(차콜)를 새 좌표까지 갱신한다.
    _renderRoute();
  }

  // 내 위치 오버레이를 네이버 기본 파란 점에서 검정 방향 포인터로 바꾼다.
  // 도착지 설정 화면(route_setup_screen.dart)과 완전히 동일한 처리다.
  // getLocationOverlay / setIcon / setIconSize / setAnchor / setCircleColor /
  // setCircleRadius 는 flutter_naver_map 의 NLocationOverlay 실제 API다.
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

  // 계획 경로(회색) + 지나온 경로(차콜) + 정화 거점(핫스팟) 핀을 그린다.
  // 계획 라인은 연회색으로 깔고, 내가 걸은 부분(트래킹 누적 좌표)을 그 위에
  // 차콜(ink)로 얹어 '걸은 부분'이 또렷하게 드러나도록 한다.
  Future<void> _renderRoute() async {
    final c = _mapController;
    if (c == null) return;
    final result = ref.read(routeNotifierProvider).valueOrNull;
    final tracking = ref.read(trackingProvider);

    final overlays = <NAddableOverlay>{};

    // 1) 계획(추천) 경로 — 연회색 라인. 아래에 깐다.
    if (result != null && result.polyline.length >= 2) {
      overlays.add(
        NPathOverlay(
          id: 'route',
          coords: result.polyline.map((p) => NLatLng(p[0], p[1])).toList(),
          width: 7,
          color: _routeColor,
          outlineWidth: 0,
        ),
      );
    }

    // 2) 지나온(걸은) 경로 — 차콜(ink) 라인. 계획 위에 얹는다.
    final path = tracking.path;
    if (path.length >= 2) {
      overlays.add(
        NPathOverlay(
          id: 'traveled',
          coords: path.map((p) => NLatLng(p.lat, p.lng)).toList(),
          width: 7,
          color: _traveledColor,
          outlineWidth: 0,
        ),
      );
    }

    // 도착지 핀 — 경로 끝점. 경로가 짧거나 출발지와 가까워도 항상 도착지를 표시한다.
    if (result != null && result.polyline.isNotEmpty) {
      final end = result.polyline.last;
      final destIcon = _destIcon ??= await NOverlayImage.fromWidget(
        context: context,
        size: const Size(34, 42),
        widget: const Directionality(
          textDirection: TextDirection.ltr,
          child: _DestFlagPin(),
        ),
      );
      if (!mounted) return;
      overlays.add(
        NMarker(
          id: 'dest',
          position: NLatLng(end[0], end[1]),
          icon: destIcon,
          size: const NSize(34, 42),
          anchor: const NPoint(0.5, 1.0),
        ),
      );
    }

    // 3) 정화 거점: 흰 핀 + 재활용 아이콘 (도착지 설정 화면과 동일). 아이콘은 1회만 굽는다.
    if (result != null && result.k3Hotspots.isNotEmpty) {
      final icon = _hotspotIcon ??= await NOverlayImage.fromWidget(
        context: context,
        size: const Size(34, 42),
        widget: const Directionality(
          textDirection: TextDirection.ltr,
          child: _HotspotPin(),
        ),
      );
      for (int i = 0; i < result.k3Hotspots.length; i++) {
        final h = result.k3Hotspots[i];
        overlays.add(
          NMarker(
            id: 'hotspot_$i',
            position: NLatLng(h.latitude, h.longitude),
            icon: icon,
            size: const NSize(34, 42),
            anchor: const NPoint(0.5, 1.0),
          ),
        );
      }
    }

    if (!mounted) return;
    // 내 위치(getLocationOverlay)는 clearOverlays 로 지워지지 않아 그대로 유지된다.
    c.clearOverlays();
    if (overlays.isNotEmpty) c.addOverlayAll(overlays);
  }

  // 촬영 버튼 탭 — 기록 중일 때만 촬영 화면으로.
  void _handleCameraTap() {
    // 일시정지 중에는 촬영 불가 (기록 중에만 촬영하는 규칙과 동일선상)
    if (ref.read(trackingProvider).paused) {
      AppSnackBar.show(context, '일시정지 중에는 촬영할 수 없어요. 먼저 이어하기를 눌러주세요.');
      return;
    }
    _openCamera();
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
      ref.read(trackingProvider.notifier).reset(); // 세션 폐기(이어하기 안 묻게)
      // 홈이 아니라 목적지 설정 화면으로 이동한다.
      if (mounted) context.go(AppRoutes.ploggingRoute);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pointSub?.cancel();
    _offRouteCardTimer?.cancel();
    _expandCtrl.dispose();
    _holdCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  // PLOG-07 종료 컨펌 → 정산 화면으로
  Future<void> _endPlogging() async {
    final counts = ref.read(ploggingProvider).totalCounts;
    final t = ref.read(trackingProvider);
    final weight = ActivityMetrics.weightLabel(counts);
    final ok = await AppDialog.show(
      context,
      title: '플로깅을 마치시겠어요?',
      message: '${t.distanceText}km · 수거 $weight이 기록되고\n포인트가 적립돼요',
      cancelText: '계속 뛰기',
      confirmText: '마치기',
      icon: TablerIcons.flagFilled, // 라임 스퀘어클 + 검정 깃발
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
          _resolveDestName(); // 새 경로 끝점 기준 도착지명 해석
        }
      });
    });

    if (ploggingState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.lime)),
      );
    }

    final totalCounts = ploggingState.totalCounts;

    // 다크 배경 위: 상단 라이브 지도(라임 경로) + 하단 다크 통계/조작 패널.
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // 라이브 네이버 지도 (전체 배경). 하단 패널이 아래쪽을 덮는다.
          Positioned.fill(
            child: NaverMap(
              options: const NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: _fallback,
                  zoom: 15,
                ),
                locationButtonEnable: false,
                // 하단 다크 패널 높이만큼 아래쪽 여백을 줘 카메라가 내 위치를
                // 화면 위쪽에 잡도록 한다(패널에 가려지지 않게).
                contentPadding: EdgeInsets.only(bottom: 320),
              ),
              onMapReady: (controller) {
                _mapController = controller;
                _centerOnGps(ref.read(currentLocationProvider).valueOrNull);
                _renderRoute();
              },
            ),
          ),

          // 상단 헤더: 화면 가로 끝까지 채우는 하나의 흰색 상단바.
          //   [뒤로] … [중앙: 도착지명] … [도움말]
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 뒤로가기 (지도 위 잉크 글리프)
                    _topButton(
                        TablerIcons.chevronLeft, 27, _confirmCancel),
                    // 가운데 도착지 — 목적지 설정 화면처럼 하얀 박스로 감쌈.
                    // 44 높이 안에서 세로 중앙 정렬해 뒤로가기/재설정 버튼과 줄을 맞춘다.
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: _destLatLng() != null
                              ? _destPill()
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    // 도움말(정보) — 상단 오른쪽. 위치 재설정은 하단바 위로 이동.
                    _topButton(TablerIcons.infoCircle, 24, _showGuide),
                  ],
                ),
              ),
            ),
          ),

          // 경로 이탈 안내 카드 (상단 버튼 아래, 4초 후 자동 사라짐)
          if (_showOffRouteCard)
            Positioned(
              left: 20,
              right: 20,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: _offRouteCard(),
                ),
              ),
            ),

          // 하단 다크 패널 + 그 오른쪽 위에 위치 재설정 버튼(목적지 설정 화면과 동일)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 하단바 바로 위 줄: (접혔을 때) 가운데 카메라 + 오른쪽 위치 재설정.
                // 재설정 아이콘이 하단바에 바짝 붙도록 아래 정렬 + 여백 최소화.
                Padding(
                  padding: const EdgeInsets.only(left: 18, right: 18, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SizedBox(width: 46), // 오른쪽 재설정과 대칭
                      Expanded(
                        child: Center(
                          // 접혔을 때 카메라는 하단바에서 조금 더 띄운다(너무 붙지 않게).
                          child: _panelCollapsed
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _captureButton(),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      _recenterButton(),
                    ],
                  ),
                ),
                _bottomPanel(tracking, totalCounts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 상단 헤더 아이콘 (뒤로 · 도움말) ──────────────────
  // 규칙 A: 컨테이너(캡슐·테두리·그림자) 없이 글리프만. 44x44 탭 영역.
  // 상단은 밝은 지도 위라 흰색이 안 보여서 검정(ink)으로 그린다.
  Widget _topButton(IconData icon, double iconSize, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Icon(icon, size: iconSize, color: AppColors.ink),
        ),
      ),
    );
  }

  // 상단 헤더 중앙 도착지 표시 — 깃발 아이콘 + "도착지 · {장소명}".
  // 장소명 미해석 시 "도착지"만 표시. 별도 pill 없이 헤더 위에 바로 얹는다.
  Widget _destTitle() {
    final String name = _destName ?? '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(TablerIcons.flagFilled, size: 15, color: AppColors.ink),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            name.isEmpty ? '도착지' : '도착지 · $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  // 도착지 — 목적지 설정 화면처럼 하얀 라운드 박스로 감싼 표식(가운데).
  Widget _destPill() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: _destTitle(),
      ),
    );
  }

  // 위치 재설정 — 목적지 설정 화면과 동일한 흰 바탕 원형 버튼(기본 아이콘).
  Widget _recenterButton() {
    // 하얀 바탕 없이 아이콘만(지도 위 잉크 글리프).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _recenterToGps,
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
    );
  }

  // 현재 위치로 지도 카메라 복귀 (버튼용 — 최초 1회 제한 없이 항상 이동)
  void _recenterToGps() {
    final c = _mapController;
    final loc = ref.read(currentLocationProvider).valueOrNull;
    if (c == null || loc == null) return;
    final lat = (loc['latitude'] as num?)?.toDouble();
    final lon = (loc['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return;
    _updateMyLocation(lat, lon);
    c.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lon), zoom: 16),
    );
  }

  // 경로 이탈 안내 카드 — 다크 칩 톤, 4초 후 자동 사라짐
  Widget _offRouteCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(TablerIcons.route, size: 20, color: AppColors.lime),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '경로를 벗어나 새 경로로 다시 안내할게요',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 하단 다크 패널 ─────────────────────────────────────
  Widget _bottomPanel(TrackingState tracking, Map<String, int> totalCounts) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33191E24),
            blurRadius: 40,
            offset: Offset(0, -14),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 드래그 영역 = 핸들 + '경과 시간' + 타이머 전체(같은 라인 폭 전부).
              // 어디를 스와이프해도 접히고 펴진다. 아래 조작부(버튼)는 제외.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _panelCollapsed = !_panelCollapsed),
                // 아주 조금만 스와이프해도 접고/펴지도록 임계값을 낮춘다.
                onVerticalDragUpdate: (d) {
                  final dy = d.primaryDelta ?? 0;
                  if (dy > 2 && !_panelCollapsed) {
                    setState(() => _panelCollapsed = true);
                  } else if (dy < -2 && _panelCollapsed) {
                    setState(() => _panelCollapsed = false);
                  }
                },
                onVerticalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v > 30) {
                    setState(() => _panelCollapsed = true);
                  } else if (v < -30) {
                    setState(() => _panelCollapsed = false);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 핸들 선
                    Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.only(top: 8, bottom: 14),
                      child: Container(
                        width: 56,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.gray500,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // 경과 시간 (접혀도 항상 보인다)
                    Text(
                      '경과 시간',
                      style: AppType.overline.copyWith(
                        letterSpacing: 0.5,
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: tracking.paused ? 0.5 : 1,
                      child: Text(
                        tracking.durationText,
                        style: const TextStyle(
                          fontSize: 44,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                          color: Colors.white,
                        ).tabular,
                      ),
                    ),
                  ],
                ),
              ),
              // 접히면 통계·조작부는 부드럽게 사라진다
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 240),
                sizeCurve: Curves.easeInOut,
                crossFadeState: _panelCollapsed
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    _statCards(tracking, totalCounts),
                    const SizedBox(height: 14),
                    _controlBar(tracking),
                    const SizedBox(height: 8),
                    Text(
                      '전원 버튼 길게 눌러 플로깅 종료',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 거리 / 걸음 / 수거(펼침) 3카드 + 아래로 펼쳐지는 수거 상세(5색 칩).
  Widget _statCards(TrackingState tracking, Map<String, int> totalCounts) {
    final int collected = totalCounts.values.fold<int>(0, (s, v) => s + v);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: tracking.paused ? 0.5 : 1,
          child: Row(
            children: [
              Expanded(
                child: _statCard(
                  label: '거리',
                  value: tracking.distanceText,
                  unit: 'km',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  label: '걸음',
                  value: _comma(tracking.steps),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  label: '수거',
                  value: '$collected',
                  unit: '개',
                  valueColor: AppColors.lime,
                  expandable: true,
                  onTap: () => _setExpanded(!_isExpanded),
                ),
              ),
            ],
          ),
        ),
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1.0, // 위 경계를 고정하고 아래로 펼쳐짐
          child: FadeTransition(
            opacity: _expandAnim,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _haulPanel(totalCounts),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    String? unit,
    Color valueColor = Colors.white,
    bool expandable = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
                if (expandable) ...[
                  const SizedBox(width: 4),
                  RotationTransition(
                    turns:
                        Tween<double>(begin: 0, end: 0.5).animate(_expandAnim),
                    child: const Icon(
                      TablerIcons.chevronDown,
                      size: 14,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: valueColor,
                    ).tabular,
                  ),
                  if (unit != null)
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: valueColor,
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

  // 인식한 쓰레기 칩 — 5색 고정. 인식된 종류는 분류색, 미인식은 darkChip.
  Widget _haulPanel(Map<String, int> totalCounts) {
    // 박스를 칩 내용만큼만 감싸고(왼쪽 빈 여백 제거), 수거 카드 아래(오른쪽)로 붙인다.
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final cat in _haulCats)
              _haulChip(
                cat.$1,
                cat.$2,
                cat.$3,
                totalCounts[cat.$4] ?? 0,
              ),
          ],
        ),
      ),
    );
  }

  // (라벨, 아이콘, 분류색, ploggingProvider 키)
  static const List<(String, IconData, Color, String)> _haulCats = [
    ('플라스틱', TablerIcons.bottle, AppColors.dataPlastic, 'plastic'),
    ('캔', TablerIcons.cup, AppColors.dataCan, 'can'),
    ('종이', TablerIcons.fileDescription, AppColors.dataPaper, 'paper'),
    ('유리', TablerIcons.glassFull, AppColors.dataGlass, 'glass'),
    ('일반', TablerIcons.trash, AppColors.dataGeneral, 'trash'),
  ];

  Widget _haulChip(String label, IconData icon, Color color, int count) {
    final bool on = count > 0;
    final Color bg = on ? color : AppColors.darkChip;
    final Color fg = on ? Colors.white : AppColors.gray400;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            '$label $count',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: on ? FontWeight.w700 : FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ── 일시정지 / 촬영 / 종료(롱프레스) 조작 바 ──────────────
  Widget _controlBar(TrackingState tracking) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pauseButton(tracking.paused),
        const SizedBox(width: 20),
        _captureButton(),
        const SizedBox(width: 20),
        _endHoldButton(),
      ],
    );
  }

  Widget _pauseButton(bool paused) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final n = ref.read(trackingProvider.notifier);
        paused ? n.unpause() : n.pause();
      },
      child: Container(
        width: 58,
        height: 58,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          paused ? TablerIcons.playerPlayFilled : TablerIcons.playerPauseFilled,
          size: 26,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _captureButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleCameraTap,
      child: Container(
        width: 74,
        height: 74,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.lime,
          shape: BoxShape.circle,
          // 두 겹(라임 원 + 어두운 라임 링) — 별도 border 없이 링 하나만.
          boxShadow: [
            BoxShadow(
              color: Color(0xFFB1C84E),
              spreadRadius: 4,
              blurRadius: 0,
            ),
          ],
        ),
        child: const Icon(TablerIcons.cameraFilled, size: 30, color: AppColors.ink),
      ),
    );
  }

  // 종료 롱프레스: 누르는 동안 안쪽이 아래→위로 차오름(1.2s), 완료 시 종료 확인.
  void _cancelHold() {
    if (_holdCtrl.status != AnimationStatus.completed && _holdCtrl.value > 0) {
      _holdCtrl.reverse();
    }
  }

  Widget _endHoldButton() {
    const double d = 58; // 버튼 지름
    const double iconSz = 26;
    const Color red = Color(0xFFFF6B5A);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _holdCtrl.forward(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: _cancelHold,
      child: SizedBox(
        width: d,
        height: d,
        child: ClipOval(
          child: AnimatedBuilder(
            // 채움 높이(_holdCtrl) + 물결 위상(_waveCtrl) 둘 다에 반응.
            animation: Listenable.merge([_holdCtrl, _waveCtrl]),
            builder: (context, _) {
              final double level = _holdCtrl.value; // 0~1 (떼면 다시 0으로 내려감)
              final double phase = _waveCtrl.value * 2 * math.pi;
              return Stack(
                children: [
                  // 바탕: 어두운 원 + 빨간 전원 아이콘(수면 위 부분)
                  const Positioned.fill(
                    child: ColoredBox(color: Color(0xFF3A2A28)),
                  ),
                  const Center(
                    child: Icon(TablerIcons.power, size: iconSz, color: red),
                  ),
                  // 아래→위로 차오르는 빨간 물결(바다처럼 출렁)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WaveFillPainter(
                        level: level,
                        phase: phase,
                        color: red,
                      ),
                    ),
                  ),
                  // 물결에 덮인 부분만 아이콘을 하양으로 — 같은 물결 경로로 클립.
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _WaveClipper(level: level, phase: phase),
                      child: const Center(
                        child: Icon(
                          TablerIcons.power,
                          size: iconSz,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
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
                    firstRun ? '첫 플로깅을 시작할게요' : '플로깅 이렇게 해요',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _rule(
                    icon: TablerIcons.route,
                    title: '코스를 따라 걸어요',
                    lines: const [
                      _Span('추천 코스나 직접 정한 목적지까지, 정화지역을 지나며 이동해요'),
                    ],
                  ),
                  _rule(
                    icon: TablerIcons.camera,
                    lime: true, // 촬영만 라임 강조
                    title: '주웠으면 바로 촬영',
                    lines: const [
                      _Span('갤러리 업로드는 안 되고 활동 중 촬영만 인정돼요. 종류는 자동으로 인식돼요'),
                    ],
                  ),
                  _rule(
                    icon: TablerIcons.scale,
                    title: '무게는 자동 계산',
                    lines: const [
                      _Span('인식된 품목 수로 수거량이 쌓여요. 화면의 수거 카드를 눌러 항목별로 확인할 수 있어요'),
                    ],
                  ),
                  _rule(
                    icon: TablerIcons.power,
                    title: '도착하면 종료',
                    lines: const [
                      _Span('화면 오른쪽 전원 버튼을 꾹 누르면 플로깅이 끝나고 기록·포인트가 저장돼요. 중간에 나가면 저장되지 않아요'),
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
                  firstRun ? '시작하기' : '확인했어요',
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
    bool lime = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아이콘 타일 — 라운드 스퀘어. 촬영만 라임, 나머지는 연회색.
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lime ? AppColors.lime : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: AppColors.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                for (int i = 0; i < lines.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                    child: Text(
                      lines[i].text,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
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

// 도착지 핀: 흰 핀(원+꼬리) + 라임 깃발. 도착지 설정 화면과 동일 도형.
class _DestFlagPin extends StatelessWidget {
  const _DestFlagPin();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 42,
      child: Stack(
        children: [
          // 검정 바탕 핀 + 라임 깃발
          const Positioned.fill(
            child: CustomPaint(painter: _PinShapePainter(color: AppColors.ink)),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 8,
            child: Center(
              child: Icon(TablerIcons.flagFilled,
                  color: AppColors.lime, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

// 핀 도형(원 + 아래 삼각형)을 지정 색으로 그린다(기본 흰색).
class _PinShapePainter extends CustomPainter {
  final Color color;
  const _PinShapePainter({this.color = Colors.white});

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
    canvas.drawPath(pin, Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _PinShapePainter old) => old.color != color;
}

// 내 위치 퍽: 검정 방향 포인터(위쪽을 가리키는 뾰족한 검정 원). 네이버 지도 느낌.
// 도착지 설정 화면(route_setup_screen.dart)과 동일한 도형으로 통일한다.
// 네이버 내장 위치 오버레이의 setIcon 으로 붙는다(기본 파란 점 대체).
// 목적지 설정 화면과 완전히 동일한 내 위치 퍽(원 + 짧은 아래 삼각형 + 그림자).
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

class _MyLocationPainter extends CustomPainter {
  const _MyLocationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double r = 9;
    final double cy = r + 4; // 13
    final double tipY = size.height - 2;

    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final ink = Paint()
      ..color = AppColors.ink
      ..isAntiAlias = true;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      ..isAntiAlias = true;

    final tri = Path()
      ..moveTo(cx - r * 0.5, cy + r * 0.5)
      ..lineTo(cx + r * 0.5, cy + r * 0.5)
      ..lineTo(cx, tipY)
      ..close();
    final circle = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    canvas.drawCircle(Offset(cx, cy + 2), r, shadow);
    canvas.drawPath(tri, ink);
    canvas.drawPath(circle, ink);
    canvas.drawPath(circle, white);
  }

  @override
  bool shouldRepaint(covariant _MyLocationPainter oldDelegate) => false;
}

// ── 종료 버튼 채움 물결(바다 출렁) ─────────────────────────
// 수면 아래 영역을 하나의 Path 로 만든다. level(0~1)은 채움 높이,
// phase 는 위상. 페인터와 클리퍼가 같은 경로를 써서 '덮인 부분만 하양'을 만든다.
Path _waveFillPath(Size size, double level, double phase) {
  final double w = size.width;
  final double h = size.height;
  final double baseY = h * (1 - level.clamp(0.0, 1.0));
  // 버튼 폭에 파도 한 개가 지나가는 하나의 큰 물결. 다 차오를수록
  // 진폭을 줄여 매끈하게 마무리한다(바다가 잔잔해지듯).
  final double amp = 4.5 * (1 - level).clamp(0.0, 1.0) + 0.5;
  final path = Path()..moveTo(0, baseY);
  const int steps = 16;
  for (int i = 0; i <= steps; i++) {
    final double t = i / steps;
    final double x = w * t;
    // 폭당 한 주기(frequency 1.0)의 저주파 사인 — 하나의 큰 물결.
    final double y = baseY + amp * math.sin(t * 2 * math.pi + phase);
    path.lineTo(x, y);
  }
  path
    ..lineTo(w, h)
    ..lineTo(0, h)
    ..close();
  return path;
}

class _WaveFillPainter extends CustomPainter {
  final double level;
  final double phase;
  final Color color;
  const _WaveFillPainter({
    required this.level,
    required this.phase,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (level <= 0) return;
    canvas.drawPath(
      _waveFillPath(size, level, phase),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveFillPainter old) =>
      old.level != level || old.phase != phase || old.color != color;
}

class _WaveClipper extends CustomClipper<Path> {
  final double level;
  final double phase;
  const _WaveClipper({required this.level, required this.phase});

  @override
  Path getClip(Size size) => _waveFillPath(size, level, phase);

  @override
  bool shouldReclip(covariant _WaveClipper old) =>
      old.level != level || old.phase != phase;
}
