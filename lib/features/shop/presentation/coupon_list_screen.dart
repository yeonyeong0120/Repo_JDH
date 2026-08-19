import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/shop/data/shop_service.dart';
import 'package:repo_jdh/features/shop/domain/shop_item.dart';
import 'package:repo_jdh/features/shop/presentation/coupon_detail_screen.dart';
import 'package:repo_jdh/features/shop/presentation/widgets/coupon_thumb.dart';

/// SHOP-03 내 쿠폰함 (사용 가능 / 사용 완료 탭)
class CouponListScreen extends StatefulWidget {
  const CouponListScreen({super.key});

  @override
  State<CouponListScreen> createState() => _CouponListScreenState();
}

class _CouponListScreenState extends State<CouponListScreen> {
  List<Coupon> _coupons = [];
  bool _loading = true;
  int _tab = 0; // 0 사용 가능 / 1 사용 완료

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

  @override
  Widget build(BuildContext context) {
    final usable = _coupons.where((c) => c.usable).toList();
    final done = _coupons.where((c) => !c.usable).toList();
    final list = _tab == 0 ? usable : done;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(TablerIcons.chevronLeft, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '내 쿠폰함',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            _tabs(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.actionPrimary,
                        strokeWidth: 2,
                      ),
                    )
                  : list.isEmpty
                  ? _empty(_tab == 0 ? '사용할 수 있는 쿠폰이 없어요' : '사용 완료·만료된 쿠폰이 없어요')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _card(list[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 사용 가능 / 사용 완료 탭 ──
  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _tabItem('사용 가능', 0),
          const SizedBox(width: 22),
          _tabItem('사용 완료', 1),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _tabItem(String label, int i) {
    final on = _tab == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                color: on ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          // 활성 탭 밑줄
          Container(
            height: 2.5,
            width: 52,
            decoration: BoxDecoration(
              color: on ? AppColors.actionPrimary : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String t) => Center(
    child: Text(
      t,
      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
    ),
  );

  Widget _card(Coupon c) {
    final dim = !c.usable;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CouponDetailScreen(coupon: c)),
        );
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Opacity(opacity: dim ? 0.5 : 1, child: const CouponThumb(size: 64)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.brand,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: dim
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statusPill(c),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          c.expiresText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상태 배지 — 사용 가능(초록) / 사용 완료·기간 만료(회색)
  Widget _statusPill(Coupon c) {
    final usable = c.usable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: usable ? AppColors.green100 : AppColors.neutral100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        usable ? '사용 가능' : c.statusText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: usable ? AppColors.textBrandOnLight : AppColors.textSecondary,
        ),
      ),
    );
  }
}
