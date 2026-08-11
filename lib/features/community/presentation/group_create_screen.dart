import 'package:flutter/material.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_dialog.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';

/// Ploggo - 그룹 만들기 화면 (GRP-03)
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _introController.dispose();
    super.dispose();
  }

  // GRP-04: 이미 그룹 가입 상태 → 차단 (만들기 불가), 확인 시 뒤로
  Future<void> _showBlocked() async {
    await AppDialog.showInfo(
      context,
      title: '그룹 생성 불가',
      message: '이미 그룹에 가입되어 있습니다.\n\n기존 그룹에서 탈퇴한 뒤 새 그룹을 만들 수 있어요.',
      barrierDismissible: false,
    );
    if (mounted) Navigator.pop(context); // 만들기 화면 닫기
  }

  bool _creating = false;

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppSnackBar.show(context, '그룹 이름을 입력해주세요');
      return;
    }
    if (_creating) return;
    setState(() => _creating = true);
    try {
      // TODO: 대표 사진 업로드 후 imageUrl 전달, 동네는 실제 위치로
      await GroupService.createGroup(
        name: name,
        region: '00구 00동',
        intro: _introController.text.trim(),
      );
      if (!mounted) return;
      AppSnackBar.show(context, '\'$name\' 그룹을 만들었어요');
      Navigator.pop(context, true); // true = 목록 새로고침 신호
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      AppSnackBar.show(context, '그룹을 만들지 못했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
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
            // 스크롤 없이 한 화면에 다 보이게 (스크롤 제거)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 대표 사진 (선택)
                    Center(
                      child: GestureDetector(
                        // TODO: 이미지 선택 연결
                        onTap: () {},
                        child: Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCEDE3), // 목업 대표사진 배경
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_outlined,
                            color: AppColors.textBrandOnLight,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        '대표 사진 (선택)',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 11),

                    // 이름
                    _label('그룹 이름'),
                    const SizedBox(height: 8),
                    _field(
                      controller: _nameController,
                      hint: '그룹 이름을 입력하세요',
                      maxLength: 20,
                    ),
                    const SizedBox(height: 11),

                    // 동네 (자동)
                    _label('동네'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7EFE9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.location_on_outlined,
                            size: 19,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 8),
                          // TODO: 실제 현재 위치(동네)로 자동 설정
                          Expanded(
                            child: Text(
                              '00구 00동',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textOnTint,
                              ),
                            ),
                          ),
                          Text(
                            '현재 위치',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        '동네는 현재 위치로 자동 설정돼요. 같은 동네 이웃에게 먼저 보입니다.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 11),

                    // 소개
                    _label('소개'),
                    const SizedBox(height: 8),
                    _field(
                      controller: _introController,
                      hint: '그룹을 소개해 주세요',
                      maxLength: 200,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 7),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        '언제 어디서 모이는지 적어두면 이웃이 참여하기 쉬워요.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 하단 만들기 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: AppButton(
                label: _creating ? '만드는 중...' : '그룹 만들기',
                onTap: _create,
                enabled: !_creating,
                type: AppButtonType.primary,
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
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  // 목업: 흰 칸 + 1.5px 테두리(입력 시 초록), 카운터는 칸 "안" 오른쪽에.
  Widget _field({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    int maxLines = 1,
  }) {
    final Widget counter = Text(
      '${controller.text.length}/$maxLength',
      style: const TextStyle(fontSize: 13, color: AppColors.neutral400),
    );

    // 흰 박스 한 겹만. (테마의 회색 채움은 _rawInput 에서 filled:false 로 끈다)
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      // 한 줄(이름)은 낮게, 여러 줄(소개)은 여유 있게. (상하 여백 축소)
      padding: maxLines == 1
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 6)
          : const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: maxLines == 1
          ? Row(
              children: [
                Expanded(child: _rawInput(controller, hint, maxLength, 1)),
                const SizedBox(width: 8),
                counter,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _rawInput(controller, hint, maxLength, maxLines),
                Align(alignment: Alignment.centerRight, child: counter),
              ],
            ),
    );
  }

  Widget _rawInput(
    TextEditingController controller,
    String hint,
    int maxLength,
    int maxLines,
  ) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      onChanged: (_) => setState(() {}), // 카운터·테두리색 갱신
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false, // 테마의 회색 채움 끔 → 바깥 흰 박스 한 겹만
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        counterText: '', // 기본(칸 밖) 카운터 숨김
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
      ),
      style: const TextStyle(
        fontSize: 15,
        height: 1.6,
        color: AppColors.textPrimary,
      ),
    );
  }
}
