import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/shop/data/shop_service.dart';
import 'package:repo_jdh/features/shop/domain/shop_item.dart';
import 'package:repo_jdh/features/shop/presentation/coupon_detail_screen.dart';

/// SHOP-03 쿠폰함 (Startline 목업 구조)
/// 사용 가능 쿠폰이 위, 사용 완료/만료 쿠폰은 아래에 흐리게. 카드 탭·"사용하기" → 쿠폰 상세.
class CouponListScreen extends StatefulWidget {
  const CouponListScreen({super.key});

  @override
  State<CouponListScreen> createState() => _CouponListScreenState();
}

class _CouponListScreenState extends State<CouponListScreen> {
  List<Coupon> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Coupon> list = [];
    try {
      list = await ShopService.myCoupons();
    } catch (_) {
      // 실패 시 빈 목록
    }
    if (!mounted) return;
    setState(() {
      _coupons = list;
      _loading = false;
    });
  }

  Future<void> _openDetail(Coupon c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CouponDetailScreen(coupon: c)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    // 사용 가능 → 사용 완료/만료 순으로 정렬
    final usable = _coupons.where((c) => c.usable).toList();
    final done = _coupons.where((c) => !c.usable).toList();
    final ordered = [...usable, ...done];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(usable.length),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.actionPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : ordered.isEmpty
                  ? _empty()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      itemCount: ordered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _card(ordered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 상단 바: 뒤로 + '쿠폰함' + 우측 '사용 가능 N' ──
  Widget _topBar(int usableCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 22, 12),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                TablerIcons.chevronLeft,
                size: 24,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '쿠폰함',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '사용 가능 $usableCount',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }

  // 쿠폰 이름 키워드로 아이콘 선택 (쿠폰 데이터에 종류 필드가 없어 이름 기반으로 매핑)
  IconData _couponIcon(String name) {
    if (name.contains('커피') || name.contains('음료') || name.contains('카페')) {
      return TablerIcons.coffee;
    }
    if (name.contains('텀블러') || name.contains('컵')) return TablerIcons.cup;
    if (name.contains('에코백') || name.contains('굿즈')) return TablerIcons.gift;
    return TablerIcons.ticket;
  }

  Widget _empty() => const Center(
    child: Text(
      '쿠폰함이 비어 있어요',
      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
    ),
  );

  // ── 쿠폰 카드 (아이콘 + 이름/유효기한 + 사용하기 버튼) ──
  Widget _card(Coupon c) {
    final used = !c.usable;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: used ? AppColors.neutral50 : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: used ? AppColors.line100 : AppColors.gray200,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // 아이콘 사각형 — 사용 가능=라임 / 사용 완료=회색
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: used ? AppColors.surfaceMuted : AppColors.lime,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _couponIcon(c.name),
                size: 23,
                color: used ? AppColors.gray400 : AppColors.ink,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: used ? AppColors.gray400 : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    used ? c.statusText : c.expiresText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 사용하기 / 사용됨 pill 버튼
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: used ? AppColors.surfaceMuted : AppColors.ink,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                used ? '사용됨' : '사용하기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: used ? AppColors.gray400 : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
