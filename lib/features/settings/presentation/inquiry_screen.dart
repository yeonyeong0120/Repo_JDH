import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';

/// 문의 및 신고 (도움말 → 1:1 문의하기) — Startline 토큰 적용
/// Firestore: inquiries/{id} 에 저장 → 운영자가 확인
/// 위치 권장: lib/features/settings/presentation/inquiry_screen.dart
class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key});

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  static const List<String> _types = [
    '이용 문의',
    '오류 신고',
    '부적절한 게시물 신고',
    '포인트·쿠폰 문의',
    '기타',
  ];

  String _type = _types.first;
  final _contentController = TextEditingController();
  final _emailController = TextEditingController(
    text: FirebaseAuth.instance.currentUser?.email ?? '',
  );
  bool _sending = false;

  @override
  void dispose() {
    _contentController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.length < 10) {
      AppSnackBar.show(context, '내용을 10자 이상 입력해주세요');
      return;
    }
    if (_sending) return;
    setState(() => _sending = true);

    try {
      await FirebaseFirestore.instance.collection('inquiries').add({
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'type': _type,
        'content': content,
        'email': _emailController.text.trim(),
        'status': 'open', // open / answered
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppSnackBar.show(context, '접수하지 못했어요. 잠시 후 다시 시도해주세요');
      return;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    await _showDone();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showDone() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  TablerIcons.check,
                  size: 30,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '접수되었습니다',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '확인 후 입력하신 이메일로 답변드릴게요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.gray500),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                  children: [
                    _label('유형'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final t in _types) _typeChip(t)],
                    ),
                    const SizedBox(height: 24),
                    _label('내용'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: TextField(
                        controller: _contentController,
                        maxLines: 8,
                        maxLength: 1000,
                        cursorColor: AppColors.ink,
                        decoration: const InputDecoration(
                          filled: false,
                          hintText:
                              '어떤 점이 불편하셨는지 자세히 알려주세요.\n'
                              '신고의 경우 대상과 상황을 함께 적어주시면 빠르게 확인할 수 있어요.',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: AppColors.gray500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterStyle: TextStyle(
                            fontSize: 13,
                            color: AppColors.gray500,
                          ),
                        ),
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _label('답변받을 이메일'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        cursorColor: AppColors.ink,
                        decoration: const InputDecoration(
                          filled: false,
                          hintText: '이메일을 입력해주세요',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: AppColors.gray500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '보내주신 내용은 운영팀만 확인하며, 답변까지 영업일 기준 3일 정도 걸릴 수 있어요.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 20),
                child: GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      _sending ? '보내는 중...' : '접수하기',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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
            '문의 및 신고',
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

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
  );

  Widget _typeChip(String t) {
    final on = _type == t;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _type = t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: on ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? AppColors.ink : AppColors.gray200),
        ),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 13,
            fontWeight: on ? FontWeight.w800 : FontWeight.w500,
            color: on ? Colors.white : AppColors.gray500,
          ),
        ),
      ),
    );
  }
}
