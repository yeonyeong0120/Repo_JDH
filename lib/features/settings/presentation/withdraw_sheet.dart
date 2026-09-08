import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';
import 'package:repo_jdh/features/mypage/data/badge_service.dart';
import 'package:repo_jdh/features/mypage/domain/badge.dart';
import 'package:repo_jdh/features/shop/data/shop_service.dart';

/// 탈퇴로 잃게 되는 것들. §2 손실 목록과 §3 본문이 같은 값을 쓴다.
class WithdrawStats {
  final double weightKg;
  final int points;
  final int badges;
  final int groups;

  const WithdrawStats({
    this.weightKg = 0,
    this.points = 0,
    this.badges = 0,
    this.groups = 0,
  });

  /// 누적 수거량을 소수 첫째 자리까지 (예: 48.2)
  String get kgText => ((weightKg * 10).round() / 10).toStringAsFixed(1);
}

/// 회원 탈퇴 흐름 — 디자인 명세 '회원 탈퇴' 문서 전체.
///
/// 설정 → 「탈퇴하기」에서 이 함수 하나만 부르면 된다.
///
/// ```
/// §2 안내 시트(무엇을 잃는지 + 동의)
///   └ §3 최종 확인 팝업(되돌릴 수 없음)
///        └ deleteAccount()
///             ├ 실패 → 스낵바
///             └ 성공 → §4 완료 화면 → /login
/// ```
///
/// 확인이 두 단계인 이유: §2는 **고지**(+동의 수집), §3은 **최종 확인**이다.
/// 역할이 달라 합치지 않는다.
Future<void> startWithdrawFlow(BuildContext context) async {
  // §2 — 동의까지 마치면 손실 수치를 들고 나온다.
  final stats = await showModalBottomSheet<WithdrawStats>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // 파괴적 흐름의 시작이라 딤이 한 단 더 어둡다(다른 시트는 .5).
    barrierColor: _dim,
    builder: (_) => const _WithdrawSheet(),
  );
  if (stats == null || !context.mounted) return;

  // §3 최종 확인 — deleteAccount 를 부르는 유일한 지점이다.
  final ok = await AppDialog.show(
    context,
    title: '정말 탈퇴하시겠어요?',
    message: '누적 ${stats.kgText}kg과 뱃지, 포인트가\n30일 후 완전히 삭제돼요',
    cancelText: '계속 이용하기', // 위 · 다크 (안전)
    confirmText: '탈퇴하기', // 아래 · 연회색 면 + 빨강 글자 (파괴)
    danger: true,
    softDanger: true,
    verticalButtons: true,
    icon: TablerIcons.alertTriangle,
    iconBg: const Color(0xFFFDEBE7),
    iconFg: const Color(0xFFE4573D),
    barrierColor: _dim,
  );
  if (ok != true || !context.mounted) return;

  try {
    await UserService.deleteAccount();
  } catch (_) {
    if (context.mounted) {
      AppSnackBar.show(context, '탈퇴하지 못했어요. 다시 로그인 후 시도해주세요');
    }
    return;
  }
  if (!context.mounted) return;

  // §4 완료 화면 — 성공을 조용히 넘기지 않는다.
  await Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => const _WithdrawDoneScreen(),
      fullscreenDialog: true,
    ),
  );
  if (context.mounted) context.go('/login');
}

/// 탈퇴 흐름 전용 딤 — 명세 rgba(20,24,22,.55).
const Color _dim = Color(0x8C141816);

// ───────────────────────── §2 안내 시트 ─────────────────────────

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet();

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  // 시트를 열 때마다 새로 만들어지므로 동의는 항상 false 에서 시작한다.
  bool _agree = false;
  bool _loading = true;
  WithdrawStats _stats = const WithdrawStats();

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
      _stats = WithdrawStats(
        weightKg: kg,
        points: points,
        badges: badges,
        groups: groups,
      );
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
              // 이 시트는 질문이 아니라 고지다.
              // '정말 탈퇴하시겠어요?'는 §3 최종 확인의 문장이라 여기 쓰지 않는다 —
              // 같은 질문이 두 번 나오면 두 번째가 무게를 잃는다.
              const Text(
                '탈퇴하기 전에 확인해주세요',
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

  // 잃게 되는 것 4가지. 0인 항목도 숨기지 않는다 —
  // 목록 길이가 변하면 시트 높이가 흔들린다.
  Widget _lossBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _lossRow(TablerIcons.trash, '누적 수거량', '${_stats.kgText}kg'),
          const SizedBox(height: 11),
          _lossRow(TablerIcons.coin, '보유 포인트', '${_comma(_stats.points)}P'),
          const SizedBox(height: 11),
          _lossRow(TablerIcons.award, '획득 뱃지', '${_stats.badges}개'),
          const SizedBox(height: 11),
          _lossRow(TablerIcons.users, '가입한 그룹', '${_stats.groups}개'),
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

  // 버튼 행 — 폭이 비대칭이다. 안전한 선택이 넓고 다크, 탈퇴는 120 고정.
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
          // 에러 토스트를 띄우지 않는다 — 체크박스가 답이다.
          onTap: _agree ? () => Navigator.pop(context, _stats) : null,
          child: Container(
            width: 120,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  _agree ? const Color(0xFFE4573D) : const Color(0xFFF1F3F2),
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

// ───────────────────────── §4 완료 화면 ─────────────────────────

/// 탈퇴 완료 — 잉크 풀스크린 + 라임 CTA.
///
/// 앱의 마지막 화면이고 뒤에 아무것도 없으므로 시트나 팝업이 아니라 화면이다.
/// 뒤로가기·닫기가 없고 유일한 출구는 「확인」이다.
/// 아이콘은 문을 나가는 글리프가 아니라 인사다 — 경고는 §2·§3에서 끝났고
/// 여기서는 배웅만 한다.
class _WithdrawDoneScreen extends StatelessWidget {
  const _WithdrawDoneScreen();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 뒤로가기로 빠져나갈 수 없다.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.lime.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    TablerIcons.handLoveYou,
                    size: 31,
                    color: AppColors.lime,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '그동안 함께 걸어줘서\n고마웠어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                // 30일 보관을 여기서 다시 말한다 —
                // 되돌릴 방법을 마지막으로 알려주는 자리다.
                const Text(
                  '계정은 30일간 보관돼요. 그 안에 다시\n로그인하면 기록이 그대로 살아나요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.7,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9BA29C),
                  ),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      // 다크 배경이라 이 화면만 버튼이 라임이다.
                      color: AppColors.lime,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
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
  }
}
