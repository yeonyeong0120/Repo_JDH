import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';

/// 그룹 대표 이미지 썸네일. 그룹 목록·정보 팝업 등에서 공통 사용.
/// 대표 사진이 없으면 기본 마스코트 썸네일(ploggo_default)로 대체.
class GroupThumb extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const GroupThumb({super.key, required this.imageUrl, required this.size});

  // 썸네일 미설정 시 기본 이미지 (assets/images/ 에 넣어주세요)
  static const String defaultAsset = 'assets/images/ploggo_default.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      // 기본 썸네일도 '박스'로 보이도록 옅은 회색 면 + 라운드.
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: Radii.tileR,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imageUrl == null
          // 기본 썸네일 — 이미지가 없으면 박스 가운데 사진 아이콘으로 폴백.
          // (Center 로 감싸지 않으면 아이콘이 좌상단에 붙어 '아이콘만' 있는 것처럼 보인다)
          ? Image.asset(
              defaultAsset,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                TablerIcons.photo,
                size: size * 0.4,
                color: AppColors.gray400,
              ),
            )
          // 가로·세로 모두 썸네일을 꽉 채운다(비율 유지, 넘치면 크롭).
          : Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
    );
  }
}
