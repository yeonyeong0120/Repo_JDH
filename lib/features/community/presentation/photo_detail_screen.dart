import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:share_plus/share_plus.dart'; // 시스템 공유 시트

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/features/community/domain/group.dart';

// ============================================================
// 한 컷 (Startline 19 — 인증샷 단일 상세, 다크)
//  - 활동 사진 그리드에서 타일 탭으로 진입.
//  - 실데이터: GroupPost(작성자·인증샷·거리·수거 개수·시간·시각·내 사진 여부).
//  - 목업의 kg·분류별(캔/페트/종이) 수치는 앱 데이터에 없어, 실제로 있는
//    거리·총 수거 개수만 칩으로 보여준다.
//  - 상단 더보기(dots) → 저장 / 공유하기 / 신고하기 시트.
//    저장은 스낵바 안내, 공유는 share_plus 시스템 공유, 신고는 사유 선택 시트.
//  - 삭제/자랑하기는 전용 서비스가 없어 준비 중 안내(플레이스홀더).
// ============================================================

class PhotoDetailScreen extends StatelessWidget {
  final GroupPost post;

  const PhotoDetailScreen({super.key, required this.post});

  // 시각 라벨 — '2026. 9. 2. 오전 9:12'
  String _dateLabel(DateTime d) {
    final period = d.hour < 12 ? '오전' : '오후';
    var hh = d.hour % 12;
    if (hh == 0) hh = 12;
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}. ${d.month}. ${d.day}. $period $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final url = post.imageUrl;
    // 메타 줄: 시각 + (활동 시간이 있으면) 뒤에 이어붙임.
    final meta = post.duration.isEmpty
        ? _dateLabel(post.createdAt)
        : '${_dateLabel(post.createdAt)} · ${post.duration} 활동';

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _topBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.screenPad,
                  Gap.sm,
                  Gap.screenPad,
                  Gap.lg,
                ),
                children: [
                  // 인증샷 영역 (다크 서페이스)
                  AspectRatio(
                    aspectRatio: 0.82,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: (url != null && url.startsWith('http'))
                          ? Image.network(
                              url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => _photoPlaceholder(),
                            )
                          : _photoPlaceholder(),
                    ),
                  ),
                  Gap.h20,
                  // 작성자 (실데이터). 목업의 장소명은 앱 데이터에 없어 작성자명을 쓴다.
                  Text(
                    post.userName.isEmpty ? '플로거' : post.userName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppColors.surface,
                    ),
                  ),
                  Gap.h8,
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray400,
                    ),
                  ),
                  Gap.h16,
                  // 칩 — 실제로 있는 거리·총 수거 개수만.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (post.distance.isNotEmpty)
                        _chip(post.distance, accent: true),
                      _chip('수거 ${post.trash}개'),
                    ],
                  ),
                ],
              ),
            ),
            _bottomBar(context),
          ],
        ),
      ),
    );
  }

  // 상단 바 — 뒤로 / 가운데 '한 컷' / 더보기
  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, Gap.xs, 4, Gap.xs),
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
                color: AppColors.surface,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '한 컷',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.surface,
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showMoreSheet(context),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                TablerIcons.dots,
                size: 22,
                color: AppColors.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────── 더보기(dots) 메뉴 — 저장 / 공유하기 / 신고하기 ─────────
  // 화면에 별도 저장·공유 버튼을 두지 않고, 상단 더보기 하나로 모아 연결한다.
  void _showMoreSheet(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              _moreRow(
                icon: TablerIcons.download,
                label: '저장',
                onTap: () {
                  Navigator.pop(ctx);
                  _saveImage(context);
                },
              ),
              _moreRow(
                icon: TablerIcons.share2,
                label: '공유하기',
                onTap: () {
                  Navigator.pop(ctx);
                  _shareImage();
                },
              ),
              _moreRow(
                icon: TablerIcons.flag,
                label: '신고하기',
                danger: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportSheet(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 더보기 메뉴 한 줄
  Widget _moreRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? AppColors.actionDanger : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 저장 — 실제 갤러리 저장 백엔드가 없어 스낵바로만 안내.
  void _saveImage(BuildContext context) {
    AppSnackBar.show(context, '사진을 저장했어요', kind: SnackKind.success);
  }

  // 공유 — share_plus 시스템 공유 시트.
  Future<void> _shareImage() async {
    final url = post.imageUrl;
    final who = post.userName.isEmpty ? '플로거' : post.userName;
    final text = (url != null && url.isNotEmpty)
        ? '$who님의 플로깅 인증샷\n$url'
        : '$who님의 플로깅 인증샷을 플로고에서 확인해요.';
    // share_plus 11 이상에서 deprecated 경고가 뜨면 아래로 교체:
    //   SharePlus.instance.share(ShareParams(text: text))
    await Share.share(text);
  }

  // ───────── 사진 신고 시트 (사유 라디오 + 신고하기) ─────────
  void _showReportSheet(BuildContext context) {
    const reasons = [
      '부적절한 사진이에요',
      '욕설·비방이 담겨 있어요',
      '광고·스팸이에요',
      '활동과 관계없는 사진이에요',
      '기타',
    ];
    String? selected;

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
          final canSubmit = selected != null;
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
                Text('사진 신고', style: AppType.title2),
                const SizedBox(height: 6),
                Text(
                  '신고 내용은 운영진만 볼 수 있어요.',
                  style: AppType.body.copyWith(color: AppColors.textSecondary),
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
                const SizedBox(height: 6),
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
                          // TODO: 실제 신고 접수 (대상 post · 사유 selected)
                          AppSnackBar.show(
                            context,
                            '신고가 접수됐어요. 운영팀이 24시간 내에 확인해요',
                            duration: const Duration(milliseconds: 3200),
                          );
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

  Widget _photoPlaceholder() {
    return const Center(
      child: Text(
        '인증샷 (사용자 사진)',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.gray400,
        ),
      ),
    );
  }

  // 칩 — accent(라임 면 + 잉크 글씨) 또는 다크 칩.
  Widget _chip(String label, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent ? AppColors.lime : AppColors.darkChip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: accent ? AppColors.limeOn : AppColors.surface,
        ),
      ),
    );
  }

  // 하단 바 — (내 사진이면) 삭제 + 자랑하기. 둘 다 준비 중 안내.
  Widget _bottomBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.screenPad,
        Gap.md,
        Gap.screenPad,
        MediaQueryData.fromView(View.of(context)).padding.bottom + Gap.md,
      ),
      child: Row(
        children: [
          if (post.isMine) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => AppSnackBar.show(context, '사진 삭제는 준비 중이에요'),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.darkChip,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  TablerIcons.trash,
                  size: 22,
                  color: AppColors.actionDanger,
                ),
              ),
            ),
            Gap.w12,
          ],
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => AppSnackBar.show(context, '자랑하기는 준비 중이에요'),
              child: Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(TablerIcons.share2, size: 20, color: AppColors.limeOn),
                    SizedBox(width: 8),
                    Text(
                      '자랑하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.limeOn,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
