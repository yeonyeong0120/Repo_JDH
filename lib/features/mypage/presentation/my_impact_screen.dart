import 'dart:math';
import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';

/// 나의 환경 영향력 화면 (개인 통계)
/// 위치 제안: lib/features/mypage/presentation/my_impact_screen.dart
/// 홈의 5일 연속 카드(유저카드) → 이 화면
///
/// 이미지("지금 우리는") 톤을 개인 버전으로: 배지 → 연한 소제목 → 굵은 제목
/// → 일러스트(이모지 placeholder) → 하이라이트 숫자 박스, 세로 스크롤.
class MyImpactScreen extends StatefulWidget {
  // 가입년도. 넘겨주지 않으면 기본값(2024) 사용.
  // TODO: 실제 사용자 프로필의 가입일(연도)로 넘기면 자동 반영
  //       예: MyImpactScreen(joinYear: profile.joinedAt.year)
  final int? joinYear;
  const MyImpactScreen({super.key, this.joinYear});

  @override
  State<MyImpactScreen> createState() => _MyImpactScreenState();
}

class _MyImpactScreenState extends State<MyImpactScreen> {
  // TODO: 실제 개인 누적 데이터로 교체
  static const String _userName = '김연영';

  // 목표 달성 파이의 스크롤 진행도 (0=빔, 1=꽉 참)
  final GlobalKey _pieKey = GlobalKey();
  double _pieProgress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePieProgress());
  }

  // 파이가 화면 아래에서 올라와 세로 중앙에 오면 progress=1, 아래면 0
  void _updatePieProgress() {
    final ctx = _pieKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final pieCenter = box.localToGlobal(Offset.zero).dy + box.size.height / 2;
    final vh = MediaQuery.of(context).size.height;
    final p = ((vh - pieCenter) / (vh / 2)).clamp(0.0, 1.0);
    if ((p - _pieProgress).abs() > 0.001) {
      setState(() => _pieProgress = p);
    }
  }

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
              child: NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  _updatePieProgress();
                  return false;
                },
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

                      const SizedBox(height: 34),
                      // 감축 목표 달성률 파이 (위 온실가스 감축량과 한 파트) — 스크롤로 채워짐
                      // TODO: 실제 목표/달성 데이터로 교체 (지금 더미 62%)
                      KeyedSubtree(
                        key: _pieKey,
                        child: _goalPie(0.62, _pieProgress),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '목표 20kg 중 12.4kg 감축했어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // 지역 상위 랭킹
                      // TODO: 실제 지역 랭킹 데이터로 교체 (지금 더미 상위 8%)
                      _highlightBox(
                        prefix: '우리 지역',
                        value: '상위 8%',
                        suffix: '안에 들어요',
                        bg: AppColors.chartActivity.withValues(alpha: 0.18),
                        valueColor: AppColors.chartActivityPeak,
                      ),

                      const SizedBox(height: 40),

                      // 상세 수치 (2열 그리드)
                      _badge('상세 기록'),
                      const SizedBox(height: 16),
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              // 고정 높이 → 화면 좁아도 카드 내용 안 넘침(오버플로우 방지)
                              mainAxisExtent: 138,
                            ),
                        children: const [
                          _StatCard('♻️', '누적 수거량', '38.5', 'kg'),
                          _StatCard('🚶', '활동 횟수', '32', '회'),
                          _StatCard('👟', '누적 거리', '46.2', 'km'),
                          _StatCard('🔥', '소모 칼로리', '18,400', 'kcal'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '* ${widget.joinYear ?? 2024}년부터 누적된 나의 기록이에요.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 공유하기 (HOME-02)
                      AppButton(
                        label: '공유하기',
                        type: AppButtonType.primary,
                        // TODO: 실제 시스템 공유(share_plus 등) 연결
                        onTap: () => AppSnackBar.show(
                          context,
                          '공유 기능은 준비 중이에요',
                          neutral: true,
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

  // 목표 달성률 파이
  //  target  : 표시할 목표 달성률(숫자, 항상 고정)
  //  progress: 파이 채움 정도(스크롤 0~1) — 숫자는 안 변하고 그래프만 참
  Widget _goalPie(double target, double progress) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DonutPainter(target * progress)),
          ),
          // 가운데: 퍼센트 + 감축 목표 달성
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(target * 100).round()}%',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: AppColors.chartActivityPeak,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '감축 목표 달성',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 초록 필 배지
  Widget _badge(String text, {Color? bg, Color? fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg ?? AppColors.primaryPale,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: fg ?? AppColors.primaryDeep,
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
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            Text(
              suffix,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 목표 달성률 도넛 링 (트랙 + 그라데이션 진행 아크 + 라운드 캡)
class _DonutPainter extends CustomPainter {
  final double ratio; // 0~1 (달성 비율 × 스크롤 진행도)
  _DonutPainter(this.ratio);

  @override
  void paint(Canvas canvas, Size size) {
    final r = ratio.clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = size.width * 0.15; // 링 두께
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 배경 트랙
    final track = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * pi, false, track);

    if (r <= 0) return;

    const start = -pi / 2; // 12시부터
    final sweep = 2 * pi * r;
    // 시작·끝 색을 같게(연초록→진초록→연초록) 매핑 → 12시(0/2π) 경계에서 색이 안 튀어 이음새 없음
    final progress = Paint()
      ..shader = SweepGradient(
        colors: const [
          AppColors.chartActivity,
          AppColors.chartActivityPeak,
          AppColors.chartActivity,
        ],
        stops: [0.0, r, 1.0],
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, progress);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.ratio != ratio;
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
