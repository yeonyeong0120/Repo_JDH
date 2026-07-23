import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/shop/domain/shop_item.dart';
import 'package:repo_jdh/features/shop/data/shop_service.dart';
import 'package:repo_jdh/features/shop/presentation/coupon_screen.dart';

/// SHOP-01 에코 포인트 상점 (+ SHOP-02 구매 컨펌 모달)
/// 위치 권장: lib/features/shop/presentation/shop_screen.dart
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final PageController _pageController = PageController();
  int _index = 0; // 현재 카테고리 인덱스
  int _points = 0;
  bool _loading = true;

  ShopCategory get _category => ShopCategory.values[_index];

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPoints() async {
    int p = 0;
    try {
      p = await ShopService.myPoints();
    } catch (_) {
      // 실패 시 0
    }
    if (!mounted) return;
    setState(() {
      _points = p;
      _loading = false;
    });
  }

  Future<void> _openCoupons() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CouponScreen()),
    );
    _loadPoints();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            _pointsLine(),
            const SizedBox(height: 14),
            _categoryBar(),
            const SizedBox(height: 4),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final c in ShopCategory.values) _productList(c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 상단 바 ─────────────────────────
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              '에코 포인트 상점',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: '쿠폰함',
            icon: const Icon(
              Symbols.confirmation_number,
              weight: 500,
              size: 24,
            ),
            color: AppColors.primary,
            onPressed: _openCoupons,
          ),
        ],
      ),
    );
  }

  // ───────── 보유 포인트 배너 (지갑처럼 — 화면의 중심 정보) ─────────
  Widget _pointsLine() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Row(
        children: [
          const Text(
            '사용 가능한 포인트',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const Spacer(),
          const Icon(
            Symbols.eco,
            weight: 600,
            size: 17,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            _loading ? '-' : '${_format(_points)} P',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 카테고리 ─────────────────────────
  Widget _categoryBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          for (int i = 0; i < ShopCategory.values.length; i++)
            Expanded(child: _categoryChip(i)),
        ],
      ),
    );
  }

  Widget _categoryChip(int i) {
    final c = ShopCategory.values[i];
    final on = _index == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.primary : AppColors.cardBG,
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Icon(
                c.icon,
                size: 21,
                color: on ? Colors.white : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              c.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: on ? AppColors.primaryDeep : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 상품 목록 ─────────────────────────
  Widget _productList(ShopCategory c) {
    final items = ShopService.byCategory(c);
    if (items.isEmpty) {
      return const Center(
        child: Text(
          '준비 중인 카테고리예요',
          style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _itemCard(items[i]),
    );
  }

  // 카드 전체가 교환 버튼 역할 (행마다 버튼을 두면 화면이 시끄러워짐)
  Widget _itemCard(ShopItem item) {
    final enough = _points >= item.price;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _confirmExchange(item),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상품 이미지
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.appBG,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  // TODO: 실제 상품 이미지(Image.network)로 교체
                  child: Icon(
                    Symbols.redeem,
                    weight: 300,
                    size: 40,
                    color: enough ? AppColors.primaryLight : AppColors.divider,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.brand,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Symbols.eco,
                        weight: 600,
                        size: 15,
                        color: enough
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _format(item.price),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: enough
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
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

  // TODO: 실제 상품 이미지(Image.network)로 교체
  Widget _thumb(double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.appBG,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        Symbols.redeem,
        weight: 400,
        size: size * 0.42,
        color: AppColors.primaryLight,
      ),
    );
  }

  // ───────────────── SHOP-02 구매 컨펌 모달 ─────────────────
  Future<void> _confirmExchange(ShopItem item) async {
    if (_points < item.price) {
      AppSnackBar.show(context, '포인트가 조금 더 필요해요');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardBG,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _thumb(110),
              const SizedBox(height: 16),
              Text(
                item.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '이 상품으로 교환할까요?',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.appBG,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _summaryRow('사용 포인트', '-${_format(item.price)} P'),
                    const SizedBox(height: 8),
                    _summaryRow(
                      '교환 후 잔여',
                      '${_format(_points - item.price)} P',
                      strong: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.appBG,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          '아니오',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          '교환하기',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;

    try {
      await ShopService.exchange(item);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '교환하지 못했어요');
      return;
    }
    await _loadPoints();
    if (mounted) _showDone();
  }

  Widget _summaryRow(String label, String value, {bool strong = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 15 : 13,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
            color: strong ? AppColors.primaryDeep : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ───────────────────── 교환 완료 모달 ─────────────────────
  void _showDone() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardBG,
        insetPadding: const EdgeInsets.symmetric(horizontal: 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPale,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '교환되었습니다',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '쿠폰함에서 바로 사용할 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.appBG,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          '계속 둘러보기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _openCoupons();
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          '쿠폰함 가기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
