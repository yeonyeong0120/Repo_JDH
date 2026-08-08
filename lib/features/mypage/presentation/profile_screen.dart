import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/mypage/domain/profile_detail.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';

/// 프로필 조회 · 수정 (메뉴 → 프로필 카드 탭)
/// 회원가입에서 받은 정보(성별·나이·키·몸무게·지역)를 여기서 수정한다.
/// 상단 '저장'을 눌러야 실제 반영된다(닉네임 중복 검사 포함).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileDetail _p = const ProfileDetail();
  final TextEditingController _nickCtrl = TextEditingController();
  String _originalNick = ''; // 중복검사 스킵용(내 닉 그대로면 통과)
  bool _loading = true;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    super.dispose();
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
      _originalNick = p.nickname;
      _nickCtrl.text = p.nickname;
      _loading = false;
    });
  }

  // ── 상단 '저장' — 닉네임 검증 후 전체 필드 반영 ──
  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final nick = _nickCtrl.text.trim();
    if (nick.isEmpty) {
      AppSnackBar.show(context, '닉네임을 입력해주세요');
      return;
    }

    setState(() => _saving = true);
    try {
      // 닉네임이 바뀌었을 때만 중복 검사
      if (nick != _originalNick && await UserService.isNicknameTaken(nick)) {
        if (mounted) {
          setState(() => _saving = false);
          AppSnackBar.show(context, '이미 사용 중인 닉네임이에요');
        }
        return;
      }

      await UserService.updateProfileFields(
        nickname: nick,
        gender: _p.gender,
        age: _p.age,
        height: _p.height,
        weight: _p.weight,
        region: _p.region.isEmpty ? null : _p.region,
      );

      if (!mounted) return;
      _originalNick = nick;
      AppSnackBar.show(context, '저장했어요');
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppSnackBar.show(context, '저장하지 못했어요');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.actionPrimary,
                  strokeWidth: 2,
                ),
              )
            : Column(
                children: [
                  _topBar(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        const SizedBox(height: 6),
                        _avatar(),
                        const SizedBox(height: 22),
                        _nicknameCard(),
                        const SizedBox(height: 24),
                        _sectionLabel('기본 정보', '칼로리 계산에 사용해요'),
                        const SizedBox(height: 10),
                        _basicInfoCard(),
                        const SizedBox(height: 24),
                        _sectionLabel('계정', null),
                        const SizedBox(height: 10),
                        _accountCard(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── 상단 바: 뒤로 + 프로필 + 저장 ──
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
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
          const Spacer(),
          TextButton(
            onPressed: _saving ? null : _save,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.actionPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.actionPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    '저장',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }

  // ── 프로필 사진(둥근 네모) + 카메라 뱃지 ──
  Widget _avatar() {
    final url = _p.photoUrl;
    return Center(
      child: GestureDetector(
        onTap: _uploading ? null : _changePhoto,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 104,
              height: 104,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surfaceBrand,
                borderRadius: BorderRadius.circular(28),
              ),
              child: _uploading
                  ? const CircularProgressIndicator(
                      color: AppColors.actionPrimary,
                      strokeWidth: 2,
                    )
                  : (url == null || url.isEmpty)
                  ? const Icon(
                      Icons.person,
                      size: 56,
                      color: AppColors.textSecondary,
                    )
                  : Image.network(
                      url,
                      width: 104,
                      height: 104,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        size: 56,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.actionPrimary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bg, width: 3),
                ),
                child: const Icon(
                  Icons.photo_camera,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 닉네임: 라벨은 박스 위, 입력칸은 단색(초록 없음) ──
  Widget _nicknameCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            '닉네임',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 2, 14, 2),
          decoration: BoxDecoration(
            // 아래 기본 정보 카드와 동일한 하양 + 테두리
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nickCtrl,
                  maxLength: 10,
                  cursorColor: AppColors.textPrimary, // 초록 커서 제거
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) {
                        return null; // 기본 카운터 숨김 (우측에 직접 표시)
                      },
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '닉네임',
                    hintStyle: TextStyle(color: AppColors.textDisabled),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_nickCtrl.text.characters.length}/10',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 섹션 라벨 ('기본 정보' + 보조설명) ──
  Widget _sectionLabel(String title, String? sub) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(width: 8),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 기본 정보 카드 ──
  Widget _basicInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _editRow('성별', _p.gender ?? '선택 안 함', _editGender),
          _editRow(
            '나이',
            _p.age == null ? '입력 안 함' : '${_p.age}세',
            () => _pickNumber(
              '나이',
              '세',
              _p.age ?? 25,
              10,
              100,
              (v) => setState(() => _p = _p.copyWith(age: v)),
            ),
          ),
          _editRow(
            '키',
            _p.height == null ? '입력 안 함' : '${_p.height}cm',
            () => _pickNumber(
              '키',
              'cm',
              _p.height ?? 165,
              100,
              220,
              (v) => setState(() => _p = _p.copyWith(height: v)),
            ),
          ),
          _editRow(
            '몸무게',
            _p.weight == null ? '입력 안 함' : '${_p.weight}kg',
            () => _pickNumber(
              '몸무게',
              'kg',
              _p.weight ?? 60,
              30,
              150,
              (v) => setState(() => _p = _p.copyWith(weight: v)),
            ),
          ),
          _editRow(
            '지역',
            _p.region.isEmpty ? '입력 안 함' : _p.region,
            _editRegion,
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _editRow(
    String label,
    String value,
    VoidCallback onTap, {
    bool last = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.border, width: 0.8),
                ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }

  // ── 계정 카드 (읽기 전용) ──
  Widget _accountCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 0.8),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '접속 중인 계정',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    _p.email.isEmpty ? '-' : _maskEmail(_p.email),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (_providerLabel != null) ...[
                  const SizedBox(width: 8),
                  _providerChip(_providerLabel!),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                const Text(
                  '가입일',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  _p.joinedText,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_daysSinceJoin != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '+$_daysSinceJoin일',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textBrand,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.green100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textBrandOnLight,
        ),
      ),
    );
  }

  // 이메일 도메인으로 추정한 로그인 수단 라벨 (표시용)
  String? get _providerLabel {
    final e = _p.email.toLowerCase();
    if (e.isEmpty) return null;
    if (e.endsWith('@gmail.com')) return 'Google';
    if (e.endsWith('@naver.com')) return 'Naver';
    if (e.endsWith('@kakao.com')) return 'Kakao';
    return '이메일';
  }

  int? get _daysSinceJoin {
    final d = _p.joinedAt;
    if (d == null) return null;
    final days = DateTime.now().difference(d).inDays;
    return days < 0 ? 0 : days;
  }

  // kim****@gmail.com 형태로 로컬파트 일부 마스킹
  String _maskEmail(String e) {
    final at = e.indexOf('@');
    if (at <= 0) return e;
    final local = e.substring(0, at);
    final domain = e.substring(at);
    if (local.length <= 3) {
      return '${local.characters.first}***$domain';
    }
    return '${local.substring(0, 3)}****$domain';
  }

  // ── 사진 변경 — 갤러리 또는 카메라 ──
  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
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

  // ── 성별 선택 시트 ──
  Future<void> _editGender() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            for (final g in ['남성', '여성'])
              ListTile(
                title: Text(g),
                trailing: _p.gender == g
                    ? const Icon(Icons.check, color: AppColors.actionPrimary)
                    : null,
                onTap: () => Navigator.pop(ctx, g),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _p = _p.copyWith(gender: picked));
  }

  // ── 지역 입력 다이얼로그 ──
  Future<void> _editRegion() async {
    FocusScope.of(context).unfocus();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: '지역 변경',
        hint: '예: 인천 남동구 만수동',
        initial: _p.region,
        maxLength: 20,
      ),
    );
    if (result != null) setState(() => _p = _p.copyWith(region: result.trim()));
  }

  // ── 숫자 선택 시트 (−/+ · 직접 입력) ──
  Future<void> _pickNumber(
    String label,
    String unit,
    int initial,
    int min,
    int max,
    ValueChanged<int> onDone,
  ) async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _NumberSheet(
        label: label,
        unit: unit,
        initial: initial,
        min: min,
        max: max,
        onDone: onDone,
      ),
    );
  }
}

// ── 지역 등 짧은 텍스트 입력 다이얼로그 (컨트롤러 자체 소유) ──
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.hint,
    required this.initial,
    required this.maxLength,
  });

  final String title;
  final String hint;
  final String initial;
  final int maxLength;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _c,
              autofocus: true,
              maxLength: widget.maxLength,
              decoration: InputDecoration(
                hintText: widget.hint,
                counterText: '',
                hintStyle: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.actionPrimary,
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _c.text),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      color: AppColors.actionPrimary,
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
}

// ── 숫자 조절 시트 (−/+ 버튼 · 키패드 직접 입력) ──
class _NumberSheet extends StatefulWidget {
  const _NumberSheet({
    required this.label,
    required this.unit,
    required this.initial,
    required this.min,
    required this.max,
    required this.onDone,
  });

  final String label;
  final String unit;
  final int initial;
  final int min;
  final int max;
  final ValueChanged<int> onDone;

  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  late int _value = _clampInt(widget.initial);
  late final TextEditingController _c = TextEditingController(
    text: _value.toString(),
  );

  // int 로 안전하게 범위 제한 (num.clamp 반환형 회피)
  int _clampInt(int v) {
    if (v < widget.min) return widget.min;
    if (v > widget.max) return widget.max;
    return v;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _set(int v) {
    final nv = _clampInt(v);
    setState(() {
      _value = nv;
      _c.text = nv.toString();
      _c.selection = TextSelection.collapsed(offset: _c.text.length);
    });
  }

  void _commitField() {
    final v = int.tryParse(_c.text.trim());
    _set(v ?? _value);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _roundBtn(Icons.remove, () => _set(_value - 1)),
                  // 값 입력칸 — 고정 폭 박스(단색), IntrinsicWidth 미사용
                  SizedBox(
                    width: 150,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        SizedBox(
                          width: 96,
                          child: TextField(
                            controller: _c,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            cursorColor: AppColors.textPrimary,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onSubmitted: (_) => _commitField(),
                            onEditingComplete: _commitField,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.unit,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _roundBtn(Icons.add, () => _set(_value + 1)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _quick('-10', -10),
                  _quick('-5', -5),
                  _quick('+5', 5),
                  _quick('+10', 10),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    _commitField();
                    widget.onDone(_value);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.actionPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.neutral300, width: 1.2),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Icon(icon, size: 26, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  // 빠른 증감 — 회원가입과 동일한 방식(내용 크기에 맞춘 pill)
  Widget _quick(String label, int delta) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _set(_value + delta),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.neutral300),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
