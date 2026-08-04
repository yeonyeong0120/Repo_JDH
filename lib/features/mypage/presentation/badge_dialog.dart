import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';

/// ACT-08 뱃지 상세 모달
/// 획득/미획득 모두 클릭 가능. 획득조건은 항상 표시하고, 달성일자만 획득 시 노출.
///
/// 보상은 에코 포인트만 표시한다.
/// (줍댕이 꾸미기 기능은 범위에서 제외 — badge.dart 의 reward/slot 은 미사용)
Future<void> showBadgeDetail(BuildContext context, BadgeData badge) {
  final earned = BadgeRepo.isEarned(badge.id);
  final date = BadgeRepo.dateOf(badge.id);

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: Gap.xl4),
      shape: RoundedRectangleBorder(borderRadius: Radii.sheetR),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.xl2, Gap.xl2, Gap.xl2, Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 뱃지 (미획득이면 자물쇠)
            // TODO: 실제 2D 뱃지 이미지로 교체
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: earned ? AppColors.surfaceBrand : AppColors.neutral100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                earned ? badge.icon : Icons.lock_outline,
                size: 42,
                color: earned
                    ? AppColors.textBrandOnLight
                    : AppColors.neutral400,
              ),
            ),
            Gap.h16,
            Text(
              earned ? badge.name : '???',
              style: AppType.title2,
              textAlign: TextAlign.center,
            ),
            Gap.h4,
            Text(
              '${badge.tier.label} 등급',
              style: AppType.caption.copyWith(color: AppColors.textSecondary),
            ),
            Gap.h20,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.lg,
              ),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: Radii.innerR,
              ),
              child: Column(
                children: [
                  _row('획득조건', badge.condition),
                  Gap.h12,
                  _row('획득보상', '에코 포인트 ${badge.points} P'),
                  if (earned && date != null) ...[
                    Gap.h12,
                    _row('달성일자', date),
                  ],
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

Widget _row(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 66,
        child: Text(
          label,
          style: AppType.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      Gap.w8,
      Expanded(
        child: Text(
          value,
          style: AppType.caption.copyWith(color: AppColors.textPrimary),
        ),
      ),
    ],
  );
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
                    Symbols.eco,
                    size: 20,
                    fill: 1,
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
