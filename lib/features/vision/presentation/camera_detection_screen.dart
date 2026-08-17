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

  // 카테고리 한글명 + 색 (인식 박스·집계 pill 공용)
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

  static const Color _darkBg = Color(0xFF141815);

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        backgroundColor: _darkBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('카메라 준비 중...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    final cameraAspectRatio = 1 / _camera!.value.aspectRatio;
    final int total = _liveCounts.values.fold<int>(0, (s, v) => s + v);
    final bool detected = total > 0;
    final entries = _liveCounts.entries.where((e) => e.value > 0).toList();

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  _darkIconButton(TablerIcons.chevronLeft, _cancel),
                  const SizedBox(width: 10),
                  const Text(
                    '쓰레기 등록',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  _darkIconButton(
                    TablerIcons.helpCircle,
                    () => setState(() => _showGuide = true),
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
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: _guideBanner(),
              ),
            ),
            // 카메라 프리뷰 + 인식 박스 + 코너 브래킷
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: cameraAspectRatio,
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
                              valueColor: AlwaysStoppedAnimation(Colors.white),
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
            // 하단 패널: 인식 상태 + 집계 pill + 취소·촬영하기
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statusChip(detected, total),
                  if (entries.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final e in entries) _countPill(e.key, e.value),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _cancelButton(),
                      const SizedBox(width: 12),
                      Expanded(child: _shotButton()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _darkIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: Colors.white, size: 23),
      ),
    );
  }

  Widget _guideBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF262B27),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(TablerIcons.bulbFilled, color: AppColors.green400, size: 20),
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

  Widget _statusChip(bool detected, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: detected ? AppColors.green400 : Colors.white38,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            detected ? '이렇게 인식했어요' : '쓰레기를 비춰주세요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: detected ? Colors.white : Colors.white54,
            ),
          ),
          const Spacer(),
          if (detected)
            Text(
              '$total개',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _countPill(String key, int count) {
    final (label, color) = _catMeta(key);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            '$label $count',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cancelButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isCapturing ? null : _cancel,
      child: Container(
        width: 84,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          '취소',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _shotButton() {
    // 인식이 안 돼도 촬영 가능 — 촬영한 사진으로 등록/직접 분류
    final bool on = !_isCapturing;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: on ? _registerAndClose : null,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.actionPrimary : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              TablerIcons.cameraFilled,
              size: 22,
              color: on ? Colors.white : Colors.white38,
            ),
            const SizedBox(width: 10),
            Text(
              '촬영하기',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 카메라 뷰파인더 4모서리 브래킷 (반투명 흰색).
class _BracketsPainter extends CustomPainter {
  const _BracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const double m = 34; // 가장자리 여백
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
