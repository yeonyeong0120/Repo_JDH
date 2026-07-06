import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/vision/presentation/camera_screen.dart';
import 'package:repo_jdh/core/providers/plogging_provider.dart';
import 'package:repo_jdh/features/plogging/data/storage_repository.dart';
import 'package:repo_jdh/features/plogging/domain/plogging_session_providers.dart';
import 'package:repo_jdh/features/plogging/domain/route_notifier.dart';
import 'package:repo_jdh/features/auth/data/auth_repository.dart';
import 'package:repo_jdh/core/router/app_router.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';

class PloggingHomeScreen extends ConsumerStatefulWidget {
  const PloggingHomeScreen({super.key});

  @override
  ConsumerState<PloggingHomeScreen> createState() => _PloggingHomeScreenState();
}

Widget _buildCircleButton({
  required IconData icon,
  required VoidCallback onPressed,
}) {
  const double buttonSize = 40; // 흰 동그라미 크기
  const double iconSize = 20;
  return Container(
    width: buttonSize,
    height: buttonSize,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
    child: IconButton(
      padding: EdgeInsets.zero,
      iconSize: iconSize,
      icon: Icon(icon),
      color: Colors.black87,
      onPressed: onPressed,
    ),
  );
}

class _PloggingHomeScreenState extends ConsumerState<PloggingHomeScreen> {
  final String _duration = '06:12';
  final String _distance = '0.12';
  final String _totalDistance = '0.9';
  final int _steps = 125;

  String? _selectedButton = 'camera';
  bool _isExpanded = false;

  // 네이버 지도
  NaverMapController? _mapController;
  bool _mapCentered = false;
  static const _fallback = NLatLng(37.5074, 126.7218); // GPS 전 기본 위치
  static const _routeColor = Color(0xFF1D9E75);

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

  void _showGuide() {
    AppDialog.showInfo(
      context,
      title: '플로깅 안내',
      message:
          '• 카메라를 눌러 쓰레기를 촬영하면 자동으로 종류가 인식돼요.\n'
          '• 한 번 더 누르면 촬영, 종료도 한 번 더 누르면 끝나요.\n'
          '• 상단 카드를 누르면 수거 상세를 볼 수 있어요.',
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await AppDialog.show(
      context,
      title: '로그아웃',
      message: '정말 로그아웃 하시겠습니까?',
      cancelText: '취소',
      confirmText: '로그아웃',
      danger: true,
    );
    if (ok == true) {
      await AuthRepository.signOut();
    }
  }

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
    setState(() => _isExpanded = true);

    final summary = counts.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key} ${e.value}')
        .join(', ');

    if (mounted) {
      AppSnackBar.show(
        context,
        imageUrl != null ? '등록 완료 (사진 저장됨): $summary' : '등록 완료: $summary',
      );
    }
  }

  // PLOG-06 활동 취소 컨펌 (뒤로가기 시): 진행 기록 폐기 후 홈
  Future<void> _confirmCancel() async {
    final ok = await AppDialog.show(
      context,
      title: '활동 취소',
      message:
          '활동을 취소하시겠어요?\n지금까지 수거한 쓰레기는 포인트로 적립되지 않아요. '
          '도착지를 다시 정하려면 활동을 취소하고 처음부터 시작해주세요.',
      cancelText: '계속하기',
      confirmText: '활동 취소',
      primaryIsCancel: true, // 계속하기를 강조(주 버튼), 활동 취소는 보조로
    );
    if (ok == true) {
      await ref.read(ploggingProvider.notifier).reset();
      if (mounted) context.go('/home');
    }
  }

  // PLOG-07 종료 컨펌 → 정산 화면으로
  Future<void> _endPlogging() async {
    final counts = ref.read(ploggingProvider).totalCounts;
    final total = counts.values.fold<int>(0, (s, v) => s + v);
    final ok = await AppDialog.show(
      context,
      title: '오늘의 줍다행을 마칠까요?',
      message: '지금까지 총 $total개를 주웠어요.',
      cancelText: '계속하기',
      confirmText: '종료',
      danger: true, // 종료는 빨강으로 통일
    );
    if (ok == true && mounted) {
      context.push(AppRoutes.ploggingSettlement); // 정산 화면으로
    }
  }

  Widget _buildStatBox(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTrashCount(
    String asset,
    String label,
    int count, {
    double size = 22,
  }) {
    final Color textColor = count > 0
        ? AppColors.mintDeep
        : AppColors.textTertiary;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 26,
              child: Center(
                child: Image.asset('assets/icons/$asset', height: 22),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ploggingState = ref.watch(ploggingProvider);

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
    final bool isCameraSelected = _selectedButton == 'camera';
    final bool isEndSelected = _selectedButton == 'end';
    const Color cameraColor = Color(0xFF0C7D5E); // ◀ 카메라 색
    const Color endColor = Color(0xFFE83737); // ◀ 종료 색

    return Scaffold(
      body: GestureDetector(
        child: Stack(
          children: [
            Positioned.fill(
              child: NaverMap(
                options: const NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: _fallback,
                    zoom: 15,
                  ),
                  locationButtonEnable: true,
                ),
                onMapReady: (controller) {
                  _mapController = controller;
                  _centerOnGps(ref.read(currentLocationProvider).valueOrNull);
                  _renderRoute();
                },
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCircleButton(
                          icon: Icons.arrow_back_ios_new,
                          onPressed: _confirmCancel,
                        ),
                        _buildCircleButton(
                          icon: Icons.help_outline,
                          onPressed: () => _showGuide(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                            child: Row(
                              children: [
                                Expanded(child: _buildStatBox(_duration, '시간')),
                                Expanded(
                                  child: _buildStatBox(_distance, '거리(km)'),
                                ),
                                Expanded(child: _buildStatBox('$_steps', '걸음')),
                                InkWell(
                                  onTap: () => setState(
                                    () => _isExpanded = !_isExpanded,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: AnimatedRotation(
                                      turns: _isExpanded ? 0.5 : 0,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.grey[700],
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: _isExpanded
                                ? Column(
                                    children: [
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        indent: 16,
                                        endIndent: 16,
                                        color: AppColors.divider,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildTrashCount(
                                              'plastic.png',
                                              '플라스틱',
                                              totalCounts['plastic'] ?? 0,
                                              size: 28,
                                            ),
                                            _buildTrashCount(
                                              'can.png',
                                              '캔',
                                              totalCounts['can'] ?? 0,
                                            ), // 22 기본
                                            _buildTrashCount(
                                              'paper.png',
                                              '종이',
                                              totalCounts['paper'] ?? 0,
                                            ),
                                            _buildTrashCount(
                                              'bottle.png',
                                              '유리',
                                              totalCounts['glass'] ?? 0,
                                              size: 28,
                                            ),
                                            _buildTrashCount(
                                              'trash.png',
                                              '일반',
                                              totalCounts['trash'] ?? 0,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 토글 알약: 바깥은 하나, 선택된 쪽이 둥근 컬러 알약으로 채워짐
                      SizedBox(
                        height: 54,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double totalW = constraints.maxWidth;
                            // 선택된 쪽이 넓어짐 (카메라 0.66 / 종료 0.34 / 둘 다 X 0.5)
                            final double cameraRatio = isCameraSelected
                                ? 0.66
                                : (isEndSelected ? 0.34 : 0.5);
                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: cameraRatio),
                              duration: const Duration(milliseconds: 380),
                              curve: Curves.easeOutCubic,
                              builder: (context, ratio, _) {
                                final double cameraW = totalW * ratio;
                                final double endW = totalW - cameraW;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(27),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(27),
                                    child: Stack(
                                      children: [
                                        // 선택된 쪽 컬러 알약 (안쪽 경계가 둥글게)
                                        if (_selectedButton != null)
                                          Positioned(
                                            top: 0,
                                            bottom: 0,
                                            left: isCameraSelected
                                                ? 0
                                                : cameraW,
                                            width: isCameraSelected
                                                ? cameraW
                                                : endW,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isCameraSelected
                                                    ? cameraColor
                                                    : endColor,
                                                borderRadius:
                                                    BorderRadius.circular(27),
                                              ),
                                            ),
                                          ),
                                        // 라벨 + 탭 영역
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: cameraW,
                                              child: _buildSegmentLabel(
                                                label: '카메라',
                                                subtitle: '한 번 더 누르면 촬영됩니다',
                                                selected: isCameraSelected,
                                                baseColor: cameraColor,
                                                onTap: _handleCameraTap,
                                              ),
                                            ),
                                            SizedBox(
                                              width: endW,
                                              child: _buildSegmentLabel(
                                                label: '종료',
                                                subtitle: '한 번 더 누르면 종료됩니다',
                                                selected: isEndSelected,
                                                baseColor: endColor,
                                                onTap: _handleEndTap,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentLabel({
    required String label,
    required String subtitle,
    required bool selected,
    required Color baseColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : baseColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (selected)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
