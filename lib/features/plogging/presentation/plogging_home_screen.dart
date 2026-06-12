import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/vision/presentation/camera_screen.dart';
import 'package:repo_jdh/core/providers/plogging_provider.dart';
import 'package:repo_jdh/features/plogging/data/storage_repository.dart';
import 'package:repo_jdh/features/auth/data/auth_repository.dart';
import 'package:go_router/go_router.dart';

class PloggingHomeScreen extends ConsumerStatefulWidget {
  const PloggingHomeScreen({super.key});

  @override
  ConsumerState<PloggingHomeScreen> createState() => _PloggingHomeScreenState();
}

class _PloggingHomeScreenState extends ConsumerState<PloggingHomeScreen> {
  final String _duration = '06:12';
  final String _distance = '0.12';
  final String _totalDistance = '0.9';
  final int _steps = 125;

  String? _selectedButton;
  bool _isExpanded = false;

  void _handleCameraTap() {
    if (_selectedButton == 'camera') {
      setState(() => _selectedButton = null);
      _openCamera();
    } else {
      setState(() => _selectedButton = 'camera');
    }
  }

  void _handleEndTap() {
    if (_selectedButton == 'end') {
      setState(() => _selectedButton = null);
      context.push('/plogging/settlement');
    } else {
      setState(() => _selectedButton = 'end');
    }
  }

  void _clearSelection() {
    if (_selectedButton != null) {
      setState(() => _selectedButton = null);
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthRepository.signOut();
    }
  }

  Future<void> _openCamera() async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (context) => const CameraDetectionScreen()),
    );

    if (result == null) return;

    final Map<String, int> counts = Map<String, int>.from(
      result['counts'] ?? {},
    );
    final String? imagePath = result['imagePath'];
    final Map<String, dynamic>? locationData =
        result['location'] as Map<String, dynamic>?;

    if (counts.isEmpty) return;

    String? imageUrl;
    if (imagePath != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('이미지 업로드 중...'),
              ],
            ),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.blue,
          ),
        );
      }
      imageUrl = await StorageRepository.uploadImage(File(imagePath));
    }

    try {
      await ref
          .read(firestoreRepositoryProvider)
          .saveDetection(counts, imageUrl: imageUrl, location: locationData);
    } catch (e) {
      debugPrint('Firestore 저장 실패: $e');
    }

    await ref.read(ploggingProvider.notifier).addCounts(counts);
    setState(() => _isExpanded = true);

    final summary = counts.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key} ${e.value}')
        .join(', ');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            imageUrl != null
                ? '✅ 등록 완료 (사진 저장됨): $summary'
                : '✅ 등록 완료: $summary',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _endPlogging() {
    final ploggingState = ref.read(ploggingProvider);
    final totalCounts = ploggingState.totalCounts;
    final registerCount = ploggingState.registerCount;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 플로깅 종료'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⏱️ 시간: $_duration'),
            Text('📏 거리: $_distance / $_totalDistance km'),
            Text('🚶 걸음: $_steps 보'),
            const Divider(),
            const Text(
              '수거한 쓰레기:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('🧴 플라스틱: ${totalCounts['plastic']}개'),
            Text('🥫 캔: ${totalCounts['can']}개'),
            Text('📄 종이: ${totalCounts['paper']}개'),
            Text('🪟 유리: ${totalCounts['glass']}개'),
            Text('🗑️ 일반: ${totalCounts['trash']}개'),
            const SizedBox(height: 8),
            Text(
              '총 $registerCount회 등록',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('계속하기'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(ploggingProvider.notifier).reset();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔄 초기화 완료!'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 22),
        color: Colors.black87,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTrashCount(String emoji, String label, int count) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: count > 0 ? Colors.green[700] : Colors.grey[600],
              ),
            ),
          ],
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ploggingState = ref.watch(ploggingProvider);

    if (ploggingState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totalCounts = ploggingState.totalCounts;
    final bool isCameraSelected = _selectedButton == 'camera';
    final bool isEndSelected = _selectedButton == 'end';
    final int cameraFlex = isCameraSelected ? 7 : (isEndSelected ? 3 : 5);
    final int endFlex = isEndSelected ? 7 : (isCameraSelected ? 3 : 5);

    return Scaffold(
      body: GestureDetector(
        onTap: _clearSelection,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/map_sample.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: Colors.green[100]);
                },
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildCircleButton(
                          icon: Icons.arrow_back_ios_new,
                          onPressed: _confirmLogout,
                        ),
                        _buildCircleButton(
                          icon: Icons.help_outline,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                            child: Row(
                              children: [
                                Expanded(child: _buildStatBox(_duration, '시간')),
                                Expanded(
                                  child: _buildStatBox(
                                    '$_distance/$_totalDistance',
                                    '거리(km)',
                                  ),
                                ),
                                Expanded(child: _buildStatBox('$_steps', '걸음')),
                                InkWell(
                                  onTap: () => setState(
                                    () => _isExpanded = !_isExpanded,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: AnimatedRotation(
                                      turns: _isExpanded ? 0.5 : 0,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.grey[700],
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: _isExpanded
                                ? Column(
                                    children: [
                                      const Divider(
                                        height: 1,
                                        indent: 16,
                                        endIndent: 16,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildTrashCount(
                                              '🧴',
                                              '플라스틱',
                                              totalCounts['plastic'] ?? 0,
                                            ),
                                            _buildTrashCount(
                                              '🥫',
                                              '캔',
                                              totalCounts['can'] ?? 0,
                                            ),
                                            _buildTrashCount(
                                              '📄',
                                              '종이',
                                              totalCounts['paper'] ?? 0,
                                            ),
                                            _buildTrashCount(
                                              '🪟',
                                              '유리',
                                              totalCounts['glass'] ?? 0,
                                            ),
                                            _buildTrashCount(
                                              '🗑️',
                                              '일반',
                                              totalCounts['trash'] ?? 0,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 16),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Row(
                        children: [
                          Expanded(
                            flex: cameraFlex,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              color: isCameraSelected
                                  ? AppColors.primary
                                  : Colors.white,
                              child: InkWell(
                                onTap: _handleCameraTap,
                                child: Center(
                                  child: _buildCameraButtonContent(
                                    isCameraSelected,
                                    isEndSelected,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_selectedButton == null)
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                          Expanded(
                            flex: endFlex,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              color: isEndSelected
                                  ? AppColors.error
                                  : Colors.white,
                              child: InkWell(
                                onTap: _handleEndTap,
                                child: Center(
                                  child: _buildEndButtonContent(
                                    isEndSelected,
                                    isCameraSelected,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildCameraButtonContent(bool isSelected, bool otherSelected) {
    // 선택됨 = 파랑 배경 위 흰색 / 미선택 = 흰 배경 위 파랑
    final Color contentColor = isSelected ? Colors.white : AppColors.primary;

    if (isSelected) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 20, color: contentColor),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '카메라 촬영',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: contentColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '한 번 더 누르세요',
                    style: TextStyle(
                      fontSize: 11,
                      color: contentColor.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (otherSelected) {
      return Icon(Icons.camera_alt, size: 24, color: contentColor);
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 22, color: contentColor),
            const SizedBox(width: 8),
            Text(
              '카메라',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: contentColor,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildEndButtonContent(bool isSelected, bool otherSelected) {
    // 선택됨 = 빨강 배경 위 흰색 / 미선택 = 흰 배경 위 빨강
    if (isSelected) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_settings_new, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '플로깅 종료',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '한 번 더 누르세요',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (otherSelected) {
      // 카메라가 선택돼 종료가 좁아진 상태 → 아이콘만
      return const Icon(
        Icons.power_settings_new,
        size: 24,
        color: AppColors.error,
      );
    } else {
      // 아무것도 선택 안 됨 → 아이콘 + '종료' 글자
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.power_settings_new, size: 22, color: AppColors.error),
            SizedBox(width: 8),
            Text(
              '종료',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      );
    }
  }
}
