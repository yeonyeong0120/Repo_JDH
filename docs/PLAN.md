# PLAN.md

본 문서는 AI 플로깅 플랫폼 "Ploggo" 프로젝트의 비전·기능 명세·아키텍처·일정·의사결정 항목을 통합 정리한 단일 참조 문서이다. 원본 문서 `Ploggo_Flutter_개발가이드라인_v4_260524.docx`와 `v2_2026년_한이음_드림업_프로젝트_수행계획서.pdf`, 그리고 `Ploggo_알고리즘테스트_컨텍스트_핸드오프_v1_2_260524.md`를 통합·정리한 것이다.

본 문서가 다루지 않는 영역(코드 작성 규칙, 명명 규칙, Riverpod 사용 규칙 등)은 본 저장소의 `CLAUDE.md`를 참조한다.

---

# 1. 프로젝트 비전 및 핵심 가치

## 1-1. 해결하려는 문제

기존 플로깅 앱은 단순 GPS 트래킹 방식으로, 사용자의 자율적 경로 선택에 의존하여 이미 정비된 공원이나 산책로 위주로 활동이 편중되는 구조적 한계를 지닌다. 본 시스템은 무단투기 단속 CCTV 공공데이터를 분석하여 정화가 시급한 취약 구역을 선별하고, 사용자의 보행 편의성(우회 거리 최소화)과 환경 개선 효과(오염도 가중치)를 수학적으로 모델링한 경로 최적화 알고리즘을 적용하여 플로깅 동선을 안내한다.

본 시스템이 해결하려는 핵심 문제는 다음과 같다.

- **공간적 편중**: 기존 플로깅의 공원·산책로 위주 활동을 무단투기 핫스팟으로 능동적으로 유도한다.
- **인증 피로도**: Vision AI 기반 객관적 인증으로 사용자의 자발적 게시물 작성 부담을 제거한다.
- **행정 사각지대**: 지자체의 인력·예산 한계로 상시 관리가 어려운 위생 사각지대를 시민 참여로 보완한다.
- **보상 부재**: 수거 인증부터 실질적 보상까지 전 과정을 연결하여 지속 참여 동기를 부여한다.

## 1-2. 주요 기능 요약

수행계획서에서 정의된 5개 핵심 기능은 다음과 같다.

| 기능 | 설명 |
|---|---|
| 공공데이터 기반 스마트 경로 추천 | 사용자가 지도에서 목적지를 설정하면, 이동 동선 반경 내 무단투기 빈발 구역(핫스팟) 2~3곳을 자동 탐색한다. 오염도가 심각한 곳을 우선 포함하고 우회 거리를 최소화하는 경로를 안내한다. |
| 플로깅 트래킹 | 실시간 대시보드를 통해 누적 이동 거리·소요 시간·걸음 수·소모 칼로리를 제공한다. 화면이 꺼지거나 앱이 백그라운드 상태여도 위치 추적과 활동량 측정이 중단되지 않는다. |
| Vision AI 기반 수거 인증 | 플로깅 종료 후 카메라로 수거 쓰레기 봉투를 촬영하면, YOLOv8n 기반 비전 AI가 플라스틱·캔·종이 등 쓰레기 종류 및 개수를 자동 식별한다. |
| 환경 영향력 시각화 및 리워드 | 탄소 절감량(소나무 식재 효과 환산) 등 환경적 기여도를 시각화하고, 수거량에 비례한 '에코 포인트'를 친환경 상품·모바일 쿠폰으로 교환할 수 있도록 한다. |
| 커뮤니티 및 환경 뉴스 | 그룹 탭에서 플로깅 결과를 자동 공유하고, Gemini 2.5 Flash 기반 환경 뉴스 3줄 요약 기능을 제공한다. |

## 1-3. 성과목표 및 정량 지표

| 분류 | 세부 성과 목표 | 정량적 지표 |
|---|---|---|
| 서비스 실증 | Google Play Store 앱 출시 및 실사용자 기반 검증 | 2026년 9월 앱 배포 완료, 베타 테스터 50명 이상 확보, 피드백 기반 UI/UX 2차 개선 |
| 기술적 완성도 | 한국 생활폐기물 데이터셋 파인튜닝 모델 최적화 및 안정적인 서비스 품질 확보 | YOLOv8n 객체 인식 정확도 75% 이상, Vision AI API 응답 시간 3초 이내, GeoHash 핫스팟 탐색 응답 시간 1초 이내 |
| 학술적 성과 | LBS 및 Vision AI 융합 연구 성과 발표 및 한이음 공모전 우수 선정 | ICT 분야 학술대회 논문 게재, ICT 한이음 드림업 공모전 출품, 기술적 성과 도출 및 최종 결과보고서 제출 |

## 1-4. 활용 분야

- **B2G**: 지자체 환경 정책 수립을 위한 '구간별 오염도 데이터 맵' 제공. 누적 사용자 이동·수거 데이터로 구간별 오염도 매핑 자료가 자동 생성된다.
- **B2B**: 인천 이음카드 등 지역 화폐와의 에코포인트 연계를 통한 로컬 순환경제 구축.
- **B2B/B2C**: 기업 임직원 ESG 활동 및 청소년 환경 봉사활동에 활용. 1365 자원봉사포털 연계로 봉사시간 자동 인정 가능성.

---

# 2. 시스템 아키텍처

## 2-1. 전체 아키텍처 개요

본 시스템은 모바일 클라이언트(Flutter), AI 추론 서버(FastAPI), BaaS(Firebase), 외부 API(Naver Cloud Platform, Gemini)의 4개 영역으로 구성된다.

```
┌────────────────────────────────────────────────────────────────┐
│                     [ Mobile Client - Flutter ]                │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐   │
│  │ Naver Maps   │  │ Geolocator   │  │ Health Connect      │   │
│  │ SDK          │  │ + Foreground │  │ (걸음수·칼로리)     │   │
│  │ (지도 렌더)  │  │  Service     │  │                     │   │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬──────────┘   │
│         │                 │                     │              │
│  ┌──────┴─────────────────┴─────────────────────┴──────────┐   │
│  │           Riverpod 2.x State Management                 │   │
│  │  (AsyncNotifier 기반 단방향 데이터 흐름)                │   │
│  └────┬──────────────────┬──────────────────┬──────────────┘   │
└───────┼──────────────────┼──────────────────┼──────────────────┘
        │                  │                  │
        │ Auth Token       │ REST (dio)       │ SDK Direct
        │                  │                  │
        ▼                  ▼                  ▼
┌────────────────┐  ┌───────────────────┐  ┌──────────────────┐
│   Firebase     │  │  FastAPI Server   │  │  External APIs   │
│                │  │  (AWS EC2/Docker) │  │  (via FastAPI)   │
│ - Auth         │  │                   │  │                  │
│ - Firestore    │  │ - YOLOv8n(ONNX)   │  │ - Naver Maps     │
│ - Storage      │◀─│ - Naver Proxy     │─▶│   Directions 5   │
│   (이미지)     │  │ - Gemini Proxy    │  │ - Naver Geocode  │
│                │  │ - News Crawler    │  │ - Gemini 2.5 F   │
└────────────────┘  └───────────────────┘  └──────────────────┘
```

## 2-2. Flutter·FastAPI·Firebase 책임 분담

각 시스템 컴포넌트의 책임 영역은 가이드라인 v3에서 옵션 B(메인 채택안) 기준으로 확정되었다.

| 책임 영역 | 메인 채택 (옵션 B) | 향후 검토 (옵션 A) |
|---|---|---|
| 지도 렌더링 (Maps SDK) | Flutter (flutter_naver_map) | 동일 |
| 실시간 GPS 추적 | Flutter (geolocator + Foreground Service) | 동일 |
| 핫스팟 buffer 탐색 | Flutter (Firestore GeoHash 쿼리) | 동일 |
| Waypoint 알고리즘 (K=3) | Flutter (route_notifier) | FastAPI 이관 가능 |
| Naver Directions 5 호출 | FastAPI 프록시 (Client Secret 보호) | 동일 |
| Naver Geocoding 호출 | FastAPI 프록시 | 동일 |
| YOLOv8n 추론 | FastAPI (필수) | 동일 |
| Gemini API 호출 | FastAPI 프록시 (API Key 보호) | 동일 |
| 환경 뉴스 크롤링 | FastAPI (캐시 효율) | 동일 |
| 인증 (Auth) | Firebase Auth | 동일 |
| DB | Firestore | 동일 |
| 이미지 저장 | Firebase Storage (S3 대신 확정) | 동일 |
| 클라우드 호스팅 | AWS EC2 단일 인스턴스 (베타) | 동일 |

**옵션 B 채택 근거:**
- 사용자별 OD(Origin-Destination) 좌표가 매번 달라 서버 캐시 의미가 적다.
- 클라이언트 응답 속도가 사용자 체감에 직접적 영향을 준다.
- Client Secret 보안 이슈는 Directions·Geocoding을 FastAPI 프록시로 분리하여 해소된다.

**옵션 A 전환 조건:**
- 알고리즘 테스트 핸드오프 v1.2의 4번째 알고리즘(후보 C 등)이 채택되어 복잡도가 증가하는 경우.
- 정식 출시 후 한이음 클라우드 활용도가 높아져 서버 책임을 확대할 필요가 있는 경우.

## 2-3. 핵심 데이터 흐름

플로깅 시작부터 AI 인증 및 보상까지의 전체 데이터 흐름은 4단계 선순환 구조로 설계되었다.

```
[1단계: 경로 추천]
User OD 입력
   ↓
Flutter: Geocoding (주소→좌표) - FastAPI 프록시
   ↓
Flutter: Firestore GeoHash Buffer 탐색 → 후보 핫스팟 N개
   ↓
Flutter: route_notifier가 Greedy 알고리즘으로 K=3 핫스팟 선정
   ↓
Flutter: Naver Directions 5 호출 (FastAPI 프록시) → polyline 좌표
   ↓
Flutter: Naver Maps SDK로 polyline 렌더링

[2단계: 트래킹]
사용자 플로깅 시작
   ↓
Foreground Service 시작 (상태바 알림 표시)
   ↓
geolocator GPS 스트림 + Health Connect 걸음수·칼로리
   ↓
Riverpod plogging_notifier로 실시간 대시보드 업데이트
   ↓
경로 GPX 좌표 누적 → 종료 시 Firestore에 저장

[3단계: AI 인증]
image_picker 카메라 촬영
   ↓
Firebase Storage에 putFile() 업로드 → download URL 발급
   ↓
FastAPI에 이미지 URL + plogging_id 전송
   ↓
FastAPI: YOLOv8n 추론 → Firestore에 결과(plastic, can 등 개수) 기록
   ↓
Flutter: Firestore 결과 문서 watch → vision_result_screen 표시

[4단계: 보상 및 데이터 축적]
vision 결과 → reward_notifier로 에코포인트 산출
   ↓
Firestore users/{uid}/eco_points 갱신
   ↓
탄소 절감량 시각화 (소나무 식재 효과 환산)
   ↓
누적 데이터 → 지자체 정책 자료로 활용 가능
```

## 2-4. 인프라 운영 원칙

FastAPI 서버는 개발 착수 시점부터 Docker 이미지로 패키징하며, 상태 비저장(Stateless) 설계를 적용한다.

### Docker 컨테이너화

| 항목 | 적용 시점 | 효과 |
|---|---|---|
| Dockerfile 작성 | 백엔드 개발 착수 | 개발자 PC 간 환경 일관성 |
| Docker 이미지 빌드·실행 | FastAPI MVP 완성 시 | 배포 자동화 토대 |
| 환경 변수 외부화 (.env) | 처음부터 | 개발/스테이징/운영 환경 분리 |
| 상태 비저장 설계 | 처음부터 | 서버 재시작 시 데이터 손실 없음 |

### 영구 데이터 저장 위치 (Stateless 설계)

| 데이터 종류 | 저장 위치 |
|---|---|
| 사용자 인증 정보 | Firebase Auth (외부) |
| 트랜잭션 데이터 | Firestore (외부) |
| 업로드 이미지 | Firebase Storage (외부) |
| YOLOv8n 모델 가중치 | Docker 이미지 내장 (.onnx) |
| 일시적 추론 캐시 | Redis (선택, 향후 검토) |

### K8S 도입 시점

K8S는 다음 조건이 충족되는 시점에 도입한다. 현 단계(베타 50명)는 단일 EC2 + Docker로 충분하므로 K8S를 도입하지 않는다.

- 동시 사용자 1,000명 초과
- 추론 처리량 한계 도달
- 무중단 배포 필요

---

# 3. Feature별 기능 명세

각 feature의 상세 파일 구성 및 화면별 역할을 정리한다. feature 간 의존성 순서에 따라 auth → home → plogging → vision → reward → community → mypage 순으로 개발한다.

## 3-1. auth feature (로그인)

모든 feature가 Firebase 인증 상태에 의존하므로 가장 먼저 개발한다.

| 레이어 | 파일 | 역할 |
|---|---|---|
| data | auth_repository.dart | Firebase Auth Google 로그인 호출 |
| domain | auth_notifier.dart | AsyncNotifier: 로그인·로그아웃 상태 관리 |
| presentation | login_screen.dart | Google 로그인 버튼 UI |

## 3-2. home feature (메인 홈)

로그인 후 진입하는 첫 화면이다. 바텀내비게이션바를 포함한다.

| 레이어 | 파일 | 역할 |
|---|---|---|
| data | home_repository.dart | Firestore 사용자 프로필 및 활동 요약 조회 |
| domain | home_notifier.dart | AsyncNotifier: 홈 화면 데이터 상태 관리 |
| presentation | home_screen.dart | 프로필 카드, 컨텐츠, 바텀내비게이션바 UI |

홈 화면 표시 항목: 사용자 프로필 카드, 주간 활동 통계, 연속 플로깅 일수, 동네 랭킹, 환경 영향력 메뉴 진입점.

## 3-3. plogging feature (경로 추천 + 트래킹)

앱의 핵심 기능이다. GPS, Foreground Service, GeoHash, Waypoint 알고리즘, Naver Maps SDK가 집중된 가장 복잡한 feature다.

| 레이어 | 파일 | 역할 |
|---|---|---|
| data | location_repository.dart | geolocator GPS 스트림, Foreground Service 연동 |
| data | hotspot_repository.dart | Firestore GeoHash 기반 핫스팟 탐색 |
| data | route_repository.dart | FastAPI 프록시로 Naver Directions 5 / Geocoding 호출 |
| domain | plogging_notifier.dart | AsyncNotifier: 트래킹 상태(거리·시간·걸음수) 관리 |
| domain | route_notifier.dart | AsyncNotifier: Waypoint 알고리즘 + 경로 추천 결과 |
| presentation | route_screen.dart | Naver Maps 경로 안내 화면 |
| presentation | tracking_screen.dart | 실시간 트래킹 대시보드 화면 |

**Naver Directions 5 한계 사항:**
- Naver Directions 5는 차량(driving) 경로만 제공한다. 한국에서 도보 길찾기 좌표 API는 사실상 부재한다.
- 차량 polyline을 도보 가이드로 사용하므로 일방통행 우회, 차량 진입 불가 도로 누락, 신호 대기 시간 부정확 등의 한계가 있다.
- 본 프로젝트의 핵심 가치인 '핫스팟 경유' 자체는 polyline 정확도와 무관하므로 베타 단계는 이 한계를 수용한다. 베타 테스트 피드백 후 Tmap·KakaoMobility 도보 API 추가 검토.

**Naver Directions 5 호출 비용 추정:**

| 호출 시점 | 빈도 | 비용 추정 (월) |
|---|---|---|
| 사용자 1회 플로깅 시작 | 1회 | - |
| 베타 50명 × 30일 × 1회/일 | 약 1,500회 | 무료 한도 내 |
| 정식 500명 × 30일 × 1회/일 | 약 15,000회 | 약 5,000~10,000원/월 |

## 3-4. vision feature (AI 수거 인증)

플로깅 종료 후 쓰레기 봉투를 촬영하면 Firebase Storage에 이미지를 저장하고, FastAPI 서버의 YOLOv8n이 해당 이미지를 분석하여 결과를 반환한다.

| 레이어 | 파일 | 역할 |
|---|---|---|
| data | storage_repository.dart | Firebase Storage 이미지 업로드 및 URL 발급 |
| data | vision_repository.dart | dio로 FastAPI에 이미지 URL 전송 및 YOLO 결과 수신 |
| domain | vision_notifier.dart | AsyncNotifier: 촬영→업로드→분석→결과 파이프라인 |
| presentation | camera_screen.dart | image_picker 카메라 촬영 화면 |
| presentation | vision_result_screen.dart | 객체 인식 결과(종류·개수) 출력 화면 |

**처리 흐름:**
1. Flutter: image_picker로 사진 촬영
2. Flutter: Firebase Storage에 putFile() 업로드, download URL 발급
3. Flutter: FastAPI에 이미지 URL과 plogging_id 전달
4. FastAPI: 이미지 URL로 다운로드 → YOLOv8n 추론 → 결과(plastic, can, paper 등 개수)를 Firestore에 기록
5. Flutter: Firestore 결과 문서를 watch하여 vision_result_screen에 표시

Firebase Storage가 Auth 토큰을 직접 검증하므로 별도의 Pre-signed URL 발급 단계가 불필요하다. FastAPI 서버가 준비되기 전까지는 Mock 응답으로 UI 개발을 선행할 수 있다.

## 3-5. reward feature (에코포인트·환경 영향력)

vision feature의 인식 결과를 기반으로 에코포인트를 산출하고 환경 영향력을 시각화한다.

| 레이어 | 파일 | 역할 |
|---|---|---|
| data | reward_repository.dart | Firestore 에코포인트 적립·조회, 상점 쿠폰 연동 |
| domain | reward_notifier.dart | AsyncNotifier: 포인트 계산 및 시각화 데이터 상태 관리 |
| presentation | reward_screen.dart | 탄소 절감량, 에코포인트, 상점 화면 |

**[의사결정 필요]** 에코포인트 산출 공식(수거 쓰레기 종류·개수 → 포인트 환산 기준)을 사전에 확정해야 한다. 이 기준이 없으면 vision_notifier와 reward_notifier 간 데이터 연결이 불가능하다.

## 3-6. community feature (그룹·뉴스)

플로깅 결과를 그룹에 자동 공유하고, Gemini API로 환경 뉴스를 3줄 요약한다. Gemini 호출은 FastAPI 프록시 경유.

| 레이어 | 파일 | 역할 |
|---|---|---|
| data | community_repository.dart | Firestore 그룹 데이터 CRUD |
| data | news_repository.dart | FastAPI 경유: 환경 뉴스 원문 + Gemini 요약 결과 수신 |
| domain | community_notifier.dart | AsyncNotifier: 그룹 피드 상태 관리 |
| domain | news_notifier.dart | AsyncNotifier: 뉴스 요약 상태 관리 |
| presentation | group_screen.dart | 그룹 피드 화면 |
| presentation | news_screen.dart | 환경 뉴스 요약 피드 화면 |

**[의사결정 필요]** 환경 뉴스 원문 데이터 소스를 확정해야 한다. 공개 RSS 피드(환경부 등)를 사용할지, 별도 크롤러 서버를 FastAPI에 포함할지 결정이 필요하다.

## 3-7. mypage feature (마이페이지·설정)

사용자 프로필, 활동 히스토리, 앱 설정을 관리한다.

| 레이어 | 파일 | 역할 |
|---|---|---|
| data | user_repository.dart | Firestore 사용자 정보 조회·수정 |
| domain | user_notifier.dart | AsyncNotifier: 사용자 상태 관리 |
| presentation | mypage_screen.dart | 프로필, 활동 히스토리 화면 |
| presentation | settings_screen.dart | 알림, 로그아웃 등 설정 화면 |

---

# 4. 핵심 알고리즘 결정사항

본 절은 알고리즘 테스트 핸드오프 v1.2(2026-05-24)의 1차 검증 결과를 기반으로 정리한다. 인천 9개 군구 1,535곳 핫스팟 실데이터에 대해 27회 테스트(9 OD × 3 알고리즘)를 수행한 결과다.

## 4-1. Waypoint 알고리즘: Greedy 채택

1차 검증 결과 Greedy 알고리즘이 정답률·실행시간·비용 측면에서 모두 우수하여 채택되었다.

| 알고리즘 | 평균 Score | 평균 정답률 | 평균 실행시간 | 평균 우회 | 평균 MPD |
|---|---|---|---|---|---|
| BruteForce | 5.178 | 100.00% | 794.90 ms | 1.032 km | 0.787 km |
| **Greedy** | **5.105** | **98.14%** | **7.90 ms** | **1.123 km** | **1.147 km** |
| Clustering | 3.957 | 75.44% | 23.55 ms | 1.585 km | 1.799 km |

검증 PDF(가상 25곳)와의 정합성: Greedy 정답률 99.7% → 98.14% (-1.56%p), 사실상 정합. 60배 스케일에서도 Greedy 채택 결정이 유효함을 확인.

## 4-2. S_i 공식 (D2-2)

핫스팟 i의 오염도 점수 공식은 D2-2를 채택한다.

```
S_i = cctv_count + 0.5 × neighbor_200m
```

- **변별력**: 표준편차 1.75 (충분)
- **이웃 보유 비율**: 76.7% (1,535곳 중 1,178곳)
- **정규화**: 1차 미적용

군구별 S_i 편향 주의: 연수구는 다중 카메라 60.3%와 청학동 핫스팟 밀집(neighbor_200m 16~17)으로 다른 군구 대비 평균 4배, 최댓값 5배의 S_i를 보인다. 결과 해석 시 연수구 OD의 Score가 과대평가될 수 있음을 고려해야 한다.

## 4-3. Score 공식 및 가중치

플로깅 경로의 종합 점수 공식은 다음과 같다.

```
Score = α × ΣS_i − β × 우회거리
      = 0.5 × ΣS_i − 0.5 × 우회거리
```

- **α (오염도 가중치)**: 0.5
- **β (거리 패널티 가중치)**: 0.5
- **K (경유 핫스팟 수)**: 3 (후보 부족 시 K=2 fallback)
- **거리 계산**: Haversine × 1.3 (보정계수, ±15% 오차 허용)

## 4-4. Buffer Zone 정책

| 군구 | Buffer 반경 |
|---|---|
| 강화군 | 2.5 km |
| 그 외 8개 군구 | 1.5 km |

- **Buffer 모양**: 타원/회랑형 (`dist(O,h) + dist(h,D) − dist(O,D) < R × 1.5`)
- **이유**: 긴 OD에서도 라인상 후보 포함 가능

## 4-5. 4번째 알고리즘 후보 (잔여 검토 항목)

1차 검증에서 9 OD 중 7개는 100% 정답률, 2개(junggu, namdong)는 미흡 패턴을 보였다.

| 미흡 패턴 | 미흡 사유 | 해당 OD | 시사점 |
|---|---|---|---|
| 패턴 A: 우회 손실 | ΣS는 동일하나 Greedy가 더 먼 핫스팟을 골라 우회 거리 손해 | junggu | Greedy가 *개별 D_i* 기준으로 선택하나 *경로 전체* 우회는 고려 못함 |
| 패턴 B: ΣS 손실 | 우회 거리는 동일하나 BF가 더 높은 ΣS 조합 발견 | namdong | Greedy가 *Top-3 S_i*에 갇혀 더 나은 *조합*을 놓침 |

**4번째 알고리즘 후보:**

| 후보 | 공식·구조 | 보완 대상 |
|---|---|---|
| 후보 A | 경로 전체 우회 페널티 강화 (Greedy 선정 후 경로 전체 우회 거리 재계산, 임계값 초과 시 swap) | 패턴 A (junggu) |
| 후보 B | K개 조합 부분 탐색 (Top-N에서 Greedy K개 선정 후 조합 swap 시도) | 패턴 B (namdong) |
| **후보 C** | **A·B 결합 (우회 페널티 + 조합 swap)** | **두 패턴 모두 (1순위 권고)** |
| 후보 D | OD 라인 인접 보너스 (`-δ × perp_dist(핫스팟, OD 라인)`) | 패턴 A (간접 보완) |

핸드오프 8-3절 권고: 후보 C(A+B 결합)가 두 미흡 패턴을 모두 보완하는 방향이다. 계산 비용은 Greedy + O(K × Top-N) 수준으로 BruteForce(2,730 조합) 대비 훨씬 낮다.

**도입 시점:** 베타 테스트 사용자 피드백 후 재검토.

## 4-6. 테스트 시나리오: OD 9쌍 (확정)

| 군구 | Origin | Destination | 직선거리 | 도보 예상 | Buffer | 후보 수 |
|---|---|---|---|---|---|---|
| ganghwa | 강화군청 | 갑곶돈대 | 7.16 km | 139분 | 2.5 km | 27곳 |
| junggu | 신포로27번길 80 | 월미공원 | 1.64 km | 31분 | 1.5 km | 28곳 |
| donggu | 우각로 75 | 만석부두 | 2.60 km | 50분 | 1.5 km | 46곳 |
| michuhol | 인주대로 530 | 문학경기장 | 1.72 km | 33분 | 1.5 km | 45곳 |
| seogu | 서구청 | 가좌역 | 2.43 km | 47분 | 1.5 km | 61곳 |
| yeonsu | 연수구청 | 청량산 | 3.33 km | 64분 | 1.5 km | 67곳 |
| namdong | 남동구청 | 인천종합문화예술회관 | 2.77 km | 54분 | 1.5 km | 73곳 |
| bupyeong | 부평구청 | 백운공원 | 3.23 km | 62분 | 1.5 km | 23곳 |
| gyeyang | 계양구청 | 작전역 | 1.56 km | 30분 | 1.5 km | 110곳 |

---

# 5. 개발 로드맵

## 5-1. 단계별 STEP

가이드라인 v4의 STEP 1~9 기준이다. 각 STEP은 순차 진행하며, 미완료 상태에서 다음 단계로 진행 시 빌드 오류 또는 런타임 오류가 발생할 수 있다.

| STEP | 내용 | 상태 |
|---|---|---|
| STEP 1 | pubspec.yaml 패키지 구성 (flutter_naver_map 추가, firebase_storage 추가, google_maps_flutter 제거) | ⬜ |
| STEP 2 | 폴더 구조 재편 (Feature-First 3-Layer) | ✅ |
| STEP 3 | android/app/build.gradle.kts 설정 (applicationId: com.ploggo.app, minSdk 26, targetSdk 36) | ⬜ |
| STEP 4 | AndroidManifest.xml 권한 및 Naver Maps Client ID meta-data 등록 | ⬜ |
| STEP 5 | Firebase 프로젝트 연결 (google-services.json) | ⬜ |
| STEP 5.5 | Naver Cloud Platform Application 등록 | ⬜ |
| STEP 6 | .env 파일 작성 | ⬜ |
| STEP 7 | main.dart 기본 골격 (dotenv → Firebase → FlutterNaverMap init → ProviderScope) | ⬜ |
| STEP 8 | core/router/ 라우터 작성 (go_router 기반) | ⬜ |
| STEP 9 | feature별 개발 (auth → home → plogging → vision → reward → community → mypage) | ⬜ |

## 5-2. 월별 일정 (수행계획서 기준)

| 단계 | 추진 내용 | 월 |
|---|---|---|
| 계획 및 분석 | 요구사항 정의, 공공데이터 확보, CCTV 매핑·GeoHash 설계 | 4월 |
| 설계 | UI/UX 프로토타입(Figma), Firebase DB 구조 및 AI 서버 아키텍처 설계 | 4월~5월 |
| 개발 | Flutter UI 및 Firebase 로그인 연동 | 5월~6월 |
| 개발 | Naver Maps SDK 연동 및 Waypoint 알고리즘 구현 | 6월~7월 |
| 개발 | 한국 생활폐기물 데이터셋 파인튜닝 및 FastAPI 서버 구축 | 6월~7월 |
| 개발 | Health Connect·Foreground Service 트래킹 구현 | 7월 |
| 개발 | 커뮤니티, 에코 포인트, LLM 뉴스 요약 구현 | 7월~8월 |
| 테스트 | 앱-서버 통합 테스트 및 디버깅 | 8월 |
| 테스트 | 교내 베타 테스트 및 피드백 수집·반영 | 8월~9월 |
| 종료 | Google Play Store 심사 및 배포 | 9월 |
| 종료 | UI/UX 2차 개선 및 성능 최적화 | 9월~10월 |
| 종료 | 최종 결과보고서 작성 및 공모전 준비 | 10월 |

## 5-3. 현재 진척 상태

- ✅ 데이터 정제 완료 (9개 군구 1,535곳 통합 데이터셋)
- ✅ 알고리즘 테스트 1차 완료 (27회 실행, Greedy 채택 결정)
- ✅ Flutter 프로젝트 골격 생성 (lib/ 폴더 Feature-First 3-Layer 구조)
- ⬜ pubspec.yaml에 flutter_naver_map 추가 필요
- ⬜ applicationId 변경 필요 (`com.example.repo_jdh` → `com.ploggo.app`)
- ⬜ Firebase 프로젝트 연결 (google-services.json) 필요
- ⬜ NCP Application 등록 필요
- ⬜ .env 파일 작성 필요
- ⬜ feature별 본격 개발 미착수

## 5-4. 팀 운영 원칙

| 항목 | 내용 |
|---|---|
| 팀 구성 | 멘티 4명 + ICT 전문가 멘토 1명 + 지도교수 1명 |
| 역할 분담 | Flutter 앱 개발 2명, AI 서버 개발 1명, 백엔드·DB 설계 1명 |
| 멘토링 | 월 1회 정기 멘토링(오프라인) + 상시 멘토링(온라인) |
| 미팅 | 주 1회 이상 오프라인 팀 미팅 |
| 문서 관리 | Notion (회의록, 요구사항 명세서, API 문서) |
| 코드 관리 | GitHub Issues + Pull Request, GitHub Flow 전략, 격일 1커밋 지향 |
| 회고 | 매주 짧은 스프린트 회고 |

---

# 6. 의사결정 항목 추적

## 6-1. 해소된 항목 (참고)

가이드라인 v4 시점까지 해소된 의사결정 항목이다.

| # | 항목 | 결정 내용 |
|---|---|---|
| #1 | Firebase 프로젝트명 및 패키지명(applicationId) | com.ploggo.app |
| #2 | Google Maps API Key 발급 | NCP Application 등록으로 대체 (Naver Maps + Directions 5 + Geocoding) |
| #5 | Waypoint 알고리즘 처리 위치 | Flutter 클라이언트 메인 (옵션 B), FastAPI 이관은 향후 검토 |
| #8 | Flutter Naver Maps 패키지 | flutter_naver_map 1.3.1 |
| #9 | Naver Directions 5 호출 위치 | FastAPI 프록시 (Client Secret 보안) |
| #10 | Geocoding API 선택 | Naver Geocoding |
| #11 | NCP Application 개수 | 베타 1개, 정식 2개 분리 |
| #12 | 도보 vs 차량 polyline | 차량 polyline 사용 (한계 명시) |
| #13 | 알고리즘 채택 | Greedy (1차 검증 정답률 98.14%) |
| #14 | S_i 공식 | D2-2 (cctv_count + 0.5 × neighbor_200m) |
| #15 | α·β 가중치 | 0.5 / 0.5 (베타 테스트 후 재검토) |
| #16 | K 경유 수 | 3 (fallback 2) |
| #17 | 거리 계산 방식 | Haversine × 1.3 (옵션 B) |
| #18 | Buffer Zone 정책 | 강화 2.5km / 그 외 1.5km, 타원형 |
| #19 | GT 평가 방식 | Brute Force Score 기반 |
| #20 | 클라우드 호스팅 | AWS EC2 (Naver Cloud 미선택) |
| #21 | 이미지 저장소 | Firebase Storage (S3 미선택) |
| #22 | Docker 패키징 | 백엔드 개발 착수 시점부터 적용 |
| #23 | K8S 도입 시점 | 정식 출시 후 확장기에 재검토 |

## 6-2. 잔여 의사결정 항목

| # | 항목 | 관련 STEP | 진행 방향 |
|---|---|---|---|
| #3 | 바텀내비게이션바 플로깅 버튼 동작 방식 (탭 전환 vs 화면 push) | STEP 8 | 미정 |
| #4 | 바텀내비게이션바 위젯 위치 (home 내부 vs core/widgets/) | 3-2 | home 내부 유지 권장 |
| #6 | 에코포인트 산출 공식 (쓰레기 종류·개수 → 포인트 환산 기준) | 3-5 | reward feature 개발 전 확정 필요 |
| #7 | 환경 뉴스 데이터 소스 (공개 RSS vs FastAPI 크롤러) | 3-6 | community feature 개발 전 확정 필요 |
| #24 | EC2 인스턴스 사양 (vCPU, RAM) | 백엔드 개발 착수 시 | 미정 |
| #25 | 4번째 알고리즘 도입 여부 | 베타 테스트 사용자 피드백 후 | 후보 C (A+B 결합) 1순위 권고 |
| #26 | α·β 최종값 조정 | 베타 테스트 후 | 현재 0.5/0.5 유지 |
| #27 | 사용자 방문 이력 기반 S_i 감쇠 메커니즘 | Firestore visit_history 컬렉션 설계 시 | 미정 |

---

# 7. 외부 의존성 및 환경 변수

## 7-1. Firebase 프로젝트 설정

| 항목 | 내용 |
|---|---|
| 프로젝트 등록 | Firebase 콘솔(https://console.firebase.google.com)에서 새 프로젝트 생성 |
| Android 패키지명 | com.ploggo.app |
| 자격증명 파일 | google-services.json (android/app/ 폴더에 저장) |
| 활성화 서비스 | Authentication (Google 로그인), Cloud Firestore (테스트 모드), Cloud Storage |
| Git 추적 | google-services.json은 .gitignore에 추가하여 추적 제외 |

## 7-2. Naver Cloud Platform 설정

| 항목 | 내용 |
|---|---|
| 콘솔 경로 | NCP 콘솔 > AI·Application Service > AI·NAVER API > Application |
| Application 이름 | ploggo-beta (예시) |
| 활성화 서비스 | Maps (Mobile Dynamic Map), Directions 5, Geocoding |
| Android 패키지명 등록 | com.ploggo.app |
| 발급 자격증명 | Client ID, Client Secret |
| 베타 구성 | 단일 Application |
| 정식 구성 | 보안 분리를 위해 2개 Application 분할 |

**자격증명 보관 위치:**

| 자격증명 | 보관 위치 | 용도 |
|---|---|---|
| Client ID | Flutter .env + AndroidManifest meta-data | Maps SDK 지도 렌더링 |
| Client ID | FastAPI .env | Directions 5 + Geocoding 호출 헤더 |
| Client Secret | FastAPI .env에만 | Directions 5 + Geocoding 호출 헤더 |
| Client ID·Secret | Colab 알고리즘 테스트 노트북 (보안 비밀) | 알고리즘 시각화 단계 polyline 추출 |

Maps SDK Client ID는 앱 패키지명으로 제한되어 다른 패키지에서 도용해도 인증 실패한다. 따라서 앱 빌드에 포함되어도 보안상 문제 없다. 반면 Client Secret(Directions·Geocoding용)은 FastAPI에만 보관한다.

## 7-3. .env 파일 구성

### Flutter .env (앱에 포함)

| 키 | 설명 |
|---|---|
| NAVER_MAPS_CLIENT_ID | Naver Maps SDK 지도 렌더링용 Client ID |
| FASTAPI_BASE_URL | YOLO 추론 및 Naver API 프록시 서버 주소 (개발: localhost, 운영: 클라우드 URL) |

### FastAPI .env (서버에만 보관)

| 키 | 설명 |
|---|---|
| NAVER_MAPS_CLIENT_ID | Directions 5·Geocoding 호출 헤더 (Flutter와 동일 값) |
| NAVER_MAPS_CLIENT_SECRET | Directions 5·Geocoding 호출 헤더 (FastAPI에만 보관) |
| GEMINI_API_KEY | Gemini 2.5 Flash 뉴스 요약 API Key |

### Git 관리 원칙

- `.env`는 `.gitignore`에 등록하여 추적 제외한다.
- `.env.example` 파일에 키 이름만 기재하고 값은 비워둔 상태로 GitHub에 올린다.
- 실제 값은 팀원 간 별도 채널(Notion 보안 페이지 등)로 공유한다.

## 7-4. Android 권한 요구사항

| 권한 | 대상 기능 |
|---|---|
| ACCESS_FINE_LOCATION | 실시간 GPS 위치 추적 |
| ACCESS_COARSE_LOCATION | 네트워크 기반 위치 보조 |
| FOREGROUND_SERVICE | 화면 Off 상태 백그라운드 GPS 유지 |
| FOREGROUND_SERVICE_LOCATION | Foreground Service 위치 유형 명시 (Android 14+) |
| CAMERA | 쓰레기 봉투 촬영 |
| ACTIVITY_RECOGNITION | 걸음수 인식 (Health Connect 필수) |
| INTERNET | FastAPI·Firebase·Naver API 통신 |
| health 관련 READ 권한 | Health Connect 걸음수·칼로리 데이터 접근 |

## 7-5. 필요 기자재 및 외부 계정

| 품목 | 활용 계획 |
|---|---|
| 테스트용 Android 스마트폰 | 백그라운드 GPS 위치 추적 및 실시간 경로 렌더링 성능 테스트, Health Connect API 정확도 및 배터리 최적화 검증, 카메라 UI/UX 및 이미지 해상도 테스트 |
| 클라우드 서버 인프라 | YOLOv8n ONNX 모델 추론 및 FastAPI 서버 운영을 위한 AWS EC2 구축, 무단투기 CCTV 공공데이터 사전 적재 및 Firebase DB 연동 테스트 환경 |
| Google Play Store 개발자 계정 | 앱 배포 |
| Naver Cloud Platform 계정 | Maps·Directions 5·Geocoding API 호출 비용 확보 |
| Gemini API 계정 | 환경 뉴스 요약 API 호출 비용 확보 |

---

작성: 2026-05-24
버전: 1.0
원본 문서: Ploggo_Flutter_개발가이드라인_v4_260524.docx, v2_2026년_한이음_드림업_프로젝트_수행계획서.pdf, Ploggo_알고리즘테스트_컨텍스트_핸드오프_v1_2_260524.md
