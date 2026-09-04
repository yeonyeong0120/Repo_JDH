import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/group_thumb.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'group_detail_screen.dart';

/// Ploggo - 그룹 검색 화면 (GRP-02, Startline)
/// 검색바(퍼지 매칭은 GroupService.search) + 정렬 시트 + 라인 보더 결과 카드.
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

  // 최근 검색어(메모리 보관, 최신순, 최대 6개). 저장소 연동은 아직 없다.
  final List<String> _recent = <String>[];

  // 검색어 제출 시 최근 검색 목록에 추가(중복 제거·최신 우선·6개 제한)
  void _addRecent(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    setState(() {
      _recent.remove(t);
      _recent.insert(0, t);
      if (_recent.length > 6) _recent.removeRange(6, _recent.length);
    });
  }

  // 최근 검색 칩 탭 → 해당 검색어로 다시 검색
  void _applyRecent(String q) {
    _controller.text = q;
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: q.length));
    setState(() => _query = q);
    _load();
  }

  // 정렬 — 실제 모델 필드(todayActiveCount / memberCount / createdAt)로만 구성.
  int _sort = 0;
  static const List<String> _sortLabels = ['활동순', '인기순', '최신순'];
  static const List<String> _sortHints = ['오늘 활동 많은 순', '멤버 많은 순', '개설 최신순'];

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

  // 검색어 없으면 전체 목록, 있으면 이름 검색(GroupService.search — 퍼지 매칭)
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

  // 현재 정렬 기준으로 결과를 정렬한 사본
  List<Group> _sorted() {
    final list = [..._results];
    switch (_sort) {
      case 0: // 활동순 (같으면 멤버 많은 순)
        list.sort((a, b) {
          final t = b.todayActiveCount.compareTo(a.todayActiveCount);
          return t != 0 ? t : b.memberCount.compareTo(a.memberCount);
        });
        break;
      case 1: // 인기순 (멤버 많은 순)
        list.sort((a, b) => b.memberCount.compareTo(a.memberCount));
        break;
      case 2: // 최신순 (개설 최신)
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return list;
  }

  // 정렬 바텀시트
  void _openSort() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.gray200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 0, 10, 6),
                child: Text(
                  '정렬',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              for (int i = 0; i < _sortLabels.length; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() => _sort = i);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 15,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.line100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _sortLabels[i],
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight:
                                  _sort == i ? FontWeight.w800 : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _sortHints[i],
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.gray350,
                          ),
                        ),
                        if (_sort == i) ...[
                          const SizedBox(width: 10),
                          const Icon(TablerIcons.check,
                              size: 20, color: AppColors.ink),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    '닫기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _sorted();
    return Scaffold(
      backgroundColor: AppColors.surface,
      // 키보드가 떠도 레이아웃을 밀지 않아 '찾는 그룹이 없어요'가 고정된다.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단: 뒤로가기 + 검색바
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 18, 0),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(TablerIcons.chevronLeft,
                          size: 24, color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(TablerIcons.search,
                              size: 19, color: AppColors.gray500),
                          const SizedBox(width: 9),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              textAlignVertical: TextAlignVertical.center,
                              onChanged: (v) {
                                setState(() => _query = v);
                                _load();
                              },
                              onSubmitted: _addRecent,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 13),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                hintText: '그룹명 또는 동네 검색',
                                hintStyle: TextStyle(
                                  fontSize: 14.5,
                                  color: AppColors.gray350,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() => _query = '');
                                _load();
                              },
                              child: const Icon(TablerIcons.x,
                                  size: 18, color: AppColors.gray400),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 상태바/검색바 아래 살짝 여백을 둬 콘텐츠가 위에 붙지 않게 한다.
            const SizedBox(height: 8),
            // 최근 검색 — 저장된 검색어가 있을 때만 라벨 + 칩을 노출한다.
            if (_recent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '최근 검색',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final q in _recent) _recentPill(q),
                      ],
                    ),
                  ],
                ),
              ),
            // 검색 결과 N + 정렬 토글
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppColors.ink,
                        ),
                        children: [
                          const TextSpan(text: '검색 결과 '),
                          TextSpan(
                            text: _loading ? '' : '${results.length}',
                            style: const TextStyle(color: AppColors.gray500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openSort,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(TablerIcons.arrowsSort,
                            size: 16, color: AppColors.ink),
                        const SizedBox(width: 5),
                        Text(
                          _sortLabels[_sort],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 결과
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.progress,
                        strokeWidth: 2,
                      ),
                    )
                  : results.isEmpty
                      // 빈 상태는 아래 고정 오버레이(_empty)로 그린다.
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            MediaQueryData.fromView(View.of(context))
                                    .padding
                                    .bottom +
                                92,
                          ),
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _groupCard(results[i]),
                        ),
            ),
          ],
        ),
          ),
          // 빈 상태 — 전체 화면 높이 기준 고정(키보드 온/오프와 무관하게 안 움직임)
          if (!_loading && results.isEmpty)
            Positioned(
              left: 0,
              right: 0,
              top: MediaQuery.of(context).size.height * 0.30,
              child: _empty(),
            ),
        ],
      ),
    );
  }

  // 최근 검색 칩 — 라운드 필. 탭하면 해당 검색어로 재검색.
  Widget _recentPill(String q) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _applyRecent(q),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.gray200, width: 1.5),
        ),
        child: Text(
          q,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }

  // 결과 없음 — 라임 라운드 스퀘어(72) + mapSearch(검정) + 안내 문구.
  // 화면 중앙보다 살짝 위(헤더 높이만큼 아래로 치우쳐 보이던 것 보정).
  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(TablerIcons.mapSearch,
                  size: 34, color: AppColors.limeOn),
            ),
            const SizedBox(height: 18),
            const Text(
              '찾는 그룹이 없어요',
              style: TextStyle(
                fontSize: 18,
                height: 1.4,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '검색어를 줄이거나 동네 이름으로\n다시 찾아보세요',
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

  // 라인 보더 결과 카드 → 상세/가입
  Widget _groupCard(Group g) {
    final active = g.todayActiveCount > 0;
    final meta = active
        ? '지금 ${g.todayActiveCount}명 활동 중 · 멤버 ${g.memberCount}명'
        : '멤버 ${g.memberCount}명${g.region.isEmpty ? '' : ' · ${g.region}'}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line100, width: 1.5),
        ),
        child: Row(
          children: [
            GroupThumb(imageUrl: g.imageUrl, size: 50),
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
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (active) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.ink,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          meta,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.gray500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(TablerIcons.chevronRight,
                size: 22, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }
}
