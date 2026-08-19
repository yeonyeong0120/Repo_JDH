# Ploggo Flutter 개발 가이드라인 v9

AI 플로깅 플랫폼 (Ploggo) | 2026 한이음 드림업 프로젝트

- 작성일: 2026-08-13
- 기준 커밋: `f/route` 브랜치 HEAD (`66e28d7`)
- 검증 환경: Flutter 3.44.2 (stable) / Dart 3.12.2
- 근거 자료: `docs/audit_v8.md`, `docs/audit_v8_supplement.md`, `docs/2026-08-12-코드정비백로그.md`
- v8(`docs/guideline_v8.md`)은 삭제하지 않고 이력 문서로 보존한다. 본 문서 작성 과정에서 코드는 수정하지 않았다.

---

## 0. 문서 목적 및 v8 대비 구조 변경

본 문서는 Ploggo Flutter 앱과 FastAPI 서버의 **현행 상태(as-is)**, 서버 API 계약, 계층 규약, 코딩 규칙, 잔여 과제를 기술한다.

### 0-1. STEP 번호 체계 폐기

v8까지 유지하던 STEP 1~9 번호 체계와 완료/미완료 체크박스를 폐기한다.

- 완료된 단계(구 STEP 2·3·7·8)의 내용은 1장 현행 아키텍처에 사실 문장으로 흡수한다.
- 미완료 단계의 내용은 5장 잔여 과제로 옮긴다.
- 본 문서 어디에도 STEP 번호와 완료/미완료 체크박스를 두지 않는다.

폐기 사유는 다음과 같다. 체크박스 상태와 코드가 어긋나는 부정합이 v7·v8에서 반복되었다. 구체적으로 구 STEP 3(build.gradle.kts 설정), 구 STEP 7(main.dart 초기화), 구 STEP 8(라우터 작성)은 코드상 완료되어 있음에도 v8에서 미완료로 표기되어 있었다. 체크박스는 갱신 주체가 불분명하여 노후화가 구조적으로 반복되므로, 상태 표기 대신 현행 서술과 잔여 과제 목록으로 대체한다.

### 0-2. 표기 규칙

- 이모지를 사용하지 않는다. v3~v8의 버전 마커 6세트(🔁/🆕 계열)는 본문에서 제거하고 부록 A에서만 이력으로 참조한다.
- 최상위 장 번호는 `1.`~`6.` 형식, 하위 절 번호는 `1-1.` 형식으로 구분한다. 표 내부에서 절을 인용할 때는 `본 문서 3-2` 형식으로 적는다.
- 현재 구현을 기술할 때는 현재형으로 쓴다. 아직 구현되지 않은 목표를 기술할 때는 반드시 "향후"를 명시한다.
- 저장소 파일만으로 판정할 수 없는 항목은 "저장소 파일로 확인 불가"로 명시한다. 삭제하거나 단정하지 않는다.

---

## 1. 현행 아키텍처

### 1-1. 기술 스택

버전은 `pubspec.lock` 실측값이다. v8 표의 버전 표기 중 실제와 달랐던 항목을 정정하였다.

| 구분 | 기술 | 실제 버전 | 역할 |
|---|---|---|---|
| 프론트엔드 | Flutter / Dart | 3.44.2 / 3.12.2 (`pubspec.yaml:7` sdk 제약 `^3.9.2`) | Android 우선 크로스플랫폼 앱 |
| 상태 관리 | flutter_riverpod | 2.6.1 | 비동기 상태 관리 |
| 코드 생성 | riverpod_annotation | 2.6.1 | `app_router.g.dart` 생성 |
| 라우팅 | go_router | 15.1.3 | 선언적 화면 전환 |
| 인증 | firebase_auth | — | 로그인. 앱이 직접 접근 |
| DB | cloud_firestore | — | NoSQL. 앱이 직접 접근 |
| 이미지 저장 | firebase_storage | 12.4.10 | 수거 인증 사진·프로필 사진 저장 |
| 지도 렌더링 | flutter_naver_map | 1.4.4 | Naver Maps SDK |
| 위치 추적 | geolocator | 13.0.4 | 실시간 GPS |
| 역지오코딩 | geocoding | 3.0.0 | 좌표 → 주소 변환 |
| 헬스 데이터 | health | 13.3.1 | Health Connect 걸음수·칼로리 |
| 백그라운드 | flutter_foreground_task | 8.17.0 | 화면 Off 상태 GPS 연속 추적 |
| 카메라 | camera | 0.10.6 | 실시간 프리뷰 및 촬영 |
| 서버 통신 (경로) | dio | 5.11.0 | `POST /route/recommend` |
| 서버 통신 (비전·뉴스) | http | 1.6.0 | `POST /detect`, `GET /news`. 본 문서 3-4에 따라 향후 dio로 통일 |
| 환경변수 | flutter_dotenv | 5.2.1 | `.env` 로드 |
| 폰트 | Pretendard (메인) / NotoSansKR (백업) | — | `pubspec.yaml:98~118`. NotoSansKR은 "백업 폰트(나중에 삭제 가능)" 주석 |
| 경로 알고리즘 | FastAPI 서버 `route_recommender` | — | 후보 필터·Score·회피 페널티·Safe Swap·Tmap 호출·교차 검사 전량 서버 처리 |
| 도보 경로 API | Tmap Pedestrian (서버 내부 호출) | — | 앱은 Tmap을 직접 호출하지 않는다 |
| 공간 탐색 | 타원 buffer + numpy 전수 계산 | — | 출발지·목적지 두 초점 타원 필터. GeoHash 인덱스 미사용 |
| LLM | Gemini 2.5 Flash (FastAPI 경유) | — | 환경 뉴스 요약. 서버 구현 완료, 앱이 수신·표시 중 |
| 백엔드 AI | Python FastAPI + YOLOv8n (ONNX) | — | 추론 + 경로 알고리즘 서버 |
| 백엔드 인프라 | AWS EC2 (Ubuntu, 포트 8000) | — | 별도 저장소 `ploggo-server` |
| 컨테이너화 | Docker | 미도입 | Dockerfile·compose 부재. 향후 |
| 오케스트레이션 | Kubernetes | 미도입 | 확장기 검토. 향후 |

등록되어 있으나 코드 사용처가 0건인 패키지가 2개 있다.

| 패키지 | 버전 | 상태 |
|---|---|---|
| `dart_geohash` | 2.1.0 | 사용처 0건. 공간 탐색이 서버 타원 buffer 방식으로 확정되어 불필요해진 잔존 의존성 |
| `google_generative_ai` | 0.4.7 | 사용처 0건. Gemini 호출을 서버가 전담하므로 앱에는 불필요 |

### 1-2. Dart 패키지명과 applicationId

두 값이 서로 다르다. Flutter에서 Dart 패키지명과 Android applicationId는 독립적인 값이므로 코드상 오류가 아니다. 다만 문서만 읽으면 import 경로를 `package:ploggo/...`로 오인할 수 있어 명시한다.

| 항목 | 값 | 위치 |
|---|---|---|
| Dart 패키지명 | `repo_jdh` | `pubspec.yaml:1` |
| import 경로 | `package:repo_jdh/...` | 전 파일. `package:ploggo/...` 형식은 0건 |
| Android applicationId | `com.ploggo.app` | `android/app/build.gradle.kts:21` |
| Android namespace | `com.ploggo.app` | `android/app/build.gradle.kts:11` |
| 앱 표시명 label | `ploggo` | `android/app/src/main/AndroidManifest.xml:37` |

Firebase Console과 NCP Application 등록 시 입력하는 값은 applicationId인 `com.ploggo.app`이다.

### 1-3. Android 빌드 구성

아래 4개 값은 모두 적용 완료 상태다.

| 항목 | 값 | 위치 |
|---|---|---|
| applicationId | `com.ploggo.app` | `build.gradle.kts:21` |
| minSdk | 26 | `build.gradle.kts:24` |
| targetSdk | 36 | `build.gradle.kts:25` |
| compileSdk | 36 | `build.gradle.kts:12` |

minSdk 26은 Health Connect와 flutter_naver_map의 요구사항이다.

### 1-4. Android 권한 선언

`AndroidManifest.xml`에 선언된 권한은 다음과 같다. 전부 선언 완료 상태다.

| 권한 | 대상 기능 | 라인 |
|---|---|---|
| ACCESS_FINE_LOCATION | 실시간 GPS 위치 추적 | `:5` |
| ACCESS_COARSE_LOCATION | 네트워크 기반 위치 보조 | `:7` |
| ACCESS_BACKGROUND_LOCATION | 백그라운드 위치 접근 | `:9` |
| FOREGROUND_SERVICE | 화면 Off 상태 GPS 유지 | `:13` |
| FOREGROUND_SERVICE_LOCATION | Foreground Service 위치 유형 명시 (Android 14+) | `:15` |
| CAMERA | 쓰레기 봉투 촬영 | `:19` |
| ACTIVITY_RECOGNITION | 걸음수 인식 | `:23` |
| INTERNET | FastAPI·Firebase 통신 | `:25` |
| health READ 권한 (걸음수·칼로리) | Health Connect 데이터 접근 | `:27`, `:31` |
| WRITE_EXTERNAL_STORAGE (maxSdkVersion 29) | 레거시 저장소 쓰기 | `:33` |

`ACCESS_BACKGROUND_LOCATION`과 `WRITE_EXTERNAL_STORAGE`는 v8 권한표에 없던 항목으로 v9에서 추가 기술한다. 두 권한의 실제 필요 여부 검토는 5장 잔여 과제에 둔다.

Naver Maps Client ID는 manifest의 `com.naver.maps.map.CLIENT_ID` meta-data로 등록되어 있지 않다. 대신 런타임에 `lib/main.dart:29`에서 `dotenv`로 주입한다. 두 방식 중 하나만 있으면 되므로 현행 방식으로 확정한다.

### 1-5. 앱 초기화 순서

`lib/main.dart`의 실제 초기화 순서는 다음과 같다. v8이 기술한 "dotenv 우선" 순서와 앞 두 단계가 반대이며, 현행 순서를 기준으로 한다.

| 순서 | 처리 | 라인 |
|---|---|---|
| 1 | `Firebase.initializeApp()` | `:22` |
| 2 | `dotenv.load()` | `:25` |
| 3 | `FlutterNaverMap().init(clientId: dotenv.env['NAVER_MAP_CLIENT_ID']!)` | `:28~29` |
| 4 | `runApp(const ProviderScope(child: MyApp()))` | `:46` |

`MyApp`은 `ConsumerWidget`이다(`:49`).

### 1-6. 폴더 구조

`lib/core/` 하위는 7개 디렉토리로 구성된다.

| 경로 | 역할 | 실제 내용 |
|---|---|---|
| `lib/main.dart` | 앱 진입점 | 1-5 참조 |
| `lib/core/constants/` | 앱 전역 상수 | `eco_constants.dart` |
| `lib/core/dev/` | 개발용 더미·시드 코드 | `dev_data.dart`, `dev_seed.dart`, `dev_user.dart` (566줄). 활성화 플래그는 모두 `false` |
| `lib/core/providers/` | 전역 Provider | `auth_provider.dart`, `plogging_provider.dart`, `shared_group_provider.dart`, `tracking_provider.dart` |
| `lib/core/router/` | go_router 라우팅 정의 + ShellRoute 셸 | `app_router.dart`, `app_router.g.dart` |
| `lib/core/theme/` | 색상·간격·타이포·테마 | `app_colors.dart`, `app_spacing.dart`, `app_theme.dart`, `app_typography.dart` |
| `lib/core/view_models/` | 화면별 뷰모델 | `screen_views.dart` |
| `lib/core/widgets/` | 2개 이상 feature 공용 위젯 | 7개 파일 (아래 참조) |
| `assets/fonts/` | 폰트 파일 | Pretendard 4종 + NotoSansKR |
| `assets/images/` | 이미지 리소스 | — |
| `.env` | `NAVER_MAP_CLIENT_ID`, `FASTAPI_BASE_URL` | Git 비추적 |

`lib/core/utils/`는 존재하지 않는다. 순수 헬퍼 함수는 현재 각 feature의 domain 계층에 있다(`eco_math.dart`, `level_system.dart`).

**`lib/core/widgets/` 실제 내용 (7개 파일)**

v8은 이 디렉토리를 "현재 비어 있음, 향후 추출용"으로 기술했으나 사실과 다르다. 아래 7개 공용 위젯이 이미 추출되어 여러 feature에서 사용 중이다.

`app_button.dart`, `app_card.dart`, `app_dialog.dart`, `app_section.dart`, `app_snackbar.dart`, `app_stat.dart`, `trash_bag_icon.dart`

`lib/features/*/presentation/widgets/`는 현재 `shop` 한 곳에만 존재한다(`shop/presentation/widgets/coupon_thumb.dart`).

### 1-7. feature 목록

`lib/features/` 하위 feature는 9개다.

| feature | data | domain | presentation | 비고 |
|---|---|---|---|---|
| auth | 3 | 1 | 3 | 로그인·회원가입·닉네임 설정 |
| community | 2 | 1 | 5 | 그룹. `data/news_repository.dart`는 `class NewsRepository {}` 빈 스텁 |
| home | 0 | 1 | 1 | data 계층 없음. `domain/eco_math.dart`만 존재 |
| mypage | 1 | 4 | 8 | 활동·임팩트·퀘스트·프로필·뱃지 |
| **news** | 0 | 0 | 3 | v8 미기재. `presentation/`만 존재 |
| plogging | 7 | 6 | 3 | 경로 추천·트래킹·정산 |
| settings | 0 | 0 | 6 | v8은 data·domain에 `.gitkeep`이 있다고 기술했으나 디렉토리 자체가 없다. `.gitkeep`은 `lib/` 전체에 0건 |
| **shop** | 2 | 2 | 4 | v8 미기재. 포인트·쿠폰 담당 |
| vision | 1 | 0 | 2 | domain 계층 없음 |

**`reward` feature는 존재하지 않는다.** v8 1-2 폴더표와 9-5절은 `reward` feature와 `reward_screen.dart`를 전제로 기술하고 있으나, 해당 디렉토리와 파일은 코드에 없다. 에코포인트·쿠폰·상점 기능은 실질적으로 `shop` feature가 담당한다. `/reward` 라우트는 현재 라우터에서 제거되어 있다(1-8 참조).

**`news`와 `shop`은 v8에 서술이 없는 feature다.** v8 9-6절은 뉴스 기능을 `community` feature 하위로 규정하나, 실제 구현은 별도 `news` feature에 있다. `community/data/news_repository.dart`는 빈 스텁이며 실제 뉴스 호출 코드는 `news/presentation/news_service.dart`에 있다. 이 파일의 계층 배치 정정은 코드 정비 대상이며 `docs/2026-08-12-코드정비백로그.md` 항목 I가 다룬다.

### 1-8. 라우팅

`lib/core/router/app_router.dart`에 11개 라우트가 정의되어 있다. `initialLocation`은 `/splash`다(`:102`).

| 경로 | 화면 | 구조 |
|---|---|---|
| `/splash` | `_SplashScreen` (라우터 파일 내 private) | 최상위 |
| `/login` | `LoginScreen` | 최상위 |
| `/nickname-setup` | `NicknameSetupScreen` | 최상위 |
| `/home` | `HomeScreen` | ShellRoute 하위 |
| `/group` | `GroupScreen` | ShellRoute 하위 |
| `/mypage` | `MyActivityScreen` | ShellRoute 하위 |
| `/settings` | `MenuScreen` | ShellRoute 하위 |
| `/plogging/route` | `RouteSetupScreen` | 최상위 |
| `/plogging/tracking` | `PloggingTrackingScreen` | 최상위 |
| `/plogging/settlement` | `SettlementScreen` | 최상위 |
| `/group/feed` | `GroupFeedScreen` | 최상위. `state.extra`로 groupId·groupName 전달 |

v8 감사 시점에 존재하던 `/vision/result`, `/reward`, `/news` 세 라우트와 `core/router/placeholder_screen.dart`는 커밋 `8425794`("refactor: CO2 계수 통합, 홈 핸들러 연결, 죽은 라우트 제거")에서 제거되었다. `docs/audit_v8.md` H절이 기록한 "15개 라우트"와 "placeholder_screen.dart"는 현재 상태와 다르다.

**바텀내비게이션바**는 go_router의 ShellRoute 셸이 담당한다. 셸 위젯은 `app_router.dart` 내부의 private 위젯 `_ScaffoldWithBottomNav`(`:263~`)이며, 4개 탭 화면(`/home`, `/group`, `/mypage`, `/settings`)을 감싸 공통 바를 한 번만 그린다. 각 화면은 본문(body)만 채우며 하단 바를 직접 그리지 않는다. 표준 `BottomNavigationBar`가 아니라 `Stack` + `Container` + `CustomPaint`로 구현한 커스텀 바이며 중앙 돌출 시작 버튼을 포함한다.

중앙 시작 버튼은 탭 전환이 아니라 **화면 push 방식으로 이미 구현되어 있다**(`context.push(AppRoutes.ploggingRoute)`). v8이 잔여 의사결정 #3으로 두었던 항목은 코드상 결정된 상태이므로 5장 잔여 과제에 포함하지 않는다.

탭 간 상태 보존(각 탭의 스크롤·입력 유지)이 필요해지면 `StatefulShellRoute`로의 전환을 검토한다. 향후 과제다.

### 1-9. 화면 목록

`lib/` 내 `*_screen.dart` 파일은 31개다. v8 9장이 실제 파일명으로 서술한 것은 8개이며, 이름이 다르게 적힌 것이 5개, 서술이 아예 없는 것이 18개다.

**2026-08-06 리네임 5건.** v8은 이 리네임을 반영하지 않았다. v9는 전 장에서 아래 오른쪽 이름을 사용한다.

| 구 이름 (v8 표기) | 현행 이름 |
|---|---|
| `plogging_home_screen.dart` | `plogging_tracking_screen.dart` |
| `plogging_session_screen.dart` | `route_setup_screen.dart` |
| `plogging_session_providers.dart` | `destination_providers.dart` |
| `activity_screen.dart` | `my_activity_screen.dart` |
| `camera_screen.dart` | `camera_detection_screen.dart` |

v8 9장이 사용한 `route_screen.dart`·`tracking_screen.dart`·`camera_screen.dart`·`mypage_screen.dart` 표기는 모두 폐기한다. `vision_result_screen.dart`와 `reward_screen.dart`는 v8이 존재를 전제했으나 코드에 없는 파일이므로 목록에서 제외한다.

**v8에 서술이 없던 화면 18개.** v9에서 신규 기술한다.

| feature | 화면 파일 | 역할 |
|---|---|---|
| auth | `signup_screen.dart` | 회원가입 |
| auth | `nickname_setup_screen.dart` | 최초 로그인 후 닉네임 설정. 라우터 redirect 대상 |
| plogging | `settlement_screen.dart` | 플로깅 종료 후 정산 |
| community | `group_create_screen.dart` | 그룹 생성 |
| community | `group_detail_screen.dart` | 그룹 상세 |
| community | `group_feed_screen.dart` | 그룹 피드 |
| community | `group_search_screen.dart` | 그룹 검색 |
| news | `news_detail_screen.dart` | 뉴스 상세. `NewsArticle` 모델 정의 보유 |
| mypage | `profile_screen.dart` | 프로필 편집 |
| settings | `faq_screen.dart` | FAQ |
| settings | `inquiry_screen.dart` | 1:1 문의. Firestore `inquiries` 컬렉션에 기록 |
| settings | `licenses_screen.dart` | 오픈소스 라이선스 |
| settings | `notice_screen.dart` | 공지 목록·상세 (`NoticeListScreen`, `NoticeDetailScreen`) |
| settings | `terms_screen.dart` | 약관 |
| shop | `shop_screen.dart` | 상점 |
| shop | `coupon_list_screen.dart` | 쿠폰 목록 |
| shop | `coupon_detail_screen.dart` | 쿠폰 상세 |
| shop | `point_history_screen.dart` | 포인트 내역 |

`shop/presentation/coupon_screen.dart`는 커밋 `6e667f4`("refactor: coupon_screen.dart 를 3개 파일로 분할")에서 `coupon_list_screen.dart`, `coupon_detail_screen.dart`, `widgets/coupon_thumb.dart` 세 파일로 분할되었다. `docs/audit_v8.md`와 `docs/audit_v8_supplement.md`의 `coupon_screen.dart` 참조는 현재 상태와 다르다.

화면 외 presentation 파일로 `mypage/presentation/badge_dialog.dart`, `mypage/presentation/reward_dialogs.dart`, `vision/presentation/box_painter.dart`, `shop/presentation/widgets/coupon_thumb.dart`가 있다.

### 1-10. Flutter·FastAPI·Firebase 책임 분담

서버는 연산(경로 알고리즘·YOLO 추론·뉴스 수집 및 요약)만 담당한다. 서버 코드에 `firebase-admin`이 없고 Firebase 참조가 0건임을 확인하였다. Firebase 접근은 앱이 전담한다.

| 책임 영역 | 담당 주체 | 비고 |
|---|---|---|
| 인증 (로그인) | 앱 → Firebase Auth | 서버 미관여 |
| 유저 프로필·활동 기록·커뮤니티·포인트 | 앱 → Cloud Firestore | 앱이 직접 읽고 씀 |
| 수거 인증 이미지·프로필 사진 **보관** | 앱 → Firebase Storage | `storage_repository.dart`, `photo_service.dart`, `user_service.dart` |
| 수거 인증 이미지 **분석** | 앱 → 서버 `POST /detect` (multipart) | 분석용 바이너리 전송. 서버는 저장하지 않음 |
| 경로 추천 알고리즘 | 서버 (FastAPI) | 앱은 요청·수신만 |
| YOLO 객체 인식 | 서버 (FastAPI) | 앱은 이미지 전송·결과 수신 |
| 환경 뉴스 수집 + Gemini 요약 | 서버 (FastAPI) | 앱은 `GET /news` 호출 |
| 도보 경로 (Tmap) | 서버 내부 호출 | 앱은 Tmap을 직접 호출하지 않음 |
| 지도 렌더링 | 앱 → Naver Maps SDK | — |
| 역지오코딩 (좌표→주소) | 앱 → `geocoding` 패키지 | 서버 프록시 경유 아님 |
| GPS·걸음·칼로리 트래킹 | 앱 → Foreground Service·Health Connect | — |

**이미지 처리 흐름 정정.** v8은 "Firebase Storage 미사용, 이미지는 서버 직접 수신"으로 규정했으나 사실과 다르다. 현행은 두 경로가 병존한다. 분석용 바이너리는 `POST /detect`로 서버에 전송하고(서버는 저장하지 않음), 인증 사진 자체는 Firebase Storage에 업로드하여 URL을 Firestore에 보관한다. v8의 의사결정 #33·#38 기술은 이 사실로 무효화되므로 5장 잔여 과제에서 제외한다.

**Gemini 뉴스 요약 정정.** v8은 "서버에 키 이름만 존재하고 실제 호출 코드가 없음"으로 규정했으나 사실과 다르다. 서버 `_gemini_enrich()`가 구현되어 있고 `GET /news`가 매 요청마다 호출한다. 앱도 `aiSummary` 필드를 수신·표시 중이다. v8의 의사결정 #39는 해소된 항목이므로 5장에서 제외한다.

**환경 뉴스 데이터 소스 정정.** v8은 "공개 RSS vs FastAPI 크롤러 미확정"으로 두었으나, 서버가 네이버 뉴스 검색 API로 구현을 확정한 상태다. v8의 의사결정 #7은 해소된 항목이므로 5장에서 제외한다.

### 1-11. 인프라 운영 원칙

클라우드는 AWS EC2(Ubuntu)이며 FastAPI가 포트 8000에서 서빙한다(`ploggo-server/server.py:447`). 서버 형상관리는 별도 저장소 `ploggo-server`에서 한다.

Docker 컨테이너화는 미도입 상태다. `ploggo-server` 루트에 Dockerfile·docker-compose 파일이 없다. Stateless 설계 원칙과 확장기 Kubernetes 도입 계획은 향후 과제로 유지한다.

| 항목 | 상태 |
|---|---|
| Dockerfile 작성 | 미도입 (향후) |
| Docker 이미지 빌드·실행 | 미도입 (향후) |
| Kubernetes | 미도입 (확장기 검토) |
| 환경 변수 외부화 (.env) | 적용됨 |
| 상태 비저장(Stateless) 설계 | 적용됨. 서버는 영구 데이터 미보유 |

Kubernetes는 동시 사용자 1,000명 초과, 추론 처리량 한계 도달, 무중단 배포 필요 중 하나가 충족되는 시점에 검토한다. 현 단계(베타 50명)는 단일 EC2로 충분하다.

### 1-12. 데이터 저장 위치

| 데이터 | 저장 위치 | 접근 주체 |
|---|---|---|
| 사용자 계정·인증 | Firebase Auth | 앱 직접 |
| 유저 프로필·활동 기록·커뮤니티·포인트 | Cloud Firestore | 앱 직접 |
| 수거 인증 이미지·프로필 사진 | Firebase Storage | 앱 직접 |
| 1:1 문의 | Firestore `inquiries` 컬렉션 | 앱 직접 |
| CCTV 핫스팟 (1,535개) | 서버 보유 CSV | 서버 (알고리즘) |
| 회피 영역 폴리곤 (147개) | 서버 메모리 (GeoJSON, 시작 시 1회 로드) | 서버 (알고리즘) |
| YOLO 가중치 (12,268,394 B, 약 11.7 MiB, 640×640, 5클래스) | 서버 배치 | 서버 (추론) |
| 외부 API 키 (Tmap·Gemini·네이버 뉴스) | 서버 `.env` | 서버 |

### 1-13. 서버 알고리즘 참고 사항

Flutter 개발과 직접 관련은 낮으나 문서 정합을 위해 유지한다.

- 근접 핫스팟 탐색은 GeoHash 공간 인덱스가 아니라, 출발지·목적지를 두 초점으로 하는 타원형 buffer(기본 1.5km, 강화군 2.5km) 필터와 numpy 전수 거리 계산으로 수행한다. 이웃 밀도는 오프라인에서 BallTree로 사전 계산한다. 데이터가 소규모(1,535개)여서 공간 인덱스의 실익이 없기 때문이다.
- 회피 영역 통과 길이 계산에 경도 방향 cos 보정이 미적용되어 동서 성분에 계통 편향이 있으나, 모든 후보에 동일하게 작용하여 경유지 선정·경로 판정에는 영향이 없다. 앱이 절대 통과 거리(m)를 사용자에게 표시하지 않으므로 현 단계에서 보정은 불필요하다.
- 경유지 방문 순서는 현재 Score 내림차순 고정이다. 순서 최적화는 향후 알고리즘 고도화 단계에서 다룬다.
- 알고리즘 서버 실행은 연산 부하 때문이 아니라 다음 세 가지 운영상 근거에 따른 결정이다. (1) Python 공간 연산 스택(shapely)으로 설계·검증한 자산을 그대로 재사용하여 검증 결과의 일관성을 유지한다. (2) Tmap API 키를 서버에 두고 프록시로 경유하여 키를 보호한다. (3) 회피 영역·핫스팟 데이터를 서버에서 관리하여 앱 재배포 없이 갱신한다.

---

## 2. 서버 API 계약

서버 코드로 확인된 엔드포인트와 스키마다. Flutter Data 계층은 이 계약을 기준으로 구현한다.

### 2-1. baseUrl 규약

서버 접속 주소는 하드코딩하지 않고 `.env`의 `FASTAPI_BASE_URL`로 주입한다.

현재 3개 호출 지점 중 2개(`route_repository.dart:15`, `news_service.dart:13`)가 이 규약을 따르고, `vision/data/detector.dart:62`는 EC2 IP를 하드코딩하고 있어 규약 위반 상태다. 정비 대상이며 `docs/2026-08-12-코드정비백로그.md` 항목 A가 다룬다.

### 2-2. 엔드포인트 목록

| 메서드 | 경로 | 기능 | 앱 호출 여부 |
|---|---|---|---|
| GET | `/` | 루트 상태 확인 | 미호출 |
| GET | `/health` | 상태 확인 | 미호출 |
| GET | `/news` | 환경 뉴스 목록 + Gemini 요약 | 호출 중 (`news_service.dart:26`) |
| POST | `/detect` | 이미지 → 종류·개수·박스 | 호출 중 (`detector.dart`) |
| POST | `/detect_and_crop` | 이미지 → 카운트 + 크롭 이미지(base64) | 미호출 |
| POST | `/route/recommend` | 출발지·도착지 → 회피 우회 K=3 경로 | 호출 중 (`route_repository.dart`) |
| GET | `/route/health` | 경로 모듈 상태 확인 | 미호출 |

`GET /`과 `GET /news`는 v8 엔드포인트 목록에 없던 항목으로 v9에서 추가한다. 특히 `GET /news`는 앱이 실제로 호출하고 있음에도 계약에 누락되어 있었다.

### 2-3. 경로 추천 요청·응답 스키마

**요청 (RouteRequest)**

| 필드 | 필수 | 설명 |
|---|---|---|
| `origin{lat, lon}` | 필수 | 출발지 좌표 |
| `destination{lat, lon}` | 필수 | 도착지 좌표 (지도 마커로 획득) |
| `district` | 선택 | 인천 9개 군구 영문명 |

경유지 수 K는 요청 파라미터가 아니라 서버 환경 변수 `ALGO_K`(기본 3)로 결정된다.

**응답 (RouteResponse)**

| 필드 | 설명 |
|---|---|
| `success` | 성공 여부 |
| `is_hard_case` | swap 후에도 회피 영역 통과가 남은 경우 true |
| `intersection_m` / `intersection_ratio` | 회피 영역 통과 길이(m) / 비율 |
| `crossed_uqa_codes[]` | 통과한 회피 영역 코드 목록 |
| `polyline[[lat,lon]]` | 경로 좌표 배열 (지도 렌더링용) |
| `distance_m` / `duration_ms` | 총 거리 / 예상 소요시간 |
| `n_swaps` | swap 시도 횟수 |
| **`best_from_attempt`** | `Optional[int]`. 최종 채택된 경로가 몇 번째 시도에서 나왔는지. v8 응답표에 없던 필드로 v9에서 추가 |
| `k3_hotspots[]` | 선정 핫스팟 목록. 각 항목은 `hotspot_id`, `latitude`, `longitude`, `S_i`, `avoid_penalty` 5개 필드 |

Tmap 응답 실패 시 서버가 HTTP 502로 반환한다. Data 계층에서 502를 별도 처리하고 Presentation에서 사용자 메시지를 노출한다. 현재 `route_repository.dart:87~93`에 502 분기가 구현되어 있다.

### 2-4. 비전 응답 스키마 (`POST /detect`)

요청은 `multipart/form-data`의 `file` 필드로 이미지 바이너리를 전송한다.

| 필드 | 설명 |
|---|---|
| `success` | 성공 여부 |
| `image_size{width, height}` | 이미지 크기 |
| `detections[]` | `class_id`, `class_name`, `confidence`, `box`, `box_pixel` |
| `counts{클래스명: int}` | 클래스별 개수 |
| `total` | 총 개수 |

클래스명은 `can`, `glass`, `paper`, `plastic`, `trash` 5종이다. 한글 표기는 캔·유리·종이·플라스틱·일반쓰레기로 통일한다(일반쓰레기 = `trash`). YOLO 입력 크기는 640×640이다.

### 2-5. 뉴스 응답 스키마 (`GET /news`)

서버가 네이버 뉴스 검색 API로 환경 뉴스를 수집하고, 각 기사에 Gemini 2.5 Flash로 요약·카테고리·언론사명을 부가하여 반환한다. 앱은 `aiSummary` 필드를 수신하여 화면에 표시한다.

서버 모델 기본값은 `GEMINI_MODEL` 환경 변수로 지정하며 기본값은 `gemini-2.5-flash`다. 네이버 검색 키(`NAVER_NEWS_CLIENT_ID`/`SECRET`)와 Gemini 키는 서버에만 존재한다.

### 2-6. 목적지 입력 방식

- 목적지는 지도에서 마커를 이동하여 지정하며, 그 지점의 위경도를 직접 획득한다. 주소·장소명 검색 방식이 아니므로 주소→좌표 지오코딩이 필요 없다. 서버 `/route/recommend`가 좌표를 직접 받는 구현과 정합한다.
- Naver 지오코딩 프록시는 사용하지 않는다. 서버에 해당 엔드포인트가 없다.
- 다만 앱은 `geocoding` 패키지로 **좌표→주소 역변환**을 사용 중이다(`location_repository.dart:3, :44`). v8은 이 용도를 서술하지 않았다. 역지오코딩은 지도에 표시할 지명 표기용이며 경로 계산과 무관하다.

---

## 3. 3-Layer 규약

### 3-1. 기본 방향

Feature-First 3-Layer 구조를 유지한다. 각 feature는 `presentation`(화면), `domain`(비즈니스 로직·모델·Provider), `data`(외부 데이터 접근) 세 계층으로 구성한다.

기본 의존 방향은 하향 단방향이다.

```
presentation  →  domain  →  data
```

- presentation은 domain Provider를 watch한다. data를 직접 import하지 않는다.
- domain은 data의 Repository를 호출한다. presentation을 알지 못한다.
- data는 외부 SDK·API를 호출한다. presentation을 알지 못한다.

### 3-2. 예외 규칙 (1) — data는 domain의 모델·엔티티를 참조할 수 있다

**data 계층은 domain 계층의 모델·엔티티를 import할 수 있다. domain의 Notifier·Provider는 참조하지 않는다. presentation은 어떤 경우에도 참조하지 않는다.**

근거는 다음과 같다. `docs/2026-08-12-코드정비백로그.md` 항목 R의 구분표에 따르면, 현재 data → domain import 10건은 **전부 도메인 모델·엔티티 참조**이며 Notifier·Provider 참조는 0건이다. 대상 9개 파일 중 어느 것도 `Provider`·`Notifier`를 정의하지 않는다. 10건 모두 Repository가 Firestore 문서를 도메인 타입으로 매핑하기 위해 모델 정의를 참조하는 형태다.

이 참조를 금지하면 Repository가 도메인 타입을 반환할 수 없게 되어 data 전용 DTO 계층 신설과 DTO↔도메인 변환 코드가 강제된다. 현재 규모에서 그 비용이 얻는 이득보다 크므로 허용으로 확정한다.

이에 따라 기존 10건은 규약 위반이 아니다.

### 3-3. 예외 규칙 (2) — 라우터의 presentation import

**`lib/core/router/app_router.dart`가 feature의 presentation을 import하는 것은 위반이 아니다.** go_router 라우트 테이블이 화면 위젯을 참조하는 것은 구조적 필연이기 때문이다. 현재 10건이 이에 해당한다.

이 예외는 `app_router.dart`에만 적용한다. `lib/core/`의 다른 파일이 presentation을 import하는 것은 위반이다. 현재 `core/view_models/screen_views.dart`의 2건이 여기 해당하며 정비 대상이다.

### 3-4. HTTP 클라이언트 표준

**서버 통신 HTTP 클라이언트는 `dio`를 표준으로 한다.** 타임아웃·재시도·오류 매핑 정책을 한 곳에서 관리하기 위함이다.

현재 3개 호출 지점 중 `route_repository.dart`만 dio를 사용하고, `detector.dart`와 `news_service.dart`는 `package:http`를 사용한다. 502 등 서버 오류 분기도 `route_repository.dart`에만 있다. 나머지 두 지점의 dio 전환은 정비 대상이다.

### 3-5. 위반 현황

현재 계층 규약 위반 수치는 다음과 같다. 위반 건별 파일·라인 상세와 정비 방향은 `docs/2026-08-12-코드정비백로그.md`가 관할하며 본 문서는 중복 기재하지 않는다.

| 규약 | 위반 건수 | 대상 파일 수 | 백로그 항목 |
|---|---|---|---|
| presentation → data 직접 import 금지 | 35 | 21 | D |
| `core/` (라우터 제외) → presentation 참조 금지 | 2 | 1 | H |
| data → domain 모델 참조 | 0 (3-2로 허용 확정) | — | R (해소) |
| data → presentation 참조 금지 | 0 | — | — |
| HTTP 클라이언트 dio 표준 | 2 | 2 | Q |

부수적으로, 비동기 상태를 `AsyncValue`가 아닌 `setState`·boolean 플래그로 관리하는 사례가 39건(19개 파일), provider 접근이 필요하나 Consumer를 상속하지 않은 공개 위젯이 13개(13개 파일) 있다. 상세는 백로그 항목 E·F·G가 다룬다.

### 3-6. Provider 선정 기준

| 상황 | 사용할 Provider |
|---|---|
| 단순 읽기 전용 데이터 (설정 로드, 단건 Firestore read) | `FutureProvider` 또는 `StreamProvider` |
| 사용자 액션으로 상태 변경 (경로 요청, 수거 인증, 저장, 로그인) | `AsyncNotifier` |
| 동기 상태 (토글, 카운터) | `Notifier` |

- 로딩·에러 boolean 플래그를 수동 관리하지 않는다. `AsyncValue`를 사용한다.
- 비동기 처리는 `AsyncValue.guard`로 감싼다.
- UI에서는 `AsyncValue.when(data:, loading:, error:)` 패턴으로 분기한다.
- 단일 원본(Single Source of Truth)을 유지하고, 순차 데이터는 상위 Provider 값을 하위 입력으로 연결한다.
- Riverpod은 2.x를 사용한다. 3.x 마이그레이션은 별도 의사결정 전까지 보류하며, 3.x 전용 API를 임의로 사용하지 않는다.

현재 `AsyncValue.guard` 사용은 `plogging/domain/route_notifier.dart:23` 1곳뿐이다. 이 규약은 목표 상태이며 현행 대부분의 화면이 아직 따르지 않는다.

### 3-7. 참조 구현 (경로 요청)

현재 코드에서 3-Layer 규약을 온전히 따르는 유일한 흐름이다. 신규 feature 작성 시 이 구조를 참조한다.

- Data: `plogging/data/route_repository.dart`가 dio로 `POST /route/recommend`를 호출한다. HTTP 502를 별도 분기한다.
- Domain: `plogging/domain/route_notifier.dart`가 `AsyncNotifier<RouteResult?>`로 요청 상태를 관리하고 `AsyncValue.guard`로 감싼다.
- Presentation: `plogging/presentation/route_setup_screen.dart`가 상태를 구독하여 Naver Maps에 polyline을 렌더링하고 오류 메시지를 노출한다.

### 3-8. 점진적 디렉토리 확장

다음 하위 디렉토리는 필요 시점에만 추가한다. 처음부터 만들지 않는다.

| 디렉토리 | 추가 시점 |
|---|---|
| `features/{f}/presentation/widgets/` | 한 화면이 위젯으로 쪼개지기 시작할 때 (200줄 초과 기준) |
| `features/{f}/domain/models/` | 도메인 모델이 2개 이상 생길 때 |
| `features/{f}/data/dto/` | 서버·Firestore 응답 매핑이 복잡해질 때 |

빈 디렉토리를 `.gitkeep`으로 미리 만들지 않는다. `lib/` 전체에 `.gitkeep`은 0건이며 이 방침과 정합한다.

---

## 4. 코딩 규칙

### 4-1. Flutter 코딩 규칙

- 색상 투명도는 `withOpacity()`가 아니라 `color.withValues(alpha: value)`를 사용한다. named parameter로 호출하며 alpha 범위는 0.0~1.0이다. 현재 `withOpacity` 사용은 0건이다.
- 서버 접속 주소·API 키는 하드코딩하지 않고 `.env`로 관리한다.
- 코드 수정 시 전체 파일을 덮어쓰지 않는다. 수정이 필요한 부분만 발췌하여 변경한다.
- 코드 내 주석은 한국어로 작성한다.
- Naver Maps 좌표는 `NLatLng(lat, lng)`을 사용한다. Google Maps의 `LatLng`와 혼동하지 않는다. Google Maps 관련 패키지는 본 프로젝트에서 사용하지 않는다.
- 동일 패키지 내부 import는 상대 경로(`../`)가 아니라 패키지 경로(`package:repo_jdh/...`)를 사용한다. 현재 위반 6건이 있으며 백로그 항목 N이 다룬다.
- 릴리스 코드에서 `print`를 사용하지 않는다. `debugPrint` 또는 로깅 유틸리티를 사용한다. 현재 위반 52건이 있으며 백로그 항목 K가 다룬다.

### 4-2. 색상

**primary color는 초록 계열 `#17855A`다.** `app_colors.dart`에서 `green600`으로 정의되고 `actionPrimary`·`textBrand`·`success` 등 시맨틱 이름으로 노출된다.

v8이 기준으로 삼은 파스텔 블루 `#6BA3E8`은 `lib/` 전체에서 0건이다. v8 5-1의 색상 서술과 의사결정 #37("primary color 최종 조정")은 존재하지 않는 값을 전제로 하고 있어 무효이므로 v9에서 정정하고 5장 잔여 과제에서 제외한다.

색상 사용 규칙은 `app_colors.dart` 상단 주석에 정의되어 있다.

- 화면 코드에서는 시맨틱 이름만 사용한다. `green600` 같은 스케일 값을 직접 참조하지 않는다.
- `actionPrimary`(꽉 찬 초록)는 화면당 하나만 사용한다. 두 번째 버튼은 `actionSecondary`를 사용한다.
- `@Deprecated`가 붙은 별칭(`primary`, `primaryMuted`, `mintDeep`, `info`)은 신규 코드에서 사용하지 않는다.

### 4-3. 명명 규칙

| 대상 | 규칙 | 예시 |
|---|---|---|
| data 파일 | `{대상}_repository.dart` | `auth_repository.dart`, `location_repository.dart` |
| domain Notifier | `{기능}_notifier.dart` | `route_notifier.dart` |
| domain 모델 | `{대상}.dart` | `activity.dart`, `shop_item.dart` |
| presentation 화면 | `{기능}_screen.dart` | `login_screen.dart`, `route_setup_screen.dart` |
| presentation 보조 위젯 | `{이름}.dart` (스네이크 케이스) | `coupon_thumb.dart` |
| 클래스 | 파스칼 케이스 | `AuthRepository`, `RouteSetupScreen` |

`_service.dart` 명명은 사용하지 않는다. 외부 서비스 접근 클래스도 `_repository.dart`로 통일한다. 현재 위반 9건이 있으며 백로그 항목 I·J가 다룬다.

코드 생성기가 만든 `.g.dart` 파일은 직접 수정하지 않는다. 생성 명령은 다음과 같다.

```
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4-4. Git 커밋 규칙

커밋 메시지는 다음 prefix를 사용한다.

| prefix | 사용 상황 |
|---|---|
| `feat:` | 새로운 기능 추가 |
| `fix:` | 버그 수정 |
| `refactor:` | 기능 변경 없는 코드 개선 |
| `chore:` | 설정 파일, 패키지 등 변경 |
| `docs:` | 문서 수정 |

`update:` 등 위 목록 외의 prefix는 사용하지 않는다. 과거 이력의 미준수 건은 소급 정정하지 않는다.

### 4-5. 작업 후 확인

- 코드 변경 후 `flutter analyze`로 오류·경고를 확인한다. 현재 61건(error 0 / warning 3 / info 58)이 미해소 상태이며 백로그 항목 K·L·M이 다룬다.
- 신규 파일 생성 시 4-3 명명 규칙을 준수한다.
- presentation에서 data를 직접 import하지 않았는지 3장 규약 기준으로 점검한다.

---

## 5. 잔여 과제

미완료 작업과 미해소 의사결정 항목을 하나의 목록으로 통합한다. v8의 STEP 미완료 항목과 6-2 잔여 의사결정 표를 여기로 흡수하였다.

**코드 결함 정비 항목(3-Layer 위반, setState 오용, 하드코딩 등)은 본 장에 중복 기재하지 않는다.** `docs/2026-08-12-코드정비백로그.md`가 관할한다.

### 5-1. 잔여 과제 목록

| # | 항목 | 성격 | 현재 상태 | 관련 절 |
|---|---|---|---|---|
| R-1 | 에코포인트 산출 공식 확정 (수거 쓰레기 종류·개수 → 포인트 환산 기준) | 의사결정 | 미확정. 클래스명은 can·glass·paper·plastic·trash로 통일됨 | 본 문서 2-4 |
| R-2 | 경유지 수 K의 요청 파라미터화 협의 | 의사결정 | 현재 서버 환경 변수 `ALGO_K`(기본 3). 사용자가 활동 강도를 선택하는 UX로 확장하려면 서버가 K를 요청 파라미터로 받도록 협의 필요 | 본 문서 2-3 |
| R-3 | `ALGO_HARD_CASE_M` 코드 연결 또는 변수 제거 | 의사결정 | 서버 `.env.example:15`에 100으로 정의되어 있으나 `config.py`·`algorithm.py` 어디에서도 참조하지 않는다. `is_hard_case` 판정이 이 임계값과 연결되어 있지 않다. 앱 동작에는 영향 없음 | 서버 |
| R-4 | Tmap Pedestrian 무료 한도·종량제 단가 확인 | 조사 | 미확인 | 본 문서 1-10 |
| R-5 | EC2 인스턴스 사양 확정 (vCPU, RAM) | 의사결정 | 저장소 파일로 확인 불가 | 본 문서 6-3 |
| R-6 | Docker 컨테이너화 도입 | 구현 | 미도입. Dockerfile·compose 부재 | 본 문서 1-11 |
| R-7 | Kubernetes 도입 | 구현 | 미도입. 확장기 조건 충족 시 검토 | 본 문서 1-11 |
| R-8 | `vision` feature의 domain 계층 신설 | 구현 | `vision/domain/` 디렉토리 자체가 없다. data(`detector.dart`)와 presentation 사이에 AsyncNotifier 계층이 없다 | 본 문서 1-7 |
| R-9 | `home` feature의 data 계층 신설 | 구현 | `home/data/` 없음. 홈 화면 데이터는 `core/view_models/screen_views.dart`가 조립한다. 현행 구조를 유지할지 data 계층을 만들지 미결정 | 본 문서 1-7 |
| R-10 | `settings` feature의 data·domain 계층 | 구현 | 현재 presentation만 존재. 3-8에 따라 필요 시점에만 추가하므로 즉시 과제는 아님 | 본 문서 3-8 |
| R-11 | `StatefulShellRoute` 전환 검토 | 의사결정 | 현재 `ShellRoute`. 탭 간 상태 보존이 필요해지는 시점에 검토 | 본 문서 1-8 |
| R-12 | `community/data/news_repository.dart` 빈 스텁 처리 | 구현 | `class NewsRepository {}` 한 줄. 실제 뉴스 구현은 `news` feature에 있다. 백로그 항목 I와 함께 처리 방침 결정 필요 | 본 문서 1-7 |
| R-13 | 미사용 패키지 제거 여부 (`dart_geohash`, `google_generative_ai`) | 의사결정 | 두 패키지 모두 코드 사용처 0건 | 본 문서 1-1 |
| R-14 | `ACCESS_BACKGROUND_LOCATION`·`WRITE_EXTERNAL_STORAGE` 권한 필요성 검토 | 조사 | 선언되어 있으나 실제 필요 여부 미검증. 불필요 시 스토어 심사 리스크 감소 | 본 문서 1-4 |
| R-15 | `core/dev/` 개발용 시드 코드 처리 | 의사결정 | 566줄이 릴리스 경로에 포함. 활성화 플래그는 모두 `false`이나 시드 버튼 UI는 빌드 모드로 분기되지 않는다. 정비 여부 결정 유보 상태 | 백로그 5장 부록 |
| R-16 | 유효 테스트 도입 | 구현 | `test/widget_test.dart`가 Flutter 카운터 템플릿 원본이며 실행 시 실패한다. 유효 테스트 0개. CI 도입 전 처리 필요 | 백로그 항목 C |
| R-17 | 정식 출시 시 플로깅 시작 조건 강화 | 구현 | 현재 도착지 설정 시 활성화. "경로 추천 성공 시에만 시작 가능"으로 조일지 결정 | `docs/TODO.md` (가) |
| R-18 | 도착지 자동 추천 디바운스 적용 | 구현 | 짧은 시간 연속 탭 시 요청 몰림 방지 미적용 | `docs/TODO.md` (나) |
| R-19 | 추적 화면 정적 지도 이미지를 실제 NaverMap으로 교체 | 구현 | `PloggingTrackingScreen`의 지도가 정적 이미지. `currentLocation`/`destination`/`routeNotifier` provider 공유 watch 필요 | `docs/TODO.md` (다) |

### 5-2. v8 잔여 항목 중 v9에서 제외한 것

v8 6-2의 잔여 의사결정 항목 중 아래는 코드 확인 결과 이미 해소되었거나 전제가 무효이므로 v9 잔여 과제에서 제외한다.

| v8 번호 | 항목 | 제외 사유 |
|---|---|---|
| #3 | 바텀내비 시작 버튼 동작 방식 (탭 전환 vs push) | push로 이미 구현됨 (`context.push(AppRoutes.ploggingRoute)`) |
| #7 | 환경 뉴스 데이터 소스 (RSS vs 크롤러) | 네이버 뉴스 검색 API로 확정 구현됨 |
| #37 | primary color 최종 조정 | 기준으로 삼은 `#6BA3E8`이 코드에 없어 항목 전제가 무효. 현행은 `#17855A` |
| #38 | Firebase Storage 이미지 전환 여부 | 이미 전환·사용 중 (3개 파일) |
| #39 | Gemini 뉴스 요약 서버 구현 | 구현 완료. 앱도 수신·표시 중 |
| #41 | 설정 화면 폴더·파일명 정합 | `settings` feature의 `menu_screen.dart`로 확정. 4-3 명명 규칙 정비 대상으로 백로그가 관할 |
| — | `.env.example`의 `GEMINI_API_KEY`·`NAVER_MAP_CLIENT_SECRET` 제거 | 2026-08-12 삭제·커밋 완료 (본 문서 6-1) |

---

## 6. 환경 구성

### 6-1. Flutter `.env` 키

앱에 포함되는 `.env`에는 클라이언트에서만 필요한 값만 둔다. 서버 전용 키는 서버 `.env`에만 보관한다.

`.env.example`(팀 공유용 양식, Git 추적 대상)의 현재 키는 2개다.

| 키 | 설명 | `.env.example` 라인 | 코드 참조 |
|---|---|---|---|
| `NAVER_MAP_CLIENT_ID` | Naver Maps SDK 지도 렌더링용 Client ID | `:6` | `lib/main.dart:29` |
| `FASTAPI_BASE_URL` | 서버 접속 주소 | `:9` | `news_service.dart:13`, `route_repository.dart:15` |

키 이름은 `NAVER_MAP_CLIENT_ID`(MAP 단수)다. v8과 PLAN.md가 표기한 `NAVER_MAPS_CLIENT_ID`(MAPS 복수)는 코드와 다르므로 v9에서 정정한다.

`GEMINI_API_KEY`와 `NAVER_MAP_CLIENT_SECRET`은 2026-08-12에 `.env.example`에서 삭제·커밋되었다(`.env.example:3` 주석에 사유 기록). 앱이 참조하지 않는 서버 전용 키였다. 해소된 항목이므로 잔여 과제에 두지 않는다.

`.env` 자체는 `.gitignore:123~124`로 무시되며 `:127`의 `!.env.example`로 예시 파일만 추적한다. `git log --all -- .env` 결과 커밋 이력은 없다.

`.env` 파일은 `pubspec.yaml:95`에 에셋으로 선언되어 있어, 신규 클론 시 `.env`를 생성하지 않으면 앱과 테스트 모두 빌드되지 않는다. 처리 방향은 백로그 항목 B가 다룬다.

### 6-2. 서버 `.env` 키 (앱과 무관, 참고)

| 키 | 설명 |
|---|---|
| `TMAP_APP_KEY` | Tmap Pedestrian API 호출 |
| `TMAP_TIMEOUT_S` | Tmap 호출 타임아웃 |
| `GEMINI_API_KEY` | Gemini 호출 |
| `GEMINI_MODEL` | 기본값 `gemini-2.5-flash` |
| `NAVER_NEWS_CLIENT_ID` / `NAVER_NEWS_CLIENT_SECRET` | 네이버 뉴스 검색 API |
| `NAVER_MAPS_CLIENT_SECRET` | 서버 `.env.example`에 존재 |
| `ALGO_ALPHA` / `ALGO_BETA` / `ALGO_GAMMA` | 알고리즘 가중치 (기본 0.5 / 0.5 / 1.0) |
| `ALGO_K` / `ALGO_BF_TOP_N` / `ALGO_MAX_SWAP` | 경유 수·후보풀·swap 한도 (기본 3 / 15 / 5) |
| `ALGO_HARD_CASE_M` | hard case 판정 임계 (기본 100m). 정의만 되어 있고 코드가 참조하지 않는다 (R-3) |
| `AVOID_ZONES_GEOJSON` / `HOTSPOTS_CSV` | 정적 데이터 파일 경로 |

v8이 서버 `.env` 키로 기재한 `VWORLD_KEY`는 서버 `.env.example`에 존재하지 않는다. v9에서 목록에서 제외한다.

### 6-3. 외부 콘솔 등록 상태 — 저장소 파일로 확인 불가 (4건)

아래 4건은 외부 콘솔·인프라 상태이므로 저장소 파일만으로는 등록 여부를 판정할 수 없다. 삭제하지 않고 유지하되, 확인 방법을 함께 기술한다.

| # | 항목 | 확인 불가 사유 | 확인 방법 |
|---|---|---|---|
| V-1 | Firebase 프로젝트·앱 등록 | `google-services.json`이 `.gitignore:130`으로 비추적이라 저장소에 없다. `Firebase.initializeApp()` 호출 코드는 존재한다 | Firebase Console에서 `com.ploggo.app` Android 앱 등록 여부 확인 |
| V-2 | Google 로그인 SHA-1 지문 등록 | Firebase Console 상태다. 저장소로 확인 불가 | Gradle `signingReport` 또는 `keytool`로 지문을 얻고 Console 등록 목록과 대조. 각 개발자 PC 디버그 키스토어, 릴리스 키스토어, Play 앱 서명 SHA-1 세 종류가 모두 필요하다 |
| V-3 | NCP Application 등록 | NCP 콘솔 상태다. 저장소로 확인 불가 | NCP 콘솔 > AI·Application Service > Application에서 Maps(Mobile Dynamic Map) 활성화 및 Android 패키지명 `com.ploggo.app` 등록 확인 |
| V-4 | EC2 인스턴스 사양 | 저장소에 서버 코드만 있고 인프라 정의 파일이 없다. `server.py:447`로 포트 8000만 확인된다 | AWS 콘솔에서 인스턴스 타입·vCPU·RAM 확인 (R-5와 연결) |

Tmap Pedestrian API 등록은 서버 `.env.example`에 `TMAP_APP_KEY` 키가 정의되어 있고 서버 코드가 이를 환경 변수로만 읽으며 하드코딩이 없음을 확인하였다. 다만 실제 발급·유효 여부는 SK Open API 콘솔 상태이므로 동일하게 저장소로는 확인할 수 없다.

---

## 부록 A. v3~v9 변경 이력

v8의 8·9·10장을 통합하고 v9 변경을 추가한다. 본문에서 제거한 버전 마커(v3~v8 6세트)의 의미는 아래 표로 대체한다.

### A-1. v3~v8 요약

| 버전 | 핵심 변경 |
|---|---|
| v3 | 지도·경로 API를 Google에서 Naver로 통합. Waypoint 알고리즘 처리 위치 확정. 패키지명 `com.ploggo.app` 확정. Firebase Storage 기반 이미지 흐름 보강. Flutter·FastAPI·Firebase 책임 분담 명확화 |
| v4 | 알고리즘 1차 검증 결과 반영. 백엔드 인프라 결정 추가(AWS EC2, Docker, K8S 도입 시점). GT 평가 방식 명시. 인프라 운영 원칙 절 신설 |
| v5 | 도보 경로 API를 Naver Directions 5에서 Tmap Pedestrian으로 전환. Naver Maps SDK는 지도 렌더링 용도로 유지 |
| v6 | 경로 알고리즘을 Flutter에서 FastAPI로 전량 이관. 서버는 연산만, Firebase 접근은 앱 전담으로 확정. 이미지 처리를 서버 직접 수신으로 확정. 서버 API 계약 신규 명시. 목적지 입력을 지도 마커 좌표 획득으로 확정. GeoHash 표기를 타원 buffer + numpy로 정정 |
| v7 | 문서 정합성 검수. 바텀내비 위치를 `core/widgets/`로 확정. Gemini 뉴스 요약을 미구현으로 표기. `ALGO_HARD_CASE_M`을 코드 미참조로 표기. 설정 화면 구조를 known issue로 명시 |
| v8 | 바텀내비 실제 코드 위치를 ShellRoute 셸로 정정. `core/widgets/`를 "비어 있음"으로 정정(이 정정은 v9에서 다시 정정됨) |

### A-2. v8 → v9 변경

v9는 `docs/audit_v8.md`(약 130건 대조, 불일치 55건)와 `docs/audit_v8_supplement.md`의 결과를 반영한 정합성 갱신이다. 아키텍처 결정 자체의 변경은 3-2·3-3·3-4 세 규칙의 명문화뿐이며, 나머지는 문서를 코드 현행에 맞춘 것이다.

| 구분 | 항목 | v8 | v9 |
|---|---|---|---|
| 구조 | STEP 1~9 번호 체계 | 9개 STEP + 완료/미완료 체크박스 | 폐기. 완료분은 1장 흡수, 미완료분은 5장 이관 |
| 구조 | 장 구성 | 0~10장 (변경이력 3개 장 분산) | 0~6장 + 부록 A·B |
| 정정 | `core/widgets/` | "현재 비어 있음" | 7개 파일 존재 |
| 정정 | Firebase Storage | "미사용, 향후 검토" | 3개 파일에서 사용 중. 분석용 서버 전송과 병존 |
| 정정 | Gemini 뉴스 요약 | "미구현, 서버에 키만 존재" | 서버 구현 완료, 앱이 수신·표시 중 |
| 정정 | 환경 뉴스 데이터 소스 | RSS vs 크롤러 미확정 | 네이버 뉴스 검색 API로 확정 |
| 정정 | primary color | 파스텔 블루 `#6BA3E8` | 초록 `#17855A` (`green600`) |
| 정정 | `.env` 키 이름 | `NAVER_MAPS_CLIENT_ID` | `NAVER_MAP_CLIENT_ID` |
| 정정 | flutter_naver_map | 1.3.1 | 1.4.4 |
| 정정 | Flutter / Dart | 3.41.5 / 3.11.3 | 3.44.2 / 3.12.2 |
| 정정 | 폰트 | Noto Sans KR | Pretendard(메인) + NotoSansKR(백업) |
| 정정 | 초기화 순서 | dotenv → Firebase → NaverMap | Firebase → dotenv → NaverMap |
| 정정 | 화면 파일명 | `route_screen`, `tracking_screen`, `camera_screen`, `mypage_screen` | 2026-08-06 리네임 5건 반영 |
| 정정 | 서버 `.env` | `VWORLD_KEY` 기재 | 제외. 서버 `.env.example`에 없음 |
| 정정 | 3-Layer 위반 규모 | vision domain 부재 1건 | presentation → data 35건 등. 상세는 백로그 참조 |
| 추가 | `news` feature | 미기재 | 1-7에 신규 기술 |
| 추가 | `shop` feature | 미기재 | 1-7에 신규 기술 |
| 추가 | `core/dev/`, `core/view_models/`, `core/constants/` | 미기재 | 1-6에 신규 기술 |
| 추가 | 문서화되지 않은 화면 18개 | 미기재 | 1-9에 신규 기술 |
| 추가 | Dart 패키지명 `repo_jdh` | 미기재 | 1-2에 명시 |
| 추가 | `GET /`, `GET /news` | 엔드포인트 목록에 없음 | 2-2에 추가 |
| 추가 | `best_from_attempt` | 응답표에 없음 | 2-3에 추가 |
| 추가 | 역지오코딩 용도 | 미기재 | 2-6에 명시 |
| 추가 | `ACCESS_BACKGROUND_LOCATION` 등 권한 2종 | 미기재 | 1-4에 추가 |
| 삭제 | `reward` feature | 존재 전제 | 코드에 없음. `shop`이 실질 대체 |
| 삭제 | `/vision/result`, `/reward`, `/news` 라우트 | 존재 | 커밋 `8425794`에서 제거됨 |
| 신규 규칙 | data → domain 모델 참조 | 미규정 | 3-2에서 허용으로 확정 |
| 신규 규칙 | 라우터의 presentation import | 미규정 | 3-3에서 예외로 확정 |
| 신규 규칙 | HTTP 클라이언트 | dio 전제이나 미명문화 | 3-4에서 dio 표준으로 확정 |

---

## 부록 B. 문서 체계

각 문서의 관할 범위와 우선순위를 정의한다. 서술이 충돌할 경우 아래 순서로 판단한다.

### B-1. 현행 기준 문서

| 문서 | 관할 | 우선순위 |
|---|---|---|
| `docs/guideline_v9.md` (본 문서) | 아키텍처, 서버 API 계약, 계층 규약, 코딩 규칙, 잔여 과제, 환경 구성 | **최우선.** 다른 문서와 충돌하면 본 문서를 따른다 |
| `docs/PLAN.md` | 프로젝트 비전, 성과 목표, 일정, 팀 운영 | 해당 영역에 한정. 기술 사실이 본 문서와 다르면 본 문서를 따른다 |
| `docs/TODO.md` | 미이행 작업 백로그 | 본 문서 5장과 중복되는 항목은 5장 R-17~R-19로 흡수되어 있다 |
| `docs/2026-08-12-코드정비백로그.md` | 코드 결함 정비 대상 (위반 건별 파일·라인, 위험도, 착수 순서) | 코드 정비 영역의 단일 출처. 본 문서 3-5는 수치만 인용한다 |

저장소 루트에 `CLAUDE.md`를 두지 않는다. 2026-08-13 결정이며, 사유는 다음과 같다. 코드 정비가 완료되기 전에는 규칙 문서와 실제 코드의 괴리가 커서 에이전트가 규칙에 맞추려 광범위한 리팩터링을 시도할 여지가 있다. 코드 작성 규칙은 본 문서 3장과 4장이 담당한다.

Claude Code는 저장소 루트의 `CLAUDE.md`를 세션 시작 시 자동으로 읽으나 본 문서는 자동으로 읽지 않는다. 따라서 규칙 준수가 필요한 작업을 지시할 때는 본 문서의 3장과 4장을 참조하도록 명시한다.

재검토 시점은 `docs/2026-08-12-코드정비백로그.md`의 정비가 완료된 이후로 한다.

### B-2. 시점 기록물 — 현행 기준이 아님

아래는 특정 시점의 상태를 기록한 작업 로그다. **현행 기준으로 인용하지 않는다.**

- `docs/archive/` 하위 전체
- 날짜가 붙은 문서(`YYYY-MM-DD-*.md`) 전반. 예: `docs/2026-07-01-프론트엔드현황.md`, `docs/2026-08-06-화면구조정리.md`
- `docs/guideline_v3.md` ~ `docs/guideline_v8.md`
- `docs/audit_v8.md`, `docs/audit_v8_supplement.md` — 2026-08-10~12 시점의 감사 기록이다. 본 문서의 근거 자료이지만, 그 이후 코드가 변경된 부분이 있으므로 현행 사실 확인에는 사용하지 않는다

`docs/2026-08-12-코드정비백로그.md`는 날짜가 붙어 있으나 예외로 현행 기준 문서다. 정비가 완료되면 항목을 갱신하여 유지한다.

### B-3. 감사 문서 이후 변경된 사항

`docs/audit_v8.md`(2026-08-10)와 `docs/audit_v8_supplement.md`(2026-08-12) 작성 이후 코드가 변경되어, 두 문서의 아래 서술은 현재 상태와 다르다. 본 문서 작성 시점(2026-08-13, 커밋 `66e28d7`) 기준으로 정리한다.

| 감사 문서 서술 | 현재 상태 | 변경 커밋 |
|---|---|---|
| 라우트 15개, `core/router/placeholder_screen.dart` 존재, `/vision/result`·`/reward`·`/news` 라우트 존재 | 라우트 11개. `placeholder_screen.dart` 및 3개 라우트 제거됨 | `8425794` |
| `shop/presentation/coupon_screen.dart` (`CouponScreen`, `CouponDetailScreen` 포함) | `coupon_list_screen.dart`, `coupon_detail_screen.dart`, `widgets/coupon_thumb.dart` 3파일로 분할 | `6e667f4` |
| `.env.example`에 4개 키 (`GEMINI_API_KEY`, `NAVER_MAP_CLIENT_SECRET` 포함) | 2개 키 (`NAVER_MAP_CLIENT_ID`, `FASTAPI_BASE_URL`) | 2026-08-12 |
| `lib/core/constants/` 디렉토리 없음 | `eco_constants.dart` 존재 | — |
| `features/*/presentation/widgets/` 디렉토리 0개 | `shop/presentation/widgets/` 1개 존재 | `6e667f4` |
| presentation → data import 34건 | 35건 | — |

`flutter analyze` 결과는 두 시점 모두 61건(error 0 / warning 3 / info 58)으로 동일하다. 다만 `deprecated_member_use` 2건의 위치가 `coupon_screen.dart:300`에서 `coupon_detail_screen.dart:63`으로 이동하였다.

---

문서 끝
