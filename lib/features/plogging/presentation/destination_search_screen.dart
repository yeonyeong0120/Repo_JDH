// 목적지 검색 화면(07). 플로깅 경로 설정에서 상단 검색창을 누르면 진입한다.
//
// 앱에는 실제 장소 검색(정방향 지오코딩) 백엔드가 없다. LocationRepository/GeocodeService는
// 좌표 -> 주소(역지오코딩)만 제공한다. 따라서 이 화면의 검색 결과 목록은 지어낸 백엔드가
// 아니라 "정직한 플레이스홀더"다 — 망원 일대의 예시 장소를 정적으로 담고, 입력어로
// 로컬 필터링만 한다. 결과를 탭하면 그 좌표를 destinationProvider에 넣고 화면을 닫는다.
//
// 실데이터로 동작하는 부분:
//  - "현재 위치" 칩: currentLocationProvider(실 GPS)로 도착지를 잡고 닫는다.
//  - 거리 표시·"가까운 순" 정렬: 실 GPS가 있으면 예시 좌표까지의 실제 거리로 계산한다.
//
// 가이드라인 준수: package: 절대경로 import, withValues(alpha:), 한국어 주석, "플로고".
//                 단순 로컬 UI 상태(입력어)만 setState로 다룬다.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import 'package:repo_jdh/core/theme/app_colors.dart';
import 'package:repo_jdh/core/theme/app_typography.dart';
import 'package:repo_jdh/core/theme/app_spacing.dart';
import 'package:repo_jdh/features/plogging/domain/destination_providers.dart';

class DestinationSearchScreen extends ConsumerStatefulWidget {
  const DestinationSearchScreen({super.key});

  @override
  ConsumerState<DestinationSearchScreen> createState() =>
      _DestinationSearchScreenState();
}

class _DestinationSearchScreenState
    extends ConsumerState<DestinationSearchScreen> {
  final TextEditingController _controller = TextEditingController();

  // 현재 입력어 — 로컬 필터에만 쓰는 단순 UI 상태.
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 두 좌표 사이 거리(m) — 하버사인. 실 GPS가 있을 때 결과 목록의 거리·정렬에 쓴다.
  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000; // 지구 반지름(m)
    final double dLat = (lat2 - lat1) * math.pi / 180;
    final double dLon = (lon2 - lon1) * math.pi / 180;
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // 결과 탭 — 좌표를 도착지로 지정하고 경로 설정 화면으로 돌아간다.
  void _selectPlace(double lat, double lon) {
    ref.read(destinationProvider.notifier).state = (lat, lon);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 실 GPS(출발지) — 거리 계산·정렬 기준점.
    final loc = ref.watch(currentLocationProvider).valueOrNull;
    final double? myLat = (loc?['latitude'] as num?)?.toDouble();
    final double? myLon = (loc?['longitude'] as num?)?.toDouble();

    // 입력어로 예시 장소를 필터링한다(로컬). 백엔드 검색이 아니다.
    final String q = _query.trim();
    // ⚠️ 항상 새 리스트로 만든다 — 아래 sort() 가 리스트를 제자리 수정하므로,
    //    const 리스트(_examplePlaces)를 그대로 넘기면 Unsupported operation(빨간 화면)이 난다.
    final List<_PlaceItem> filtered = q.isEmpty
        ? [..._examplePlaces]
        : _examplePlaces
              .where(
                (p) => p.name.contains(q) || p.address.contains(q),
              )
              .toList();

    // GPS가 있으면 실제 거리로 "가까운 순" 정렬한다.
    if (myLat != null && myLon != null) {
      filtered.sort((a, b) {
        final da = _distanceMeters(myLat, myLon, a.lat, a.lon);
        final db = _distanceMeters(myLat, myLon, b.lat, b.lon);
        return da.compareTo(db);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 뒤로가기 + 검색 입력창(× 지우기)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 18, 0),
              child: Row(
                children: [
                  _backButton(),
                  const SizedBox(width: 4),
                  Expanded(child: _searchField()),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 결과 헤더: 검색 결과 N / 가까운 순
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '검색 결과 ${filtered.length}',
                    style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.gray500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '가까운 순',
                    style: AppType.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // 결과 목록(정직한 플레이스홀더)
            Expanded(
              child: filtered.isEmpty
                  ? _emptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.line100.withValues(alpha: 0.9),
                      ),
                      itemBuilder: (context, i) {
                        final p = filtered[i];
                        final String distanceLabel =
                            (myLat != null && myLon != null)
                            ? _formatDistance(
                                _distanceMeters(myLat, myLon, p.lat, p.lon),
                              )
                            : p.exampleDistance;
                        return _placeRow(p, distanceLabel);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 거리(m) -> "620m" / "1.2km" 표기.
  String _formatDistance(double meters) {
    if (meters < 1000) return '${(meters / 10).round() * 10}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  // 상단 뒤로가기 버튼(원형 히트영역).
  Widget _backButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Icon(TablerIcons.chevronLeft, size: 24, color: AppColors.ink),
      ),
    );
  }

  // 검색 입력창 — 실제 TextField. 백엔드 없이 예시 목록만 로컬 필터한다.
  Widget _searchField() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // 목적지 설정 화면의 검색창(흰색)과 색을 통일한다.
      // 회색 면 대신 흰 배경 + 연한 테두리로 경계를 살린다.
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: Radii.fullR,
        border: Border.all(color: AppColors.line100, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(TablerIcons.search, size: 20, color: AppColors.gray500),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              style: AppType.label.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
              cursorColor: AppColors.ink,
              decoration: InputDecoration(
                isCollapsed: true,
                // 포커스 시 회색 테두리 박스가 생기지 않게 모든 상태를 없앤다.
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                hintText: '장소 · 지하철역 · 주소 검색',
                hintStyle: AppType.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray350,
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty) ...[
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _controller.clear();
                setState(() => _query = '');
              },
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gray250.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  TablerIcons.x,
                  size: 15,
                  color: AppColors.gray700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 결과 한 줄: 아이콘 타일 + 이름/주소 + 거리.
  Widget _placeRow(_PlaceItem p, String distanceLabel) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectPlace(p.lat, p.lon),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // 아이콘 타일 — 결과는 모두 동일한 회색 타일로 통일한다.
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: Radii.tileR,
              ),
              child: Icon(p.icon, size: 22, color: AppColors.gray700),
            ),
            const SizedBox(width: 14),
            // 이름 + 주소
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.title3.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(
                      color: AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 거리
            Text(
              distanceLabel,
              style: AppType.label.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 빈 결과 상태.
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            TablerIcons.mapSearch,
            size: 40,
            color: AppColors.gray300,
          ),
          const SizedBox(height: 12),
          Text(
            '검색 결과가 없어요',
            style: AppType.label.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.gray500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '지도에서 직접 도착지를 골라보세요',
            style: AppType.caption.copyWith(color: AppColors.gray400),
          ),
        ],
      ),
    );
  }
}

// 예시 장소 항목(플레이스홀더 전용, presentation 로컬 모델).
// domain/data의 모델이 아니며, 실제 장소 검색 백엔드가 없어 시각 대조용으로만 쓴다.
class _PlaceItem {
  final IconData icon;
  final String name;
  final String address;
  final double lat;
  final double lon;
  final String exampleDistance; // GPS가 없을 때 보여줄 예시 거리
  final bool limeTile; // 아이콘 타일을 라임 틴트로 표시할지

  const _PlaceItem({
    required this.icon,
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
    required this.exampleDistance,
    this.limeTile = false,
  });
}

// 망원 일대 예시 목적지(정직한 플레이스홀더). 좌표는 대략값이며 실검색 결과가 아니다.
const List<_PlaceItem> _examplePlaces = [
  _PlaceItem(
    icon: TablerIcons.mapPin,
    name: '월드컵로13길 22',
    address: '망원한강공원 2번 출입구',
    lat: 37.5545,
    lon: 126.8975,
    exampleDistance: '620m',
  ),
  _PlaceItem(
    icon: TablerIcons.buildingStore,
    name: 'GS25 망원역점',
    address: '서울 마포구 망원로8길 15',
    lat: 37.5561,
    lon: 126.9105,
    exampleDistance: '340m',
  ),
  _PlaceItem(
    icon: TablerIcons.tree,
    name: '망원한강공원',
    address: '서울 마포구 망원동 s1-1',
    lat: 37.5545,
    lon: 126.8960,
    exampleDistance: '620m',
    limeTile: true,
  ),
  _PlaceItem(
    icon: TablerIcons.train,
    name: '망원역 2번 출구',
    address: '서울 지하철 6호선',
    lat: 37.5556,
    lon: 126.9106,
    exampleDistance: '480m',
  ),
  _PlaceItem(
    icon: TablerIcons.basket,
    name: '망원시장',
    address: '서울 마포구 망원로8길 14',
    lat: 37.5563,
    lon: 126.9080,
    exampleDistance: '410m',
  ),
  _PlaceItem(
    icon: TablerIcons.buildingCommunity,
    name: '망원동 주민센터',
    address: '서울 마포구 월드컵로13길 20',
    lat: 37.5580,
    lon: 126.9040,
    exampleDistance: '560m',
  ),
];
