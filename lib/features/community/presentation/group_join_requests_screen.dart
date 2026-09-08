import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';

/// 승인 후 가입(isPublic:false) 그룹의 가입 요청 관리 (§5·§6)
/// - 그룹장 전용 전용 화면: '대기 중' / '처리됨' 탭.
/// - 요청자 프로필 카드(누적 수거량·활동 일수·뱃지) + 승인/거절.
/// 위치: lib/features/community/presentation/group_join_requests_screen.dart

// ───────────────────────── §6 승인/거절 확인 팝업 ─────────────────────────

/// 승인 확인 — 58 원(#EDEFEE) + 요청자 이니셜. 확인 시 true.
Future<bool> confirmApproveJoin(BuildContext context, JoinRequest req) async {
  final initial = req.userName.isEmpty ? '?' : req.userName.substring(0, 1);
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.neutral900.withValues(alpha: 0.45),
    builder: (_) => _ConfirmDialog(
      tileBg: const Color(0xFFEDEFEE),
      tileChild: Text(
        initial,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: AppColors.gray700,
        ),
      ),
      title: '${req.userName} 님을\n멤버로 받을까요?',
      body: '승인하면 바로 그룹 채팅과\n주간 랭킹에 참여해요',
      confirmText: '승인',
      confirmDanger: false,
    ),
  );
  return ok == true;
}

/// 거절 확인 — 58 원(#FDEBE7) + ti-userX. 확인 시 true.
Future<bool> confirmRejectJoin(BuildContext context, JoinRequest req) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.neutral900.withValues(alpha: 0.45),
    builder: (_) => _ConfirmDialog(
      tileBg: const Color(0xFFFDEBE7),
      tileChild: const Icon(TablerIcons.userX, size: 27, color: Color(0xFFE4573D)),
      title: '${req.userName} 님의 요청을\n거절할까요?',
      body: '요청은 목록에서 사라져요.\n거절 사유는 상대에게 보이지 않아요',
      confirmText: '거절',
      confirmDanger: true,
    ),
  );
  return ok == true;
}

/// §6 공용 확인 팝업 — 원형 타일(아이콘/이니셜) + 제목 + 취소/확인.
class _ConfirmDialog extends StatelessWidget {
  final Color tileBg;
  final Widget tileChild;
  final String title;
  final String body;
  final String confirmText;
  final bool confirmDanger;

  const _ConfirmDialog({
    required this.tileBg,
    required this.tileChild,
    required this.title,
    required this.body,
    required this.confirmText,
    required this.confirmDanger,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tileBg, shape: BoxShape.circle),
              child: tileChild,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                height: 1.4,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.6,
                fontWeight: FontWeight.w500,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _dialogBtn(
                    label: '취소',
                    bg: AppColors.surfaceSoft,
                    fg: AppColors.gray700,
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _dialogBtn(
                    label: confirmText,
                    bg: confirmDanger ? AppColors.actionDanger : AppColors.ink,
                    fg: Colors.white,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogBtn({
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── §5 가입 요청 전용 화면 ─────────────────────────

class GroupJoinRequestsScreen extends StatefulWidget {
  final String groupId;
  final int memberCount;

  const GroupJoinRequestsScreen({
    super.key,
    required this.groupId,
    this.memberCount = 0,
  });

  @override
  State<GroupJoinRequestsScreen> createState() =>
      _GroupJoinRequestsScreenState();
}

class _GroupJoinRequestsScreenState extends State<GroupJoinRequestsScreen> {
  int _tab = 0; // 0 대기 중 / 1 처리됨
  bool _busy = false; // 승인/거절 처리 중 중복 방지

  Future<void> _approve(JoinRequest req) async {
    if (_busy) return;
    if (!await confirmApproveJoin(context, req)) return;
    setState(() => _busy = true);
    try {
      await GroupService.approveJoin(widget.groupId, req);
      if (mounted) AppSnackBar.show(context, '${req.userName} 님을 멤버로 받았어요', kind: SnackKind.success);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '처리에 실패했어요', kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(JoinRequest req) async {
    if (_busy) return;
    if (!await confirmRejectJoin(context, req)) return;
    setState(() => _busy = true);
    try {
      await GroupService.rejectJoin(widget.groupId, req);
      if (mounted) AppSnackBar.show(context, '요청을 거절했어요');
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '처리에 실패했어요', kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            _memberRow(),
            _tabs(),
            Expanded(
              child: _tab == 0 ? _pendingList() : _processedList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 22, 8),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(TablerIcons.chevronLeft, size: 26, color: AppColors.ink),
            ),
          ),
          const Text(
            '가입 요청',
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

  Widget _memberRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(TablerIcons.users, size: 18, color: AppColors.gray700),
            const SizedBox(width: 9),
            Text(
              '멤버 ${widget.memberCount}명',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: AppColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 6),
      child: StreamBuilder<List<JoinRequest>>(
        stream: GroupService.watchPendingRequests(widget.groupId),
        builder: (_, snap) {
          final n = snap.data?.length ?? 0;
          return Row(
            children: [
              _tabChip('대기 중${n > 0 ? ' $n' : ''}', 0),
              const SizedBox(width: 8),
              _tabChip('처리됨', 1),
            ],
          );
        },
      ),
    );
  }

  Widget _tabChip(String label, int value) {
    final on = _tab == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = value),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? AppColors.ink : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: on ? FontWeight.w800 : FontWeight.w700,
            color: on ? AppColors.textOnBrand : AppColors.gray700,
          ),
        ),
      ),
    );
  }

  Widget _pendingList() {
    return StreamBuilder<List<JoinRequest>>(
      stream: GroupService.watchPendingRequests(widget.groupId),
      builder: (_, snap) {
        final list = snap.data ?? const <JoinRequest>[];
        if (list.isEmpty) return _empty('대기 중인 요청이 없어요');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
          itemCount: list.length,
          itemBuilder: (_, i) => _requestCard(list[i], pending: true),
        );
      },
    );
  }

  Widget _processedList() {
    return StreamBuilder<List<JoinRequest>>(
      stream: GroupService.watchProcessedRequests(widget.groupId),
      builder: (_, snap) {
        final list = snap.data ?? const <JoinRequest>[];
        if (list.isEmpty) return _empty('처리된 요청이 없어요');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
          itemCount: list.length,
          itemBuilder: (_, i) => _requestCard(list[i], pending: false),
        );
      },
    );
  }

  Widget _empty(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: AppColors.gray500),
      ),
    );
  }

  // 요청자 카드 — 아바타/이름/지역 + 3지표 그리드 + (대기중이면) 거절/승인
  Widget _requestCard(JoinRequest req, {required bool pending}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line100, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(req),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      req.screenMeta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!pending) _statusChip(req.status),
            ],
          ),
          const SizedBox(height: 14),
          if (req.hasRecord)
            _metrics(req)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(TablerIcons.seedling, size: 18, color: AppColors.gray500),
                  SizedBox(width: 9),
                  Text(
                    '아직 플로깅 기록이 없어요',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
          if (pending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: _cardBtn(
                    '거절',
                    bg: AppColors.surfaceSoft,
                    fg: const Color(0xFFE4573D),
                    onTap: _busy ? null : () => _reject(req),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _cardBtn(
                    '승인',
                    bg: AppColors.ink,
                    fg: Colors.white,
                    icon: TablerIcons.check,
                    onTap: _busy ? null : () => _approve(req),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatar(JoinRequest req) {
    final photo = req.photoUrl;
    final initial = req.userName.isEmpty ? '?' : req.userName.substring(0, 1);
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFEE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: (photo != null && photo.isNotEmpty)
          ? Image.network(photo, width: 52, height: 52, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialText(initial))
          : _initialText(initial),
    );
  }

  Widget _initialText(String initial) => Text(
        initial,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.gray700,
        ),
      );

  // 3지표 그리드 (누적 수거량 / 활동 일수 / 뱃지)
  Widget _metrics(JoinRequest req) {
    return Row(
      children: [
        _metric(req.cumulativeKgText, '누적kg'),
        _metricDivider(),
        _metric('${req.activeDays}', '활동 일수'),
        _metricDivider(),
        _metric('${req.badgeCount}', '뱃지'),
      ],
    );
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.gray500),
          ),
        ],
      ),
    );
  }

  Widget _metricDivider() => Container(
        width: 1,
        height: 26,
        color: AppColors.line100,
      );

  Widget _statusChip(String status) {
    final rejected = status == JoinStatus.rejected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: rejected ? const Color(0xFFFDEBE7) : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rejected ? '거절됨' : '승인됨',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: rejected ? const Color(0xFFE4573D) : AppColors.gray700,
        ),
      ),
    );
  }

  Widget _cardBtn(
    String label, {
    required Color bg,
    required Color fg,
    required VoidCallback? onTap,
    IconData? icon,
  }) {
    final Color on = onTap == null ? AppColors.gray500 : fg;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.gray200 : bg,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              // 승인 버튼 체크는 잉크 면 위 라임 (완료 계열 강조)
              Icon(icon,
                  size: 19,
                  color: onTap == null ? AppColors.gray500 : AppColors.lime),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: on,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
