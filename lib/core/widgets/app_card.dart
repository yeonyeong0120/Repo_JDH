import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';

/// 카드 표면 종류.
enum CardTone {
  /// 흰 배경 + 헤어라인. 기본.
  plain,

  /// 브랜드 틴트. 화면당 1개만.
  brand,
}

/// 앱 전체 카드의 단일 소스.
/// v2: 선 대신 부드러운 그림자로 띄운다 (레퍼런스 어휘).
/// 틴트 카드(brand)는 그림자 없이 색면으로만 구분한다.
/// 탭 가능한 카드는 onTap을 넘기면 잉크 리플과 최소 높이가 자동 적용된다.
class AppCard extends StatelessWidget {
  final Widget child;
  final CardTone tone;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const AppCard({
    super.key,
    required this.child,
    this.tone = CardTone.plain,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final bool brand = tone == CardTone.brand;

    final Widget body = Padding(
      padding: padding ?? Gap.card,
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Radii.cardR,
        boxShadow: brand ? null : AppColors.cardShadow,
      ),
      child: Material(
        color: brand ? AppColors.surfaceBrand : AppColors.surface,
        borderRadius: Radii.cardR,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.cardR,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Touch.min),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// 아이콘 타일 + 제목/부제 + 오른쪽 화살표로 구성된 리스트형 카드.
/// 메뉴 · 그룹 목록 · 활동 기록 등 반복 리스트에 사용.
class AppListCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final bool chevron;
  final VoidCallback? onTap;

  const AppListCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.chevron = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.lg,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, Gap.w16],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: t.titleMedium),
                if (subtitle != null) ...[
                  Gap.h4,
                  Text(
                    subtitle!,
                    style: t.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailingText != null) ...[
            Gap.w8,
            Text(
              trailingText!,
              style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (chevron) ...[
            Gap.w8,
            const Icon(
              Icons.chevron_right_rounded,
              size: Touch.icon,
              color: AppColors.neutral400,
            ),
          ],
        ],
      ),
    );
  }
}

/// 카드 왼쪽에 놓는 정사각 아이콘 타일.
/// color를 주면 그 색의 연한 틴트 배경 + 원색 아이콘.
class AppIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AppIconTile({
    super.key,
    required this.icon,
    this.color = AppColors.green600,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.tint(color),
        borderRadius: Radii.tileR,
      ),
      child: Icon(icon, size: Touch.icon, color: color),
    );
  }
}
