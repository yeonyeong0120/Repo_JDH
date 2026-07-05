import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/providers/plogging_provider.dart';
import 'package:repo_jdh/core/router/app_router.dart';

/// 줍다행 - 활동 정산 화면 (플로깅 종료 후 결과 요약 + 보상 + 기록/공유)
/// 위치 권장: lib/features/plogging/presentation/settlement_screen.dart
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

  /// 마무리 동작. share=false 면 기록만, true 면 그룹 공유까지.
  Future<void> _finish({required bool share}) async {
    // TODO: 활동 기록을 Firestore에 저장
    //       share == true 이면 그룹 피드에도 결과 게시
    await ref.read(ploggingProvider.notifier).reset(); // 다음 활동 위해 초기화
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(share ? '그룹에 공유했어요' : '활동을 기록했어요'),
        backgroundColor: AppColors.mintDeep,
        duration: const Duration(seconds: 2),
      ),
    );
    // 공유하면 그룹 채팅창으로, 기록만 하면 홈으로
    if (share) {
      context.go('/group/feed'); // 그룹 채팅창(그룹 피드)
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 실제 수거 데이터 읽기
    final state = ref.watch(ploggingProvider);
    final counts = state.totalCounts;
    final totalTrash = counts.values.fold<int>(0, (s, v) => s + v);

    return Scaffold(
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
                    _recordCard(),
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
          SizedBox(height: 4),
          Text(
            '오늘도 줍다행 했어요',
            style: TextStyle(fontSize: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 오늘의 기록 ─────────────────────────
  // TODO: 거리/시간/걸음/칼로리는 아직 ploggingProvider에 없음(추적값 미저장).
  //       GPS·걸음 추적을 provider/state에 담으면 여기서 실제 값으로 교체.
  Widget _recordCard() {
    return _card(
      title: '오늘의 기록',
      child: Column(
        children: [
          Row(
            children: [
              _metric('시간', '00:42'),
              const SizedBox(width: 10),
              _metric('거리', '2.1 km'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metric('걸음', '3,120'),
              const SizedBox(width: 10),
              _metric('칼로리', '245'),
            ],
          ),
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
            AppColors.mintDeep,
          ),
          const SizedBox(height: 4),
          _rewardRow(
            Icons.star_outline,
            '경험치',
            '+20 XP',
            AppColors.primaryDeep,
          ),
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

  // ───────────────────────── 하단 버튼 ─────────────────────────
  Widget _bottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _finish(share: false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cardBG,
                  border: Border.all(color: AppColors.primaryLight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '기록만 할게요',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _finish(share: true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.buttonShadow,
                ),
                child: const Text(
                  '그룹에 공유하기',
                  style: TextStyle(
                    fontSize: 15,
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
