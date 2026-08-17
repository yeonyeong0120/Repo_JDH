<!-- 원본: Ploggo_Flutter_개발가이드라인_v8_260708.docx
     변환: 서식(헤딩/코드펜스/리스트)만 정리. 본문 문구는 원문 그대로 유지.
     서식 정정 1건: "STEP 9. feature별 개발" 헤딩이 원본에서 H1이었으나
     STEP 1~8과 동일한 H2로 조정함 (계층 오류 교정, 내용 변경 없음). -->

# Ploggo Flutter 개발 전체 가이드라인 v8

AI 플로깅 플랫폼 (Ploggo) | 2026 한이음 드림업 프로젝트

작성일: 2026. 07. 08. (바텀내비 위치 코드 정합 반영)

# 0. 문서 목적 및 표기 규칙

본 문서는 AI 플로깅 플랫폼(Ploggo) Flutter 프로젝트의 개발 착수 시점부터 배포까지 전 과정을 단계별로 기술한 가이드라인이다. 팀원 전원이 동일한 기준으로 개발을 진행할 수 있도록 아키텍처, 기술 스택, 코딩 규칙, 단계별 작업 항목을 명시한다.

v3는 v2 대비 다음을 반영한다. (1) 지도·경로 API를 Google에서 Naver로 통합, (2) 알고리즘 테스트 1차 결과 기반 Waypoint 알고리즘 처리 위치 확정, (3) 패키지명 com.ploggo.app 확정, (4) Firebase Storage 기반 이미지 처리 흐름 보강, (5) Flutter·FastAPI·Firebase 책임 분담 명확화.

v4는 v3 대비 다음을 반영한다. (1) 알고리즘 1차 검증 결과 반영, (2) 백엔드 인프라 결정 추가 (AWS EC2, Docker, K8S 도입 시점), (3) GT 평가 방식 명시, (4) 인프라 운영 원칙 신규 절 추가 (1-4).

v5는 v4 대비 다음을 반영한다. (1) 도보 경로 API를 Naver Directions 5에서 Tmap Pedestrian API로 전환, (2) Naver Maps SDK는 지도 렌더링 용도로 유지, (3) STEP 5.6 신설, (4) #12 도보 polyline 결정 항목 해소.

v6는 v5 대비 서버 코드 분석 결과와 팀 논의로 확정된 사항을 반영한다. (1) 경로 알고리즘 처리 위치를 Flutter에서 FastAPI 서버로 전량 이관 (서버 이식 완료 확인), (2) 서버는 연산만 담당하고 Firebase 접근은 앱이 전담함을 확정, (3) 이미지 처리 흐름을 서버 직접 수신 방식으로 확정 (Firebase Storage는 향후 검토), (4) 서버 API 계약(엔드포인트·스키마) 신규 명시, (5) 목적지 입력을 지도 마커 좌표 획득으로 확정하여 지오코딩 제거, (6) 개발 환경 셋업(SHA-1) 신규 추가, (7) GeoHash 표기를 실제 구현(타원 buffer + numpy 전수 계산)에 맞게 정정.

v7은 v6 대비 문서 정합성 검수 결과를 반영한다. (1) 바텀내비게이션바 위젯 위치를 core/widgets/로 확정하여 #4 중복 모순 해소, (2) Gemini 뉴스 요약을 현재 미구현·향후 상태로 표기하여 다른 미구현 항목과 일관화, (3) ALGO_HARD_CASE_M을 정의됨·코드 미참조 상태로 표기, (4) 설정 화면 구조 불일치를 known issue 노트로 명시 (구조 정정은 개발 단계 처리).

v8은 v7 대비 바텀내비게이션바의 실제 코드 위치를 정합화한다. 코드 확인 결과 바텀내비는 core/widgets/가 아니라 go_router의 ShellRoute 셸(core/router/app_router.dart의 _ScaffoldWithBottomNav)이 담당하며, 각 화면은 본문(body)만 채운다. v7이 목표로 삼은 core/widgets/ 서술과 관련 세 곳(9-2 결정 노트, 1-2 폴더 표의 home 행, 9-2 home_screen 행)의 불일치를 실제 구현 기준으로 정정한다. 코드는 변경하지 않는다.

| **표기** |** 의미** |
| --- | --- |
| ▶ [의사결정 필요] | 팀 내 합의가 필요한 사항. 개발 진행 전 반드시 결정해야 한다. |
| ※ | 주의사항 또는 참고 사항 |
| ✅ | 완료된 항목 |
| ⬜ | 미완료 항목 |
| 🔁 / 🆕 | v2 → v3 갱신 / v3 신규 |
| 🔁📈 / 🆕📈 | v3 → v4 갱신 / 신규 |
| 🔁🎯 / 🆕🎯 | v4 → v5 갱신 / 신규 (Tmap 전환) |
| 🔁🖥 / 🆕🖥 | v5 → v6 갱신 / 신규 (서버 아키텍처 확정) |
| 🔁📄 / 🆕📄 | v6 → v7 갱신 / 신규 (문서 정합성 검수) |
| 🔁🧭 / 🆕🧭 | v7 → v8 갱신 / 신규 (바텀내비 코드 정합) |

# 1. 프로젝트 개요

## 1-1. 기술 스택 요약  🔁🖥

v6에서 경로 알고리즘 처리 위치가 Flutter에서 FastAPI 서버로 이관되었다. 서버 코드에 후보 필터·Score 산정·회피 페널티·Safe Swap·Tmap 호출·polyline 교차 검사가 모두 이식 완료되었음을 확인하였다. Flutter는 서버에 요청을 보내고 결과를 수신·시각화하는 역할만 담당한다.

| **구분** |** 기술** |** 역할** |** v3~v6** |
| --- | --- | --- | --- |
| 프론트엔드 | Flutter 3.41.5 + Dart 3.11.3 | Android 우선 크로스플랫폼 앱 |  |
| 상태 관리 | Riverpod 2.x + AsyncNotifier | 비동기 상태 관리 및 단방향 데이터 흐름 |  |
| 라우팅 | go_router 15.x | 선언적 화면 전환 및 딥링크 |  |
| 인증·DB | Firebase Auth + Cloud Firestore | 소셜 로그인, NoSQL 실시간 DB (앱이 직접 접근) | 🔁🖥 |
| 이미지 처리 | 앱 → 서버 직접 전송 (multipart) | 수거 인증 이미지를 서버에 직접 전송 (Firebase Storage는 향후 검토) | 🔁🖥 |
| 지도 렌더링 | flutter_naver_map 1.3.1 | Naver Maps SDK 한국 지도 표시 | 🔁 |
| 위치 추적 | geolocator | 실시간 GPS 추적 |  |
| 경로 알고리즘 | FastAPI 서버 (route_recommender) | 후보 필터·Score·회피 페널티·Safe Swap·Tmap 호출·교차 검사 전량 서버 처리 | 🔁🖥 |
| 도보 경로 API | Tmap Pedestrian API (서버 내부 호출) | 보행자 도보 경로 polyline 좌표 (서버가 호출) | 🔁🎯 |
| 목적지 입력 | 지도 마커 좌표 획득 | 주소 검색 아닌 마커 이동으로 위경도 직접 획득 (지오코딩 불필요) | 🆕🖥 |
| 공간 탐색 | 타원 buffer + numpy 전수 계산 | 출발지·목적지 두 초점 타원 필터 (GeoHash 인덱스 미사용) | 🔁🖥 |
| 헬스 데이터 | health 13.x (Health Connect) | 저전력 걸음수·칼로리 측정 |  |
| 백그라운드 | flutter_foreground_task 8.x | 화면 Off 상태 GPS 연속 추적 |  |
| AI 통신 | dio 5.x → FastAPI 서버 | YOLO 추론 요청 + 경로 추천 요청 | 🔁🖥 |
| LLM | Gemini 2.5 Flash (FastAPI 경유) | 환경 뉴스 3줄 요약 (현재 미구현, 향후: 서버에 키만 존재) | 🔁📄 |
| 환경변수 | flutter_dotenv 5.x | FASTAPI_BASE_URL 등 관리 (하드코딩 금지) | 🔁🖥 |
| 폰트 | Noto Sans KR | 한국어·영어 통일 서체 |  |
| 백엔드 AI | Python FastAPI + YOLOv8n (ONNX) | AI 추론 + 경로 알고리즘 서버 |  |
| 백엔드 인프라 | AWS EC2 (Ubuntu, 포트 8000) | FastAPI 서빙 (별도 저장소 ploggo-server) | 🔁🖥 |
| 컨테이너화 | Docker (미구현, 예정) | Dockerfile·compose 현재 부재 확인 | 🔁🖥 |
| 오케스트레이션 | Kubernetes (K8S) | 향후 확장 시 도입 (현재 보류) | 🆕📈 |

## 1-2. 폴더 구조

본 프로젝트는 Feature-First 3-Layer 아키텍처를 채택한다. 각 feature는 presentation(화면), domain(비즈니스 로직·Provider), data(외부 데이터 접근) 세 레이어로 구성되며, 의존성은 presentation → domain → data 단방향만 허용된다.

| **경로** |** 역할** |
| --- | --- |
| lib/main.dart | 앱 진입점. Firebase·dotenv·FlutterNaverMap 초기화, ProviderScope 선언 |
| lib/core/theme/ | 앱 전체 테마, 색상(app_colors.dart), 폰트(app_theme.dart) |
| lib/core/router/ | go_router 전체 라우팅 + ShellRoute 셸(_ScaffoldWithBottomNav)이 공통 바텀내비 담당 |
| lib/core/providers/ | Firebase 인스턴스, Dio(FastAPI 클라이언트) 등 전역 Provider |
| lib/core/widgets/ | 여러 feature 공용 위젯 (현재 비어 있음, 향후 추출용) |
| lib/features/auth/ | 로그인·회원가입 feature |
| lib/features/home/ | 메인 홈 화면 (본문만, 바텀내비는 셸이 담당) |
| lib/features/plogging/ | 경로 추천(서버 요청), 실시간 트래킹 feature |
| lib/features/vision/ | 카메라 촬영, 서버 전송, AI 수거 인증 feature |
| lib/features/reward/ | 에코포인트, 환경 영향력 시각화 feature |
| lib/features/community/ | 그룹, LLM 뉴스 요약 feature |
| lib/features/mypage/ | 마이페이지 feature (활동 히스토리 등) |
| lib/features/settings/ | 설정 화면 feature (아래 known issue 참조) |
| assets/fonts/ | NotoSansKR 폰트 파일 |
| assets/images/ | 앱 내 이미지 리소스 |
| .env | FASTAPI_BASE_URL, NAVER_MAPS_CLIENT_ID 관리 (Git 비추적) |

🔁🧭 v8: 바텀내비게이션바는 go_router의 ShellRoute 셸(core/router/app_router.dart의 private 위젯 _ScaffoldWithBottomNav)이 담당한다. 셸이 각 화면(child)을 감싸 공통 바를 한 번만 그리며, 4개 탭 화면(/home, /group, /mypage, /settings)의 본문은 셸 아래에서 body만 채운다. 표준 BottomNavigationBar가 아니라 Stack + Container + CustomPaint로 만든 커스텀 바(중앙 돌출 시작 버튼 포함)다.

※ 배치 근거: 바텀내비는 여러 feature를 가로지르는 공용 셸 UI이므로 특정 feature가 아닌 라우터(core/router)가 관리하는 것이 원칙에 부합한다. 현재 탭이 4개로 라우터 인라인 정의로 충분하며, 향후 재사용·복잡도가 커지면 core/widgets/로 위젯을 추출한다.

※ 참고: v7에서 목표로 삼았던 core/widgets/ 배치는 실제 코드에 존재하지 않는다. 코드는 이미 ShellRoute 셸로 올바르게 분리되어 있어, v8은 코드를 변경하지 않고 문서를 실제 구현에 맞춘다.

※ known issue (설정 화면 구조): 설정 화면은 현재 코드에서 별도 settings feature 폴더의 menu_screen.dart(클래스 MenuScreen)로 구현되어 있으며 라우터에 정상 연결되어 동작한다. 다만 (1) 파일명이 명명 규칙 {기능}_screen.dart와 달리 menu_screen.dart이고, (2) 본 가이드라인의 초기 목표 구조(mypage 하위 settings_screen.dart)와 위치가 다르다. 폴더 위치·파일명 정합은 개발 단계에서 정리하며, v8에서는 구조를 변경하지 않는다.

## 1-3. 앱·서버·Firebase 책임 분담  🔁🖥

v6에서 책임 분담이 서버 코드 분석으로 확정되었다. 서버는 연산(경로 알고리즘·YOLO 추론)만 담당하며, Firebase 접근은 앱이 전담한다. 서버 코드에 firebase-admin이 없고 Firebase 참조가 전무함을 확인하였다.

| **책임 영역** |** 담당 주체** |** 비고** |
| --- | --- | --- |
| 인증 (소셜 로그인) | 앱 → Firebase Auth | 서버 미관여 |
| 유저 프로필·활동 기록·커뮤니티·리워드 | 앱 → Cloud Firestore | 앱이 직접 읽고 씀. 서버 미관여 |
| 수거 인증 이미지 저장 | 앱 → 서버 직접 전송 (현재) | 3장 참조 |
| 경로 추천 알고리즘 | 서버 (FastAPI) | Flutter는 요청·수신만 |
| YOLO 객체 인식 | 서버 (FastAPI) | Flutter는 이미지 전송·결과 수신 |
| 지도 렌더링 | 앱 → Naver Maps SDK |  |
| GPS·걸음·칼로리 트래킹 | 앱 → Foreground Service·Health Connect |  |

※ v5까지는 Waypoint 알고리즘을 Flutter route_notifier에서 수행하는 옵션 B를 메인으로 규정하였으나, v6에서 서버 이식 완료가 확인되어 알고리즘 연산 전량을 FastAPI로 이관하는 것으로 확정한다. 상세는 6장을 참조한다.

## 1-4. 인프라 운영 원칙  🔁🖥

v6에서 서버 실제 구성이 확인되어 일부 갱신한다. 클라우드는 AWS EC2(Ubuntu)로 확정하며, 서버는 FastAPI로 포트 8000에서 서빙한다. 서버 형상관리는 별도 저장소(ploggo-server)에서 관리한다.

### 1-4-1. Docker 컨테이너화 원칙  🔁🖥

Docker 컨테이너화는 현재 미구현이며(Dockerfile·compose 부재 확인), 향후 구현 예정으로 유지한다. Stateless 설계 원칙과 확장기 Kubernetes 도입 계획은 유지한다.

| **항목** |** 적용 시점** |** 상태** |
| --- | --- | --- |
| Dockerfile 작성 | 향후 | 미구현 |
| Docker 이미지 빌드·실행 | 향후 | 미구현 |
| 환경 변수 외부화 (.env) | 적용됨 | 서버 .env 운영 중 |
| 상태 비저장(Stateless) 설계 | 적용됨 | 서버는 영구 데이터 미보유 |

### 1-4-2. 상태 비저장 설계 적용 범위

FastAPI 서버 자체는 로컬 디스크에 영구 데이터를 두지 않는다. 앱이 접근하는 영구 데이터는 Firebase에, 서버가 사용하는 정적 데이터(핫스팟 CSV·회피 GeoJSON·YOLO 가중치)는 서버 배치 파일로 관리한다.

| **데이터 종류** |** 저장 위치** |
| --- | --- |
| 사용자 인증 정보 | Firebase Auth (앱 직접) |
| 트랜잭션 데이터 (프로필·활동·리워드) | Firestore (앱 직접) |
| 수거 인증 이미지 | 서버 직접 수신 (현재), Firebase Storage 전환은 향후 검토 |
| CCTV 핫스팟 (1,535개) | 서버 보유 CSV |
| 회피 영역 폴리곤 (147개) | 서버 메모리 (GeoJSON, 시작 시 1회 로드) |
| YOLO 가중치 (약 11.7MB) | 서버 배치 |
| 외부 API 키 (Tmap 등) | 서버 .env |

### 1-4-3. K8S(Kubernetes) 도입 시점

K8S는 다음 조건 충족 시점에 도입한다. 현 단계(베타 50명)는 단일 EC2로 충분하므로 도입하지 않는다.

| **조건** |** 본 프로젝트 시점** |
| --- | --- |
| 동시 사용자 1,000명 초과 | 정식 출시 이후 확장기 |
| 추론 처리량 한계 도달 | 동일 |
| 무중단 배포 필요 | 동일 |

# 2. 단계별 개발 가이드라인

아래 단계는 순서대로 진행한다. 각 단계가 완료되지 않은 상태에서 다음 단계를 진행하면 빌드 오류 또는 런타임 오류가 발생할 수 있다.

## STEP 1. pubspec.yaml 패키지 구성  🔁  ⬜

flutter_naver_map 패키지가 필요하다. Google Maps 관련 패키지가 있다면 제거한다. 서버 통신은 dio raw HTTP 호출을 사용하므로 경로·비전용 별도 패키지가 필요 없다.

| **패키지** |** 버전** |** 용도** |** 비고** |
| --- | --- | --- | --- |
| flutter_naver_map | ^1.3.1 | Naver Maps SDK 렌더링 | 🆕 v3 추가 |
| google_maps_flutter | - | Google Maps SDK | 🔁 v3 제거 |
| dio | ^5.x | FastAPI 통신 (경로 추천·비전) | 유지 |
| image_picker | ^1.x | 카메라 촬영 | 유지 |
| firebase_storage | - | 이미지 업로드 | 🔁🖥 v6 현재 미사용 (향후 검토) |

※ v5에서 추가 예정이던 firebase_storage는 v6 현재 구현에서 사용하지 않는다. 이미지는 서버로 직접 전송한다(3장). 향후 Storage 전환 시 재도입한다.

## STEP 2. 폴더 구조 재편  ✅

Feature-First 3-Layer 구조로 lib/ 하위 폴더 재편이 완료된 상태다.

## STEP 3. android/app/build.gradle.kts 설정  ⬜

| **항목** |** 확정값** |** 이유** |
| --- | --- | --- |
| applicationId | com.ploggo.app | 🔁 확정 |
| minSdk | 26 | Health Connect + flutter_naver_map 요구사항 |
| targetSdk | 36 | flutter doctor 기준 현재 SDK |
| compileSdk | 36 | 최신 Android API 사용 |

※ applicationId가 com.ploggo.app으로 확정되었으므로, Firebase Console과 NCP Application 등록 시 모두 동일하게 입력한다.

## STEP 4. AndroidManifest.xml 권한 및 메타데이터 설정  🔁  ⬜

앱이 민감한 기기 기능(GPS, 카메라, 신체 데이터)을 사용하려면 권한을 사전 선언해야 한다.

**① 권한 선언:**

| **권한** |** 대상 기능** |
| --- | --- |
| ACCESS_FINE_LOCATION | 실시간 GPS 위치 추적 |
| ACCESS_COARSE_LOCATION | 네트워크 기반 위치 보조 |
| FOREGROUND_SERVICE | 화면 Off 상태 백그라운드 GPS 유지 |
| FOREGROUND_SERVICE_LOCATION | Foreground Service 위치 유형 명시 (Android 14+) |
| CAMERA | 쓰레기 봉투 촬영 |
| ACTIVITY_RECOGNITION | 걸음수 인식 (Health Connect 필수) |
| INTERNET | FastAPI·Firebase 통신 |
| health 관련 READ 권한 | Health Connect 걸음수·칼로리 데이터 접근 |

**② Naver Maps Client ID meta-data 등록:**

```xml
<meta-data
    android:name="com.naver.maps.map.CLIENT_ID"
    android:value="여기에 NCP Application Client ID" />
```

## STEP 5. Firebase 프로젝트 연결  ⬜

Flutter 앱이 Firebase와 통신하려면 Firebase 콘솔에서 앱을 등록하고 google-services.json을 android/app/에 위치시켜야 한다. v6에서 인증·DB 접근은 모두 앱이 전담하므로 Firebase 연결이 핵심이다.

**진행 순서:**

- Firebase 콘솔(https://console.firebase.google.com)에서 새 프로젝트 생성
- Android 앱 등록 시 패키지명 com.ploggo.app 입력
- google-services.json 다운로드 후 android/app/ 폴더에 저장
- Firebase Authentication 활성화: Google 로그인 방식 선택
- Cloud Firestore 데이터베이스 생성: 테스트 모드로 시작
- 개발자 각자 및 배포용 SHA-1 지문 등록 (STEP 5.7 참조)  🆕🖥

🔁🖥 v6: Cloud Storage 활성화 단계는 현재 미사용으로 보류한다. 이미지를 서버로 직접 전송하기 때문이다(3장).

## STEP 5.5. Naver Cloud Platform Application 등록  🔁🖥  ⬜

Naver Maps SDK(지도 렌더링) 사용을 위해 NCP Application을 등록한다. v6에서 목적지 입력이 지도 마커 좌표 획득으로 확정되어 지오코딩이 불필요해졌으므로, Geocoding 활성화는 향후 확장을 위한 예비 항목으로만 둔다.

**진행 순서:**

- Naver Cloud Platform 회원가입 (https://www.ncloud.com)
- 콘솔 > AI·Application Service > AI·NAVER API > Application > 등록
- Application 이름: ploggo-beta (예시)
- 서비스 선택: Maps (Mobile Dynamic Map) 활성화. Geocoding은 향후 확장 예비  🔁🖥
- Android 패키지명 등록: com.ploggo.app
- 등록 후 Client ID 발급 확인

🔁🖥 v6: 목적지를 지도 마커로 지정하여 좌표를 직접 획득하므로 지오코딩(주소→좌표)이 필요 없다. 서버 /route/recommend가 좌표를 직접 받는 구현과 정합한다. Naver 지오코딩 프록시는 사용하지 않는다.

## STEP 5.6. SK Open API Tmap Pedestrian 등록  🆕🎯  ⬜

도보 경로 좌표 산출을 위해 SK Open API의 Tmap Pedestrian API를 사용한다. v6에서 이 API 호출은 서버가 전담하므로, Tmap AppKey는 서버 .env에만 보관하고 앱은 관여하지 않는다.

**진행 순서:**

- SK Open API 회원가입 (https://openapi.sk.com)
- 마이페이지 > 앱 관리 > 앱 등록
- 서비스 선택: Tmap Pedestrian (보행자 경로 안내) 활성화
- 등록 후 AppKey 발급 → 서버 .env에 저장 (앱에는 저장하지 않음)  🔁🖥

※ Tmap Pedestrian API는 서버 route_recommender 내부에서 호출된다. Flutter는 Tmap을 직접 호출하지 않으며, 서버 /route/recommend 응답의 polyline만 수신한다.

## STEP 5.7. 개발 환경 셋업 — Google 로그인 SHA-1 등록  🆕🖥  ⬜

Google 로그인은 앱을 서명한 인증서의 SHA-1 지문이 Firebase 콘솔에 등록된 환경에서만 동작한다. 현재 특정 PC의 SHA-1만 등록되어 있어 그 PC 빌드에서만 로그인이 된다. 로그인이 필요한 모든 환경의 SHA-1을 등록해야 한다.

**등록 대상:**

| **환경** |** SHA-1 종류** |** 확인 방법** |
| --- | --- | --- |
| 각 개발자 PC | 디버그 키스토어 SHA-1 | Gradle signingReport 또는 keytool |
| 배포 (Play 업로드) | 릴리스 키스토어 SHA-1 | keytool -list -v -keystore |
| 배포 (Play 앱 서명) | Play 앱 서명 SHA-1 | Play Console 앱 서명 페이지 |

※ SHA-1은 keytool 또는 Gradle signingReport로 확인한다. 참고: https://developers.google.com/android/guides/client-auth

## STEP 6. .env 파일 작성  🔁🖥  ⬜

Flutter .env에는 클라이언트에서만 필요한 값만 포함한다. Tmap AppKey·Client Secret 등 민감 정보는 서버 .env에만 보관한다. v6에서 서버 접속 주소 하드코딩을 제거하고 .env로 주입하는 것이 핵심이다.

**① Flutter .env (앱에 포함):**

| **키** |** 설명** |
| --- | --- |
| FASTAPI_BASE_URL | 서버 접속 주소 (경로 추천·비전 요청). 하드코딩 금지, .env 주입  🔁🖥 |
| NAVER_MAPS_CLIENT_ID | Naver Maps SDK 지도 렌더링용 Client ID |

**② 서버 .env (앱과 무관, 참고):**

| **키** |** 설명** |
| --- | --- |
| TMAP_APP_KEY | Tmap Pedestrian API 호출 (서버 내부) |
| VWORLD_KEY | 회피 영역 폴리곤 수집 (오프라인/서버) |
| ALGO_ALPHA / ALGO_BETA / ALGO_GAMMA | 알고리즘 가중치 (기본 0.5 / 0.5 / 1.0) |
| ALGO_K / ALGO_BF_TOP_N / ALGO_MAX_SWAP | 경유 수·후보풀·swap 한도 (기본 3 / 15 / 5) |
| ALGO_HARD_CASE_M | hard case 판정 임계 (기본 100m). 정의됨, 현재 코드 미참조 (향후 판정 로직 연결 예정) |

🔁🖥 v6: 현재 detector.dart가 특정 EC2 IP를 하드코딩하고 있으므로 제거 대상이다. Dio baseUrl을 .env에서 주입한다.

```dart
final dio = Dio(BaseOptions(baseUrl: dotenv.env["FASTAPI_BASE_URL"]!));
```

🔁📄 v7: ALGO_HARD_CASE_M은 .env.example에 100으로 정의되어 있으나, 실제 알고리즘 코드가 이 값을 참조하지 않는다. 현재 is_hard_case 판정이 이 임계값과 연결되어 있지 않으므로, "100m 기준"은 아직 판정에 적용되지 않는 상태다. 서비스·앱 동작에는 영향이 없다(앱은 절대 통과 거리를 사용자에게 표시하지 않음). 향후 판정 로직에 이 임계값을 연결하거나 변수를 제거할지는 백엔드 팀 확인 후 결정한다.

## STEP 7. main.dart 기본 골격 작성  🔁  ⬜

앱 시작 시 다음 네 가지를 초기화한다.

- flutter_dotenv: .env 파일을 메모리에 로드
- Firebase.initializeApp(): Firebase 서버 연결 완료
- FlutterNaverMap().init(): Naver Maps SDK 초기화 (Client ID 전달)
- ProviderScope: 앱 전체를 감싸 Riverpod Provider 동작

※ 초기화 순서: dotenv 로드 → Firebase 초기화 → FlutterNaverMap init → ProviderScope.

## STEP 8. core/router/ 라우터 작성  🔁🧭  ⬜

go_router로 앱의 모든 화면 전환 규칙을 한 파일(app_router.dart)에서 정의한다. 공통 바텀내비는 ShellRoute 셸로 구현되어 있다.

- 로그인 상태에 따른 redirect 분기
- ShellRoute 셸(_ScaffoldWithBottomNav)이 4개 탭 화면(/home, /group, /mypage, /settings)을 감싸 공통 바텀내비를 한 번만 그린다. 각 화면은 body만 채운다.
- 플로깅 시작 버튼 → 경로 추천 화면 → 트래킹 화면 → AI 인증 화면 순 이동

※ 셸 구조: 현재 ShellRoute를 사용한다. 탭 간 상태 보존(각 탭의 스크롤·입력 유지)이 필요해지면 StatefulShellRoute로의 전환을 검토한다.

**▶ [의사결정 필요]** 바텀내비게이션바의 플로깅 시작 버튼(중앙 돌출 버튼)은 탭 전환이 아닌 별도 화면 push 방식으로 동작하도록 설계할 것인지 확정해야 한다. (현재 커스텀 바에 중앙 시작 버튼 존재)

## STEP 9. feature별 개발  ⬜

STEP 1~8의 뼈대가 완성된 후 각 feature를 아래 순서로 개발한다.

## 9-1. auth feature (로그인)

| **레이어** |** 파일** |** 역할** |
| --- | --- | --- |
| data | auth_repository.dart | Firebase Auth Google 로그인 호출 |
| domain | auth_notifier.dart | AsyncNotifier: 로그인·로그아웃 상태 관리 |
| presentation | login_screen.dart | Google 로그인 버튼 UI |

※ 로그인 동작 전제로 STEP 5.7의 SHA-1 등록이 완료되어야 한다.

## 9-2. home feature (메인 홈)  🔁🧭

| **레이어** |** 파일** |** 역할** |
| --- | --- | --- |
| data | home_repository.dart | Firestore 사용자 프로필 및 활동 요약 조회 |
| domain | home_notifier.dart | AsyncNotifier: 홈 화면 데이터 상태 관리 |
| presentation | home_screen.dart | 헤더+활동 요약 카드, 카드 2개, 동네활동 영역 (바텀내비 없음 — 셸이 담당) |

🔁🧭 v8: 바텀내비게이션바는 home feature가 아니라 core/router의 ShellRoute 셸(_ScaffoldWithBottomNav)이 담당한다(#4 해소, 1-2 참조). home_screen은 자신의 본문 콘텐츠만 책임지며 하단 바를 직접 그리지 않는다.

## 9-3. plogging feature (경로 추천 + 트래킹)  🔁🖥

앱의 핵심 기능이다. v6에서 경로 알고리즘이 서버로 이관되어, Flutter는 서버 단일 엔드포인트(POST /route/recommend)를 호출하고 결과를 수신·시각화하는 역할만 담당한다. 알고리즘을 실행하지 않는다.

| **레이어** |** 파일** |** 역할** |** v6** |
| --- | --- | --- | --- |
| data | location_repository.dart | geolocator GPS 스트림, Foreground Service 연동 |  |
| data | route_repository.dart | Dio로 서버 POST /route/recommend 호출 (알고리즘 미실행) | 🔁🖥 |
| domain | plogging_notifier.dart | AsyncNotifier: 트래킹 상태(거리·시간·걸음수) 관리 |  |
| domain | route_notifier.dart | AsyncNotifier: 경로 요청 상태 관리 (AsyncValue.guard) | 🔁🖥 |
| presentation | route_screen.dart | AsyncValue.when으로 처리, Naver Maps에 polyline 렌더링 | 🔁🖥 |
| presentation | tracking_screen.dart | 실시간 트래킹 대시보드 화면 |  |

🔁🖥 v6: v5의 hotspot_repository.dart(Firestore GeoHash 탐색)는 삭제한다. 핫스팟 탐색은 서버 알고리즘 내부에서 수행되며, 앱은 출발지·목적지 좌표만 전송한다.

### 경로 알고리즘 서버 이관 — 처리 위치 확정  🔁🖥

v5까지는 Waypoint 알고리즘(K=3)을 Flutter route_notifier에서 수행하는 것으로 규정하였다. v6에서 서버 이식 완료가 확인되어 알고리즘 연산 전량을 FastAPI 서버로 이관한다.

| **항목** |** v5 (Flutter)** |** v6 확정 (FastAPI 서버)** |
| --- | --- | --- |
| 후보 필터 (타원 buffer) | Flutter | 서버 route_recommender/algorithm.py |
| Score 산정 + 회피 페널티 | Flutter | 서버 |
| Safe Swap | Flutter (미구현) | 서버 (구현 완료) |
| Tmap 호출 + polyline 교차 검사 | FastAPI 프록시 | 서버 (통합) |
| Flutter 역할 | 알고리즘 실행 | 요청 전송 + 결과 수신·시각화 |

**서버 실행 근거 (연산 부하가 아님):**

- Python 공간 연산 스택(shapely)으로 설계·검증한 자산을 그대로 재사용하여 검증 결과의 일관성을 유지한다.
- Tmap·V-World API 키를 서버에 두고 프록시로 경유하여 키를 보호한다.
- 회피 영역·핫스팟 데이터를 서버에서 관리하여 앱 재배포 없이 갱신한다.

※ 알고리즘 자체는 모바일에서도 실시간 처리가 가능할 만큼 가볍다. 서버 실행은 연산 부하 때문이 아니라 위 세 가지 운영상 근거에 따른 결정이다.

### Riverpod 3-Layer 구현 규약 (경로 요청)  🆕🖥

- Data: route_repository가 Dio로 서버 단일 엔드포인트(POST /route/recommend)를 호출한다.
- Domain: route_notifier(AsyncNotifier)가 요청 상태를 관리하고 AsyncValue.guard로 감싼다.
- Presentation: AsyncValue.when으로 data·loading·error를 처리하고 Naver Maps에 경로를 렌더링한다.
- Tmap 응답 실패 시 서버가 HTTP 502로 반환하므로, Data 계층에서 502를 별도 처리하고 Presentation에서 사용자 메시지를 노출한다.

## 9-4. vision feature (AI 수거 인증)  🔁🖥

플로깅 종료 후 쓰레기 봉투를 촬영하면 이미지를 서버로 직접 전송하고, 서버 YOLOv8n이 분석하여 결과(종류·개수·박스)를 JSON으로 반환한다. v6 현재 Firebase Storage 연동은 앱·서버 어느 쪽에도 구현되어 있지 않다.

| **레이어** |** 파일** |** 역할** |** v6** |
| --- | --- | --- | --- |
| data | vision_repository.dart | 이미지 바이너리를 서버 /detect에 multipart 직접 전송 | 🔁🖥 |
| domain | vision_notifier.dart | AsyncNotifier: 촬영→전송→결과 파이프라인 (신규 구현 필요) | 🆕🖥 |
| presentation | camera_screen.dart | image_picker 카메라 촬영 화면 |  |
| presentation | vision_result_screen.dart | 객체 인식 결과(종류·개수) 출력 화면 |  |

🔁🖥 v6: v5의 storage_repository.dart(Firebase Storage 업로드)는 현재 구현에서 제거한다. 이미지는 서버로 직접 전송한다.

※ 정비 필요: 현재 vision feature의 domain 계층이 미구현 상태다. data(서버 통신)와 presentation(화면) 사이에 domain(AsyncNotifier) 계층을 추가하여 3-Layer를 완성해야 한다.

**처리 흐름 (현재 구현):**

- Flutter: image_picker로 사진 촬영
- Flutter: 이미지 바이너리를 서버 /detect에 multipart/form-data의 file 필드로 전송
- 서버: YOLOv8n 추론 후 결과(종류·개수·박스)를 JSON 반환
- Flutter: 응답을 vision_result_screen에 표시

**vision_repository 핵심 슬라이스:**

```dart
Future<VisionResult> detect(File image) async {
  final form = FormData.fromMap({
    "file": await MultipartFile.fromFile(image.path),
  });
  final res = await _dio.post("/detect", data: form);
  return VisionResult.fromJson(res.data);
}
```

※ 향후 개선 (미구현): 서버 부하 경감과 Stateless 원칙을 위해, 앱이 Firebase Storage에 직접 업로드하고 서버에는 다운로드 URL만 전달하는 방식으로 전환을 검토한다. 현 단계에서는 적용하지 않는다.

## 9-5. reward feature (에코포인트·환경 영향력)

| **레이어** |** 파일** |** 역할** |
| --- | --- | --- |
| data | reward_repository.dart | Firestore 에코포인트 적립·조회, 상점 쿠폰 연동 |
| domain | reward_notifier.dart | AsyncNotifier: 포인트 계산 및 시각화 데이터 상태 관리 |
| presentation | reward_screen.dart | 탄소 절감량, 에코포인트, 상점 화면 |

**▶ [의사결정 필요]** 에코포인트 산출 공식(수거 쓰레기 종류·개수 → 포인트 환산 기준)을 사전에 확정해야 한다. 클래스명은 can·glass·paper·plastic·trash(일반쓰레기)로 통일한다.

## 9-6. community feature (그룹·뉴스)  🔁📄

| **레이어** |** 파일** |** 역할** |** v7** |
| --- | --- | --- | --- |
| data | community_repository.dart | Firestore 그룹 데이터 CRUD |  |
| data | news_repository.dart | FastAPI 경유: 환경 뉴스 원문 + Gemini 요약 수신 (현재 미구현, 향후) | 🔁📄 |
| domain | community_notifier.dart | AsyncNotifier: 그룹 피드 상태 관리 |  |
| domain | news_notifier.dart | AsyncNotifier: 뉴스 요약 상태 관리 (향후) | 🔁📄 |
| presentation | group_screen.dart | 그룹 피드 화면 |  |
| presentation | news_screen.dart | 환경 뉴스 요약 피드 화면 (향후) | 🔁📄 |

🔁📄 v7: Gemini 뉴스 요약은 현재 미구현이다. 서버에 GEMINI_API_KEY 이름만 존재하고 실제 호출 코드가 없음이 확인되었다. Docker·Firebase Storage와 동일하게 "미구현·향후"로 표기한다. 뉴스 기능 개발 착수 시 서버 Gemini 프록시부터 구현해야 한다.

**▶ [의사결정 필요]** 환경 뉴스 원문 데이터 소스를 확정해야 한다. (Gemini 프록시 미구현 상태이므로 서버 구현과 함께 진행)

## 9-7. mypage feature (마이페이지)  🔁📄

| **레이어** |** 파일** |** 역할** |
| --- | --- | --- |
| data | user_repository.dart | Firestore 사용자 정보 조회·수정 |
| domain | user_notifier.dart | AsyncNotifier: 사용자 상태 관리 |
| presentation | mypage_screen.dart | 프로필, 활동 히스토리 화면 |
| presentation | (활동·임팩트·퀘스트 화면) | activity·activity_list·activity_detail·my_impact·quest_list 등 |

🔁📄 v7: 설정 화면은 mypage 하위가 아니라 별도 settings feature에 있다(9-8 참조). v6까지 mypage에 두었던 settings_screen.dart 항목은 실제 구조와 맞지 않아 분리한다.

## 9-8. settings feature (설정)  🆕📄

설정·메뉴 화면을 담는 별도 feature다. 실제 코드 기준으로 v7에서 독립 절로 명시한다.

| **레이어** |** 파일** |** 역할** |
| --- | --- | --- |
| data | (비어 있음) | .gitkeep |
| domain | (비어 있음) | .gitkeep |
| presentation | menu_screen.dart (MenuScreen) | 설정·메뉴 화면. 라우터 /settings에 연결, 하단 네비 메뉴 탭(index 4) 진입 |

※ known issue: 파일명 menu_screen.dart는 명명 규칙 {기능}_screen.dart(→ settings_screen.dart)와 어긋난다. 기능이 설정이므로 settings_screen.dart가 규칙에 부합하나, 현재 정상 동작 중이므로 개발 단계에서 리네임 여부를 결정한다. v7에서는 실제 구조를 그대로 문서화하고 변경하지 않는다.

# 3. 서버 API 계약  🆕🖥

서버 코드로 확인된 엔드포인트와 스키마다. Flutter Data 계층은 이 계약을 기준으로 구현한다.

## 3-1. baseUrl 규약

서버 접속 주소는 하드코딩하지 않고 .env의 FASTAPI_BASE_URL로 주입한다. 현재 detector.dart가 특정 EC2 IP를 하드코딩하고 있으므로 제거 대상이다.

## 3-2. 엔드포인트 목록

| **메서드** |** 경로** |** 기능** |
| --- | --- | --- |
| POST | /detect | 이미지 → 종류·개수·박스 |
| POST | /detect_and_crop | 이미지 → 카운트 + 크롭 이미지(base64) |
| POST | /route/recommend | 출발지·도착지 → 회피 우회 K=3 경로 |
| GET | /health, /route/health | 상태 확인 |

## 3-3. 경로 추천 요청·응답 스키마

**요청 (RouteRequest):**

| **필드** |** 필수** |** 설명** |
| --- | --- | --- |
| origin{lat, lon} | 필수 | 출발지 좌표 |
| destination{lat, lon} | 필수 | 도착지 좌표 (지도 마커로 획득) |
| district | 선택 | 인천 9개 군구 영문명 |

**응답 (RouteResponse) 주요 필드:**

| **필드** |** 설명** |
| --- | --- |
| success | 성공 여부 |
| is_hard_case | swap 후에도 회피 영역 통과가 남은 경우 true |
| intersection_m / intersection_ratio | 회피 영역 통과 길이(m) / 비율 |
| crossed_uqa_codes[] | 통과한 회피 영역 코드 목록 |
| polyline[[lat,lon]] | 경로 좌표 배열 (지도 렌더링용) |
| distance_m / duration_ms | 총 거리 / 예상 소요시간 |
| n_swaps | swap 시도 횟수 |
| k3_hotspots[] | 선정 핫스팟 목록 (hotspot_id, latitude, longitude, S_i, avoid_penalty) |

※ Tmap 응답 실패 시 서버가 HTTP 502로 반환하므로, Data 계층에서 502를 별도 처리하고 Presentation에서 사용자 메시지를 노출한다.

## 3-4. 비전 응답 스키마 (/detect)

| **필드** |** 설명** |
| --- | --- |
| success | 성공 여부 |
| image_size{width,height} | 이미지 크기 |
| detections[] | class_id, class_name, confidence, box, box_pixel |
| counts{클래스명:int} | 클래스별 개수 |
| total | 총 개수 |

**클래스명:** can, glass, paper, plastic, trash. 한글 표기는 캔·유리·종이·플라스틱·일반쓰레기로 통일한다(일반쓰레기 = trash).

## 3-5. 목적지 입력 방식  🆕🖥

- 목적지는 지도에서 마커를 이동하여 지정하며, 그 지점의 위경도 좌표를 직접 획득한다.
- 주소·장소명 검색 방식이 아니므로 지오코딩(주소→좌표 변환)이 필요 없다. 서버 /route/recommend가 좌표를 직접 받는 구현과 정합한다.
- Naver 지오코딩 프록시는 사용하지 않는다. .env.example의 Naver 키는 지도 SDK·향후 확장을 위한 예비 항목으로 둔다.

# 4. 상태 관리 및 3-Layer 아키텍처

## 4-1. 재확인 원칙

- Feature-First 3-Layer(presentation/domain/data)를 유지한다. 의존 방향은 Presentation → Domain → Data 하향 단방향이다.
- 프로바이더 선정 기준: 단순 조회(설정 로드·단건 Firestore read)는 FutureProvider/StreamProvider, 사용자 액션 기반 상태 변경(경로 요청·수거 인증·저장)은 AsyncNotifier.
- 로딩·에러 불리언 플래그의 수동 관리를 금지하고 AsyncValue.guard·AsyncValue.when을 사용한다.
- 단일 원본(Single Source of Truth)을 유지하고, 순차 데이터는 상위 프로바이더 값을 하위 입력으로 연결한다.

## 4-2. 정비 필요 항목  🆕🖥

vision feature의 domain 계층이 미구현 상태이므로, data(서버 통신)와 presentation(화면) 사이에 domain(AsyncNotifier) 계층을 추가하여 3-Layer를 완성한다. (9-4 참조)

## 4-3. 경유지 수(K) 사용자 선택형 확장 (향후 계획)  🆕🖥

서버 알고리즘이 경유지 수를 파라미터로 입력받는다(현재 ALGO_K 환경 변수, 기본값 3). 향후 플로깅 시작 전 사용자가 활동 강도를 선택하면 해당 값을 K로 전달하는 방식으로 확장한다.

| **활동 강도 (예시)** |** 경유지 수 K** |
| --- | --- |
| 짧게 | 2곳 |
| 보통 | 3~4곳 |
| 길게 | 5곳 |

**구조 예시:**

```dart
final ploggingIntensityProvider = StateProvider<int>((ref) => 3); // 기본 K=3
// route 요청 프로바이더가 이 값을 watch하여 요청 파라미터로 전달(체이닝)
```

**▶ [의사결정 필요]** 요청 단위로 K를 전달하려면 서버가 K를 요청 파라미터로 받도록 하는 협의가 필요하다(현재는 환경 변수). 이는 프론트엔드·UX 과제로 향후 진행한다.

# 5. 코딩 규칙

## 5-1. Flutter 코딩 규칙

- 색상 투명도는 withOpacity가 아니라 color.withValues(alpha: value)를 사용한다. withValues는 명명 인자로 호출하며 alpha 범위는 0.0~1.0이다.
- 서버 접속 주소·API 키 등은 하드코딩하지 않고 .env로 관리한다.
- 코드 수정 시 전체 파일을 덮어쓰지 않는다. 수정이 필요한 부분만 발췌하여 변경한다.
- 코드 내 주석은 한국어로 작성한다.
- Naver Maps 좌표는 NLatLng(lat, lng) 사용. Google Maps의 LatLng와 혼동하지 않는다.
- primary color는 현재 파스텔 블루 #6BA3E8(app_colors)를 사용하며, 최종 배포 전 색상 조정이 예정되어 있다.

## 5-2. Git 커밋 규칙

| **prefix** |** 사용 상황** |
| --- | --- |
| feat: | 새로운 기능 추가 |
| fix: | 버그 수정 |
| refactor: | 기능 변경 없는 코드 개선 |
| chore: | 설정 파일, 패키지 등 변경 |
| docs: | 문서 수정 |

# 6. 의사결정 필요 항목 목록

## 6-1. 해소된 항목  ✅

v3~v5에서 해소된 항목(#1·#2·#5·#8~#28)은 유지된다. 아래는 v6에서 추가 해소된 항목이다.

**v6에서 추가 해소된 항목  🆕🖥:**

| **번호** |** 항목** |** 결정 내용** |
| --- | --- | --- |
| #31 | 경로 알고리즘 처리 위치 | FastAPI 서버 전량 이관 (서버 이식 완료). Flutter는 요청·수신만 |
| #32 | 앱-서버-Firebase 책임 분담 | 서버는 연산만, Firebase 접근은 앱 전담 (서버 firebase-admin 부재 확인) |
| #33 | 이미지 처리 흐름 | 서버 직접 수신 (multipart). Firebase Storage는 향후 검토 |
| #34 | 목적지 입력 방식 | 지도 마커 좌표 획득. 지오코딩 불필요 |
| #35 | 근접 탐색 방식 | 타원 buffer + numpy 전수 계산 (GeoHash 인덱스 미사용) |

**v7에서 추가 해소된 항목  🆕📄:**

| **번호** |** 항목** |** 결정 내용** |
| --- | --- | --- |
| #4 | 바텀내비게이션바 위젯 위치 | core/router의 ShellRoute 셸(_ScaffoldWithBottomNav)이 담당 (v8 코드 정합 정정). 셸이 4개 탭 화면을 감싸 공통 바를 한 번만 그림. 향후 재사용·복잡도 증가 시 core/widgets/로 추출 |

**v8에서 정정된 항목  🔁🧭:**

| **번호** |** 항목** |** 정정 내용** |
| --- | --- | --- |
| #4 | 바텀내비 실제 위치 | v7의 core/widgets/ 목표 서술을 실제 구현(ShellRoute 셸)로 정정. 관련 3곳(9-2 노트, 1-2 home 행, 9-2 home_screen 행) 동기화. 코드는 미변경 |

## 6-2. 잔여 의사결정 항목  ⬜

#4(바텀내비 위젯 위치)는 v7에서 해소되어 6-1로 이동하였다. 아래는 잔여 항목이다.

| **번호** |** 항목** |** 관련 위치** |
| --- | --- | --- |
| #3 | 바텀내비게이션바 플로깅 버튼 동작 방식 (탭 전환 vs 화면 push) | STEP 8 |
| #6 | 에코포인트 산출 공식 (쓰레기 종류·개수 → 포인트 환산 기준) | 9-5 |
| #7 | 환경 뉴스 데이터 소스 (공개 RSS vs FastAPI 크롤러) | 9-6 |
| #24 | EC2 인스턴스 사양 (vCPU, RAM) | 서버 운영 |
| #29 | Tmap Pedestrian 무료 한도·종량제 단가 확인 | STEP 5.6 |
| #36 | K 요청 파라미터화 협의 (현재 환경 변수) | 4-3 |
| #37 | primary color 최종 색상 조정 | 5-1 (배포 전) |
| #38 | Firebase Storage 이미지 전환 여부 | 9-4 (향후) |
| #39 | Gemini 뉴스 요약 서버 구현 (현재 미구현) | 9-6 |
| #40 | ALGO_HARD_CASE_M 코드 연결 또는 변수 제거 (현재 미참조) | STEP 6 / 백엔드 |
| #41 | 설정 화면 폴더·파일명 정합 (settings/menu_screen.dart) | 9-8 (개발 단계) |

# 7. 데이터 관리 구조 (참고)  🆕🖥

Flutter 개발자가 데이터의 위치를 파악하기 위한 참고 표다.

| **데이터** |** 저장 위치** |** 접근 주체** |
| --- | --- | --- |
| 사용자 계정·인증 | Firebase Auth | 앱 직접 |
| 유저 프로필·활동 기록·커뮤니티·리워드 | Cloud Firestore | 앱 직접 |
| 수거 인증 이미지 | 서버 직접 수신 (현재) | 앱이 서버에 전송 |
| CCTV 핫스팟 (1,535개) | 서버 보유 CSV | 서버 (알고리즘) |
| 회피 영역 폴리곤 (147개) | 서버 메모리 (GeoJSON) | 서버 (알고리즘) |
| YOLO 가중치 (약 11.7MB, 640×640, 5클래스) | 서버 배치 | 서버 (추론) |
| 외부 API 키 (Tmap 등) | 서버 .env | 서버 |

## 7-1. 서버측 참고 사항 (Flutter 직접 관련 낮음)

- 근접 핫스팟 탐색은 GeoHash 공간 인덱스가 아니라, 출발지·목적지를 두 초점으로 하는 타원형 buffer(기본 1.5km, 강화군 2.5km) 필터와 numpy 전수 거리 계산으로 수행한다. 이웃 밀도는 오프라인에서 BallTree로 사전 계산한다. 데이터가 소규모(1,535개)여서 공간 인덱스의 실익이 없기 때문이다. v5·계획서의 "GeoHash 기반 공간 인덱싱" 표기는 실제 구현과 다르므로 갱신 대상이다.
- 회피 영역 통과 길이 계산에 경도 방향 cos 보정이 미적용되어 동서 성분에 계통 편향이 있으나, 모든 후보에 동일하게 작용하여 경유지 선정·경로 판정에는 영향이 없다. 앱에서 절대 통과 거리(m)를 사용자에게 표시할 계획이 없으므로 현 단계에서 보정은 불필요하다.
- 경유지 방문 순서는 현재 Score 내림차순 고정이며, 순서 최적화는 알고리즘 고도화 단계에서 개선한다.

# 8. v5 → v6 변경 이력  🆕🖥

v5에서 v6로 갱신된 항목을 한 곳에 정리한다. v6의 핵심은 서버 코드 분석 결과에 따른 아키텍처 확정이다. 경로 알고리즘의 서버 이관, 서버-Firebase 책임 분리, 이미지 처리 흐름 확정, 서버 API 계약 명시가 주요 변경이다.

| **항목** |** v5** |** v6 (갱신)** |
| --- | --- | --- |
| 경로 알고리즘 위치 | Flutter route_notifier | FastAPI 서버 전량 이관 |
| 이미지 업로드 | Firebase Storage 직접 검토 | 서버 직접 수신(현재), Storage는 향후 |
| 서버-Firebase | 연동 가정 | 서버 미연동, 앱 전담 |
| 목적지 입력 | 미특정 (지오코딩 전제) | 지도 마커 좌표 획득, 지오코딩 불필요 |
| 근접 탐색 | GeoHash 인덱싱 | 타원 buffer + numpy 전수 계산 |
| K값 | 3 고정 | 환경 변수(기본 3), 사용자 선택형 확장 계획 |
| Docker | 도입 원칙 | 미구현, 예정 |
| 클래스명 | 혼재 | can·glass·paper·plastic·trash(일반쓰레기) |
| SHA-1 등록 | 미기재 | STEP 5.7 신규 (개발 환경 셋업) |
| 서버 API 계약 | 미기재 | 3장 신규 (엔드포인트·스키마) |
| 문서 구조 | 경로/코딩/결정/변경이력 | 서버 API 계약·데이터 관리 구조 절 추가 |

# 9. v6 → v7 변경 이력  🆕📄

v6에서 v7로 갱신된 항목을 정리한다. v7은 서버·앱 코드 검수에서 드러난 문서-코드 불일치와 미구현 항목을 문서에 정확히 반영하는 정합성 갱신이다. 아키텍처 자체의 변경은 없다.

| **항목** |** v6** |** v7 (갱신)** |
| --- | --- | --- |
| #4 바텀내비 위젯 | 해소·잔여 양쪽에 중복 표기 (모순) | core/widgets/ 확정 → 6-1 해소로 일원화, 6-2에서 제거 |
| 바텀내비 배치 근거 | 미기재 | 1-2에 공용 셸 UI·core 소속 근거 및 향후 세분화 방침 명시 |
| Gemini 뉴스 요약 | 구현된 것처럼 표기 | 현재 미구현·향후로 표기 (1-1·9-6). #39 잔여 추가 |
| ALGO_HARD_CASE_M | 작동 중처럼 표기 | 정의됨·코드 미참조로 표기 (STEP 6). #40 잔여 추가 |
| 설정 화면 구조 | mypage 하위 settings_screen.dart | known issue 명시: 실제는 settings feature의 menu_screen.dart. 9-8 신규 절, #41 잔여 추가 |
| mypage feature | 설정 화면 포함 | 설정 분리, 실제 화면(활동·임팩트·퀘스트) 반영 |
| 문서 구조 | 8개 장 | 9-8 settings 절·9장 변경 이력 추가 |

# 10. v7 → v8 변경 이력  🆕🧭

v7에서 v8로 갱신된 항목을 정리한다. v8은 바텀내비게이션바의 실제 코드 위치를 문서에 정합화하는 갱신이다. 코드 확인 결과 바텀내비는 v7이 목표로 삼은 core/widgets/가 아니라 ShellRoute 셸이 담당하고 있어, 관련 서술을 실제 구현 기준으로 정정한다. 코드는 변경하지 않는다.

| **항목** |** v7** |** v8 (정정)** |
| --- | --- | --- |
| #4 바텀내비 위치 | core/widgets/ 배치 확정 (목표) | core/router의 ShellRoute 셸(_ScaffoldWithBottomNav)이 담당 (실제 구현) |
| 1-2 core/router 행 | 전체 라우팅 정의 | ShellRoute 셸이 공통 바텀내비 담당 명시 |
| 1-2 core/widgets 행 | 바텀내비 공용 위젯 | 현재 비어 있음(향후 추출용)으로 정정 |
| 1-2 home 행 | 메인 홈 화면, 바텀네비게이션바 | 메인 홈 화면 (본문만, 바텀네비는 셸 담당) |
| 9-2 home_screen 행 | ...바텀네비게이션바 UI | 헤더·카드·동네활동 (바텀네비 없음) |
| 9-2 결정 노트 | home vs core/widgets 미결정(모순) | 삭제 → 셸 담당 해소 참조로 교체 |
| STEP 8 | 탭 전환만 기술 | ShellRoute 셸 구조·StatefulShellRoute 검토 조건 명시 |
| 문서 구조 | 9개 장 | 10장 변경 이력 추가 |

— 문서 끝 —
