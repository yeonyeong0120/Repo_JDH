import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/auth/data/auth_repository.dart';
import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/core/location/region_updater.dart';
import 'package:repo_jdh/features/plogging/data/location_repository.dart';
import 'package:repo_jdh/features/plogging/data/geocode_service.dart';

/// 회원가입 온보딩 (3단계) — 플로고 · Startline 구조
///  1) 이메일·비밀번호·비밀번호 확인(인라인 3상태 검증)
///  2) 성별·나이·키·몸무게·지역(선택)
///  3) 닉네임
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

  String? _gender; // '남성' / '여성'
  int? _age;
  int? _height;
  int? _weight;

  bool _isLoading = false;

  // 2단계 지역 박스에 보여줄 현재 위치 주소.
  // 화면 진입(2단계 도달) 시 GPS+역지오코딩으로 한 번 채운다. 저장은 _finish 에서.
  String? _region; // 성공 시 '인천 남동구' 같은 지역명
  bool _regionLoading = false;
  bool _regionTried = false; // 중복 요청 방지

  // 단계별 제목/부제 (상단 고정 헤더에 노출)
  static const _titles = ['이메일로 시작해요', '더 정확한 측정에 필요해요', '어떻게 불러드릴까요?'];
  static const _subtitles = [
    '비밀번호는 8자 이상으로 만들어주세요.',
    '걸음수와 칼로리를 계산하는 데 쓰여요.',
    '그룹 채팅과 활동 기록에 표시되는 이름이에요.',
  ];

  @override
  void initState() {
    super.initState();
    // 인라인 검증을 실시간으로 갱신하기 위해 입력마다 리빌드
    _emailController.addListener(_rebuild);
    _passwordController.addListener(_rebuild);
    _pw2Controller.addListener(_rebuild);
    _nicknameController.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  // 현재 위치 주소를 한 번 불러와 2단계 지역 박스에 표시한다.
  // 저장하지 않고 표시만 한다 — 실제 저장은 _finish 의 RegionUpdater 가 담당.
  Future<void> _loadRegion() async {
    if (_regionTried) return;
    _regionTried = true;
    setState(() => _regionLoading = true);
    String? region;
    try {
      final coords = await LocationRepository().getCurrentCoordinates();
      if (coords != null) {
        region = await GeocodeService.regionOf(
          lat: coords.lat,
          lng: coords.lng,
        );
      }
    } catch (_) {
      // 실패는 무시 — 박스는 안내 문구로 폴백한다
    }
    if (!mounted) return;
    setState(() {
      _region = region;
      _regionLoading = false;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _pw2Controller.dispose();
    _nicknameController.dispose();
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

  // 최종: 계정 생성 + 프로필 저장
  Future<void> _finish() async {
    final nick = _nicknameController.text.trim();
    if (nick.length < 2 || nick.length > 10) {
      _snack('닉네임은 2~10자로 만들어주세요.');
      return;
    }
    setState(() => _isLoading = true);
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
      await UserService.updateProfileFields(
        gender: _gender,
        age: _age,
        height: _height,
        weight: _weight,
      );
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
                  onPageChanged: (i) {
                    setState(() => _step = i);
                    // 2단계 도달 시 현재 위치 주소를 한 번 불러온다
                    if (i == 1) _loadRegion();
                  },
                  children: [_step1(), _step2(), _step3()],
                ),
              ),
              _bottomArea(),
            ],
          ),
        ),
      ),
    );
  }

  // ── 상단 고정 헤더: 뒤로 + 3분할 진행바 + n/3 + 제목 + 부제 ──
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
              // 진행바 3분할
              Expanded(
                child: Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _step ? AppColors.ink : AppColors.gray200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: 5),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_step + 1} / 3',
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
    final color = [AppColors.gray500, AppColors.ink, AppColors.actionDanger][state];
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

  // ═══════════════ 1단계: 이메일 · 비밀번호 · 비밀번호 확인 ═══════════════
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
            const ['로그인할 때 쓰는 주소예요', '사용할 수 있는 이메일이에요', '올바른 이메일 형식이 아니에요'][_emailState],
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
            decoration: _underlineState('8자 이상', _pwState, suffix: _pwEyeToggle()),
          ),
          _validationRow(
            _pwState,
            const ['영문·숫자를 섞어 8자 이상', '쓸 수 있는 비밀번호예요', '8자 이상으로 만들어주세요'][_pwState],
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
            decoration:
                _underlineState('한 번 더 입력해주세요', _pw2State, suffix: _pwEyeToggle()),
          ),
          _validationRow(
            _pw2State,
            const ['똑같이 한 번 더 입력해주세요', '비밀번호가 일치해요', '비밀번호가 서로 달라요'][_pw2State],
          ),
          const SizedBox(height: 20),
          // 안내 박스
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
                  child: Icon(TablerIcons.shield, size: 18, color: AppColors.ink),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '이메일은 비밀번호를 다시 만들 때만 써요. 그룹에는 닉네임만 보입니다.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gray700,
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

  // ═══════════════ 2단계: 성별·나이·키·몸무게·지역 ═══════════════
  Widget _step2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('성별'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _genderBox('남성')),
              const SizedBox(width: 9),
              Expanded(child: _genderBox('여성')),
            ],
          ),
          const SizedBox(height: 22),
          _numberRow(
            icon: TablerIcons.cake,
            label: '나이',
            valueText: _age == null ? null : '$_age세',
            onTap: () => _showNumberSheet(
              title: '나이',
              subtitle: '칼로리 계산에 사용해요',
              unit: '세',
              min: 14,
              max: 100,
              initial: _age ?? 34,
              onConfirm: (v) => setState(() => _age = v),
            ),
          ),
          _numberRow(
            icon: TablerIcons.ruler2,
            label: '키',
            valueText: _height == null ? null : '${_height}cm',
            onTap: () => _showNumberSheet(
              title: '키',
              subtitle: '걸음 보폭과 칼로리 계산에 사용해요',
              unit: 'cm',
              min: 120,
              max: 220,
              initial: _height ?? 170,
              onConfirm: (v) => setState(() => _height = v),
            ),
          ),
          _numberRow(
            icon: TablerIcons.scale,
            label: '몸무게',
            valueText: _weight == null ? null : '${_weight}kg',
            onTap: () => _showNumberSheet(
              title: '몸무게',
              subtitle: '칼로리 계산에 사용해요',
              unit: 'kg',
              min: 30,
              max: 150,
              initial: _weight ?? 65,
              onConfirm: (v) => setState(() => _weight = v),
            ),
          ),
          const SizedBox(height: 20),
          // 지역 (자동 — 가입 완료 시 위치 권한 기반으로 설정)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  TablerIcons.currentLocation,
                  size: 19,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '지역',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.gray500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _regionLoading
                            ? '현재 위치를 확인하는 중…'
                            : (_region ?? '위치 권한을 켜면 자동으로 채워져요'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: (_region == null && !_regionLoading)
                              ? AppColors.gray500
                              : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_regionLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gray400,
                    ),
                  )
                else
                  const Text(
                    '자동',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '지금 건너뛰어도 괜찮아요. 메뉴에서 언제든 채울 수 있어요.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              fontWeight: FontWeight.w400,
              color: AppColors.gray350,
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderBox(String g) {
    final on = _gender == g;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _gender = g),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.lime : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: on ? AppColors.ink : AppColors.gray200,
            width: 1.5,
          ),
        ),
        child: Text(
          g,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }

  // 나이/키/몸무게 행 (h60, 밑줄 line100)
  Widget _numberRow({
    required IconData icon,
    required String label,
    required String? valueText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          border: Border(
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
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            Text(
              valueText ?? '선택',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: valueText == null ? AppColors.gray400 : AppColors.ink,
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

  // ═══════════════ 3단계: 닉네임 ═══════════════
  Widget _step3() {
    final nick = _nicknameController.text.trim();
    // 상태 0 미입력 / 1 통과 / 2 오류(2자 미만)
    final int nickState = nick.isEmpty ? 0 : (_nickOk ? 1 : 2);
    final borderColor =
        [AppColors.gray200, AppColors.ink, AppColors.actionDanger][nickState];
    final hintColor =
        [AppColors.gray500, AppColors.ink, AppColors.actionDanger][nickState];
    const hintIcons = [
      TablerIcons.infoCircle,
      TablerIcons.circleCheckFilled,
      TablerIcons.alertCircleFilled,
    ];
    final hintText = const [
      '한글·영문·숫자를 쓸 수 있어요',
      '쓸 수 있는 닉네임이에요',
      '두 글자 이상 입력해주세요',
    ][nickState];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('닉네임'),
          const SizedBox(height: 2),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 2),
              ),
            ),
            padding: const EdgeInsets.only(top: 9, bottom: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _nicknameController,
                    maxLength: 10,
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
                  '${nick.length}/10',
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
          Row(
            children: [
              Icon(hintIcons[nickState], size: 17, color: hintColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hintText,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: hintColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 미리보기 카드
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
        ],
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
    } else if (_step == 1) {
      label = '다음';
      icon = TablerIcons.arrowRight;
      enabled = true;
      onTap = () => _goTo(2);
      sub = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _goTo(2),
        child: const SizedBox(
          height: 46,
          child: Center(
            child: Text(
              '건너뛰기',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.gray500,
              ),
            ),
          ),
        ),
      );
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
          _ctaButton(label, icon, enabled, onTap, loading: _step == 2 && _isLoading),
          if (sub != null) ...[
            if (_step == 0) const SizedBox(height: 14),
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

  // ── 숫자 증감/키패드 바텀시트 ──
  void _showNumberSheet({
    required String title,
    required String subtitle,
    required String unit,
    required int min,
    required int max,
    required int initial,
    required ValueChanged<int> onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.ink.withValues(alpha: 0.42),
      builder: (ctx) => _NumberSheet(
        title: title,
        subtitle: subtitle,
        unit: unit,
        min: min,
        max: max,
        initial: initial,
        onConfirm: onConfirm,
      ),
    );
  }
}

/// 나이·키·몸무게 입력 시트 — −/+ 버튼(56×56) + 숫자 직접 입력 + 퀵칩 + 확인.
class _NumberSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String unit;
  final int min;
  final int max;
  final int initial;
  final ValueChanged<int> onConfirm;
  const _NumberSheet({
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.min,
    required this.max,
    required this.initial,
    required this.onConfirm,
  });

  @override
  State<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends State<_NumberSheet> {
  late int _val = widget.initial;
  late final TextEditingController _c = TextEditingController(
    text: '${widget.initial}',
  );
  final _focus = FocusNode();

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _set(int v) {
    final nv = v.clamp(widget.min, widget.max);
    setState(() {
      _val = nv;
      _c.text = '$nv';
      _c.selection = TextSelection.collapsed(offset: _c.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.fromLTRB(22, 14, 22, 30 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              height: 1.4,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.subtitle,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 22),
          // − [숫자(키패드)] +
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepBtn(TablerIcons.minus, () => _set(_val - 1)),
              const SizedBox(width: 18),
              SizedBox(
                width: 126,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    IntrinsicWidth(
                      child: TextField(
                        controller: _c,
                        focusNode: _focus,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 40,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.4,
                          color: AppColors.ink,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) _val = n;
                        },
                        onSubmitted: (_) => _set(_val),
                        onEditingComplete: () => _set(_val),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      widget.unit,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gray700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              _stepBtn(TablerIcons.plus, () => _set(_val + 1)),
            ],
          ),
          const SizedBox(height: 16),
          // 퀵칩 −10 / −5 / +5 / +10
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _quick('-10', () => _set(_val - 10)),
              const SizedBox(width: 6),
              _quick('-5', () => _set(_val - 5)),
              const SizedBox(width: 6),
              _quick('+5', () => _set(_val + 5)),
              const SizedBox(width: 6),
              _quick('+10', () => _set(_val + 10)),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final n = int.tryParse(_c.text) ?? _val;
                widget.onConfirm(n.clamp(widget.min, widget.max));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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
    );
  }

  // −/+ 버튼 56×56 radius18 보더
  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gray200, width: 1.5),
        ),
        child: Icon(icon, size: 25, color: AppColors.ink),
      ),
    );
  }

  Widget _quick(String label, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gray200, width: 1.5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.gray700,
          ),
        ),
      ),
    );
  }
}
