import 'package:repo_jdh/features/auth/data/user_service.dart';
import 'package:repo_jdh/features/plogging/data/geocode_service.dart';
import 'package:repo_jdh/features/plogging/data/location_repository.dart';

/// GPS 로 지역(region)을 갱신하는 흐름의 실패 지점.
/// 호출부가 사용자에게 보여줄 안내 문구를 이걸로 고른다.
enum RegionRefreshError {
  locationUnavailable, // GPS 권한 거부 · 서비스 꺼짐 · 좌표 획득 실패
  geocodeUnavailable, // 좌표는 얻었지만 서버 역지오코딩 실패
  saveFailed, // 지역명은 얻었지만 Firestore 저장 실패
}

/// GPS 좌표 → 서버 역지오코딩 → 프로필 region 저장까지의 결과.
class RegionRefreshResult {
  final String? region; // 성공 시 갱신된 지역명 (서버 형식 그대로, 예: '남동구 논현고잔동')
  final RegionRefreshError? error; // 실패 시 사유. 성공이면 null.

  const RegionRefreshResult.success(this.region) : error = null;
  const RegionRefreshResult.failure(this.error) : region = null;

  bool get isSuccess => error == null;
}

/// GPS 로 현재 위치를 다시 잡아 프로필의 지역을 갱신한다.
/// 회원가입 화면 · 홈 화면이 동일한 흐름을 공유하도록 core 에 둔다.
///
/// 각 단계가 예외를 던지지 않고 실패를 RegionRefreshError 로 흡수하므로,
/// 호출부는 try/catch 없이 결과만 보면 된다.
class RegionUpdater {
  RegionUpdater._();

  static Future<RegionRefreshResult> refreshFromGps() async {
    final coords = await LocationRepository().getCurrentCoordinates();
    if (coords == null) {
      return const RegionRefreshResult.failure(
        RegionRefreshError.locationUnavailable,
      );
    }

    final region = await GeocodeService.placeNameOf(
      lat: coords.lat,
      lng: coords.lng,
    );
    if (region == null || region.isEmpty) {
      return const RegionRefreshResult.failure(
        RegionRefreshError.geocodeUnavailable,
      );
    }

    try {
      await UserService.updateRegion(
        region: region,
        lat: coords.lat,
        lng: coords.lng,
      );
    } catch (_) {
      return const RegionRefreshResult.failure(RegionRefreshError.saveFailed);
    }

    return RegionRefreshResult.success(region);
  }
}
