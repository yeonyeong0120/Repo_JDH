import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';

/// 섹션 헤더. "내 그룹", "진행 중인 퀘스트" 처럼 목록 위에 오는 제목.
/// 항목 제목(title3)과 굵기·크기를 반드시 구분해야 위계가 생긴다.
class SectionHeader extends StatelessWidget {
  final String title;

  /// 제목 옆 보조 설명 (선택)
  final String? caption;

  /// "더보기" 화살표. onMore를 주면 표시된다.
  final VoidCallback? onMore;
  final String moreLabel;

  const SectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.onMore,
    this.moreLabel = '더보기',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sectionHead),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppType.title2),
                if (caption != null) ...[
                  Gap.h4,
                  Text(
                    caption!,
                    style: AppType.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onMore != null)
            // 텍스트 + 화살표를 하나의 48 터치 타깃으로 묶는다.
            InkWell(
              onTap: onMore,
              borderRadius: Radii.fullR,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm,
                  vertical: Gap.md,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      moreLabel,
                      style: AppType.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.neutral400,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 섹션 하나(헤더 + 내용)를 감싸 아래 여백까지 책임진다.
/// 화면에서 SizedBox로 간격을 직접 주지 않게 하려는 위젯.
class AppSection extends StatelessWidget {
  final String title;
  final String? caption;
  final VoidCallback? onMore;
  final Widget child;

  /// 마지막 섹션이면 true — 아래 여백을 없앤다.
  final bool last;

  const AppSection({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.onMore,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : Gap.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionHeader(title: title, caption: caption, onMore: onMore),
          child,
        ],
      ),
    );
  }
}
