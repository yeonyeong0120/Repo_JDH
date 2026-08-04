import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/shop/domain/shop_item.dart';
import 'package:repo_jdh/features/shop/data/shop_service.dart';

/// SHOP-03 쿠폰함 (미사용 / 사용완료·만료)
/// 위치 권장: lib/features/shop/presentation/coupon_screen.dart
class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});

  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponScreenState extends State<CouponScreen> {
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

  @override
  Widget build(BuildContext context) {
    final usable = _coupons.where((c) => c.usable).toList();
    final done = _coupons.where((c) => !c.usable).toList();

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
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
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
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        _label('미사용 쿠폰'),
                        const SizedBox(height: 10),
                        if (usable.isEmpty)
                          _empty('사용할 수 있는 쿠폰이 없어요')
                        else
                          ...usable.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _card(c),
                            ),
                          ),
                        const SizedBox(height: 24),
                        _label('사용 완료 및 만료'),
                        const SizedBox(height: 10),
                        if (done.isEmpty)
                          _empty('아직 없어요')
                        else
                          ...done.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _card(c),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    ),
  );

  Widget _empty(String t) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 24),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Text(
      t,
      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Opacity(opacity: dim ? 0.45 : 1, child: _thumb(56)),
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: dim
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.expiresText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: dim ? AppColors.textSecondary : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (dim)
              Text(
                c.statusText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// SHOP-04 쿠폰 상세 (바코드 + 사용 완료)
class CouponDetailScreen extends StatefulWidget {
  final Coupon coupon;
  const CouponDetailScreen({super.key, required this.coupon});

  @override
  State<CouponDetailScreen> createState() => _CouponDetailScreenState();
}

class _CouponDetailScreenState extends State<CouponDetailScreen> {
  bool _used = false;

  @override
  void initState() {
    super.initState();
    // 이미 사용한 쿠폰이면 처음부터 '사용 완료 취소' 상태로 열린다
    _used = widget.coupon.used;
  }

  // 바코드 영역을 이미지로 캡처하기 위한 키
  final GlobalKey _shotKey = GlobalKey();

  /// 바코드 영역을 PNG 바이트로 캡처
  Future<Uint8List?> _capture() async {
    try {
      final obj = _shotKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary) return null;
      final image = await obj.toImage(pixelRatio: 3); // 확대해도 안 깨지게
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// 공유 — 임시 파일로 저장한 뒤 시스템 공유 시트 호출
  Future<void> _share() async {
    final bytes = await _capture();
    if (bytes == null) {
      if (mounted) AppSnackBar.show(context, '쿠폰을 불러오지 못했어요');
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/coupon_${widget.coupon.id}.png');
      await file.writeAsBytes(bytes);
      // share_plus 11 이상에서 deprecated 경고가 뜨면 아래로 교체:
      //   SharePlus.instance.share(ShareParams(files: [XFile(file.path)]))
      await Share.shareXFiles([
        XFile(file.path),
      ], text: '${widget.coupon.name} 쿠폰');
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '공유하지 못했어요');
    }
  }

  /// 저장 — 기기 갤러리에 이미지로 저장
  Future<void> _save() async {
    final bytes = await _capture();
    if (bytes == null) {
      if (mounted) AppSnackBar.show(context, '쿠폰을 불러오지 못했어요');
      return;
    }
    try {
      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) AppSnackBar.show(context, '사진 접근 권한이 필요해요');
          return;
        }
      }
      await Gal.putImageBytes(bytes, album: '플로고');
      if (mounted) AppSnackBar.show(context, '갤러리에 저장했어요');
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '저장하지 못했어요');
    }
  }

  Future<void> _toggleUsed() async {
    final next = !_used;
    setState(() => _used = next);
    try {
      await ShopService.setUsed(widget.coupon.id, next);
      // 버튼 상태가 바로 바뀌므로 별도 안내는 띄우지 않음
    } catch (_) {
      if (mounted) {
        setState(() => _used = !next);
        AppSnackBar.show(context, '변경하지 못했어요');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.coupon;
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
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '쿠폰 상세',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  Center(
                    child: Opacity(
                      opacity: _used ? 0.4 : 1,
                      child: _thumb(150),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    c.brand,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 바코드 (이 영역이 공유·저장 시 캡처됨)
                  RepaintBoundary(
                    key: _shotKey,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Opacity(
                        opacity: _used ? 0.35 : 1,
                        child: Column(
                          children: [
                            Text(
                              c.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // TODO: 실제 바코드 규격이 필요하면 barcode_widget 패키지로 교체
                            SizedBox(
                              height: 76,
                              child: CustomPaint(
                                size: const Size(double.infinity, 76),
                                painter: _BarcodePainter(c.code),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c.code,
                              style: const TextStyle(
                                fontSize: 15,
                                letterSpacing: 3,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              c.expiresText,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _action(Icons.zoom_out_map, '확대', () => _zoom(c)),
                      const SizedBox(width: 36),
                      _action(Icons.share_outlined, '공유', _share),
                      const SizedBox(width: 36),
                      _action(Icons.download_outlined, '저장', _save),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '유효기간  |  ',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        c.expiresText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 사용 완료 / 되돌리기 (기간이 지난 쿠폰은 조작 불가)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: c.expired
                  ? Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        '기간이 만료된 쿠폰이에요',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _toggleUsed,
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _used ? AppColors.surface : AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _used
                                ? AppColors.border
                                : AppColors.primary,
                          ),
                        ),
                        child: Text(
                          _used ? '사용 완료 취소' : '사용완료',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _used
                                ? AppColors.textSecondary
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
            ),
            // 버튼 아래 안내
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              child: Text(
                c.expired
                    ? '유효기간이 지나 사용할 수 없어요.'
                    : _used
                    ? '이미 사용한 쿠폰이에요. 실수로 눌렀다면 되돌릴 수 있어요.'
                    : '매장에서 바코드를 보여준 뒤 사용 완료를 눌러주세요.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // 바코드 확대 (매장에서 스캔하기 쉽게)
  void _zoom(Coupon c) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 150,
                child: CustomPaint(
                  size: const Size(double.infinity, 150),
                  painter: _BarcodePainter(c.code),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                c.code,
                style: const TextStyle(
                  fontSize: 20,
                  letterSpacing: 4,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 공통 썸네일 — TODO: 실제 상품 이미지로 교체
Widget _thumb(double size) {
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.surfaceBrand,
      borderRadius: BorderRadius.circular(size * 0.16),
    ),
    child: Icon(
      Icons.card_giftcard,
      size: size * 0.4,
      color: AppColors.green400,
    ),
  );
}

/// 숫자 코드로 막대를 그리는 간단한 바코드
/// 실제 스캔 규격(EAN-13 등)이 필요하면 barcode_widget 패키지로 교체할 것
class _BarcodePainter extends CustomPainter {
  final String code;
  const _BarcodePainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    if (code.isEmpty) return;
    final paint = Paint()..color = Colors.black;

    // 숫자마다 굵기 다른 막대 + 여백을 반복
    final bars = <double>[];
    for (final ch in code.split('')) {
      final n = int.tryParse(ch) ?? 0;
      bars.add(1 + (n % 3)); // 막대 굵기 1~3
      bars.add(1 + ((n + 1) % 2)); // 여백 1~2
    }
    final unit = size.width / bars.fold<double>(0, (a, b) => a + b);

    double x = 0;
    for (int i = 0; i < bars.length; i++) {
      final w = bars[i] * unit;
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter old) => old.code != code;
}
