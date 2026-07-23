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

/// 줍다행 - 활동 정산 화면 (플로깅 종료 후 결과 요약 + 보상 + 기록/공유)
class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  // 쓰레기 종류 정의 (라벨, 컬러 PNG 아이콘, ploggingProvider의 키)
  static const List<_TrashDef> _trashDefs = [
    _TrashDef('플라스틱', 'plastic.png', 'plastic'),
    _TrashDef('캔', 'can.png', 'can'),
    _TrashDef('종이', 'paper.png', 'paper'),
    _TrashDef('유리', 'bottle.png', 'glass'),
    _TrashDef('일반', 'trash.png', 'trash'),
  ];

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
    final total = ref
        .read(ploggingProvider)
        .totalCounts
        .values
        .fold<int>(0, (s, v) => s + v);
    await showBadgeEarned(
      context,
      badges: badges,
      summary:
          '걸음 ${t.steps} · ${t.kcal} kcal · ${(total * 0.1).toStringAsFixed(1)} kg',
    );
  }

  // 찍기 → 봉투 인증샷 촬영 → 자동 그룹 공유 → 홈 + AUTO-02 팝업
  Future<void> _takePhoto() async {
    // TODO: PLOG-08 카메라(봉투 모드) → PLOG-09 미리보기 → 사진 DB 저장
    await _shareAndHome();
  }

  // 갤러리 → 사진 선택 → 자동 그룹 공유 → 홈 + AUTO-02 팝업
  Future<void> _pickGallery() async {
    // TODO: 시스템 갤러리 호출 → 사진 선택 → 사진 DB 저장
    await _shareAndHome();
  }

  // 스킵 → 그룹 미공유, 곧장 홈
  Future<void> _skip() async {
    await ref.read(ploggingProvider.notifier).reset();
    if (!mounted) return;
    await _showBadgesIfAny(); // 뱃지 획득 시 축하 모달 → 닫으면 홈
    ref.read(trackingProvider.notifier).reset();
    if (!mounted) return;
    context.go('/home');
  }

  // 사진 결정(찍기/갤러리) 공통: 자동 그룹 공유 후 홈 이동
  Future<void> _shareAndHome() async {
    // 내 그룹 피드에 활동 카드 게시 (공유 횟수도 함께 누적 → 'share_10' 뱃지)
    String myGroupName = '우리 동네 그룹';
    try {
      final myGroup = await GroupService.myGroup();
      if (myGroup != null) {
        myGroupName = myGroup.name;
        // TODO: 인증샷 업로드 후 imageUrl 전달
        final t = ref.read(trackingProvider);
        final total = ref
            .read(ploggingProvider)
            .totalCounts
            .values
            .fold<int>(0, (s, v) => s + v);
        await GroupService.addPost(
          groupId: myGroup.id,
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
    await _showBadgesIfAny(); // 뱃지 획득 시 축하 모달 → 닫으면 홈
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
        backgroundColor: AppColors.appBG,
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
    return _card(
      title: '활동 경로',
      child: Container(
        height: 140,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryPale,
          borderRadius: BorderRadius.circular(14),
        ),
        // TODO: 실제 활동 경로 지도(Polyline + 거점 마커)로 교체
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.map_outlined, size: 32, color: AppColors.textTertiary),
            SizedBox(height: 6),
            Text(
              '경로 지도',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 오늘의 기록 (트래킹 실측값) ─────────────────────────
  Widget _recordCard(int totalTrash) {
    final t = ref.watch(trackingProvider);
    // TODO: 무게는 개당 100g 가정. 실제 추정 로직 생기면 교체.
    final weight = (totalTrash * 0.1).toStringAsFixed(1);
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
          Row(children: [_metric('무게(추정)', '$weight kg')]),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryPale,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
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
          color: AppColors.primaryPale,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '총 $total개',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDeep,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                d.label,
                style: const TextStyle(
                  fontSize: 11,
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
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── 하단 버튼 (찍기 / 갤러리 / 스킵) ─────────────────────────
  Widget _bottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
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
        color: AppColors.cardBG,
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
