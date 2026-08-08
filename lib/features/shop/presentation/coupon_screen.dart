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

/// SHOP-03 내 쿠폰함 (사용 가능 / 사용 완료 탭)
/// 위치 권장: lib/features/shop/presentation/coupon_screen.dart
class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});

  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponScreenState extends State<CouponScreen> {
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
            Opacity(opacity: dim ? 0.5 : 1, child: _thumb(64)),
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

/// SHOP-04 쿠폰 상세 (바코드 + 사용 완료 처리)
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
      body: Stack(
        clipBehavior: Clip.none, // 오프스크린(-4000) 캡처 카드가 클립되지 않도록
        children: [
          // 갤러리 저장·공유용 오프스크린 캡처 카드(사진+상품명+유효기한+바코드 한 장)
          Positioned(left: -4000, top: 0, child: _captureCard(c)),
          SafeArea(
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
                    '쿠폰',
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
                          Icons.ios_share,
                          '공유',
                          _share,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _outlinedAction(
                          Icons.download_outlined,
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

  // ── 저장·공유 전용 캡처 카드 (초록 헤더 + 사진 + 상품명 + 유효기한 + 바코드) ──
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
            // 초록 헤더
            Container(
              width: double.infinity,
              color: AppColors.actionPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: const [
                  Icon(Icons.eco, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '플로고 에코포인트 쿠폰',
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
                      _thumb(64),
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
                                color: AppColors.textBrandOnLight,
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
                      letterSpacing: 2,
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Opacity(opacity: _used ? 0.4 : 1, child: _thumb(96)),
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
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _detailStatusPill(c),
          const SizedBox(height: 20),
          const _DashedDivider(),
          const SizedBox(height: 20),
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
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
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
            _used ? '이미 사용한 쿠폰이에요' : '매장에서 바코드를 보여주세요',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textBrandOnLight,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 14, bottom: 6),
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
                bottom: BorderSide(color: AppColors.border, width: 0.8),
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
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
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

  Widget _detailStatusPill(Coupon c) {
    final usable = !_used && !c.expired;
    final label = usable ? '사용 가능' : (c.expired ? '기간 만료' : '사용 완료');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: usable ? AppColors.green100 : AppColors.neutral100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: usable ? AppColors.textBrandOnLight : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _outlinedAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
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

  // 하단 버튼 — 사용완료 처리 / 되돌리기 / 만료 안내
  Widget _bottomButton(Coupon c) {
    if (c.expired) {
      return Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.neutral100,
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
      );
    }
    return GestureDetector(
      onTap: _toggleUsed,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _used ? AppColors.surface : AppColors.actionPrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _used ? AppColors.border : AppColors.actionPrimary,
          ),
        ),
        child: Text(
          _used ? '사용 완료 취소' : '사용 완료 처리',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _used ? AppColors.textSecondary : Colors.white,
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
}

// 공통 썸네일 — '상품 이미지' 플레이스홀더 (실제 이미지 준비 시 교체)
Widget _thumb(double size) {
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
            (_) => Container(
              width: dash,
              height: 1.4,
              color: AppColors.border,
            ),
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
