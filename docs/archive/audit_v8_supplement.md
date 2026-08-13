# audit_v8 보완 조사

- 작성일: 2026-08-12
- 범위: `Repo_JDH`, `ploggo-server` 두 저장소로 한정
- 기준 커밋: `f/route` 브랜치 HEAD (`7b4628e`)
- 수정 여부: **코드·문서 일절 수정하지 않음** (본 파일만 신규 생성)
- 실행 환경: Flutter 3.44.2 (stable) / Dart 3.12.2

---

## 1. 역방향 의존 전수 추출

정의: 의존성 허용 방향은 `presentation → domain → data`. 아래는 **data 또는 core 계층 파일이 presentation 파일을 import하는 사례**의 전수 목록이다.

### 1-A. data → presentation

| # | 파일:라인 | import 대상 |
|---|---|---|
| — | 해당 없음 (0건) | — |

`lib/features/*/data/` 하위 전체를 대상으로 `^import .*presentation/`(패키지 경로) 및 `^import '(\./|\.\./)...'`(상대 경로) 두 형태를 모두 검색했으며 매칭 0건이다.

### 1-B. core → presentation (12건)

| # | 파일:라인 | import 대상 |
|---|---|---|
| 1 | `lib/core/router/app_router.dart:9` | `package:repo_jdh/features/auth/presentation/login_screen.dart` |
| 2 | `lib/core/router/app_router.dart:10` | `package:repo_jdh/features/auth/presentation/nickname_setup_screen.dart` |
| 3 | `lib/core/router/app_router.dart:12` | `package:repo_jdh/features/plogging/presentation/plogging_tracking_screen.dart` |
| 4 | `lib/core/router/app_router.dart:13` | `package:repo_jdh/features/home/presentation/home_screen.dart` |
| 5 | `lib/core/router/app_router.dart:14` | `package:repo_jdh/features/community/presentation/group_screen.dart` |
| 6 | `lib/core/router/app_router.dart:15` | `package:repo_jdh/features/mypage/presentation/my_activity_screen.dart` |
| 7 | `lib/core/router/app_router.dart:16` | `package:repo_jdh/features/settings/presentation/menu_screen.dart` |
| 8 | `lib/core/router/app_router.dart:17` | `package:repo_jdh/features/plogging/presentation/settlement_screen.dart` |
| 9 | `lib/core/router/app_router.dart:18` | `package:repo_jdh/features/community/presentation/group_feed_screen.dart` |
| 10 | `lib/core/router/app_router.dart:19` | `package:repo_jdh/features/plogging/presentation/route_setup_screen.dart` |
| 11 | `lib/core/view_models/screen_views.dart:27` | `package:repo_jdh/features/news/presentation/news_service.dart` |
| 12 | `lib/core/view_models/screen_views.dart:28` | `package:repo_jdh/features/news/presentation/news_detail_screen.dart` |

**성격 구분**

- **1~10 (`app_router.dart`)**: go_router 라우트 테이블이 화면 위젯을 참조하는 것은 라우터의 구조적 필연이다. 다만 CLAUDE.md 2-1은 `core/router/`를 "go_router 라우팅 정의"로만 규정하고 core가 feature presentation을 참조하는 예외를 명시하지 않았으므로, 규칙 문언상으로는 미규정 상태다.
- **11~12 (`screen_views.dart`)**: 구조적 필연이 아니다. `screen_views.dart`는 자기 자신이 "화면별 뷰모델"(`screen_views.dart:1`)임을 선언하면서, presentation에 위치한 `news_service.dart`(데이터 접근 클래스)와 `news_detail_screen.dart`(`NewsArticle` 모델 보유)를 참조한다. 즉 **모델·데이터 접근 코드가 presentation에 잘못 배치되어 있기 때문에 발생한 파생 위반**이다.

### 1-C. (관련) data → domain — 10건

CLAUDE.md 2-2는 "data는 외부 SDK·API만 호출한다. **domain·presentation을 알지 못한다**"로 규정한다. presentation 대상은 0건이나 domain 대상은 10건이다. 항목 1의 직접 요청 범위 밖이지만 동일 조항의 역방향 위반이므로 병기한다.

| # | 파일:라인 | import 대상 |
|---|---|---|
| 1 | `lib/features/auth/data/user_profile_provider.dart:4` | `.../auth/domain/user_profile.dart` |
| 2 | `lib/features/auth/data/user_service.dart:5` | `.../auth/domain/user_profile.dart` |
| 3 | `lib/features/auth/data/user_service.dart:6` | `.../mypage/domain/profile_detail.dart` |
| 4 | `lib/features/community/data/group_service.dart:3` | `.../community/domain/group.dart` |
| 5 | `lib/features/mypage/data/badge_service.dart:4` | `.../plogging/domain/activity_metrics.dart` |
| 6 | `lib/features/mypage/data/badge_service.dart:5` | `.../mypage/domain/badge.dart` |
| 7 | `lib/features/plogging/data/activity_service.dart:2` | `.../plogging/domain/activity.dart` |
| 8 | `lib/features/plogging/data/route_repository.dart:9` | `../domain/route_models.dart` |
| 9 | `lib/features/shop/data/point_history_service.dart:3` | `.../shop/domain/point_log.dart` |
| 10 | `lib/features/shop/data/shop_service.dart:3` | `.../shop/domain/shop_item.dart` |

### 1-D. (관련) core → data — 8건

| # | 파일:라인 | import 대상 |
|---|---|---|
| 1 | `lib/core/dev/dev_data.dart:2` | `.../mypage/data/badge_service.dart` |
| 2 | `lib/core/providers/plogging_provider.dart:2` | `../../features/plogging/data/firestore_repository.dart` |
| 3 | `lib/core/providers/tracking_provider.dart:4` | `.../plogging/data/location_repository.dart` |
| 4 | `lib/core/router/app_router.dart:11` | `.../auth/data/user_profile_provider.dart` |
| 5 | `lib/core/view_models/screen_views.dart:17` | `.../community/data/group_service.dart` |
| 6 | `lib/core/view_models/screen_views.dart:19` | `.../mypage/data/badge_service.dart` |
| 7 | `lib/core/view_models/screen_views.dart:22` | `.../plogging/data/activity_service.dart` |
| 8 | `lib/core/view_models/screen_views.dart:26` | `.../auth/data/user_service.dart` |

### 1-E. 계층 간 의존 방향 종합

| 방향 | 건수 | 허용 여부 |
|---|---|---|
| presentation → domain | (허용 방향, 미집계) | 허용 |
| presentation → data | 34 | 금지 (CLAUDE.md 2-2, 4-3) |
| domain → data | 2 | 허용 |
| data → domain | 10 | 금지 (CLAUDE.md 2-2) |
| data → presentation | 0 | 금지 — 위반 없음 |
| core → presentation | 12 | 미규정 (10건은 라우터 필연, 2건은 구조 결함) |
| core → data | 8 | 미규정 |

---

## 2. flutter analyze 결과

실행 명령: `flutter analyze --no-pub` / 소요 12.7초 / **총 61 issues**

### 2-A. 심각도별 총계

| 심각도 | 건수 |
|---|---|
| error | 0 |
| warning | 3 |
| info | 58 |
| **합계** | **61** |

### 2-B. 규칙별 집계

| 규칙 | 심각도 | 건수 | 분포 |
|---|---|---|---|
| `avoid_print` | info | 52 | `auth/data/auth_repository.dart` 13, `plogging/data/firestore_repository.dart` 17, `plogging/data/location_repository.dart` 8, `plogging/data/storage_repository.dart` 14 |
| `deprecated_member_use` | info | 5 | `news_detail_screen.dart:83` 2건(`Share`/`share`), `coupon_screen.dart:300` 2건(`Share`/`shareXFiles`), `plogging_tracking_screen.dart:558` 1건(`axisAlignment`) |
| `constant_identifier_names` | info | 1 | `vision/data/detector.dart:62` — `SERVER_URL` |
| `unused_import` | **warning** | 1 | `settings/presentation/menu_screen.dart:4` — `core/theme/app_spacing.dart` |
| `unnecessary_non_null_assertion` | **warning** | 1 | `plogging/presentation/route_setup_screen.dart:555` |
| `asset_does_not_exist` | **warning** | 1 | `pubspec.yaml:95` — 에셋 `.env` 파일 부재 |
| `unused_element` | — | 0 | 검출 없음 |

### 2-C. 주목 사항

1. `avoid_print` 52건이 전체의 85%이며, **전부 data 레이어 4개 파일에 집중**되어 있다. presentation 레이어에는 `print` 호출이 없다.
2. `asset_does_not_exist`(`pubspec.yaml:95`)는 단순 경고가 아니라 **빌드 차단 요인**이다 — 항목 3 참조.
3. `detector.dart:62`의 `SERVER_URL`은 audit_v8에서 지적한 EC2 IP 하드코딩과 동일 라인이며, 명명 규칙 위반으로도 이중 검출된다.

---

## 3. test/ 디렉토리 상태

### 3-A. 구성

```
test/
└── widget_test.dart      (31줄, 유일한 테스트 파일)
```

### 3-B. Flutter 기본 카운터 템플릿 여부 — **템플릿 원본 그대로**

| 판단 근거 | 파일:라인 |
|---|---|
| 템플릿 주석 원문(`// This is a basic Flutter widget test.`) 미삭제 | `test/widget_test.dart:1-6` |
| 테스트명이 템플릿 기본값 `'Counter increments smoke test'` | `test/widget_test.dart:14` |
| 카운터 0 → 1 증가 검증문 | `test/widget_test.dart:18-19, 26-28` |
| `Icons.add` 탭 (카운터 앱 FAB) | `test/widget_test.dart:23` |

패키지명만 `package:repo_jdh/main.dart`로 자동 반영되어 있고(`:11`), 그 외 본 프로젝트 코드에 맞춘 수정은 전혀 없다.

### 3-C. 실행 결과 — **실패 (테스트 실행 이전 단계에서 빌드 중단)**

`flutter test --no-pub` 실제 출력 전문:

```
Error detected in pubspec.yaml:
No file or variants found for asset: .env.

Error: Failed to build asset bundle
```

**판단**: 테스트 케이스가 실행되지도 못한다. `pubspec.yaml:95`가 `.env`를 에셋으로 선언했으나 작업 트리에 `.env` 파일이 없어 에셋 번들 빌드 단계에서 중단된다.

### 3-D. `.env`를 배치해도 실패하는가 — **실패한다**

에셋 문제를 해소하더라도 두 가지 이유로 이 테스트는 통과할 수 없다.

| # | 사유 | 근거 |
|---|---|---|
| 1 | `MyApp`은 `ConsumerWidget`이고 앱은 `ProviderScope`로 감싸 실행된다(`lib/main.dart:46`, `:49`). 테스트는 `ProviderScope` 없이 `pumpWidget(const MyApp())`를 호출한다(`test/widget_test.dart:16`). | `lib/main.dart:46,49` / `test/widget_test.dart:16` |
| 2 | 본 앱은 카운터 앱이 아니다. 초기 라우트는 스플래시이며(`app_router.dart:102` `initialLocation: AppRoutes.splash`) 텍스트 `'0'`도 `Icons.add` FAB도 존재하지 않는다. `find.text('0')` / `find.byIcon(Icons.add)` 는 매칭 실패한다. | `lib/core/router/app_router.dart:102` / `test/widget_test.dart:19,23` |

**결론**: 본 저장소에는 **유효한 테스트가 0개**이며, 유일한 테스트 파일은 실행 시 실패한다.

---

## 4. CLAUDE.md 조항별 준수 여부

### 4-0. 선행 확인 — CLAUDE.md는 현재 저장소에 존재하지 않는다

| 확인 항목 | 결과 | 근거 |
|---|---|---|
| 작업 트리 존재 | 없음 | `Glob **/CLAUDE.md` → 0건 |
| git 추적 여부 | 미추적 | `git ls-files CLAUDE.md` → 빈 출력 |
| 최초 생성 | `f6e1325` "docs: 클로드/plan md 파일 생성" | `git log --all -- CLAUDE.md` |
| 삭제 커밋 | `3aaa1e9` "상의한 부분 수정" (f/route, main 양쪽에 포함) | `git log --all --diff-filter=D -- CLAUDE.md` |
| 상위 스코프 대체본 | 없음 (`~/.claude/CLAUDE.md` 부재, `ploggo-server/CLAUDE.md` 부재) | `ls` 확인 |

따라서 **아래 표는 삭제 직전 최종본(`git show 3aaa1e9^:CLAUDE.md`, 237줄, 버전 1.1 / 작성 2026-05-24)을 기준**으로 판정한 것이다. 이 문서는 현재 어떤 도구에도 자동 로드되지 않는다.

### 4-1. 조항별 판정표

판정 값: **준수 / 위반 / 판정 불가** (3가지만 사용)

| 조항 번호 | 조항 내용 | 준수 여부 | 위반 건수 | 근거 |
|---|---|---|---|---|
| 1-a | 프레임워크는 Flutter 3.41.x + Dart 3.11.x | 위반 | 1 | 실제 Flutter 3.44.2 / Dart 3.12.2 (`flutter --version`), `pubspec.yaml:7` `sdk: ^3.9.2` |
| 1-b | 패키지명(applicationId)은 `com.ploggo.app` | 준수 | 0 | `android/app/build.gradle.kts:21` `applicationId = "com.ploggo.app"`, `:11` namespace 동일 |
| 1-c | 최소 Android SDK 26 | 준수 | 0 | `android/app/build.gradle.kts:24` `minSdk = 26` |
| 1-d | 백엔드는 Firebase Auth/Firestore/Storage + FastAPI(AWS EC2) | 준수 | 0 | `pubspec.yaml:24-26` firebase 3종, `lib/features/plogging/data/route_repository.dart:15` FastAPI 호출 |
| 1-e | YOLOv8n·Gemini 모두 FastAPI 프록시 경유 | 준수 | 0 | `ploggo-server/server.py:287` `/detect`, `:135-221` `_gemini_enrich()`; Flutter에 두 SDK 직접 호출 없음 |
| 1-f | 지도는 Naver Directions 5 + Naver Geocoding, 모두 FastAPI 프록시 경유 | 위반 | 2 | 도보 경로는 Tmap Pedestrian (`ploggo-server/route_recommender/config.py:36` `TMAP_PEDESTRIAN_URL`, `algorithm.py:246`); 역지오코딩은 프록시 없이 `geocoding` 패키지 직접 호출 (`lib/features/plogging/data/location_repository.dart:3,44`) |
| 2-1 | `lib/core/`는 constants/providers/router/theme/utils/widgets 6개로 구성 | 위반 | 3 | 실제 7개: `constants`, `dev`, `providers`, `router`, `theme`, `view_models`, `widgets`. `utils/` 부재, `dev/`·`view_models/` 미규정 추가 |
| 2-2 | 레이어 의존은 `presentation → domain → data` 단방향, 역방향 import 금지 | 위반 | 44 | presentation→data 34건(§1-E), data→domain 10건(§1-C) |
| 2-3 | feature 목록은 auth, home, plogging, vision, reward, community, mypage 7개 | 위반 | 4 | `lib/features/` 실제 9개 — `reward` 부재, `news`·`shop`·`settings` 미규정 추가 |
| 2-4 | `presentation/widgets/`·`domain/models/`·`data/dto/`는 필요 시점에만 추가 | 위반 | 2 | presentation 34개 중 200줄 초과 30개인데 `presentation/widgets/` 디렉토리 0개 (`find lib/features -type d`); domain 직하 모델 파일 14개인데 `domain/models/` 0개 |
| 3-1-a | data 파일명은 `{대상}_repository.dart` | 위반 | 8 | data 레이어 `_service.dart` 8건: `auth/data/user_service.dart`, `community/data/group_service.dart`, `mypage/data/badge_service.dart`, `plogging/data/activity_service.dart`, `plogging/data/attendance_service.dart`, `plogging/data/photo_service.dart`, `shop/data/point_history_service.dart`, `shop/data/shop_service.dart` |
| 3-1-b | domain 파일명은 `{기능}_notifier.dart` | 준수 | 0 | domain 내 Notifier는 `lib/features/plogging/domain/route_notifier.dart` 1개이며 패턴 일치 |
| 3-1-c | presentation 파일명은 `{기능}_screen.dart` 또는 보조 위젯 스네이크 케이스 | 위반 | 1 | `lib/features/news/presentation/news_service.dart` — 화면도 보조 위젯도 아닌 HTTP 데이터 접근 클래스 (`:4` `package:http`, `:26` `$_baseUrl/news`) |
| 3-1-d | `_service.dart` 명명 금지, 외부 서비스 접근 클래스도 `_repository.dart`로 통일 | 위반 | 9 | 3-1-a의 8건 + `news/presentation/news_service.dart` |
| 3-1-e | 코드 생성기가 만든 `.g.dart`는 수정하지 않는다 | 판정 불가 | — | 대상 파일은 `lib/core/router/app_router.g.dart` 1개. 수동 편집 여부는 생성기 재실행 없이 판별 불가 |
| 3-2 | 클래스명은 파스칼 케이스 | 준수 | 0 | `grep -rh "^class "` 전수 검사 결과 비-파스칼 0건. `_`로 시작하는 항목은 전부 Dart 표준 private + PascalCase(`_ScaffoldWithBottomNav` 등) |
| 4-1 | Riverpod 2.x 사용, 3.x 전용 API 사용 금지 | 준수 | 0 | `pubspec.lock:645` `flutter_riverpod 2.6.1`; 3.x 전용 API 검출 없음 (`flutter analyze` error 0) |
| 4-2 | 상황별 Provider 선택 기준(FutureProvider/AsyncNotifier/Notifier) | 판정 불가 | — | "단순 읽기 전용" / "사용자 액션" 분류가 코드에서 기계적으로 판별되지 않음 |
| 4-3-a | 복잡한 파이프라인·화면 간 상태 공유에 `setState` 사용 금지 | 위반 | 120 | `setState(` 호출 120건 / 26개 파일. Firestore 로드 결과를 setState로 반영하는 대표 사례: `community/presentation/group_screen.dart:36`, `shop/presentation/shop_screen.dart:24`, `mypage/presentation/profile_screen.dart:24` |
| 4-3-b | `isLoading`/`hasError` boolean 수동 관리 금지, `AsyncValue` 사용 | 위반 | 9 | `login_screen.dart:27`, `signup_screen.dart:33`, `group_screen.dart:36`, `group_search_screen.dart:31`, `profile_screen.dart:24`, `quest_list_screen.dart:23`, `coupon_screen.dart:25`, `point_history_screen.dart:17`, `shop_screen.dart:24` |
| 4-3-c | presentation에서 data Repository 직접 import 금지 | 위반 | 34 | §1-E. 대표: `settlement_screen.dart:13,14,17,18,19` 5건, `plogging_tracking_screen.dart:13,16,21,22` 4건 |
| 4-4-a | 비동기 처리는 `AsyncValue.guard`로 감싼다 | 위반 | 1 | 전체 코드베이스에서 `AsyncValue.guard` 사용은 `plogging/domain/route_notifier.dart:23` 단 1곳. 나머지 비동기 로드는 전부 setState 기반 |
| 4-4-b | UI는 `AsyncValue.when(data:, loading:, error:)`으로 분기 | 위반 | 1 | `.when(` 전체 2건에 불과. `ConsumerWidget` 계열 12개 대비 현저히 적음 |
| 4-4-c | 위젯은 `ConsumerWidget`/`ConsumerStatefulWidget`을 상속 | 위반 | 89 | `ConsumerWidget`·`ConsumerStatefulWidget` 상속 12건 vs 순수 `StatelessWidget`·`StatefulWidget` 상속 89건 |
| 4-4-d | `ref.watch()`와 `ref.read()`를 사용처에 따라 구분 | 판정 불가 | — | 호출 위치별 적절성 판단이 정적 검색으로 불가 |
| 4-4-e | 순차적 데이터 파이프라인은 Provider 체인으로 구성 | 판정 불가 | — | 조항이 예시로 든 `cameraProvider → uploadProvider → visionProvider` 체인 자체가 부재하여, 미구현인지 미해당인지 구분 불가 |
| 5-1 | `withOpacity()` 금지, `withValues(alpha:)` 사용 | 준수 | 0 | `withOpacity` 검색 결과 0건 (audit_v8 §K 재확인) |
| 5-2 | 코드 수정 시 전체 파일 덮어쓰기 금지 | 판정 불가 | — | 작업 방식에 관한 프로세스 조항. 최종 코드 상태로 판별 불가 |
| 5-3 | 코드 주석은 한국어로 작성 | 준수 | 0 | `//` 주석 라인 2,162건 중 2,020건(93.4%)에 한글 포함. 나머지는 대부분 `// ═══` 구분선·URL |
| 5-4 | Naver Maps `NLatLng` 사용, Google Maps import 금지 | 준수 | 0 | `google_maps` 검색 결과 lib 전체 0건, `pubspec.yaml`에도 `google_maps_flutter` 없음 |
| 5-5-a | 동일 패키지 내부 import는 `package:repo_jdh/...` 사용, 상대 경로 금지 | 위반 | 6 | `auth/presentation/signup_screen.dart:5`, `vision/presentation/box_painter.dart:2`, `auth/presentation/login_screen.dart:7`, `core/providers/plogging_provider.dart:2`, `plogging/data/route_repository.dart:9`, `plogging/domain/route_notifier.dart:7` |
| 5-5-b | import 순서: dart → flutter → 외부 패키지 → 본 프로젝트 | 판정 불가 | — | 34개 화면 전수 순서 검증을 수행하지 않음. 미검증 항목이므로 추정하지 않음 |
| 6-a | Waypoint 알고리즘(K=3)은 Flutter `route_notifier`가 담당 | 위반 | 1 | `route_notifier.dart`는 `AsyncValue.guard`로 Repository 호출만 수행(`:23`). 알고리즘은 서버 `ploggo-server/route_recommender/algorithm.py`(502줄, numpy 기반)에 존재 |
| 6-b | Naver Directions 5 호출을 FastAPI 프록시가 담당 | 위반 | 1 | 서버는 Tmap Pedestrian 호출 (`route_recommender/algorithm.py:246`, `config.py:36`). Naver Directions 코드 부재 |
| 6-c | Naver Geocoding 호출을 dio로 FastAPI 경유 | 위반 | 1 | Flutter가 `geocoding` 패키지로 직접 처리 (`plogging/data/location_repository.dart:3,44` `placemarkFromCoordinates`). 서버에 지오코딩 엔드포인트 없음 |
| 6-d | YOLOv8n 추론은 dio로 FastAPI 호출 | 위반 | 2 | `vision/data/detector.dart:3` `package:http` 사용(dio 아님), `:62` `SERVER_URL = 'http://54.70.167.93:8000'` 하드코딩(`FASTAPI_BASE_URL` 미사용) |
| 6-e | Gemini API는 dio로 FastAPI 호출 | 위반 | 1 | 프록시 경유는 준수하나 dio가 아닌 `package:http` 사용 (`news/presentation/news_service.dart:4,26`) |
| 6-f | 인증은 `firebase_auth` SDK 직접 사용 | 준수 | 0 | `lib/features/auth/data/auth_repository.dart` — FastAPI 경유 없음 |
| 6-g | DB는 `cloud_firestore` SDK 직접 사용 | 준수 | 0 | `lib/features/plogging/data/firestore_repository.dart` 등 data 레이어 전반 |
| 6-h | 이미지 저장은 `firebase_storage` SDK 직접 사용 | 준수 | 0 | `plogging/data/storage_repository.dart:6`, `plogging/data/photo_service.dart:63`, `auth/data/user_service.dart:230` |
| 6-i | Naver Client Secret·Gemini API Key를 Flutter 코드나 `.env`에 포함 금지 | 위반 | 2 | `Repo_JDH/.env.example:6` `NAVER_MAP_CLIENT_SECRET`, `:12` `GEMINI_API_KEY` (키 이름만 확인, 값 미열람) |
| 6-j | Flutter `.env`에는 `NAVER_MAPS_CLIENT_ID`와 `FASTAPI_BASE_URL`만 포함 | 위반 | 3 | 키 이름이 `NAVER_MAP_CLIENT_ID`(MAPS 아님, `.env.example:5` / `lib/main.dart:29`)이고, 조항이 허용하지 않은 2개 키가 추가로 존재 (`.env.example:6,12`) |
| 6-k | Firebase 접근 시 별도 토큰 핸들링 코드를 작성하지 않는다 | 준수 | 0 | data 레이어에 수동 ID 토큰 취득·첨부 코드 없음 |
| 7-1 | `google_maps_flutter`, `provider`, `bloc` 사용 금지 | 준수 | 0 | `pubspec.yaml` 검색 결과 3종 모두 0건 |
| 7-2 | `riverpod_generator` 산출물 `.g.dart`를 직접 수정하지 않는다 | 판정 불가 | — | 3-1-e와 동일 사유 |
| 8 | 커밋 메시지는 `feat:`/`fix:`/`refactor:`/`chore:`/`docs:` prefix 사용 | 위반 | 50 | 비-merge 커밋 67건 중 규격 준수 17건(25.4%), 위반 50건. 예: "굵직하게는 다 수정한듯", "폴더 정리....", "초기설정260125_1", `update:` prefix 5건(허용 목록 외) |
| 9-1-a | 코드 수정 전 해당 feature 폴더의 기존 구조·명명을 먼저 확인 | 판정 불가 | — | 프로세스 조항. 최종 코드로 판별 불가 |
| 9-1-b | Riverpod 코드 작성 시 Context7 MCP로 2.x 문서 참조 | 판정 불가 | — | 도구 사용 이력이 저장소에 남지 않음 |
| 9-1-c | 외부 패키지 API 사용 시 Context7로 현재 버전 문서 확인 | 판정 불가 | — | 동일 사유 |
| 9-2-a | 코드 변경 후 `flutter analyze`로 오류·경고 확인 | 위반 | 3 | 미해소 warning 3건 잔존 — `menu_screen.dart:4` unused_import, `route_setup_screen.dart:555` unnecessary_non_null_assertion, `pubspec.yaml:95` asset_does_not_exist(빌드 차단, §3-C) |
| 9-2-b | 새 파일 생성 시 본 문서의 명명 규칙 준수 | 위반 | 9 | 3-1-d와 동일 (`_service.dart` 9건) |
| 9-2-c | presentation에서 data를 직접 import하지 않았는지 의존성 방향 점검 | 위반 | 34 | 4-3-c와 동일 |
| 10 | 비전·기능 명세·알고리즘 검증·서버 코드는 본 문서 범위 밖 (`docs/PLAN.md` 참조) | 판정 불가 | — | 문서 범위를 선언하는 메타 조항으로, 코드 준수 대상이 아님 |

### 4-2. 판정 집계

| 판정 | 건수 |
|---|---|
| 준수 | 14 |
| 위반 | 26 |
| 판정 불가 | 11 |
| **합계** | **51** |

위반 조항의 총 위반 건수 합계: **약 476건** (최다: `setState` 120, `avoid_print` 관련 미포함, `ConsumerWidget` 미상속 89, 커밋 규격 50, presentation→data 34×2회 계상 조항 포함).

### 4-3. 구조적 결론

CLAUDE.md는 **삭제되어 현재 강제력이 없는 문서**이며, 남아 있는 최종본 기준으로는 아키텍처 조항(2-2, 4-3, 4-4)과 백엔드 책임 분담 조항(6)이 사실상 전면 미준수 상태다. 특히 6절은 11개 항목 중 6개가 위반인데, 이는 코드가 규칙을 어긴 것이 아니라 **프로젝트 설계 자체가 2026-05-24 이후 변경(경로 알고리즘 서버 이전, Naver Directions → Tmap 전환)되었으나 CLAUDE.md가 갱신되지 않은 채 삭제된 것**이다. audit_v8에서 확인한 `guideline_v8.md`의 55건 불일치와 같은 원인이다.

---

## 5. `.env` 관련 확인

> `.env` 파일의 내용은 열람하지 않았다. 존재 여부, `.gitignore` 등록 상태, git 커밋 이력, 코드 내 참조 키 이름만 확인했다.

### 5-A. `.gitignore` 등록 여부 — **등록됨**

| 라인 | 내용 | 의미 |
|---|---|---|
| `.gitignore:123` | `.env` | 루트 `.env` 무시 |
| `.gitignore:124` | `*.env` | 모든 `.env` 접미 파일 무시 |
| `.gitignore:126` | `# .env.example은 팀 공유용 양식 파일로 추적 대상에 포함` | 주석 |
| `.gitignore:127` | `!.env.example` | 예외 등록 (추적) |

`.gitignore:86`의 `**/ios/Flutter/flutter_export_environment.sh`는 별개 항목이다.

### 5-B. git 커밋 이력 — **이력 없음**

```
$ git log --all --oneline -- .env
(출력 없음, exit 0)
```

전체 브랜치(`f/route`, `main`, `origin/*`)를 대상으로 검색했으며 `.env`가 커밋된 이력은 확인되지 않았다. 시크릿이 git 히스토리에 남아 있지 않다.

**부수 확인**: `flutter analyze` 결과 `pubspec.yaml:95`의 에셋 `.env`가 부재하다는 warning이 발생했다 — 현재 작업 트리에 `.env` 파일 자체가 없다. 이것이 §3-C의 테스트 빌드 실패 원인이다.

### 5-C. `lib/` 전체에서 `dotenv.env[...]`로 참조되는 키 — **2종 / 3개소**

| # | 키 이름 | 참조 위치 | 접근 형태 |
|---|---|---|---|
| 1 | `NAVER_MAP_CLIENT_ID` | `lib/main.dart:29` | `dotenv.env['NAVER_MAP_CLIENT_ID']!` (non-null 단언) |
| 2 | `FASTAPI_BASE_URL` | `lib/features/news/presentation/news_service.dart:13` | `dotenv.env['FASTAPI_BASE_URL'] ?? ''` |
| 2 | `FASTAPI_BASE_URL` | `lib/features/plogging/data/route_repository.dart:15` | `_normalizeBaseUrl(dotenv.env['FASTAPI_BASE_URL'])` |

### 5-D. `.env.example` 선언 키와의 대조

| `.env.example` 키 | 라인 | `lib/`에서 실제 참조 | 비고 |
|---|---|---|---|
| `NAVER_MAP_CLIENT_ID` | `:5` | 예 (`main.dart:29`) | — |
| `NAVER_MAP_CLIENT_SECRET` | `:6` | **아니오** | CLAUDE.md 6-i 위반 — 앱이 쓰지 않는 Secret이 Flutter 양식에 노출 |
| `FASTAPI_BASE_URL` | `:9` | 예 (2개소) | — |
| `GEMINI_API_KEY` | `:12` | **아니오** | CLAUDE.md 6-i 위반 — 서버 전용 키가 Flutter 양식에 노출 |

### 5-E. 주목 사항

1. **`detector.dart`만 `.env`를 쓰지 않는다.** 서버 주소를 참조하는 3개 지점 중 `news_service.dart`와 `route_repository.dart`는 `FASTAPI_BASE_URL`을 읽지만, `vision/data/detector.dart:62`는 `SERVER_URL = 'http://54.70.167.93:8000'`을 하드코딩한다. 서버 IP 변경 시 이 파일만 누락된다.
2. **`.env` 부재로 현재 앱과 테스트 모두 빌드되지 않는다.** `.gitignore` 정책 자체는 올바르나, 신규 클론 시 `.env` 생성이 필수라는 안내가 `README.md`에 있는지는 본 조사 범위 밖이다.
3. **`main.dart:29`의 `!` 단언**은 `.env`에 키가 없으면 앱 시작 시 즉시 크래시한다.

---

## 6. 보완 조사 종합

| 조사 항목 | 핵심 결과 |
|---|---|
| 1. 역방향 의존 | data→presentation **0건**. core→presentation 12건(10건은 라우터 필연, `screen_views.dart` 2건은 구조 결함). 추가로 data→domain 10건이 CLAUDE.md 2-2 위반 |
| 2. flutter analyze | 총 **61 issues** (error 0 / warning 3 / info 58). `avoid_print` 52건이 data 레이어 4개 파일에 집중. `unused_element` 0건 |
| 3. test/ | 유일한 `widget_test.dart`가 **Flutter 카운터 템플릿 원본**. `.env` 에셋 부재로 빌드 단계에서 중단되며, 해소하더라도 `ProviderScope` 누락·카운터 위젯 부재로 통과 불가. **유효 테스트 0개** |
| 4. CLAUDE.md | 파일이 커밋 `3aaa1e9`에서 **삭제되어 현존하지 않음**. 최종본 51개 조항 기준 준수 14 / 위반 26 / 판정 불가 11. 6절(백엔드 책임 분담) 11개 중 6개 위반 |
| 5. `.env` | `.gitignore:123-124` 등록 완료, 커밋 이력 **없음**(유출 없음). `lib/` 참조 키는 `NAVER_MAP_CLIENT_ID`·`FASTAPI_BASE_URL` 2종뿐이나 `.env.example`은 미사용 시크릿 2종을 추가 노출. 작업 트리에 `.env` 부재로 현재 빌드 불가 |

### 우선 조치 후보 (판단 근거만 제시, 본 단계에서 수정하지 않음)

1. `Repo_JDH/.env.example`에서 `NAVER_MAP_CLIENT_SECRET`·`GEMINI_API_KEY` 제거 — 앱이 참조하지 않는 서버 전용 키다 (§5-D).
2. `vision/data/detector.dart:62`의 하드코딩 IP를 `FASTAPI_BASE_URL` 참조로 전환 (§5-E-1).
3. `test/widget_test.dart` — 템플릿 그대로 두면 CI 도입 시 즉시 실패한다. 삭제하거나 실제 테스트로 교체 (§3).
4. CLAUDE.md 부재 상태 결정 — 현재 규칙 문서 없이 작업 중이다. 갱신 복원 또는 명시적 폐기 중 택일 (§4-0).
5. `avoid_print` 52건 — 전부 data 레이어 4개 파일이므로 국소 수정으로 해소 가능 (§2-B).
