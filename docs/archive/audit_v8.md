# guideline_v8.md 코드 대조 감사 (2026-08-10)

감사 대상 문서: `Repo_JDH/docs/guideline_v8.md`
대조 저장소: `Repo_JDH`(Flutter 앱), `ploggo-server`(FastAPI 서버)
감사 범위: 문서의 검증 가능한 사실 서술 전수. 코드·문서 수정 없음(읽기 전용).

판정 정의
- **일치**: 문서 서술과 코드 실제가 같다.
- **불일치**: 문서 서술과 코드 실제가 다르다.
- **문서 누락**: 코드에 존재하나 문서에 서술이 없다.
- **검증 불가**: 저장소 내 파일로 확인할 수 없다(외부 콘솔·실행 환경 등).

근거의 라인 번호는 감사 시점(2026-08-10) 기준이다.

---

## 출력 1 — 코드 대조 감사표

### A. STEP 1~9 체크박스 (중점 항목 a)

| 문서 위치 | 문서 서술 | 코드 실제 | 판정 | 근거 |
|---|---|---|---|---|
| STEP 1 (161행) | `⬜` 미완료 — pubspec 패키지 구성 | flutter_naver_map·dio·image_picker 모두 등록, google_maps_flutter 부재. 구성 완료 상태 | 불일치 | Repo_JDH/pubspec.yaml:29,40,43 (google_maps_flutter 검색 결과 0건) |
| STEP 1 표 (167행) | flutter_naver_map `^1.3.1` | `^1.4.4` (lock 1.4.4) | 불일치 | Repo_JDH/pubspec.yaml:29 / pubspec.lock:629 |
| STEP 1 표 (168행) | google_maps_flutter 제거됨 | pubspec에 없음 | 일치 | Repo_JDH/pubspec.yaml 전체 (해당 항목 부재) |
| STEP 1 표 (171행) | firebase_storage "v6 현재 미사용(향후 검토)" | 등록되어 있고 3개 파일에서 실사용 | 불일치 | Repo_JDH/pubspec.yaml:26; storage_repository.dart:6; photo_service.dart:63; user_service.dart:230 |
| STEP 1 ※ (173행) | "이미지는 서버로 직접 전송한다" | 수거 인증 이미지가 Firebase Storage로 업로드된다 | 불일치 | Repo_JDH/lib/features/plogging/presentation/plogging_tracking_screen.dart:203 |
| STEP 2 (175행) | `✅` Feature-First 3-Layer 재편 완료 | lib/core + lib/features 하위 9개 feature, 각 data/domain/presentation 구조 존재 | 일치 | Repo_JDH/lib/features/ (디렉토리 트리) |
| STEP 3 (179행) | `⬜` 미완료 — build.gradle.kts 설정 | applicationId·minSdk·targetSdk·compileSdk 4개 확정값 모두 적용 완료 | 불일치 | Repo_JDH/android/app/build.gradle.kts:12,21,24,25 |
| STEP 3 표 (183행) | applicationId `com.ploggo.app` | `com.ploggo.app` (namespace도 동일) | 일치 | Repo_JDH/android/app/build.gradle.kts:11,21 |
| STEP 3 표 (184~186행) | minSdk 26 / targetSdk 36 / compileSdk 36 | 26 / 36 / 36 | 일치 | Repo_JDH/android/app/build.gradle.kts:24,25,12 |
| STEP 4 (190행) | `⬜` 미완료 | ① 권한 8종 전부 선언됨 ② Naver CLIENT_ID meta-data 부재 → ②만 미완료 | 불일치 | Repo_JDH/android/app/src/main/AndroidManifest.xml:5,7,13,15,19,23,25,27,31 (권한) / CLIENT_ID 검색 0건 |
| STEP 4 ① 표 (196~205행) | 권한 8종 선언 필요 | FINE·COARSE·FOREGROUND_SERVICE·FOREGROUND_SERVICE_LOCATION·CAMERA·ACTIVITY_RECOGNITION·INTERNET·READ_STEPS·READ_TOTAL_CALORIES_BURNED 전부 선언 | 일치 | Repo_JDH/android/app/src/main/AndroidManifest.xml:5,7,13,15,19,23,25,27,31 |
| STEP 4 ② (209~213행) | Naver Maps CLIENT_ID meta-data 등록 | manifest에 해당 meta-data 없음. Client ID는 런타임에 dotenv로 주입 | 일치 (미등록 상태) | Repo_JDH/android/app/src/main/AndroidManifest.xml (CLIENT_ID 0건) / lib/main.dart:29 |
| STEP 4 (미서술) | — | `ACCESS_BACKGROUND_LOCATION`, `WRITE_EXTERNAL_STORAGE(maxSdk 29)` 선언됨. 문서 권한표에 없음 | 문서 누락 | Repo_JDH/android/app/src/main/AndroidManifest.xml:9,33 |
| STEP 5 (215행) | `⬜` 미완료 — Firebase 연결 | `google-services.json` 저장소에 없음(.gitignore 처리). `Firebase.initializeApp()`은 호출됨. 실제 콘솔 등록 여부는 저장소로 판정 불가 | 검증 불가 | Repo_JDH/.gitignore:130 / lib/main.dart:22 (파일 자체 부재) |
| STEP 5 (228행) | "Cloud Storage 활성화는 미사용으로 보류" | firebase_storage 실사용 중 → Storage 활성화 없이는 동작 불가 | 불일치 | Repo_JDH/lib/features/plogging/data/photo_service.dart:63; storage_repository.dart:6 |
| STEP 5.5 (230행) | `⬜` NCP Application 등록 | 외부 콘솔 상태. 저장소로 확인 불가 | 검증 불가 | — (NCP 콘솔은 저장소 외부) |
| STEP 5.6 (245행) | `⬜` Tmap Pedestrian 등록, AppKey는 서버 .env에만 | 서버가 `TMAP_APP_KEY`를 환경변수로만 읽고 하드코딩 없음. Flutter 측 Tmap 참조 0건 | 일치 | ploggo-server/route_recommender/config.py:35; .env.example:4 / Repo_JDH lib 내 "Tmap" 호출 코드 0건 |
| STEP 5.7 (258행) | `⬜` SHA-1 등록 | Firebase 콘솔 상태. 저장소로 확인 불가 | 검증 불가 | — (Firebase 콘솔은 저장소 외부) |
| STEP 6 (272행) | `⬜` .env 작성 | `.env.example` 존재, 코드가 `FASTAPI_BASE_URL`·`NAVER_MAP_CLIENT_ID` 참조. detector.dart는 여전히 하드코딩 → 부분 미완료 | 일치 | Repo_JDH/.env.example:5,9 / lib/main.dart:29 / route_repository.dart:15 / detector.dart:62 |
| STEP 7 (301행) | `⬜` 미완료 — main.dart 4종 초기화 | 4종 전부 구현 완료 | 불일치 | Repo_JDH/lib/main.dart:18,22,25,28,46 |
| STEP 7 ※ (310행) | 초기화 순서: dotenv → Firebase → NaverMap → ProviderScope | 실제: Firebase(:22) → dotenv(:25) → NaverMap(:28) → ProviderScope(:46). 앞 두 단계 순서가 반대 | 불일치 | Repo_JDH/lib/main.dart:22,25,28,46 |
| STEP 8 (312행) | `⬜` 미완료 — 라우터 작성 | app_router.dart에 15개 라우트 + redirect 가드 + ShellRoute 셸 구현 완료 | 불일치 | Repo_JDH/lib/core/router/app_router.dart:98~233 |
| STEP 8 (317행) | ShellRoute 셸이 4개 탭(/home, /group, /mypage, /settings)을 감싼다 | 동일 | 일치 | Repo_JDH/lib/core/router/app_router.dart:165~188 |
| STEP 8 ▶결정 #3 (322행) | 중앙 시작 버튼의 탭 전환 vs push 미확정 | 코드는 `context.push(AppRoutes.ploggingRoute)` — push 방식으로 이미 구현됨 | 불일치 | Repo_JDH/lib/core/router/app_router.dart:482 |
| STEP 9 (324행) | `⬜` feature별 개발 미완료 | reward feature 부재, vision domain 부재 등 미완료 항목 존재 | 일치 | Repo_JDH/lib/features/ (reward 디렉토리 없음, vision/domain 없음) |

### B. 3장 서버 API 계약 (중점 항목 b)

| 문서 위치 | 문서 서술 | 코드 실제 | 판정 | 근거 |
|---|---|---|---|---|
| 3-1 (480행) | detector.dart가 EC2 IP를 하드코딩 중 | `SERVER_URL = 'http://54.70.167.93:8000'` 상수로 잔존 | 일치 | Repo_JDH/lib/features/vision/data/detector.dart:62 |
| 3-2 (486행) | `POST /detect` | 존재 | 일치 | ploggo-server/server.py:287 |
| 3-2 (487행) | `POST /detect_and_crop` | 서버에 존재. 단 Flutter 호출부 0건 | 일치 | ploggo-server/server.py:358 / Repo_JDH lib 내 "detect_and_crop" 0건 |
| 3-2 (488행) | `POST /route/recommend` | 존재 (`prefix="/route"` + `@router.post("/recommend")`) | 일치 | ploggo-server/route_recommender/router.py:21,67 |
| 3-2 (489행) | `GET /health`, `GET /route/health` | 둘 다 존재 | 일치 | ploggo-server/server.py:64 / route_recommender/router.py:84 |
| 3-2 엔드포인트 목록 | (목록에 없음) | `GET /` 루트 상태 엔드포인트 존재 | 문서 누락 | ploggo-server/server.py:53 |
| 3-2 엔드포인트 목록 | (목록에 없음) | `GET /news` 환경 뉴스 엔드포인트 존재. Flutter가 실제로 호출 중 | 문서 누락 | ploggo-server/server.py:224 / Repo_JDH/lib/features/news/presentation/news_service.dart:26 |
| 3-3 요청 (497행) | `origin{lat, lon}` 필수 | `origin: LatLng` (lat, lon 필수) | 일치 | ploggo-server/route_recommender/router.py:27~33 |
| 3-3 요청 (498행) | `destination{lat, lon}` 필수 | 동일 | 일치 | ploggo-server/route_recommender/router.py:34 |
| 3-3 요청 (499행) | `district` 선택, 인천 9개 군구 영문명 | `Optional[str] = None`, description에 동일 서술 | 일치 | ploggo-server/route_recommender/router.py:35~39 |
| 3-3 응답 (505~512행) | success / is_hard_case / intersection_m / intersection_ratio / crossed_uqa_codes[] / polyline / distance_m / duration_ms / n_swaps / k3_hotspots[] | RouteResponse에 동일 필드명 전부 존재 | 일치 | ploggo-server/route_recommender/router.py:50~61 |
| 3-3 응답 표 | (표에 없음) | `best_from_attempt: Optional[int]` 필드 존재 | 문서 누락 | ploggo-server/route_recommender/router.py:60 |
| 3-3 (512행) | k3_hotspots 필드 = hotspot_id, latitude, longitude, S_i, avoid_penalty | HotspotOut에 동일 5개 필드 | 일치 | ploggo-server/route_recommender/router.py:42~47 |
| 3-3 ※ (514행) | Tmap 실패 시 서버가 HTTP 502 반환, Data 계층이 502 별도 처리 | 서버가 502 raise, 앱이 502 분기 후 사용자 메시지 | 일치 | ploggo-server/route_recommender/router.py:76~80 / Repo_JDH/lib/features/plogging/data/route_repository.dart:87~93 |
| 3-4 (520~524행) | /detect 응답 = success / image_size{width,height} / detections[] / counts{} / total | 동일 | 일치 | ploggo-server/server.py:345~351 |
| 3-4 (522행) | detections[] = class_id, class_name, confidence, box, box_pixel | 동일 5개 키 | 일치 | ploggo-server/server.py:320~338 |
| 3-4 (526행) | 클래스명 can, glass, paper, plastic, trash | `CLASS_NAMES = ["can","glass","paper","plastic","trash"]`, labels.txt 동일 | 일치 | ploggo-server/server.py:42 / labels.txt:1~5 |
| 3-5 (530행) | 목적지는 지도 마커로 좌표 직접 획득, 지오코딩 불필요 | 지도 탭으로 destinationProvider에 좌표 설정. 단 앱에 `geocoding` 패키지가 남아 있고 좌표→주소 역지오코딩을 사용 중 | 불일치 | Repo_JDH/lib/features/plogging/presentation/route_setup_screen.dart:236 / lib/features/plogging/data/location_repository.dart:3,44 |
| 3-5 (532행) | "Naver 지오코딩 프록시는 사용하지 않는다" | 서버에 지오코딩 프록시 엔드포인트 없음 | 일치 | ploggo-server/server.py:53~447 (해당 라우트 없음) |
| 3-5 (532행) | ".env.example의 Naver 키는 지도 SDK·향후 확장 예비" | Flutter `.env.example`에 `NAVER_MAP_CLIENT_SECRET`이 존재 — Secret은 CLAUDE.md 6장상 Flutter에 두지 않아야 함 | 불일치 | Repo_JDH/.env.example:6 |

### C. Gemini 뉴스 요약(#39)·ALGO_HARD_CASE_M(#40) (중점 항목 d)

| 문서 위치 | 문서 서술 | 코드 실제 | 판정 | 근거 |
|---|---|---|---|---|
| 1-1 (63행) | LLM: Gemini 2.5 Flash "현재 미구현, 향후: 서버에 키만 존재" | 서버에 `_gemini_enrich()` 실호출 구현 완료. `/news`가 매 요청마다 호출. 기본 모델 `gemini-2.5-flash` | 불일치 | ploggo-server/server.py:123,128~132,135~221,276 |
| 9-6 (441행) | news_repository.dart: FastAPI 경유 뉴스+Gemini 요약 수신 "현재 미구현, 향후" | 서버는 구현 완료. 앱도 `NewsService.fetchNews()`로 `aiSummary` 수신·표시 중. 단 위치가 community/data가 아니라 news/presentation | 불일치 | Repo_JDH/lib/features/news/presentation/news_service.dart:26,72,89 / ploggo-server/server.py:276 |
| 9-6 (447행) | "서버에 GEMINI_API_KEY 이름만 존재하고 실제 호출 코드가 없음이 확인되었다" | `requests.post(GEMINI_URL, ...)` 실호출 존재 | 불일치 | ploggo-server/server.py:172~184 |
| 6-2 #39 (629행) | Gemini 뉴스 요약 서버 구현 = 잔여 의사결정 항목 | 이미 구현·동작. 잔여 항목이 아님 | 불일치 | ploggo-server/server.py:135~221 |
| 6-2 #7 (623행) | 환경 뉴스 데이터 소스 미확정 (RSS vs 크롤러) | 네이버 뉴스 검색 API로 확정 구현됨 | 불일치 | ploggo-server/server.py:79,224~278 |
| STEP 6 (291행) | `ALGO_HARD_CASE_M` 기본 100m, "정의됨, 현재 코드 미참조" | `.env.example`에만 존재. config.py·algorithm.py 어디에서도 참조 없음 | 일치 | ploggo-server/.env.example:15 / config.py:22~27 (해당 상수 없음) / algorithm.py 내 "HARD_CASE" 0건 |
| STEP 6 (299행) | is_hard_case 판정이 임계값과 연결되어 있지 않다 | `hard_case`는 알고리즘 내부 상태로만 산출, 임계값 미사용 | 일치 | ploggo-server/route_recommender/algorithm.py:348,353,492 |
| 6-2 #40 (630행) | ALGO_HARD_CASE_M 코드 연결/제거 = 잔여 항목 | 여전히 미연결 상태 | 일치 | ploggo-server/route_recommender/config.py:22~27 |

### D. Docker 관련 파일 (중점 항목 e)

| 문서 위치 | 문서 서술 | 코드 실제 | 판정 | 근거 |
|---|---|---|---|---|
| 1-1 (68행) | 컨테이너화: Docker 미구현, "Dockerfile·compose 현재 부재 확인" | ploggo-server 루트에 Dockerfile·docker-compose 파일 없음 | 일치 | ploggo-server/ (루트 파일 목록: README.md, docs/, garbage_yolo_model.onnx, labels.txt, requirements*.txt, route_recommender/, scripts/, server.py) |
| 1-4-1 표 (128~129행) | Dockerfile 작성·이미지 빌드 = 미구현 | 동일 | 일치 | ploggo-server/ (Docker 관련 파일 0건) |
| 1-4-1 표 (130행) | 환경 변수 외부화 (.env) 적용됨 | `load_dotenv()` 호출 + `.env.example` 존재 | 일치 | ploggo-server/server.py:14~15 / .env.example:1~15 |
| 1-4-1 표 (131행) | Stateless — 서버는 영구 데이터 미보유 | 정적 데이터(CSV·GeoJSON·ONNX)만 배치, 쓰기 없음 | 일치 | ploggo-server/route_recommender/config.py:41~47 / server.py:36~38 |

### E. 패키지 버전 (중점 항목 f) — pubspec.lock 기준

| 문서 위치 | 문서 서술 | 코드 실제(lock) | 판정 | 근거 |
|---|---|---|---|---|
| 1-1 (49행) | Flutter 3.41.5 + Dart 3.11.3 | 로컬 툴체인 기록은 Flutter 3.44.2 / pub(Dart) 3.12.2. pubspec sdk 제약은 `^3.9.2` | 불일치 | Repo_JDH/.dart_tool/version:1 / .dart_tool/package_config.json (generatorVersion) / pubspec.yaml:7 |
| 1-1 (50행) | Riverpod 2.x + AsyncNotifier | flutter_riverpod 2.6.1, riverpod_annotation 2.6.1 | 일치 | Repo_JDH/pubspec.lock:645,1351 |
| 1-1 (51행) | go_router 15.x | 15.1.3 | 일치 | Repo_JDH/pubspec.lock:791 |
| 1-1 (54행) | flutter_naver_map **1.3.1** | 1.4.4 | 불일치 | Repo_JDH/pubspec.lock:629 / pubspec.yaml:29 |
| 1-1 (55행) | 위치 추적: geolocator | 13.0.4 (문서에 버전 표기 없음) | 일치 | Repo_JDH/pubspec.lock:735 |
| 1-1 (60행) | health 13.x (Health Connect) | 13.3.1 | 일치 | Repo_JDH/pubspec.lock:863 |
| 1-1 (61행) | flutter_foreground_task 8.x | 8.17.0 | 일치 | Repo_JDH/pubspec.lock:592 |
| 1-1 (62행) | AI 통신: dio 5.x → FastAPI | dio 5.11.0. 단 vision·news는 dio가 아닌 `http` 1.6.0 사용 | 불일치 | Repo_JDH/pubspec.lock:411,895 / detector.dart:3 / news_service.dart:4 |
| 1-1 (64행) | 환경변수 flutter_dotenv 5.x | 5.2.1 | 일치 | Repo_JDH/pubspec.lock:584 |
| 1-1 (65행) | 폰트: Noto Sans KR "한국어·영어 통일 서체" | 메인 폰트는 Pretendard 4종. NotoSansKR은 주석상 "백업 폰트(나중에 삭제 가능)" | 불일치 | Repo_JDH/pubspec.yaml:98~118 |
| 1-1 표 전체 | (표에 없음) | `dart_geohash 2.1.0` 등록됨, 코드 사용처 0건 | 문서 누락 | Repo_JDH/pubspec.lock:379 / lib 내 geohash 0건 |
| 1-1 표 전체 | (표에 없음) | `google_generative_ai 0.4.7`(Gemini 클라이언트 SDK) 등록됨, 코드 사용처 0건 | 문서 누락 | Repo_JDH/pubspec.lock:799 / lib 내 사용 0건 |
| 1-1 표 전체 | (표에 없음) | `camera 0.10.6`, `geocoding 3.0.0`, `http 1.6.0` 등록·사용 중 | 문서 누락 | Repo_JDH/pubspec.lock:171,703,895 |

### F. 3-Layer 의존성 역전 위반 전수 (중점 항목 g)

문서 4-1(538행)은 `presentation → domain → data` 하향 단방향을 규정한다. presentation이 data를 직접 import하는 사례를 전수 조사한 결과 **34건**이 확인되었다. 문서는 4-2에서 vision의 domain 부재 1건만 "정비 필요"로 언급한다.

| 문서 위치 | 문서 서술 | 코드 실제 | 판정 | 근거 |
|---|---|---|---|---|
| 4-1 (538행) | presentation → domain → data 단방향 유지 | presentation → data 직접 import 34건 | 불일치 | 아래 세부 목록 |
| 4-2 (545행) | 위반은 vision domain 부재 1건 | 8개 feature에 걸쳐 광범위 위반 | 불일치 | 아래 세부 목록 |

세부 위반 목록 (파일:라인 → import 대상)

| # | 위치 | import 대상 |
|---|---|---|
| 1 | auth/presentation/login_screen.dart:7 | ../data/auth_repository.dart |
| 2 | auth/presentation/nickname_setup_screen.dart:7 | auth/data/user_profile_provider.dart |
| 3 | auth/presentation/nickname_setup_screen.dart:8 | auth/data/user_service.dart |
| 4 | auth/presentation/signup_screen.dart:5 | ../data/auth_repository.dart |
| 5 | auth/presentation/signup_screen.dart:6 | auth/data/user_service.dart |
| 6 | community/presentation/group_create_screen.dart:6 | community/data/group_service.dart |
| 7 | community/presentation/group_detail_screen.dart:9 | community/data/group_service.dart |
| 8 | community/presentation/group_feed_screen.dart:5 | community/data/group_service.dart |
| 9 | community/presentation/group_screen.dart:13 | community/data/group_service.dart |
| 10 | community/presentation/group_search_screen.dart:4 | community/data/group_service.dart |
| 11 | mypage/presentation/my_activity_screen.dart:14 | mypage/data/badge_service.dart |
| 12 | mypage/presentation/my_activity_screen.dart:15 | plogging/data/activity_service.dart (feature 교차) |
| 13 | mypage/presentation/my_impact_screen.dart:8 | auth/data/user_profile_provider.dart (feature 교차) |
| 14 | mypage/presentation/my_impact_screen.dart:9 | plogging/data/activity_service.dart (feature 교차) |
| 15 | mypage/presentation/profile_screen.dart:8 | auth/data/user_service.dart (feature 교차) |
| 16 | mypage/presentation/quest_list_screen.dart:5 | mypage/data/badge_service.dart |
| 17 | news/presentation/news_feed_screen.dart:4 | news_service.dart (data 성격 파일이 presentation에 위치) |
| 18 | plogging/presentation/plogging_tracking_screen.dart:13 | plogging/data/storage_repository.dart |
| 19 | plogging/presentation/plogging_tracking_screen.dart:16 | auth/data/user_service.dart (feature 교차) |
| 20 | plogging/presentation/plogging_tracking_screen.dart:21 | plogging/data/location_repository.dart |
| 21 | plogging/presentation/plogging_tracking_screen.dart:22 | plogging/data/activity_service.dart |
| 22 | plogging/presentation/settlement_screen.dart:13 | mypage/data/badge_service.dart (feature 교차) |
| 23 | plogging/presentation/settlement_screen.dart:14 | community/data/group_service.dart (feature 교차) |
| 24 | plogging/presentation/settlement_screen.dart:17 | plogging/data/photo_service.dart |
| 25 | plogging/presentation/settlement_screen.dart:18 | plogging/data/activity_service.dart |
| 26 | plogging/presentation/settlement_screen.dart:19 | plogging/data/location_repository.dart |
| 27 | settings/presentation/menu_screen.dart:9 | mypage/data/badge_service.dart (feature 교차) |
| 28 | settings/presentation/menu_screen.dart:10 | auth/data/user_service.dart (feature 교차) |
| 29 | shop/presentation/coupon_screen.dart:12 | shop/data/shop_service.dart |
| 30 | shop/presentation/point_history_screen.dart:4 | shop/data/point_history_service.dart |
| 31 | shop/presentation/shop_screen.dart:6 | shop/data/shop_service.dart |
| 32 | vision/presentation/box_painter.dart:2 | ../data/detector.dart |
| 33 | vision/presentation/camera_detection_screen.dart:9 | vision/data/detector.dart |
| 34 | vision/presentation/camera_detection_screen.dart:10 | plogging/data/location_repository.dart (feature 교차) |

부수 확인: `core/router/app_router.dart:12`도 `auth/data/user_profile_provider.dart`를 직접 import한다(라우터는 presentation 계층은 아니나 domain 경유 원칙에서 벗어남).

### G. lib/core/widgets/ 실제 내용물 (중점 항목 h)

| 문서 위치 | 문서 서술 | 코드 실제 | 판정 | 근거 |
|---|---|---|---|---|
| 1-2 표 (81행) | `lib/core/widgets/` — "현재 비어 있음, 향후 추출용" | 7개 파일 존재: app_button.dart, app_card.dart, app_dialog.dart, app_section.dart, app_snackbar.dart, app_stat.dart, trash_bag_icon.dart | 불일치 | Repo_JDH/lib/core/widgets/ (파일 7개) |
| 1-2 ※ (96행) | "향후 재사용·복잡도가 커지면 core/widgets/로 위젯을 추출한다" | 이미 7개 공용 위젯이 추출되어 사용 중 (예: route_setup_screen이 app_dialog import) | 불일치 | Repo_JDH/lib/features/plogging/presentation/route_setup_screen.dart:22 |
| 10장 표 (693행) | v8 정정: core/widgets 행을 "현재 비어 있음"으로 정정 | 정정 방향이 코드와 반대 (실제로는 비어 있지 않음) | 불일치 | Repo_JDH/lib/core/widgets/ |

### H. 화면 파일 전수 vs 9장 문서화 여부 (중점 항목 i)

`lib/` 내 `*_screen.dart` 파일은 총 31개다. guideline_v8 9장에 실제 파일명으로 서술된 것은 8개뿐이며, 나머지 23개는 문서에 없거나 다른 이름으로 적혀 있다.

| # | 화면 파일 | 9장 서술 | 판정 | 근거 |
|---|---|---|---|---|
| 1 | auth/presentation/login_screen.dart | 9-1 login_screen.dart | 일치 | guideline_v8.md:334 |
| 2 | auth/presentation/signup_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/auth/presentation/signup_screen.dart |
| 3 | auth/presentation/nickname_setup_screen.dart | 없음 (STEP 8 redirect에도 미기재) | 문서 누락 | Repo_JDH/lib/features/auth/presentation/nickname_setup_screen.dart / app_router.dart:161~164 |
| 4 | home/presentation/home_screen.dart | 9-2 home_screen.dart | 일치 | guideline_v8.md:344 |
| 5 | plogging/presentation/route_setup_screen.dart | 9-3은 `route_screen.dart`로 표기 | 불일치 | guideline_v8.md:358 / Repo_JDH/lib/features/plogging/presentation/route_setup_screen.dart:28 |
| 6 | plogging/presentation/plogging_tracking_screen.dart | 9-3은 `tracking_screen.dart`로 표기 | 불일치 | guideline_v8.md:359 / Repo_JDH/lib/features/plogging/presentation/plogging_tracking_screen.dart |
| 7 | plogging/presentation/settlement_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/plogging/presentation/settlement_screen.dart |
| 8 | vision/presentation/camera_detection_screen.dart | 9-4는 `camera_screen.dart`로 표기 | 불일치 | guideline_v8.md:398 / Repo_JDH/lib/features/vision/presentation/camera_detection_screen.dart |
| 9 | (vision_result_screen.dart) | 9-4에 존재로 표기 | 불일치 (파일 없음. `/vision/result`는 PlaceholderScreen) | guideline_v8.md:399 / Repo_JDH/lib/core/router/app_router.dart:218~222 |
| 10 | (reward_screen.dart) | 9-5에 존재로 표기 | 불일치 (파일·feature 모두 없음) | guideline_v8.md:432 / Repo_JDH/lib/features/ (reward 없음) |
| 11 | community/presentation/group_screen.dart | 9-6 group_screen.dart | 일치 | guideline_v8.md:444 |
| 12 | community/presentation/group_feed_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/community/presentation/group_feed_screen.dart |
| 13 | community/presentation/group_create_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/community/presentation/group_create_screen.dart |
| 14 | community/presentation/group_detail_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/community/presentation/group_detail_screen.dart |
| 15 | community/presentation/group_search_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/community/presentation/group_search_screen.dart |
| 16 | news/presentation/news_feed_screen.dart | 9-6은 community 하위 `news_screen.dart`(향후)로 표기 | 불일치 | guideline_v8.md:445 / Repo_JDH/lib/features/news/presentation/news_feed_screen.dart |
| 17 | news/presentation/news_detail_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/news/presentation/news_detail_screen.dart |
| 18 | mypage/presentation/my_activity_screen.dart | 9-7은 `mypage_screen.dart` 및 "activity"로 표기 | 불일치 | guideline_v8.md:457,458 / Repo_JDH/lib/features/mypage/presentation/my_activity_screen.dart |
| 19 | mypage/presentation/activity_list_screen.dart | 9-7 "activity_list" | 일치 | guideline_v8.md:458 |
| 20 | mypage/presentation/activity_detail_screen.dart | 9-7 "activity_detail" | 일치 | guideline_v8.md:458 |
| 21 | mypage/presentation/my_impact_screen.dart | 9-7 "my_impact" | 일치 | guideline_v8.md:458 |
| 22 | mypage/presentation/quest_list_screen.dart | 9-7 "quest_list" | 일치 | guideline_v8.md:458 |
| 23 | mypage/presentation/profile_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/mypage/presentation/profile_screen.dart |
| 24 | settings/presentation/menu_screen.dart | 9-8 menu_screen.dart (MenuScreen) | 일치 | guideline_v8.md:470 |
| 25 | settings/presentation/faq_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/settings/presentation/faq_screen.dart |
| 26 | settings/presentation/inquiry_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/settings/presentation/inquiry_screen.dart |
| 27 | settings/presentation/licenses_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/settings/presentation/licenses_screen.dart |
| 28 | settings/presentation/notice_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/settings/presentation/notice_screen.dart |
| 29 | settings/presentation/terms_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/settings/presentation/terms_screen.dart |
| 30 | shop/presentation/shop_screen.dart | 없음 (9-5 reward_screen이 "상점 화면"을 겸한다고만 표기) | 문서 누락 | Repo_JDH/lib/features/shop/presentation/shop_screen.dart |
| 31 | shop/presentation/coupon_screen.dart | 없음 (CouponScreen·CouponDetailScreen 2개 화면 포함) | 문서 누락 | Repo_JDH/lib/features/shop/presentation/coupon_screen.dart |
| 32 | shop/presentation/point_history_screen.dart | 없음 | 문서 누락 | Repo_JDH/lib/features/shop/presentation/point_history_screen.dart |
| 33 | core/router/placeholder_screen.dart | 없음 (3개 라우트가 이 화면에 연결) | 문서 누락 | Repo_JDH/lib/core/router/placeholder_screen.dart / app_router.dart:218~232 |

부수: 다이얼로그 파일 `mypage/presentation/badge_dialog.dart`, `mypage/presentation/reward_dialogs.dart`도 9장에 없다 → 문서 누락.

### I. 패키지명·applicationId (중점 항목 j)

| 문서 위치 | 문서 서술 | 코드 실제 | 판정 | 근거 |
|---|---|---|---|---|
| STEP 3 (183행), 1-2, STEP 5, 5.5 | applicationId `com.ploggo.app` 확정 | Android applicationId·namespace 모두 `com.ploggo.app` | 일치 | Repo_JDH/android/app/build.gradle.kts:11,21 |
| (문서 미서술) | — | Dart 패키지명은 `repo_jdh`. import 경로는 전부 `package:repo_jdh/...` | 문서 누락 | Repo_JDH/pubspec.yaml:1 / lib/main.dart:6,7 / lib/core/router/app_router.dart:4,8~21 |
| (문서 미서술) | — | `package:ploggo/...` 형식 import는 0건 | 문서 누락 | Repo_JDH/lib (해당 문자열 0건) |
| (문서 미서술) | — | 앱 표시명 label은 `ploggo` | 문서 누락 | Repo_JDH/android/app/src/main/AndroidManifest.xml:37 |

정리: applicationId(`com.ploggo.app`)와 Dart 패키지명(`repo_jdh`)이 서로 다른 값이며, 문서는 Dart 패키지명을 한 번도 언급하지 않는다. 두 값은 Flutter에서 독립적이므로 코드상 오류는 아니나, 문서만 읽으면 import 경로를 `package:ploggo/...`로 오인할 수 있다.

### J. lib/features/ 실제 feature 목록 (중점 항목 k)

| feature | 1-2 폴더 표 서술 | 코드 실제 | 판정 | 근거 |
|---|---|---|---|---|
| auth | 있음 (82행) | data 3 / domain 1 / presentation 3 | 일치 | Repo_JDH/lib/features/auth/ |
| home | 있음 (83행) | domain 1(eco_math.dart) / presentation 1. data 없음 | 불일치 (9-2가 규정한 home_repository.dart·home_notifier.dart 부재) | Repo_JDH/lib/features/home/ / guideline_v8.md:342,343 |
| plogging | 있음 (84행) | data 7 / domain 6 / presentation 3 | 일치 | Repo_JDH/lib/features/plogging/ |
| plogging (9-3) | `plogging_notifier.dart` 존재로 표기 | 파일 없음. 트래킹 상태는 core/providers/tracking_provider.dart·plogging_provider.dart에 있음 | 불일치 | guideline_v8.md:356 / Repo_JDH/lib/features/plogging/domain/ (해당 파일 없음) / lib/core/providers/tracking_provider.dart |
| vision | 있음 (85행) | data 1(detector.dart) / presentation 2. domain 디렉토리 자체 없음 | 일치 (문서 403행이 domain 미구현으로 명시) | Repo_JDH/lib/features/vision/ / guideline_v8.md:403 |
| vision (9-4) | `vision_repository.dart` 존재로 표기 | 파일 없음. 실제 파일명은 detector.dart이며 dio가 아닌 http 사용 | 불일치 | guideline_v8.md:396 / Repo_JDH/lib/features/vision/data/detector.dart:3,64 |
| reward | 있음 (86행) | **feature 디렉토리 자체가 없음** | 불일치 | Repo_JDH/lib/features/ (reward 없음) |
| community | 있음 (87행) | data 2 / domain 1 / presentation 5. news_repository.dart는 빈 클래스 | 불일치 (뉴스 요약 feature가 community가 아닌 별도 news feature에 구현됨) | Repo_JDH/lib/features/community/data/news_repository.dart:3 / lib/features/news/ |
| mypage | 있음 (88행) | data 1 / domain 4 / presentation 8 | 일치 | Repo_JDH/lib/features/mypage/ |
| settings | 있음 (89행) | presentation 6개만. **data/·domain/ 디렉토리 자체가 없음** | 불일치 | Repo_JDH/lib/features/settings/ |
| settings (9-8 표) | data·domain "(비어 있음) .gitkeep" | .gitkeep 파일이 lib/ 전체에 0건. 디렉토리 자체가 없음 | 불일치 | Repo_JDH/lib (find .gitkeep 결과 0건) |
| **news** | 표에 없음 | presentation 3(news_feed·news_detail·news_service). data/domain 없음 | 문서 누락 | Repo_JDH/lib/features/news/ |
| **shop** | 표에 없음 | data 2 / domain 2 / presentation 3 | 문서 누락 | Repo_JDH/lib/features/shop/ |
| core/dev | 1-2 표에 없음 | dev_data.dart, dev_seed.dart, dev_user.dart (개발용 시드) | 문서 누락 | Repo_JDH/lib/core/dev/ |
| core/view_models | 1-2 표에 없음 | screen_views.dart | 문서 누락 | Repo_JDH/lib/core/view_models/ |
| core/constants, core/utils | CLAUDE.md 2-1에 정의 | 디렉토리 없음 (v8 1-2 표에도 없음 — 이 점은 정합) | 일치 | Repo_JDH/lib/core/ |

### K. 기타 사실 서술

| 문서 위치 | 문서 서술 | 코드 실제 | 판정 | 근거 |
|---|---|---|---|---|
| 1-1 (56행) | 경로 알고리즘 전량 FastAPI 서버 처리 | 후보 필터·Score·회피 페널티·swap·Tmap 호출 모두 서버. Flutter는 요청·수신만 | 일치 | ploggo-server/route_recommender/algorithm.py:155,175,216,246 / Repo_JDH/lib/features/plogging/data/route_repository.dart:77~85 |
| 1-1 (57행) | 도보 경로 = Tmap Pedestrian, 서버 내부 호출 | `TMAP_PEDESTRIAN_URL` 서버 상수, 서버가 POST | 일치 | ploggo-server/route_recommender/config.py:36 / algorithm.py:246 |
| 1-1 (59행) | 공간 탐색 = 타원 buffer + numpy 전수 계산, GeoHash 미사용 | `filter_candidates_by_ellipse_buffer`, numpy import. 서버 GeoHash 참조 0건 | 일치 | ploggo-server/route_recommender/algorithm.py:22,155~161 |
| 1-1 (67행) | AWS EC2 포트 8000 | `uvicorn.run(app, host="0.0.0.0", port=8000)`. EC2 인스턴스 자체는 확인 불가 | 검증 불가 | ploggo-server/server.py:447 (포트만 확인) |
| 1-2 (94행) | 바텀내비 = ShellRoute 셸 `_ScaffoldWithBottomNav`, Stack+Container+CustomPaint 커스텀 바, 중앙 돌출 시작 버튼 | 동일 (Stack:324, CustomPaint:373, 시작 버튼:430) | 일치 | Repo_JDH/lib/core/router/app_router.dart:165~168,288~394,430 |
| 1-2 (94행) | 4개 탭 화면 = /home, /group, /mypage, /settings | 동일 | 일치 | Repo_JDH/lib/core/router/app_router.dart:171~186 |
| 1-2 (100행) | 설정 화면이 settings feature의 menu_screen.dart(MenuScreen)로 구현, 라우터 연결 | 동일 | 일치 | Repo_JDH/lib/features/settings/presentation/menu_screen.dart / app_router.dart:18,185 |
| 1-3 (104행) | 서버에 firebase-admin 없고 Firebase 참조 전무 | requirements.txt·모든 .py에서 firebase 문자열 0건 | 일치 | ploggo-server/requirements.txt / *.py (grep 0건) |
| 1-3 (110행) | 수거 인증 이미지 저장 = 앱 → 서버 직접 전송 | 검출은 서버 전송이나, 인증 이미지 자체는 Firebase Storage에 업로드·URL 보관 | 불일치 | Repo_JDH/lib/features/plogging/presentation/plogging_tracking_screen.dart:203 / photo_service.dart:63 |
| 1-4-2 표 (142행) | CCTV 핫스팟 1,535개, 서버 CSV | CSV 1,536행(헤더 1 + 데이터 1,535) | 일치 | ploggo-server/route_recommender/data/hotspots_with_si.csv |
| 1-4-2 표 (143행) | 회피 폴리곤 147개, 시작 시 1회 로드 | GeoJSON features 147개 | 일치 | ploggo-server/route_recommender/data/incheon_avoid_zones_v1_260601.geojson |
| 1-4-2 표 (144행) | YOLO 가중치 약 11.7MB | 12,268,394 B ≈ 11.70 MiB | 일치 | ploggo-server/garbage_yolo_model.onnx |
| 7장 (644행) | YOLO 640×640, 5클래스 | `IMG_SIZE = 640`, CLASS_NAMES 5개 | 일치 | ploggo-server/server.py:42,47 |
| 4-3 (549행) | 서버가 경유지 수를 ALGO_K 환경변수(기본 3)로 받음, 요청 파라미터 아님 | `K = _i("ALGO_K", 3)`. RouteRequest에 K 필드 없음 | 일치 | ploggo-server/route_recommender/config.py:25 / router.py:32~39 |
| 5-1 (570행) | withOpacity 금지, withValues(alpha:) 사용 | lib 전체에서 withOpacity 0건 | 일치 | Repo_JDH/lib (grep 0건) |
| 5-1 (571행) | 서버 주소·API 키 하드코딩 금지 | detector.dart:62에 EC2 IP 하드코딩 잔존 | 불일치 | Repo_JDH/lib/features/vision/data/detector.dart:62 |
| 5-1 (574행) | Naver Maps 좌표는 NLatLng 사용 | NLatLng 사용, Google Maps LatLng 미사용 | 일치 | Repo_JDH/lib/features/plogging/presentation/route_setup_screen.dart:70,334,351 |
| 5-1 (575행) | primary color = 파스텔 블루 `#6BA3E8` | `#6BA3E8`는 lib 전체에서 0건. 브랜드/actionPrimary는 green600 `#17855A`(초록) | 불일치 | Repo_JDH/lib/core/theme/app_colors.dart:35,85,161 |
| STEP 6 ① 표 (281행) | Flutter .env 키 = `NAVER_MAPS_CLIENT_ID` | 실제 키 이름은 `NAVER_MAP_CLIENT_ID`(MAP 단수) | 불일치 | Repo_JDH/lib/main.dart:29 / .env.example:5 |
| STEP 6 ① 표 (278~281행) | Flutter .env는 FASTAPI_BASE_URL·NAVER_MAPS_CLIENT_ID 2개만 | .env.example에 `NAVER_MAP_CLIENT_SECRET`, `GEMINI_API_KEY`도 기재 | 불일치 | Repo_JDH/.env.example:6,12 |
| STEP 6 ② 표 (287행) | 서버 .env에 TMAP_APP_KEY | 서버 .env.example에 존재 | 일치 | ploggo-server/.env.example:4 |
| STEP 6 ② 표 (288행) | 서버 .env에 `VWORLD_KEY` | 서버 .env.example에 없음 | 불일치 | ploggo-server/.env.example:1~15 |
| STEP 6 ② 표 (289~290행) | ALGO_ALPHA/BETA/GAMMA 0.5/0.5/1.0, ALGO_K/BF_TOP_N/MAX_SWAP 3/15/5 | config.py 기본값 동일 | 일치 | ploggo-server/route_recommender/config.py:22~27 |
| STEP 6 ② 표 (미기재) | — | 서버 .env.example에 `NAVER_MAPS_CLIENT_SECRET` 존재. 또한 server.py는 `NAVER_NEWS_CLIENT_ID/SECRET`, `GEMINI_MODEL`, `TMAP_TIMEOUT_S`, `AVOID_ZONES_GEOJSON`, `HOTSPOTS_CSV`를 읽음 | 문서 누락 | ploggo-server/.env.example:6 / server.py:77,78,128 / config.py:37,43,46 |
| STEP 6 코드 예시 (296행) | `Dio(BaseOptions(baseUrl: dotenv.env["FASTAPI_BASE_URL"]!))` | route_repository는 정규화 함수를 거쳐 주입(스킴·포트 보정). detector는 dio 미사용 | 일치 (route_repository 한정) | Repo_JDH/lib/features/plogging/data/route_repository.dart:14~25,32~48 |
| 9-1 표 (333행) | `auth_notifier.dart` (AsyncNotifier) | 파일 없음. 인증 상태는 core/providers/auth_provider.dart + app_router의 authStatusProvider | 불일치 | Repo_JDH/lib/features/auth/domain/ (user_profile.dart만 존재) / lib/core/providers/auth_provider.dart |
| 9-3 표 (355행) | route_repository.dart가 Dio로 POST /route/recommend | 동일 | 일치 | Repo_JDH/lib/features/plogging/data/route_repository.dart:77~85 |
| 9-3 표 (357행) | route_notifier가 AsyncNotifier + AsyncValue.guard | 동일 | 일치 | Repo_JDH/lib/features/plogging/domain/route_notifier.dart:10,23 |
| 9-3 (361행) | hotspot_repository.dart 삭제 | 파일 없음 | 일치 | Repo_JDH/lib/features/plogging/data/ |
| 9-4 (401행) | storage_repository.dart는 현재 구현에서 제거 | 파일 존재하고 사용 중 | 불일치 | Repo_JDH/lib/features/plogging/data/storage_repository.dart:5 / plogging_tracking_screen.dart:203 |
| 9-4 (408행) | 이미지를 /detect에 multipart의 `file` 필드로 전송 | 동일 | 일치 | Repo_JDH/lib/features/vision/data/detector.dart:65~68 / ploggo-server/server.py:288 |
| 9-4 코드 슬라이스 (415~421행) | `_dio.post("/detect", ...)` | 실제는 `http.MultipartRequest` + 하드코딩 URL | 불일치 | Repo_JDH/lib/features/vision/data/detector.dart:3,64~70 |
| 9-6 표 (440행) | community_repository.dart | 파일 없음. 실제는 group_service.dart | 불일치 | Repo_JDH/lib/features/community/data/group_service.dart |
| 9-6 표 (442~443행) | community_notifier.dart, news_notifier.dart | 둘 다 없음. community/domain에는 group.dart만 존재 | 불일치 | Repo_JDH/lib/features/community/domain/group.dart |
| 9-7 표 (455~456행) | user_repository.dart, user_notifier.dart | 둘 다 없음. mypage/data는 badge_service.dart 1개 | 불일치 | Repo_JDH/lib/features/mypage/data/badge_service.dart |
| 6-1 #33 (599행) | 이미지 처리 흐름 = 서버 직접 수신, Storage는 향후 | Firebase Storage 사용 중 | 불일치 | Repo_JDH/lib/features/plogging/data/photo_service.dart:63 |
| 6-2 #38 (628행) | Firebase Storage 이미지 전환 여부 = 미결 | 이미 전환·사용 중 | 불일치 | Repo_JDH/lib/features/plogging/presentation/plogging_tracking_screen.dart:203 |
| 6-2 #37 (627행) | primary color 최종 조정 = 잔여 | 문서가 기준으로 삼은 #6BA3E8이 코드에 없어 잔여 항목 기술 자체가 무효 | 불일치 | Repo_JDH/lib/core/theme/app_colors.dart:85 |

---

## 출력 2 — 문서 간 모순표

대상: `docs/guideline_v8.md`, `docs/PLAN.md`, `docs/TODO.md`, `docs/2026-07-01-프론트엔드현황.md`, `docs/2026-08-06-화면구조정리.md`, `CLAUDE.md`.
판정 기준은 코드 실제 구현이다.

| 사안 | 문서 A 서술 | 문서 B 서술 | 코드 실제 | 근거 |
|---|---|---|---|---|
| **경로 알고리즘 처리 위치** | guideline_v8 1-1·9-3: FastAPI 서버 전량 이관, Flutter는 요청·수신만 (45,350,365행) | PLAN.md 2-2·2-3: Flutter route_notifier가 Greedy로 K=3 선정 (95,127행). CLAUDE.md 6장: "Waypoint 알고리즘(K=3) — route_notifier (Flutter)" | **서버**. Flutter route_notifier는 Repository 호출만 수행, 점수·선정 로직 없음 | ploggo-server/route_recommender/algorithm.py:155~175,467 / Repo_JDH/lib/features/plogging/domain/route_notifier.dart:23~31 / CLAUDE.md 6장 표 / PLAN.md:95,127 |
| **이미지 저장소** | guideline_v8 1-1·1-3·9-4·6-1 #33: 앱 → 서버 직접 수신(multipart), Firebase Storage는 향후 검토 (53,110,401,599행) | PLAN.md 2-2 #21·3-4: Firebase Storage 확정(S3 미선택), putFile → URL을 FastAPI에 전달 (103,257,265행). CLAUDE.md 6장: "이미지 저장 — firebase_storage SDK 직접 사용" | **둘 다 사용 중**. 검출은 서버 multipart(detector.dart), 인증 이미지 보관은 Firebase Storage(plogging_tracking_screen·photo_service·user_service). 즉 guideline_v8의 "Storage 미사용"은 사실이 아니고, PLAN.md의 "서버가 URL로 다운로드"도 사실이 아님 | Repo_JDH/lib/features/vision/data/detector.dart:64~70 / plogging_tracking_screen.dart:203 / photo_service.dart:63 / user_service.dart:230 / ploggo-server/server.py:288 (URL 수신 파라미터 없음) |
| **바텀내비게이션바 위치** | guideline_v8 1-2·9-2·6-1 #4·10장: core/router의 ShellRoute 셸 `_ScaffoldWithBottomNav`가 담당 (94,346,607,691행) | PLAN.md 3-2·6-2 #4: home_screen.dart가 바텀내비를 포함, "home 내부 유지 권장" (220,499행). 2026-07-01 현황 6절: app_router.dart의 `_ScaffoldWithBottomNav` 커스텀 구현 (206행) | **ShellRoute 셸**. guideline_v8·2026-07-01 현황이 맞고 PLAN.md가 틀림 | Repo_JDH/lib/core/router/app_router.dart:165~168,288~394 |
| **도보 경로 API** | guideline_v8 1-1·STEP 5.6: Tmap Pedestrian API, 서버 내부 호출 (57,247행) | PLAN.md 2-2·3-3·6-1 #9·#12: Naver Directions 5, FastAPI 프록시, 차량 polyline 수용 (96,232,478,481행). CLAUDE.md 6장: "Naver Directions 5 호출 — dio로 FastAPI 호출" | **Tmap Pedestrian**. 서버가 `apis.openapi.sk.com/tmap/routes/pedestrian`을 직접 호출. Naver Directions 참조 0건 | ploggo-server/route_recommender/config.py:36 / algorithm.py:246 / ploggo-server 전체 "directions" 0건 |
| **공간 탐색 방식** | guideline_v8 1-1·7-1: 타원 buffer + numpy 전수 계산, GeoHash 인덱스 미사용 (59,649행) | PLAN.md 1-3·2-2·3-3·5-2: "GeoHash 핫스팟 탐색 응답 1초 이내", "Flutter Firestore GeoHash 쿼리", hotspot_repository.dart (39,94,231행) | **타원 buffer + numpy**. 서버에 GeoHash 없음, 앱에도 hotspot_repository 없음. `dart_geohash`는 등록만 되고 사용처 0건 | ploggo-server/route_recommender/algorithm.py:22,155~161 / Repo_JDH/pubspec.lock:379 / lib 내 geohash 0건 |
| **화면 파일명 (2026-08-06 리네임 반영)** | 2026-08-06 화면구조정리 2-1: plogging_home_screen→plogging_tracking_screen, plogging_session_screen→route_setup_screen, activity_screen→my_activity_screen, camera_screen→camera_detection_screen, plogging_session_providers→destination_providers (23~33행) | guideline_v8 9-3·9-4·9-7: route_screen.dart, tracking_screen.dart, camera_screen.dart, vision_result_screen.dart, mypage_screen.dart (358,359,398,399,457행). PLAN.md 3-3·3-4·3-7도 동일 옛 이름. 2026-07-01 현황도 옛 이름 | **리네임 후 이름이 실제**. guideline_v8(2026-07-08 작성)은 v8에서도 리네임을 반영하지 않았다. 화면구조정리 3-(h)가 "옛 파일명이 남아 있다"고 인정하나 대상에 guideline_v8은 빠져 있다 | Repo_JDH/lib/features/plogging/presentation/{plogging_tracking_screen,route_setup_screen}.dart / mypage/presentation/my_activity_screen.dart / vision/presentation/camera_detection_screen.dart / plogging/domain/destination_providers.dart |
| **core/widgets/ 상태** | guideline_v8 1-2·10장: "현재 비어 있음, 향후 추출용" (81,693행). 2026-07-01 현황 1절도 ".gitkeep(비어있음)" (24행) | 2026-08-06 화면구조정리 6절: "core/widgets/에 이미 app_button 등 6개가 있어 승격 자리는 준비되어 있다" (264행) | **7개 파일 존재**. 화면구조정리가 사실에 가깝고(개수만 1개 차이) guideline_v8이 틀림 | Repo_JDH/lib/core/widgets/ (app_button, app_card, app_dialog, app_section, app_snackbar, app_stat, trash_bag_icon) |
| **Gemini 뉴스 요약 구현 여부** | guideline_v8 1-1·9-6·6-2 #39: 현재 미구현, "서버에 키만 존재하고 실제 호출 코드가 없음 확인" (63,441,447,629행). 2026-07-01 현황 3절: "환경뉴스(Gemini) 미연동" (123행) | PLAN.md 1-2·3-6: Gemini 2.5 Flash 3줄 요약 기능 제공 (32,286행) | **구현 완료**. 서버 `_gemini_enrich()`가 3줄 요약·카테고리·언론사명을 생성하고 `/news`가 매 호출마다 실행. 앱도 `aiSummary`를 수신·표시. PLAN.md 쪽이 결과적으로 맞고 guideline_v8이 틀림 | ploggo-server/server.py:123,135~221,276 / Repo_JDH/lib/features/news/presentation/news_service.dart:72,89 |
| **환경 뉴스 데이터 소스** | guideline_v8 6-2 #7: 공개 RSS vs FastAPI 크롤러 미결 (623행). PLAN.md 6-2 #7 동일 (501행) | PLAN.md 2-1 아키텍처 도식: "News Crawler" (82행) | **네이버 뉴스 검색 API**. 크롤러도 RSS도 아님 | ploggo-server/server.py:79,224~254 |
| **뉴스 feature 위치** | guideline_v8 9-6: community feature의 news_repository.dart / news_screen.dart (441,445행). PLAN.md 3-6 동일 (291,295행) | 2026-08-06 화면구조정리 6절: news feature 존재를 전제로 `news/presentation/news_detail_screen.dart`의 NewsArticle 모델 위치를 지적 (266~268행) | **별도 news feature**. community/data/news_repository.dart는 `class NewsRepository {}` 빈 클래스이고, 실제 구현은 news/presentation/news_service.dart(data 성격 파일이 presentation에 위치) | Repo_JDH/lib/features/community/data/news_repository.dart:3 / lib/features/news/presentation/news_service.dart:11 |
| **reward feature 존재 여부** | guideline_v8 1-2·9-5: reward feature 및 reward_screen.dart 존재 전제 (86,432행). PLAN.md 3-5 동일 (272~280행). CLAUDE.md 2-3: feature 목록에 reward 포함 | 2026-07-01 현황 1절·3절: "reward — 폴더 자체 없음, 진척 0%" (76,122행). 2026-08-06 화면구조정리 3-(b): "/reward 라우트는 죽은 라우트, ShopScreen을 연결해야 한다" (93행) | **reward feature 없음**. 대신 shop feature(data 2·domain 2·presentation 3)가 포인트·쿠폰을 담당. `/reward`는 PlaceholderScreen | Repo_JDH/lib/features/ (reward 없음) / lib/features/shop/ / lib/core/router/app_router.dart:223~227 |
| **shop feature 문서화** | guideline_v8·PLAN.md·CLAUDE.md 모두 shop feature 미언급 | 2026-08-06 화면구조정리 3-(b)·3-(c): shop_screen.dart 완성, coupon_screen.dart 631줄 2화면 (93,102~105행) | **shop feature 존재**(shop_service, point_history_service, shop_item, point_log, 화면 3개) | Repo_JDH/lib/features/shop/ |
| **settings feature 정의** | CLAUDE.md 2-3 feature 목록에 settings 없음. PLAN.md 3-7: 설정은 mypage 하위 settings_screen.dart (308행) | guideline_v8 1-2·9-8: 별도 settings feature, menu_screen.dart (89,462~472행). 2026-07-01 현황: "가이드라인 미정의 feature (신규 추가됨)" (60,77행) | **별도 settings feature**의 menu_screen.dart. guideline_v8이 맞고 CLAUDE.md·PLAN.md가 갱신되지 않음 | Repo_JDH/lib/features/settings/presentation/menu_screen.dart / app_router.dart:18,185 |
| **settings feature의 data/domain** | guideline_v8 9-8 표: data·domain "(비어 있음) .gitkeep" (468,469행). 2026-07-01 현황 1절도 `.gitkeep` 표기 (61,62행) | 2026-08-06 화면구조정리: 해당 언급 없음 | **디렉토리 자체가 없음**. lib/ 전체에 .gitkeep 파일 0건 | Repo_JDH/lib/features/settings/ (presentation만) |
| **Docker 도입 시점** | guideline_v8 1-1·1-4-1: 미구현·향후 예정, Dockerfile 부재 확인 (68,124,128행) | PLAN.md 2-4·6-1 #22: "개발 착수 시점부터 Docker 이미지로 패키징", YOLO 가중치는 "Docker 이미지 내장" (167,173,185,491행) | **Docker 파일 없음**. 모델은 서버 루트에 평문 배치 | ploggo-server/ (Dockerfile·compose 0건) / ploggo-server/garbage_yolo_model.onnx / server.py:36 |
| **primary color** | guideline_v8 5-1·6-2 #37: 파스텔 블루 #6BA3E8 (575,627행). 2026-07-01 현황 5절·7절도 동일 (179,218행) | 2026-08-06 화면구조정리: 색상 언급 없음 | **초록 계열**. actionPrimary = green600 `#17855A`. `#6BA3E8`은 lib 전체 0건 | Repo_JDH/lib/core/theme/app_colors.dart:35,85,161 |
| **detector.dart의 서버 주소** | guideline_v8 3-1·STEP 6: "특정 EC2 IP 하드코딩 중, 제거 대상" (293,480행) | 2026-07-01 현황 3절: 하드코딩 주소를 `35.161.165.53:8000`으로 기재 (121행) | **`54.70.167.93:8000`**. 하드코딩 잔존은 맞으나 IP 값이 2026-07-01 현황과 다름(그 사이 변경) | Repo_JDH/lib/features/vision/data/detector.dart:62 |
| **Flutter .env 키 이름** | guideline_v8 STEP 6·PLAN.md 7-3: `NAVER_MAPS_CLIENT_ID`(MAPS 복수) (281,550행). CLAUDE.md 6장도 `NAVER_MAPS_CLIENT_ID` | 2026-07-01 현황 5절: 코드가 참조하는 키는 `NAVER_MAP_CLIENT_ID`(단수) (184행) | **`NAVER_MAP_CLIENT_ID`(단수)**. 2026-07-01 현황이 맞음 | Repo_JDH/lib/main.dart:29 / .env.example:5 |
| **Flutter .env 포함 키 범위** | guideline_v8 STEP 6·CLAUDE.md 6장: FASTAPI_BASE_URL과 NAVER_MAPS_CLIENT_ID 2개만. Secret·Gemini 키는 서버에만 | 2026-07-01 현황 5절: ".env / .env.example 파일 부재" (184행) — 현재는 사실이 아님 | **.env.example에 4개 키**. `NAVER_MAP_CLIENT_SECRET`, `GEMINI_API_KEY`가 Flutter 쪽 예시 파일에 포함되어 규칙 위반 | Repo_JDH/.env.example:5,6,9,12 |
| **hotspot_repository.dart** | guideline_v8 9-3: "v5의 hotspot_repository.dart는 삭제한다" (361행). PLAN.md 3-3: data 계층에 존재로 명시 (231행) | 2026-07-01 현황 4절: "부재. 핫스팟 탐색이 서버측이므로 클라이언트 미생성" (155행) | **파일 없음**(애초에 생성된 적 없음). guideline_v8의 "삭제한다"는 표현이 부정확 | Repo_JDH/lib/features/plogging/data/ |
| **3-Layer 위반 규모** | guideline_v8 4-2: 정비 필요는 vision domain 부재 1건 (545행) | 2026-08-06 화면구조정리 6절: "feature 간 직접 import 27건", NewsArticle 역방향 의존 3건 (268,274~276행) | **presentation→data 직접 import 34건**(그중 feature 교차 11건). guideline_v8의 인식이 실제 규모와 크게 다름 | 출력 1 F절 세부 목록 참조 |
| **`_service` 명명 규칙** | CLAUDE.md 3-1: "`_service.dart` 명명은 사용하지 않는다. `_repository.dart`로 통일" | 2026-07-01 현황 1절: 위반 2~3건 지적 (81행) | **위반 8건**: user_service, group_service, badge_service, activity_service, attendance_service, photo_service, point_history_service, shop_service, news_service. guideline_v8은 이 규칙을 아예 다루지 않음 | Repo_JDH/lib/features/*/data/*_service.dart, lib/features/news/presentation/news_service.dart |
| **라우트 개수** | 2026-07-01 현황 5절: "정의된 라우트 14개" (175행) | 2026-08-06 화면구조정리 4-2: "라우트 15개" (194~199행) | **15개**(splash 포함). 화면구조정리가 맞음 | Repo_JDH/lib/core/router/app_router.dart:151~233 |
| **initialLocation** | 2026-07-01 현황 5절: `initialLocation: /home` (173행) | 2026-08-06 화면구조정리 4-2: splash를 첫 라우트로 열거 (196행) | **`/splash`** | Repo_JDH/lib/core/router/app_router.dart:102 |
| **STEP 1~9 체크박스** | guideline_v8 STEP 1·3·4·5·6·7·8·9 = `⬜`, STEP 2 = `✅` | PLAN.md 5-1: 동일한 체크박스 상태 (412~421행). PLAN.md 5-3: "applicationId 변경 필요(com.example.repo_jdh → com.ploggo.app)" (446행) | STEP 3·7·8은 완료, STEP 1도 실질 완료. applicationId는 이미 `com.ploggo.app`. 두 문서가 같은 값으로 동기화되어 있으나 **둘 다 코드보다 뒤처져 있음** | Repo_JDH/android/app/build.gradle.kts:21 / lib/main.dart:18~46 / lib/core/router/app_router.dart:98~233 |
| **Dart 패키지명 / applicationId** | guideline_v8 STEP 3·PLAN.md 6-1 #1·CLAUDE.md 1장: `com.ploggo.app`으로 확정 표기 | 어느 문서도 Dart 패키지명(`repo_jdh`)을 명시하지 않음 | **applicationId = com.ploggo.app, Dart 패키지명 = repo_jdh**. import는 전부 `package:repo_jdh/...`. `package:ploggo/...`는 0건 | Repo_JDH/pubspec.yaml:1 / android/app/build.gradle.kts:21 / lib/core/router/app_router.dart:4,8~21 |
| **폰트** | guideline_v8 1-1: Noto Sans KR "한국어·영어 통일 서체" (65행). PLAN.md·CLAUDE.md 미언급 | 2026-07-01 현황 2절: "로컬 폰트 Pretendard(메인) + NotoSansKR(백업)" (108행) | **Pretendard 메인**(4 weight), NotoSansKR은 "백업 폰트(나중에 삭제 가능)" 주석. 2026-07-01 현황이 맞음 | Repo_JDH/pubspec.yaml:98~118 |
| **TODO (다) 항목** | TODO.md (다): "추적 화면(PloggingHomeScreen)의 정적 지도 이미지를 실제 NaverMap으로 교체" (5행) | 2026-08-06 화면구조정리 2-1: `PloggingHomeScreen`은 `PloggingTrackingScreen`으로 리네임됨 (24행) | **클래스명은 PloggingTrackingScreen**. TODO.md가 옛 이름을 그대로 둠(화면구조정리 3-(h)가 인정한 미갱신 문서) | Repo_JDH/lib/features/plogging/presentation/plogging_tracking_screen.dart |
| **의사결정 #4 상태** | guideline_v8 6-1: v7에서 해소되어 6-1로 이동 (607,617행) | PLAN.md 6-2 #4: 여전히 잔여 항목, "home 내부 유지 권장" (499행) | **해소됨**(ShellRoute 셸). guideline_v8이 맞고 PLAN.md 미갱신 | Repo_JDH/lib/core/router/app_router.dart:165~168 |
| **의사결정 #3(중앙 시작 버튼)** | guideline_v8 STEP 8·6-2 #3: 탭 전환 vs push 미확정 (322,621행). PLAN.md 6-2 #3 동일 (498행) | 2026-08-06 화면구조정리: 언급 없음 | **push로 구현됨** (`context.push(AppRoutes.ploggingRoute)`). 코드는 이미 결정된 상태 | Repo_JDH/lib/core/router/app_router.dart:482 |
| **목적지 입력 / 지오코딩** | guideline_v8 1-1·3-5·STEP 5.5: 지도 마커 좌표 직접 획득, 지오코딩 불필요 (58,232,530행) | PLAN.md 2-3·6-1 #10: Geocoding(주소→좌표) 단계 포함, Naver Geocoding 확정 (123,479행). CLAUDE.md 6장: "Naver Geocoding 호출 — dio로 FastAPI 호출" | **지도 탭으로 좌표 획득**(주소→좌표 변환 없음). 다만 `geocoding` 패키지로 좌표→주소 역변환은 사용 중이며, 어느 문서에도 이 용도가 서술되지 않음 | Repo_JDH/lib/features/plogging/presentation/route_setup_screen.dart:236 / lib/features/plogging/data/location_repository.dart:3,44 |

---

## 감사 요약

- 감사 항목 총 약 130건. **일치 46건 / 불일치 55건 / 문서 누락 25건 / 검증 불가 4건.**
- 판정 불일치의 성격은 대부분 **문서가 코드보다 뒤처진 것**이지, 코드가 규칙을 어긴 것이 아니다. 예외는 3-Layer 의존성 위반 34건, detector.dart의 IP 하드코딩, Flutter `.env.example`의 Secret·Gemini 키 노출 3건으로, 이들은 코드 쪽 정비 대상이다.
- 영향이 큰 순서로 정리하면 다음과 같다.
  1. **Firebase Storage** — guideline_v8이 "미사용"으로 규정한 항목이 4개 파일에서 실사용 중이다. #33·#38 의사결정 기술 전체가 무효 상태다.
  2. **Gemini 뉴스 요약** — "코드 없음이 확인되었다"는 v7 검수 결론이 사실과 다르다. #39는 이미 해소된 항목이다.
  3. **화면 파일명** — 2026-08-06 리네임이 guideline_v8(2026-07-08)에 반영되지 않았고, v8 갱신 시에도 반영되지 않았다. SB 프로그램 ID 표기와 직접 충돌한다.
  4. **STEP 체크박스** — STEP 3·7·8은 완료되었으나 `⬜`로 남아 있어 진척도 판단을 왜곡한다.
  5. **feature 목록** — 문서에 있고 코드에 없는 것(reward), 코드에 있고 문서에 없는 것(news, shop)이 각각 존재한다.
  6. **core/widgets/** — v8이 "비어 있음"으로 *정정*한 서술이 오히려 사실과 반대다.
- 검증 불가 4건은 모두 외부 콘솔 상태(Firebase 프로젝트 등록, SHA-1 등록, NCP Application 등록, EC2 인스턴스)로, 저장소 파일만으로는 판정할 수 없다.

감사 수행: 2026-08-10 · 코드·문서 무수정
