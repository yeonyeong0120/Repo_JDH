import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/core/widgets/trash_bag_icon.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';

/// ACT-08 뱃지 상세 모달
/// 획득/미획득 모두 클릭 가능. 획득조건은 항상 표시하고, 달성일자만 획득 시 노출.
///
/// 보상은 에코 포인트만 표시한다.
/// (줍댕이 꾸미기 기능은 범위에서 제외 — badge.dart 의 reward/slot 은 미사용)
Future<void> showBadgeDetail(
  BuildContext context,
  BadgeData badge, {
  int current = 0,
  int total = 0,
}) {
  final earned = BadgeRepo.isEarned(badge.id);
  final date = BadgeRepo.dateOf(badge.id);
  final color = badgeColor(badge);
  final xp = badgeXp(badge);
  final tot = total <= 0 ? 1 : total;
  final progress = (current / tot).clamp(0.0, 1.0);
  final pct = (progress * 100).round();
  final remain = (tot - current).clamp(0, tot);

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: Gap.xl3),
      shape: RoundedRectangleBorder(borderRadius: Radii.sheetR),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, Gap.xl),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // 상단: 뱃지 아이콘 + 이름/조건 (X는 아래 Stack 오버레이 — 레이아웃 안 밀림)
            Row(
              children: [
                _BadgeMedal(
                  badge: badge,
                  earned: earned,
                  color: color,
                  progress: progress,
                  pct: pct,
                ),
                Gap.w16,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(badge.name, style: AppType.title2),
                      Gap.h4,
                      Text(
                        badge.condition,
                        style: AppType.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Gap.h20,
            const Divider(height: 1, color: AppColors.border),
            Gap.h16,
            if (earned) ...[
              _rewardLabel('받은 보상'),
              Gap.h12,
              _valueRow('받은 포인트', '${badge.points} P',
                  valueColor: AppColors.textBrandOnLight),
              Gap.h12,
              _valueRow('받은 경험치', '$xp XP',
                  valueColor: AppColors.textBrandOnLight),
              if (date != null && date.isNotEmpty) ...[
                Gap.h12,
                _valueRow('받은 날', _prettyDate(date)),
              ],
            ] else ...[
              _valueRow(
                '${_comma(remain)} 남았어요',
                '${_comma(current)} / ${_comma(tot)}',
              ),
              Gap.h16,
              _rewardLabel('달성하면 받아요'),
              Gap.h12,
              _valueRow('포인트', '${badge.points} P',
                  valueColor: AppColors.textBrandOnLight),
              Gap.h12,
              _valueRow('경험치', '$xp XP',
                  valueColor: AppColors.textBrandOnLight),
            ],
              ],
            ),
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(ctx),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(TablerIcons.x, size: 22,
                      color: AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 상세 팝업의 뱃지 메달 — 획득: 색 틴트 + 체크 / 미획득: 회색 링 + %.
class _BadgeMedal extends StatelessWidget {
  final BadgeData badge;
  final bool earned;
  final Color color;
  final double progress;
  final int pct;
  const _BadgeMedal({
    required this.badge,
    required this.earned,
    required this.color,
    required this.progress,
    required this.pct,
  });

  // 수거 봉지 뱃지만 쓰레기봉투 아이콘으로
  Widget _icon(Color c, double size) => usesTrashBagIcon(badge)
      ? TrashBagIcon(size: size, color: c)
      : Icon(badge.icon, size: size, color: c);

  @override
  Widget build(BuildContext context) {
    const d = 76.0;
    if (earned) {
      return SizedBox(
        width: d,
        height: d,
        child: Stack(
          children: [
            Container(
              width: d,
              height: d,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tint(color, 0.16),
                borderRadius: BorderRadius.circular(22),
              ),
              child: _icon(color, 34),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green600,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: const Icon(TablerIcons.check, size: 14,
                    color: AppColors.textOnBrand),
              ),
            ),
          ],
        ),
      );
    }
    // 미획득: 은은한 초록 바탕 + 두꺼운 회색 링, 아이콘은 가운데,
    // 달성도(%)는 오른쪽 아래 흰 알약으로.
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BadgeRingPainter(
                progress,
                AppColors.neutral400,
                stroke: 7, // 미리보기 타일 링과 같은 두께
              ),
            ),
          ),
          _icon(AppColors.neutral400, 28),
          Positioned(
            right: -5,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(13),
                boxShadow: AppColors.cardShadow,
              ),
              child: Text(
                '$pct%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _rewardLabel(String text) {
  return Text(
    text,
    style: AppType.caption.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
    ),
  );
}

Widget _valueRow(String label, String value, {Color? valueColor}) {
  return Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: AppType.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
      Text(
        value,
        style: AppType.title3.copyWith(
          fontWeight: FontWeight.w800,
          color: valueColor ?? AppColors.textPrimary,
        ),
      ),
    ],
  );
}

// '2026.08.05' → '8월 5일'
String _prettyDate(String d) {
  final parts = d.split('.');
  if (parts.length == 3) {
    final m = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (m != null && day != null) return '$m월 $day일';
  }
  return d;
}

// 천 단위 콤마
String _comma(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// 미획득 뱃지의 달성률을 나타내는 둥근 네모 링.
/// 회색 트랙 위에 카테고리색으로 progress 만큼 채운다.
class BadgeRingPainter extends CustomPainter {
  final double progress; // 0~1
  final Color color;
  final double stroke;
  final double radius;
  const BadgeRingPainter(
    this.progress,
    this.color, {
    this.stroke = 3,
    this.radius = 18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    // 머리 꼭대기(12시)에서 시작해 시계방향으로 도는 둥근 네모 경로
    final path = _roundedFromTop(r, radius);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.neutral200,
    );
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(
        m.extractPath(0, m.length * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BadgeRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.stroke != stroke;
}

// 상단 중앙에서 시작해 시계방향으로 도는 둥근 네모 경로.
// (달성률 스트로크가 '머리 꼭대기'에서 시작하도록)
Path _roundedFromTop(Rect r, double radius) {
  final rr = radius.clamp(0.0, r.shortestSide / 2);
  final cx = r.center.dx;
  return Path()
    ..moveTo(cx, r.top)
    ..lineTo(r.right - rr, r.top)
    ..arcToPoint(Offset(r.right, r.top + rr), radius: Radius.circular(rr))
    ..lineTo(r.right, r.bottom - rr)
    ..arcToPoint(Offset(r.right - rr, r.bottom), radius: Radius.circular(rr))
    ..lineTo(r.left + rr, r.bottom)
    ..arcToPoint(Offset(r.left, r.bottom - rr), radius: Radius.circular(rr))
    ..lineTo(r.left, r.top + rr)
    ..arcToPoint(Offset(r.left + rr, r.top), radius: Radius.circular(rr))
    ..lineTo(cx, r.top);
}

/// ACT-09 뱃지 획득 모달 (정산 → 확인/공유하기 → 자동 노출)
/// 여러 개를 한 번에 얻어도 한 장에 묶어서 보여주고, 포인트는 합산.
/// 뱃지를 누르면 해당 뱃지 상세로 이동.
Future<void> showBadgeEarned(
  BuildContext context, {
  required List<BadgeData> badges,
  required String summary, // 예: '걸음 12,340 · 320 kcal · 1.2 kg'
}) {
  if (badges.isEmpty) return Future.value();
  final totalPoints = badges.fold<int>(0, (sum, b) => sum + b.points);
  final shown = badges.take(3).toList();
  final more = badges.length - shown.length;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: Gap.xl3),
      shape: RoundedRectangleBorder(borderRadius: Radii.sheetR),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl2, Gap.xl, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              badges.length == 1 ? '뱃지 획득!' : '뱃지 ${badges.length}개 획득!',
              style: AppType.title1.copyWith(
                color: AppColors.textBrandOnLight,
              ),
              textAlign: TextAlign.center,
            ),
            Gap.h8,
            Text(
              summary,
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
            ),
            Gap.h20,
            // 획득한 뱃지 (최대 3개 노출, 탭하면 상세)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in shown)
                  Expanded(
                    child: InkWell(
                      onTap: () => showBadgeDetail(context, b),
                      borderRadius: Radii.innerR,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: Gap.sm,
                          horizontal: Gap.xs,
                        ),
                        child: Column(
                          children: [
                            // TODO: 실제 2D 뱃지 이미지로 교체
                            Container(
                              width: 62,
                              height: 62,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceBrand,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                b.icon,
                                size: 28,
                                color: AppColors.textBrandOnLight,
                              ),
                            ),
                            Gap.h8,
                            Text(
                              b.name,
                              textAlign: TextAlign.center,
                              style: AppType.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (more > 0) ...[
              Gap.h12,
              Text(
                '+$more개 더',
                style: AppType.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            Gap.h20,
            // 보상 — 에코 포인트만
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceBrand,
                borderRadius: Radii.innerR,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    TablerIcons.leaf,
                    size: 20,
                    color: AppColors.textBrandOnLight,
                  ),
                  Gap.w8,
                  Text.rich(
                    TextSpan(
                      text: '+$totalPoints',
                      style: AppType.title3
                          .copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textBrandOnLight,
                          )
                          .tabular,
                      children: [
                        TextSpan(
                          text: ' P',
                          style: AppType.label.copyWith(
                            color: AppColors.textBrandOnLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Gap.h20,
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
