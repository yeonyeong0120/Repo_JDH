import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
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

  /// true면 caption을 제목 아래가 아니라 제목 오른쪽에 나란히 붙인다.
  final bool captionInline;

  const SectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.onMore,
    this.moreLabel = '더보기',
    this.captionInline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sectionHead),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: (captionInline && caption != null)
                // 제목 오른쪽에 caption 나란히 (베이스라인 정렬)
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(title, style: AppType.title2),
                      Gap.w8,
                      Flexible(
                        child: Text(
                          caption!,
                          style: AppType.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Column(
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
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBrandOnLight,
                      ),
                    ),
                    const Icon(
                      TablerIcons.chevronRight,
                      size: 20,
                      color: AppColors.textBrandOnLight,
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
  final String moreLabel;
  final Widget child;

  /// true면 caption을 제목 오른쪽에 나란히 붙인다.
  final bool captionInline;

  /// 마지막 섹션이면 true — 아래 여백을 없앤다.
  final bool last;

  const AppSection({
    super.key,
    required this.title,
    required this.child,
    this.caption,
    this.onMore,
    this.moreLabel = '더보기',
    this.captionInline = false,
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
          SectionHeader(
            title: title,
            caption: caption,
            onMore: onMore,
            moreLabel: moreLabel,
            captionInline: captionInline,
          ),
          child,
        ],
      ),
    );
  }
}

/// 상단 워시 + 헤더 글자가 은근하게 떠오르는 등장 애니메이션.
/// 워시는 페이드만(1.3초), 글자는 10px 아래에서 올라오며 페이드(1.15초).
/// 화면 진입 때 한 번만 재생된다.
class HeaderRise extends StatefulWidget {
  final Widget child;

  /// true 면 페이드만 (워시처럼 움직이면 안 되는 면).
  final bool fadeOnly;
  const HeaderRise({super.key, required this.child, this.fadeOnly = false});

  @override
  State<HeaderRise> createState() => _HeaderRiseState();
}

class _HeaderRiseState extends State<HeaderRise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.fadeOnly ? 1000 : 800),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 홈과 동일하게 '밑에서 위로' 떠오르는 결(easeOutCubic 페이드+상승).
    // 스케일(확대)은 정면에서 다가오는 느낌이라 쓰지 않고, 상승폭만 키워 더 극적으로.
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) {
        final t = curve.value;
        return Opacity(
          opacity: t,
          child: widget.fadeOnly
              ? child
              : Transform.translate(
                  offset: Offset(0, (1 - t) * 36),
                  child: child,
                ),
        );
      },
      child: widget.child,
    );
  }
}

/// 헤더 초록 워시가 홈처럼 위→아래로 '차오르며(pour)' 등장한다.
/// 배경(워시)만 애니메이션하고, 그 위 콘텐츠(child)는 그대로 둔다.
/// child 는 배경 없이 padding + 내용만 넘긴다(그라데이션은 이 위젯이 그린다).
class HeaderWashPour extends StatefulWidget {
  final Widget child;
  const HeaderWashPour({super.key, required this.child});

  @override
  State<HeaderWashPour> createState() => _HeaderWashPourState();
}

class _HeaderWashPourState extends State<HeaderWashPour>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // 홈 pour 와 동일한 커브 — 위에서 아래로 부드럽게 차오른다.
        final pour = const Cubic(0.33, 0.72, 0.24, 1.0).transform(_c.value);
        return Stack(
          children: [
            // 배경 워시: 위(topCenter) 기준으로 세로로 스케일 → 아래로 채워짐
            Positioned.fill(
              child: Transform(
                alignment: Alignment.topCenter,
                transform:
                    Matrix4.diagonal3Values(1, pour.clamp(0.0001, 1.0), 1),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.washTop,
                        AppColors.washMid,
                        AppColors.washEnd,
                      ],
                      stops: [0.0, 0.62, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}
