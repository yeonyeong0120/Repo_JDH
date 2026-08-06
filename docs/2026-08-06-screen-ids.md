# 화면 ID 정본

작성일: 2026-08-06
대상 브랜치: f/route

---

## 1. 문서 목적

본 문서는 Ploggo 앱의 화면 ID 정본이다. 제작설계서(SB)에 기재하는 화면 ID와 저장소의 실제 코드를 연결하는 기준표 역할을 한다.

제작설계서 작성을 위해 화면 ID 체계를 새로 확정했다. 그러나 확정 이전에 코드 주석에 적혀 있던 옛 체계의 ID가 21종(35개 표기) 남아 있고, 그 ID를 정의한 문서는 저장소 안에 없었다. 옛 ID의 근거는 저장소 외부의 기획서에만 존재한다. 본 문서가 그 정의를 저장소 안으로 들여온다.

본 문서를 작성하면서 코드는 수정하지 않았다. 조사와 문서 작성만 수행했다. 코드 주석에 남아 있는 옛 ID는 본 문서가 확정된 뒤 별도 작업으로 정리한다. 정리 방식은 9절에 기록한다.

---

## 1-1. 개정 기록

| 일자 | 내용 |
|---|---|
| 2026-08-06 | 최초 작성 (83건) |
| 2026-08-06 | ACT 재구성(기록·뱃지·그래프를 단일 화면의 탭으로 통합), MNU 재번호(지역 변경을 프로필 하위로 이동), ID 2건 신규 부여, 1건 삭제 |

번호 회수 금지 규칙(2-4절)은 본 문서가 확정된 이후부터 적용한다. 위 개정은 확정 전에 이루어진 것이므로 결번을 남기지 않고 번호를 당겼다.

---

## 2. ID 체계

### 2-1. 형식

```
{접두사 3자리}-{주화면 2자리}-{부수 2자리}{유형 2자리}
```

예시:

| ID | 의미 |
|---|---|
| `SHP-01-00MS` | 에코포인트 상점 (주화면) |
| `SHP-01-01DG` | 그 화면에서 뜨는 구매 컨펌 모달 |

### 2-2. 접두사 10종

| 접두사 | 영역 |
|---|---|
| AUT | 진입·계정 |
| HOM | 홈 |
| NWS | 뉴스 |
| PLG | 플로깅 |
| GRP | 그룹 |
| ACT | 내 활동 |
| MNU | 메뉴·프로필 |
| SHP | 에코포인트·상점 |
| PRM | 권한 |
| ERR | 전역 오류 |

### 2-3. 유형 코드 9종

| 코드 | 명칭 | 정의 |
|---|---|---|
| MS | Main Screen | 라우트 또는 Navigator.push로 진입하는 전체 화면 |
| FP | Full Popup | 화면 전체를 덮는 오버레이 |
| DG | Dialog | showDialog 부분 팝업 |
| BS | Bottom Sheet | showModalBottomSheet |
| TB | Tab | 탭 전환으로만 바뀌는 상태 |
| CD | Card | 화면 위 일시 노출 후 자동 소멸 |
| TO | Toast | 토스트·스낵바 |
| ES | Empty State | 데이터 0건 상태 |
| TT | Tooltip | 툴팁·말풍선 |

### 2-4. 번호 규칙

- 부수 번호 `00`은 주화면 자신이다.
- 한 번 부여한 번호는 회수하지 않는다. 삭제 시 결번으로 남긴다.
- 뒤 번호일수록 슬라이드 수록 여부가 미확정인 항목이다.

---

## 3. 프로그램 ID 표기 규칙

`lib/` 와 `features/` 를 생략한 3단 경로로 쓴다.

```
plogging/presentation/plogging_tracking_screen.dart
core/router/app_router.dart
```

- 라인 번호는 넣지 않는다.
- 클래스명·함수명은 별도 열에 넣는다.
- 같은 프로그램 ID가 여러 ID에 반복되는 것은 정상이다(1:N 허용). 한 파일에 주화면과 그 화면의 다이얼로그가 함께 들어 있는 경우가 대부분이다.

---

## 4. 전체 매핑표

구현 상태는 다음 5단계로 판정했다.

| 상태 | 판정 기준 |
|---|---|
| 완성 | UI가 그려지고 실제 데이터(provider 또는 service)를 사용한다 |
| 부분 | UI는 있으나 하드코딩·더미 데이터만 쓰거나 일부 동작이 TODO다 |
| 스텁 | 빈 Scaffold, Placeholder, TODO 주석만 있다 |
| 미구현 | 대응하는 코드가 없다 |
| 확인필요 | 코드에 있는 것 같으나 특정하지 못했다 |

### 4-1. AUT 진입·계정

| 신규 ID | 화면명 | 프로그램 ID | 클래스/함수명 | 구현 상태 | 구 ID(설계서) | 구 ID(코드) | 비고 |
|---|---|---|---|---|---|---|---|
| AUT-01-00MS | 스플래시 | core/router/app_router.dart | `_SplashScreen` | 부분 | AUTH-01 | - | app_router.dart 안의 private 클래스. `CircularProgressIndicator` 하나뿐이고 로고·브랜딩이 없다. 인증 확인 중(`AuthStatus.unknown`) 체류 화면으로는 동작한다 |
| AUT-02-00MS | 로그인 | auth/presentation/login_screen.dart | `LoginScreen` | 완성 | AUTH-02 | - | 이메일·비밀번호, Google 로그인, 비밀번호 재설정 메일 발송 모두 `AuthRepository` 실호출 |
| AUT-02-01TO | 인증 실패 안내 | auth/presentation/login_screen.dart | `_handleLogin` / `_handleGoogleSignIn` 내 `ScaffoldMessenger.showSnackBar` | 완성 | ERR-04 | - | 문구는 auth/data/auth_repository.dart `_getKoreanErrorMessage`가 Firebase 오류 코드 13종을 한국어로 변환한다. 공용 `AppSnackBar`가 아니라 원시 `SnackBar`를 쓴다 |
| AUT-03-00MS | 회원가입 | auth/presentation/signup_screen.dart | `SignupScreen` | 완성 | AUTH-03 | AUTH-03 | 가입 후 선택 정보를 `UserService.updateProfileFields`로 저장 |
| AUT-03-01BS | 키·몸무게 입력 휠 | auth/presentation/signup_screen.dart | `_showNumberPicker` | 부분 | - | - | 수록 미확정. **휠(`CupertinoPicker`)은 나이에만 적용된다.** 키·몸무게는 `TextFormField` 직접 입력이므로 이 ID의 이름과 실제 구현이 어긋난다 |
| AUT-04-00MS | 닉네임 설정 | auth/presentation/nickname_setup_screen.dart | `NicknameSetupScreen` | 완성 | - | - | 코드에만 존재. `UserService.isNicknameTaken` 중복 확인 + `createProfile` 저장. 라우터가 닉네임 미설정 시 자동 진입시킨다 |
| AUT-05-00MS | 지역 설정 | - | - | 미구현 | AUTH-04 | - | 별도 화면 없음. 회원가입 폼 안의 지역 `TextFormField`(자유 입력)로 대체되어 있다 |

### 4-2. HOM 홈

| 신규 ID | 화면명 | 프로그램 ID | 클래스/함수명 | 구현 상태 | 구 ID(설계서) | 구 ID(코드) | 비고 |
|---|---|---|---|---|---|---|---|
| HOM-01-00MS | 홈 메인 | home/presentation/home_screen.dart | `HomeScreen` / `_HomeBody` | 완성 | HOME-01 | - | HOME-03(지금 우리 동네는)은 이 화면의 `_NeighborBlock` 컴포넌트로 흡수. 데이터는 core/view_models/screen_views.dart `homeViewProvider`가 6개 서비스를 병렬 호출 |
| HOM-01-01CD | 그룹 공유 완료 팝업 | core/providers/shared_group_provider.dart | `sharedGroupProvider` (신호만) | 미구현 | AUTO-02 | AUTO-02 | **신호 전달자만 있고 표시 코드가 없다.** 정산 화면이 `set(myGroupName)`으로 값을 쓰지만, 홈을 포함해 이 provider를 읽는 코드가 저장소 전체에 없다 |
| HOM-01-02TT | 에코 계산식 안내 | home/presentation/home_screen.dart | `_showEcoMathInfo` | 부분 | - | - | 수록 미확정. 현재 `AlertDialog`이므로 유형(TT)과 구현(DG)이 다르다. 계수는 home/domain/eco_math.dart `EcoMath` 한 곳에서 관리 |
| HOM-02-00MS | 환경 영향력 상세 | mypage/presentation/my_impact_screen.dart | `MyImpactScreen` | 완성 | HOME-02 | HOME-02 | `ActivityService.getRecentCompleted(limit: 500)` 합산. **다만 저장소 어디에서도 이 화면으로 이동하지 않는다**(호출 지점 0건). 홈의 '내가 만든 변화' 섹션 `onMore`가 빈 콜백 + TODO |

### 4-3. NWS 뉴스

| 신규 ID | 화면명 | 프로그램 ID | 클래스/함수명 | 구현 상태 | 구 ID(설계서) | 구 ID(코드) | 비고 |
|---|---|---|---|---|---|---|---|
| NWS-01-00MS | 뉴스 목록 | news/presentation/news_feed_screen.dart | `NewsFeedScreen` | 완성 | NEWS-01 | - | `NewsService.fetchNews()`(FastAPI `/news`) 실호출. 로딩·에러·빈목록·데이터 4상태 처리. **진입 경로가 없다.** 홈의 '알아두면 좋은 소식' `onMore`가 빈 콜백 + TODO |
| NWS-02-00MS | 뉴스 상세 | news/presentation/news_detail_screen.dart | `NewsDetailScreen` | 완성 | NEWS-02 | - | 원문 링크 열기(`url_launcher`), 공유(`share_plus`), 관련 뉴스 3건. 진입은 뉴스 목록에서만 가능하다. 홈의 `_NewsCard`는 `onTap: () {}` + TODO |

### 4-4. PLG 플로깅

| 신규 ID | 화면명 | 프로그램 ID | 클래스/함수명 | 구현 상태 | 구 ID(설계서) | 구 ID(코드) | 비고 |
|---|---|---|---|---|---|---|---|
| PLG-01-00MS | 도착지 설정 | plogging/presentation/route_setup_screen.dart | `RouteSetupScreen` | 완성 | PLOG-02 | - | 지도 탭 → 도착지 지정 → `routeNotifierProvider.recommend` 자동 호출. 하단 패널이 `AsyncValue.when`으로 분기 |
| PLG-01-01TO | 날씨 안내 | - | - | 미구현 | PLOG-01 | - | 8절 참조 |
| PLG-01-02DG | 트래킹 중단 복구 모달 | plogging/presentation/route_setup_screen.dart | `_checkInterrupted` | 완성 | PLOG-12 | PLOG-10 | `TrackingNotifier.loadSaved()`로 강제 종료 세션 복원. '이어서 하기' 선택 시 `resume` 후 트래킹으로 이동 |
| PLG-01-03FP | 카운트다운 | - | - | 미구현 | PLOG-04 | - | 8절 참조 |
| PLG-02-00MS | 트래킹 진행 | plogging/presentation/plogging_tracking_screen.dart | `PloggingTrackingScreen` | 완성 | PLOG-05 | - | `trackingProvider` 1초 틱, `LocationRepository().watchTrackPoints()` 구독, 추천 경로 `NPathOverlay` 렌더 |
| PLG-02-01DG | 플로깅 활동 규칙 모달 | plogging/presentation/plogging_tracking_screen.dart | `_maybeShowGuide` | 완성 | PLOG-03 | PLOG-04 | `UserService.hasSeenPloggingGuide()`로 첫 활동 1회만 노출, `markPloggingGuideSeen()`으로 기록 |
| PLG-02-02DG | 활동 취소 컨펌 모달 | plogging/presentation/plogging_tracking_screen.dart | `_confirmCancel` | 완성 | PLOG-06 | PLOG-06 | `AppDialog.show(primaryIsCancel: true)` — '계속하기'를 주 버튼으로 강조 |
| PLG-02-03DG | 종료 컨펌 모달 | plogging/presentation/plogging_tracking_screen.dart | `_endPlogging` | 완성 | PLOG-07 | PLOG-07 | 확인 시 `ActivityService.saveCompleted` 후 정산 화면으로 push |
| PLG-02-04CD | 경로 이탈 재추천 카드 | - | - | 미구현 | AUTO-01 | - | 8절 참조 |
| PLG-02-05TO | GPS 미수신 안내 | - | - | 미구현 | ERR-02 | - | 8절 참조 |
| PLG-02-06DG | 플로깅 안내 도움말 | plogging/presentation/plogging_tracking_screen.dart | `_showGuide` | 완성 | - | - | 트래킹 화면 우상단 물음표 버튼으로 열리는 `AppDialog.showInfo`. 첫 활동 1회만 노출되는 PLG-02-01DG(활동 규칙 모달)와 다른 팝업이며, 언제든 다시 열 수 있다. 설계서에 정의되어 있지 않은 화면이다 |
| PLG-03-00MS | 쓰레기 등록 (카메라) | vision/presentation/camera_detection_screen.dart | `CameraDetectionScreen` | 완성 | PLOG-08 | - | vision feature이나 접두사는 사용자 흐름 기준이라 PLG. 700ms 간격 스트림 추론(`GarbageDetector.detect`) + `DetectionPainter` 실시간 박스 |
| PLG-03-01FP | AI 분석 중 | vision/presentation/camera_detection_screen.dart | (실시간 오버레이로 대체) | 미구현 | PLOG-10 | - | 8절 참조. 별도 '분석 중' 화면 없이 실시간 오버레이로 대체되어 있다 |
| PLG-03-02DG | AI 분석 실패 | vision/presentation/camera_detection_screen.dart | `_onImage` catch / `_registerAndClose` | 부분 | ERR-03 | - | 다이얼로그 없음. 추론 실패는 `debugPrint('Detect error: $e')`로 로그만 남기고 사용자에게 노출되지 않는다. 인식 0건일 때만 스낵바 '인식된 쓰레기가 없습니다' |
| PLG-03-03FP | 사진 미리보기 / 종류 확인 | - | - | 미구현 | PLOG-09 | - | 8절 참조 |
| PLG-04-00MS | 정산 화면 | plogging/presentation/settlement_screen.dart | `SettlementScreen` | 완성 | PLOG-11 | - | `PopScope(canPop: false)`로 뒤로가기 차단. 활동 저장 → 뱃지 판정 → 그룹 공유 순서 |
| PLG-04-01DG | 뱃지 획득 알림 모달 | mypage/presentation/badge_dialog.dart | `showBadgeEarned` | 완성 | ACT-08 | ACT-09 | 코드는 mypage에 있으나 뜨는 위치 기준으로 PLG에 귀속. 호출 지점은 settlement_screen.dart `_showBadgesIfAny` (`BadgeService.checkAndSave()` 결과가 있을 때만) |

### 4-5. GRP 그룹

| 신규 ID | 화면명 | 프로그램 ID | 클래스/함수명 | 구현 상태 | 구 ID(설계서) | 구 ID(코드) | 비고 |
|---|---|---|---|---|---|---|---|
| GRP-01-00MS | 그룹 메인 | community/presentation/group_screen.dart | `GroupScreen` | 완성 | GRP-01 | - | `GroupService.myGroup()` + `otherGroups(limit: 5)`. 오늘 활동 많은 순 정렬 |
| GRP-01-01ES | 그룹 미가입 빈 상태 | community/presentation/group_screen.dart | `_NoGroupCard` | 완성 | EMPTY-02 | - | '내 그룹' 섹션에서 `_myGroup == null`일 때 표시. 검색 화면으로 유도 |
| GRP-02-00MS | 그룹 검색 | community/presentation/group_search_screen.dart | `GroupSearchScreen` | 부분 | GRP-02 | GRP-02 | 이름 검색은 동작(`GroupService.search`). 지역 필터(`_region`)·정렬(`_sort`)은 UI만 있고 쿼리에 반영되지 않는다(TODO) |
| GRP-03-00MS | 그룹 만들기 | community/presentation/group_create_screen.dart | `GroupCreateScreen` | 부분 | GRP-03 | GRP-03 | 생성은 동작(`GroupService.createGroup`). 대표 사진 업로드 미연결(TODO), 동네가 `'00구 00동'` 하드코딩 |
| GRP-03-01DG | 그룹 가입 차단 모달 | community/presentation/group_create_screen.dart<br>community/presentation/group_detail_screen.dart | `_showBlocked`<br>`_showAlreadyJoined` | 완성 | GRP-04 | GRP-04 | 그룹 상세에서도 호출되나 부모는 만들기로 통일. 만들기 쪽은 진입 즉시 차단 후 pop, 상세 쪽은 안내만 |
| GRP-04-00MS | 그룹 상세 | community/presentation/group_detail_screen.dart | `GroupDetailScreen` | 완성 | GRP-05 | - | GRP-05를 상세·피드로 분리. 가입 확인 → `GroupService.joinGroup` → 피드로 이동 |
| GRP-04-01DG | 그룹 가입 확인 | community/presentation/group_detail_screen.dart | `_join` 내부 `AppDialog.show` | 완성 | - | - | 그룹 상세의 '가입' 버튼을 누르면 뜨는 확인 팝업. GRP-03-01DG(가입 차단 모달)보다 먼저 노출되며, 이미 다른 그룹에 소속된 경우에만 차단 모달로 이어진다. 설계서에 정의되어 있지 않은 화면이다 |
| GRP-05-00MS | 그룹 피드 | community/presentation/group_feed_screen.dart | `GroupFeedScreen` | 부분 | GRP-05 | GRP-05 | 위와 동일. `groupId`가 있으면 `GroupService.watchPosts` 스트림으로 교체되지만, 없으면 코드에 박힌 더미 3건이 그대로 보인다. 게시물 사진은 TODO |
| GRP-05-01BS | 그룹 정보 시트 | community/presentation/group_feed_screen.dart | `_showGroupInfo` | 완성 | - | - | 수록 미확정. `GroupService.getGroup`으로 소개·동네 조회. 대표 이미지는 TODO |
| GRP-05-02DG | 그룹 탈퇴 확인 | community/presentation/group_feed_screen.dart | `_confirmLeave` | 완성 | - | - | 수록 미확정. 탈퇴는 이 화면에서만 가능 |
| GRP-05-03DG | 신고 다이얼로그 | community/presentation/group_feed_screen.dart | `_showReport` | 부분 | - | - | 수록 미확정. 사유 3종 선택 + 기타 입력 UI는 완성이나, 제출 시 `AppSnackBar.show(context, '신고가 접수됐어요')`만 뜨고 저장되지 않는다(TODO: 실제 신고 접수 처리) |

### 4-6. ACT 내 활동

| 신규 ID | 화면명 | 프로그램 ID | 클래스/함수명 | 구현 상태 | 구 ID(설계서) | 구 ID(코드) | 비고 |
|---|---|---|---|---|---|---|---|
| ACT-01-00MS | 내 활동 - 기록 탭 | mypage/presentation/my_activity_screen.dart | `MyActivityScreen` / `_RecordsTab` | 완성 | ACT-01 | - | `ActivityService.getRecentCompleted(limit: 3)` + `BadgeService.progressOf`로 퀘스트 3건. 기록·뱃지·그래프는 `MyActivityScreen` 하나의 `PageView` 페이지이므로, 기록 탭만 MS로 두고 나머지는 이 화면의 TB 부수로 배정했다 |
| ACT-01-01TB | 내 활동 - 뱃지 탭 | mypage/presentation/my_activity_screen.dart | `_BadgesTab` | 완성 | ACT-02 | - | `BadgeService.loadEarned()`로 Firestore 획득 현황 반영. 등급 4단계로 나눠 표시. 설계서 EMPTY-03(뱃지 미획득)은 별도 빈 상태가 아니라 이 화면의 기본 상태다. 미획득 뱃지는 자물쇠 타일로 항상 표시되므로 0건 상태가 발생하지 않는다 |
| ACT-01-02TB | 내 활동 - 그래프 (주간) | mypage/presentation/my_activity_screen.dart | `_GraphTab(period: 0)` | 완성 | ACT-03 | - | `ActivityService.getRecentCompleted(limit: 200)` 집계 |
| ACT-01-03TB | 내 활동 - 그래프 (월간) | mypage/presentation/my_activity_screen.dart | `_GraphTab(period: 1)` | 완성 | ACT-03 | - | 같은 클래스에 `period`만 다르다 |
| ACT-01-04TB | 내 활동 - 그래프 (누적) | mypage/presentation/my_activity_screen.dart | `_GraphTab(period: 2)` | 완성 | ACT-03 | - | 상동 |
| ACT-01-05ES | 활동 기록 없음 | mypage/presentation/my_activity_screen.dart | `_EmptyRecords` | 완성 | EMPTY-01 | - | 로딩 완료 후 0건일 때만. 로딩 중(null)·에러와 명확히 구분되어 있다 |
| ACT-01-06DG | 뱃지 상세 모달 | mypage/presentation/badge_dialog.dart | `showBadgeDetail` | 완성 | ACT-06 | ACT-08 | 미획득도 열람 가능(자물쇠 + '???'). 획득조건은 항상, 달성일자는 획득 시에만 |
| ACT-01-07TT | 그래프 기준 안내 툴팁 | - | - | 미구현 | ACT-03 | - | 수록 미확정. `Tooltip` 위젯 및 기준 안내 문구 0건 |
| ACT-02-00MS | 전체 활동 기록 | mypage/presentation/activity_list_screen.dart | `ActivityListScreen` | 부분 | ACT-04 | ACT-04 | 목록이 `static const List<_Act> _acts` 더미 4건으로 고정되어 있다(TODO: 실제 활동 데이터로 교체) |
| ACT-02-01DG | 기간 선택 | mypage/presentation/activity_list_screen.dart | `_pickDate` | 완성 | - | - | 수록 미확정. 시작일·종료일 + 달력/휠 전환. 선택 결과는 위 더미 목록에 적용된다 |
| ACT-03-00MS | 개별 활동 상세 | mypage/presentation/activity_detail_screen.dart | `ActivityDetailScreen` | 부분 | ACT-05 | ACT-05 | 값은 호출 측이 넘긴다. 내 활동 탭에서는 실데이터, 전체 활동 기록에서는 더미가 들어온다. 사진은 TODO |
| ACT-03-01BS | 활동 메뉴 시트 | mypage/presentation/activity_detail_screen.dart | `_showMenu` | 부분 | - | - | 수록 미확정. '그룹에 공유'·'활동 삭제' 둘 다 스낵바만 뜨고 실제 처리가 없다(TODO 2건) |
| ACT-04-00MS | 전체 퀘스트 목록 | mypage/presentation/quest_list_screen.dart | `QuestListScreen` | 완성 | - | ACT-09 | 코드에만 존재. `BadgeService.loadStats()` 실통계로 20개 진행률 계산. 코드 주석의 ACT-09는 뱃지 획득 모달과 충돌(6절 참조) |
| ACT-05-00MS | 마스코트 꾸미기 | - | - | 미구현 | ACT-07 | - | badge.dart의 `reward`/`slot` 필드가 존재하나 badge_dialog.dart 주석이 "줍댕이 꾸미기 기능은 범위에서 제외 — 미사용"이라고 명시한다 |
| ACT-05-01DG | 아이템 획득 조건 모달 | - | - | 미구현 | ACT-07 | - | 수록 미확정. 상동 |

### 4-7. MNU 메뉴·프로필

| 신규 ID | 화면명 | 프로그램 ID | 클래스/함수명 | 구현 상태 | 구 ID(설계서) | 구 ID(코드) | 비고 |
|---|---|---|---|---|---|---|---|
| MNU-01-00MS | 메뉴 메인 | settings/presentation/menu_screen.dart | `MenuScreen` | 부분 | MENU-01 | - | 프로필·상점·하위 화면 이동은 모두 동작. '실시간 알림 설정' 토글만 로컬 `setState` 뿐이고 저장·권한 연결이 없다(TODO) |
| MNU-01-01DG | 로그아웃 확인 | settings/presentation/menu_screen.dart | `_confirmSignOut` | 완성 | - | - | 수록 미확정. `UserService.signOut()` 후 `/login` |
| MNU-01-02DG | 탈퇴 확인 | settings/presentation/menu_screen.dart | `_confirmDelete` | 완성 | - | - | 수록 미확정. `UserService.deleteAccount()`. 재인증 필요 시 안내 스낵바 |
| MNU-02-00MS | 프로필 | mypage/presentation/profile_screen.dart | `ProfileScreen` | 완성 | MENU-02 | - | `loadProfileDetail` 조회 + `updateProfileFields` 낙관적 저장 |
| MNU-02-01BS | 사진 소스 선택 | mypage/presentation/profile_screen.dart | `_changePhoto` | 완성 | - | - | 수록 미확정. 앨범/촬영 선택 후 `UserService.uploadProfilePhoto` |
| MNU-02-02DG | 닉네임 입력 | mypage/presentation/profile_screen.dart | `_editNickname` → `_textDialog` | 완성 | - | - | 수록 미확정 |
| MNU-02-03BS | 성별 선택 | mypage/presentation/profile_screen.dart | `_editGender` | 완성 | - | - | 수록 미확정 |
| MNU-02-04BS | 나이·키·몸무게 휠 | mypage/presentation/profile_screen.dart | `_editNumber` (나이) / `_editIntField` (키·몸무게) | 부분 | - | - | 수록 미확정. **휠 바텀시트는 나이만이다.** 키·몸무게는 `_textDialog` 기반 숫자 입력 다이얼로그이므로 하나의 BS로 묶을 수 없다 |
| MNU-02-05DG | 지역 변경 | mypage/presentation/profile_screen.dart | `_editRegion` → `_textDialog` | 부분 | MENU-03 | - | 별도 화면이 아니라 프로필 화면 안의 텍스트 입력 다이얼로그다. 설계서 MENU-03은 지도 기반 현재 위치 호출로 정의되어 있으나, 실제 구현은 자유 텍스트 입력이다 |
| MNU-03-00MS | 공지사항 목록 | settings/presentation/notice_screen.dart | `NoticeListScreen` | 부분 | MENU-04 | EXTRA-03 | MENU-04를 목록·상세로 분리. 공지 3건이 `static final List<Notice> _notices` 더미(TODO: Firestore notices 컬렉션으로 교체) |
| MNU-04-00MS | 공지사항 상세 | settings/presentation/notice_screen.dart | `NoticeDetailScreen` | 부분 | MENU-04 | EXTRA-04 | 위와 동일 파일. 더미 공지를 그대로 받는다 |
| MNU-05-00MS | FAQ | settings/presentation/faq_screen.dart | `FaqScreen` | 부분 | MENU-05 | - | 문답이 `static const List<(String, String)> _faqs` 코드 상수. 아코디언 동작은 완성(TODO: 실제 문의 많은 항목으로 보강) |
| MNU-06-00MS | 문의 및 신고 | settings/presentation/inquiry_screen.dart | `InquiryScreen` | 완성 | MENU-06 | - | Firestore `inquiries` 컬렉션에 실제 저장 |
| MNU-06-01DG | 문의 접수 완료 | settings/presentation/inquiry_screen.dart | `_showDone` | 완성 | - | - | 수록 미확정. '접수되었습니다' + '확인 후 입력하신 이메일로 답변드릴게요' |
| MNU-07-00MS | 이용약관 / 개인정보처리방침 | settings/presentation/terms_screen.dart | `TermsScreen` | 부분 | MENU-07 | - | MENU-07을 약관·오픈소스로 분리. 본문이 초안이며 파일 상단에 법률 검토 TODO가 달려 있다. 화면 안에 이용약관/개인정보 2개 내부 탭(`_tab`)이 있으나 ID가 없다 |
| MNU-08-00MS | 오픈소스 및 출처 | settings/presentation/licenses_screen.dart | `LicensesScreen` | 부분 | MENU-07 | - | 위와 동일. 아이콘 제작자명이 전부 `'TODO: 제작자명'`으로 비어 있다 |

### 4-8. SHP 에코포인트·상점

| 신규 ID | 화면명 | 프로그램 ID | 클래스/함수명 | 구현 상태 | 구 ID(설계서) | 구 ID(코드) | 비고 |
|---|---|---|---|---|---|---|---|
| SHP-01-00MS | 에코포인트 상점 | shop/presentation/shop_screen.dart | `ShopScreen` | 부분 | SHOP-01 | SHOP-01 | 포인트 조회·교환은 Firestore 실연동(`_useDummy = false`). 상품 목록만 shop/data/shop_service.dart의 `static const catalog` 코드 상수(TODO: Firestore products 컬렉션으로 이관) |
| SHP-01-01DG | 구매 컨펌 모달 | shop/presentation/shop_screen.dart | `_confirmExchange` | 완성 | SHOP-02 | SHOP-02 | 사용 포인트·교환 후 잔여 표시. 포인트 부족 시 다이얼로그 대신 스낵바 '포인트가 조금 더 필요해요' |
| SHP-01-02DG | 구매 완료 모달 | shop/presentation/shop_screen.dart | `_showDone` | 완성 | SHOP-03 | - | '교환되었습니다'. 코드 주석에는 이 ID가 없었다 |
| SHP-02-00MS | 쿠폰함 - 미사용 | shop/presentation/coupon_screen.dart | `CouponScreen` | 완성 | SHOP-04 | SHOP-03 | `ShopService.myCoupons()` 실호출. 0건이면 '사용할 수 있는 쿠폰이 없어요' |
| SHP-02-01TB | 쿠폰함 - 사용완료·만료 | shop/presentation/coupon_screen.dart | `CouponScreen` 내 '사용 완료 및 만료' 섹션 | 부분 | SHOP-04 | - | **탭이 아니다.** 미사용 쿠폰과 같은 `ListView` 안의 두 번째 섹션으로, 탭 전환 없이 함께 스크롤된다. 유형 TB와 구현이 어긋난다 |
| SHP-03-00MS | 쿠폰 상세 | shop/presentation/coupon_screen.dart | `CouponDetailScreen` | 완성 | SHOP-05 | SHOP-04 | 공유(`share_plus`)·갤러리 저장(`gal`)·사용 완료 토글 모두 동작. 한 파일에 화면 2개가 들어 있다 |
| SHP-03-01DG | 바코드 확대 | shop/presentation/coupon_screen.dart | `_zoom` | 부분 | - | - | 수록 미확정. 확대 다이얼로그는 동작하나 바코드가 자체 `_BarcodePainter`로 그린 장식이며 실제 스캔 규격이 아니다(파일 주석: 실제 규격이 필요하면 barcode_widget 패키지로 교체할 것) |

### 4-9. PRM 권한

| 신규 ID | 화면명 | 프로그램 ID | 클래스/함수명 | 구현 상태 | 구 ID(설계서) | 구 ID(코드) | 비고 |
|---|---|---|---|---|---|---|---|
| PRM-01-00MS | 권한 요청 안내 | - | - | 미구현 | PERM-01 | - | 앱 자체 안내 화면 없음. plogging/data/location_repository.dart가 `Geolocator.requestPermission()`으로 OS 다이얼로그를 바로 띄운다 |
| PRM-02-00MS | 백그라운드 위치 안내 | - | - | 미구현 | PERM-02 | - | 백그라운드 위치 관련 UI 및 Foreground Service 안내 코드 0건 |
| PRM-03-00MS | 권한 거부 안내 | - | - | 미구현 | PERM-03 | - | 거부(`denied`)·영구 거부(`deniedForever`)를 구분해 처리하지만, 결과는 `print` 로그(`'위치 권한 거부됨'`, `'위치 권한 영구 거부됨 — 설정에서 허용 필요'`)뿐이고 사용자에게 노출되지 않는다 |

### 4-10. ERR 전역 오류

| 신규 ID | 화면명 | 프로그램 ID | 클래스/함수명 | 구현 상태 | 구 ID(설계서) | 구 ID(코드) | 비고 |
|---|---|---|---|---|---|---|---|
| ERR-01-00FP | 네트워크 오류 | - | - | 미구현 | ERR-01 | - | 전역 오버레이 없음. 화면별 인라인 처리로 분산되어 있다. 8절 참조 |
| ERR-02-00DG | 기타 시스템 오류 | - | - | 미구현 | ERR-05 | - | 전역 오류 다이얼로그 없음. `AppDialog`는 확인/취소 공용 팝업이지 오류 전용이 아니다. 8절 참조 |

---

## 5. 통계

### 5-1. 접두사별

| 접두사 | 건수 | 주화면(00) | 부수(01~) |
|---|---|---|---|
| AUT | 7 | 5 | 2 |
| HOM | 4 | 2 | 2 |
| NWS | 2 | 2 | 0 |
| PLG | 17 | 4 | 13 |
| GRP | 11 | 5 | 6 |
| ACT | 15 | 5 | 10 |
| MNU | 16 | 8 | 8 |
| SHP | 7 | 3 | 4 |
| PRM | 3 | 3 | 0 |
| ERR | 2 | 2 | 0 |
| **합계** | **84** | **39** | **45** |

주화면 39건 중 37건이 MS이고, 나머지 2건은 ERR-01-00FP와 ERR-02-00DG다. 전역 오류는 부모 화면이 없어 자기 자신이 00번을 차지하면서 유형만 FP/DG가 된다.

부수가 가장 많은 것은 PLG(13)와 ACT(10)다. PLG는 트래킹 흐름 전체가 모달·토스트로 분기하기 때문이고, ACT는 한 화면(`MyActivityScreen`)이 탭 4개를 품고 있기 때문이다.

### 5-2. 유형별

| 유형 | 건수 |
|---|---|
| MS Main Screen | 37 |
| DG Dialog | 23 |
| BS Bottom Sheet | 6 |
| TB Tab | 5 |
| FP Full Popup | 4 |
| TO Toast | 3 |
| ES Empty State | 2 |
| CD Card | 2 |
| TT Tooltip | 2 |
| **합계** | **84** |

### 5-3. 구현 상태별

| 상태 | 건수 | 비율 |
|---|---|---|
| 완성 | 46 | 55% |
| 부분 | 22 | 26% |
| 스텁 | 0 | 0% |
| 미구현 | 16 | 19% |
| 확인필요 | 0 | 0% |
| **합계** | **84** | |

'스텁'이 0건인 것은 `PlaceholderScreen`을 쓰는 세 라우트(`/vision/result`, `/reward`, `/news`)가 ID 목록에 없기 때문이다(7절 참조).

### 5-4. 접두사별 구현 상태

| 접두사 | 완성 | 부분 | 미구현 |
|---|---|---|---|
| AUT | 4 | 2 | 1 |
| HOM | 2 | 1 | 1 |
| NWS | 2 | 0 | 0 |
| PLG | 10 | 1 | 6 |
| GRP | 7 | 4 | 0 |
| ACT | 9 | 3 | 3 |
| MNU | 8 | 8 | 0 |
| SHP | 4 | 3 | 0 |
| PRM | 0 | 0 | 3 |
| ERR | 0 | 0 | 2 |
| **합계** | **46** | **22** | **16** |

미구현 16건 중 11건이 PLG(6)·PRM(3)·ERR(2)에 몰려 있다. 플로깅 흐름의 보조 안내(날씨·카운트다운·이탈·GPS)와 권한·오류 처리가 통째로 비어 있는 상태다.

MNU는 미구현이 0건이나 16건 중 8건이 부분이다. 공지·FAQ·약관·출처가 모두 코드 상수 더미이기 때문이며, 화면 골격은 완성되어 있고 내용만 비어 있는 상태다.

---

## 6. 옛 ID 대조표

코드 주석에 남아 있는 옛 ID는 고유 21종, 표기 35개(33개 라인)다. 표기는 전부 주석 안에만 있으며 문자열 리터럴이나 변수명에는 쓰이지 않는다.

| 옛 ID(코드 주석) | 코드상 위치 | 대응 신규 ID | 대조 결과 |
|---|---|---|---|
| AUTH-03 | auth/presentation/signup_screen.dart | AUT-03-00MS | 일치 |
| HOME-02 | mypage/presentation/my_impact_screen.dart | HOM-02-00MS | 일치. 단 코드 주석은 mypage 파일에 붙어 있고 신규 ID는 HOM 접두사다 |
| AUTO-02 | core/providers/shared_group_provider.dart<br>plogging/presentation/settlement_screen.dart ×3 | HOM-01-01CD | 대응은 되나 **표시 코드가 없다**. 4건 모두 신호를 쓰는 쪽 주석이고 읽는 쪽이 없다 |
| PLOG-04 | plogging/presentation/plogging_tracking_screen.dart | PLG-02-01DG | **번호 이동.** 옛 설계서에서는 PLOG-03이 규칙 모달이었고 코드 주석만 PLOG-04로 적혀 있었다. 신규 체계에서는 PLG-01-03FP(카운트다운)가 옛 PLOG-04 자리를 쓴다 |
| PLOG-06 | plogging/presentation/plogging_tracking_screen.dart | PLG-02-02DG | 일치 |
| PLOG-07 | plogging/presentation/plogging_tracking_screen.dart | PLG-02-03DG | 일치 |
| PLOG-10 | plogging/presentation/route_setup_screen.dart ×2 | PLG-01-02DG | **번호 이동.** 설계서상 중단 복구는 PLOG-12이고, 옛 PLOG-10은 AI 분석 중(PLG-03-01FP)이다. 코드 주석이 설계서와 다른 번호를 쓰고 있었다 |
| GRP-02 | community/presentation/group_search_screen.dart | GRP-02-00MS | 일치 |
| GRP-03 | community/presentation/group_create_screen.dart | GRP-03-00MS | 일치 |
| GRP-04 | group_create_screen.dart ×4<br>group_detail_screen.dart ×2<br>group_search_screen.dart<br>community/data/group_service.dart | GRP-03-01DG | 일치. 8곳에 흩어져 있고 그중 하나는 data 레이어(`group_service.dart`)다. 화면 ID라기보다 정책 식별자로 쓰이고 있다 |
| GRP-05 | community/presentation/group_feed_screen.dart | GRP-05-00MS | 일치. 신규 체계에서 옛 GRP-05가 GRP-04-00MS(상세)와 GRP-05-00MS(피드)로 분리되었으므로, 주석이 붙은 위치(피드)를 기준으로 GRP-05-00MS에 대응한다 |
| ACT-04 | mypage/presentation/activity_list_screen.dart | ACT-02-00MS | **번호 이동.** 신규 체계에서 내 활동 화면(기록·뱃지·그래프)이 ACT-01 하나로 통합되면서 이후 주화면이 두 칸씩 당겨졌다 |
| ACT-05 | mypage/presentation/activity_detail_screen.dart | ACT-03-00MS | **번호 이동.** 위와 같은 사유 |
| ACT-08 | mypage/presentation/badge_dialog.dart | ACT-01-06DG | **번호 이동.** 설계서상 뱃지 상세는 ACT-06이고, 옛 ACT-08은 뱃지 획득 모달(PLG-04-01DG)이다. 코드 주석이 설계서와 다른 번호를 쓰고 있었다. 신규 체계에서는 내 활동 화면의 부수로 들어간다 |
| ACT-09 (뱃지 획득 모달) | mypage/presentation/badge_dialog.dart<br>plogging/presentation/settlement_screen.dart | PLG-04-01DG | **충돌.** 아래 항목과 같은 번호다 |
| ACT-09 (전체 퀘스트 목록) | mypage/presentation/quest_list_screen.dart | ACT-04-00MS | **충돌.** 위 항목과 같은 번호다 |
| SHOP-01 | shop/presentation/shop_screen.dart | SHP-01-00MS | 일치 |
| SHOP-02 | shop/presentation/shop_screen.dart ×2 | SHP-01-01DG | 일치 |
| SHOP-03 | shop/presentation/coupon_screen.dart | SHP-02-00MS | **번호 이동.** 설계서상 쿠폰함은 SHOP-04이고, 옛 SHOP-03은 구매 완료 모달(SHP-01-02DG)이다 |
| SHOP-04 | shop/presentation/coupon_screen.dart | SHP-03-00MS | **번호 이동.** 설계서상 쿠폰 상세는 SHOP-05다. 위 항목과 같은 방향으로 한 칸씩 밀려 있다 |
| EXTRA-03 | settings/presentation/notice_screen.dart | MNU-03-00MS | 설계서에는 EXTRA 접두사가 없고 MENU-04로 되어 있어, 코드 주석만 별도 접두사를 썼다. 신규 체계에서는 지역 변경이 MNU-02의 부수로 내려가면서 이후 주화면이 한 칸씩 당겨졌다 |
| EXTRA-04 | settings/presentation/notice_screen.dart | MNU-04-00MS | 상동. EXTRA-03과 같은 한 줄에 함께 적혀 있다 |

### 6-1. ACT-09 충돌 기록

옛 체계에서 `ACT-09`가 서로 다른 두 대상에 붙어 있었다.

| 위치 | 지칭 대상 | 신규 ID |
|---|---|---|
| mypage/presentation/badge_dialog.dart | 뱃지 획득 모달 | PLG-04-01DG |
| plogging/presentation/settlement_screen.dart | 뱃지 획득 모달 (위 모달의 호출 측) | PLG-04-01DG |
| mypage/presentation/quest_list_screen.dart | 전체 퀘스트 목록 화면 | ACT-04-00MS |

앞의 두 건은 같은 대상을 가리키므로 정상이나, `quest_list_screen.dart`는 전혀 다른 화면에 같은 번호를 쓰고 있었다. 코드만으로는 어느 쪽이 기획서와 맞는지 판별할 수 없었다. 신규 체계에서는 두 대상이 서로 다른 접두사(PLG / ACT)를 갖게 되어 충돌이 해소된다.

이 충돌은 ID를 정의한 문서가 저장소 안에 없어 코드 작성 시점에 대조할 기준이 없었기 때문에 발생했다. 본 문서가 그 기준을 제공한다.

### 6-2. 접두사 대조

옛 코드 주석에서 실제로 쓰인 접두사는 `AUTH`, `HOME`, `AUTO`, `PLOG`, `GRP`, `ACT`, `SHOP`, `EXTRA` 8종이다. 설계서 기준으로 언급되던 `MENU`, `PERM`, `ERR`, `EMPTY`, `NEWS`는 코드 주석에 한 건도 없었다. 반대로 `EXTRA`는 설계서에 없는 접두사인데 코드에만 존재했다.

신규 체계는 접두사를 3자리로 통일했으므로 `AUTH → AUT`, `HOME → HOM`, `PLOG → PLG`, `SHOP → SHP`, `MENU → MNU`, `PERM → PRM`, `NEWS → NWS`로 바뀐다. `AUTO`와 `EXTRA`는 폐기하고 각각 부모 화면(HOM, MNU)에 귀속시킨다. `EMPTY`는 유형 코드 `ES`로 흡수한다.

`EMPTY` 3건 중 EMPTY-01(활동 기록 없음)은 ACT-01-05ES, EMPTY-02(그룹 미가입)는 GRP-01-01ES로 대응한다. **EMPTY-03(뱃지 미획득)은 대응 ID가 없다.** 별도 빈 상태가 아니라 뱃지 탭(ACT-01-01TB)의 기본 상태이며, 미획득 뱃지도 자물쇠 타일로 항상 표시되어 0건 상태가 발생하지 않기 때문이다. 최초 작성 시 ACT-02-02ES로 두었으나 본 개정에서 삭제했다.

---

## 7. ID 미부여 항목

4절 목록의 어느 ID에도 대응하지 않으면서 코드에는 존재하는 항목이다. 본 문서에서 ID를 부여하지 않는다.

### 7-1. 라우트는 있으나 목록에 없는 것 (3건)

| 라우트 | 프로그램 ID | 표시 내용 | 추정 사유 |
|---|---|---|---|
| `/vision/result` | core/router/app_router.dart → core/router/placeholder_screen.dart | `PlaceholderScreen(screenName: 'AI 인증 결과')` | 기능 폐기. 실시간 오버레이 방식으로 바뀌면서 결과 화면이 불필요해졌으나 라우트만 남았다 |
| `/reward` | 상동 | `PlaceholderScreen(screenName: '에코포인트')` | 부모에 흡수. 에코포인트는 SHP 접두사(상점·쿠폰함)로 재편되었다 |
| `/news` | 상동 | `PlaceholderScreen(screenName: '환경 뉴스')` | 중복. NWS-01-00MS(`NewsFeedScreen`)가 실제 구현이나 이 라우트는 그것을 가리키지 않는다 |

`PlaceholderScreen` 자체(core/router/placeholder_screen.dart)도 ID가 없다. 세 라우트의 공용 껍데기이며 화면이 아니다.

### 7-2. 어느 ID에도 대응하지 않는 다이얼로그·시트 (0건)

최초 작성 시 2건이 있었으나, 본 개정에서 둘 다 ID를 부여해 4절로 옮겼다.

| 항목 | 부여한 ID |
|---|---|
| 플로깅 안내 도움말 (`_showGuide`) | PLG-02-06DG |
| 그룹 가입 확인 (`_join` 내부 `AppDialog.show`) | GRP-04-01DG |

두 건 모두 설계서에 정의되어 있지 않으나 실제 사용자 흐름에 노출되는 팝업이므로, 부모 화면의 부수로 편입했다. 현재 ID가 없는 다이얼로그·시트는 남아 있지 않다.

### 7-3. 어느 ID에도 대응하지 않는 탭 (4묶음)

| 항목 | 프로그램 ID | 클래스/함수명 | 추정 사유 |
|---|---|---|---|
| 퀘스트 분류 탭 (전체/진행중/완료됨) | mypage/presentation/quest_list_screen.dart | `QuestListScreen` 내 `PageController` | 부모(ACT-04-00MS)에 흡수된 것으로 보인다 |
| 약관 탭 (이용약관/개인정보 처리방침) | settings/presentation/terms_screen.dart | `_TermsScreenState._tab` | 부모(MNU-07-00MS)에 흡수. 다만 화면명이 두 문서를 병기하고 있어 TB 부여 여지가 있다 |
| 상점 카테고리 탭 | shop/presentation/shop_screen.dart | `_ShopScreenState._pageController` / `ShopCategory` | 부모(SHP-01-00MS)에 흡수 |
| 검색 필터 드롭다운 (지역/정렬) | community/presentation/group_search_screen.dart | `_FilterDropdown` | 부모(GRP-02-00MS)에 흡수. 현재 값이 쿼리에 반영되지 않는다 |

### 7-4. 어느 ID에도 대응하지 않는 빈 상태·오류 상태 (6건)

| 항목 | 프로그램 ID | 클래스/함수명 | 표시 문구 | 추정 사유 |
|---|---|---|---|---|
| 홈 전체 로드 실패 | home/presentation/home_screen.dart | `_ErrorState` | '정보를 불러오지 못했어요' | ERR-01-00FP가 미구현이라 화면별로 흩어진 결과 |
| 홈 뉴스 섹션 실패 | home/presentation/home_screen.dart | `_NewsUnavailable` | '환경 소식을 불러오지 못했어요' / '잠시 후 다시 시도해 주세요' | 상동 |
| 기록 로드 실패 | mypage/presentation/my_activity_screen.dart | `_ErrorBox` | '기록을 불러오지 못했어요' | 상동 |
| 뉴스 목록 실패·빈목록 | news/presentation/news_feed_screen.dart | `_CenterMessage` | '뉴스를 불러오지 못했어요' / '표시할 뉴스가 없어요' | 상동 |
| 다른 그룹 0건 | community/presentation/group_screen.dart | `_EmptyCard` | '아직 다른 그룹이 없어요' / '첫 번째 그룹을 만들어보세요' | 기획 누락. GRP-01-01ES(내 그룹 미가입)만 ID가 있고 이쪽은 없다 |
| 쿠폰 0건 | shop/presentation/coupon_screen.dart | `_empty` | '사용할 수 있는 쿠폰이 없어요' / '아직 없어요' | 기획 누락 |

### 7-5. 개발용 (1묶음, 3곳)

| 항목 | 프로그램 ID | 클래스/함수명 | 추정 사유 |
|---|---|---|---|
| 가짜 데이터 심기·지우기 버튼 | mypage/presentation/my_activity_screen.dart<br>community/presentation/group_screen.dart<br>community/presentation/group_feed_screen.dart | `_DevSeedButtons` / `_runSeed` | 개발용. 세 파일 모두 "배포 전 삭제" 주석이 달려 있다. core/dev/dev_seed.dart를 호출한다 |

### 7-6. 촬영 중 오버레이 (1건)

| 항목 | 프로그램 ID | 클래스/함수명 | 표시 문구 | 추정 사유 |
|---|---|---|---|---|
| 사진 촬영 중 전체 오버레이 | vision/presentation/camera_detection_screen.dart | `_isCapturing` 분기 | '사진 촬영 중...' | 기획 누락. PLG-03-01FP(AI 분석 중)가 있어야 할 자리에 다른 성격의 오버레이가 들어 있다 |

### 7-7. 소계

| 구분 | 건수 |
|---|---|
| 라우트 (스텁 화면) | 3 |
| 다이얼로그 | 0 |
| 탭 묶음 | 4 |
| 빈 상태·오류 상태 | 6 |
| 개발용 버튼 묶음 | 1 |
| 전체 오버레이 | 1 |
| **합계** | **15** |

최초 작성 시 17건이었고, 본 개정에서 다이얼로그 2건에 ID를 부여해 15건이 되었다.

이 밖에 공용 위젯(core/widgets/의 `AppDialog`, `AppSnackBar`, `AppButton`, `AppCard`, `AppSection`, `AppStat`)은 화면이 아니라 부품이므로 대상에서 제외했다. `AppSnackBar`를 통해 나가는 개별 문구는 20건 이상이며, 대부분 '...하지 못했어요' 형태의 실패 안내다.

---

## 8. 검증이 필요한 항목

특별 검증 대상 8건의 조사 결과다. 검색은 모두 `lib/` 전체를 대상으로 했다.

### 8-1. PLG-01-01TO 날씨 안내 — 미구현

검색: 정규식 `(?i)weather|날씨|기온|온도|미세먼지`

결과 1건, 화면 코드 아님. `core/dev/dev_seed.dart`의 더미 그룹 게시글 문구 `'오늘 날씨 좋네요'` 하나뿐이다. 날씨 API 호출, 날씨 모델, 배너·토스트 위젯이 모두 없다. `RouteSetupScreen` 진입 시점(`initState`)에 실행되는 것은 경로 상태 초기화와 중단 세션 확인 두 가지뿐이다.

### 8-2. PLG-01-03FP 카운트다운 — 미구현

검색: 정규식 `(?i)countdown|카운트다운|3, 2, 1|준비`

카운트다운 관련 코드 0건. 매칭된 6건은 '카메라 준비 중...', '준비 중인 카테고리예요' 등 무관한 문구다. `RouteSetupScreen`의 '플로깅 시작' 버튼은 `context.push(AppRoutes.ploggingTracking)`을 직접 호출하며, 중간 단계가 없다. 트래킹 화면의 `initState`도 즉시 `trackingProvider.start()`를 호출한다.

### 8-3. PLG-02-04CD 경로 이탈 재추천 카드 — 미구현

검색: 정규식 `(?i)이탈|deviat|offRoute|재추천|경로를 벗어|100m`

결과 0건. 추천 경로(`routeNotifierProvider`)와 현재 위치(`watchTrackPoints`)를 비교하는 코드가 없다. `plogging_tracking_screen.dart`는 추천 경로를 `NPathOverlay`로 그리기만 하고, 이탈 판정 로직이 없다.

### 8-4. PLG-02-05TO GPS 미수신 안내 — 미구현

검색: 정규식 `(?i)GPS|signal|신호|accuracy|위치 정확`

매칭 25건 전부가 주석 또는 좌표 처리 코드다. 사용자에게 노출되는 위치 관련 문구는 `route_setup_screen.dart`의 `'현재 위치를 가져오지 못했습니다. 위치 권한을 확인해 주세요.'` 하나뿐이며, 이는 권한 문제 안내이지 GPS 신호 세기 안내가 아니다. `location_repository.dart`는 `LocationAccuracy.best`로 요청하고 정확도 값을 받지만 이를 UI로 전달하지 않는다. 트래킹 화면은 위치 스트림 오류를 `onError: (_) {}`로 삼킨다.

### 8-5. PLG-03-01FP AI 분석 중 — 미구현 (실시간 오버레이로 대체)

지시된 대로 `camera_detection_screen.dart` 전문을 확인했다. 사전 예상이 맞다.

이 화면은 700ms 간격(`_intervalMs = 700`)으로 카메라 스트림 프레임을 JPEG로 변환해 서버에 보내고, 결과를 `_detections`에 담아 `DetectionPainter`로 프리뷰 위에 실시간으로 겹쳐 그린다. 별도의 '분석 중' 화면이나 전체 오버레이는 없다. 대신 다음 두 가지가 있다.

| 상태 | 표현 | 문구 |
|---|---|---|
| `_isProcessing` (추론 중) | 프리뷰 우상단 20×20 스피너 | 없음 |
| `_isCapturing` (등록 버튼 누른 뒤 촬영·업로드 중) | 프리뷰 전체를 `Colors.black54`로 덮는 오버레이 + 스피너 | '사진 촬영 중...' |

두 번째가 형태상 FP에 가장 가깝지만 의미가 다르다. AI 분석 대기가 아니라 사진 촬영 대기이며, 촬영 사진이나 바운딩 박스를 보여주지 않는다. 따라서 PLG-03-01FP는 미구현으로 판정하고, 이 오버레이는 7-6절에 ID 미부여 항목으로 별도 기록했다.

### 8-6. PLG-03-02DG AI 분석 실패 — 부분

검색: `_onImage`의 예외 처리 경로를 직접 확인했다.

추론 실패 시 실행되는 코드는 `debugPrint('Detect error: $e')` 한 줄이다. 사용자에게는 아무것도 보이지 않으며, 실패한 프레임은 조용히 버려지고 700ms 뒤 다음 프레임이 재시도된다. 다이얼로그가 없다.

사용자에게 보이는 유일한 관련 안내는 인식 결과가 0건일 때의 스낵바다.

```
'인식된 쓰레기가 없습니다'
```

이는 실패 안내가 아니라 빈 결과 안내이므로, 이 ID는 완성이 아니라 부분으로 판정했다. 서버 연결 상태는 앱바 우측 아이콘(`cloud_done` / `cloud_off`)으로만 표시된다.

### 8-7. ERR-01-00FP 네트워크 오류 — 미구현

전역 네트워크 오류 오버레이는 없다. 형태는 **화면별 인라인 상태 + 스낵바**로 분산되어 있으며, 다음 6가지가 확인된다.

| 형태 | 위치 | 사용자에게 보이는 문구 |
|---|---|---|
| 인라인 전체 화면 | home/presentation/home_screen.dart `_ErrorState` | `'정보를 불러오지 못했어요'` + 예외 문자열 + `'다시 시도'` |
| 인라인 카드 | home/presentation/home_screen.dart `_NewsUnavailable` | `'환경 소식을 불러오지 못했어요'` / `'잠시 후 다시 시도해 주세요'` + `'다시 시도'` |
| 인라인 전체 영역 | news/presentation/news_feed_screen.dart `_CenterMessage` | `'뉴스를 불러오지 못했어요'` + `'다시 시도'` |
| 인라인 카드 | mypage/presentation/my_activity_screen.dart `_ErrorBox` | `'기록을 불러오지 못했어요'` + `'다시 시도'` |
| SnackBar | auth/presentation/login_screen.dart (문구는 auth_repository.dart `_getKoreanErrorMessage`) | `'네트워크 연결을 확인해주세요.'` |
| 예외 메시지 → 인라인 텍스트 | plogging/data/route_repository.dart → route_setup_screen.dart 하단 패널 | `'도보 경로를 가져오지 못했습니다. 잠시 후 다시 시도해 주세요.'` |

공통 규칙이 없다. 재시도 버튼이 있는 곳과 없는 곳이 섞여 있고, 문구의 어미도 `'~해주세요.'`(마침표 있음)와 `'~해 주세요'`(없음)가 혼재한다.

### 8-8. ERR-02-00DG 기타 시스템 오류 — 미구현

전역 시스템 오류 다이얼로그는 없다. `core/widgets/app_dialog.dart`의 `AppDialog`는 제목·본문·버튼 1~2개를 받는 범용 확인 팝업이며, 오류 전용 경로가 아니다. 저장소 전체에서 오류를 다이얼로그로 띄우는 곳은 한 군데도 없다.

대신 다음 두 가지 처리가 섞여 있다.

| 처리 | 예 | 사용자에게 보이는 문구 |
|---|---|---|
| SnackBar 안내 | shop_screen.dart, coupon_screen.dart, group_create_screen.dart 등 20곳 이상 | `'교환하지 못했어요'`, `'쿠폰을 불러오지 못했어요'`, `'그룹을 만들지 못했어요'`, `'탈퇴하지 못했어요'`, `'저장하지 못했어요'` 등 |
| 무시 + 로그 | settlement_screen.dart, plogging_tracking_screen.dart 등 | 없음. `debugPrint('[정산] 활동 저장 실패: $e')`, `debugPrint('Firestore 저장 실패: $e')` |

두 번째 유형이 특히 문제가 될 수 있다. 정산 화면의 활동 저장 실패와 트래킹 화면의 수거 기록 저장 실패가 모두 무음으로 처리되어, 사용자는 기록이 사라진 것을 나중에서야 알게 된다. 다만 이는 본 문서의 범위 밖이므로 기록만 남긴다.

---

## 9. 향후 작업

### 9-1. 코드 주석에 ID 부여

본 문서가 확정된 뒤, 별도 작업으로 각 화면 코드 상단에 다음 형식의 주석을 붙인다.

```dart
/// Screen ID   : PLG-02-00MS
/// Screen Name : 플로깅 - 트래킹 진행
```

규칙은 다음과 같다.

- 다이얼로그·바텀시트는 호출 함수 바로 위에 동일 형식으로 붙인다.
- 부모 화면을 참조하는 주석(예: `GRP-03-01DG 차단 규칙과 동일`)은 자유 형식으로 두고, `Screen ID` 주석은 화면당 1회만 쓴다. 한 정책이 여러 파일에 흩어진 옛 GRP-04 같은 사례를 방지하기 위함이다.
- 옛 ID 표기(`AUTH-`, `HOME-`, `AUTO-`, `PLOG-`, `GRP-`, `ACT-`, `SHOP-`, `EXTRA-`)는 이때 함께 제거한다. 대상은 33개 라인이며 전부 주석이므로 동작에 영향이 없다.

대조 명령:

```
grep -rn "Screen ID" lib/
```

부여가 끝나면 이 명령의 결과 건수가 본 문서 4절의 행 수 중 구현 상태가 미구현이 아닌 것의 수(68건)와 일치해야 한다.

### 9-2. 본 문서의 갱신 시점

다음 경우에 본 문서를 갱신한다.

- 새 화면·다이얼로그를 추가할 때. 번호는 회수하지 않으므로 해당 접두사의 다음 번호를 쓴다.
- 구현 상태가 바뀔 때. 특히 미구현 17건과 부분 22건.
- 7절의 ID 미부여 항목에 ID를 부여하기로 결정할 때.

### 9-3. 우선 결정이 필요한 사항

본 문서 작성 중 확인된, 코드 구조와 ID 목록이 어긋나는 지점이다. 코드는 수정하지 않았고 ID 목록도 그대로 두었다.

1. **HOM-01-01CD** — `sharedGroupProvider`에 값을 쓰는 코드만 있고 읽는 코드가 없다. 팝업을 구현할지, provider를 제거할지 결정이 필요하다.
2. **SHP-02-01TB** — 쿠폰함의 '사용완료·만료'는 탭이 아니라 같은 리스트의 두 번째 섹션이다. 유형을 바꿀지, 화면을 탭으로 바꿀지 결정이 필요하다.
3. **AUT-03-01BS / MNU-02-04BS** — 두 ID 모두 이름에 키·몸무게가 들어 있으나, 실제로 휠 바텀시트를 쓰는 것은 나이뿐이다. 키·몸무게는 텍스트 입력 다이얼로그이므로 하나의 BS로 묶을 수 없다.
4. **HOM-02-00MS, NWS-01-00MS** — 구현은 완성이나 앱 안에서 도달할 수 없다. SB에 수록하되 진입 경로 연결이 선행되어야 한다.

최초 작성 시 지적한 6건 중 2건(ACT의 유형, MNU-03 지역 변경)은 1-1절의 개정으로 해소되었다.
