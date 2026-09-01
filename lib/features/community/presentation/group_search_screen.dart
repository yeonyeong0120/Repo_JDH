import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'group_detail_screen.dart';

/// Ploggo - 그룹 검색 화면 (GRP-02)
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
      backgroundColor: AppColors.bg,
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
                    icon: const Icon(TablerIcons.chevronLeft, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            TablerIcons.search,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              textAlignVertical: TextAlignVertical.center,
                              onChanged: (v) {
                                setState(() => _query = v);
                                _load();
                              },
                              decoration: const InputDecoration(
                                isDense: true,
                                // 위아래 여백을 대칭으로 줘서 문구를 세로 가운데로
                                contentPadding: EdgeInsets.symmetric(vertical: 11),
                                // 포커스해도 색/테두리 안 변하게 (테마 채움·초록 테두리 차단)
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: '그룹명 또는 동네 검색',
                                hintStyle: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              child: const Icon(
                                TablerIcons.x,
                                size: 18,
                                color: AppColors.textSecondary,
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
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  // 결과 개수 (목업: 왼쪽, 드롭다운은 오른쪽)
                  Expanded(
                    child: Text(
                      _loading ? '' : '${_results.length}개 그룹',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
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
                  const SizedBox(width: 8),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFE9EFEB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                TablerIcons.searchOff,
                size: 30,
                color: AppColors.neutral400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '찾는 그룹이 없어요',
              style: TextStyle(
                fontSize: 17,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '다른 이름으로 찾아보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupCard(Group g) {
    return GestureDetector(
      onTap: () async {
        final joined = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => GroupDetailScreen(
              group: g,
              alreadyInGroup: widget.alreadyInGroup,
            ),
          ),
        );
        if (!mounted) return;
        // 가입했다면 검색 화면도 닫아 그룹 홈이 채팅방으로 이동하게 한다
        if (joined == true) {
          Navigator.pop(context, true);
        } else {
          _load();
        }
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
            // TODO: 실제 그룹 대표 이미지로 교체
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceBrand,
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
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    g.region,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    g.meta,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
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
            // 토글 바로 아래, 가운데 정렬로 연다.
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 7),
            child: Align(
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      // 고정 폭 대신 항목 글씨 폭에 맞춘다.
                      constraints: const BoxConstraints(minWidth: 112),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppColors.cardShadow,
                      ),
                      child: IntrinsicWidth(
                        child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(widget.options.length, (i) {
                          final on = widget.selected == i;
                          return InkWell(
                            onTap: () => widget.onSelect(i),
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              // 목업: 텍스트만, 선택 항목만 초록 굵게 (체크 없음)
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

  // 토글 라벨 스타일 (선택 텍스트 · 폭 예약용 동일 적용)
  static const TextStyle _labelStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textBrandOnLight,
  );

  @override
  Widget build(BuildContext context) {
    // 테두리 없는 토글 — 라벨 + 아래 화살표.
    // 폭은 가장 긴 옵션 기준으로 고정해, 선택이 바뀌어도 흔들리지 않는다.
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // 가장 긴 옵션들을 투명하게 깔아 폭을 고정한다.
                  for (final o in widget.options)
                    Opacity(
                      opacity: 0,
                      child: Text(o,
                          maxLines: 1, softWrap: false, style: _labelStyle),
                    ),
                  // 실제 표시되는 선택 라벨
                  Text(
                    widget.options[widget.selected],
                    maxLines: 1,
                    softWrap: false,
                    style: _labelStyle,
                  ),
                ],
              ),
              const SizedBox(width: 3),
              // 라벨 오른쪽에 아래 화살표(열리면 위로 뒤집힘)
              Icon(
                widget.open ? TablerIcons.chevronUp : TablerIcons.chevronDown,
                size: 16,
                color: AppColors.textBrandOnLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
