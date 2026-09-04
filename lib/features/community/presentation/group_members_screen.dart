import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 초대 링크 복사(Clipboard)
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';

// ============================================================
// 그룹 멤버 (Startline 16 — 멤버 목록)
//  - 그룹 채팅 → 햄버거 메뉴 → 멤버 보기 로 진입.
//  - 실데이터: GroupService.memberNames(groupId) 로 실제 닉네임을 받아온다.
//    멤버 수는 넘겨받은 memberCount(groups/{id}.memberCount)를 우선 사용.
//  - 목업의 개인별 누적 수거량(kg)·활동 일수는 앱 데이터에 없어 표시하지 않는다.
//    (지어내지 않고, 실제로 있는 닉네임·인원만 보여준다.)
// ============================================================

class GroupMembersScreen extends StatefulWidget {
  final String groupId;

  /// groups/{id}.memberCount — 타이틀 '멤버 N명'에 사용.
  final int memberCount;

  const GroupMembersScreen({
    super.key,
    required this.groupId,
    this.memberCount = 0,
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  List<String> _members = [];
  bool _loading = true;

  // 아바타 톤 — 그룹 드로어와 같은 팔레트.
  static const List<Color> _faceTones = [
    Color(0xFFC3B4E8),
    Color(0xFF9CC3E8),
    Color(0xFF8FD9BA),
    Color(0xFFF0C48A),
    Color(0xFFC6CCC9),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.groupId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    List<String> names = [];
    try {
      // 넉넉히 가져온다 (미리보기 기본 8보다 크게).
      names = await GroupService.memberNames(widget.groupId, limit: 100);
    } catch (e) {
      debugPrint('[그룹 멤버] 목록 로드 실패: $e');
    }
    if (!mounted) return;
    setState(() {
      _members = names;
      _loading = false;
    });
  }

  // 초대하기 — 그룹 채팅 드로어와 동일한 초대 바텀시트를 연다.
  void _invite() {
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
              Text('초대하기', style: AppType.title2),
              const SizedBox(height: 6),
              Text(
                '친구에게 초대 링크를 보내 그룹에 함께해요.',
                style: AppType.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              _inviteChannelRow(
                icon: TablerIcons.brandKakoTalk,
                label: '카카오톡',
                onTap: () {
                  Navigator.pop(ctx);
                  AppSnackBar.show(context, '카카오톡으로 초대 링크를 보냈어요');
                },
              ),
              const SizedBox(height: 8),
              _inviteChannelRow(
                icon: TablerIcons.message2,
                label: '문자',
                onTap: () {
                  Navigator.pop(ctx);
                  AppSnackBar.show(context, '문자로 초대 링크를 보냈어요');
                },
              ),
              const SizedBox(height: 8),
              _inviteChannelRow(
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
  Widget _inviteChannelRow({
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
                style: AppType.label.copyWith(
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

  @override
  Widget build(BuildContext context) {
    // 실제 인원 수 — memberCount 우선, 없으면 받아온 이름 수.
    final count = widget.memberCount > 0 ? widget.memberCount : _members.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar('멤버 $count명'),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.progress,
                        strokeWidth: 2,
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        Gap.screenPad,
                        Gap.sm,
                        Gap.screenPad,
                        MediaQueryData.fromView(
                              View.of(context),
                            ).padding.bottom +
                            24,
                      ),
                      children: [
                        _inviteRow(),
                        Gap.h16,
                        if (_members.isEmpty)
                          _empty()
                        else
                          for (int i = 0; i < _members.length; i++) ...[
                            _MemberRow(
                              name: _members[i],
                              tone: _faceTones[i % _faceTones.length],
                            ),
                            if (i != _members.length - 1) Gap.h8,
                          ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, Gap.sm, Gap.screenPad, 0),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
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
          Text(title, style: AppType.title2),
        ],
      ),
    );
  }

  // 멤버 초대하기 — 소프트 그레이 알약 행 (탭 → 초대 바텀시트)
  Widget _inviteRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _invite,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(TablerIcons.userPlus, size: 20, color: AppColors.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '멤버 초대하기',
                style: AppType.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
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

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(TablerIcons.users, size: 40, color: AppColors.gray400),
          Gap.h12,
          Text(
            '멤버를 불러오지 못했어요',
            style: AppType.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── 멤버 한 줄 (아바타 + 닉네임) ──
// 개인별 kg·활동 일수는 앱 데이터에 없어 넣지 않는다.
class _MemberRow extends StatelessWidget {
  final String name;
  final Color tone;
  const _MemberRow({required this.name, required this.tone});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.substring(0, 1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name.isEmpty ? '플로거' : name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
