# CLAUDE.md

본 문서는 변하지 않는 코드 작성 규칙만 담는다.
기술 스택, 폴더 구조, 서버 API 계약, 진척 상태는 `docs/guideline_v9.md`를 참조한다.
두 문서가 충돌하면 `docs/guideline_v9.md`가 우선한다.

## 1. 계층 구조

- Feature-First 3-Layer를 따른다. `lib/features/{feature}/` 아래
  `presentation`, `domain`, `data`로 분리한다.
- 의존성은 presentation -> domain -> data 단방향이다.
  presentation은 data를 직접 import하지 않는다.
- data는 domain의 모델·엔티티를 참조할 수 있다.
  domain의 Notifier·Provider는 참조하지 않는다.
- data와 domain은 presentation을 참조하지 않는다.
- 데이터 접근 클래스를 presentation 폴더에 두지 않는다.

## 2. 상태 관리

- Riverpod을 사용한다.
- 복잡한 데이터 파이프라인과 화면 간 공유 상태에 `setState`를 사용하지 않는다.
  단순 로컬 UI 토글에는 사용해도 된다.
- `isLoading`, `hasError` 같은 boolean 플래그를 수동으로 관리하지 않는다.
  `AsyncValue.guard`로 처리하고 UI에서 `AsyncValue.when`으로 분기한다.
- 사용자 액션에 의한 상태 변경은 Notifier 계열을 사용한다.
  단순 조회는 `FutureProvider` 또는 `StreamProvider`를 사용한다.

## 3. 명명

- data: `{대상}_repository.dart`
- domain: `{기능}_notifier.dart`, 모델은 `{모델명}.dart`
- presentation: `{기능}_screen.dart`
- `_service.dart` 명명을 사용하지 않는다.
- 클래스명은 파스칼 케이스, 파일명은 스네이크 케이스를 사용한다.

## 4. 코드 작성

- 색상 투명도는 `color.withValues(alpha: value)`를 사용한다.
  `withOpacity`는 사용하지 않는다. alpha 범위는 0.0~1.0이다.
- import는 절대 경로를 사용한다. 상대 경로를 쓰지 않는다.
- 로그 출력은 `debugPrint`를 사용한다. `print`를 사용하지 않는다.
- 주석은 한국어로 작성한다.
- 생성 파일(`.g.dart` 등)을 직접 수정하지 않는다. 생성기를 재실행한다.

## 5. 보안

- 서버 주소와 API 키를 코드에 하드코딩하지 않는다. 환경 변수에서 읽는다.
- 앱의 환경 변수 파일은 빌드 산출물에 포함되어 평문 추출이 가능하다.
  클라이언트에 노출되어도 되는 값만 넣는다. 서버 전용 키를 넣지 않는다.

## 6. 작업 방식

- 코드 수정 시 전체 파일을 덮어쓰지 않는다. 변경이 필요한 부분만 수정한다.
- 코드와 설명에 이모지를 사용하지 않는다.
- 변경 후 `flutter analyze`를 실행하고 결과를 확인한다.
- 커밋 메시지는 `feat:`, `fix:`, `refactor:`, `chore:`, `docs:` 중 하나로 시작한다.
