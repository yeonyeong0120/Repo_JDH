import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';

/// 회원가입 온보딩 (3단계) — 플로고
///  1) 이메일·비밀번호  2) 성별·나이·키·몸무게·지역(선택)  3) 닉네임
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _pageController = PageController();
  int _step = 0;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _obscurePassword = true;

  String? _gender; // '남성' / '여성'
  int? _age;
  int? _height;
  int? _weight;
  // TODO: 실제 현재 위치(역지오코딩)로 자동 설정
  final String _region = '인천 남동구 만수동';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        // 화면 맨 아래가 아니라 '다음' 버튼 위치쯤에 뜨게
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      ),
    );
  }

  void _goTo(int i) {
    FocusScope.of(context).unfocus();
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      _goTo(_step - 1);
    }
  }

  // 1단계 → 2단계: 이메일·비밀번호 검증
  void _next1() {
    final email = _emailController.text.trim();
    final pw = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      _snack('올바른 이메일을 입력해주세요.');
      return;
    }
    if (pw.length < 8) {
      _snack('비밀번호는 8자 이상이어야 해요.');
      return;
    }
    _goTo(1);
  }

  // 최종: 계정 생성 + 프로필 저장
  Future<void> _finish() async {
    final nick = _nicknameController.text.trim();
    if (nick.length < 2 || nick.length > 10) {
      _snack('닉네임은 2~10자로 만들어주세요.');
      return;
    }
    setState(() => _isLoading = true);
    final error = await AuthRepository.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _isLoading = false);
      _snack(error);
      _goTo(0); // 이메일 단계로 되돌림
      return;
    }
    try {
      await UserService.createProfile(
        email: _emailController.text.trim(),
        nickname: nick,
      );
      await UserService.updateProfileFields(
        gender: _gender,
        age: _age,
        height: _height,
        weight: _weight,
        region: _region,
      );
    } catch (_) {
      // 프로필 저장 실패해도 가입은 완료된 상태 — 나중에 메뉴에서 채움
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    // 로그인 화면으로 pop → 라우터가 로그인 상태·닉네임 보고 홈으로 보냄
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _step = i),
                  children: [_step1(), _step2(), _step3()],
                ),
              ),
              _bottomArea(),
            ],
          ),
        ),
      ),
    );
  }

  // ── 상단: 뒤로 + 진행바 + n/3 ──
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _back,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, size: 20,
                  color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 14),
          // 진행바 3칸
          Expanded(
            child: Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? AppColors.actionPrimary
                            : AppColors.neutral200,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_step + 1} / 3',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 공통: 큰 제목 + 부제 ──
  Widget _header(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 2, left: 2),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );

  InputDecoration _underline(String hint, {Widget? suffix}) {
    UnderlineInputBorder line(Color c, [double w = 1]) =>
        UnderlineInputBorder(borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 17),
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      suffixIcon: suffix,
      border: line(AppColors.border),
      enabledBorder: line(AppColors.border),
      focusedBorder: line(AppColors.actionPrimary, 1.6),
    );
  }

  // ═══════════════ 1단계: 이메일 · 비밀번호 ═══════════════
  Widget _step1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header('이메일로 시작해요', '비밀번호는 8자 이상으로 만들어주세요.'),
          const SizedBox(height: 26),
          _fieldLabel('이메일'),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 17),
            decoration: _underline('name@example.com'),
          ),
          const SizedBox(height: 20),
          _fieldLabel('비밀번호'),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(fontSize: 17),
            decoration: _underline(
              '8자 이상',
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                  size: 21,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 22),
          // 안내 박스
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.green100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.shield_outlined, size: 18,
                    color: AppColors.textBrandOnLight),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '이메일은 비밀번호를 다시 만들 때만 써요. 그룹에는 닉네임만 보입니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textOnTint,
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

  // ═══════════════ 2단계: 성별·나이·키·몸무게·지역 ═══════════════
  Widget _step2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header('더 정확한 측정에 필요해요', '걸음수와 칼로리를 계산하는 데 쓰여요.'),
          const SizedBox(height: 24),
          _fieldLabel('성별'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _genderBox('남성')),
              const SizedBox(width: 12),
              Expanded(child: _genderBox('여성')),
            ],
          ),
          const SizedBox(height: 20),
          _pickerRow(
            icon: Icons.cake_outlined,
            label: '나이',
            valueText: _age == null ? null : '$_age세',
            onTap: () => _showNumberSheet(
              title: '나이',
              subtitle: '칼로리 계산에 사용해요',
              unit: '세',
              min: 8,
              max: 100,
              initial: _age ?? 40,
              onConfirm: (v) => setState(() => _age = v),
            ),
          ),
          _divider(),
          _pickerRow(
            icon: Icons.straighten,
            label: '키',
            valueText: _height == null ? null : '${_height}cm',
            onTap: () => _showNumberSheet(
              title: '키',
              subtitle: '걸음 보폭 계산에 사용해요',
              unit: 'cm',
              min: 100,
              max: 220,
              initial: _height ?? 165,
              onConfirm: (v) => setState(() => _height = v),
            ),
          ),
          _divider(),
          _pickerRow(
            icon: Icons.monitor_weight_outlined,
            label: '몸무게',
            valueText: _weight == null ? null : '${_weight}kg',
            onTap: () => _showNumberSheet(
              title: '몸무게',
              subtitle: '칼로리 계산에 사용해요',
              unit: 'kg',
              min: 30,
              max: 200,
              initial: _weight ?? 60,
              onConfirm: (v) => setState(() => _weight = v),
            ),
          ),
          const SizedBox(height: 20),
          // 지역 (자동)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location, size: 20,
                    color: AppColors.textBrandOnLight),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '지역',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _region,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  '자동',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '지금 건너뛰어도 괜찮아요. 메뉴에서 언제든 채울 수 있어요.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: AppColors.border);

  Widget _genderBox(String g) {
    final on = _gender == g;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _gender = g),
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.green100 : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on ? AppColors.actionPrimary : AppColors.border,
            width: on ? 1.5 : 1,
          ),
        ),
        child: Text(
          g,
          style: TextStyle(
            fontSize: 16,
            fontWeight: on ? FontWeight.w800 : FontWeight.w600,
            color: on ? AppColors.textBrandOnLight : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _pickerRow({
    required IconData icon,
    required String label,
    required String? valueText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              valueText ?? '선택',
              style: TextStyle(
                fontSize: 15,
                fontWeight: valueText == null
                    ? FontWeight.w500
                    : FontWeight.w700,
                color: valueText == null
                    ? AppColors.textSecondary
                    : AppColors.textBrandOnLight,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  // ═══════════════ 3단계: 닉네임 ═══════════════
  Widget _step3() {
    final nick = _nicknameController.text.trim();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header('어떻게 불러드릴까요?', '그룹 피드와 활동 기록에 표시되는 이름이에요.'),
          const SizedBox(height: 26),
          _fieldLabel('닉네임'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _nicknameController,
                  maxLength: 10,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: _underline('2~10자').copyWith(counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${nick.length}/10',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.info_outline, size: 15, color: AppColors.neutral400),
              SizedBox(width: 5),
              Text(
                '한글·영문·숫자를 쓸 수 있어요',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 26),
          // 미리보기 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '그룹 피드에서는 이렇게 보여요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceBrand,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, size: 22,
                            color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nick.isEmpty ? '닉네임' : nick,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            '오전 7:30 · 소래습지 한 바퀴',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
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

  // ── 하단 버튼 영역 (단계별) ──
  Widget _bottomArea() {
    late final Widget button;
    late final Widget? link;
    if (_step == 0) {
      button = _primaryButton('다음', onTap: _next1, arrow: true);
      link = _loginLink();
    } else if (_step == 1) {
      button = _primaryButton('다음', onTap: () => _goTo(2), arrow: true);
      link = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goTo(2),
        child: const Text(
          '건너뛰기',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      );
    } else {
      final ok = _nicknameController.text.trim().length >= 2;
      button = _primaryButton(
        '플로고 시작하기',
        onTap: ok && !_isLoading ? _finish : null,
        check: true,
        loading: _isLoading,
      );
      link = null;
    }
    // 로그인 화면의 버튼·링크와 같은 높이에 오도록 아래 여백을 맞춤(더 아래로)
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          const SizedBox(height: 12),
          // 링크 자리 고정(없는 단계도 높이 유지 → 버튼 위치 안 흔들림)
          SizedBox(height: 22, child: Center(child: link ?? const SizedBox())),
        ],
      ),
    );
  }

  Widget _loginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '이미 계정이 있나요? ',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: const Text(
            '로그인',
            style: TextStyle(
              color: AppColors.actionPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(
    String label, {
    required VoidCallback? onTap,
    bool arrow = false,
    bool check = false,
    bool loading = false,
  }) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.actionPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.neutral300,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (arrow) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                  if (check) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check, size: 20),
                  ],
                ],
              ),
      ),
    );
  }

  // ── 숫자 증감/키패드 바텀시트 ──
  void _showNumberSheet({
    required String title,
    required String subtitle,
    required String unit,
    required int min,
    required int max,
    required int initial,
    required ValueChanged<int> onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NumberSheet(
        title: title,
        subtitle: subtitle,
        unit: unit,
        min: min,
        max: max,
        initial: initial,
        onConfirm: onConfirm,
      ),
    );
  }
}

/// 나이·키·몸무게 입력 시트 — 증감 버튼 + 숫자 터치 시 키패드 수동 입력.
class _NumberSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String unit;
  final int min;
  final int max;
  final int initial;
  final ValueChanged<int> onConfirm;
  const _NumberSheet({
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.min,
    required this.max,
    required this.initial,
    required this.onConfirm,
  });

  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  late int _val = widget.initial;
  late final TextEditingController _c =
      TextEditingController(text: '${widget.initial}');
  final _focus = FocusNode();

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _set(int v) {
    final nv = v.clamp(widget.min, widget.max);
    setState(() {
      _val = nv;
      _c.text = '$nv';
      _c.selection = TextSelection.collapsed(offset: _c.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(22, 12, 22, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutral300,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 22,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 22),
          // − [숫자(키패드)] +
          Row(
            children: [
              _roundBtn(Icons.remove, () => _set(_val - 1)),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    IntrinsicWidth(
                      child: TextField(
                        controller: _c,
                        focusNode: _focus,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) _val = n;
                        },
                        onSubmitted: (_) => _set(_val),
                        onEditingComplete: () => _set(_val),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.unit,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _roundBtn(Icons.add, () => _set(_val + 1)),
            ],
          ),
          const SizedBox(height: 16),
          // 빠른 증감
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _quick('-10', () => _set(_val - 10)),
              const SizedBox(width: 8),
              _quick('-5', () => _set(_val - 5)),
              const SizedBox(width: 8),
              _quick('+5', () => _set(_val + 5)),
              const SizedBox(width: 8),
              _quick('+10', () => _set(_val + 10)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final n = int.tryParse(_c.text) ?? _val;
                widget.onConfirm(n.clamp(widget.min, widget.max));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.actionPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '확인',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface, // 하양 통일
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.neutral300),
        ),
        child: Icon(icon, size: 24, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _quick(String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface, // 하양 통일
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.neutral300),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
