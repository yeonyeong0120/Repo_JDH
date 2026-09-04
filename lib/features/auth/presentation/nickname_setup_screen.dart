import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/router/app_router.dart';
import 'package:repo_jdh/features/auth/data/user_profile_provider.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';

/// 회원가입 후 닉네임 입력 화면 — Startline 구조.
/// 25/800 밑줄 인풋 + 인라인 힌트(3상태) + 라임 아바타 미리보기 + 차콜 CTA.
/// 프로필이 없거나 닉네임이 비어있을 때 라우터가 자동으로 이 화면으로 보냄.
class NicknameSetupScreen extends ConsumerStatefulWidget {
  const NicknameSetupScreen({super.key});

  @override
  ConsumerState<NicknameSetupScreen> createState() =>
      _NicknameSetupScreenState();
}

class _NicknameSetupScreenState extends ConsumerState<NicknameSetupScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  bool _isChecking = false;
  String? _availabilityMessage;
  bool? _isAvailable;
  Timer? _debounce;

  static const int _minLength = 2;
  // 스크린샷(0/10)·플레이스홀더("2~10자")·가입 3단계와 동일하게 10자로 맞춘다.
  static const int _maxLength = 10;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _availabilityMessage = null;
      _isAvailable = null;
    });

    _debounce?.cancel();
    final value = _controller.text.trim();
    if (value.length < _minLength) return;
    if (value.length > _maxLength) return;

    _debounce = Timer(const Duration(milliseconds: 400), _checkAvailability);
  }

  Future<void> _checkAvailability() async {
    final value = _controller.text.trim();
    if (value.length < _minLength) return;

    setState(() => _isChecking = true);

    try {
      final taken = await UserService.isNicknameTaken(value);
      if (!mounted) return;
      setState(() {
        _isAvailable = !taken;
        _availabilityMessage = taken ? '이미 사용 중인 닉네임이에요' : '쓸 수 있는 닉네임이에요';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAvailable = null;
        _availabilityMessage = '중복 확인 중 오류가 발생했어요';
      });
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  String? _validate(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return '닉네임을 입력해주세요';
    if (v.length < _minLength) return '$_minLength자 이상 입력해주세요';
    if (v.length > _maxLength) return '$_maxLength자 이하로 입력해주세요';
    if (RegExp(r'\s').hasMatch(v)) return '공백은 사용할 수 없습니다';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isAvailable == false) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('다른 닉네임을 사용해주세요')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      final nickname = _controller.text.trim();
      final email = user.email ?? '';

      await UserService.createProfile(email: email, nickname: nickname);

      // 프로필 프로바이더 무효화 → 라우터가 자동으로 redirect
      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('환영합니다, $nickname님!'),
            backgroundColor: AppColors.actionPrimary,
            duration: const Duration(seconds: 2),
          ),
        );
        // 명시적 이동 (라우터 redirect 보조)
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e'), backgroundColor: AppColors.actionDanger),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── 인라인 힌트 상태 계산 (아이콘/색/문구) ──
  // 0 정보(회색) / 1 통과(잉크) / 2 오류(위험)
  ({int state, IconData icon, Color color, String text}) _hint() {
    final v = _controller.text.trim();
    const info = TablerIcons.infoCircle;
    const ok = TablerIcons.circleCheckFilled;
    const bad = TablerIcons.alertCircleFilled;

    if (v.isEmpty) {
      return (state: 0, icon: info, color: AppColors.gray500, text: '한글·영문·숫자를 쓸 수 있어요');
    }
    if (v.length < _minLength) {
      return (state: 2, icon: bad, color: AppColors.actionDanger, text: '두 글자 이상 입력해주세요');
    }
    if (v.length > _maxLength) {
      return (state: 2, icon: bad, color: AppColors.actionDanger, text: '$_maxLength자 이하로 입력해주세요');
    }
    if (_isChecking) {
      return (state: 0, icon: info, color: AppColors.gray500, text: '닉네임을 확인하고 있어요');
    }
    if (_isAvailable == true) {
      return (state: 1, icon: ok, color: AppColors.ink, text: '쓸 수 있는 닉네임이에요');
    }
    if (_isAvailable == false) {
      return (
        state: 2,
        icon: bad,
        color: AppColors.actionDanger,
        text: _availabilityMessage ?? '이미 사용 중인 닉네임이에요',
      );
    }
    // 확인 전(디바운스 대기) 또는 오류 메시지
    if (_availabilityMessage != null) {
      return (state: 2, icon: bad, color: AppColors.actionDanger, text: _availabilityMessage!);
    }
    return (state: 0, icon: info, color: AppColors.gray500, text: '한글·영문·숫자를 쓸 수 있어요');
  }

  bool get _nickReady {
    final v = _controller.text.trim();
    return v.length >= _minLength &&
        v.length <= _maxLength &&
        !RegExp(r'\s').hasMatch(v) &&
        _isAvailable != false &&
        !_isChecking;
  }

  @override
  Widget build(BuildContext context) {
    final nick = _controller.text.trim();
    final hint = _hint();
    final borderColor =
        [AppColors.gray200, AppColors.ink, AppColors.actionDanger][hint.state];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                // 키보드가 올라와 공간이 부족할 때만 스크롤된다.
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            const Text(
                              '어떻게 불러드릴까요?',
                              style: TextStyle(
                                fontSize: 27,
                                height: 1.28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '그룹 채팅과 활동 기록에 표시되는 이름이에요.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                                color: AppColors.gray500,
                              ),
                            ),
                            const SizedBox(height: 36),
                            // ── 닉네임 밑줄 인풋 (25/800) + n/max 카운터 ──
                            const Text(
                              '닉네임',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                color: AppColors.gray500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom:
                                      BorderSide(color: borderColor, width: 2),
                                ),
                              ),
                              padding: const EdgeInsets.only(top: 9, bottom: 11),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _controller,
                                      maxLength: _maxLength,
                                      enabled: !_isSubmitting,
                                      textInputAction: TextInputAction.done,
                                      validator: _validate,
                                      onFieldSubmitted: (_) => _submit(),
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.6,
                                        color: AppColors.ink,
                                      ),
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        counterText: '',
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedErrorBorder: InputBorder.none,
                                        errorStyle: TextStyle(height: 0, fontSize: 0),
                                        contentPadding: EdgeInsets.zero,
                                        hintText: '2~10자',
                                        hintStyle: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.6,
                                          color: AppColors.gray350,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${nick.length}/$_maxLength',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.gray400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 11),
                            // ── 인라인 힌트 ──
                            Row(
                              children: [
                                Icon(hint.icon, size: 17, color: hint.color),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    hint.text,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: hint.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // ── 미리보기 카드 ──
                            Container(
                              padding: const EdgeInsets.all(17),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '그룹 채팅에서는 이렇게 보여요',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.4,
                                      color: AppColors.gray500,
                                    ),
                                  ),
                                  const SizedBox(height: 11),
                                  Container(
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            color: AppColors.lime,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            TablerIcons.userFilled,
                                            size: 19,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        const SizedBox(width: 11),
                                        // 실제 그룹 채팅은 닉네임만 보여준다 — 미리보기도 닉네임만 표시
                                        Expanded(
                                          child: Text(
                                            nick.isEmpty ? '닉네임' : nick,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // ── 차콜 CTA "플로고 시작하기" + check ──
                            _startButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _startButton() {
    final enabled = _nickReady && !_isSubmitting;
    final bg = enabled ? AppColors.ink : AppColors.gray200;
    final fg = enabled ? Colors.white : AppColors.gray350;
    final iconFg = enabled ? AppColors.lime : AppColors.gray350;
    return SizedBox(
      height: 58,
      child: ElevatedButton(
        onPressed: enabled ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '플로고 시작하기',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(TablerIcons.check, size: 20, color: iconFg),
                ],
              ),
      ),
    );
  }
}
