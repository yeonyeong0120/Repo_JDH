import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';

/// 회원가입 화면 (AUTH-03) — 플로고
/// 필수: 이메일 · 비밀번호(*) / 선택: 성별 · 나이 · 키 · 몸무게 · 지역 (안 채워도 가입)
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  static const Color _bg = Color(0xFFE3F6EC);

  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // 선택 (프로필용 — 안 채워도 가입)
  String? _gender;
  int? _age; // 나이는 휠 선택
  final _heightController = TextEditingController(); // 키는 직접 입력
  final _weightController = TextEditingController(); // 몸무게는 직접 입력
  final _regionController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // 이메일/비번으로 가입. 선택 정보(성별/나이/키/몸무게/지역)는 가입 후 프로필에 저장 연결.
    final error = await AuthRepository.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    } else {
      // 선택 정보(성별·나이·키·몸무게·지역)를 프로필에 저장 — 나중에 메뉴에서 수정 가능
      try {
        await UserService.updateProfileFields(
          gender: _gender,
          age: _age,
          height: int.tryParse(_heightController.text.trim()),
          weight: int.tryParse(_weightController.text.trim()),
          region: _regionController.text.trim().isEmpty
              ? null
              : _regionController.text.trim(),
        );
      } catch (_) {
        // 프로필 저장 실패해도 가입은 완료된 상태
      }
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  InputDecoration _input(
    String hint, {
    IconData? icon,
    Widget? suffix,
    String? suffixText,
  }) {
    UnderlineInputBorder line(Color c, [double w = 1]) => UnderlineInputBorder(
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 16),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: AppColors.textTertiary, size: 20),
      suffixIcon: suffix,
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14),
      enabledBorder: line(AppColors.divider),
      focusedBorder: line(AppColors.primary, 1.6),
      errorBorder: line(AppColors.error),
      focusedErrorBorder: line(AppColors.error, 1.6),
    );
  }

  Widget _genderChip(String g) {
    final selected = _gender == g;
    return ChoiceChip(
      label: Text(g),
      selected: selected,
      onSelected: (v) => setState(() => _gender = v ? g : null),
      showCheckmark: false,
      backgroundColor: AppColors.appBG,
      selectedColor: AppColors.primaryPale,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.primary : AppColors.textSecondary,
      ),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.divider,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  // 숫자 선택 필드 — 탭하면 아래에서 스크롤 휠로 고름
  Widget _pickerField(
    String label,
    String unit,
    int? value,
    int min,
    int max,
    int initial,
    ValueChanged<int> onChanged,
  ) {
    return InkWell(
      onTap: () =>
          _showNumberPicker(label, unit, min, max, value ?? initial, onChanged),
      child: InputDecorator(
        decoration: _input(
          label,
          suffix: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.textTertiary,
            size: 22,
          ),
        ),
        isEmpty: value == null,
        child: value == null
            ? null
            : Text(
                '$value$unit',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
      ),
    );
  }

  void _showNumberPicker(
    String label,
    String unit,
    int min,
    int max,
    int initial,
    ValueChanged<int> onChanged,
  ) {
    int temp = initial;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBG,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          onChanged(temp);
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          '완료',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 40,
                    scrollController: FixedExtentScrollController(
                      initialItem: initial - min,
                    ),
                    onSelectedItemChanged: (i) => temp = min + i,
                    children: [
                      for (int n = min; n <= max; n++)
                        Center(
                          child: Text(
                            '$n $unit',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: false, // 키보드로 레이아웃 안 밀림
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: CustomScrollView(
            physics: const NeverScrollableScrollPhysics(), // 스크롤/바운스 제거
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── 카드 ──
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBG,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 필수 *
                              const Text.rich(
                                TextSpan(
                                  text: '필수 ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '*',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),

                              // 이메일 *
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _input(
                                  '이메일 *',
                                  icon: Icons.email_outlined,
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
                              const SizedBox(height: 10),

                              // 비밀번호 *
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: _input(
                                  '비밀번호 (8자 이상) *',
                                  icon: Icons.lock_outline,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textTertiary,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return '비밀번호를 입력해주세요.';
                                  }
                                  if (v.length < 8) {
                                    return '비밀번호는 8자 이상이어야 합니다.';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 14),

                              // 성별
                              Row(
                                children: [
                                  const Text(
                                    '성별',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                  const Spacer(),
                                  _genderChip('남'),
                                  const SizedBox(width: 8),
                                  _genderChip('여'),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // 나이 (스크롤 휠 선택)
                              _pickerField(
                                '나이',
                                '세',
                                _age,
                                1,
                                100,
                                25,
                                (v) => setState(() => _age = v),
                              ),
                              const SizedBox(height: 10),

                              // 키 / 몸무게 (스크롤 휠 선택)
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _heightController,
                                      keyboardType: TextInputType.number,
                                      decoration: _input('키', suffixText: 'cm'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _weightController,
                                      keyboardType: TextInputType.number,
                                      decoration: _input(
                                        '몸무게',
                                        suffixText: 'kg',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // 지역
                              TextFormField(
                                controller: _regionController,
                                decoration: _input('지역 (예: 인천 부평구)'),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // 가입하기
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.primaryMuted,
                              elevation: 3,
                              shadowColor: Colors.black.withValues(alpha: 0.22),
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
                                    '가입하기',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // 로그인으로
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '이미 계정이 있으신가요? ',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                '로그인',
                                style: TextStyle(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
