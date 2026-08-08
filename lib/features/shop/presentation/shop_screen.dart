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
  final TextEditingController _search = TextEditingController();
  final PageController _pageController = PageController();
  int _index = 0; // 현재 카테고리 인덱스
  int _points = 0;
  bool _loading = true;
  String _query = ''; // 검색어 (상품명·브랜드)
  bool _sortAsc = true; // true=낮은 포인트순 / false=높은 포인트순
  bool _sortOpen = false; // 정렬 드롭다운 열림 여부

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  @override
  void dispose() {
    _search.dispose();
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

  // 검색·정렬을 반영한 특정 카테고리 상품 목록
  List<ShopItem> _visibleItems(ShopCategory c) {
    var items = ShopService.byCategory(c);
    final q = _query.trim();
    if (q.isNotEmpty) {
      items = items
          .where((i) => i.name.contains(q) || i.brand.contains(q))
          .toList();
    }
    items.sort(
      (a, b) =>
          _sortAsc ? a.price.compareTo(b.price) : b.price.compareTo(a.price),
    );
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            _searchBar(),
            const SizedBox(height: 16),
            _categoryBar(),
            const SizedBox(height: 14),
            _sortAndPoints(),
            const SizedBox(height: 8),
            // 좌우로 밀어 카테고리 전환
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
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: AppColors.textPrimary,
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            '에코포인트 상점',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 검색 바 ─────────────────────────
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          // 그룹 검색창과 동일: 하양 + 카드 그림자
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                textInputAction: TextInputAction.search,
                textAlignVertical: TextAlignVertical.center,
                cursorColor: AppColors.textPrimary, // 초록 커서 제거
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  // 위아래 여백을 대칭으로 줘서 문구를 세로 가운데로
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: '상품이나 브랜드를 검색하세요',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _search.clear();
                  setState(() => _query = '');
                },
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.neutral400,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 카테고리 ─────────────────────────
  Widget _categoryBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.actionPrimary : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: on ? AppColors.actionPrimary : AppColors.border,
                ),
              ),
              child: Icon(
                c.icon,
                size: 24,
                color: on ? Colors.white : AppColors.neutral500,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              c.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                height: 1.15,
                fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                color: on ? AppColors.textBrandOnLight : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────── 정렬 드롭다운 + 보유 포인트 칩 ───────────────
  Widget _sortAndPoints() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // 그룹 검색과 동일한 오버레이 드롭다운 토글
          _SortDropdown(
            options: const ['낮은 포인트순', '높은 포인트순'],
            selected: _sortAsc ? 0 : 1,
            open: _sortOpen,
            onToggle: () => setState(() => _sortOpen = !_sortOpen),
            onSelect: (i) => setState(() {
              _sortAsc = i == 0;
              _sortOpen = false;
            }),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.green100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Symbols.eco,
                  weight: 600,
                  size: 16,
                  color: AppColors.actionPrimary,
                ),
                const SizedBox(width: 5),
                Text(
                  _loading ? '- P' : '${_format(_points)} P',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textBrandOnLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 상품 목록 (세로 리스트) ─────────────────────────
  Widget _productList(ShopCategory c) {
    final items = _visibleItems(c);
    if (items.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty ? '준비 중인 카테고리예요' : '검색 결과가 없어요',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _itemCard(items[i]),
    );
  }

  Widget _itemCard(ShopItem item) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _confirmExchange(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // 포인트가 부족해도 동일하게 표기
            _thumb(item, 68),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.brand,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'P',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.actionPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }

  // 상품 이미지 자리 — 실제 이미지 있으면 표시, 없으면 '상품 이미지' 플레이스홀더
  // TODO: 상품 이미지가 준비되면 imageUrl 을 채워 Image.network 로 렌더
  Widget _thumb(ShopItem item, double size) {
    final url = item.imageUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: (url == null || url.isEmpty)
          ? const Text(
              '상품\n이미지',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: AppColors.neutral400,
              ),
            )
          : Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Text(
                '상품\n이미지',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: AppColors.neutral400,
                ),
              ),
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
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _thumb(item, 110),
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
                  color: AppColors.bg,
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
                          color: AppColors.bg,
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
                          color: AppColors.actionPrimary,
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
            color: strong ? AppColors.green800 : AppColors.textPrimary,
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
        backgroundColor: AppColors.surface,
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
                  color: AppColors.surfaceBrand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 34,
                  color: AppColors.actionPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '교환되었습니다',
                style: TextStyle(
                  fontSize: 20,
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
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          '계속 둘러보기',
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
                      onTap: () {
                        Navigator.pop(ctx);
                        _openCoupons();
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.actionPrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          '쿠폰함 가기',
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

/// 정렬 오버레이 드롭다운 — 그룹 검색(GRP-02)과 동일한 토글 방식.
/// 라벨+화살표를 누르면 아래에 옵션 목록이 떠서 화면을 밀지 않는다.
class _SortDropdown extends StatefulWidget {
  final List<String> options;
  final int selected;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelect;

  const _SortDropdown({
    required this.options,
    required this.selected,
    required this.open,
    required this.onToggle,
    required this.onSelect,
  });

  // 가장 긴 옵션 폭으로 라벨 폭 고정 (선택이 바뀌어도 크기 불변)
  double get _labelWidth {
    double widest = 0;
    for (final o in options) {
      final tp = TextPainter(
        text: TextSpan(
          text: o,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > widest) widest = tp.width;
    }
    return widest + 2;
  }

  @override
  State<_SortDropdown> createState() => _SortDropdownState();
}

class _SortDropdownState extends State<_SortDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(_fade);
  }

  @override
  void didUpdateWidget(covariant _SortDropdown old) {
    super.didUpdateWidget(old);
    if (widget.open && _entry == null) {
      _show();
    } else if (!widget.open && _entry != null) {
      _hide();
    }
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _ac.dispose();
    super.dispose();
  }

  void _show() {
    _entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onToggle,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: Align(
              alignment: Alignment.topLeft,
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 168,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(widget.options.length, (i) {
                          final on = widget.selected == i;
                          return InkWell(
                            onTap: () => widget.onSelect(i),
                            child: Container(
                              height: 48,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Text(
                                widget.options[i],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: on
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: on
                                      ? AppColors.textBrandOnLight
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entry == null) return;
      Overlay.of(context).insert(_entry!);
      _ac.forward(from: 0);
    });
  }

  Future<void> _hide() async {
    final entry = _entry;
    _entry = null;
    if (entry == null) return;
    await _ac.reverse();
    entry.remove();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget._labelWidth,
              child: Text(
                widget.options[widget.selected],
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.open
                      ? AppColors.textBrandOnLight
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 2),
            AnimatedRotation(
              turns: widget.open ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: widget.open
                    ? AppColors.textBrandOnLight
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
