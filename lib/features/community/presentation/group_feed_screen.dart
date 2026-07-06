import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';

/// 줍다행 - 그룹 세부 화면 (활동 공유 피드)
/// 채팅 기능 없음. 멤버들의 플로깅 결과를 보고 '좋아요'만 누름.
/// 위치 권장: lib/features/community/presentation/group_feed_screen.dart
class GroupFeedScreen extends StatefulWidget {
  final String groupName;
  final int memberCount;

  const GroupFeedScreen({
    super.key,
    this.groupName = '00동 같이 주워봐요',
    this.memberCount = 12,
  });

  @override
  State<GroupFeedScreen> createState() => _GroupFeedScreenState();
}

class _GroupFeedScreenState extends State<GroupFeedScreen> {
  // 피드 데이터 (placeholder — 실제 그룹 활동 공유로 교체)
  // date = 게시(=활동) 시각. TODO: 실제 활동 데이터의 DateTime으로 교체
  final List<_FeedItem> _items = [
    _FeedItem(
      '김연영',
      DateTime.now().subtract(const Duration(hours: 2)),
      '2.1 km',
      33,
      '00:42',
      likes: 5,
      liked: true,
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
  final List<String> _members = const [
    '김연영',
    '박서연',
    '이준호',
    '최민지',
    '정우성',
    '한소희',
    '오정환',
    '유가을',
  ];

  void _toggleLike(_FeedItem it) {
    setState(() {
      it.liked = !it.liked;
      it.likes += it.liked ? 1 : -1;
    });
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
      widgets.add(_feedCard(it));
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Widget _dateChip(String label) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.cardBG,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ───────── 오른쪽 위 메뉴(≡): 멤버 보기 / 신고 / 그룹 탈퇴 ─────────
  void _showGroupMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _menuItem(
              icon: Icons.group_outlined,
              label: '멤버 보기',
              onTap: () {
                Navigator.pop(ctx);
                _showMembers();
              },
            ),
            _menuItem(
              icon: Icons.logout,
              label: '그룹 탈퇴',
              danger: true,
              onTap: () {
                Navigator.pop(ctx);
                _confirmLeave();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }

  // ───────── 멤버 보기 ─────────
  void _showMembers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Text(
                    '멤버 ${_members.length}명',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: _members.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryPale,
                    child: Icon(
                      Icons.person,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  title: Text(
                    _members[i],
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
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
  void _showReport(_FeedItem item) {
    // [사유, 설명]
    const reasons = [
      ['부정 활동', '고의적 조작 의심 (이동수단 이용, 비정상 수치 등)'],
      ['기록 오류', '기록이 잘못 찍힘 (GPS 튐, 앱 오작동 등)'],
      ['기타', '직접 작성해 주세요'],
    ];
    String? selected;
    final etcController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final isEtc = selected == '기타';
          // 사유 선택 필수 + 기타면 입력까지 있어야 활성
          final canSubmit =
              selected != null &&
              (!isEtc || etcController.text.trim().isNotEmpty);
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.name}님의 활동 신고',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 사유 선택 (커스텀 옵션 행)
                  ...reasons.map((r) {
                    final on = selected == r[0];
                    return GestureDetector(
                      onTap: () => setSt(() => selected = r[0]),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: on ? AppColors.primaryPale : AppColors.appBG,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: on ? AppColors.primary : AppColors.divider,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 라디오 표시
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: on
                                      ? AppColors.primary
                                      : AppColors.textTertiary,
                                  width: 2,
                                ),
                              ),
                              child: on
                                  ? Center(
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r[0],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r[1],
                                    style: const TextStyle(
                                      fontSize: 12,
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
                  }),
                  // 기타 선택 시 입력창
                  if (isEtc)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: TextField(
                        controller: etcController,
                        autofocus: true,
                        maxLength: 100,
                        maxLines: 2,
                        onChanged: (_) => setSt(() {}),
                        decoration: InputDecoration(
                          hintText: '신고 사유를 입력해 주세요',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                          filled: true,
                          fillColor: AppColors.appBG,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.divider,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.divider,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.divider,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: '취소',
                          onTap: () => Navigator.pop(ctx),
                          type: AppButtonType.secondary,
                          expand: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: '신고',
                          enabled: canSubmit,
                          type: AppButtonType.danger,
                          onTap: () {
                            Navigator.pop(ctx);
                            // TODO: 실제 신고 접수 처리
                            //   대상: item(활동) / 사유: selected
                            //   기타면 상세 사유: etcController.text
                            AppSnackBar.show(context, '신고가 접수됐어요');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────── 그룹 탈퇴 (탈퇴는 여기서만 가능 — 기획서 GRP-05) ─────────
  Future<void> _confirmLeave() async {
    final ok = await AppDialog.show(
      context,
      title: '그룹 탈퇴',
      message: '${widget.groupName}에서 탈퇴하시겠습니까?',
      cancelText: '아니오',
      confirmText: '탈퇴',
      danger: true,
    );
    if (ok == true && mounted) {
      // TODO: 실제 그룹 탈퇴 로직 (소속 해제 Firestore)
      AppSnackBar.show(context, '그룹에서 탈퇴했어요');
      context.go('/group');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryPale,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: _buildFeed(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 상단 바 ─────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: AppColors.cardBG,
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '멤버 ${widget.memberCount}명',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // 오른쪽 위 메뉴 (≡)
          IconButton(
            icon: const Icon(Icons.menu),
            color: AppColors.textSecondary,
            onPressed: _showGroupMenu,
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 활동 공유 카드 (A안) ─────────────────────────
  Widget _feedCard(_FeedItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias, // 사진 모서리 둥글게
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 봉투 인증샷 (스킵으로 마친 활동은 사진 없음)
          // TODO: 실제 사진(Image.network(item.photoUrl))으로 교체
          if (item.hasPhoto)
            Container(
              height: 160,
              width: double.infinity,
              color: AppColors.primaryPale,
              alignment: Alignment.center,
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 32,
                color: AppColors.textTertiary,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 작성자 + 시간 + (오른쪽) 좋아요
                Row(
                  children: [
                    // TODO: 실제 프로필 이미지로 교체
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryPale,
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                    ),
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
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _reportButton(item),
                  ],
                ),
                const SizedBox(height: 12),
                // 결과 요약 (왼쪽) + 좋아요 (오른쪽 끝)
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            _statInline('거리', item.distance),
                            _dot(),
                            _statInline('수거', '${item.trash}개'),
                            _dot(),
                            _statInline('시간', item.duration),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _likeButton(item),
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
  Widget _statInline(String label, String value) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 14,
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
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '·',
        style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _reportButton(_FeedItem item) {
    return GestureDetector(
      onTap: () => _showReport(item),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(
          Icons.flag_outlined,
          size: 18,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _likeButton(_FeedItem item) {
    return GestureDetector(
      onTap: () => _toggleLike(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: item.liked
              ? AppColors.error.withValues(alpha: 0.10)
              : AppColors.appBG,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.liked ? Icons.favorite : Icons.favorite_border,
              size: 16,
              color: item.liked ? AppColors.error : AppColors.textTertiary,
            ),
            const SizedBox(width: 5),
            Text(
              '${item.likes}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: item.liked ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
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
  _FeedItem(
    this.name,
    this.date,
    this.distance,
    this.trash,
    this.duration, {
    this.hasPhoto = true,
    this.likes = 0,
    this.liked = false,
  });
}
