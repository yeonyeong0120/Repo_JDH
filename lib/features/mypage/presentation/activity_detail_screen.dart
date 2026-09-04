import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/route_pin.dart';
import 'package:repo_jdh/features/plogging/data/photo_service.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';

/// Ploggo - 개별 활동 상세 (ACT-05)
/// 상단 경로 지도 + 기록/수거/인증샷/보상.
/// 수거 개수는 호출부가 활동별 trashCounts 를 넘겨야 한다 — 기본값을 더미로 두면
/// 누락됐을 때 모든 활동이 같은 숫자로 보이므로 빈 맵(전부 0)으로 둔다.
class ActivityDetailScreen extends StatelessWidget {
  final String dateTime;
  final String title;
  final int steps;
  final String weight;
  final int kcal;
  final String time;
  final String distance;

  /// 인증샷 URL. 비어 있으면 '사진 없음'으로 그린다 —
  /// 별도의 hasPhoto 플래그를 두면 URL 과 어긋나 사진이 없는데도
  /// '인증샷 이미지'라고 표시되는 문제가 생긴다. 여기가 유일한 판단 근거다.
  final List<String> imageUrls;

  final Map<String, int> trashCounts;
  final int rewardPoints;
  final int rewardXp;

  /// 활동 문서 ID (users/{uid}/activities/{id}). 있으면 인증샷을 나중에 추가할 수 있다.
  final String activityId;

  /// GPS 경로 ([{lat, lng, t}, ...]). 없으면 헤더에 '경로 없음' 표시.
  final List<Map<String, dynamic>> path;

  const ActivityDetailScreen({
    super.key,
    required this.dateTime,
    required this.title,
    this.steps = 0,
    this.weight = '0kg',
    this.kcal = 0,
    this.time = '0분',
    this.distance = '0km',
    this.imageUrls = const [],
    this.trashCounts = const {},
    this.rewardPoints = 330,
    this.rewardXp = 20,
    this.activityId = '',
    this.path = const [],
  });

  static String _comma(int n) {
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단 바 — 뒤로 + 활동 기록 + 공유
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        TablerIcons.chevronLeft,
                        size: 24,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Text(
                    '활동 기록',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // 공유 (D-3): 그룹 공유 물어보기 팝업 → 공유 시 스낵바
                    onTap: () => _confirmShareToGroup(context),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        TablerIcons.share2,
                        size: 21,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  8,
                  22,
                  MediaQueryData.fromView(View.of(context)).padding.bottom + 100,
                ),
                children: [
                  // 날짜(헤드라인) + 시간·장소
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dateTime,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 경로 지도 (196)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      height: 196,
                      width: double.infinity,
                      child: _ActivityRouteMap(path: path),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 2x2 통계 — 수거량(잉크/라임 강조) · 거리 · 시간 · 걸음
                  Row(
                    children: [
                      _statTile('수거량', weight, featured: true),
                      const SizedBox(width: 10),
                      _statTile('거리', distance),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statTile('시간', time),
                      const SizedBox(width: 10),
                      _statTile('걸음', _comma(steps)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // 인증샷 (없으면 촬영 추가)
                  _PhotoSection(activityId: activityId, initialUrls: imageUrls),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 공유 (D-3): 그룹 공유 물어보기 팝업 → 공유 시 스낵바 ──
  // 실제 그룹 게시 백엔드는 아직 없어 공유 확정 시 스낵바로만 안내한다.
  Future<void> _confirmShareToGroup(BuildContext context) async {
    final ok = await AppDialog.show(
      context,
      title: '그룹에 공유할까요?',
      message: '이 활동 기록을 가입한 그룹 채팅에 공유해요.',
      cancelText: '취소',
      confirmText: '공유',
    );
    if (ok != true || !context.mounted) return;
    AppSnackBar.show(
      context,
      '그룹에 활동 기록을 공유했어요',
      kind: SnackKind.success,
    );
  }

  // 통계 타일 — featured 는 잉크 면 + 라임 값(수거량 강조)
  Widget _statTile(String label, String value, {bool featured = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: featured ? AppColors.ink : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: featured ? AppColors.gray400 : AppColors.gray500,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                  color: featured ? AppColors.lime : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 상단 경로 지도 (네이버 지도 + 실제 GPS 경로) ────────────
// path 가 2개 미만이면 지도 대신 안내만 — 정산 화면과 동일한 원칙.
class _ActivityRouteMap extends StatefulWidget {
  final List<Map<String, dynamic>> path;
  const _ActivityRouteMap({required this.path});

  @override
  State<_ActivityRouteMap> createState() => _ActivityRouteMapState();
}

class _ActivityRouteMapState extends State<_ActivityRouteMap> {
  late final List<NLatLng>? _coords = _toCoords(widget.path);

  static List<NLatLng>? _toCoords(List<Map<String, dynamic>> path) {
    final coords = <NLatLng>[];
    for (final p in path) {
      final lat = (p['lat'] as num?)?.toDouble();
      final lng = (p['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      coords.add(NLatLng(lat, lng));
    }
    return coords.length < 2 ? null : coords;
  }

  @override
  Widget build(BuildContext context) {
    final coords = _coords;
    if (coords == null) {
      return Container(
        color: AppColors.surfaceBrand,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TablerIcons.map, size: 36, color: AppColors.textSecondary),
            SizedBox(height: 8),
            Text(
              '기록된 경로가 없어요',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return NaverMap(
      // 제스처는 기본값(전부 true) 그대로 둔다 — 지난 기록을 되짚어보는
      // 화면이라 정산 화면(보기 전용)과 달리 확대·이동이 가능해야 자연스럽다.
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(target: coords.first, zoom: 15),
      ),
      onMapReady: (controller) => _drawRoute(controller, coords),
    );
  }

  Future<void> _drawRoute(
    NaverMapController controller,
    List<NLatLng> coords,
  ) async {
    try {
      await controller.addOverlay(
        NPolylineOverlay(
          id: 'activity_route',
          coords: coords,
          color: AppColors.routeLine,
          width: 6,
        ),
      );

      if (!mounted) return;
      final startIcon = await _pinIcon(TablerIcons.userFilled);
      final endIcon = await _pinIcon(TablerIcons.flagFilled);
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

      final bounds = NLatLngBounds.from(coords);
      await controller.updateCamera(
        NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(32)),
      );
    } catch (e) {
      debugPrint('[활동 상세] 경로 지도 그리기 실패: $e');
    }
  }

  Future<NOverlayImage> _pinIcon(IconData icon) {
    return NOverlayImage.fromWidget(
      context: context,
      size: const Size(40, 50),
      widget: Directionality(
        textDirection: TextDirection.ltr,
        child: RoutePin(icon: icon),
      ),
    );
  }
}

// ── 인증샷 섹션 (없으면 '추가하기' 탭 → 촬영·업로드) ────────────
class _PhotoSection extends StatefulWidget {
  final String activityId;
  final List<String> initialUrls;
  const _PhotoSection({required this.activityId, required this.initialUrls});

  @override
  State<_PhotoSection> createState() => _PhotoSectionState();
}

class _PhotoSectionState extends State<_PhotoSection> {
  late List<String> _urls = [...widget.initialUrls];
  bool _uploading = false;

  bool get _hasPhoto => _urls.isNotEmpty;

  Future<void> _addPhoto() async {
    if (_uploading) return;
    if (widget.activityId.isEmpty) {
      AppSnackBar.show(context, '이 활동에는 인증샷을 추가할 수 없어요');
      return;
    }
    XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '카메라를 열지 못했어요');
      return;
    }
    if (shot == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final url = await PhotoService.uploadActivityPhoto(shot);
      if (url == null) {
        if (mounted) {
          AppSnackBar.show(context, '업로드에 실패했어요', kind: SnackKind.error);
        }
        return;
      }
      await ActivityService.addPhoto(
        activityId: widget.activityId,
        imageUrl: url,
      );
      if (!mounted) return;
      setState(() => _urls = [..._urls, url]);
      AppSnackBar.show(context, '인증샷을 추가했어요', kind: SnackKind.success);
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, '인증샷을 추가하지 못했어요', kind: SnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 목업: 74 썸네일(또는 점선 촬영 박스) + 우측 설명 한 줄
    if (_hasPhoto) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              _urls.first,
              width: 74,
              height: 74,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _thumbFallback(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '인증샷 ${_urls.length}장',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  '활동 중 남긴 인증샷이에요',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    // 인증샷 없음 → 점선 촬영 박스 (탭하면 촬영)
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _addPhoto,
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.gray300,
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
            child: _uploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    TablerIcons.cameraPlus,
                    size: 26,
                    color: AppColors.gray700,
                  ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '인증샷을 남기지 않았어요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '지금 촬영해 기록에 추가할 수 있어요 (촬영만 가능)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 썸네일 로딩 실패 자리
  Widget _thumbFallback() {
    return Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(TablerIcons.photo, size: 24, color: AppColors.gray400),
    );
  }
}
