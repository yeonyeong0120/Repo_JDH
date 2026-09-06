import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
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
    // 목업(Startline): 프로필은 흰 배경 + 밑줄/칩 구성.
    return Scaffold(
      backgroundColor: AppColors.surface,
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
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
                      children: [
                        _avatar(),
                        const SizedBox(height: 22),
                        _nicknameField(),
                        const SizedBox(height: 26),
                        _infoSection(),
                        const SizedBox(height: 26),
                        _readOnlySection(),
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

  // ── 라임 원형 아바타 96 + 카메라 뱃지 (목업) ──
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
              width: 96,
              height: 96,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: AppColors.lime, // 라임 아바타
                shape: BoxShape.circle,
              ),
              child: _uploading
                  ? const CircularProgressIndicator(
                      color: AppColors.actionPrimary,
                      strokeWidth: 2,
                    )
                  : (url == null || url.isEmpty)
                  ? _avatarInitial()
                  : Image.network(
                      url,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarInitial(),
                    ),
            ),
            // 카메라 뱃지 — 차콜 원 + 흰 테두리 + 라임 카메라
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                ),
                child: const Icon(
                  TablerIcons.camera,
                  size: 14,
                  color: AppColors.lime,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 아바타 폴백 — 닉네임 첫 글자 (사진 없을 때) ──
  Widget _avatarInitial() {
    final nick = _nickCtrl.text.trim().isEmpty
        ? _p.nickname
        : _nickCtrl.text.trim();
    final ch = nick.characters.isEmpty ? '' : nick.characters.first;
    return Text(
      ch,
      style: const TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.w800,
        color: AppColors.limeOn,
      ),
    );
  }

  // ── 폼 섹션 마이크로 라벨 (대문자 트래킹 느낌) ──
  Widget _microLabel(String title, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: AppColors.gray500,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 5),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: AppColors.gray350,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 닉네임: 마이크로 라벨 + 2px 잉크 밑줄 인풋 + n/10 ──
  Widget _nicknameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _microLabel('닉네임'),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.ink, width: 2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nickCtrl,
                  maxLength: 10,
                  cursorColor: AppColors.textPrimary,
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
                    fontSize: 18,
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
                    hintText: '닉네임',
                    hintStyle: TextStyle(color: AppColors.textDisabled),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_nickCtrl.text.characters.length}/10',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray350,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 내 정보: 몸무게 스테퍼 행만 (칼로리 계산용) ──
  // 성별·나이·키는 쓰이는 곳이 없어 수집하지 않는다.
  Widget _infoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _microLabel('내 정보', sub: '칼로리를 계산하는 데 쓰여요'),
        const SizedBox(height: 4),
        _numRow(
          TablerIcons.scale,
          '몸무게',
          _p.weight == null ? null : '${_p.weight}kg',
          () => _pickNumber(
            '몸무게',
            'kg',
            _p.weight ?? 60,
            30,
            150,
            (v) => setState(() => _p = _p.copyWith(weight: v)),
          ),
          last: true,
        ),
      ],
    );
  }

  // 스테퍼 행 (아이콘 + 라벨 + 값 + 셰브론). 미설정은 '선택'.
  Widget _numRow(
    IconData icon,
    String label,
    String? value,
    VoidCallback onTap, {
    bool last = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.line100, width: 1.5),
                ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.gray700),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              value ?? '선택',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: value == null ? AppColors.gray400 : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              TablerIcons.chevronRight,
              size: 19,
              color: AppColors.gray300,
            ),
          ],
        ),
      ),
    );
  }

  // ── 읽기 전용: 동네(수정 가능) / 접속 계정 / 가입일 ──
  Widget _readOnlySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _roRow(
          TablerIcons.mapPin,
          '동네',
          _p.region.isEmpty ? '미설정' : _p.region,
          onTap: _editRegion,
        ),
        _roRow(
          TablerIcons.userFilled,
          '접속 계정',
          _p.email.isEmpty ? '-' : _maskEmail(_p.email),
        ),
        _roRow(TablerIcons.calendar, '가입일', _joinedDot),
      ],
    );
  }

  Widget _roRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line100)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.gray700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray500,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                TablerIcons.chevronRight,
                size: 18,
                color: AppColors.gray300,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 가입일 — '2026. 4. 18.' 형식 (목업과 동일)
  String get _joinedDot {
    final d = _p.joinedAt;
    if (d == null) return _p.joinedText;
    return '${d.year}. ${d.month}. ${d.day}.';
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
              leading: const Icon(TablerIcons.photo),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(TablerIcons.camera),
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
                  _roundBtn(TablerIcons.minus, () => _set(_value - 1)),
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
                  _roundBtn(TablerIcons.plus, () => _set(_value + 1)),
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
            borderRadius: BorderRadius.circular(13),
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
