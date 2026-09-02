import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';

/// 그룹 대표 이미지 썸네일. 그룹 목록·정보 팝업 등에서 공통 사용.
/// 대표 사진이 없으면 회색 원형 배경 + 사람 아이콘으로 대체.
class GroupThumb extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const GroupThumb({super.key, required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: Radii.tileR,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null
          ? Icon(TablerIcons.users, size: size * 0.42, color: AppColors.neutral400)
          : Image.network(imageUrl!, fit: BoxFit.cover),
    );
  }
}
