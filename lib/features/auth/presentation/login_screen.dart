import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/auth/data/auth_repository.dart';
import 'package:repo_jdh/features/auth/presentation/signup_screen.dart';

/// 로그인(첫 화면) — Startline 구조.
/// 흰 배경 · PLOGGO 워드마크 · 34/800 헤드라인(라임 하이라이트) · 라임 원 블롭(진입 애니메이션)
/// · 밑줄 인풋 · 차콜 CTA(라임 arrow).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final error = await AuthRepository.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.actionDanger),
      );
    }
  }

  // 비밀번호 찾기 — 팝업(별도 위젯)으로 이메일 입력받아 재설정 링크 발송
  Future<void> _handlePasswordReset() async {
    FocusScope.of(context).unfocus();
    final email = await showDialog<String>(
      context: context,
      builder: (_) =>
          _PasswordResetDialog(initialEmail: _emailController.text.trim()),
    );
    if (email == null || !mounted) return; // 취소/닫기
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일을 입력해주세요.')));
      return;
    }
    final error = await AuthRepository.sendPasswordResetEmail(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '비밀번호 재설정 이메일을 전송했습니다.'),
        backgroundColor: error != null
            ? AppColors.actionDanger
            : AppColors.actionPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── 라임 원 블롭 180×180 (우측, 진입 시 좌로 슬라이드) ──
          Positioned(
            right: -56,
            top: 176,
            child:
                Container(
                      width: 180,
                      height: 180,
                      decoration: const BoxDecoration(
                        color: AppColors.lime,
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate()
                    .slideX(
                      begin: 0.72, // 130px ≈ 180 폭의 0.72 (근사)
                      end: 0,
                      duration: 4600.ms,
                      curve: const Cubic(0.12, 0.72, 0.24, 1),
                    )
                    .fadeIn(duration: 900.ms),
          ),
          SafeArea(
            bottom: false,
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    // 키보드가 올라와 공간이 부족할 때만 스크롤된다.
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 44),
                              // ── 헤더: PLOGGO 워드마크 + 34/800 헤드라인 ──
                              Padding(
                                padding: const EdgeInsets.fromLTRB(26, 0, 26, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'PLOGGO',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 6,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    _headline(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 64),
                              // ── 폼: 밑줄 인풋 ──
                              Padding(
                                padding: const EdgeInsets.fromLTRB(26, 0, 26, 0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _fieldLabel('이메일'),
                                    const SizedBox(height: 2),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      decoration: _underline('name@example.com'),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return '이메일을 입력해주세요.';
                                        }
                                        if (!v.contains('@')) {
                                          return '올바른 이메일 형식이 아닙니다.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    _fieldLabel('비밀번호'),
                                    const SizedBox(height: 2),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      decoration: _underline(
                                        '8자 이상',
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? TablerIcons.eyeOff
                                                : TablerIcons.eye,
                                            color: AppColors.gray500,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return '비밀번호를 입력해주세요.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    // "비밀번호를 잊으셨나요?" 우측 정렬
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _isLoading
                                            ? null
                                            : _handlePasswordReset,
                                        child: const Text(
                                          '비밀번호를 잊으셨나요?',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.gray500,
                                            decoration: TextDecoration.underline,
                                            decorationColor: AppColors.gray500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              // ── 하단 고정 CTA ──
                              Padding(
                                padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
                                child: _loginButton(),
                              ),
                              const SizedBox(height: 16),
                              _signupLink(),
                              const SizedBox(height: 24),
                              // ── 약관 문구 ──
                              const Padding(
                                padding: EdgeInsets.fromLTRB(26, 0, 26, 0),
                                child: Text.rich(
                                  TextSpan(
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.6,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF9AA09B),
                                    ),
                                    children: [
                                      TextSpan(text: '계속하면 '),
                                      TextSpan(
                                        text: '이용약관',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      TextSpan(text: '과 '),
                                      TextSpan(
                                        text: '개인정보 처리방침',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      TextSpan(text: '에\n동의하는 것으로 봅니다'),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: safeBottom + 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 34/800 헤드라인 — "깨끗"에 라임 하이라이트
  Widget _headline() {
    return const Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 34,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
          color: AppColors.ink,
        ),
        children: [
          TextSpan(text: '줍고 뛰면\n동네가 '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ColoredBox(
              color: AppColors.lime,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '깨끗',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.4,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
          TextSpan(text: '해져요'),
        ],
      ),
    );
  }

  // 로그인 버튼 h58 radius18 차콜 + 라임 arrow
  Widget _loginButton() {
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.textOnBrand,
          disabledBackgroundColor: AppColors.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isLoading
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
                children: const [
                  Text(
                    '로그인',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(TablerIcons.arrowRight, size: 20, color: AppColors.lime),
                ],
              ),
      ),
    );
  }

  // "아직 계정이 없나요? 가입하기"
  Widget _signupLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '아직 계정이 없나요? ',
          style: TextStyle(
            color: AppColors.gray500,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _isLoading
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
          child: const Text(
            '가입하기',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  // 폼 필드 라벨 11.5/800/자간1.4 gray500
  Widget _fieldLabel(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
      color: AppColors.gray500,
    ),
  );

  InputDecoration _underline(String hint, {Widget? suffix}) {
    UnderlineInputBorder line(Color c, [double wdt = 1.5]) =>
        UnderlineInputBorder(borderSide: BorderSide(color: c, width: wdt));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.gray350,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      suffixIcon: suffix,
      border: line(AppColors.gray200),
      enabledBorder: line(AppColors.gray200),
      focusedBorder: line(AppColors.ink),
      errorBorder: line(AppColors.actionDanger),
      focusedErrorBorder: line(AppColors.actionDanger),
    );
  }
}

/// 비밀번호 재설정 팝업 — 자체 컨트롤러를 관리(닫힘 애니메이션 중 dispose 오류 방지).
/// 보내기 → 입력한 이메일 반환, 취소/닫기 → null.
class _PasswordResetDialog extends StatefulWidget {
  final String initialEmail;
  const _PasswordResetDialog({required this.initialEmail});

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initialEmail,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    UnderlineInputBorder line(Color col, [double w = 1.5]) =>
        UnderlineInputBorder(borderSide: BorderSide(color: col, width: w));
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '비밀번호를 다시 만들까요?',
              style: TextStyle(
                fontSize: 20,
                height: 1.4,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              '가입한 이메일로 재설정 링크를 보내드려요.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                fontWeight: FontWeight.w500,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '이메일',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppColors.gray500,
              ),
            ),
            const SizedBox(height: 2),
            TextField(
              controller: _c,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'name@example.com',
                hintStyle: const TextStyle(
                  color: AppColors.gray350,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: line(AppColors.gray200),
                focusedBorder: line(AppColors.ink),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.surfaceSoft,
                        foregroundColor: AppColors.gray700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _c.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: const Text(
                        '보내기',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
