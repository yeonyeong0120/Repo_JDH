import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/vision/data/detector.dart';
import 'package:repo_jdh/features/plogging/data/location_repository.dart';
import 'package:repo_jdh/features/vision/presentation/box_painter.dart';

class CameraDetectionScreen extends ConsumerStatefulWidget {
  const CameraDetectionScreen({super.key});

  @override
  ConsumerState<CameraDetectionScreen> createState() =>
      _CameraDetectionScreenState();
}

class _CameraDetectionScreenState extends ConsumerState<CameraDetectionScreen> {
  CameraController? _camera;
  final GarbageDetector _detector = GarbageDetector();

  bool _isReady = false;
  bool _isProcessing = false;
  bool _serverConnected = false;
  bool _isCapturing = false;
  bool _showGuide = true; // 상시 촬영 가이드 배너 (닫기 가능)

  // 카테고리 한글명 + 색 (인식 박스·집계 칩 공용)
  (String, Color) _catMeta(String k) {
    switch (k) {
      case 'plastic':
        return ('플라스틱', AppColors.dataPlastic);
      case 'can':
        return ('캔', AppColors.dataCan);
      case 'paper':
        return ('종이', AppColors.dataPaper);
      case 'glass':
        return ('유리', AppColors.dataGlass);
      default:
        return ('일반', AppColors.dataGeneral);
    }
  }

  List<DetectionResult> _detections = [];
  Map<String, int> _liveCounts = {};

  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _intervalMs = 700;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _serverConnected = await _detector.healthCheck();

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _camera = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _camera!.initialize();
    if (!mounted) return;

    await _camera!.setFlashMode(FlashMode.off);
    setState(() => _isReady = true);
    await _camera!.startImageStream(_onImage);
  }

  Future<void> _onImage(CameraImage image) async {
    final now = DateTime.now();
    if (now.difference(_lastSentAt).inMilliseconds < _intervalMs) return;
    if (_isProcessing) return;
    if (!_serverConnected) return;

    _lastSentAt = now;
    _isProcessing = true;

    try {
      final jpegBytes = await _convertYUV420toJPEG(image);
      final response = await _detector.detect(jpegBytes);

      if (mounted) {
        setState(() {
          _detections = response.detections;
          _liveCounts = response.counts;
        });
      }
    } catch (e) {
      debugPrint('Detect error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _registerAndClose() async {
    // TODO(임시): 인식 없어도 촬영 버튼을 눌러 흐름을 확인할 수 있게 0개 가드 임시 해제.
    // final totalNow = _liveCounts.values.fold<int>(0, (sum, v) => sum + v);
    // if (totalNow == 0) {
    //   AppSnackBar.show(context, '인식된 쓰레기가 없습니다', neutral: true);
    //   return;
    // }

    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    // 인식된 결과 그대로 사용 (없으면 빈 값 — 촬영한 사진으로 진행, 확인 시트에서 직접 분류)
    final Map<String, int> recognized = Map<String, int>.from(_liveCounts);

    String? imagePath;
    Map<String, dynamic>? locationData;
    try {
      if (_camera!.value.isStreamingImages) {
        await _camera!.stopImageStream();
      }
      final results = await Future.wait([
        _camera!.takePicture(),
        LocationRepository().getCurrentLocation(),
      ]);
      imagePath = (results[0] as XFile).path;
      locationData = results[1] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[등록] 촬영 실패: $e');
    }
    if (mounted) setState(() => _isCapturing = false);
    if (!mounted) return;

    // '이렇게 담을까요?' 확인 시트 → 개수 수정/추가 후 담기
    final confirmed = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(initial: recognized),
    );
    if (!mounted) return;

    if (confirmed == null) {
      // 다시 찍기 → 스트림 재개
      try {
        if (!_camera!.value.isStreamingImages) {
          await _camera!.startImageStream(_onImage);
        }
      } catch (_) {}
      return;
    }

    Navigator.pop(context, {
      'counts': confirmed,
      'imagePath': imagePath,
      'location': locationData,
    });
  }

  void _cancel() => Navigator.pop(context, null);

  Future<Uint8List> _convertYUV420toJPEG(CameraImage image) async {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final imgBuffer = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final yValue = yBuffer[yIndex];
        final uValue = uBuffer[uvIndex];
        final vValue = vBuffer[uvIndex];

        int r = (yValue + 1.402 * (vValue - 128)).round();
        int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
            .round();
        int b = (yValue + 1.772 * (uValue - 128)).round();

        imgBuffer.setPixelRgb(
          x,
          y,
          r.clamp(0, 255),
          g.clamp(0, 255),
          b.clamp(0, 255),
        );
      }
    }

    final rotated = img.copyRotate(imgBuffer, angle: 90);
    return Uint8List.fromList(img.encodeJpg(rotated, quality: 80));
  }

  @override
  void dispose() {
    if (_camera?.value.isStreamingImages ?? false) {
      _camera?.stopImageStream();
    }
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.lime),
              SizedBox(height: 16),
              Text('카메라 준비 중...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    final int total = _liveCounts.values.fold<int>(0, (s, v) => s + v);
    final bool detected = total > 0;
    final entries = _liveCounts.entries.where((e) => e.value > 0).toList();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바: 닫기(×) · 안내(i)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  // 규칙 A: 닫기 x 23 / 흰색 / 44x44 / 컨테이너 없음
                  _darkIconButton(TablerIcons.x, _cancel, size: 23),
                  const Spacer(),
                  // 우상단 안내(i) 아이콘 — 촬영 가이드 열기/닫기 토글 (흰색 21)
                  _darkIconButton(
                    TablerIcons.infoCircle,
                    () => setState(() => _showGuide = !_showGuide),
                  ),
                ],
              ),
            ),
            // 상시 촬영 가이드 — 닫아도 자리(높이)는 유지해 카메라 크기가 안 변한다.
            Visibility(
              visible: _showGuide,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _guideBanner(),
              ),
            ),
            // 카메라 미리보기 + 인식 박스 + 라임 코너 브래킷
            // (화면 밖으로 넘치던 뷰파인더 박스 제거 — 미리보기가 프레임을 채운다)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_camera!),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: DetectionPainter(detections: _detections),
                        ),
                      ),
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _BracketsPainter()),
                        ),
                      ),
                      if (_isProcessing)
                        const Positioned(
                          top: 12,
                          right: 12,
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.lime),
                            ),
                          ),
                        ),
                      if (_isCapturing)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '사진 촬영 중...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // 하단: 인식 결과(종류 칩 + 개수) + 라임 촬영 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '인식됨',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                          color: AppColors.gray500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        // 예: 2종 · 7개
                        detected
                            ? '${entries.length}종 · $total개'
                            : '쓰레기를 비춰주세요',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (entries.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in entries) _foundChip(e.key, e.value),
                      ],
                    )
                  else
                    _emptyChip(),
                  const SizedBox(height: 20),
                  Center(child: _captureButton()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _darkIconButton(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.white,
    double size = 21,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // 규칙 A(다크): 글리프만 44x44, 반투명 캡슐 배경 제거
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: Icon(icon, color: color, size: size)),
      ),
    );
  }

  Widget _guideBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.darkChip,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(TablerIcons.bulbFilled, color: AppColors.lime, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              const TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white70,
                ),
                children: [
                  TextSpan(
                    text: '한 번에 하나씩 ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(text: '비춰주세요. 바닥에 내려놓고 찍으면 더 잘 인식돼요.'),
                ],
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _showGuide = false),
            child: const Padding(
              padding: EdgeInsets.only(left: 4, top: 1),
              child: Icon(TablerIcons.x, color: Colors.white54, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // 인식된 종류 칩 — 분류색 면 + 흰 글씨/아이콘 (목업 그대로)
  Widget _foundChip(String key, int count) {
    final (label, color) = _catMeta(key);
    IconData icon;
    switch (key) {
      case 'plastic':
        icon = TablerIcons.bottle;
        break;
      case 'can':
        icon = TablerIcons.cup;
        break;
      case 'paper':
        icon = TablerIcons.fileDescription;
        break;
      case 'glass':
        icon = TablerIcons.glassFull;
        break;
      default:
        icon = TablerIcons.trash;
    }
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: Colors.white),
          const SizedBox(width: 7),
          Text(
            '$label $count',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // 아직 인식 전 — 비활성 칩 하나로 자리 유지
  Widget _emptyChip() {
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.darkChip,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        '쓰레기를 인식시켜 주세요',
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.gray400,
        ),
      ),
    );
  }

  // 라임 원형 촬영 버튼 (인식이 안 돼도 촬영 가능 — 확인 시트에서 직접 분류)
  Widget _captureButton() {
    final bool on = !_isCapturing;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: on ? _registerAndClose : null,
      child: Container(
        width: 88,
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.lime : AppColors.darkChip,
          shape: BoxShape.circle,
          boxShadow: on
              ? [
                  BoxShadow(
                    color: AppColors.lime.withValues(alpha: 0.18),
                    spreadRadius: 6,
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Icon(
          TablerIcons.cameraFilled,
          size: 34,
          color: on ? AppColors.ink : Colors.white38,
        ),
      ),
    );
  }
}

// 카메라 뷰파인더 4모서리 브래킷 (라임).
class _BracketsPainter extends CustomPainter {
  const _BracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const double m = 24; // 가장자리 여백
    const double len = 30; // 브래킷 길이

    void corner(double cx, double cy, int sx, int sy) {
      final path = Path()
        ..moveTo(cx + sx * len, cy)
        ..lineTo(cx, cy)
        ..lineTo(cx, cy + sy * len);
      canvas.drawPath(path, p);
    }

    corner(m, m, 1, 1); // 좌상
    corner(size.width - m, m, -1, 1); // 우상
    corner(m, size.height - m, 1, -1); // 좌하
    corner(size.width - m, size.height - m, -1, -1); // 우하
  }

  @override
  bool shouldRepaint(covariant _BracketsPainter oldDelegate) => false;
}

// '이렇게 담을까요?' 확인 시트 (촬영 후 노출).
// 인식된 종류는 '인식된 그대로예요', 수정·직접 추가한 종류는 '직접 고쳤어요'.
// 개수 1에서 - 를 누르면 그 종류는 목록에서 삭제되어 '다른 종류 추가'로 돌아간다.
class _ConfirmSheet extends StatefulWidget {
  final Map<String, int> initial;
  const _ConfirmSheet({required this.initial});

  @override
  State<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends State<_ConfirmSheet> {
  // (키, 라벨, 아이콘, 색)
  static const List<(String, String, IconData, Color)> _cats = [
    ('plastic', '플라스틱', TablerIcons.bottle, Color(0xFF5F9EE8)),
    ('can', '캔', TablerIcons.cup, Color(0xFFE07B2E)),
    ('paper', '종이', TablerIcons.fileDescription, Color(0xFF31C88B)),
    ('glass', '유리', TablerIcons.glassFull, Color(0xFF8E7EC4)),
    ('trash', '일반', TablerIcons.trash, Color(0xFF9AA3A0)),
  ];

  late Map<String, int> _counts;
  final Set<String> _edited = {}; // 사용자가 수정·추가한 종류
  bool _showAdd = false;

  @override
  void initState() {
    super.initState();
    _counts = Map<String, int>.of(widget.initial);
  }

  int get _total => _counts.values.fold<int>(0, (s, v) => s + v);

  void _dec(String k) {
    setState(() {
      final c = _counts[k] ?? 0;
      if (c <= 1) {
        _counts.remove(k); // 1에서 내리면 종류 삭제 → 다른 종류 추가로 복귀
      } else {
        _counts[k] = c - 1;
      }
      _edited.add(k);
    });
  }

  void _inc(String k) {
    setState(() {
      _counts[k] = (_counts[k] ?? 0) + 1;
      _edited.add(k);
    });
  }

  void _add(String k) {
    setState(() {
      _counts[k] = 1;
      _edited.add(k);
      _showAdd = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final present = _cats.where((c) => (_counts[c.$1] ?? 0) > 0).toList();
    final absent = _cats.where((c) => (_counts[c.$1] ?? 0) == 0).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: AppColors.neutral300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '이렇게 담을까요?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '다르면 개수를 고쳐주세요.',
                    style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  for (final c in present) _row(c),
                  if (absent.isNotEmpty) _addSection(absent),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 14 + media.padding.bottom),
            child: Row(
              children: [
                Expanded(
                  child: _sheetButton(
                    label: '다시 찍기',
                    icon: TablerIcons.refresh,
                    primary: false,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _sheetButton(
                    label: '$_total개 담기',
                    primary: true,
                    onTap: _total == 0
                        ? null
                        : () => Navigator.pop(
                            context,
                            Map<String, int>.fromEntries(
                              _counts.entries.where((e) => e.value > 0),
                            ),
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

  Widget _row((String, String, IconData, Color) c) {
    final k = c.$1;
    final int cnt = _counts[k] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(c.$3, size: 21,  color: c.$4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.$2,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _edited.contains(k) ? '직접 고쳤어요' : '인식된 그대로예요',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _stepper(k, cnt),
        ],
      ),
    );
  }

  Widget _stepper(String k, int cnt) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(TablerIcons.minus, () => _dec(k)),
          SizedBox(
            width: 26,
            child: Text(
              '$cnt',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _stepBtn(TablerIcons.plus, () => _inc(k)),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 20, color: AppColors.textBrandOnLight),
      ),
    );
  }

  Widget _addSection(List<(String, String, IconData, Color)> absent) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showAdd = !_showAdd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showAdd ? '접기' : '다른 종류 추가',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textBrandOnLight,
                  ),
                ),
                Icon(
                  _showAdd ? TablerIcons.chevronUp : TablerIcons.chevronDown,
                  size: 20,
                  color: AppColors.textBrandOnLight,
                ),
              ],
            ),
          ),
        ),
        if (_showAdd) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final c in absent) _addChip(c)],
          ),
        ],
      ],
    );
  }

  Widget _addChip((String, String, IconData, Color) c) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _add(c.$1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(c.$3, size: 18,  color: c.$4),
            const SizedBox(width: 6),
            Text(
              c.$2,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(TablerIcons.plus, size: 16, color: AppColors.textBrandOnLight),
          ],
        ),
      ),
    );
  }

  Widget _sheetButton({
    required String label,
    IconData? icon,
    required bool primary,
    VoidCallback? onTap,
  }) {
    final bool on = onTap != null;
    final Color bg = primary
        ? (on ? AppColors.actionPrimary : AppColors.neutral200)
        : AppColors.surface;
    final Color fg = primary
        ? (on ? Colors.white : AppColors.neutral500)
        : AppColors.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: primary ? null : Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19, color: fg),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
