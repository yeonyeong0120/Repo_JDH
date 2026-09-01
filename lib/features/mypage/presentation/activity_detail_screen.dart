import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
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
    final total = trashCounts.values.fold<int>(0, (s, v) => s + v);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 경로 지도 헤더 + 뒤로/더보기 버튼 (본문과 함께 스크롤됨)
          Stack(
            children: [
              SizedBox(
                height: 250,
                width: double.infinity,
                child: _ActivityRouteMap(path: path),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 6,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _glassBtn(
                        TablerIcons.chevronLeft, () => Navigator.pop(context)),
                    _glassBtn(TablerIcons.dots, () => _showMenu(context)),
                  ],
                ),
              ),
            ],
          ),
          Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    // 하단 네비바에 마지막 카드가 가리지 않게 넉넉히
                    MediaQueryData.fromView(View.of(context)).padding.bottom + 100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateTime,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 2x2 통계 타일
                      Row(
                        children: [
                          _statTile(TablerIcons.route, AppColors.dataDistance, '거리',
                              distance),
                          const SizedBox(width: 12),
                          _statTile(TablerIcons.clock, AppColors.dataTime, '시간',
                              time),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _statTile(TablerIcons.shoe, AppColors.dataSteps, '걸음',
                              '${_comma(steps)}걸음'),
                          const SizedBox(width: 12),
                          _statTile(TablerIcons.flame,
                              AppColors.dataCalorie, '칼로리', '${kcal}kcal'),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _trashCard(total),
                      const SizedBox(height: 14),
                      _photoCard(),
                      const SizedBox(height: 14),
                      _rewardCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
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

  Widget _statTile(IconData icon, Color color, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _valueUnit(value),
            ),
          ],
        ),
      ),
    );
  }

  // '2.4km' → 숫자(크고 진하게) + 단위(작은 회색)
  Widget _valueUnit(String v) {
    int i = 0;
    while (i < v.length && '0123456789,. '.contains(v[i])) {
      i++;
    }
    final num = v.substring(0, i).trim();
    final unit = v.substring(i).trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          num,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 3),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _card({required String title, Widget? trailing, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _trashCard(int total) {
    const cats = [
      ('plastic', '플라스틱', TablerIcons.bottle, Color(0xFF5F9EE8)),
      ('can', '캔', TablerIcons.cup, Color(0xFFE07B2E)),
      ('paper', '종이', TablerIcons.fileDescription, Color(0xFF31C88B)),
      ('glass', '유리', TablerIcons.glassFull, Color(0xFF8E7EC4)),
      ('trash', '일반', TablerIcons.trash, Color(0xFF9AA3A0)),
    ];
    return _card(
      title: '수거한 쓰레기',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.neutral100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '총 $total개',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      child: Row(
        children: [
          for (final c in cats)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _catCell(c.$3, c.$4, c.$2, trashCounts[c.$1] ?? 0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _catCell(IconData icon, Color color, String label, int count) {
    final active = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      decoration: BoxDecoration(
        color: AppColors.neutral100, // 쿨 뉴트럴 타일 (정산·다른 화면과 통일)
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            // 안 모은 종류(0)는 아이콘도 회색
            child: Icon(
              icon,
              size: 20,
              color: active ? color : AppColors.neutral400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: active ? AppColors.textPrimary : AppColors.neutral400,
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoCard() {
    return _card(
      title: '인증샷',
      child: _PhotoSection(
        activityId: activityId,
        initialUrls: imageUrls,
      ),
    );
  }

  // 획득 보상 — '획득 보상' 라벨 오른쪽에 작은 알약 두 개(포인트/경험치).
  Widget _rewardCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          const Text(
            '획득 보상',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          _rewardPill(TablerIcons.leaf, '+$rewardPoints P', AppColors.dataDistance),
          const SizedBox(width: 8),
          _rewardPill(TablerIcons.starFilled, '+$rewardXp XP', AppColors.dataTime),
        ],
      ),
    );
  }

  Widget _rewardPill(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(TablerIcons.trash,
                  color: AppColors.actionDanger),
              title: const Text(
                '활동 삭제',
                style: TextStyle(color: AppColors.actionDanger),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await AppDialog.show(
                  context,
                  title: '활동 삭제',
                  message: '이 활동 기록을 삭제할까요?\n\n삭제하면 되돌릴 수 없어요.',
                  cancelText: '취소',
                  confirmText: '삭제',
                  danger: true,
                );
                if (ok == true && context.mounted) {
                  // TODO: 실제 삭제 로직 연결
                  AppSnackBar.show(context, '활동을 삭제했어요');
                  Navigator.pop(context);
                }
              },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasPhoto)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              _urls.first,
              height: 170,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(loadFailed: true),
            ),
          )
        else
          _placeholder(loadFailed: false),
      ],
    );
  }

  // 사진 없음(추가하기) / 로딩 실패 자리. 없을 때만 탭하면 촬영.
  Widget _placeholder({required bool loadFailed}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loadFailed ? null : _addPhoto,
      child: Container(
        height: 170,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.green50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: _uploading
            ? const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    loadFailed ? TablerIcons.photo : TablerIcons.cameraPlus,
                    size: 34,
                    color: AppColors.neutral400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loadFailed ? '인증샷을 불러오지 못했어요' : '인증샷 추가하기',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
