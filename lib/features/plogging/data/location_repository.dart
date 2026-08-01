import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationRepository {
  /// 현재 위치 정보를 반환 (위도, 경도, 한국어 주소)
  /// 실패 시 null 반환 — 위치 저장 실패해도 앱은 정상 동작
  Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      // 1. 위치 서비스 활성화 확인
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ [Location] 기기 위치 서비스가 꺼져 있습니다');
        return null;
      }

      // 2. 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ [Location] 위치 권한 거부됨');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        print('⚠️ [Location] 위치 권한 영구 거부됨 — 설정에서 허용 필요');
        return null;
      }

      // 3. 현재 위치 획득
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      print('✅ [Location] 좌표 획득: ${position.latitude}, ${position.longitude}');

      // 4. 좌표 → 한국어 주소 변환
      String address = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            p.administrativeArea,
            p.subAdministrativeArea,
            p.locality,
            p.subLocality,
            p.thoroughfare,
          ].where((s) => s != null && s.isNotEmpty).toList();

          address = parts.join(' ');
          print('✅ [Location] 주소 변환 완료: $address');
        }
      } catch (e) {
        print('⚠️ [Location] 주소 변환 실패 (좌표만 저장): $e');
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
      };
    } on TimeoutException catch (_) {
      print('⚠️ [Location] 위치 획득 시간 초과');
      return null;
    } catch (e) {
      print('❌ [Location] 위치 획득 실패: $e');
      return null;
    }
  }

  /// 트래킹용 이동 거리 스트림 — 직전 위치와의 이동분(m)을 흘려보낸다.
  /// distanceFilter 만큼 움직여야 이벤트가 오므로 배터리 부담이 적다.
  Stream<double> watchDistanceMeters({int distanceFilter = 5}) async* {
    Position? last;
    final stream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilter,
      ),
    );

    await for (final p in stream) {
      if (last != null) {
        final m = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          p.latitude,
          p.longitude,
        );
        // GPS 튐 보정: 너무 작거나(오차) 너무 큰(순간이동) 값은 버림
        if (m >= 3 && m < 200) yield m;
      }
      last = p;
    }
  }

  /// 트래킹용 — 좌표와 이동분을 함께 흘려보낸다.
  ///
  /// watchDistanceMeters 는 거리(m)만 주기 때문에 경로를 그릴 수 없다.
  /// 활동 경로 지도를 그리려면 지나온 좌표가 필요하므로 이 스트림을 쓴다.
  ///
  /// moveMeters 는 직전 지점과의 거리. 첫 지점은 0 이다.
  Stream<TrackPoint> watchTrackPoints({int distanceFilter = 5}) async* {
    Position? last;
    final stream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: distanceFilter,
      ),
    );

    await for (final p in stream) {
      if (last == null) {
        // 첫 지점 — 경로 시작점으로 기록 (이동분 0)
        yield TrackPoint(
          lat: p.latitude,
          lng: p.longitude,
          moveMeters: 0,
          at: DateTime.now(),
        );
        last = p;
        continue;
      }

      final m = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        p.latitude,
        p.longitude,
      );
      // GPS 튐 보정: 너무 작거나(오차) 너무 큰(순간이동) 값은 버림
      if (m >= 3 && m < 200) {
        yield TrackPoint(
          lat: p.latitude,
          lng: p.longitude,
          moveMeters: m,
          at: DateTime.now(),
        );
        last = p; // 유효한 이동일 때만 기준점 갱신
      }
    }
  }
}

/// 트래킹 중 수집하는 경로 한 점
class TrackPoint {
  final double lat;
  final double lng;
  final double moveMeters; // 직전 지점과의 거리(m)
  final DateTime at;

  const TrackPoint({
    required this.lat,
    required this.lng,
    required this.moveMeters,
    required this.at,
  });
}