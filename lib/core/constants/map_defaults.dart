/// 지도 기본값 (앱 전역 단일 소스).
///
/// GPS 첫 좌표가 오기 전 잠깐 보여줄 카메라 위치다. 경로 설정 화면과 플로깅
/// 화면이 각자 같은 리터럴을 복사해 갖고 있어 한쪽만 고치면 어긋난다.
/// 좌표는 순수 Dart 타입으로 둔다 — NLatLng 변환은 presentation 에서 한다.
class MapDefaults {
  MapDefaults._();

  /// GPS 획득 전 기본 카메라 위치 (인천 부평구청 부근).
  static const double fallbackLat = 37.5074;
  static const double fallbackLng = 126.7218;
}
