import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
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
import 'package:repo_jdh/features/plogging/data/activity_service.dart';

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
      (p) => ref.read(trackingProvider.notifier).addTrackPoint(p),
      onError: (_) {}, // 위치 실패해도 시간은 계속 측정
    );
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

  // 지도를 현재 GPS로 최초 1회 이동
  void _centerOnGps(Map<String, dynamic>? loc) {
    if (_mapCentered) return;
    final c = _mapController;
    if (c == null || loc == null) return;
    final lat = (loc['latitude'] as num?)?.toDouble();
    final lon = (loc['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null) return;
    _mapCentered = true;
    c.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lon), zoom: 16),
    );
  }

  // 추천 경로가 있으면 polyline으로 그린다.
  // TODO: 트래킹 중 "지나온 자취(GPS 경로)"는 세션 경로 데이터가 붙으면 추가로 그리기
  void _renderRoute() {
    final c = _mapController;
    if (c == null) return;
    final result = ref.read(routeNotifierProvider).valueOrNull;
    if (result == null || result.polyline.length < 2) return;
    c.clearOverlays();
    c.addOverlayAll({
      NPathOverlay(
        id: 'route',
        coords: result.polyline.map((p) => NLatLng(p[0], p[1])).toList(),
        width: 6,
        color: _routeColor,
        outlineWidth: 2,
        outlineColor: Colors.white,
      ),
    });
  }

  void _handleCameraTap() {
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

    // 트래킹 정지 + 활동 기록 저장 (퀘스트·뱃지 판정에 사용)
    final t = ref.read(trackingProvider);
    ref.read(trackingProvider.notifier).stop();
    try {
      await ActivityService.saveCompleted(
        startedAt: t.startedAt ?? DateTime.now(),
        endedAt: DateTime.now(),
        durationSeconds: t.elapsedSeconds,
        distanceMeters: t.distanceMeters,
        trashCounts: counts,
      );
    } catch (_) {
      // 저장 실패해도 정산 화면은 보여줌
    }
    if (!mounted) return;
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
        if (r != null) _renderRoute();
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
                      icon: Icons.chevron_left,
                      iconSize: 24,
                      onTap: _confirmCancel,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _destProgressCard()),
                    const SizedBox(width: 8),
                    _glassSquareButton(
                      icon: Icons.help_outline,
                      iconSize: 21,
                      onTap: _showGuide,
                    ),
                  ],
                ),
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
          const Icon(Icons.flag, size: 18, color: AppColors.primary),
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
        // GPS 상태 칩 — 카드 상단 경계에 걸침
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(child: _gpsChip(gpsGood)),
        ),
      ],
    );
  }

  Widget _gpsChip(bool gpsGood) {
    final Color dot = gpsGood ? const Color(0xFF34AE77) : AppColors.neutral400;
    final String label = gpsGood ? 'GPS 양호 · 기록 중' : 'GPS 확인 중…';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E8E3)),
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
              color: AppColors.neutral700,
            ),
          ),
        ],
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
        _threeTiles(tracking, collected),
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
            icon: Symbols.footprint,
            iconColor: AppColors.dataSteps,
            value: _comma(tracking.steps),
            unit: '걸음',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            icon: Symbols.route,
            iconColor: AppColors.dataDistance,
            value: tracking.distanceText,
            unit: 'km',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            icon: Symbols.delete,
            iconColor: AppColors.green700,
            value: '$collected',
            unit: '개',
            bg: AppColors.green100,
            trailing: RotationTransition(
              turns: Tween<double>(begin: 0, end: 0.5).animate(_expandAnim),
              child: const Icon(
                Icons.keyboard_arrow_down,
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
      child: Icon(icon, size: 18, fill: 1, color: color),
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
          _catCell(Symbols.water_bottle, const Color(0xFF5F9EE8), '플라스틱',
              totalCounts['plastic'] ?? 0),
          _catCell(Symbols.local_drink, const Color(0xFFE07B2E), '캔',
              totalCounts['can'] ?? 0),
          _catCell(Symbols.description, const Color(0xFF31C88B), '종이',
              totalCounts['paper'] ?? 0),
          _catCell(Symbols.wine_bar, const Color(0xFF8E7EC4), '유리',
              totalCounts['glass'] ?? 0),
          _catCell(Symbols.delete, const Color(0xFF9AA3A0), '일반',
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
              Icon(icon, size: 23, fill: 1, color: color),
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
            Icon(Symbols.photo_camera, size: 26, fill: 1, color: fg),
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
                    icon: Symbols.map,
                    title: '활동 범위',
                    lines: const [
                      _Span('인천시 안에서만 플로깅할 수 있어요. 목적지는 300km 이내로 정해주세요.'),
                    ],
                  ),
                  _rule(
                    icon: Symbols.recycling,
                    title: '정화 거점과 위험 구간',
                    lines: const [
                      _Span('지도의 초록 핀은 정화 거점이에요. 쓰레기가 많이 나오는 곳이라 여기를 지나면 더 많이 주울 수 있어요.'),
                      _Span('위험 구간은 공사장·차도처럼 걷기 위험한 곳이에요. 경로는 이곳을 피해서 그려집니다.'),
                    ],
                  ),
                  _rule(
                    icon: Symbols.photo_camera,
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
                    icon: Symbols.flag,
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
            child: Icon(icon, size: 19, fill: 1, color: AppColors.green700),
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