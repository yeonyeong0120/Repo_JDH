# TODO (미룬 작업)

- (가) 정식 출시 시 '경로 추천 성공 시에만 플로깅 시작 가능'으로 활성화 조건 조이기 (현재는 도착지 설정 시 활성화).
- (나) 도착지 자동 추천에 디바운스 적용 (짧은 시간 연속 탭 시 요청 몰림 방지).
- (다) 추적 화면(PloggingHomeScreen)의 정적 지도 이미지를 실제 NaverMap + 경로 오버레이로 교체 (currentLocation/destination/routeNotifier provider 공유 watch).
- (라) GeoDistance 에 project() 추가하고 _distToSegment 가 그 위에서 선분 투영만 하도록 리팩터링 — 평면 근사 수식 중복 제거. 항법 코드(경로 이탈 → 자동 재추천)라 실기기 검증(100m 이탈 후 30초 대기) 필요. 방금 추가한 포인트 지급 기능 검증과 겹치면 문제 발생 시 원인 구분이 어려워 뒤로 미룸.
- (마) 하단 인셋 계산 22곳을 공용 헬퍼로 통일 (bottomSafePad 등). 현재 +92/+96/+64/+30 이 섞여 있음. 값 보존하며 이관 필요, 레이아웃 회귀 검증 범위 큼.
  - 셸 안(extendBody)은 `MediaQueryData.fromView(View.of(context)).padding.bottom`, 셸 밖은 `MediaQuery.of(context).padding.bottom` 으로 읽어야 해서 헬퍼를 두 개로 나눠야 한다. 이 구분이 현재 group_screen.dart 주석 한 곳에만 기록되어 있다.
  - 베이스 상수 12종(14/16/24/30/32/34/64/92/96/100/120/Gap.md)이 흩어져 있고, 92·96·100·120 은 목적이 같은데 값만 갈라진 것으로 보인다.
  - 헬퍼만 만들고 쓰지 않으면 죽은 코드가 되므로 이관과 함께 진행한다.
