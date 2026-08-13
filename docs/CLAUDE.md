# CLAUDE.md

본 문서는 코드 작성 규칙만 담는다. 아키텍처, 서버 API 계약, 진척 상태는
`docs/guideline_v9.md`를 참조한다. 두 문서가 충돌하면 `docs/guideline_v9.md`가 우선한다.

## 1. 아키텍처 규칙

- Feature-First 3-Layer를 따른다. `lib/features/{feature}/` 아래
  `presentation`, `domain`, `data`로 분리한다.
- 의존성은 presentation -> domain -> data 단방향이다.
  presentation이 data를 직접 import하지 않는다.
- data 계층은 domain의 모델·엔티티를 참조할 수 있다.
  domain의 Notifier·Provider는 참조하지 않는다. presentation은 참조하지 않는다.
- 예외: `core/router/app_router.dart`가 presentation을 import하는 것은
  go_router 라우트 테이블 구성상 필연이므로 허용한다.
  `core/`의 다른 파일이 presentation을 import하는 것은 위반이다.

## 2. 상태 관리

- Riverpod을 사용한다. provider, bloc 등 다른 상태관리 패키지를 추가하지 않는다.
- 복잡한 데이터 파이프라인과 화면 간 공유 상태에 `setState`를 사용하지 않는다.
  단순 로컬 UI 토글에는 사용해도 된다.
- `isLoading`, `hasError` 같은 boolean 플래그를 수동으로 관리하지 않는다.
  `AsyncValue.guard`로 처리하고 UI에서 `AsyncValue.when`으로 분기한다.
- 비동기 provider 선택 기준
  - 단순 조회(설정 1회 로드, 단일 문서 읽기): `FutureProvider` 또는 `StreamProvider`
  - 사용자 액션에 의한 상태 변경(분석 요청, 저장 실행): `AsyncNotifier`
  - 동기 상태(토글, 카운터): `Notifier`

## 3. 명명 규칙

- data 계층: `{대상}_repository.dart`
- domain 계층: `{기능}_notifier.dart`, 모델은 `{모델명}.dart`
- presentation 계층: `{기능}_screen.dart`, 보조 위젯은 스네이크 케이스
- `_service.dart` 명명을 사용하지 않는다. 외부 서비스 접근 클래스도
  `_repository.dart`로 통일한다.
- 클래스명은 파스칼 케이스를 사용한다.
- 데이터 접근 클래스를 presentation 폴더에 두지 않는다.

## 4. 코드 작성

- 색상 투명도는 `color.withValues(alpha: value)`를 사용한다.
  `withOpacity`는 사용하지 않는다. alpha 범위는 0.0~1.0이다.
- 화면 코드에서는 시맨틱 색상 이름만 사용한다. `green600` 같은 스케일 값을
  직접 참조하지 않는다.
- 좌표는 `NLatLng`를 사용한다. Google Maps의 `LatLng`와 혼동하지 않는다.
  `google_maps_flutter`를 추가하지 않는다.
- import는 `package:repo_jdh/...` 절대 경로를 사용한다. 상대 경로를 쓰지 않는다.
  Dart 패키지명은 `repo_jdh`이고 applicationId는 `com.ploggo.app`로 서로 다르다.
- 서버 통신 HTTP 클라이언트는 `dio`를 사용한다.
- 로그 출력은 `debugPrint`를 사용한다. `print`를 사용하지 않는다.
- 주석은 한국어로 작성한다.
- `.g.dart` 등 생성 파일을 직접 수정하지 않는다. 생성기를 재실행한다.

## 5. 보안

- 서버 주소, API 키를 코드에 하드코딩하지 않는다. `.env`에서 읽는다.
- Flutter `.env`에는 클라이언트에 노출되어도 되는 값만 넣는다.
  `flutter_dotenv`는 `.env`를 에셋으로 번들링하므로 APK에서 평문 추출이 가능하다.
  서버 전용 키(Secret, LLM API Key 등)를 넣지 않는다.

## 6. 작업 방식

- 코드 수정 시 전체 파일을 덮어쓰지 않는다. 변경이 필요한 부분만 수정한다.
- 코드와 설명에 이모지를 사용하지 않는다.
- 변경 후 `flutter analyze`를 실행하고 결과를 확인한다.
- 커밋 메시지는 `feat:`, `fix:`, `refactor:`, `chore:`, `docs:` 중 하나로 시작한다.
