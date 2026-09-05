import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/features/settings/presentation/terms_screen.dart';

/// 설정 화면 (Startline 목업 32 — 메뉴 → 설정 · 개인정보 설정)
/// 알림/활동/계정 섹션의 토글·값 행. 하단에 로그아웃·탈퇴 링크 + 버전.
///
/// 데이터 주의: 토글·알림시간·위치권한 값은 설정 저장 백엔드가 없어
/// 로컬 UI 상태(bool/문자열)로만 동작한다. 실제 영속화는 하지 않는다.
/// 연결된 계정은 로그인 계정 email 이 있으면 표시, 없으면 정적 문구.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── 로컬 UI 상태 (영속화 백엔드 없음) ──
  bool _reminderOn = true; // 활동 리마인더 토글
  TimeOfDay _reminderTime = const TimeOfDay(hour: 7, minute: 0); // 알림 시간 (로컬 상태)
  final String _locationMode = '앱 사용 중'; // 위치 정보 사용 (정적)

  // 연결된 계정 표시값. 로그인 email 이 있으면 채우고, 없으면 정적 문구.
  String _accountLabel = '카카오';

  // 앱 버전 (메뉴 화면과 동일하게 정적 문자열로 표기)
  static const String _appVersion = '플로고 v1.2.0';

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    try {
      final p = await UserService.loadProfileDetail();
      if (mounted && p.email.isNotEmpty) {
        setState(() => _accountLabel = p.email);
      }
    } catch (_) {
      // 실패 시 정적 문구 유지
    }
  }

  void _push(Widget screen) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => screen),
  );

  // 백엔드가 아직 없는 행을 눌렀을 때의 정직한 안내
  void _notReady() => AppSnackBar.show(context, '준비 중이에요');

  // ── 알림 시간 설정 (F-3): 시간 피커 → 로컬 상태 저장 + 스낵바 ──
  // 영속화 백엔드가 없어 고른 값은 화면 로컬 상태로만 유지한다.
  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: '알림 시간 설정',
    );
    if (picked == null || !mounted) return;
    setState(() => _reminderTime = picked);
    AppSnackBar.show(context, '알림 시간을 ${_formatTime(picked)}로 설정했어요');
  }

  // TimeOfDay → "오전/오후 N시" (분이 있으면 "N분" 추가)
  String _formatTime(TimeOfDay t) {
    final period = t.hour < 12 ? '오전' : '오후';
    var h = t.hour % 12;
    if (h == 0) h = 12;
    final base = '$period $h시';
    return t.minute == 0 ? base : '$base ${t.minute}분';
  }

  // ── 위치 정보 사용 (F-3): OS 앱 권한 설정 화면으로 이동 ──
  Future<void> _openLocationSettings() async {
    await Geolocator.openAppSettings();
  }

  // ── 데이터 내려받기 (F-3): 내보내기 요청 접수 스낵바 ──
  void _requestDataExport() =>
      AppSnackBar.show(context, '데이터 내보내기 요청을 접수했어요');

  // ── 로그아웃 (menu_screen 과 동일한 다이얼로그 패턴) ──
  Future<void> _confirmSignOut() async {
    final ok = await AppDialog.show(
      context,
      title: '로그아웃',
      message: '로그아웃 하시겠습니까?',
      cancelText: '아니오',
      confirmText: '로그아웃',
    );
    if (ok != true || !mounted) return;
    await UserService.signOut();
    if (mounted) context.go('/login');
  }

  // ── 회원 탈퇴 (menu_screen 과 동일한 다이얼로그 패턴) ──
  Future<void> _confirmDelete() async {
    final ok = await AppDialog.show(
      context,
      title: '회원 탈퇴',
      message: '정말 탈퇴하시겠습니까?\n\n활동 기록과 뱃지, 포인트가 모두 사라지며 되돌릴 수 없어요.',
      cancelText: '아니오',
      confirmText: '탈퇴',
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await UserService.deleteAccount();
    } catch (_) {
      if (mounted) {
        AppSnackBar.show(context, '탈퇴하지 못했어요. 다시 로그인 후 시도해주세요');
      }
      return;
    }
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
                children: [
                  // 알림 섹션
                  _sectionLabel('알림'),
                  _toggleRow(
                    '활동 리마인더',
                    _reminderOn,
                    (v) => setState(() => _reminderOn = v),
                  ),
                  _valueRow(
                    '알림 시간 설정',
                    _formatTime(_reminderTime),
                    onTap: _pickReminderTime,
                  ),
                  const SizedBox(height: 22),
                  // 활동 섹션
                  _sectionLabel('활동'),
                  _valueRow(
                    '위치 정보 사용',
                    _locationMode,
                    onTap: _openLocationSettings,
                  ),
                  _valueRow('데이터 내려받기', null, onTap: _requestDataExport),
                  const SizedBox(height: 22),
                  // 계정 섹션
                  _sectionLabel('계정'),
                  _valueRow('연결된 계정', _accountLabel, onTap: _notReady),
                  _valueRow(
                    '이용약관',
                    null,
                    onTap: () => _push(const TermsScreen()),
                  ),
                  _valueRow(
                    '개인정보 처리방침',
                    null,
                    onTap: () => _push(const TermsScreen()),
                  ),
                  const SizedBox(height: 26),
                  const Divider(color: AppColors.line100, height: 1),
                  const SizedBox(height: 18),
                  _accountActions(),
                  const SizedBox(height: 12),
                  const Text(
                    _appVersion,
                    style: TextStyle(fontSize: 12, color: AppColors.gray400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 상단 바 (뒤로 + 제목) ──
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 22, 12),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
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
          const Text(
            '설정',
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

  // ── 섹션 라벨 (회색 소문자 헤더) ──
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.gray400,
        ),
      ),
    );
  }

  // ── 토글 행 (라벨 + 스위치) ──
  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line100, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          _Toggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  // ── 값 행 (라벨 + 우측 값 + 셰브론) ──
  Widget _valueRow(String label, String? value, {required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.line100, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            if (value != null) ...[
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray400,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
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

  // ── 로그아웃 / 탈퇴하기 (밑줄 텍스트 링크) ──
  Widget _accountActions() {
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _confirmSignOut,
          child: const Text(
            '로그아웃',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.gray500,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.gray500,
            ),
          ),
        ),
        const SizedBox(width: 20),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _confirmDelete,
          child: const Text(
            '탈퇴하기',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.gray400,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.gray400,
            ),
          ),
        ),
      ],
    );
  }
}

/// 라임 썸 + 차콜 트랙의 커스텀 토글 (목업 스타일)
class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? AppColors.ink : AppColors.gray250,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? AppColors.lime : AppColors.surface,
          ),
        ),
      ),
    );
  }
}
