import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 쿠폰 썸네일 — '상품 이미지' 플레이스홀더 (실제 이미지 준비 시 교체).
///
/// 쿠폰함(CouponListScreen)과 쿠폰 상세(CouponDetailScreen) 양쪽에서 쓴다.
/// 크기만 달라지므로 정의는 이 파일 한 곳에만 둔다 — 화면마다 복제하면
/// 나중에 한쪽만 바뀌어 모양이 어긋난다.
class CouponThumb extends StatelessWidget {
  /// 정사각 한 변의 길이. 모서리 반경·글자 크기가 여기에 비례한다.
  final double size;

  const CouponThumb({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      child: Text(
        '상품\n이미지',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size * 0.14,
          height: 1.3,
          color: AppColors.neutral400,
        ),
      ),
    );
  }
}
