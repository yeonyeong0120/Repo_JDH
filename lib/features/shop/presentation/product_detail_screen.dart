import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/shop/domain/shop_item.dart';
import 'package:repo_jdh/features/shop/data/shop_service.dart';
import 'package:repo_jdh/features/shop/presentation/coupon_list_screen.dart';

/// SHOP-27 상품 상세 (Startline 목업 구조)
/// 상품 이미지 + 브랜드/이름/포인트가 + 안내 항목 + 하단 '교환하기' CTA.
/// 진입: 포인트 샵(shop_screen) 상품 카드 탭 → 이 화면 push.
/// 교환 로직은 shop_screen과 동일하게 ShopService.exchange 를 재사용한다.
class ProductDetailScreen extends StatefulWidget {
  /// 실제 모델(ShopItem)을 그대로 받는다.
  final ShopItem item;

  /// 목업의 '인기' 뱃지 — 상품 데이터에 인기 필드가 없어 그리드에서 위치로 전달.
  final bool popular;

  const ProductDetailScreen({super.key, required this.item, this.popular = false});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _points = 0;
  bool _loading = true;
  bool _exchanging = false; // 교환 요청 중복 방지

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
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _image(item),
                    const SizedBox(height: 20),
                    // 브랜드 (실데이터: item.brand)
                    Text(
                      item.brand,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 상품명 (실데이터: item.name)
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _priceRow(item),
                    const SizedBox(height: 22),
                    // 안내 항목 — 상품별 안내 데이터가 모델에 없어 정적 플레이스홀더.
                    _infoRow(TablerIcons.calendar, '교환 후 30일 이내 사용'),
                    _infoDivider(),
                    _infoRow(TablerIcons.mapPin, '전국 제휴 매장 사용 가능'),
                    _infoDivider(),
                    _infoRow(TablerIcons.cup, '모바일 쿠폰으로 발급돼요'),
                  ],
                ),
              ),
            ),
            _bottomCta(item),
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
              '교환하기',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // 좌측 아이콘과 시각 균형용 여백
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  // ─────────────── 상품 이미지 (좌상단 '인기' 뱃지) ───────────────
  Widget _image(ShopItem item) {
    final url = item.imageUrl;
    Widget placeholder() => const Center(
      child: Text(
        '상품 이미지',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.gray350,
        ),
      ),
    );
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 260,
            width: double.infinity,
            color: AppColors.surfaceSoft,
            child: (url == null || url.isEmpty)
                ? placeholder()
                : Image.network(
                    url,
                    height: 260,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => placeholder(),
                  ),
          ),
        ),
        if (widget.popular)
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '인기',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.limeOn,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────── 포인트가 + 보유 잔액 ───────────────
  Widget _priceRow(ShopItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          _format(item.price),
          style: const TextStyle(
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'P',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        // 보유 잔액 (실데이터: ShopService.myPoints)
        Text(
          _loading ? '보유 -' : '보유 ${_format(_points)}P',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.gray500,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.gray500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoDivider() => const Divider(height: 1, color: AppColors.line100);

  // ─────────────── 하단 교환 CTA (차콜 버튼) ───────────────
  Widget _bottomCta(ShopItem item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: GestureDetector(
        onTap: _exchanging ? null : () => _confirmExchange(item),
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(TablerIcons.gift, size: 20, color: AppColors.lime),
              const SizedBox(width: 9),
              Text(
                '${_format(item.price)}P로 교환',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────── 교환 확인 → 실행 → 완료 (shop_screen 로직 미러) ─────────────────
  Future<void> _confirmExchange(ShopItem item) async {
    if (_loading) return;
    if (_points < item.price) {
      AppSnackBar.show(context, '포인트가 조금 더 필요해요');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CenterDialog(
        icon: TablerIcons.gift,
        title: '${_format(item.price)}P로 교환할까요?',
        message:
            '교환 후 잔액 ${_format(_points - item.price)}P · 쿠폰함에 30일간 보관돼요',
        cancelText: '취소',
        confirmText: '교환하기',
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );

    if (ok != true) return;

    setState(() => _exchanging = true);
    try {
      await ShopService.exchange(item);
    } catch (_) {
      if (mounted) {
        setState(() => _exchanging = false);
        AppSnackBar.show(context, '교환하지 못했어요');
      }
      return;
    }
    await _loadPoints();
    if (!mounted) return;
    setState(() => _exchanging = false);
    _showDone(item);
  }

  void _showDone(ShopItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CenterDialog(
        icon: TablerIcons.ticket,
        title: '교환 완료!',
        message: '${item.name}이(가) 쿠폰함에 담겼어요',
        cancelText: '닫기',
        confirmText: '쿠폰함 보기',
        onCancel: () => Navigator.pop(ctx),
        onConfirm: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const CouponListScreen()),
          );
        },
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

/// 중앙 다이얼로그 — 라임 원형 아이콘 + 제목 + 메시지 + 취소/확인 버튼.
/// shop_screen 의 buy / buyDone 오버레이와 동일한 형태(미러).
class _CenterDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _CenterDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.cancelText,
    required this.confirmText,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 29, color: AppColors.ink),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                height: 1.4,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Text(
                        cancelText,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gray700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: GestureDetector(
                    onTap: onConfirm,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          fontSize: 15.5,
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
    );
  }
}
