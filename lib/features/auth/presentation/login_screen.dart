import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import 'signup_screen.dart';

/// 로그인(첫 화면) — 상단 마을 일러스트(아래로 초록 그라데이션) + 하단 흰 로그인 시트.
/// 배경 초록은 일러스트 최상단 픽셀에서 뽑아 완전히 일치시킨다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // 일러스트 로드 전 임시값 → initState 에서 실제 색으로 교체
  Color _sky = const Color(0xFFDEE7CC);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSkyColor();
  }

  // 일러스트 최상단 픽셀 색을 읽어 배경 초록으로 사용 (완전 일치)
  Future<void> _loadSkyColor() async {
    try {
      final data = await rootBundle.load('assets/images/login_bg.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final bytes =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bytes != null && image.width > 0) {
        final x = image.width ~/ 2;
        const y = 3;
        final o = (y * image.width + x) * 4;
        final c = Color.fromARGB(
          255,
          bytes.getUint8(o),
          bytes.getUint8(o + 1),
          bytes.getUint8(o + 2),
        );
        if (mounted) setState(() => _sky = c);
      }
      image.dispose();
    } catch (_) {
      // 실패 시 기본값 유지
    }
  }

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
      builder: (_) => _PasswordResetDialog(
        initialEmail: _emailController.text.trim(),
      ),
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
        backgroundColor:
            error != null ? AppColors.actionDanger : AppColors.actionPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final illoH = w * 0.56;

    return Scaffold(
      backgroundColor: _sky,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 위쪽 배경: 일러스트 + 아래로 초록 그라데이션(좁게) ──
              Expanded(
                child: SingleChildScrollView(
                  reverse: true,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    height: illoH,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/login_bg.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, __, ___) =>
                              ColoredBox(color: _sky),
                        ),
                        // 좁은 범위(아래 30%)만 배경 초록으로 페이드
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: illoH * 0.3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [_sky.withValues(alpha: 0), _sky],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── 슬로건 + 타이틀 (박스 위, 카드와 동시에 떠오름) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '걷는 만큼 깨끗해지는 동네',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '플로고',
                      style: TextStyle(
                        fontSize: 40,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 1300.ms, curve: Curves.easeOut)
                  .slideY(
                    begin: 0.45,
                    end: 0,
                    duration: 1500.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 20),
              // ── 로그인 시트 (글씨와 동시에 떠오름) ──
              _loginCard(context)
                  .animate()
                  .fadeIn(duration: 1300.ms, curve: Curves.easeOut)
                  .slideY(
                    begin: 0.45,
                    end: 0,
                    duration: 1500.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 로그인 시트: 흰 배경(윗모서리 둥근, 좌우·아래 끝까지) + 내용은 인셋 ──
  Widget _loginCard(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      // 위 여백은 원래대로: 입력 필드는 시트 위쪽에 붙는다(늘어난 길이는 버튼 위 공백으로)
      padding: EdgeInsets.fromLTRB(26, 24, 26, safeBottom + 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _fieldLabel('이메일'),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 17),
              decoration: _underline('name@example.com'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '이메일을 입력해주세요.';
                if (!v.contains('@')) return '올바른 이메일 형식이 아닙니다.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _fieldLabel('비밀번호'),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(fontSize: 17),
              decoration: _underline(
                '비밀번호',
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
              validator: (v) {
                if (v == null || v.isEmpty) return '비밀번호를 입력해주세요.';
                return null;
              },
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _handlePasswordReset,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '비밀번호를 잊으셨나요?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            // 비밀번호 찾기 링크와 로그인 버튼 사이 공백
            // (시트가 길어진 만큼 이 공백이 커져 필드는 위로, 버튼은 하단 고정)
            const SizedBox(height: 76),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.actionPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.actionPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '아직 계정이 없나요? ',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _isLoading
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        ),
                  child: const Text(
                    '가입하기',
                    style: TextStyle(
                      color: AppColors.actionPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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
    UnderlineInputBorder line(Color c, [double wdt = 1]) =>
        UnderlineInputBorder(borderSide: BorderSide(color: c, width: wdt));
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
      errorBorder: line(AppColors.actionDanger),
      focusedErrorBorder: line(AppColors.actionDanger, 1.6),
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
  late final TextEditingController _c =
      TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    UnderlineInputBorder line(Color col, [double w = 1]) =>
        UnderlineInputBorder(borderSide: BorderSide(color: col, width: w));
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '비밀번호를 다시 만들까요?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '가입한 이메일로 재설정 링크를 보내드려요.',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(bottom: 2, left: 2),
              child: Text(
                '이메일',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextField(
              controller: _c,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                hintText: 'name@example.com',
                hintStyle:
                    const TextStyle(color: AppColors.textDisabled, fontSize: 17),
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: line(AppColors.border),
                focusedBorder: line(AppColors.actionPrimary, 1.6),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, _c.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.actionPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '보내기',
                        style: TextStyle(
                          fontSize: 16,
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
