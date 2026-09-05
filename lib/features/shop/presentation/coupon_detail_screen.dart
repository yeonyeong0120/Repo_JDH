import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/shop/data/shop_service.dart';
import 'package:repo_jdh/features/shop/domain/shop_item.dart';
import 'package:repo_jdh/features/shop/presentation/widgets/coupon_thumb.dart';

/// SHOP-04 쿠폰 상세 (바코드 + 사용 완료 처리) — Startline 목업 바코드 시트 구조.
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
    // 이미 사용한 쿠폰이면 처음부터 '사용 취소' 상태로 열린다
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
      backgroundColor: AppColors.surface,
      body: Stack(
        clipBehavior: Clip.none, // 오프스크린(-4000) 캡처 카드가 클립되지 않도록
        children: [
          // 갤러리 저장·공유용 오프스크린 캡처 카드(사진+상품명+유효기한+바코드 한 장)
          Positioned(left: -4000, top: 0, child: _captureCard(c)),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    children: [
                      _mainCard(c),
                      const SizedBox(height: 16),
                      _guideCard(c),
                    ],
                  ),
                ),
                // 하단 고정: 공유 / 저장 + 사용 완료 처리
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _outlinedAction(
                              TablerIcons.share,
                              '공유',
                              _share,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _outlinedAction(
                              TablerIcons.download,
                              '저장',
                              _save,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _bottomButton(c),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
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
          const Text(
            '쿠폰',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 저장·공유 전용 캡처 카드 (차콜 헤더 + 사진 + 상품명 + 유효기한 + 바코드) ──
  Widget _captureCard(Coupon c) {
    return RepaintBoundary(
      key: _shotKey,
      child: Container(
        width: 340,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 차콜 헤더 + 라임 아이콘
            Container(
              width: double.infinity,
              color: AppColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: const [
                  Icon(TablerIcons.ticket, size: 18, color: AppColors.lime),
                  SizedBox(width: 8),
                  Text(
                    '플로고 포인트 쿠폰',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CouponThumb(size: 64),
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
                            const SizedBox(height: 3),
                            Text(
                              c.name,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              c.expiresText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const _DashedDivider(),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 88,
                    child: CustomPaint(
                      size: const Size(double.infinity, 88),
                      painter: _BarcodePainter(c.code),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _spacedCode(c.code),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: AppColors.textPrimary,
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

  // ── 상품 + 바코드 카드 ──
  Widget _mainCard(Coupon c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Opacity(opacity: _used ? 0.4 : 1, child: const CouponThumb(size: 96)),
          const SizedBox(height: 16),
          Text(
            c.brand,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            c.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '교환일 ${_ymd(c.createdAt)} · ${c.expiresText}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 18),
          // 화면용 바코드 (탭하면 확대). 저장·공유 이미지는 _captureCard 로 별도 구성.
          GestureDetector(
            onTap: () => _zoom(c),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Opacity(
                opacity: _used ? 0.35 : 1,
                child: Column(
                  children: [
                    SizedBox(
                      height: 78,
                      child: CustomPaint(
                        size: const Size(double.infinity, 78),
                        painter: _BarcodePainter(c.code),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _spacedCode(c.code),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _used ? '사용 완료됨 · 다시 누르면 취소돼요' : '매장에서 바코드를 보여주세요',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.gray350,
            ),
          ),
        ],
      ),
    );
  }

  // ── 사용 안내 카드 ──
  Widget _guideCard(Coupon c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 6),
            child: Text(
              '사용 안내',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _guideRow('유효 기간', c.expiresText, last: false),
          _guideRow('사용처', '${c.brand} 전 매장', last: true),
        ],
      ),
    );
  }

  Widget _guideRow(String label, String value, {required bool last}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.line100, width: 0.8),
              ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.gray500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _outlinedAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.gray700),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 하단 버튼 — 사용 완료 / 사용 취소 / 만료 안내 (목업 useBtn 색)
  Widget _bottomButton(Coupon c) {
    if (c.expired) {
      return Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          '기간이 만료된 쿠폰이에요',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.gray400,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _toggleUsed,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _used ? AppColors.surfaceSoft : AppColors.ink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          _used ? '사용 취소' : '사용 완료',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            // 사용 취소는 accent(#E4573D), 사용 완료는 흰 글씨
            color: _used ? AppColors.accent : Colors.white,
          ),
        ),
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
                _spacedCode(c.code),
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

  // 1234 5678 9012 형태로 4자리씩 띄우기
  String _spacedCode(String code) {
    final buf = StringBuffer();
    for (int i = 0; i < code.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(code[i]);
    }
    return buf.toString();
  }

  // 'YYYY. M. D.' — 교환일 표기
  String _ymd(DateTime d) => '${d.year}. ${d.month}. ${d.day}.';
}

/// 점선 구분선 (쿠폰 절취선 느낌)
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const dash = 6.0;
        const gap = 5.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(width: dash, height: 1.4, color: AppColors.border),
          ),
        );
      },
    );
  }
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
