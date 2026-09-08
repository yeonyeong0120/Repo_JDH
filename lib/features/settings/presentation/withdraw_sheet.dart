import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/shop/data/shop_service.dart';

/// 회원 탈퇴 확인 시트 — 디자인 명세 POPUPS.md §18 (B형 바텀 시트).
///
/// 일반 확인 팝업(A형)과 달리 **무엇을 잃는지 먼저 보여주고 동의를 받는다.**
/// 되돌릴 수 없는 액션이라 동의 전에는 탈퇴 버튼이 눌리지 않는다.
///
/// 손실 목록의 수치는 실제 계정 데이터를 읽어 채운다 — 명세의 예시값
/// (48.2kg · 3,240P …)을 그대로 박아 두면 누가 탈퇴하든 같은 숫자가 나온다.
///
/// 반환값: 탈퇴를 확정하면 true, 그 외에는 null.
Future<bool?> showWithdrawSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // 명세 §18 — 이 시트만 딤이 한 단계 진하다 rgba(20,24,22,.55)
    barrierColor: const Color(0x8C141816),
    builder: (_) => const _WithdrawSheet(),
  );
}

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet();

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  bool _agree = false;
  bool _loading = true;

  double _weightKg = 0;
  int _points = 0;
  int _badges = 0;
  int _groups = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 잃게 되는 것들을 실제 계정에서 읽어 온다.
  // 하나라도 실패하면 그 항목만 0으로 남는다 — 탈퇴 자체를 막지는 않는다.
  Future<void> _load() async {
    double kg = 0;
    int points = 0;
    int badges = 0;
    int groups = 0;
    try {
      final stats = await BadgeService.loadStats();
      kg = stats.totalWeightKg;
    } catch (e) {
      debugPrint('[탈퇴] 누적 수거량 조회 실패: $e');
    }
    try {
      points = await ShopService.myPoints();
    } catch (e) {
      debugPrint('[탈퇴] 포인트 조회 실패: $e');
    }
    try {
      await BadgeService.loadEarned();
      badges = BadgeRepo.earnedBadges().length;
    } catch (e) {
      debugPrint('[탈퇴] 뱃지 조회 실패: $e');
    }
    try {
      // 이 앱은 1인 1그룹이라 소속이 있으면 1, 없으면 0이다.
      groups = (await GroupService.myGroupId()) != null ? 1 : 0;
    } catch (e) {
      debugPrint('[탈퇴] 그룹 조회 실패: $e');
    }
    if (!mounted) return;
    setState(() {
      _weightKg = kg;
      _points = points;
      _badges = badges;
      _groups = groups;
      _loading = false;
    });
  }

  /// 1234 → '1,234'
  String _comma(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // 명세: left/right 10, bottom 10 띄운 카드
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E6E4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                '정말 탈퇴하시겠어요?',
                style: TextStyle(
                  fontSize: 23,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 9),
              // '30일 후 완전히 삭제'만 잉크 700 으로 올려 강조한다.
              const Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.65,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray500,
                  ),
                  children: [
                    TextSpan(text: '탈퇴하면 아래 기록이 '),
                    TextSpan(
                      text: '30일 후 완전히 삭제',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(text: '되고, 되돌릴 수 없어요.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _lossBox(),
              _agreeRow(),
              const SizedBox(height: 18),
              _buttons(),
            ],
          ),
        ),
      ),
    );
  }

  // 잃게 되는 것 4가지.
  Widget _lossBox() {
    final kgText = ((_weightKg * 10).round() / 10).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _lossRow(TablerIcons.trash, '누적 수거량', '${kgText}kg'),
          const SizedBox(height: 11),
          _lossRow(TablerIcons.coin, '보유 포인트', '${_comma(_points)}P'),
          const SizedBox(height: 11),
          _lossRow(TablerIcons.award, '획득 뱃지', '$_badges개'),
          const SizedBox(height: 11),
          _lossRow(TablerIcons.users, '가입한 그룹', '$_groups개'),
        ],
      ),
    );
  }

  Widget _lossRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.gray700),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.gray700,
            ),
          ),
        ),
        // 값을 아직 못 읽었으면 숫자 대신 자리만 비워 둔다.
        Text(
          _loading ? '—' : value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // 동의 체크 — 행 전체가 탭 대상이다.
  Widget _agreeRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _agree = !_agree),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _agree
                  ? TablerIcons.squareRoundedCheckFilled
                  : TablerIcons.squareRounded,
              size: 23,
              color: _agree ? AppColors.textPrimary : const Color(0xFFC8CFCB),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                '위 내용을 확인했고, 포인트 소멸에 동의해요',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: _agree ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 버튼 행 — 폭이 비대칭이다. 계속 이용하기가 넓고, 탈퇴는 120 고정.
  Widget _buttons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                '계속 이용하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          // 동의 전에는 눌러도 아무 일이 없다.
          onTap: _agree ? () => Navigator.pop(context, true) : null,
          child: Container(
            width: 120,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _agree
                  ? const Color(0xFFE4573D)
                  : const Color(0xFFF1F3F2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              '탈퇴하기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _agree ? Colors.white : const Color(0xFFB7BEB9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
