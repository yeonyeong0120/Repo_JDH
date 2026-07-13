import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import 'signup_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// 로그인 화면 — 플로고
/// 색 배경 + 흰 카드(윗변에 마스코트가 들어가는 홈) + 카드 하단에 걸친 통통한 로그인 버튼.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const Color _bg = AppColors.primaryPale;

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
    setState(() => _isLoading = true);
    final error = await AuthRepository.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handlePasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일을 먼저 입력해주세요.')));
      return;
    }
    final error = await AuthRepository.sendPasswordResetEmail(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '비밀번호 재설정 이메일을 전송했습니다.'),
        backgroundColor: error != null ? AppColors.error : AppColors.primary,
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final error = await AuthRepository.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  InputDecoration _cardInput(String hint, IconData icon, {Widget? suffix}) {
    UnderlineInputBorder line(Color c, [double w = 1]) => UnderlineInputBorder(
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 16),
      prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      enabledBorder: line(AppColors.divider),
      focusedBorder: line(AppColors.primary, 1.6),
      errorBorder: line(AppColors.error),
      focusedErrorBorder: line(AppColors.error, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg, // 아래 흰 부분 방지 (전체 초록)
      resizeToAvoidBottomInset: false, // 키보드로 레이아웃 안 밀림
      // 배경 아무 곳이나 누르면 키패드 닫힘
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: CustomScrollView(
            physics: const NeverScrollableScrollPhysics(), // 스크롤/바운스 제거
            // SliverFillRemaining(hasScrollBody:false) → 화면 높이를 그대로 확보하고
            // 안쪽 Column의 mainAxisAlignment.center로 콘텐츠 전체(환영 문구~Google 버튼)를
            // 한 덩어리로 화면 정중앙에 배치. 내용이 넘치거나 키보드가 올라오면 자동 스크롤.
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(30, 18, 30, 24),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),
                        // 환영 문구 (휴먼범석네오) — 스르륵 나타남
                        // Transform.translate로 감싸서 레이아웃/다른 요소에 영향 없이
                        // 순수하게 화면상 위치만 위로 이동
                        Transform.translate(
                          offset: const Offset(0, -60), // 숫자를 키울수록 더 위로
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1) "플로고에 오신 것을" — 먼저 등장
                              const Text(
                                    '플로고에 오신 것을',
                                    style: TextStyle(
                                      fontFamily: 'HumanBeomseokNeo',
                                      color: AppColors.textPrimary,
                                      fontSize: 22,
                                      height: 1.2,
                                    ),
                                  )
                                  .animate()
                                  .fadeIn(
                                    duration: 2000.ms,
                                    curve: Curves.easeOut,
                                  )
                                  .slideY(
                                    begin: 0.5,
                                    end: 0,
                                    duration: 2000.ms,
                                    curve: Curves.easeOutCubic,
                                  )
                                  .tint(
                                    color: _bg,
                                    begin: 1.0,
                                    end: 0.0,
                                    duration: 2000.ms,
                                    curve: Curves.easeOutCubic,
                                  ),
                              // 두 문구 사이 간격 (넓게 — 숫자 키우면 더 벌어짐)
                              const SizedBox(height: 14),
                              // 2) "환영합니다!" — 텀(delay 800ms) 두고 나중에 등장
                              Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                    ), // ← 숫자 키우면 더 오른쪽으로
                                    child: const Text(
                                      '환영합니다!',
                                      style: TextStyle(
                                        fontFamily: 'HumanBeomseokNeo',
                                        color: AppColors.primary,
                                        fontSize: 32,
                                        height: 1.15,
                                      ),
                                    ),
                                  )
                                  .animate(delay: 800.ms) // ← 텀 조절
                                  .fadeIn(
                                    duration: 2000.ms,
                                    curve: Curves.easeOut,
                                  )
                                  .slideY(
                                    begin: 0.5,
                                    end: 0,
                                    duration: 2000.ms,
                                    curve: Curves.easeOutCubic,
                                  )
                                  .tint(
                                    color: _bg,
                                    begin: 1.0,
                                    end: 0.0,
                                    duration: 2000.ms,
                                    curve: Curves.easeOutCubic,
                                  ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        // ── 홈 파인 카드 + 마스코트 + 통통 버튼 ──
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            // 카드 (윗변 가운데가 오목하게 파임)
                            Padding(
                              padding: const EdgeInsets.only(top: 44),
                              child: PhysicalShape(
                                clipper: _NotchedCardClipper(),
                                color: AppColors.cardBG,
                                elevation: 8,
                                shadowColor: Colors.black.withValues(
                                  alpha: 0.18,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    68,
                                    24,
                                    48,
                                  ),
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        decoration: _cardInput(
                                          '이메일',
                                          Icons.email_outlined,
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return '이메일을 입력해주세요.';
                                          }
                                          if (!v.contains('@')) {
                                            return '올바른 이메일 형식이 아닙니다.';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        decoration: _cardInput(
                                          '비밀번호',
                                          Icons.lock_outline,
                                          suffix: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons
                                                        .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: AppColors.textTertiary,
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
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _handlePasswordReset,
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppColors.textTertiary,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: const Text(
                                            '비밀번호를 잊으셨나요?',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // 마스코트 (카드 홈에 쏙) — TODO: 실제 로고 이미지로 교체
                            // primary 그대로는 너무 진해서, white와 blend한 중간톤으로 조정
                            Container(
                              width: 88,
                              height: 88,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Color.alphaBlend(
                                  AppColors.primary.withValues(alpha: 0.45),
                                  Colors.white,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                '🦭',
                                style: TextStyle(fontSize: 44),
                              ),
                            ),
                            // 통통하고 짧은 로그인 버튼 (카드 하단에 걸침)
                            Positioned(
                              bottom: -22,
                              left: 52,
                              right: 52,
                              child: SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        AppColors.primaryMuted,
                                    elevation: 3,
                                    shadowColor: Colors.black.withValues(
                                      alpha: 0.22,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(27),
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
                                      : const Text(
                                          '로그인',
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
                        const SizedBox(height: 60),

                        // 회원가입
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '계정이 없으신가요? ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SignupScreen(),
                                      ),
                                    ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                '회원가입',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Google 로그인
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _handleGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              backgroundColor: AppColors.cardBG,
                              side: const BorderSide(color: AppColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'G',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Google로 로그인',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 윗변 가운데가 오목하게 파인 카드 (마스코트가 들어가는 홈)
class _NotchedCardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const r = 26.0; // 모서리 반경
    const notch = 52.0; // 마스코트 홈 반경
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final p = Path();
    p.moveTo(r, 0);
    p.lineTo(cx - notch, 0);
    // 아래로 오목하게 파이는 반원 홈
    p.arcToPoint(
      Offset(cx + notch, 0),
      radius: const Radius.circular(notch),
      clockwise: false,
    );
    p.lineTo(w - r, 0);
    p.arcToPoint(Offset(w, r), radius: const Radius.circular(r));
    p.lineTo(w, h - r);
    p.arcToPoint(Offset(w - r, h), radius: const Radius.circular(r));
    p.lineTo(r, h);
    p.arcToPoint(Offset(0, h - r), radius: const Radius.circular(r));
    p.lineTo(0, r);
    p.arcToPoint(Offset(r, 0), radius: const Radius.circular(r));
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
