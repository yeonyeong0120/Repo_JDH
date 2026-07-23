import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';

/// ACT-08 뱃지 상세 모달
/// 획득/미획득 모두 클릭 가능. 획득조건은 항상 표시하고, 달성일자만 획득 시 노출.
Future<void> showBadgeDetail(BuildContext context, BadgeData badge) {
  final earned = BadgeRepo.isEarned(badge.id);
  final date = BadgeRepo.dateOf(badge.id);

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.cardBG,
      insetPadding: const EdgeInsets.symmetric(horizontal: 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 뱃지 (미획득이면 회색 실루엣)
            // TODO: 실제 2D 뱃지 이미지로 교체
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: earned ? AppColors.primaryPale : AppColors.divider,
                shape: BoxShape.circle,
              ),
              child: Icon(
                earned ? badge.icon : Icons.lock_outline,
                size: 42,
                color: earned ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              earned ? badge.name : '???',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${badge.tier.label} 등급',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            // 정보 (라벨 : 값)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.appBG,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _row('획득조건', badge.condition),
                  const SizedBox(height: 10),
                  _row('획득보상', '${badge.reward} · ${badge.points} P'),
                  if (earned && date != null) ...[
                    const SizedBox(height: 10),
                    _row('달성일자', date),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
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
        width: 62,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      const Text(
        ':  ',
        style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
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
      backgroundColor: AppColors.cardBG,
      insetPadding: const EdgeInsets.symmetric(horizontal: 34),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              badges.length == 1 ? '뱃지 획득!' : '뱃지 ${badges.length}개 획득!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDeep,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            // 획득한 뱃지 (최대 3개 노출, 탭하면 상세)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in shown)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => showBadgeDetail(context, b),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        children: [
                          // TODO: 실제 2D 뱃지 이미지로 교체
                          Container(
                            width: 62,
                            height: 62,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryPale,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              b.icon,
                              size: 28,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            b.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (more > 0) ...[
              const SizedBox(height: 10),
              Text(
                '+$more개 더',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 18),
            // 보상 요약
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.appBG,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _reward(
                    Icons.card_giftcard,
                    AppColors.textSecondary,
                    badges.length == 1
                        ? '${badges.first.reward} (줍댕이 꾸미기)'
                        : '꾸미기 아이템 ${badges.length}개',
                  ),
                  const SizedBox(height: 10),
                  _reward(Symbols.eco, AppColors.primary, '+$totalPoints P'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _reward(IconData icon, Color color, String text) {
  return Row(
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
      ),
    ],
  );
}
