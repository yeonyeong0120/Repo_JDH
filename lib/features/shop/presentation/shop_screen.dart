import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/shop/domain/shop_item.dart';
import 'package:repo_jdh/features/shop/data/shop_service.dart';
import 'package:repo_jdh/features/shop/data/point_history_service.dart';
import 'package:repo_jdh/features/shop/presentation/coupon_list_screen.dart';
import 'package:repo_jdh/features/shop/presentation/product_detail_screen.dart';

/// SHOP-01 포인트 샵 (Startline 목업 구조)
/// 차콜 잔액 카드 + 카테고리 칩 + 2열 상품 그리드 → 탭 시 교환 확인/완료 다이얼로그.
/// 위치 권장: lib/features/shop/presentation/shop_screen.dart
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _index = 0; // 현재 카테고리 인덱스
  int _points = 0;
  // 잔액 카드 서브텍스트 — 지금 포인트로 바꿀 수 있는 상품 수와 이번 달 적립
  int _exchangeable = 0;
  int? _monthEarned;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
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
      _exchangeable =
          ShopService.catalog.where((i) => i.price <= p).length;
      _loading = false;
    });
    try {
      final earned = await PointHistoryService.earnedThisMonth();
      if (mounted) setState(() => _monthEarned = earned);
    } catch (_) {
      // 실패 시 적립 문구를 빼고 교환 가능 개수만 보여준다
    }
  }

  Future<void> _openCoupons() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CouponListScreen()),
    );
    _loadPoints();
  }

  @override
  Widget build(BuildContext context) {
    final items = ShopService.byCategory(ShopCategory.values[_index]);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            _balanceCard(),
            const SizedBox(height: 20),
            _categoryTabs(),
            const SizedBox(height: 18),
            Expanded(child: _grid(items)),
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
              '포인트 샵',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openCoupons,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                TablerIcons.ticket,
                size: 21,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── 차콜 잔액 카드 (라임 블롭 + 큰 라임 숫자) ───────────────
  Widget _balanceCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: [
          // 우하단 라임 블롭 (은은한 포인트)
          Positioned(
            right: -30,
            bottom: -40,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 120, end: 0),
              duration: const Duration(milliseconds: 2600),
              curve: const Cubic(0.12, 0.72, 0.24, 1),
              builder: (context, dx, child) =>
                  Transform.translate(offset: Offset(dx, 0), child: child),
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.lime.withValues(alpha: 0.13),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '내 포인트',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                    color: Color(0xFF9BA29C),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _loading ? '-' : _format(_points),
                      style: const TextStyle(
                        fontSize: 44,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                        color: AppColors.lime,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'P',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.lime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _monthEarned == null
                      ? '교환 가능 $_exchangeable개'
                      : '이번 달 +${_format(_monthEarned!)}P · 교환 가능 $_exchangeable개',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9BA29C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── 카테고리 칩 탭 (가로 스크롤) ───────────────
  Widget _categoryTabs() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: ShopCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _categoryChip(i),
      ),
    );
  }

  Widget _categoryChip(int i) {
    final on = _index == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _index = i),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: on ? AppColors.ink : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          ShopCategory.values[i].label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
            color: on ? Colors.white : AppColors.gray500,
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 상품 그리드 (2열) ─────────────────────────
  Widget _grid(List<ShopItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          '준비 중인 카테고리예요',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        // 카드끼리 붙어 보이지 않게 좌우·위아래 여백을 넉넉히
        crossAxisSpacing: 14,
        mainAxisSpacing: 26,
        // 사진 + 이름 + 가격
        mainAxisExtent: 196,
      ),
      itemCount: items.length,
      // 목업처럼 첫 카드에만 '인기' 뱃지 (상품 데이터에 인기 필드가 없어 위치로 표시)
      itemBuilder: (_, i) => _itemCard(items[i], popular: i == 0),
    );
  }

  Widget _itemCard(ShopItem item, {bool popular = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openDetail(item, popular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라운드 상품 이미지 + 좌상단 '인기' 뱃지
          Stack(
            children: [
              _thumb(item, 122),
              if (popular)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '인기',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.limeOn,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _format(item.price),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 3),
              const Text(
                'P',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 상품 이미지 자리(라운드 박스) — 실제 이미지 있으면 표시, 없으면 '상품 이미지' 플레이스홀더
  // TODO: 상품 이미지가 준비되면 imageUrl 을 채워 Image.network 로 렌더
  Widget _thumb(ShopItem item, double height) {
    final url = item.imageUrl;
    Widget placeholder() => const Center(
      child: Text(
        '상품 이미지',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.gray350,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        width: double.infinity,
        color: AppColors.surfaceSoft,
        child: (url != null && url.isNotEmpty)
            ? Image.network(
                url,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder(),
              )
            // 실제 상품 사진이 없어 넣어둔 목업 사진
            : (item.imageAsset == null
                  ? placeholder()
                  : Image.asset(
                      item.imageAsset!,
                      height: height,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => placeholder(),
                    )),
      ),
    );
  }

  // ───────────────── 상품 상세 팝업 (상품 카드 → 가운데 팝업) ─────────────────
  // 팝업 안에서 교환 로직(ShopService.exchange)을 그대로 수행한다.
  // 닫히면 포인트를 다시 불러와 잔액 카드를 갱신한다.
  Future<void> _openDetail(ShopItem item, bool popular) async {
    await showProductDialog(context, item: item, popular: popular);
    _loadPoints();
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
