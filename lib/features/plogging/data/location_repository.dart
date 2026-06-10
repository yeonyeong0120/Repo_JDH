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
}