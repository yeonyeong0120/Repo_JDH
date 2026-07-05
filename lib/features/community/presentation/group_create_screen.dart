import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';

/// 줍다행 - 그룹 만들기 화면 (GRP-03)
/// 이름·사진·동네(자동)·소개·공개설정 입력. 이미 그룹 소속이면 GRP-04 차단.
/// 위치 권장: lib/features/community/presentation/group_create_screen.dart
class GroupCreateScreen extends StatefulWidget {
  // 이미 다른 그룹 소속인지 (GRP-04 차단 판단용)
  final bool alreadyInGroup;
  const GroupCreateScreen({super.key, this.alreadyInGroup = false});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final _nameController = TextEditingController();
  final _introController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 진입 시 이미 그룹 소속이면 GRP-04 차단 모달
    if (widget.alreadyInGroup) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showBlocked());
    }
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _introController.dispose();
    super.dispose();
  }

  // GRP-04: 이미 그룹 가입 상태 → 차단 (만들기 불가), 확인 시 뒤로
  void _showBlocked() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('그룹 생성 불가'),
        content: const Text(
          '이미 그룹에 가입되어 있습니다.\n'
          '기존 그룹에서 탈퇴한 뒤 새 그룹을 만들 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // 모달 닫기
              Navigator.pop(context); // 만들기 화면 닫기
            },
            child: const Text(
              '확인',
              style: TextStyle(
                color: AppColors.primaryDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _create() {
    // TODO: 실제 그룹 생성 로직 (Firestore 저장 + 자동 가입)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('\'${_nameController.text.trim()}\' 그룹을 만들었어요'),
        backgroundColor: AppColors.mintDeep,
        duration: const Duration(seconds: 2),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _nameController.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: AppColors.textPrimary,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    '그룹 만들기',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 대표 사진 (선택)
                    Center(
                      child: GestureDetector(
                        // TODO: 이미지 선택 연결
                        onTap: () {},
                        child: Container(
                          width: 92,
                          height: 92,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryPale,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_outlined,
                            color: AppColors.textTertiary,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        '대표 사진 (선택)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 이름
                    _label('그룹 이름'),
                    const SizedBox(height: 8),
                    _field(
                      controller: _nameController,
                      hint: '그룹 이름을 입력하세요',
                      maxLength: 20,
                    ),
                    const SizedBox(height: 18),

                    // 동네 (자동)
                    _label('동네'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.divider.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                          SizedBox(width: 8),
                          // TODO: 실제 현재 위치(동네)로 자동 설정
                          Text(
                            '00구 00동 (현재 위치로 자동 설정)',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 소개
                    _label('소개'),
                    const SizedBox(height: 8),
                    _field(
                      controller: _introController,
                      hint: '그룹을 소개해 주세요',
                      maxLength: 200,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),

            // 하단 만들기 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
              child: GestureDetector(
                onTap: canCreate ? _create : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: canCreate ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: canCreate ? AppColors.buttonShadow : null,
                  ),
                  child: Text(
                    '그룹 만들기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: canCreate ? Colors.white : AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.cardBG,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }
}
