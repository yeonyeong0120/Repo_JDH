import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_button.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import '../data/detector.dart';
import '../../plogging/data/location_repository.dart';
import 'box_painter.dart';

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
    final totalNow = _liveCounts.values.fold<int>(0, (sum, v) => sum + v);
    if (totalNow == 0) {
      AppSnackBar.show(context, '인식된 쓰레기가 없습니다', neutral: true);
      return;
    }

    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      if (_camera!.value.isStreamingImages) {
        await _camera!.stopImageStream();
      }

      final results = await Future.wait([
        _camera!.takePicture(),
        LocationRepository().getCurrentLocation(),
      ]);

      final xFile = results[0] as XFile;
      final locationData = results[1] as Map<String, dynamic>?;

      if (mounted) {
        Navigator.pop(context, {
          'counts': Map<String, int>.from(_liveCounts),
          'imagePath': xFile.path,
          'location': locationData,
        });
      }
    } catch (e) {
      print('[등록] 실패: $e');
      if (mounted) {
        Navigator.pop(context, {
          'counts': Map<String, int>.from(_liveCounts),
          'imagePath': null,
          'location': null,
        });
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('카메라 준비 중...'),
            ],
          ),
        ),
      );
    }

    final cameraAspectRatio = 1 / _camera!.value.aspectRatio;
    final currentText = _liveCounts.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key} ${e.value}개')
        .join(', ');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          '쓰레기 등록',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: _cancel),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _serverConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _serverConnected
                  ? AppColors.primaryLight
                  : AppColors.error,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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
                                  fontSize: 16,
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
          Container(
            color: Colors.black87,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility,
                          color: Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '현재 인식:',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentText.isEmpty ? '쓰레기를 비춰주세요' : currentText,
                            style: TextStyle(
                              color: currentText.isEmpty
                                  ? Colors.white54
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: AppButton(
                            label: '취소',
                            onTap: _isCapturing ? null : _cancel,
                            enabled: !_isCapturing,
                            type: AppButtonType.secondary,
                            expand: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: AppButton(
                            label: '등록하기',
                            onTap: _isCapturing ? null : _registerAndClose,
                            enabled: !_isCapturing,
                            type: AppButtonType.primary,
                            expand: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
