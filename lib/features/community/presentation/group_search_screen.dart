import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'group_detail_screen.dart';

/// 줍다행 - 그룹 검색 화면 (GRP-02)
/// 검색바 + 필터 드롭다운(지역/정렬) + 결과 리스트. 결과 카드 → 소개/가입 화면.
/// 위치 권장: lib/features/community/presentation/group_search_screen.dart
class GroupSearchScreen extends StatefulWidget {
  // 이미 다른 그룹 소속인지 (소개/가입 화면 GRP-04 판단용)
  final bool alreadyInGroup;
  const GroupSearchScreen({super.key, this.alreadyInGroup = false});

  @override
  State<GroupSearchScreen> createState() => _GroupSearchScreenState();
}

class _GroupSearchScreenState extends State<GroupSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  int _region = 0; // 0 내 동네 / 1 전체 (기본: 내 동네)
  int _sort = 0; // 0 인원 많은 순 / 1 최신순 (기본: 인원 많은 순)
  int? _openFilter; // 0 지역 / 1 정렬 / null 닫힘 (하나만 열림)

  static const List<String> _regionOptions = ['내 동네', '전체'];
  static const List<String> _sortOptions = ['인원 많은 순', '최신순'];

  List<Group> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 검색어 없으면 전체 목록, 있으면 이름 검색
  // TODO: 지역 필터(_region)·정렬(_sort)도 쿼리에 반영
  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    List<Group> list = [];
    try {
      final q = _query.trim();
      list = q.isEmpty
          ? await GroupService.otherGroups(limit: 30)
          : await GroupService.search(q);
    } catch (_) {
      // 실패 시 빈 목록
    }
    if (!mounted) return;
    setState(() {
      _results = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단: 뒤로가기 + 검색바
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBG,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              onChanged: (v) {
                                setState(() => _query = v);
                                _load();
                              },
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: '그룹명 또는 동네 검색',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: AppColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 필터: 드롭다운 2개 (지역 / 정렬) — 오버레이로 떠서 화면 안 밀림
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterDropdown(
                    options: _regionOptions,
                    selected: _region,
                    open: _openFilter == 0,
                    onToggle: () => setState(
                      () => _openFilter = _openFilter == 0 ? null : 0,
                    ),
                    onSelect: (i) => setState(() {
                      _region = i;
                      _openFilter = null;
                    }),
                  ),
                  const SizedBox(width: 10),
                  _FilterDropdown(
                    options: _sortOptions,
                    selected: _sort,
                    open: _openFilter == 1,
                    onToggle: () => setState(
                      () => _openFilter = _openFilter == 1 ? null : 1,
                    ),
                    onSelect: (i) => setState(() {
                      _sort = i;
                      _openFilter = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 결과
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : results.isEmpty
                  ? _empty()
                  : ListView.separated(
                      // 하단 네비바에 마지막 카드가 가리지 않게 여유
                      padding: EdgeInsets.fromLTRB(
                        16,
                        12,
                        16,
                        MediaQueryData.fromView(
                              View.of(context),
                            ).padding.bottom +
                            92,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _groupCard(results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text(
            '\'$_query\' 검색 결과가 없어요',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(Group g) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(
              groupId: g.id,
              name: g.name,
              region: g.region,
              meta: g.meta,
              alreadyInGroup: widget.alreadyInGroup,
            ),
          ),
        );
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            // TODO: 실제 그룹 대표 이미지로 교체
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryPale,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('🌱', style: TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    g.region,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    g.meta,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
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
}

/// 오버레이 드롭다운 (칩 아래에 떠서 화면 안 밀림 + 페이드/슬라이드)
class _FilterDropdown extends StatefulWidget {
  final List<String> options;
  final int selected;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<int> onSelect;

  const _FilterDropdown({
    required this.options,
    required this.selected,
    required this.open,
    required this.onToggle,
    required this.onSelect,
  });

  // 가장 긴 옵션의 실제 렌더 폭으로 칩 라벨 폭 고정 (선택 바뀌어도 크기 불변)
  double get _labelWidth {
    double widest = 0;
    for (final o in options) {
      final tp = TextPainter(
        text: TextSpan(
          text: o,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > widest) widest = tp.width;
    }
    return widest + 2; // 줄바꿈 방지용 여유
  }

  @override
  State<_FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<_FilterDropdown>
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
  void didUpdateWidget(covariant _FilterDropdown old) {
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
          // 바깥 아무 데나 누르면 닫힘
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
                      width: 132,
                      decoration: BoxDecoration(
                        color: AppColors.cardBG,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(widget.options.length, (i) {
                          final on = widget.selected == i;
                          return InkWell(
                            onTap: () => widget.onSelect(i),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.options[i],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: on
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: on
                                            ? AppColors.primaryDeep
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (on)
                                    const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                ],
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
    // 빌드 중 삽입 방지 → 다음 프레임에 삽입
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
        onTap: widget.onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBG,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.open ? AppColors.primary : AppColors.divider,
            ),
          ),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.open
                        ? AppColors.primaryDeep
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: widget.open ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
