# CLAUDE.md

이 문서는 본 저장소(Ploggo)에서 Claude Code가 코드를 작성·수정할 때 반드시 따라야 하는 영구 규칙을 정의한다. 본 문서의 규칙은 사용자의 별도 지시가 없는 한 모든 작업의 기본 기준이 된다.

상세한 프로젝트 비전·기능 명세·일정·기술 선정 근거는 본 저장소의 `docs/PLAN.md`를 참조한다.

---

## 1. 프로젝트 개요

본 프로젝트는 AI 플로깅 플랫폼 "Ploggo"의 Flutter 클라이언트 앱이다. Android 우선 크로스플랫폼 앱이며, Firebase + FastAPI 백엔드와 통신한다.

- **프레임워크**: Flutter 3.41.x + Dart 3.11.x
- **패키지명(applicationId)**: `com.ploggo.app`
- **최소 Android SDK**: 26 (Health Connect + flutter_naver_map 요구사항)
- **백엔드**: Firebase Auth/Firestore/Storage + FastAPI(AWS EC2)
- **AI**: YOLOv8n(ONNX), Gemini 2.5 Flash (모두 FastAPI 프록시 경유)
- **지도**: Naver Maps SDK + Naver Directions 5 + Naver Geocoding (Directions·Geocoding은 FastAPI 프록시 경유)

---

## 2. 아키텍처 규칙 (Feature-First 3-Layer)

### 2-1. 폴더 구조

본 프로젝트는 Feature-First 3-Layer 아키텍처를 엄격히 따른다.

```
lib/
├── main.dart                          # 앱 진입점
├── core/
│   ├── constants/                     # 앱 전역 상수
│   ├── providers/                     # 전역 Provider (Firebase, Dio 인스턴스 등)
│   ├── router/                        # go_router 라우팅 정의
│   ├── theme/                         # 색상·테마
│   ├── utils/                         # 순수 헬퍼 함수
│   └── widgets/                       # 2개 이상 feature에서 공통 사용되는 위젯
└── features/
    └── {feature_name}/
        ├── data/                      # 외부 데이터 접근 (Firebase, FastAPI, 디바이스 API)
        ├── domain/                    # 비즈니스 로직 (Notifier, 도메인 모델)
        └── presentation/              # 화면 위젯
```

### 2-2. 의존성 방향

레이어 간 의존성은 **단방향**만 허용한다. 역방향 import는 금지한다.

```
presentation → domain → data
```

- presentation은 domain Provider만 watch한다. data를 직접 import하지 않는다.
- domain은 data의 Repository만 호출한다. presentation을 알지 못한다.
- data는 외부 SDK·API만 호출한다. domain·presentation을 알지 못한다.

### 2-3. feature 목록

현재 정의된 feature: `auth`, `home`, `plogging`, `vision`, `reward`, `community`, `mypage`. 각 feature의 상세 역할 및 화면 명세는 `docs/PLAN.md`를 참조한다.

### 2-4. 점진적 디렉토리 확장 원칙

다음 하위 디렉토리는 **필요 시점에만** 추가한다. 처음부터 만들지 않는다.

- `lib/features/{f}/presentation/widgets/`: 한 화면이 위젯으로 쪼개지기 시작할 때 (200줄 초과 기준)
- `lib/features/{f}/domain/models/`: 도메인 모델이 2개 이상 생길 때
- `lib/features/{f}/data/dto/`: FastAPI/Firestore 응답 매핑 로직이 복잡해질 때

---

## 3. 명명 규칙

### 3-1. 파일명

| 레이어 | 파일명 패턴 | 예시 |
|---|---|---|
| data | `{대상}_repository.dart` | `auth_repository.dart`, `location_repository.dart` |
| domain | `{기능}_notifier.dart` | `auth_notifier.dart`, `plogging_notifier.dart` |
| presentation | `{기능}_screen.dart` | `login_screen.dart`, `home_screen.dart` |
| presentation 보조 위젯 | `{이름}.dart` (스네이크 케이스) | `profile_card.dart` |

- `_service.dart` 명명은 사용하지 않는다. 외부 서비스 접근 클래스도 `_repository.dart`로 통일한다.
- 코드 생성기(`riverpod_generator`)가 만든 파일은 `.g.dart` 접미사를 가진다. 이 파일은 수정하지 않는다.

### 3-2. 클래스명

- 파스칼 케이스 사용. `AuthRepository`, `PloggingNotifier`, `LoginScreen`.

---

## 4. 상태 관리 규칙 (Riverpod 2.x)

### 4-1. 사용 버전

본 프로젝트는 **Riverpod 2.x**를 사용한다. 3.x로의 마이그레이션은 별도 의사결정 전까지 보류한다. Riverpod 3.x 전용 API(예: `Ref.mounted`, `AsyncLoading(progress:)`, `AsyncValue.requireValue` 등)를 임의로 사용하지 않는다.

### 4-2. Provider 선택 기준

| 상황 | 사용할 Provider |
|---|---|
| 단순 읽기 전용 데이터 (1회성 설정 로드, 단일 Firestore 문서 읽기) | `FutureProvider` 또는 `StreamProvider` |
| 사용자 액션으로 상태 변경 (저장, AI 분석 요청, 로그인 등) | `AsyncNotifier` |
| 동기 상태 (간단한 토글, 카운터) | `Notifier` |

### 4-3. 금지 사항

- 복잡한 데이터 파이프라인 또는 화면 간 상태 공유에 `setState`를 사용하지 않는다.
- `isLoading`, `hasError` 같은 boolean 플래그를 수동 관리하지 않는다. 반드시 `AsyncValue`를 사용한다.
- presentation 레이어에서 `data` 레이어의 Repository를 직접 import하지 않는다. 항상 domain Provider를 거친다.

### 4-4. 권장 패턴

- 비동기 처리는 `AsyncValue.guard`로 감싼다.
- UI에서는 `AsyncValue.when(data:, loading:, error:)` 패턴으로 분기한다.
- 위젯은 `ConsumerWidget` 또는 `ConsumerStatefulWidget`을 상속한다.
- 사용처에 따라 `ref.watch()`(리빌드 필요)와 `ref.read()`(콜백 내 1회 호출)를 구분한다.
- 순차적 데이터 파이프라인은 Provider 체인으로 구성한다. 예: `cameraProvider` → `uploadProvider(ref.watch(cameraProvider))` → `visionProvider`.

---

## 5. Flutter 코딩 규칙

### 5-1. 색상 투명도

- `withOpacity()`는 deprecated이므로 사용하지 않는다.
- 반드시 `color.withValues(alpha: value)` 형식을 사용한다. `alpha` 값 범위는 `0.0 ~ 1.0`이며, named parameter로 전달한다.

```dart
// 올바른 예
Colors.black.withValues(alpha: 0.5)

// 금지
Colors.black.withOpacity(0.5)
```

### 5-2. 코드 수정 방식

- 코드를 수정할 때 **전체 파일을 덮어쓰지 않는다.** 변경이 필요한 부분만 발췌하여 수정한다.
- 새 파일을 생성하는 경우가 아니라면, 기존 파일의 다른 부분은 그대로 보존한다.

### 5-3. 주석 언어

- 코드 내 주석은 **한국어**로 작성한다.
- 단, 외부에 공개되는 라이브러리성 코드에 해당하는 부분(없을 가능성이 높음)에 한해 영문 주석 허용.

### 5-4. Naver Maps 좌표

- Naver Maps SDK 좌표는 `NLatLng(lat, lng)`을 사용한다.
- Google Maps의 `LatLng`와 혼동하지 않는다. Google Maps 관련 import는 본 프로젝트에서 사용하지 않는다.

### 5-5. import 정리

- 동일 패키지 내부 import는 상대 경로(`../`)가 아닌 패키지 경로(`package:repo_jdh/...`)를 사용한다.
- import 순서: dart → flutter → 외부 패키지 → 본 프로젝트 패키지.

---

## 6. 백엔드 책임 분담

각 외부 서비스의 역할이 명확히 분리되어 있다. Claude Code가 데이터 접근 코드를 작성할 때 책임 영역을 혼동하지 않아야 한다.

| 영역 | Flutter (본 프로젝트) | FastAPI 프록시 | Firebase |
|---|---|---|---|
| 지도 렌더링 | flutter_naver_map | - | - |
| GPS 추적 | geolocator + Foreground Service | - | - |
| Waypoint 알고리즘 (K=3) | route_notifier (Flutter) | - | - |
| Naver Directions 5 호출 | dio로 FastAPI 호출 | Naver API 호출 | - |
| Naver Geocoding 호출 | dio로 FastAPI 호출 | Naver API 호출 | - |
| YOLOv8n 추론 | dio로 FastAPI 호출 | YOLO 추론 | - |
| Gemini API 호출 | dio로 FastAPI 호출 | Gemini API 호출 | - |
| 인증 | firebase_auth SDK 직접 사용 | - | Auth |
| DB | cloud_firestore SDK 직접 사용 | - | Firestore |
| 이미지 저장 | firebase_storage SDK 직접 사용 | - | Storage |

**규칙:**
- Naver Client Secret, Gemini API Key는 절대 Flutter 코드 또는 `.env`에 포함하지 않는다. FastAPI 프록시 측 환경변수로만 관리한다.
- Flutter `.env`에는 `NAVER_MAPS_CLIENT_ID`(공개 가능)와 `FASTAPI_BASE_URL`만 포함한다.
- Firebase 접근은 Flutter SDK가 인증 토큰을 자동 처리하므로 별도 토큰 핸들링 코드를 작성하지 않는다.

---

## 7. 패키지 사용 규칙

채택된 패키지 목록과 버전은 `pubspec.yaml`을 참조한다. 본 절에서는 금지 사항과 코드 생성 규칙만 명시한다.

### 7-1. 금지 패키지

- `google_maps_flutter`: Naver Maps로 전면 전환되었으므로 사용 금지. pubspec.yaml에 잔존 시 제거 대상.
- `provider`, `bloc`: 상태 관리는 Riverpod으로 통일.

### 7-2. 코드 생성

- `riverpod_generator` + `build_runner`를 사용하는 경우, 코드 생성 명령은 다음과 같다.
```bash
  flutter pub run build_runner build --delete-conflicting-outputs
```
- 생성된 `.g.dart` 파일은 직접 수정하지 않는다.

---

## 8. Git 커밋 규칙

커밋 메시지는 다음 prefix를 사용한다: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`.

예시: `feat: plogging - Naver Directions 5 프록시 호출 구현`

---

## 9. Claude Code 작업 시 추가 지침

### 9-1. 작업 전 확인 사항

- 코드 수정·생성 전, 해당 feature 폴더의 기존 구조와 명명을 먼저 확인한다.
- Riverpod 관련 코드 작성 시, Context7 MCP를 통해 Riverpod 2.x 최신 문서를 참조한다.
- 외부 패키지의 API 사용 시, Context7로 해당 패키지의 현재 버전 문서를 확인한다.

### 9-2. 작업 후 확인 사항

- 코드 변경 후 `flutter analyze`로 오류·경고 확인.
- 새 파일 생성 시 본 문서의 명명 규칙 준수.
- presentation에서 data를 직접 import하지 않았는지 의존성 방향 점검.

---

## 10. 본 문서가 다루지 않는 영역

다음 항목은 본 문서의 범위 밖이다. 본 저장소의 `docs/PLAN.md`를 참조한다.

- 프로젝트 비전, 기대효과, 일정
- 기능 명세 상세, 화면별 요구사항
- Waypoint 알고리즘 검증 결과 및 4번째 알고리즘 후보
- FastAPI 서버 코드 (별도 백엔드 저장소 참조)

---

작성: 2026-05-24
버전: 1.1 (CLAUDE.md 슬림화 적용)