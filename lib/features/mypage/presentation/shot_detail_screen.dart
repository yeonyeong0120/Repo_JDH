import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/widgets/app_snackbar.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';

/// 한 컷 상세 — 인증샷 모음집에서 사진 한 장을 눌렀을 때.
///
/// 사진·장소·촬영 시각·수거량은 모두 활동 기록(Activity)의 실데이터다.
/// 다만 사진 삭제 API가 없어 삭제 버튼은 안내만 띄운다(목업).
class ShotDetailScreen extends StatelessWidget {
  final Activity activity;
  final String imageUrl;

  const ShotDetailScreen({
    super.key,
    required this.activity,
    required this.imageUrl,
  });

  // 쓰레기 종류 한글 라벨 — 그래프 도넛과 같은 순서
  static const Map<String, String> _catLabel = {
    'plastic': '플라스틱',
    'can': '캔',
    'paper': '종이',
    'glass': '유리',
    'trash': '일반',
  };

  String get _placeName {
    final p = activity.placeName;
    return (p == null || p.isEmpty) ? '기록한 한 컷' : p;
  }

  /// '2026. 9. 2. 오전 9:12 · 38분 활동'
  String get _meta {
    final d = activity.startedAt;
    final ampm = d.hour < 12 ? '오전' : '오후';
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final dur = ActivityMetrics.durationLabel(activity.durationSeconds);
    return '${d.year}. ${d.month}. ${d.day}. $ampm $h12:$mm · $dur 활동';
  }

  @override
  Widget build(BuildContext context) {
    final grams = ActivityMetrics.weightGrams(activity.trashCounts);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _photo(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 20, 6, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _placeName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _meta,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF7E8A83),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _chips(grams),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _bottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
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
                color: Colors.white,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '한 컷',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _photo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 430,
        width: double.infinity,
        color: AppColors.darkSurface,
        alignment: Alignment.center,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 430,
          errorBuilder: (_, __, ___) => const Text(
            '사진을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7E8A83),
            ),
          ),
        ),
      ),
    );
  }

  // 수거량 라임 칩 + 종류별 개수 칩
  Widget _chips(int grams) {
    final kg = (grams / 1000).toStringAsFixed(2);
    final chips = <Widget>[
      if (grams > 0) _chip('${kg}kg', accent: true),
      for (final e in _catLabel.entries)
        if ((activity.trashCounts[e.key] ?? 0) > 0)
          _chip('${e.value} ${activity.trashCounts[e.key]}'),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _chip(String text, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: accent ? AppColors.lime : AppColors.darkSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: accent ? FontWeight.w800 : FontWeight.w600,
          color: accent ? AppColors.limeOn : Colors.white,
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onDelete(context),
            child: Container(
              width: 64,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                TablerIcons.trash,
                size: 22,
                color: Color(0xFFFF6B5A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onShare,
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(TablerIcons.share2, size: 20, color: AppColors.limeOn),
                    SizedBox(width: 8),
                    Text(
                      '자랑하기',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.limeOn,
                      ),
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

  // 사진 삭제 — 활동 기록에서 사진만 지우는 API가 없어 안내만 띄운다.
  void _onDelete(BuildContext context) {
    AppSnackBar.show(context, '사진 삭제는 준비 중이에요');
  }

  Future<void> _onShare() async {
    final grams = ActivityMetrics.weightGrams(activity.trashCounts);
    final kg = (grams / 1000).toStringAsFixed(2);
    await SharePlus.instance.share(
      ShareParams(text: '$_placeName에서 ${kg}kg 주웠어요 · 플로고\n$imageUrl'),
    );
  }
}
