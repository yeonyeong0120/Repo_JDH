import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';
import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/features/plogging/data/activity_service.dart';
import 'package:repo_jdh/features/plogging/domain/activity.dart';
import 'package:repo_jdh/features/plogging/domain/activity_metrics.dart';

/// 플로고 - 인증샷 모음집 (MYPAGE-37)
/// 진입: 메뉴 → 인증샷 모음집 (메뉴 화면은 다른 담당자 소유).
///
/// 완료된 활동의 실제 인증샷(Activity.imageUrls)을 월별로 묶어 그리드로 보여준다.
/// 상단 요약(모은 컷 수·누적 수거량)과 각 활동의 대표 컷 수거량 칩도 실데이터다.
/// 별도 갤러리 모델/서비스는 없으며 활동 기록만으로 구성한다.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  // 집계용 조회 상한 (다른 활동 화면과 맞춤)
  static const int _limit = 500;

  // null = 로딩 중 / [] = 로딩됐고 사진 0장
  List<_MonthGroup>? _months;
  int _photoCount = 0; // 모은 한 컷 (전체 사진 수)
  int _totalWeightGrams = 0; // 누적 수거 (전체 활동 합)
  Object? _loadError; // null 이 아니면 에러 발생

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ActivityService.getRecentCompleted(limit: _limit);
      if (!mounted) return;
      setState(() {
        _months = _group(list);
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  // 완료된 활동의 인증샷을 월별로 묶는다. 최신 월이 위로.
  List<_MonthGroup> _group(List<Activity> activities) {
    int photoCount = 0;
    int totalWeight = 0;
    final buckets = <int, _MonthAccum>{};

    for (final a in activities) {
      totalWeight += ActivityMetrics.weightGrams(a.trashCounts);
      if (a.imageUrls.isEmpty) continue;

      final d = a.startedAt;
      final key = d.year * 100 + d.month; // 연*100+월 → 정렬 키
      final acc = buckets.putIfAbsent(
        key,
        () => _MonthAccum(d.year, d.month),
      );
      final weight = ActivityMetrics.weightGrams(a.trashCounts);
      for (int i = 0; i < a.imageUrls.length; i++) {
        photoCount += 1;
        acc.photos.add(
          _Photo(
            url: a.imageUrls[i],
            weightGrams: weight,
            // 활동의 첫 컷에만 수거량 칩을 표시(목업처럼 듬성듬성)
            showWeight: i == 0 && weight > 0,
          ),
        );
      }
    }

    _photoCount = photoCount;
    _totalWeightGrams = totalWeight;

    final groups = buckets.values.map((e) => e.toGroup()).toList();
    groups.sort((a, b) => b.key.compareTo(a.key)); // 최신 월 먼저
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddPhoto,
        backgroundColor: AppColors.ink,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(TablerIcons.camera, color: AppColors.lime, size: 24),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 상단 바 — 뒤로 + 가운데 제목 + 달력
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
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
                  const Expanded(
                    child: Text(
                      '인증샷 모음집',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onCalendar,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        TablerIcons.calendarMonth,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // 로딩 / 에러 / 빈 / 목록
  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '인증샷을 불러오지 못했어요',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_months == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.progress,
          strokeWidth: 2,
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQueryData.fromView(View.of(context)).padding.bottom + 96,
      ),
      children: [
        _summaryRow(),
        const SizedBox(height: 20),
        if (_months!.isEmpty)
          const _EmptyGallery()
        else
          for (final m in _months!) ...[
            _monthHeader(m),
            const SizedBox(height: 10),
            _photoGrid(m),
            const SizedBox(height: 22),
          ],
      ],
    );
  }

  // 상단 요약 — 모은 한 컷(다크 카드) + 누적 수거(소프트 카드)
  Widget _summaryRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: '모은 한 컷',
            value: '$_photoCount장',
            dark: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: '누적 수거',
            value: _weightLabel(_totalWeightGrams),
            dark: false,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required bool dark,
  }) {
    return Container(
      // 고정 높이(84)는 Pretendard 라인 높이·글꼴 확대 설정에서 세로 넘침이 났다.
      // 최소 높이만 두고 내용이 커지면 카드가 함께 늘어나게 한다.
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: dark ? AppColors.ink : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dark
                  ? AppColors.gray300
                  : AppColors.gray500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            // 두 카드 높이가 어긋나지 않도록 값은 한 줄로 고정한다.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: dark ? AppColors.neutral0 : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // 월 구분 헤더 — 'N월' + '{count}장'
  Widget _monthHeader(_MonthGroup m) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          m.label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          '${m.photos.length}장',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.gray500,
          ),
        ),
      ],
    );
  }

  // 월별 사진 그리드 (3열 정사각형)
  Widget _photoGrid(_MonthGroup m) {
    return GridView.count(
      // padding 을 비워 두면 MediaQuery 의 하단 인셋이 자동으로 붙는다.
      // 바깥 SafeArea 가 bottom: false 라 그 값이 남아 있어 명시적으로 0을 준다.
      padding: EdgeInsets.zero,
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [for (final p in m.photos) _photoCell(p)],
    );
  }

  Widget _photoCell(_Photo p) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            p.url,
            fit: BoxFit.cover,
            // 로딩 중: 소프트 그레이 면
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(color: AppColors.surfaceSoft);
            },
            // 실패: 사진 없음 아이콘
            errorBuilder: (ctx, err, stack) => Container(
              color: AppColors.surfaceSoft,
              alignment: Alignment.center,
              child: const Icon(
                TablerIcons.photoOff,
                size: 22,
                color: AppColors.gray400,
              ),
            ),
          ),
          if (p.showWeight)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _weightLabel(p.weightGrams),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 달력 버튼 — 월별 이동은 아직 미구현이라 안내만 (데이터 지어내지 않음)
  void _onCalendar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('월별 보기는 준비 중이에요')),
    );
  }

  // 인증샷 추가 — 활동 단위로만 첨부 가능(활동 상세)해서 여기선 안내만
  void _onAddPhoto() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('인증샷은 활동 상세에서 추가할 수 있어요')),
    );
  }

  // 누적/개별 수거량 — 1000g 이상은 kg, 미만은 g
  String _weightLabel(int grams) {
    if (grams >= 1000) return '${(grams / 1000.0).toStringAsFixed(1)}kg';
    return '${grams}g';
  }
}

// 사진이 하나도 없을 때 보여주는 정직한 빈 화면
class _EmptyGallery extends StatelessWidget {
  const _EmptyGallery();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        children: [
          Icon(TablerIcons.photo, size: 48, color: AppColors.gray400),
          SizedBox(height: 14),
          Text(
            '아직 모은 인증샷이 없어요',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '플로깅하며 남긴 인증샷이\n이곳에 월별로 모여요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// 월 그룹 집계용 임시 버킷
class _MonthAccum {
  final int year;
  final int month;
  final List<_Photo> photos = [];

  _MonthAccum(this.year, this.month);

  _MonthGroup toGroup() {
    // 올해면 'N월', 지난 해면 'yyyy년 N월'
    final now = DateTime.now();
    final label = year == now.year ? '$month월' : '$year년 $month월';
    return _MonthGroup(
      key: year * 100 + month,
      label: label,
      photos: photos,
    );
  }
}

// 화면에 그릴 월 그룹
class _MonthGroup {
  final int key; // 연*100+월 (정렬용)
  final String label;
  final List<_Photo> photos;

  const _MonthGroup({
    required this.key,
    required this.label,
    required this.photos,
  });
}

// 인증샷 한 장
class _Photo {
  final String url;
  final int weightGrams; // 이 사진이 속한 활동의 수거량
  final bool showWeight; // 대표 컷에만 수거량 칩 표시

  const _Photo({
    required this.url,
    required this.weightGrams,
    required this.showWeight,
  });
}
