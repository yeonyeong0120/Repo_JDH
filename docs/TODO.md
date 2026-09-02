# TODO (미룬 작업)

- (가) 정식 출시 시 '경로 추천 성공 시에만 플로깅 시작 가능'으로 활성화 조건 조이기 (현재는 도착지 설정 시 활성화).
- (나) 도착지 자동 추천에 디바운스 적용 (짧은 시간 연속 탭 시 요청 몰림 방지).
- (다) 추적 화면(PloggingHomeScreen)의 정적 지도 이미지를 실제 NaverMap + 경로 오버레이로 교체 (currentLocation/destination/routeNotifier provider 공유 watch).
- (라) GeoDistance 에 project() 추가하고 _distToSegment 가 그 위에서 선분 투영만 하도록 리팩터링 — 평면 근사 수식 중복 제거. 항법 코드(경로 이탈 → 자동 재추천)라 실기기 검증(100m 이탈 후 30초 대기) 필요. 방금 추가한 포인트 지급 기능 검증과 겹치면 문제 발생 시 원인 구분이 어려워 뒤로 미룸.
