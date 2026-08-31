import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/core/dev/dev_seed.dart'; // ⚠️ 개발용 — 배포 전 이 줄과 버튼 삭제

/// Ploggo - 그룹 세부 화면 (활동 공유 피드)
/// 채팅 기능 없음. 멤버들의 플로깅 결과를 보고 '좋아요'만 누름.
/// 위치 권장: lib/features/community/presentation/group_feed_screen.dart
class GroupFeedScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final int memberCount;

  const GroupFeedScreen({
    super.key,
    this.groupId = '',
    this.groupName = '00동 같이 주워봐요',
    this.memberCount = 12,
  });

  @override
  State<GroupFeedScreen> createState() => _GroupFeedScreenState();
}

class _GroupFeedScreenState extends State<GroupFeedScreen> {
  // 피드 데이터 (placeholder — 실제 그룹 활동 공유로 교체)
  // date = 게시(=활동) 시각. TODO: 실제 활동 데이터의 DateTime으로 교체
  // groupId 가 있으면 Firestore 피드로 교체됨 (없으면 아래 더미 유지)
  List<_FeedItem> _items = [
    _FeedItem(
      '김연영',
      DateTime.now().subtract(const Duration(hours: 2)),
      '2.1 km',
      33,
      '00:42',
      likes: 5, // 남들이 누른 좋아요 수(내 글이라 내가 누르는 하트는 숨김)
      isMine: true,
    ),
    _FeedItem(
      '박서연',
      DateTime.now().subtract(const Duration(hours: 5)),
      '1.4 km',
      18,
      '00:31',
      hasPhoto: false, // 스킵으로 마친 활동 (사진 없음)
      likes: 3,
    ),
    _FeedItem(
      '이준호',
      DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      '3.0 km',
      41,
      '00:58',
      likes: 8,
    ),
  ];

  // 멤버 목록 (placeholder)
  // TODO: 실제 그룹 멤버 데이터로 교체
  List<String> _members = const [
    '김연영',
    '박서연',
    '이준호',
    '최민지',
    '정우성',
    '한소희',
    '오정환',
    '유가을',
  ];

  // 오른쪽 멤버 드로어(endDrawer) 열고/닫기용 키
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 채팅 입력창
  final TextEditingController _msgController = TextEditingController();
  bool _sending = false; // 중복 전송 방지

  // 실시간 피드 구독 (메시지가 오면 즉시 반영)
  StreamSubscription<List<GroupPost>>? _postsSub;

  // 채팅 스크롤 — 첫 진입 시 최신(맨 아래) 메시지로 한 번 이동
  final ScrollController _feedScroll = ScrollController();
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribePosts(); // 실시간 구독 시작
  }

  @override
  void dispose() {
    _postsSub?.cancel(); // 구독 해제 (안 하면 메모리 누수)
    _msgController.dispose();
    _feedScroll.dispose();
    super.dispose();
  }

  // 피드 실시간 구독 — 누가 글/메시지를 올리면 바로 목록에 반영된다
  void _subscribePosts() {
    if (widget.groupId.isEmpty) return; // 더미 모드
    _postsSub = GroupService.watchPosts(widget.groupId).listen(
      (posts) {
        if (!mounted) return;
        final wasNearBottom = _isNearBottom();
        setState(() => _items = posts.map(_fromPost).toList());
        if (!_didInitialScroll) {
          _maybeInitialScroll(); // 첫 실데이터 도착 시 최신(하단)으로
        } else if (wasNearBottom) {
          // 이미 최신을 보고 있었다면 새 메시지에 맞춰 계속 하단 유지
          WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
        }
      },
      onError: (_) {
        // 실패해도 기존 목록 유지 (화면이 비어버리지 않게)
      },
    );
  }

  // 첫 진입 시 맨 아래(최신 메시지)로 점프.
  // 이미지·아바타가 늦게 로드되며 높이가 커질 수 있어 여러 번 나눠 점프한다.
  void _maybeInitialScroll() {
    if (_didInitialScroll) return;
    _didInitialScroll = true;
    for (final ms in const [0, 150, 350, 700]) {
      Future.delayed(Duration(milliseconds: ms), () {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
      });
    }
  }

  void _jumpToBottom() {
    if (!mounted || !_feedScroll.hasClients) return;
    _feedScroll.jumpTo(_feedScroll.position.maxScrollExtent);
  }

  // 사용자가 최신(맨 아래) 근처를 보고 있는지
  bool _isNearBottom() {
    if (!_feedScroll.hasClients) return true; // 아직 안 그려졌으면 하단으로 간주
    final p = _feedScroll.position;
    return (p.maxScrollExtent - p.pixels) < 120;
  }

  // 채팅 메시지 전송
  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _sending) return;
    if (widget.groupId.isEmpty) return;

    setState(() => _sending = true);
    _msgController.clear(); // 먼저 비워서 반응이 빠르게 느껴지도록
    try {
      await GroupService.sendMessage(groupId: widget.groupId, text: text);
      // 목록은 실시간 구독이 알아서 갱신한다
    } catch (e) {
      if (!mounted) return;
      _msgController.text = text; // 실패 시 입력 복구
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // 멤버 목록 불러오기 (피드는 실시간 구독이 담당)
  Future<void> _load() async {
    if (widget.groupId.isEmpty) return; // 더미 모드
    try {
      final names = await GroupService.memberNames(widget.groupId);
      if (!mounted) return;
      setState(() {
        if (names.isNotEmpty) _members = names;
      });
    } catch (_) {
      // 실패 시 기존 목록 유지
    }
  }

  // ⚠️ 개발용 — 가짜 피드 글 심기/지우기 (배포 전 삭제)
  Future<void> _runSeed({required bool seed}) async {
    if (widget.groupId.isEmpty) return;
    try {
      final n = seed
          ? await DevSeed.seedPosts(widget.groupId)
          : await DevSeed.clearPosts(widget.groupId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${seed ? "심기" : "삭제"} $n건 완료')),
      );
      _load(); // 피드 갱신
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('실패: $e')));
    }
  }

  _FeedItem _fromPost(GroupPost p) => _FeedItem(
    p.userName,
    p.createdAt,
    p.distance,
    p.trash,
    p.duration,
    hasPhoto: p.imageUrl != null,
    likes: p.likes,
    liked: p.likedByMe,
    isMine: p.isMine,
    postId: p.id,
    photoUrl: p.photoUrl,
    imageUrl: p.imageUrl,
    isMessage: p.isMessage, // 채팅 메시지 여부
    isSystem: p.isSystem, // 가입 등 시스템 알림
    text: p.text,
  );

  Future<void> _toggleLike(_FeedItem it) async {
    final wasLiked = it.liked;
    setState(() {
      it.liked = !wasLiked;
      it.likes += it.liked ? 1 : -1;
    });
    if (widget.groupId.isEmpty || it.postId == null) return;
    try {
      await GroupService.toggleLike(
        groupId: widget.groupId,
        postId: it.postId!,
        liked: wasLiked,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        it.liked = wasLiked; // 실패 → 원복
        it.likes += it.liked ? 1 : -1;
      });
    }
  }

  // 날짜 헤더 라벨 (오늘 / 어제 / N월 N일 / 작년 이전이면 연도까지)
  String _dateHeader(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    if (d.year == now.year) return '${d.month}월 ${d.day}일';
    return '${d.year}년 ${d.month}월 ${d.day}일';
  }

  // 시각 라벨 (오전/오후 h:mm)
  String _timeLabel(DateTime d) {
    final period = d.hour < 12 ? '오전' : '오후';
    var hh = d.hour % 12;
    if (hh == 0) hh = 12;
    final mm = d.minute.toString().padLeft(2, '0');
    return '$period $hh:$mm';
  }

  // 날짜별로 묶어서: [날짜 칩] 아래에 그 날 활동 카드들
  List<Widget> _buildFeed() {
    final items = [..._items]..sort((a, b) => a.date.compareTo(b.date));
    final widgets = <Widget>[];
    String? lastLabel;
    for (final it in items) {
      final label = _dateHeader(it.date);
      if (label != lastLabel) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 10));
        widgets.add(_dateChip(label));
        widgets.add(const SizedBox(height: 12));
        lastLabel = label;
      }
      // 내 것은 오른쪽으로(왼쪽 여백), 남의 것은 왼쪽으로(오른쪽 여백) — 카드 위치만.
      // 단, 가입 등 시스템 알림은 좌우 여백 없이 전체 폭에서 가운데 정렬한다.
      widgets.add(
        it.isSystem
            ? _feedCard(it)
            : Padding(
                padding: it.isMine
                    ? const EdgeInsets.only(left: 80)
                    : const EdgeInsets.only(right: 80),
                child: _feedCard(it),
              ),
      );
      widgets.add(const SizedBox(height: 14)); // 카드 사이 간격(더 촘촘하게)
    }
    return widgets;
  }

  Widget _dateChip(String label) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ───────── 오른쪽 멤버 드로어 (≡ 누르면 오른쪽에서 슬라이드) ─────────
  Widget _buildMemberDrawer() {
    return Drawer(
      backgroundColor: AppColors.surface,
      width: 300,
      child: SafeArea(
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
              child: Row(
                children: [
                  Text(
                    '멤버 ${_members.length}명',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(TablerIcons.x, size: 22),
                    color: AppColors.textSecondary,
                    onPressed: () =>
                        _scaffoldKey.currentState?.closeEndDrawer(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            // 멤버 목록 (쫙)
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _members.length,
                itemBuilder: (_, i) {
                  final me = _members[i] == '김연영'; // TODO: 실제 로그인 사용자
                  return ListTile(
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.surfaceBrand,
                      child: Icon(
                        TablerIcons.userFilled,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    title: Text(
                      _members[i],
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    trailing: me
                        ? const Text(
                            '나',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            // 하단 탈퇴하기 (목업: 꽉 찬 빨강 버튼)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _scaffoldKey.currentState?.closeEndDrawer();
                  _confirmLeave();
                },
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.actionDanger,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.actionDanger.withValues(alpha: 0.24),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(TablerIcons.logout, size: 20, color: Colors.white),
                      SizedBox(width: 7),
                      Text(
                        '탈퇴하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── 신고 (대상: 개별 활동) ─────────
  // ───────── 신고 (대상: 활동 또는 메시지) — 목업: 사유 선택 바텀시트 ─────────
  void _showReport(_FeedItem item) {
    const reasons = [
      '부적절한 사진이에요',
      '욕설·비방이 있어요',
      '광고·스팸이에요',
      '활동과 관계없는 내용이에요',
      '다른 사유',
    ];
    String? selected;
    final otherController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final isOther = selected == '다른 사유';
          final canSubmit = selected != null &&
              (!isOther || otherController.text.trim().isNotEmpty);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Text(
                  item.isMessage ? '${item.name}님 메시지 신고' : '${item.name}님 활동 신고',
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '신고 내용은 그룹장과 운영진만 볼 수 있어요. 같은 멤버를 3번 이상 신고하면 자동으로 확인해요.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                for (final r in reasons) ...[
                  _reportReasonTile(
                    label: r,
                    selected: selected == r,
                    onTap: () => setSt(() => selected = r),
                  ),
                  const SizedBox(height: 8),
                ],
                if (isOther)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: TextField(
                      controller: otherController,
                      autofocus: true,
                      maxLength: 100,
                      maxLines: 2,
                      onChanged: (_) => setSt(() {}),
                      decoration: InputDecoration(
                        hintText: '어떤 점이 문제였나요? (선택)',
                        hintStyle: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: '취소',
                        type: AppButtonType.secondary,
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: '신고하기',
                        enabled: canSubmit,
                        type: AppButtonType.danger,
                        onTap: () {
                          Navigator.pop(ctx);
                          // TODO: 실제 신고 접수 (대상 item · 사유 selected · 상세 otherController.text)
                          AppSnackBar.show(context, '신고를 접수했어요. 검토 후 알려드릴게요');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 신고 사유 한 줄 (라디오 + 라벨)
  Widget _reportReasonTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.green100 : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.actionPrimary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.actionPrimary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.actionPrimary : AppColors.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(TablerIcons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────── 그룹 상세 정보 (소개/동네/인원) ─────────
  Future<void> _showGroupInfo() async {
    Group? g;
    if (widget.groupId.isNotEmpty) {
      try {
        g = await GroupService.getGroup(widget.groupId);
      } catch (_) {
        // 실패 시 이름만 표시
      }
    }
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // TODO: 그룹 대표 이미지로 교체
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBrand,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('🌱', style: TextStyle(fontSize: 36)),
              ),
              const SizedBox(height: 14),
              Text(
                g?.name ?? widget.groupName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                g == null ? '' : '${g.region}  ·  ${g.meta}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '그룹 소개',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (g?.intro.isNotEmpty ?? false)
                          ? g!.intro
                          : '아직 소개글이 없어요.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.7,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

  // ───────── 그룹 탈퇴 (탈퇴는 여기서만 가능 — 기획서 GRP-05) ─────────
  Future<void> _confirmLeave() async {
    final ok = await AppDialog.show(
      context,
      title: '그룹 탈퇴',
      message: '그룹에서 탈퇴하시겠습니까?',
      cancelText: '아니오',
      confirmText: '탈퇴',
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      if (widget.groupId.isNotEmpty) {
        await GroupService.leaveGroup(widget.groupId);
      }
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '탈퇴하지 못했어요');
      return;
    }
    if (!mounted) return;
    AppSnackBar.show(context, '그룹에서 탈퇴했어요');
    context.go('/group');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg, // 홈 등 다른 화면과 통일
      endDrawer: _buildMemberDrawer(), // 오른쪽에서 슬라이드되는 멤버 패널
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: ListView(
                controller: _feedScroll,
                // 입력창이 아래를 차지하므로 여백을 줄임
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                children: _buildFeed(),
              ),
            ),
            // 하단 채팅 입력창
            _chatInputBar(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 상단 바 ─────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(TablerIcons.chevronLeft, size: 20),
            color: AppColors.textPrimary,
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.groupName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '멤버 ${widget.memberCount}명',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 그룹 정보 (가입 전에 봤던 소개·동네·인원)
          IconButton(
            icon: const Icon(TablerIcons.infoCircle),
            color: AppColors.textSecondary,
            onPressed: _showGroupInfo,
          ),
          // ⚠️ 개발용 임시 버튼 — 가짜 피드 글 심기/지우기 (배포 전 삭제)
          IconButton(
            icon: const Icon(TablerIcons.flask),
            color: AppColors.textSecondary,
            onPressed: () => _runSeed(seed: true),
          ),
          IconButton(
            icon: const Icon(TablerIcons.trash),
            color: AppColors.textSecondary,
            onPressed: () => _runSeed(seed: false),
          ),
          // 오른쪽 위 ≡ → 오른쪽 멤버 드로어 열기
          IconButton(
            icon: const Icon(TablerIcons.menu2),
            color: AppColors.textSecondary,
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 활동 공유 카드 (A안) ─────────────────────────
  // 가입 등 시스템 알림 — 가운데 회색 칩 (목업의 '오늘' 칩과 같은 톤)
  Widget _systemNotice(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.neutral900.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // 채팅 말풍선 — 내 메시지는 오른쪽(초록), 남의 메시지는 왼쪽(흰색)
  Widget _chatBubble(_FeedItem item) {
    final mine = item.isMine;
    final photo = item.photoUrl;
    final avatar = CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.surfaceBrand,
      backgroundImage: (photo != null && photo.isNotEmpty)
          ? NetworkImage(photo)
          : null,
      child: (photo != null && photo.isNotEmpty)
          ? null
          : const Icon(TablerIcons.userFilled, size: 16, color: AppColors.textSecondary),
    );

    final bubble = Container(
      // 시각 라벨('오전 7:30')이 옆에 붙으므로 폭을 조금 여유 있게 잡는다
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        // 내 말풍선: 꽉 찬 초록 X → 연초록(#DCEDE3) + 진초록 글씨(#153A2B)
        color: mine ? const Color(0xFFDCEDE3) : AppColors.surface,
        borderRadius: mine
            ? const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(6),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
        boxShadow: mine ? null : AppColors.cardShadow,
      ),
      child: Text(
        item.text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
          // 채팅 글씨는 검정으로 통일 (내 말풍선도 동일)
          color: AppColors.textPrimary,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mine
            ? [
                // 내 메시지: 시각 → 말풍선
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 4),
                  child: Text(
                    _timeLabel(item.date),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                bubble,
              ]
            : [
                // 남의 메시지: 아바타 → (이름 + 말풍선) → 시각
                avatar,
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textOnTint,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // 메시지 신고 깃발 (목업: 이름 옆)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _showReport(item),
                          child: const Icon(
                            TablerIcons.flag,
                            size: 15,
                            color: AppColors.neutral400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    bubble,
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 22),
                  child: Text(
                    _timeLabel(item.date),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
      ),
    );
  }

  // 하단 채팅 입력창
  Widget _chatInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                minLines: 1,
                maxLines: 4, // 길어지면 최대 4줄까지
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요',
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  // 포커스 시 초록 테두리가 뜨지 않게 모든 상태를 테두리 없음으로.
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 전송 버튼 (전송 중엔 스피너)
            GestureDetector(
              onTap: _sending ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFB4E5C9), // 목업 보내기 버튼 연초록
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textBrandOnLight,
                        ),
                      )
                    : const Icon(
                        TablerIcons.arrowUp,
                        color: AppColors.textPrimary, // 검정 화살표
                        size: 24,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedCard(_FeedItem item) {
    // 가입 등 시스템 알림은 가운데 정렬 회색 칩으로 표시
    if (item.isSystem) return _systemNotice(item.text);
    // 채팅 메시지는 말풍선으로 표시 (활동 카드와 구분)
    if (item.isMessage) return _chatBubble(item);

    final mine = item.isMine;
    final photo = item.photoUrl;
    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.surfaceBrand,
      backgroundImage: (photo != null && photo.isNotEmpty)
          ? NetworkImage(photo)
          : null,
      child: (photo != null && photo.isNotEmpty)
          ? null
          : const Icon(TablerIcons.userFilled, size: 20, color: AppColors.textSecondary),
    );
    // 기록: 흰 바탕에 컴팩트하게 (왼쪽 밑)
    final record = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statInline('거리', item.distance),
        _dot(),
        _statInline('수거', '${item.trash}개'),
        _dot(),
        _statInline('시간', item.duration),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias, // 사진 모서리 둥글게
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 인증샷 (크게, 오버레이 없음)
          // TODO: 실제 사진(Image.network(item.photoUrl))으로 교체
          if (item.hasPhoto)
            AspectRatio(
              aspectRatio: 16 / 9, // 넓적한 띠 대신 자연스러운 가로 사진 비율
              child: Container(
                width: double.infinity,
                color: AppColors.surfaceBrand,
                alignment: Alignment.center,
                child: (item.imageUrl?.startsWith('http') ?? false)
                    ? Image.network(
                        item.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          TablerIcons.camera,
                          size: 36,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : const Icon(
                        TablerIcons.camera,
                        size: 36,
                        color: AppColors.textSecondary,
                      ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), // 상하 더 타이트하게
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 작성자 줄 (다 왼쪽 정렬) — 내 글은 신고/좋아요 버튼 없음
                Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _timeLabel(item.date),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 신고는 프로필 줄 오른쪽 (내 글엔 없음)
                    if (!mine) _reportButton(item),
                  ],
                ),
                const SizedBox(height: 6),
                // 기록 + 하트·숫자 — 내것/남의것 모두 오른쪽 46px 예약 → 기록 폭 동일(글자 크기 일치)
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: record,
                      ),
                    ),
                    SizedBox(
                      width: 46,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: _likeArea(item, mine),
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
    );
  }

  // 한 줄 수치 (라벨 + 값)
  // 한 줄 수치 (라벨 + 값) — 컴팩트
  Widget _statInline(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _reportButton(_FeedItem item) {
    return GestureDetector(
      onTap: () => _showReport(item),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(
          TablerIcons.flag,
          size: 18,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  // 하트 + 좋아요 수. 내 글은 받은 수 표시(회색·누르기 X), 남의 글은 눌러서 토글.
  Widget _likeArea(_FeedItem item, bool mine) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          // 내 글: 채워진 회색 하트(받은 수 표시) / 남의 글: 눌렀으면 빨강, 아니면 빈 하트
          mine
              ? TablerIcons.heartFilled
              : (item.liked ? TablerIcons.heartFilled : TablerIcons.heart),
          size: 18,
          color: mine
              ? AppColors.textSecondary
              : (item.liked ? AppColors.actionDanger : AppColors.textSecondary),
        ),
        const SizedBox(width: 3),
        Text(
          '${item.likes}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
    if (mine) return content; // 내 글: 받은 좋아요 수 표시만
    return GestureDetector(
      onTap: () => _toggleLike(item),
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

class _FeedItem {
  final String name;
  final DateTime date; // 게시(=활동) 시각
  final String distance;
  final int trash;
  final String duration;
  // 봉투 인증샷 유무 (스킵으로 마친 활동은 false → 사진 영역 생략)
  // TODO: 실제 사진 URL(String? photoUrl)로 교체
  final bool hasPhoto;
  int likes;
  bool liked;
  final bool isMine; // 내가 올린 기록인지 (오른쪽 정렬 + 하트 숨김)
  final String? postId; // Firestore 문서 id (더미는 null)
  final String? photoUrl; // 작성자 프로필 사진
  final String? imageUrl; // 봉투 인증샷 URL
  final bool isMessage; // true 면 채팅 말풍선으로 표시
  final bool isSystem; // true 면 가운데 시스템 알림(가입 등)으로 표시
  final String text; // 채팅 메시지 내용
  _FeedItem(
    this.name,
    this.date,
    this.distance,
    this.trash,
    this.duration, {
    this.hasPhoto = true,
    this.likes = 0,
    this.liked = false,
    this.isMine = false,
    this.postId,
    this.photoUrl,
    this.imageUrl,
    this.isMessage = false,
    this.isSystem = false,
    this.text = '',
  });
}