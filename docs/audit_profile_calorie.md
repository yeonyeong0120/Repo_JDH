# 프로필 신체정보 · 칼로리 산출 방식 조사 보고서

조사 대상: Ploggo Flutter 앱 (`lib/`), 브랜치 `f/route`
조사 방식: 코드 읽기 및 검색만 수행. 앱 코드 수정 없음.

## 1. 결론 요약

| 항목 | 판정 | 한 줄 요약 |
| --- | --- | --- |
| 성별·키·몸무게 수집 | O | 회원가입 2단계와 마이페이지 프로필 화면에서 실제로 입력받고 상태에 연결된다. |
| Firestore 저장 | O | `users/{uid}` 문서에 `gender`, `height`, `weight`(및 `age`) 필드로 `set(merge:true)` 저장된다. |
| 칼로리 계산에 실사용 | X | 칼로리는 `거리(km) x 50` 고정 계수로만 산출되며 성별·키·몸무게는 어떤 계산에도 입력되지 않는다. |

부가 판정: `health` 패키지는 `pubspec.yaml:34`에 선언되어 있고 Android 매니페스트에 Health Connect 권한도 있으나, Dart 코드에서 `package:health`를 import 하는 파일이 하나도 없다. 즉 조사 항목 3의 (A)(Health Connect 값 사용)도 아니고 (B)(신체정보 기반 공식)도 아닌 제3의 경우 — 거리만을 입력으로 하는 자체 추정식 — 에 해당한다.

## 2. 항목별 상세

### 2.1 성별·키·몸무게 수집 여부 — 수집 O (미연결 UI 아님)

입력 화면 1: 회원가입 2단계

- 화면 파일: `lib/features/auth/presentation/signup_screen.dart`
- 로컬 상태 필드 선언: `signup_screen.dart:28-31`
  - `String? _gender; // '남성' / '여성'`, `int? _age;`, `int? _height;`, `int? _weight;`
- 2단계 UI 본체: `signup_screen.dart:347-452` (`_step2()`)
  - 성별: `signup_screen.dart:356-365`. 선택 위젯은 `_genderBox()` (`signup_screen.dart:462-488`)이며 `onTap: () => setState(() => _gender = g)` (`signup_screen.dart:466`)로 값이 상태에 반영된다.
  - 나이: `signup_screen.dart:366-378`. `onConfirm: (v) => setState(() => _age = v)` (`signup_screen.dart:377`).
  - 키: `signup_screen.dart:380-394`. `onConfirm: (v) => setState(() => _height = v)` (`signup_screen.dart:392`).
  - 몸무게: `signup_screen.dart:395-409`. `onConfirm: (v) => setState(() => _weight = v)` (`signup_screen.dart:407`).
  - 숫자 입력 시트 구현: `signup_screen.dart:782` 이하 `_showNumberSheet()`.
- 화면 안내 문구는 `signup_screen.dart:354` "더 정확한 측정에 필요해요 / 걸음수와 칼로리를 계산하는 데 쓰여요.", 나이·몸무게 시트 부제 "칼로리 계산에 사용해요"(`signup_screen.dart:372`, `signup_screen.dart:402`), 키 시트 부제 "걸음 보폭 계산에 사용해요"(`signup_screen.dart:387`)이다. 아래 2.3의 결론과 대조하면 이 문구는 현재 코드 동작과 일치하지 않는다.
- 상태관리 방식: Riverpod provider가 아니라 `ConsumerStatefulWidget`의 `setState` 로컬 상태다(`signup_screen.dart:19-31`). 값이 화면 밖으로 나가는 경로는 2.2의 저장 호출 하나뿐이다.

입력 화면 2: 마이페이지 프로필 수정

- 화면 파일: `lib/features/mypage/presentation/profile_screen.dart` (`StatefulWidget`, `profile_screen.dart:14-27`)
- 상태 객체: `ProfileDetail _p` (`profile_screen.dart:22`)
- 편집 UI: `profile_screen.dart:356-411` (`_basicInfoCard()`)
  - 성별 `profile_screen.dart:366` → `_editGender()` (`profile_screen.dart:648-676`), 선택지는 `['남성','여성']`(`profile_screen.dart:661`), 확정 시 `_p = _p.copyWith(gender: picked)` (`profile_screen.dart:674`).
  - 나이 `profile_screen.dart:367-378`, 키 `profile_screen.dart:379-390`, 몸무게 `profile_screen.dart:391-403`. 각각 `_pickNumber()` 콜백에서 `copyWith`로 상태를 갱신한다(`profile_screen.dart:376`, `:388`, `:400`).
- 기존 값 로드: `_load()` → `UserService.loadProfileDetail()` (`profile_screen.dart:41-55`, `user_service.dart:138-172`).

`nickname_setup_screen.dart`에는 성별·키·몸무게 입력 UI가 없다. 닉네임 중복 확인만 수행한다(`nickname_setup_screen.dart:69`).

판정: 두 화면 모두 입력 위젯이 실제 상태에 연결되어 있고, 그 상태가 저장 호출로 이어진다. 미연결 UI가 아니다.

### 2.2 Firestore 저장 여부 — 저장 O

쓰기 지점 (유일)

- `lib/features/auth/data/user_service.dart:176-200` `UserService.updateProfileFields()`
  - 필드 매핑: `gender`(`user_service.dart:189`), `age`(`:190`), `height`(`:191`), `weight`(`:192`), `nickname`(`:188`), `region`(`:193`)
  - 쓰기 호출: `user_service.dart:196`
    `await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));`
  - 문서 경로: `users/{uid}` (`user_service.dart:11`, `:13`, `:15`)
  - null 인 값은 `data`에 담기지 않으므로 미입력 항목이 기존 값을 덮어쓰지 않는다.

호출 지점

- 회원가입 완료: `signup_screen.dart:119-124` — `createProfile()`(`signup_screen.dart:115-118`)로 문서를 만든 직후 `updateProfileFields(gender: _gender, age: _age, height: _height, weight: _weight)` 호출.
- 프로필 수정 저장: `profile_screen.dart:78-85` — `updateProfileFields(nickname:, gender:, age:, height:, weight:, region:)` 호출.

읽기 지점

- `ProfileDetail.fromJson()` (`lib/features/mypage/domain/profile_detail.dart:87-98`)이 `gender`(`:91`), `age`(`:92`), `height`(`:93`), `weight`(`:94`)를 읽는다.
- 호출 경로: `UserService.loadProfileDetail()` (`user_service.dart:138-172`, 특히 `:146-147`) → `profile_screen.dart:44`.

도메인 모델 정의 상태

- `ProfileDetail` (`lib/features/mypage/domain/profile_detail.dart:10-13`)에 `gender`, `age`, `height`, `weight`가 정의되어 있다. 이 모델은 마이페이지 프로필 화면 표시·수정 전용이다(`profile_detail.dart:3-5` 주석).
- `UserProfile` (`lib/features/auth/domain/user_profile.dart:5-34`)에는 `gender`/`height`/`weight`/`age` 필드가 정의되어 있지 않다. 따라서 `UserService.getCurrentProfile()`(`user_service.dart:20-30`)로 프로필을 읽으면 신체정보는 모델에 담기지 않고 버려진다. 저장 자체는 되지만 auth 계층 모델을 통해서는 조회되지 않는다.

부수 관찰 (조사 범위 밖이나 같은 문서에 관련됨)

- 프로필 사진 필드명이 두 갈래다. `UserProfile.toJson()`은 `profileImageUrl`을 쓰고(`user_profile.dart:61`), `uploadProfilePhoto()`와 `ProfileDetail.fromJson()`은 `photoUrl`을 쓴다(`user_service.dart:213`, `profile_detail.dart:90`).

판정: 수집된 성별·나이·키·몸무게는 `users/{uid}` 문서에 동일 이름 필드로 실제 기록된다.

### 2.3 칼로리 산출 방식 — 성별·키·몸무게 실사용 X

칼로리 값의 단일 출처

- `lib/features/plogging/domain/activity_metrics.dart:49-54`

```dart
  /// 칼로리 추정 — 거리(km) × 계수
  /// TODO: Health Connect 연동 시 실측 칼로리로 교체
  static int estimateKcal(double distanceMeters) {
    if (distanceMeters <= 0) return 0;
    return (distanceMeters / 1000.0 * _kcalPerKm).round();
  }
```

- 계수 정의: `activity_metrics.dart:27-28`

```dart
  // 칼로리 추정 계수: 1km 당 약 50kcal (평균 성인 걷기 대략치)
  static const double _kcalPerKm = 50.0;
```

- 입력 파라미터는 `distanceMeters` 하나뿐이다. 체중·키·성별·나이·시간·MET 어느 것도 함수 시그니처에 없고 본문에서도 참조하지 않는다.
- 걸음 수도 같은 성격이다. `activity_metrics.dart:44-47` `estimateSteps()`는 고정 보폭 `_strideMeters = 0.75`(`activity_metrics.dart:24-25`)로 거리를 나눈다. 사용자 키(`height`)는 보폭 계산에 들어가지 않는다(회원가입 화면의 "걸음 보폭 계산에 사용해요" 문구와 불일치).

`estimateKcal()` 호출처 전수

- `lib/core/providers/tracking_provider.dart:66` — 진행 중 활동의 실시간 kcal (`int get kcal => ActivityMetrics.estimateKcal(distanceMeters);`). 바로 위 `tracking_provider.dart:65`에 `/// TODO: 체중 기반 계산으로 교체` 주석이 남아 있다.
- `lib/features/plogging/domain/activity_stats.dart:86`, `:127`, `:149` — 기간별·전체 누적 통계.
- `lib/features/mypage/data/badge_service.dart:139` — 누적 칼로리 뱃지(`kcal_500`, `badge_service.dart:77`, `:216-217`) 판정.
- `lib/features/mypage/presentation/activity_list_screen.dart:66`, `lib/features/mypage/presentation/my_activity_screen.dart:374`, `lib/features/mypage/presentation/my_impact_screen.dart:56` — 활동 기록·임팩트 화면 표시.

모든 호출이 인자로 `distanceMeters`(또는 `a.distanceMeters`)만 넘긴다. 신체정보를 넘기는 호출은 없다.

Firestore에 칼로리는 저장되지 않는다

- `Activity` 모델(`lib/features/plogging/domain/activity.dart:12-56`)에 kcal·steps 필드가 없다. 서버에는 거리·시간·수거 개수만 저장되고 칼로리는 화면에서 매번 파생 계산된다(`activity_metrics.dart:1-9` 주석과 일치).

health 패키지 / Health Connect 상태

- 의존성 선언: `pubspec.yaml:33-34` (`health: ^13.3.1`, 주석 "헬스 데이터 (Android Health Connect)").
- Android 권한 선언: `android/app/src/main/AndroidManifest.xml:21-27`
  - `android.health.connect.permission.READ_STEPS` (`:25`)
  - `android.health.connect.permission.READ_TOTAL_CALORIES_BURNED` (`:27`)
- 그러나 `lib/`와 `test/` 전체에서 `package:health` import가 0건이다. `HealthFactory`, `Health()`, `HealthDataType` 등 API 사용도 0건이다. `android/app/src/main/kotlin`에도 Health 관련 코드가 없다.
- `lib/features/vision/data/detector.dart:88`, `:95`의 `healthCheck()`는 추론 서버 헬스체크 HTTP 호출로 Health Connect와 무관하다.

성별·키·몸무게의 실제 사용처 전수

코드 전체에서 `gender` / `height`(신체) / `weight`(체중) 값을 참조하는 위치는 다음뿐이다.

- 저장: `user_service.dart:189`, `:191`, `:192`
- 모델 정의·직렬화: `profile_detail.dart:10-13`, `:23-26`, `:76-79`, `:91-94`, `:104-106`
- 화면 표시·편집: `profile_screen.dart:80-83`, `:366`, `:381`, `:385`, `:393`, `:397`, `:664`, `:674`
- 회원가입 입력: `signup_screen.dart:28-31`, `:120-123`, `:377`, `:392`, `:407`, `:466`

계산 로직(`ActivityMetrics`, `ActivityStats`, `BadgeService`, `ImpactMetrics`, `TrackingState`) 어디에서도 이 값들을 읽지 않는다.

최종 판정: 앱이 수집·저장한 성별·키·몸무게는 칼로리 산출의 입력으로 사용되지 않는다. 현재 칼로리는 거리 기반 고정 계수 추정값이며, 프로필 신체정보는 프로필 화면에 되보여주는 용도 외에 소비되는 곳이 없다.

## 3. 데이터 흐름도 (텍스트)

### 3.1 신체정보 입력 → 저장

```
[회원가입 2단계]
signup_screen.dart:_step2()
  _genderBox onTap            (signup_screen.dart:466) -> setState(_gender)
  _showNumberSheet onConfirm  (:377 / :392 / :407)     -> setState(_age / _height / _weight)
        |
        v  (가입 완료)
signup_screen.dart:_finish() (:96)
  AuthRepository.signUp()                                  (:108)
  UserService.createProfile(email, nickname)               (:115)
  UserService.updateProfileFields(gender, age, height, weight) (:119)
        |
        v
user_service.dart:updateProfileFields() (:176)
  data['gender' | 'age' | 'height' | 'weight']  (:189-192)
  _db.collection('users').doc(uid).set(data, merge: true)  (:196)
        |
        v
Firestore  users/{uid}  { gender: String, age: int, height: int, weight: int, ... }

[마이페이지 프로필 수정]
profile_screen.dart:_editGender() / _pickNumber() -> setState(_p = _p.copyWith(...))
        |  (상단 '저장')
        v
profile_screen.dart:_save() (:58) -> UserService.updateProfileFields() (:78) -> 위와 동일 경로

[역방향 조회]
Firestore users/{uid}
  -> user_service.dart:loadProfileDetail()  (:138, :146)
  -> ProfileDetail.fromJson()               (profile_detail.dart:87)
  -> profile_screen.dart:_load()            (:41)   ... 화면 표시 전용, 계산으로 흘러가지 않음

  ※ user_service.dart:getCurrentProfile() (:20) 경로는 UserProfile 모델에
    gender/height/weight 필드가 없어(user_profile.dart:5-34) 값이 유실된다.
```

Riverpod provider는 이 경로에 개입하지 않는다. 두 화면 모두 위젯 로컬 상태(`setState`)에서 곧바로 static 메서드 `UserService.updateProfileFields()`를 호출한다.

### 3.2 칼로리 값의 출처

```
GPS 이동 거리 누적
  location_repository / tracking_provider.addDistance()  (tracking_provider.dart:166)
        |
        v
TrackingState.distanceMeters  (tracking_provider.dart:12)
        |
        v
ActivityMetrics.estimateKcal(distanceMeters)   (activity_metrics.dart:51)
   = round(distanceMeters / 1000.0 * 50.0)     (_kcalPerKm = 50.0, :28)
        |
        +-- tracking_provider.dart:66            (진행 중 화면 실시간 kcal)
        +-- activity_stats.dart:86 / :127 / :149 (기간·전체 누적)
        +-- badge_service.dart:139               -> kcal_500 뱃지 판정 (:77, :216)
        +-- activity_list_screen.dart:66 / my_activity_screen.dart:374 /
            my_impact_screen.dart:56             (기록·임팩트 화면 표시)

gender / height / weight  --X--  (어떤 화살표도 위 흐름에 들어가지 않음)

health 패키지 (pubspec.yaml:34)              --X--  Dart 코드 import 0건
Health Connect 권한 (AndroidManifest.xml:25-27) --X--  대응 코드 없음
```

## 4. 코드만으로 확인 불가한 항목

- Firestore 콘솔의 실제 문서 내용. `users/{uid}`에 `gender`/`height`/`weight`가 실제로 채워져 있는지, 기존 사용자 문서에 누락이 있는지는 코드로 판정할 수 없다.
- Firestore 보안 규칙. 저장소에 `firestore.rules` 파일이 없어 `users` 컬렉션의 읽기·쓰기 권한 범위를 확인할 수 없다. 특히 `isNicknameTaken()`(`user_service.dart:90-104`)이 타인 문서를 조회하므로 규칙에 따라 런타임에 permission-denied가 날 수 있다(해당 주석 `user_service.dart:87-89`가 이미 지적).
- 성별 값 표기. 회원가입·프로필 화면 모두 `'남성'`/`'여성'`을 저장하지만(`signup_screen.dart:28`, `profile_screen.dart:661`) `profile_detail.dart:10` 주석은 `'남' / '여'`로 적혀 있다. 실데이터에 두 표기가 섞여 있는지는 콘솔 확인이 필요하다.
- 앱 실행 시 Health Connect 권한 요청 다이얼로그가 실제로 뜨는지 여부. 매니페스트에 권한 선언만 있고 요청 코드가 없어 코드상으로는 요청되지 않을 것으로 보이나, 런타임 확인은 실기기 검증 영역이다.
- `build/` 산출물이나 다른 브랜치에 별도 구현이 존재하는지는 이번 조사 범위(현재 `lib/` 소스)에서 다루지 않았다.
