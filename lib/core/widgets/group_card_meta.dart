import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';

/// 그룹 카드 부제 한 줄 — 홈·더보기·검색 3곳이 같은 규격을 쓴다.
///
/// 구성: [오늘 활동 점] '강도 · 멤버 N명' [· 잠금 승인]
///
/// 승인 후 가입 그룹에만 잠금 글리프 + '승인'을 붙인다. 자유 가입 그룹에는
/// 아무 표기도 넣지 않는다 — 표기가 없는 것이 곧 자유 가입이라는 뜻이다.
/// 접미는 줄어들지 않게 고정하고 본문만 말줄임한다. 그러지 않으면 그룹명이
/// 긴 카드에서 '승인'이 잘려 표기가 사라진다.
class GroupCardMeta extends StatelessWidget {
  /// 본문 문구. 승인 그룹이면 뒤에 구분점까지 포함된다 (Group.cardMeta).
  final String meta;

  /// 오늘 활동한 멤버가 있으면 앞에 잉크 점을 찍는다.
  final bool showActiveDot;

  /// 승인 후 가입 그룹 여부 (isPublic 의 반대).
  final bool approvalRequired;

  const GroupCardMeta({
    super.key,
    required this.meta,
    required this.showActiveDot,
    required this.approvalRequired,
  });

  @override
  Widget build(BuildContext context) {
    // 메타 규격 12.5px w500 (AppType.caption 은 13px 이라 크기만 낮춰 쓴다).
    final style = AppType.caption.copyWith(
      fontSize: 12.5,
      color: AppColors.gray500,
    );

    return Row(
      children: [
        if (showActiveDot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            meta,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (approvalRequired) ...[
          const SizedBox(width: 5),
          const Icon(TablerIcons.lock, size: 12, color: AppColors.gray500),
          const SizedBox(width: 3),
          Text('승인', style: style),
        ],
      ],
    );
  }
}
