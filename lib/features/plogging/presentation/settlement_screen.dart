import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/providers/plogging_provider.dart';

/// 줍다행 - 활동 정산 화면 (플로깅 종료 후 결과 요약 + 보상 + 기록/공유)
/// 위치 권장: lib/features/plogging/presentation/settlement_screen.dart
class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  // 수거 내역 (placeholder — 실제 정산 데이터로 교체)
  static const List<_Trash> _trash = [
    _Trash('플라스틱', 11, AppColors.primary),
    _Trash('캔', 3, AppColors.warning),
    _Trash('종이', 9, AppColors.mintDeep),
    _Trash('유리', 0, AppColors.trashGeneral),
    _Trash('일반', 10, AppColors.error),
  ];

  int get _totalTrash => _trash.fold(0, (s, t) => s + t.count);

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
    context.go('/home'); // 홈으로 이동
  }

  @override
  Widget build(BuildContext context) {
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
                    _trashCard(),
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
        gradient: AppColors.primaryGradient,
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

  // ───────────────────────── 수거한 쓰레기 ─────────────────────────
  Widget _trashCard() {
    return _card(
      title: '수거한 쓰레기',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryPale,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '총 $_totalTrash개',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDeep,
          ),
        ),
      ),
      child: Column(
        children: _trash.map((t) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: t.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    t.label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '${t.count}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ───────────────────────── 획득 보상 ─────────────────────────
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

class _Trash {
  final String label;
  final int count;
  final Color color;
  const _Trash(this.label, this.count, this.color);
}
