import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/providers/plogging_provider.dart';
import 'package:repo_jdh/core/providers/shared_group_provider.dart';
import 'package:repo_jdh/core/providers/tracking_provider.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/mypage/presentation/badge_dialog.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:repo_jdh/features/plogging/data/photo_service.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/data/location_repository.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';

/// 줍다행 - 활동 정산 화면 (플로깅 종료 후 결과 요약 + 보상 + 기록/공유)
class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  // 사진 업로드 진행 중 여부 (버튼 중복 탭 방지 + 진행 표시)
  bool _uploading = false;

  // 경로선 색 (트래킹 화면과 동일)
  static const Color _routeColor = Color(0xFF1D9E75);

  // 쓰레기 종류 정의 (라벨, 컬러 PNG 아이콘, ploggingProvider의 키)
  static const List<_TrashDef> _trashDefs = [
    _TrashDef('플라스틱', 'plastic.png', 'plastic'),
    _TrashDef('캔', 'can.png', 'can'),
    _TrashDef('종이', 'paper.png', 'paper'),
    _TrashDef('유리', 'bottle.png', 'glass'),
    _TrashDef('일반', 'trash.png', 'trash'),
  ];

  // 활동 기록 저장 — 반드시 뱃지 판정보다 먼저 실행해야 한다.
  // (뱃지 판정이 activities 를 읽어 통계를 내므로, 이번 활동이 빠지면 안 됨)
  Future<void> _saveActivity() async {
    try {
      final t = ref.read(trackingProvider);
      final counts = ref.read(ploggingProvider).totalCounts;

      // 수거 개수가 0이면 저장하지 않음 (무의미한 기록 방지)
      final total = counts.values.fold<int>(0, (s, v) => s + v);
      if (total == 0 && t.distanceMeters <= 0) return;

      final endedAt = DateTime.now();
      // startedAt 이 없으면 경과 시간으로 역산
      final startedAt =
          t.startedAt ?? endedAt.subtract(Duration(seconds: t.elapsedSeconds));

      // 0인 항목은 빼고 저장 (문서 크기 절약)
      final trashCounts = <String, int>{};
      counts.forEach((k, v) {
        if (v > 0) trashCounts[k] = v;
      });

      await ActivityService.saveCompleted(
        startedAt: startedAt,
        endedAt: endedAt,
        durationSeconds: t.elapsedSeconds,
        distanceMeters: t.distanceMeters,
        trashCounts: trashCounts,
        groupId: null, // 그룹 활동 구분이 생기면 여기에 전달
        path: t.pathJson, // 활동 경로 (나중에 기록 상세에서 지도 표시)
        startLocation: t.startLocation,
        endLocation: t.endLocation,
      );
    } catch (e) {
      debugPrint('[정산] 활동 저장 실패: $e');
      // 저장 실패해도 화면 흐름은 계속 (사용자를 가두지 않음)
    }
  }

  // ACT-09 뱃지 획득 모달 (홈으로 나가기 직전 노출)
  // 누적 통계 집계 → 조건 판정 → 새로 딴 것만 저장 후 모달
  Future<void> _showBadgesIfAny() async {
    List<BadgeData> badges = const [];
    try {
      badges = await BadgeService.checkAndSave();
    } catch (_) {
      return; // 판정 실패해도 홈 이동은 막지 않음
    }
    if (badges.isEmpty || !mounted) return;
    final t = ref.read(trackingProvider);
    // 무게는 카테고리별 평균으로 계산 (다른 화면과 통일)
    final counts = ref.read(ploggingProvider).totalCounts;
    final weightLabel = ActivityMetrics.weightLabel(counts);
    await showBadgeEarned(
      context,
      badges: badges,
      summary: '걸음 ${t.steps} · ${t.kcal} kcal · $weightLabel',
    );
  }

  // 찍기 → 봉투 인증샷 촬영 → 자동 그룹 공유 → 홈 + AUTO-02 팝업
  Future<void> _takePhoto() async {
    final file = await PhotoService.takePhoto();
    if (file == null) return; // 촬영 취소 → 정산 화면에 머무름
    await _uploadAndShare(file);
  }

  // 갤러리 → 사진 선택 → 자동 그룹 공유 → 홈 + AUTO-02 팝업
  Future<void> _pickGallery() async {
    final file = await PhotoService.pickFromGallery();
    if (file == null) return; // 선택 취소 → 정산 화면에 머무름
    await _uploadAndShare(file);
  }

  // 사진 업로드 후 공유 (업로드 중에는 진행 표시)
  Future<void> _uploadAndShare(XFile file) async {
    if (!mounted) return;
    setState(() => _uploading = true);
    String? url;
    try {
      url = await PhotoService.uploadActivityPhoto(file);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
    // 업로드 실패해도(url == null) 사진 없는 활동으로 계속 진행
    await _shareAndHome(imageUrl: url);
  }

  // 스킵 → 그룹 미공유, 곧장 홈
  Future<void> _skip() async {
    await _saveActivity(); // ① 활동 저장 (뱃지 판정보다 먼저)
    await ref.read(ploggingProvider.notifier).reset();
    if (!mounted) return;
    await _showBadgesIfAny(); // ② 뱃지 판정 → 획득 시 축하 모달
    ref.read(trackingProvider.notifier).reset();
    if (!mounted) return;
    context.go('/home');
  }

  // 사진 결정(찍기/갤러리) 공통: 자동 그룹 공유 후 홈 이동
  Future<void> _shareAndHome({String? imageUrl}) async {
    await _saveActivity(); // ① 활동 저장 (reset 전에 해야 데이터가 살아있음)

    // ② 내 그룹 피드에 활동 카드 게시 (공유 횟수도 누적 → 'share_10' 뱃지)
    String myGroupName = '우리 동네 그룹';
    try {
      final myGroup = await GroupService.myGroup();
      if (myGroup != null) {
        myGroupName = myGroup.name;
        final t = ref.read(trackingProvider);
        final total = ref
            .read(ploggingProvider)
            .totalCounts
            .values
            .fold<int>(0, (s, v) => s + v);
        await GroupService.addPost(
          groupId: myGroup.id,
          imageUrl: imageUrl, // 업로드한 인증샷 (없으면 null)
          distance: '${t.distanceText} km',
          trash: total,
          duration: t.durationText,
        );
      }
    } catch (_) {
      // 공유 실패해도 홈 이동은 계속
    }
    await ref.read(ploggingProvider.notifier).reset();
    // AUTO-02 신호: 홈이 이 값을 읽어 공유 완료 팝업을 띄움
    ref.read(sharedGroupProvider.notifier).set(myGroupName);
    if (!mounted) return;
    await _showBadgesIfAny(); // ③ 뱃지 판정 → 획득 시 축하 모달
    ref.read(trackingProvider.notifier).reset();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    // 실제 수거 데이터 읽기
    final state = ref.watch(ploggingProvider);
    final counts = state.totalCounts;
    final totalTrash = counts.values.fold<int>(0, (s, v) => s + v);

    // 정산은 되돌아갈 수 없음 — 기기 뒤로가기로 트래킹/지도에 복귀하지 않게 막는다
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHero(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    children: [
                      _mapCard(),
                      const SizedBox(height: 14),
                      _recordCard(totalTrash),
                      const SizedBox(height: 14),
                      _trashCard(counts, totalTrash),
                      const SizedBox(height: 14),
                      _rewardCard(),
                    ],
                  ),
                ),
              ),
              _bottomButtons(),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 상단 축하 영역 (그라데이션) ─────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
      child: Column(
        children: const [
          // TODO: 줍댕이(물개) 캐릭터 이미지로 교체
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            child: Text('🦭', style: TextStyle(fontSize: 34)),
          ),
          SizedBox(height: 12),
          Text(
            '플로깅 완료!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 활동 경로 지도 ─────────────────────────
  Widget _mapCard() {
    final path = ref.watch(trackingProvider).path;

    return _card(
      title: '활동 경로',
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          // 경로가 없으면(위치 못 받음 / 너무 짧음) 안내만 표시
          child: path.length < 2
              ? Container(
                  color: AppColors.surfaceBrand,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.map_outlined,
                        size: 32,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 6),
                      Text(
                        '기록된 경로가 없어요',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : NaverMap(
                  options: NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: NLatLng(path.first.lat, path.first.lng),
                      zoom: 15,
                    ),
                    // 정산 화면에서는 보기만 — 조작 최소화
                    scrollGesturesEnable: false,
                    zoomGesturesEnable: false,
                    rotationGesturesEnable: false,
                    tiltGesturesEnable: false,
                    logoClickEnable: false,
                  ),
                  onMapReady: (controller) => _drawRoute(controller, path),
                ),
        ),
      ),
    );
  }

  // 지도에 경로선 + 시작/도착 마커 그리기
  Future<void> _drawRoute(
    NaverMapController controller,
    List<TrackPoint> path,
  ) async {
    try {
      final coords = path.map((p) => NLatLng(p.lat, p.lng)).toList();

      // 경로선
      await controller.addOverlay(
        NPolylineOverlay(
          id: 'activity_route',
          coords: coords,
          color: _routeColor,
          width: 5,
        ),
      );

      // 시작 · 도착 마커
      await controller.addOverlay(
        NMarker(id: 'route_start', position: coords.first),
      );
      await controller.addOverlay(
        NMarker(id: 'route_end', position: coords.last),
      );

      // 경로 전체가 보이도록 카메라 이동
      final bounds = NLatLngBounds.from(coords);
      await controller.updateCamera(
        NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(32)),
      );
    } catch (e) {
      debugPrint('[정산] 경로 지도 그리기 실패: $e');
    }
  }

  // ───────────────────────── 오늘의 기록 (트래킹 실측값) ─────────────────────────
  Widget _recordCard(int totalTrash) {
    final t = ref.watch(trackingProvider);
    // 무게는 카테고리별 평균으로 계산 (다른 화면과 통일)
    final counts = ref.watch(ploggingProvider).totalCounts;
    final weight = ActivityMetrics.weightLabel(counts);
    return _card(
      title: '오늘의 기록',
      child: Column(
        children: [
          Row(
            children: [
              _metric('시간', t.durationText),
              const SizedBox(width: 10),
              _metric('거리', '${t.distanceText} km'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metric('걸음', '${t.steps}'),
              const SizedBox(width: 10),
              _metric('칼로리', '${t.kcal}'),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [_metric('무게(추정)', weight)]),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceBrand,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 수거한 쓰레기 (실제 데이터 + 컬러 아이콘) ─────────────────────────
  Widget _trashCard(Map<String, int> counts, int total) {
    return _card(
      title: '수거한 쓰레기',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceBrand,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '총 $total개',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.green800,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _trashDefs.map((d) {
          final int c = counts[d.key] ?? 0;
          final bool active = c > 0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 아이콘 여백 차이 흡수용 고정 높이 + 중앙정렬
              SizedBox(
                height: 34,
                child: Center(
                  child: Image.asset('assets/icons/${d.asset}', height: 28),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$c',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                d.label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ───────────────────────── 획득 보상 ─────────────────────────
  // TODO: 포인트/경험치도 아직 provider에 없음. 보상 로직 생기면 실제 값으로 교체.
  Widget _rewardCard() {
    return _card(
      title: '획득 보상',
      child: Column(
        children: [
          _rewardRow(
            Icons.savings_outlined,
            '포인트',
            '+330 P',
            AppColors.primary,
          ),
          const SizedBox(height: 4),
          _rewardRow(Icons.star_outline, '경험치', '+20 XP', AppColors.primary),
        ],
      ),
    );
  }

  Widget _rewardRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── 하단 버튼 (찍기 / 갤러리 / 스킵) ─────────────────────────
  //
  // SafeArea 로 감싸 시스템 네비게이션 바(홈·뒤로가기)와 겹치지 않게 한다.
  // 폰마다 네비바 높이가 달라 고정 여백으로는 대응할 수 없다.
  Widget _bottomButtons() {
    // 업로드 중에는 진행 표시로 대체 (중복 탭 방지)
    if (_uploading) {
      return const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '인증샷 올리는 중…',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      top: false, // 상단은 이미 위쪽 SafeArea 가 처리
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: '찍기',
              onTap: _takePhoto,
              type: AppButtonType.primary,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '갤러리',
                    onTap: _pickGallery,
                    type: AppButtonType.secondary,
                    expand: false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: '스킵',
                    onTap: _skip,
                    type: AppButtonType.secondary,
                    expand: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 공통 카드 래퍼
  Widget _card({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TrashDef {
  final String label;
  final String asset; // assets/icons/ 안 PNG 파일명
  final String key; // ploggingProvider totalCounts 키
  const _TrashDef(this.label, this.asset, this.key);
}