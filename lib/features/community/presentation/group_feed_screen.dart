import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 초대 링크 복사(Clipboard)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:repo_jdh/core/view_models/screen_views.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'group_photos_screen.dart';
import 'photo_detail_screen.dart';
import 'group_info_screen.dart';

/// Ploggo - 그룹 세부 화면 (활동 공유 피드)
/// 채팅 기능 없음. 멤버들의 플로깅 결과를 보고 '좋아요'만 누름.
/// 위치 권장: lib/features/community/presentation/group_feed_screen.dart
class GroupFeedScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String groupName;

  const GroupFeedScreen({
    super.key,
    this.groupId = '',
    required this.groupName,
  });

  @override
  ConsumerState<GroupFeedScreen> createState() => _GroupFeedScreenState();
}

class _GroupFeedScreenState extends ConsumerState<GroupFeedScreen> {
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

  // 실제 멤버 수 — null: 확인 중. groups/{id}.memberCount 를 그대로 쓴다
  // (join/leave 때마다 GroupService 가 이미 정확히 증감시키는 값).
  int? _memberCount;
  // 오늘 활동 인원 — 상단 부제목 '오늘 N명 활동'용.
  int _todayActiveCount = 0;
  // 그룹 대표 썸네일 — 상단 그룹 이름 왼쪽 아이콘 자리에 표시.
  String? _groupImageUrl;

  // 채팅 입력창
  final TextEditingController _msgController = TextEditingController();
  bool _sending = false; // 중복 전송 방지

  // 그룹 알림 항목별 on/off (로컬 상태 — 서버 연동 전까지 화면 안에서만 유지)
  bool _notifChat = true; // 채팅 메시지
  bool _notifActivity = true; // 활동 인증
  bool _notifNearby = false; // 지금 활동 중
  bool _notifWeekly = true; // 주간 결과

  // 실시간 피드 구독 (메시지가 오면 즉시 반영)
  StreamSubscription<List<GroupPost>>? _postsSub;

  // 내 가입 시각 — 이 시각 이전 채팅은 숨긴다 (재가입하면 그 이후만 보임).
  // null: 아직 확인 전 또는 못 읽음 → 필터 없이 전체 표시.
  DateTime? _joinedAt;

  // 채팅 스크롤 — 첫 진입 시 최신(맨 아래) 메시지로 한 번 이동
  final ScrollController _feedScroll = ScrollController();
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    _load();
    _initFeed(); // 가입 시각 확인 후 실시간 구독 시작
  }

  // 내 가입 시각을 먼저 읽고 나서 피드를 구독한다. 가입 이전 대화가 잠깐
  // 스쳐 보이는 것을 막기 위해 구독보다 앞서 가입 시각을 확보한다.
  Future<void> _initFeed() async {
    if (widget.groupId.isNotEmpty) {
      _joinedAt = await GroupService.myJoinedAt(widget.groupId);
    }
    if (!mounted) return;
    _subscribePosts();
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
        // 가입 시각 이전 대화는 숨긴다 → 처음 보이는 메시지는 항상
        // 'ㅇㅇ님이 그룹에 가입하셨습니다' 시스템 알림이 된다.
        final visible = _joinedAt == null
            ? posts
            : posts
                  .where((p) => !p.createdAt.isBefore(_joinedAt!))
                  .toList();
        setState(() => _items = visible.map(_fromPost).toList());
        // 가입 시 시스템 메시지가 함께 올라오므로, 새 글이 도착할 때마다
        // 멤버 수도 다시 조회한다 (탈퇴는 시스템 메시지가 없어 반영 안 됨 —
        // 화면을 다시 열면 갱신됨).
        _loadMemberCount();
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
    await _loadMemberCount();
  }

  Future<void> _loadMemberCount() async {
    if (widget.groupId.isEmpty) return;
    try {
      final group = await GroupService.getGroup(widget.groupId);
      if (!mounted) return;
      setState(() {
        _memberCount = group?.memberCount ?? 0;
        _todayActiveCount = group?.todayActiveCount ?? 0;
        _groupImageUrl = group?.imageUrl;
      });
    } catch (_) {
      if (mounted) setState(() => _memberCount = 0);
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
    source: p, // 한 컷 상세로 넘길 원본 게시글
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
      // 시스템 알림: 전체 폭 가운데. 메시지: 말풍선(자체 정렬). 활동 카드: 남의 것은
      // 카드 오른쪽 바깥에 신고 깃발(위)·시각(아래)을 세운다(목업).
      Widget child;
      if (it.isSystem) {
        child = _feedCard(it);
      } else if (it.isMessage) {
        child = Padding(
          padding: it.isMine
              ? const EdgeInsets.only(left: 60)
              : const EdgeInsets.only(right: 60),
          child: _feedCard(it),
        );
      } else if (it.isMine) {
        // 내 활동 카드: 텍스트 메시지처럼 시각을 왼쪽 아래에. 카드는 가로 폭 제한.
        child = Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 4),
              child: Text(
                _timeLabel(it.date),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 248),
              child: _feedCard(it),
            ),
          ],
        );
      } else {
        // 남의 활동 카드: 오른쪽 바깥에 신고 깃발(위)·시각(아래). 카드 폭 제한.
        child = IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 248),
                child: _feedCard(it),
              ),
              const SizedBox(width: 6),
              _cardFlagTime(it),
            ],
          ),
        );
      }
      widgets.add(child);
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

  // ───────── 오른쪽 사이드 드로어 (≡ → 멤버 / 초대 / 사진 / 설정 / 나가기) ─────────
  // 목업: 상단 '멤버 N' 라벨 + 라임 초대 칩 → 멤버 목록 → 구분선 → 메뉴 → 하단 나가기.
  static const List<Color> _faceTones = [
    Color(0xFFC3B4E8),
    Color(0xFF9CC3E8),
    Color(0xFF8FD9BA),
    Color(0xFFF0C48A),
    Color(0xFFC6CCC9),
  ];

  Widget _buildMemberDrawer() {
    final count = _memberCount ?? _members.length;
    return Drawer(
      backgroundColor: AppColors.surface,
      width: 272,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // 멤버 N + 라임 초대 칩
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  // 멤버 수만 표시 (전체 멤버 화면 제거)
                  Expanded(
                    child: Text(
                      '멤버 $count명',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color: AppColors.gray500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _invite,
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(TablerIcons.userPlus,
                              size: 15, color: AppColors.ink),
                          SizedBox(width: 5),
                          Text(
                            '초대',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.limeOn,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 멤버 목록
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                itemCount: _members.length,
                itemBuilder: (_, i) {
                  final me = _members[i] == '김연영'; // TODO: 실제 로그인 사용자
                  final name = _members[i];
                  final initial = name.isEmpty ? '?' : name.substring(0, 1);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _faceTones[i % _faceTones.length],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (me)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.lime,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '나',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.limeOn,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: AppColors.line100),
            // 메뉴 — 활동 사진 / 알림 설정
            _drawerItem(
              icon: TablerIcons.photo,
              label: '활동 사진',
              onTap: _openGroupPhotos,
            ),
            _drawerItem(
              icon: TablerIcons.bell,
              label: '알림 설정',
              onTap: _openGroupNotif,
            ),
            // 하단 그룹 나가기 (탈퇴) — 알림 설정과의 사이 구분선 제거
            _drawerItem(
              icon: TablerIcons.logout,
              label: '그룹 나가기',
              danger: true,
              onTap: () {
                _scaffoldKey.currentState?.closeEndDrawer();
                _confirmLeave();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // 드로어 메뉴 한 줄
  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? AppColors.actionDanger : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 13),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 초대 — 드로어를 닫고 초대 바텀시트를 연다
  void _invite() {
    _scaffoldKey.currentState?.closeEndDrawer();
    _showInviteSheet();
  }

  // ───────── 초대 바텀시트 (카카오톡 / 문자 / 링크 복사) ─────────
  // 실제 초대 링크 서버가 없어 자리표시 링크를 쓰고, 각 채널은 스낵바로 안내한다.
  void _showInviteSheet() {
    final link =
        'https://ploggo.app/invite/${widget.groupId.isEmpty ? 'demo' : widget.groupId}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
              const Text(
                '초대하기',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '친구에게 초대 링크를 보내 그룹에 함께해요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              _inviteRow(
                icon: TablerIcons.brandKakoTalk,
                label: '카카오톡',
                onTap: () {
                  Navigator.pop(ctx);
                  AppSnackBar.show(context, '카카오톡으로 초대 링크를 보냈어요');
                },
              ),
              const SizedBox(height: 8),
              _inviteRow(
                icon: TablerIcons.message2,
                label: '문자',
                onTap: () {
                  Navigator.pop(ctx);
                  AppSnackBar.show(context, '문자로 초대 링크를 보냈어요');
                },
              ),
              const SizedBox(height: 8),
              _inviteRow(
                icon: TablerIcons.link,
                label: '링크 복사',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  AppSnackBar.show(context, '초대 링크를 복사했어요');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 초대 채널 한 줄 (아이콘 + 라벨)
  Widget _inviteRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              TablerIcons.chevronRight,
              size: 20,
              color: AppColors.gray400,
            ),
          ],
        ),
      ),
    );
  }

  // 활동 사진 — 인증샷 모아보기 화면
  void _openGroupPhotos() {
    _scaffoldKey.currentState?.closeEndDrawer();
    if (widget.groupId.isEmpty) {
      AppSnackBar.show(context, '활동 사진을 불러올 수 없어요');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupPhotosScreen(groupId: widget.groupId),
      ),
    );
  }

  // 인증샷 탭 → 한 컷 상세(다크). 원본 게시글이 있을 때만 이동한다(더미 제외).
  void _openPhoto(_FeedItem item) {
    final post = item.source;
    if (post == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhotoDetailScreen(post: post)),
    );
  }

  // 그룹 알림 설정 — 항목별 토글 바텀시트 (채팅/활동/지금활동중/주간결과).
  Future<void> _openGroupNotif() async {
    _scaffoldKey.currentState?.closeEndDrawer();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const Text(
                  '그룹 알림',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _notifToggleRow('채팅 메시지', '새 메시지가 오면 알림', _notifChat,
                    () => setSt(() => _notifChat = !_notifChat)),
                _notifToggleRow('활동 인증', '멤버가 인증샷을 올릴 때', _notifActivity,
                    () => setSt(() => _notifActivity = !_notifActivity)),
                _notifToggleRow('지금 활동 중', '멤버가 근처에서 뛰기 시작할 때', _notifNearby,
                    () => setSt(() => _notifNearby = !_notifNearby)),
                _notifToggleRow('주간 결과', '일요일 밤 랭킹 요약', _notifWeekly,
                    () => setSt(() => _notifWeekly = !_notifWeekly)),
                const SizedBox(height: 18),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      '완료',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textOnBrand,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {}); // 바깥 상태에도 반영
  }

  // 알림 토글 한 줄 (제목 + 부제 + 스위치)
  Widget _notifToggleRow(
      String title, String sub, bool value, VoidCallback onToggle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 28,
              padding: const EdgeInsets.all(3),
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? AppColors.ink : AppColors.gray300,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? AppColors.lime : AppColors.surface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
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
                  item.isMessage
                      ? '${item.name} 님의 메시지를 신고하시겠어요?'
                      : '${item.name} 님의 활동 인증을 신고하시겠어요?',
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

  // ───────── 그룹 상세 정보 (멤버용 전체 화면) ─────────
  // ⓘ 아이콘 → 차콜 헤더 + 이번주 활동량 + 주간 랭킹 화면(GroupInfoScreen).
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupInfoScreen(
          group: g,
          groupName: widget.groupName,
          memberCount: _memberCount ?? g?.memberCount ?? 0,
          todayActiveCount: _todayActiveCount,
        ),
      ),
    );
  }

  // ───────── 그룹 탈퇴 (탈퇴는 여기서만 가능 — 기획서 GRP-05) ─────────
  Future<void> _confirmLeave() async {
    // POPUPS §8: 파괴적 액션이지만 빨강 버튼을 쓰지 않는다(다크/라임 2색 톤 유지).
    // 경고 아이콘 + 다크 실행 버튼, 손실은 본문 텍스트로 명시한다.
    final ok = await AppDialog.show(
      context,
      title: '그룹에서 나갈까요?',
      message: '지금까지 쌓은 그룹 기여 기록이 사라져요',
      cancelText: '취소',
      confirmText: '나가기',
      warn: true,
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
    AppSnackBar.show(context, '그룹에서 탈퇴하였습니다');
    ref.invalidate(homeViewProvider); // 홈 '우리 동네 그룹'도 같이 갱신
    // 탈퇴하면 채팅방(피드)을 즉시 닫고 그룹 홈으로 나간다.
    // 피드는 push 로 열린 라우트이므로 pop 으로 확실히 닫는다(go 만으로는 남을 수 있음).
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/group');
    }
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
              // 채팅 배경(빈 곳)을 누르면 키보드가 내려가게 한다.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  controller: _feedScroll,
                  // 스크롤을 시작하면 키보드가 내려가게
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  // 입력창이 아래를 차지하므로 여백을 줄임
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  children: _buildFeed(),
                ),
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                TablerIcons.chevronLeft,
                size: 27,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          // 그룹 대표 썸네일 (없으면 라임 아이콘 타일)
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 10),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(13),
            ),
            child: (_groupImageUrl != null &&
                    _groupImageUrl!.startsWith('http'))
                ? Image.network(
                    _groupImageUrl!,
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                  )
                // 미설정 시 기본 마스코트 썸네일
                : Image.asset(
                    'assets/images/ploggo_default.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.lime,
                      alignment: Alignment.center,
                      child: const Icon(TablerIcons.users,
                          size: 21, color: AppColors.ink),
                    ),
                  ),
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
                // 부제목: ● 멤버 N명 · 오늘 M명 활동 (오늘 활동자가 있을 때만 뒤 절 표시)
                Row(
                  children: [
                    if (_memberCount != null) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.link,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        _memberCount == null
                            ? '멤버 확인 중…'
                            : (_todayActiveCount > 0
                                ? '멤버 $_memberCount명 · 오늘 $_todayActiveCount명 활동'
                                : '멤버 $_memberCount명'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
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
          // 그룹 정보 (가입 전에 봤던 소개·동네·인원)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 정보 화면으로 이동하기 전에 포커스를 풀어, 돌아왔을 때
            // 키보드가 자동으로 다시 올라오지 않게 한다.
            onTap: () {
              FocusScope.of(context).unfocus();
              _showGroupInfo();
            },
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                TablerIcons.infoCircle,
                size: 24,
                color: AppColors.ink,
              ),
            ),
          ),
          // 오른쪽 위 ≡ → 오른쪽 멤버 드로어 열기
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 드로어를 열기 전에 포커스를 풀어, 드로어를 닫고 나왔을 때
            // 키보드가 자동으로 다시 올라오는 것을 막는다.
            onTap: () {
              FocusScope.of(context).unfocus();
              _scaffoldKey.currentState?.openEndDrawer();
            },
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                TablerIcons.menu2,
                size: 24,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 활동 공유 카드 (A안) ─────────────────────────
  // 가입 등 시스템 알림 — 가운데 회색 칩 (목업의 '오늘' 칩과 같은 톤)
  Widget _systemNotice(String text) {
    // 가입 등 시스템 알림 — 날짜 칩처럼 알약(pill) 모양으로 감싸되,
    // 색은 어두운 회색으로 (날짜 칩과 구분되도록).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.gray400,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
      backgroundColor: AppColors.surfaceSoft,
      backgroundImage: (photo != null && photo.isNotEmpty)
          ? NetworkImage(photo)
          : null,
      // 사진이 없으면 이름 첫 글자를 이니셜로 표시
      child: (photo != null && photo.isNotEmpty)
          ? null
          : Text(
              item.name.isEmpty ? '?' : item.name.substring(0, 1),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
    );

    final bubble = Container(
      // 시각 라벨('오전 7:30')이 옆에 붙으므로 폭을 조금 여유 있게 잡는다
      constraints: const BoxConstraints(maxWidth: 216),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        // 내 말풍선: 유일 액센트 라임(bubbleMine) + 라임 위 글씨(textOnBubbleMine)
        color: mine ? AppColors.bubbleMine : AppColors.surface,
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
        style: TextStyle(
          fontSize: 14.5,
          height: 1.5,
          // 글씨체 더 얇게
          fontWeight: FontWeight.w400,
          // 내 말풍선(라임 위)은 limeOn, 상대 말풍선(흰 위)은 잉크.
          color: mine ? AppColors.textOnBubbleMine : AppColors.textPrimary,
        ),
      ),
    );

    // 시각 라벨 공통 스타일
    const timeStyle = TextStyle(fontSize: 12, color: AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: mine
          // 내 메시지: 시각(말풍선 아래쪽)을 말풍선 왼쪽에 두고 오른쪽 정렬
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 2),
                  child: Text(_timeLabel(item.date), style: timeStyle),
                ),
                Flexible(child: bubble),
              ],
            )
          // 남의 메시지: 아바타 → (이름 + 말풍선) + 오른쪽에 신고 깃발(위)·시각(아래)
          : Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatar,
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textOnTint,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 말풍선 높이에 맞춰 신고 깃발은 위, 시각은 아래로 벌린다
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(child: bubble),
                            const SizedBox(width: 6),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 신고 깃발 (목업: 말풍선 오른쪽 위)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _showReport(item),
                                  child: const Icon(
                                    TablerIcons.flag,
                                    size: 16,
                                    color: AppColors.gray500,
                                  ),
                                ),
                                // 시각 (목업: 말풍선 오른쪽 아래)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    _timeLabel(item.date),
                                    style: timeStyle,
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
                // 엔터는 줄바꿈만. 전송은 오른쪽 전송 아이콘으로만 한다.
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '메시지 입력',
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
            // 전송 버튼 — 글자가 있으면 라임 배경 + 검정 선(send) 아이콘으로,
            // 비어 있으면 흐린 회색으로. 입력 변화에 맞춰 색이 바뀐다.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _msgController,
              builder: (context, value, _) {
                final bool active = value.text.trim().isNotEmpty;
                return GestureDetector(
                  onTap: (_sending || !active) ? null : _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // 글자 입력 시 라임 배경, 없으면 흐린 배경
                      color: active ? AppColors.lime : AppColors.surfaceSoft,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.ink,
                            ),
                          )
                        : Icon(
                            TablerIcons.send,
                            // 라임 배경 위엔 검정 선 아이콘, 빈 상태엔 회색
                            color: active ? AppColors.ink : AppColors.gray400,
                            size: 21,
                          ),
                  ),
                );
              },
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
      backgroundColor: AppColors.surfaceSoft,
      backgroundImage: (photo != null && photo.isNotEmpty)
          ? NetworkImage(photo)
          : null,
      // 사진이 없으면 이름 첫 글자를 이니셜로 표시
      child: (photo != null && photo.isNotEmpty)
          ? null
          : Text(
              item.name.isEmpty ? '?' : item.name.substring(0, 1),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
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
    // 목업 활동 카드: 헤더(아바타·이름·시각·신고) → 인증샷 → 통계·하트
    // TODO(활동 기록 상세): 카드 전체 탭 → ActivityDetailScreen 이동은 보류.
    //   그 화면은 걸음·kcal·몸무게·적립 포인트·경로 좌표·종류별 수거량이 필요한데
    //   피드 게시글에는 이 값들이 없어(총 수거 개수만 존재) 지어내지 않고 남겨둔다.
    //   인증샷 탭은 위에서 한 컷 상세(PhotoDetailScreen)로 연결했다.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 줄
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                // 실제로는 닉네임만 표시 (시간·목적지 등 부가 정보 제거)
                // 신고 깃발·시각은 카드 바깥 오른쪽(_cardFlagTime)으로 뺐다.
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // 인증샷 (좌우 12 여백, radius14) — 탭하면 한 컷 상세로 이동
          // TODO: 실제 사진(Image.network(item.imageUrl))으로 교체
          if (item.hasPhoto)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: item.source != null ? () => _openPhoto(item) : null,
              child: Container(
                height: 132,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: (item.imageUrl?.startsWith('http') ?? false)
                    ? Image.network(
                        item.imageUrl!,
                        width: double.infinity,
                        height: 132,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          TablerIcons.camera,
                          size: 32,
                          color: AppColors.gray400,
                        ),
                      )
                    : const Text(
                        '활동 사진',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray350,
                        ),
                      ),
              ),
            ),
          // 통계 + 하트
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            child: Row(
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

  // 활동 카드 오른쪽 바깥: 신고 깃발(위) + 시각(아래) — 카드 높이에 맞춰 벌린다.
  Widget _cardFlagTime(_FeedItem item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showReport(item),
          child: const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(TablerIcons.flag, size: 17, color: AppColors.gray500),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _timeLabel(item.date),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ],
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
  final GroupPost? source; // 원본 게시글 — 한 컷 상세로 넘길 때 사용(더미는 null)
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
    this.source,
  });
}