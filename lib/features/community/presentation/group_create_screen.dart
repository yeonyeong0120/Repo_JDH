import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/community/domain/group.dart';
import 'package:repo_jdh/features/community/data/group_service.dart';

/// Ploggo - 그룹 만들기 화면 (GRP-03, Startline)
/// 목업: X 닫기 + "어떤 그룹을 만들까요?" + 썸네일·밑줄형 이름/소개 + 잉크 CTA.
/// 동네는 백엔드가 생성자 위치로 자동 설정한다(읽기 전용 안내).
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
  XFile? _photo;

  // 활동 강도(필수, 1택) — 기본값 '가볍게 뛰기'. 그룹 상세 상태 행에 노출된다.
  String _intensity = '가볍게 뛰기';
  static const List<({IconData icon, String label})> _intensities = [
    (icon: TablerIcons.shoe, label: '산책'),
    (icon: TablerIcons.run, label: '가볍게 뛰기'),
    (icon: TablerIcons.flame, label: '러닝'),
  ];

  // 분위기(선택, 복수) — 기본값 '조용히 각자'. 상세에서 태그 칩으로 노출된다.
  final Set<String> _moods = <String>{'조용히 각자'};
  static const List<String> _moodOptions = [
    '조용히 각자',
    '수다 환영',
    '인증샷 많이',
    '가족·아이 동반',
    '반려견 동반',
  ];

  // 누구나 가입 가능 토글(로컬 UI 상태).
  bool _isPublic = true;

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

  // GRP-04: 이미 그룹 운영 중 → 차단 팝업. 실제 내 그룹 정보를 불러와 보여준다.
  Future<void> _showBlocked() async {
    // 내가 운영 중인 그룹을 실제로 조회(없으면 최소 구성으로 표시)
    Group? mine;
    try {
      mine = await GroupService.myGroup();
    } catch (_) {
      // 조회 실패 시 그룹 카드 없이 안내만 표시
    }
    if (!mounted) return;
    // 그룹장(ownerUid == 내 uid)이면 '운영 중', 아니면 '그룹에 속해 있음' 안내로 분기.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final bool isOwner = mine != null && mine.ownerUid == uid;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.neutral900.withValues(alpha: 0.45),
      builder: (dctx) => _ownedGroupDialog(dctx, mine, isOwner),
    );
    if (mounted) Navigator.pop(context); // 만들 수 없으므로 만들기 화면 닫기
  }

  // (A) 이미 그룹 소속 안내 팝업 — 흰 라운드 카드(중앙 정렬).
  // isOwner: 그룹장이면 '운영 중', 일반 멤버면 '속해 있음' 문구.
  Widget _ownedGroupDialog(BuildContext dctx, Group? mine, bool isOwner) {
    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 상단 56 원형 — 소프트 그레이 면 + usersGroup 잉크 글리프
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.surfaceSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(TablerIcons.users,
                  size: 28, color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            const Text(
              // 그룹장/멤버 구분 없이 통일
              '이미 그룹에 가입되어 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.38,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '한 사람이 가입할 수 있는 그룹은 하나예요\n새로 만들려면 가입 되어 있는 그룹을 정리해주세요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: AppColors.gray700,
              ),
            ),
            // 내 그룹 카드(실데이터가 있을 때만)
            if (mine != null) ...[
              const SizedBox(height: 20),
              _ownedGroupRow(mine, isOwner),
            ],
            const SizedBox(height: 24),
            // 확인 버튼 하나만
            SizedBox(
              width: double.infinity,
              child: _dialogButton(
                '확인',
                primary: true,
                onTap: () => Navigator.pop(dctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 내 그룹 요약 행 — 라임 라운드 스퀘어 + 깃발 + 이름/멤버 수
  Widget _ownedGroupRow(Group g, bool isOwner) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.lime,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(TablerIcons.users, size: 22, color: AppColors.limeOn),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isOwner
                      ? '멤버 ${g.memberCount}명 · 내가 리더'
                      : '멤버 ${g.memberCount}명',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // (B) '같은 이름의 그룹이 있어요' 팝업 — 코랄 경고 + 단일 잉크 버튼
  Future<void> _showDuplicateName(String name) async {
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.neutral900.withValues(alpha: 0.45),
      builder: (dctx) => Dialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 상단 56 원형 — 코랄 면 + 경고 삼각형(빨강)
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.coral50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(TablerIcons.alertTriangleFilled,
                    size: 28, color: AppColors.actionDanger),
              ),
              const SizedBox(height: 16),
              const Text(
                '같은 이름의 그룹이 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.38,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\'$name\'은 이미 사용 중인 이름이에요.\n다른 이름으로 만들어주세요',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: AppColors.gray700,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _dialogButton(
                  '이름 고치기',
                  primary: true,
                  onTap: () => Navigator.pop(dctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 팝업 버튼 — primary: 잉크 채움 / 아니면 소프트 그레이 보조
  Widget _dialogButton(String label,
      {required bool primary, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? AppColors.ink : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: primary ? AppColors.textOnBrand : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file != null && mounted) setState(() => _photo = file);
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '사진을 선택하지 못했어요');
    }
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
      // 같은 이름 중복 확인 — 기존 검색 로직 재사용(새 쿼리를 만들지 않는다).
      // 정확히 같은 이름이 이미 있으면 (B) 팝업으로 안내하고 생성을 중단한다.
      final existing = await GroupService.search(name);
      if (existing.any((g) => g.name.trim() == name)) {
        if (!mounted) return;
        setState(() => _creating = false);
        await _showDuplicateName(name);
        return;
      }
      String? imageUrl;
      if (_photo != null) {
        imageUrl = await GroupService.uploadGroupPhoto(_photo!);
      }
      // region은 비워서 넘긴다 — GroupService.createGroup이 생성자의
      // users/{uid}.region을 자동으로 채운다.
      await GroupService.createGroup(
        name: name,
        intro: _introController.text.trim(),
        imageUrl: imageUrl,
        intensity: _intensity,
        moods: _moods.toList(),
        isPublic: _isPublic,
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
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단 바 — X 닫기 + 제목 + 스페이서
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(TablerIcons.x, size: 23, color: AppColors.ink),
                    ),
                  ),
                  // 상단 제목 텍스트 제거 — 아래 큰 제목("어떤 그룹을 만들까요?")과 중복.
                  const Expanded(child: SizedBox()),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 큰 제목
                    const Text(
                      '어떤 그룹을 만들까요?',
                      style: TextStyle(
                        fontSize: 27,
                        height: 1.25,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 22),
                    // 썸네일 + 이름(밑줄형) — 이름 블록을 썸네일과 세로 중앙으로 맞춘다.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _thumb(),
                        const SizedBox(width: 16),
                        Expanded(child: _nameField()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // 한 줄 소개
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        _microLabel('한 줄 소개'),
                        const SizedBox(width: 7),
                        Text(
                          '선택',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.gray200, width: 1.5),
                        ),
                      ),
                      // 입력 텍스트와 밑줄을 거의 붙인다.
                      padding: const EdgeInsets.only(top: 2),
                      child: TextField(
                        controller: _introController,
                        maxLength: 200,
                        maxLines: 2,
                        minLines: 1,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterText: '',
                          hintText: '비워두면 \'그룹 소개가 없습니다.\'로 표시돼요',
                          hintStyle: TextStyle(
                            fontSize: 16,
                            height: 1.0,
                            fontWeight: FontWeight.w500,
                            color: AppColors.gray300,
                          ),
                        ),
                        // height 1.2 로 줄 여백을 줄여 밑줄에 바짝 붙게.
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.0,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 활동 강도 — 3택 카드(필수, 기본 '가볍게 뛰기')
                    _microLabel('활동 강도'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (int i = 0; i < _intensities.length; i++) ...[
                          Expanded(child: _intensityCard(_intensities[i])),
                          if (i < _intensities.length - 1)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    // 분위기 — 복수 선택 칩(선택, 기본 '조용히 각자')
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        _microLabel('분위기'),
                        const SizedBox(width: 7),
                        Text(
                          '선택',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final m in _moodOptions) _moodChip(m),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // 누구나 가입 가능 토글 — 켜면 자유 가입, 끄면 승인 후 가입
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _isPublic = !_isPublic),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isPublic ? TablerIcons.lockOpen : TablerIcons.lock,
                              size: 20,
                              color: AppColors.ink,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '누구나 가입 가능',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '끄면 승인 후 가입할 수 있어요',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.gray500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _toggle(_isPublic),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 하단 CTA — 잉크 버튼(64 · radius22).
            // 시스템 네비게이션바에 가려지지 않도록 SafeArea(top:false)로 하단 인셋 확보.
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _creating ? null : _create,
                  child: Container(
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _creating ? AppColors.gray200 : AppColors.ink,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      _creating ? '만드는 중...' : '그룹 만들기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _creating
                            ? AppColors.gray500
                            : AppColors.textOnBrand,
                      ),
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

  // 대표 사진(업로드 버튼) — 미선택 시 점선 보더 + 카메라 아이콘 + '썸네일' 라벨.
  // (점선 = '아직 비어 있음, 채워야 함'. 우하단 카메라 배지는 두지 않는다 — GROUP_CREATE §5.1)
  Widget _thumb() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: SizedBox(
        width: 76,
        height: 76,
        child: _photo != null
            // 업로드 후: 점선·라벨 제거하고 이미지로 채움
            ? ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.file(File(_photo!.path),
                    width: 76, height: 76, fit: BoxFit.cover),
              )
            : Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(22),
                  // 점선 대신 일반(실선) 테두리
                  border: Border.all(color: AppColors.gray300, width: 1.5),
                ),
                // 텍스트 없이 카메라 아이콘만 박스 가운데
                alignment: Alignment.center,
                child: const Icon(TablerIcons.cameraPlus,
                    size: 26, color: AppColors.gray700),
              ),
      ),
    );
  }

  // 이름 밑줄형 필드 (밑줄 2px 잉크 + 우측 카운터)
  Widget _nameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _microLabel('그룹 이름'),
        Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.ink, width: 2),
            ),
          ),
          // 입력 텍스트와 밑줄을 거의 붙인다.
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  maxLength: 20,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    hintText: '그룹 이름',
                    hintStyle: TextStyle(
                      fontSize: 19,
                      height: 1.0,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gray300,
                    ),
                  ),
                  // height 1.1 로 줄 여백(leading)을 줄여 텍스트가 밑줄에 바짝 붙게.
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_nameController.text.length}/20',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray350,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 활동 강도 카드 — 아이콘+라벨 2단. 선택 시 잉크 면+라임 아이콘.
  Widget _intensityCard(({IconData icon, String label}) item) {
    final selected = _intensity == item.label;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _intensity = item.label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              item.icon,
              size: 21,
              color: selected ? AppColors.lime : AppColors.gray700,
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? AppColors.textOnBrand : AppColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 분위기 칩 — 선택 시 잉크 채움 + 흰 글씨, 미선택은 연회색 면
  Widget _moodChip(String label) {
    final selected = _moods.contains(label);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (selected) {
          _moods.remove(label);
        } else {
          _moods.add(label);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.textOnBrand : AppColors.gray700,
          ),
        ),
      ),
    );
  }

  // 토글 스위치 — 켜짐: 다크 트랙 + 라임 노브(오른쪽), 꺼짐: 회색 트랙 + 흰 노브(왼쪽)
  Widget _toggle(bool on) {
    // 그룹 알림 토글과 동일하게 부드럽게 슬라이드되도록 AnimatedContainer 사용.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      width: 46,
      height: 28,
      padding: const EdgeInsets.all(3),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: on ? AppColors.ink : AppColors.gray300,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: on ? AppColors.lime : AppColors.surface,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // 폼 필드 라벨 — 너무 작다는 피드백 반영해 키움(12→13.5), 트래킹은 살짝 완화.
  Widget _microLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.gray500,
      ),
    );
  }
}
