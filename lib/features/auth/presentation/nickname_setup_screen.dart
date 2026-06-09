import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repo_jdh/core/router/app_router.dart';
import 'package:repo_jdh/features/auth/data/user_profile_provider.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';

/// 회원가입 후 닉네임 입력 화면
/// 프로필이 없거나 닉네임이 비어있을 때 라우터가 자동으로 이 화면으로 보냄
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
  static const int _maxLength = 12;

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
        _availabilityMessage =
            taken ? '이미 사용 중인 닉네임이에요' : '사용 가능한 닉네임입니다';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다른 닉네임을 사용해주세요')),
      );
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
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        // 명시적 이동 (라우터 redirect 보조)
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  '닉네임을 정해주세요',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '그룹과 리더보드에서 사용됩니다',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _controller,
                  maxLength: _maxLength,
                  enabled: !_isSubmitting,
                  textInputAction: TextInputAction.done,
                  validator: _validate,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: '닉네임',
                    hintText: '$_minLength~$_maxLength자',
                    border: const OutlineInputBorder(),
                    suffixIcon: _isChecking
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _isAvailable == true
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : _isAvailable == false
                                ? const Icon(Icons.cancel, color: Colors.red)
                                : null,
                  ),
                ),
                if (_availabilityMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _availabilityMessage!,
                    style: TextStyle(
                      color: _isAvailable == true
                          ? Colors.green
                          : _isAvailable == false
                              ? Colors.red
                              : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
                const Spacer(),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          '시작하기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}