import 'dart:io';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/auth/data/auth_repository.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/core/location/region_updater.dart';

/// 회원가입 온보딩 (2단계) — 플로고 · Startline 구조
///  1) 이메일·비밀번호·비밀번호 확인 (인라인 3상태 검증)
///  2) 프로필 사진(선택) · 닉네임 · 몸무게(선택)
///
/// 성별·나이·키·지역은 받지 않는다.
///  - 성별·나이·키: 쓰이는 곳이 없다(칼로리는 몸무게만 사용, 없으면 표준체중 60kg).
///  - 지역: 가입 완료 시 GPS 로 자동 설정한다.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _pageController = PageController();
  int _step = 0;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pw2Controller = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _obscurePassword = true;

  // 몸무게(선택) — 처음부터 표준체중 60kg 이 찍혀 있다. 안 건드리면 60kg 으로 저장.
  static const int _weightMin = 30;
  static const int _weightMax = 150;
  static const int _weightDefault = 60;
  int _weight = _weightDefault;
  late final TextEditingController _weightController = TextEditingController(
    text: '$_weightDefault',
  );

  // 프로필 사진(선택) — 계정이 만들어진 뒤(_finish) 업로드한다.
  File? _photoFile;

  // 닉네임 중복 — 제출 시 서버 확인 결과. 닉네임을 고치면 초기화된다.
  bool _nickTaken = false;

  bool _isLoading = false;

  // 단계별 제목/부제 (상단 고정 헤더에 노출)
  static const _titles = ['이메일로 시작해요', '어떻게 불러드릴까요?'];
  static const _subtitles = [
    '비밀번호는 8자 이상으로 만들어주세요.',
    '그룹 채팅과 활동 기록에 표시되는 이름이에요.',
  ];

  @override
  void initState() {
    super.initState();
    // 인라인 검증을 실시간으로 갱신하기 위해 입력마다 리빌드
    _emailController.addListener(_rebuild);
    _passwordController.addListener(_rebuild);
    _pw2Controller.addListener(_rebuild);
    _nicknameController.addListener(_onNicknameChanged);
  }

  void _rebuild() => setState(() {});

  // 닉네임을 고치면 이전 중복 판정을 초기화한다.
  void _onNicknameChanged() {
    setState(() => _nickTaken = false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _pw2Controller.dispose();
    _nicknameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      ),
    );
  }

  void _goTo(int i) {
    FocusScope.of(context).unfocus();
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      _goTo(_step - 1);
    }
  }

  // ── 인라인 검증 상태: 0 미입력 / 1 통과 / 2 오류 ──
  static final _emailReg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  bool get _emailOk => _emailReg.hasMatch(_emailController.text.trim());
  bool get _pwOk => _passwordController.text.length >= 8;
  bool get _pw2Ok =>
      _pw2Controller.text.isNotEmpty &&
      _pw2Controller.text == _passwordController.text;
  bool get _accountReady => _emailOk && _pwOk && _pw2Ok;

  int get _emailState =>
      _emailController.text.isEmpty ? 0 : (_emailOk ? 1 : 2);
  int get _pwState => _passwordController.text.isEmpty ? 0 : (_pwOk ? 1 : 2);
  int get _pw2State => _pw2Controller.text.isEmpty ? 0 : (_pw2Ok ? 1 : 2);

  bool get _nickOk {
    final n = _nicknameController.text.trim();
    return n.length >= 2 && n.length <= 10;
  }

  // 몸무게 값 설정 (범위 보정 + 입력칸 동기화)
  void _setWeight(int v) {
    final nv = v.clamp(_weightMin, _weightMax);
    setState(() {
      _weight = nv;
      _weightController.text = '$nv';
      _weightController.selection =
          TextSelection.collapsed(offset: _weightController.text.length);
    });
  }

  // 포커스 해제/제출 시 입력칸 값을 30~150 으로 보정
  void _commitWeightField() {
    final v = int.tryParse(_weightController.text.trim());
    _setWeight(v ?? _weight);
  }

  // ── 프로필 사진 선택 (갤러리/카메라) — 로컬 파일만 보관, 업로드는 _finish ──
  Future<void> _pickPhoto() async {
    FocusScope.of(context).unfocus();
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
    setState(() => _photoFile = File(picked.path));
  }

  // 최종: 계정 생성 + 프로필 저장(닉네임·몸무게) + 사진 업로드 + GPS 지역
  Future<void> _finish() async {
    final nick = _nicknameController.text.trim();
    if (nick.length < 2 || nick.length > 10) {
      _snack('닉네임은 2~10자로 만들어주세요.');
      return;
    }
    setState(() => _isLoading = true);

    // 닉네임 중복 확인 (best-effort — 규칙상 조회 불가면 통과시킨다)
    try {
      if (await UserService.isNicknameTaken(nick)) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _nickTaken = true;
        });
        _goTo(1);
        return;
      }
    } catch (_) {
      // 조회 실패는 무시하고 진행
    }

    final error = await AuthRepository.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _isLoading = false);
      _snack(error);
      _goTo(0); // 이메일 단계로 되돌림
      return;
    }
    try {
      await UserService.createProfile(
        email: _emailController.text.trim(),
        nickname: nick,
      );
      // 몸무게만 저장한다(성별·나이·키는 수집하지 않음)
      await UserService.updateProfileFields(weight: _weight);
      // 프로필 사진(선택) — 로컬로 담아둔 파일이 있으면 업로드
      if (_photoFile != null) {
        await UserService.uploadProfilePhoto(_photoFile!);
      }
      // 실패해도 가입 자체는 계속 진행 — 지역은 나중에 홈 버튼/메뉴에서 채울 수 있음
      final regionResult = await RegionUpdater.refreshFromGps();
      if (!regionResult.isSuccess) {
        debugPrint('[회원가입] 지역 갱신 실패: ${regionResult.error}');
      }
    } catch (_) {
      // 프로필 저장 실패해도 가입은 완료된 상태 — 나중에 메뉴에서 채움
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    // 로그인 화면으로 pop → 라우터가 로그인 상태·닉네임 보고 홈으로 보냄
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _step = i),
                  children: [_step1(), _step2()],
                ),
              ),
              _bottomArea(),
            ],
          ),
        ),
      ),
    );
  }

  // ── 상단 고정 헤더: 뒤로 + 2분할 진행바 + n/2 + 제목 + 부제 ──
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _back,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    TablerIcons.chevronLeft,
                    size: 24,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 진행바 2분할
              Expanded(
                child: Row(
                  children: [
                    for (int i = 0; i < 2; i++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                i <= _step ? AppColors.ink : AppColors.gray200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (i < 1) const SizedBox(width: 5),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_step + 1} / 2',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gray500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            _titles[_step],
            style: const TextStyle(
              fontSize: 27,
              height: 1.28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitles[_step],
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }

  // overline (section label) — 800 11.5px 자간1.4 gray500
  Widget _fieldLabel(String t, {double top = 0}) => Padding(
    padding: EdgeInsets.only(top: top),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: AppColors.gray500,
      ),
    ),
  );

  // 인라인 검증 행 (아이콘 + 12.5/600, 최소 높이 18)
  Widget _validationRow(int state, String msg) {
    const icons = [
      TablerIcons.infoCircle,
      TablerIcons.circleCheckFilled,
      TablerIcons.alertCircleFilled,
    ];
    final color =
        [AppColors.gray500, AppColors.ink, AppColors.actionDanger][state];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 18,
        child: Row(
          children: [
            Icon(icons[state], size: 15, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 밑줄 색이 검증 상태에 따라 바뀌는 인풋 데코 (0 기본 / 1 잉크 / 2 위험)
  InputDecoration _underlineState(String hint, int state, {Widget? suffix}) {
    final lineColor =
        [AppColors.gray200, AppColors.ink, AppColors.actionDanger][state];
    UnderlineInputBorder line(Color c) =>
        UnderlineInputBorder(borderSide: BorderSide(color: c, width: 1.5));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.gray350,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 11),
      suffixIcon: suffix,
      border: line(lineColor),
      enabledBorder: line(lineColor),
      focusedBorder: line(lineColor),
    );
  }

  Widget _pwEyeToggle() => IconButton(
    icon: Icon(
      _obscurePassword ? TablerIcons.eyeOff : TablerIcons.eye,
      color: AppColors.gray500,
      size: 20,
    ),
    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
  );

  // ═══════════════ 1/2: 이메일 · 비밀번호 · 비밀번호 확인 ═══════════════
  Widget _step1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('이메일'),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: _underlineState('name@example.com', _emailState),
          ),
          _validationRow(
            _emailState,
            const [
              '로그인할 때 쓰는 주소예요',
              '사용할 수 있는 이메일이에요',
              '올바른 이메일 형식이 아니에요',
            ][_emailState],
          ),
          _fieldLabel('비밀번호', top: 18),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration:
                _underlineState('8자 이상', _pwState, suffix: _pwEyeToggle()),
          ),
          _validationRow(
            _pwState,
            const [
              '영문·숫자를 섞어 8자 이상',
              '쓸 수 있는 비밀번호예요',
              '8자 이상으로 만들어주세요',
            ][_pwState],
          ),
          _fieldLabel('비밀번호 확인', top: 18),
          TextField(
            controller: _pw2Controller,
            obscureText: _obscurePassword,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: _underlineState(
              '한 번 더 입력해주세요',
              _pw2State,
              suffix: _pwEyeToggle(),
            ),
          ),
          _validationRow(
            _pw2State,
            const [
              '위와 같은 비밀번호를 입력해주세요',
              '비밀번호가 일치해요',
              '비밀번호가 일치하지 않아요',
            ][_pw2State],
          ),
          const SizedBox(height: 20),
          // 안심 카드
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 1),
                  child:
                      Icon(TablerIcons.shield, size: 18, color: AppColors.ink),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '이메일은 비밀번호를 다시 만들 때만 써요. 그룹에는 닉네임만 보입니다.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════ 2/2: 프로필 사진 · 닉네임 · 몸무게 ═══════════════
  Widget _step2() {
    final nick = _nicknameController.text.trim();
    // 힌트 4상태: 빈칸 / 중복 / 1자 / 통과
    final int nickState;
    if (nick.isEmpty) {
      nickState = 0; // 안내
    } else if (_nickTaken) {
      nickState = 3; // 중복(오류)
    } else if (nick.length < 2) {
      nickState = 2; // 1자(오류)
    } else {
      nickState = 1; // 통과
    }
    final bool nickError = nickState == 2 || nickState == 3;
    final borderColor = nickError
        ? AppColors.actionDanger
        : (nickState == 1 ? AppColors.ink : AppColors.gray200);
    final hintColor = nickError
        ? AppColors.actionDanger
        : (nickState == 1 ? AppColors.ink : AppColors.gray500);
    final IconData hintIcon = nickError
        ? TablerIcons.alertCircleFilled
        : (nickState == 1
            ? TablerIcons.circleCheckFilled
            : TablerIcons.infoCircle);
    final hintText = const [
      '한글·영문·숫자를 쓸 수 있어요', // 0 빈칸
      '쓸 수 있는 닉네임이에요', // 1 통과
      '두 글자 이상 입력해주세요', // 2 1자
      '이미 사용 중인 닉네임이에요', // 3 중복
    ][nickState];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1) 프로필 사진(선택)
          Center(child: _avatarPicker()),
          const SizedBox(height: 10),
          const Text(
            '선택이에요. 안 넣으면 기본 아바타로 보여요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 22),
          // 2) 닉네임
          _fieldLabel('닉네임'),
          const SizedBox(height: 2),
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 2)),
            ),
            padding: const EdgeInsets.only(top: 8, bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _nicknameController,
                    maxLength: 10,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.0,
                      color: AppColors.ink,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      filled: false, // 테마의 회색 fill 제거 (밑줄만 쓴다)
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: '2~10자',
                      hintStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.0,
                        color: AppColors.gray350,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${nick.characters.length}/10',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(hintIcon, size: 16, color: hintColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hintText,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: hintColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 3) 미리보기 카드
          _previewCard(nick),
          const SizedBox(height: 22),
          // 4) 추가 정보(선택) — 몸무게
          _fieldLabel('추가 정보 (선택)'),
          const SizedBox(height: 10),
          _weightCard(),
        ],
      ),
    );
  }

  // 아바타(64) + 카메라 뱃지(27) — 라임 원 + 차콜 유저 아이콘, 뱃지는 차콜 원 + 라임 카메라
  Widget _avatarPicker() {
    final file = _photoFile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isLoading ? null : _pickPhoto,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
            ),
            child: file == null
                ? const Icon(
                    TablerIcons.userFilled,
                    size: 30,
                    color: AppColors.ink,
                  )
                : Image.file(file, width: 64, height: 64, fit: BoxFit.cover),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 27,
              height: 27,
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
    );
  }

  // 미리보기 카드 — 그룹 채팅에서 보이는 모습(아바타 36 + 닉네임 + 활동 한 줄)
  Widget _previewCard(String nick) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('그룹 채팅에서는 이렇게 보여요'),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    color: AppColors.lime,
                    shape: BoxShape.circle,
                  ),
                  child: _photoFile == null
                      ? const Icon(
                          TablerIcons.userFilled,
                          size: 19,
                          color: AppColors.ink,
                        )
                      : Image.file(
                          _photoFile!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nick.isEmpty ? '닉네임' : nick,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '오전 7:30 · 소래습지 한 바퀴',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 몸무게 카드 — 인라인 −/+ 스테퍼 (기본 60kg, 직접 입력 가능)
  Widget _weightCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 부가설명을 박스 안 상단에 둔다 (미리보기 카드 오버라인처럼)
          const Text(
            '칼로리 계산에만 사용되고, 미작성 시 표준체중 60kg으로 계산돼요',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                TablerIcons.scale,
                size: 20,
                color: AppColors.gray700,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '몸무게',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              _weightStepBtn(TablerIcons.minus, () => _setWeight(_weight - 1)),
              SizedBox(
                width: 96,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    IntrinsicWidth(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.ink,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: false, // 테마의 회색 fill 제거
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) _weight = n;
                        },
                        onSubmitted: (_) => _commitWeightField(),
                        onEditingComplete: _commitWeightField,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gray700,
                      ),
                    ),
                  ],
                ),
              ),
              _weightStepBtn(TablerIcons.plus, () => _setWeight(_weight + 1)),
            ],
          ),
        ],
      ),
    );
  }

  // 몸무게 −/+ 버튼 46×46 radius14 흰 배경
  Widget _weightStepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gray200, width: 1.5),
        ),
        child: Icon(icon, size: 22, color: AppColors.ink),
      ),
    );
  }

  // ── 하단 CTA 영역 (단계별) ──
  Widget _bottomArea() {
    late final String label;
    late final IconData icon;
    late final bool enabled;
    late final VoidCallback? onTap;
    Widget? sub;

    if (_step == 0) {
      label = '다음';
      icon = TablerIcons.arrowRight;
      enabled = _accountReady;
      onTap = enabled ? () => _goTo(1) : null;
      sub = _loginLink();
    } else {
      label = '플로고 시작하기';
      icon = TablerIcons.check;
      enabled = _nickOk && !_isLoading;
      onTap = enabled ? _finish : null;
      sub = null;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ctaButton(
            label,
            icon,
            enabled,
            onTap,
            loading: _step == 1 && _isLoading,
          ),
          if (sub != null) ...[
            const SizedBox(height: 14),
            sub,
          ],
        ],
      ),
    );
  }

  Widget _loginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '이미 계정이 있나요? ',
          style: TextStyle(
            color: AppColors.gray500,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: const Text(
            '로그인',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  // 차콜 CTA h58 radius18 — 라임 아이콘, 비활성은 gray200/gray350
  Widget _ctaButton(
    String label,
    IconData icon,
    bool enabled,
    VoidCallback? onTap, {
    bool loading = false,
  }) {
    final bg = enabled ? AppColors.ink : AppColors.gray200;
    final fg = enabled ? Colors.white : AppColors.gray350;
    final iconFg = enabled ? AppColors.lime : AppColors.gray350;
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 20, color: iconFg),
                ],
              ),
      ),
    );
  }
}
