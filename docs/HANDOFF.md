# 인수인계 — 2026-09-08

다른 컴퓨터에서 이어서 작업할 때 읽는 문서. 이 커밋 시점의 상태만 담는다.

## 1. 이번 작업에서 끝난 것

### 안드로이드 빌드 복구

`flutter run`이 실패하고 있었다. Flutter 3.47.2가 요구하는 AGP 최소 버전(8.11.1)보다
프로젝트 설정(8.9.1)이 낮아서다. `android/settings.gradle.kts`의 AGP를 8.11.1로 올려
해결했다. 실기기(SM G986N) 빌드·설치·실행까지 확인했다.

남은 경고 — 빌드는 되지만 Flutter가 "곧 지원 중단"을 예고한다. 다음 Flutter 업데이트에서
같은 방식으로 막힐 수 있다.

| 항목 | 현재 | 권고 |
|---|---|---|
| Gradle | 8.14.0 | 9.1.0 이상 |
| AGP | 8.11.1 | 9.0.1 이상 |
| Kotlin | 2.3.10 | 2.3.20 이상 |

AGP 9는 새 DSL만 읽어서 `android/app/build.gradle.kts` 수정이 함께 필요하다. 별도 작업으로
잡는 것을 권한다.

### 가입 시각 기준 채팅 차단

그룹에 새로 가입하거나 탈퇴 후 재가입하면, 가입 이전 글이 전부 보이지 않는다.
기준값은 `members/{uid}.joinedAt` (탈퇴 시 문서 삭제 → 재가입 시 새로 기록).

- `group_feed_screen.dart` `_applyPosts` — 채팅·시스템 알림·인증샷 구분 없이 전부 차단.
  (이전에는 인증샷을 예외로 두고 항상 보여줬다. 이번에 예외를 없앴다.)
- `group_photos_screen.dart` — 사진 앨범에도 같은 기준 적용.

주의할 점 두 가지.

1. **데이터는 삭제되지 않는다.** 클라이언트에서 가리는 방식이라 `posts` 문서는 그대로 있고
   기존 멤버에게는 계속 보인다. 서버에서 막으려면 Firestore 보안 규칙에 `joinedAt` 비교를
   넣어야 한다 — 미착수.
2. **읽기 실패 시 전체가 노출된다.** `myJoinedAt`이 null이면 필터가 꺼진다. 피드에는
   재시도(`_healJoinedAt`)가 있지만 앨범에는 없다. 노출 차단을 우선한다면 fallback을
   "전체 숨김"으로 뒤집어야 하는데, 그러면 오류 시 화면이 빈다. 결정 필요.

### 승인제 표기 (디자인 문서 7a/7b)

승인 후 가입 그룹(`isPublic:false`)임을 카드와 상세 헤더에 표기한다.

- `Group.cardMeta` getter 신설 — 홈·더보기·검색 3곳이 복붙하던 메타 조립을 모았다.
- `lib/core/widgets/group_card_meta.dart` 신설 — 잠금 글리프 + '승인' 접미를 그린다.
  접미는 줄어들지 않게 고정하고 본문만 말줄임한다(그룹명이 길면 표기가 잘려 사라지므로).
- 자유 가입 그룹에는 아무 표기도 넣지 않는다. 표기가 없는 것이 곧 자유 가입이라는 뜻.
- 상세 헤더 칩(`_accessChip`) 라운드를 999 → 6으로 수정.

작업 중 발견 — 홈·더보기 메타는 13px(`AppType.caption`), 검색만 12.5px이었다.
디자인 스펙(12.5)으로 셋 다 맞췄다.

이미 반영돼 있어 손대지 않은 확정안: 시스템 알약 색 `#5A5F5B`(`AppColors.gray700`),
멤버 탈퇴 시스템 알약(`group_service.dart` `leaveGroup`).

## 2. 결정된 것

**승인 대기 배너 색 (디자인 문서 4a/4b/4c)** — **4a 뉴트럴로 확정, 적용 완료.**

이전 판에서 '결정 필요'로 적어 둔 항목이지만, 코드를 대조해 보니 이미 4a가 들어가 있었다.
문서가 코드보다 뒤졌던 것이다. 앰버(`#F6ECDC` / `#8A5510`)는 `subPoint`·`warningBg`
토큰에만 남아 있고 이 배너에는 쓰이지 않는다.

| 위치 | 배경 | 전경 |
|---|---|---|
| 대기 배너 (`group_detail_screen.dart` `_waitingStack`) | `AppColors.surfaceSoft` `#F4F6F5` | `AppColors.gray700` `#5A5F5B` |
| 헤더 대기 칩 (`_accessChip`) | `#EDEFEE` 리터럴 | `#5A5F5B` |

칩 배경만 한 톤 어둡게 두었다. 버그가 아니다 — 칩이 얹히는 헤더 워시가
`#EFF1F0 → #F4F6F5` 그라데이션이라, `surfaceSoft`로 맞추면 워시 아래쪽에서 칩이
배경에 묻혀 사라진다. 전경색은 4a와 같다. 건드리지 말 것.

## 3. 디자인 스펙 대조 — 완료, 일부 보류

`GROUP_APPROVAL.md`(Claude Design)와 코드를 값 단위로 대조하고 어긋난 곳을 고쳤다.

**이미 맞아 손대지 않은 것** — 카드 메타(§1), 헤더 칩 2종(§1·§3.1),
햄버거 빨간 점(§5.1), 시스템 알약(§8).

**고친 것**

| 구분 | 내용 |
|---|---|
| 규칙 위반 | §7.2 위임 팝업 아이콘을 라임 원 + 왕관 → `#FDEBE7` 원 + `ti-door-exit`. 라임은 완료·획득 전용이라 파괴적 액션에 쓰지 않는다 |
| 규칙 위반 | 거절 버튼이 `#E4573D` 면 + 흰 글자로 뒤집혀 있던 것을 `#F4F6F5` 면 + `#E4573D` 글자로 (전용 화면·처리 시트 양쪽) |
| 버그 | 처리 시트 `_btn`이 `fg`를 무시하고 흰색을 고정 렌더 — 거절 버튼 글자가 면에 묻히던 것 |
| 누락 | 시트·팝업 본문 문구 4종 신설 (§2 요청 시트, §4.2 처리 시트, §6.1 승인, §6.2 거절) |
| 누락 | §4.1 배너 글리프 타일(40×40, 라임 16%), §3.2 대기 버튼 시계 글리프, §5.2 드로어 회색 면, §5.3 승인 버튼 체크 글리프·기록없음 박스, §2 고지 정보 글리프 |
| 값 | 라운드·높이·폰트·간격 40여 곳 (예: 확인 팝업 제목 18→21, 버튼 52→54·라운드 16→18) |
| 정리 | 요청 시각 상대 표기를 `JoinRequest.sinceText`/`screenMeta`/`sheetMeta`로 모델에 모았다. 전용 화면과 처리 시트가 같은 포맷을 쓴다 |

**보류 — 스펙과 다른 채로 남긴 것 3가지**

1. **§7.2 승계자 카드** (이름·아바타·「28일째 활동 · 새 그룹장」·왕관). 승계자를 미리
   조회해야 해서 `group_service`에 최고참 멤버 조회가 필요하다. 같은 이유로 팝업 제목의
   승계자 이름(스펙: 「준호 님에게 그룹을…」)도 넣지 못해 「그룹을 위임하고 나가시겠어요?」로 두었다.
2. **시트의 부착 형태.** 스펙은 좌우·아래 10px 띄운 라운드 30 플로팅 카드인데, 이 앱의
   시트 4개가 전부 하단 고정 + 상단 라운드 28로 통일돼 있다. 둘만 바꾸면 앱 안에서
   이질적이라 부착 형태는 두고 내부 값만 맞췄다. 바꾸려면 시트 전체를 한꺼번에 해야 한다.
3. **§5.3 멤버 수 행의 우측 「설정」.** 면·글리프·문구는 스펙대로 고쳤지만 「설정」은
   눌렀을 때 갈 곳이 정해져 있지 않아 넣지 않았다.

## 4. 다른 컴퓨터에서 시작할 때

**Claude Design 연동**

디자인 원본은 Claude Design 프로젝트 "플로고 디자인 기획"에 있다.

- projectId: `ad70a034-6e5e-4beb-9269-29472036f12d`
- type이 `PROJECT_TYPE_PROJECT`라 `DesignSync`의 `list_projects`에는 잡히지 않는다.
  빈 배열이 나와도 정상이며, projectId를 직접 넘기면 `list_files`/`get_file`이 동작한다.
- 인증은 컴퓨터별로 저장된다. 터미널에서 `claude` 실행 후 `/design-login`을 한 번 해야 한다.
  (PowerShell 프롬프트에 바로 치면 안 되고, CLI 안에서 입력한다.)

**확인된 제약** — `list_files`는 경로만 반환하고 파일별 수정 시각을 주지 않는다. 무엇이
바뀌었는지 자동 판별이 불가능하므로, 어느 화면인지 지정해서 요청해야 한다.
디자인 파일 스냅샷을 저장소에 두면 진짜 diff가 가능해지는데 아직 만들지 않았다.

## 5. 이 커밋에 함께 들어간 이전 작업

이번 세션 이전부터 미커밋 상태였던 변경을 한 커밋으로 묶었다. 내용은 확인하지 않았다.

`app_snackbar.dart`, `badge_service.dart`, `news_detail_screen.dart`,
`activity_service.dart`, `plogging_tracking_screen.dart`, `settlement_screen.dart`,
`point_history_screen.dart`, `group_create_screen.dart`, `group_info_screen.dart`,
`group_detail_screen.dart`, `group_service.dart`, `pubspec.yaml`,
`gradle-wrapper.properties`(8.12 → 8.14), 그리고 신규 `group_join_requests_screen.dart`.

## 6. 현재 검증 상태

2026-09-08 `flutter analyze` 재실행 — **error 0, warning 4, 전체 60 issues.**
(이전 판은 warning 2개라고 적었는데 `plogging_tracking_screen.dart`의 2개가 빠져 있었다.)

| 파일 | 내용 |
|---|---|
| `group_ranking_screen.dart:14` | `_charcoal` 미사용 필드 |
| `group_screen.dart:101` | `_openMyDetail` 미참조 |
| `plogging_tracking_screen.dart:287` | 지역변수 `tracking` 미사용 |
| `plogging_tracking_screen.dart:1344` | 선택 파라미터 `danger`에 값이 전달된 적 없음 |

넷 다 실행에 지장이 없는 미사용 선언이다.

`avoid_print` info가 `firestore_repository.dart`와 `storage_repository.dart`에 다수 남아
있다. CLAUDE.md의 `debugPrint` 규칙과 어긋나지만 실행에는 지장 없다.
