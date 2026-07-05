import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 나의 환경 영향력 화면 (개인 통계)
/// 위치 제안: lib/features/mypage/presentation/my_impact_screen.dart
/// 홈의 5일 연속 카드(유저카드) → 이 화면
///
/// 이미지("지금 우리는") 톤을 개인 버전으로: 배지 → 연한 소제목 → 굵은 제목
/// → 일러스트(이모지 placeholder) → 하이라이트 숫자 박스, 세로 스크롤.
class MyImpactScreen extends StatelessWidget {
  // 가입년도. 넘겨주지 않으면 기본값(2024) 사용.
  // TODO: 실제 사용자 프로필의 가입일(연도)로 넘기면 자동 반영
  //       예: MyImpactScreen(joinYear: profile.joinedAt.year)
  final int? joinYear;
  const MyImpactScreen({super.key, this.joinYear});

  // TODO: 실제 개인 누적 데이터로 교체
  static const String _userName = '김연영';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '나의 환경 영향력',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
                child: Column(
                  children: [
                    // 히어로: 마스코트 + 인사
                    const SizedBox(height: 8),
                    const Text('🦭', style: TextStyle(fontSize: 84)),
                    const SizedBox(height: 18),
                    Text(
                      '$_userName님의 착한 행동이',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '지구를 지키고 있어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _highlightBox(
                      prefix: '지금까지',
                      value: '38.5',
                      suffix: 'kg 를 주웠어요',
                      bg: AppColors.primaryPale,
                      valueColor: AppColors.primaryDeep,
                    ),

                    const SizedBox(height: 40),

                    // 온실가스 감축량 블록
                    _badge('온실가스 감축량'),
                    const SizedBox(height: 14),
                    const Text(
                      '지구를 위한 착한 행동으로',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '온실가스 배출이\n'),
                          TextSpan(text: '12.4kgCO₂eq'),
                        ],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '저감 되었어요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 일러스트 placeholder (실제 나무+물뿌리개 일러스트로 교체)
                    const Text('🌳', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 20),
                    _highlightBox(
                      prefix: '나무를',
                      value: '2.1',
                      suffix: '그루 심은 효과예요',
                      bg: AppColors.primaryPale,
                      valueColor: AppColors.primaryDeep,
                    ),

                    const SizedBox(height: 40),

                    // 상세 수치 (2열 그리드)
                    _badge('상세 기록'),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.3,
                      children: const [
                        _StatCard('♻️', '누적 수거량', '38.5', 'kg'),
                        _StatCard('🚶', '활동 횟수', '32', '회'),
                        _StatCard('👟', '누적 거리', '46.2', 'km'),
                        _StatCard('🔥', '소모 칼로리', '18,400', 'kcal'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '* ${joinYear ?? 2024}년부터 누적된 나의 기록이에요.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 초록 필 배지
  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryPale,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryDeep,
        ),
      ),
    );
  }

  // 하이라이트 숫자 박스 ("현재 [숫자] 명이 ..." 스타일)
  Widget _highlightBox({
    required String prefix,
    required String value,
    required String suffix,
    required Color bg,
    required Color valueColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            prefix,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardBG,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              suffix,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final String unit;
  const _StatCard(this.emoji, this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
