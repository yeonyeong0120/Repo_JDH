import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/mypage/domain/profile_detail.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';

/// 프로필 조회 · 수정 (메뉴 → 프로필 카드 탭)
/// 회원가입에서 받은 정보(성별·나이·키·몸무게·지역)를 여기서 수정한다.
/// 위치 권장: lib/features/mypage/presentation/profile_screen.dart
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileDetail _p = const ProfileDetail();
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    ProfileDetail p = const ProfileDetail();
    try {
      p = await UserService.loadProfileDetail();
    } catch (_) {
      // 실패 시 빈 프로필
    }
    if (!mounted) return;
    setState(() {
      _p = p;
      _loading = false;
    });
  }

  Future<void> _save(ProfileDetail next) async {
    setState(() => _p = next); // 낙관적 반영
    try {
      await UserService.updateProfileFields(
        nickname: next.nickname,
        gender: next.gender,
        age: next.age,
        height: next.height,
        weight: next.weight,
        region: next.region,
      );
    } catch (_) {
      if (mounted) AppSnackBar.show(context, '저장하지 못했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBG,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              )
            : Column(
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
                          '프로필',
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
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      children: [
                        _avatarAndName(),
                        const SizedBox(height: 22),
                        _infoCard(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // 사진 변경 — 갤러리 또는 카메라
  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.cardBG,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('사진 촬영'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800, // 업로드 용량 절약
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final url = await UserService.uploadProfilePhoto(File(picked.path));
      if (!mounted) return;
      setState(() {
        if (url != null) _p = _p.copyWith(photoUrl: url);
        _uploading = false;
      });
      if (url == null && mounted) AppSnackBar.show(context, '사진을 올리지 못했어요');
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      AppSnackBar.show(context, '사진을 올리지 못했어요');
    }
  }

  // ── 프로필 사진 + 닉네임 ──
  Widget _avatarAndName() {
    final url = _p.photoUrl;
    return Column(
      children: [
        GestureDetector(
          onTap: _uploading ? null : _changePhoto,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPale,
                  shape: BoxShape.circle,
                ),
                child: _uploading
                    ? const CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      )
                    : (url == null || url.isEmpty)
                    ? const Text('🦭', style: TextStyle(fontSize: 44))
                    : Image.network(
                        url,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Text('🦭', style: TextStyle(fontSize: 44)),
                      ),
              ),
              // 카메라 뱃지
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.appBG, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _editNickname,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _p.nickname.isEmpty ? '플로거' : _p.nickname,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 정보 카드 ──
  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          _row('접속 중인 계정', _p.email.isEmpty ? '-' : _p.email),
          _row('성별', _p.gender ?? '선택 안 함', onTap: _editGender),
          _row(
            '나이',
            _p.age == null ? '입력 안 함' : '${_p.age}세',
            onTap: () => _editNumber(
              '나이',
              '세',
              _p.age ?? 25,
              1,
              100,
              (v) => _save(_p.copyWith(age: v)),
            ),
          ),
          _row(
            '키',
            _p.height == null ? '입력 안 함' : '${_p.height}cm',
            onTap: () => _editIntField(
              '키 변경',
              'cm',
              _p.height,
              (v) => _save(_p.copyWith(height: v)),
            ),
          ),
          _row(
            '몸무게',
            _p.weight == null ? '입력 안 함' : '${_p.weight}kg',
            onTap: () => _editIntField(
              '몸무게 변경',
              'kg',
              _p.weight,
              (v) => _save(_p.copyWith(weight: v)),
            ),
          ),
          _row(
            '지역',
            _p.region.isEmpty ? '입력 안 함' : _p.region,
            onTap: _editRegion,
          ),
          _row('가입일', _p.joinedText, last: true),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    VoidCallback? onTap,
    bool last = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.divider, width: 0.8),
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  // ── 수정 다이얼로그들 ──

  Future<void> _editNickname() async {
    final c = TextEditingController(text: _p.nickname);
    final ok = await _textDialog('닉네임 변경', '10자 이하로 입력해주세요', c, 10);
    if (ok == true && c.text.trim().isNotEmpty) {
      await _save(_p.copyWith(nickname: c.text.trim()));
    }
  }

  Future<void> _editRegion() async {
    final c = TextEditingController(text: _p.region);
    final ok = await _textDialog('지역 변경', '예: 인천 부평구', c, 20);
    if (ok == true) await _save(_p.copyWith(region: c.text.trim()));
  }

  Future<bool?> _textDialog(
    String title,
    String hint,
    TextEditingController c,
    int maxLength,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.cardBG,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: c,
                autofocus: true,
                maxLength: maxLength,
                decoration: InputDecoration(
                  hintText: hint,
                  counterText: '',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      '확인',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 키·몸무게는 직접 입력
  Future<void> _editIntField(
    String title,
    String unit,
    int? current,
    ValueChanged<int> onDone,
  ) async {
    final c = TextEditingController(text: current?.toString() ?? '');
    final ok = await _textDialog(title, '숫자만 입력해주세요 ($unit)', c, 3);
    if (ok != true) return;
    final v = int.tryParse(c.text.trim());
    if (v != null && v > 0) {
      onDone(v);
    } else if (mounted) {
      AppSnackBar.show(context, '숫자를 입력해주세요');
    }
  }

  Future<void> _editGender() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBG,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final g in ['남', '여'])
              ListTile(
                title: Text(g),
                trailing: _p.gender == g
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, g),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await _save(_p.copyWith(gender: picked));
  }

  // 숫자는 휠로 선택 (회원가입과 동일 방식)
  Future<void> _editNumber(
    String label,
    String unit,
    int initial,
    int min,
    int max,
    ValueChanged<int> onDone,
  ) async {
    int temp = initial;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBG,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
                        onDone(temp);
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
      ),
    );
  }
}
