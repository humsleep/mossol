# 09. UI 수정 — 캐스트 소개 복구 · 타이틀 화면 · 아바타 프로필

> 2026-09-26 · mobile-app-builder. **표현 계층만 고쳤다** — `lib/ui/**` 와 `test/widget/**` 뿐이다.
> `lib/main.dart` 도 결과적으로 손댈 필요가 없었고(§2), 엔진(`lib/engine/`, `lib/game_controller.dart`,
> `lib/minigames/`)과 스토리 데이터(`assets/story/`)는 한 줄도 건드리지 않았다. 규격은 `docs/DESIGN_SYSTEM.md` 에 같이 반영했다(§1.11 · §2.3 · §2.9 ·
> §2.14 · **새 §2.15 · §2.16** · §4.1).
>
> 커밋하지 않았다. 작업 트리에만 있다.

---

## 0. 한 줄 요약

| # | 한 일 | 증명하는 테스트 |
|---|---|---|
| 1 | 첫 실행에서 사라졌던 **캐스트 소개**를 되살렸다 | `test/widget/intro_test.dart` 4건 |
| 2 | 대화 앞에 **타이틀 화면**을 세웠다(첫 실행에만) | `test/widget/title_test.dart` 6건 + `intro_test` 2건 |
| 3 | 채팅 아바타를 누르면 **초상화가 크게** 열린다 | `test/widget/profile_test.dart` 10건 |

검증: `flutter analyze` — `lib/` 와 `test/widget/` 에 문제 0건. `flutter test` — 아래 §5.

---

## 1. 캐스트 소개 복구 (`intro_screen.dart`)

### 무엇이 문제였나

`IntroScreen._start()` 가 `c.newGame(preference: preference)` 를 **직접** 불렀다. 그래서 홈 → `새 게임`
경로에만 있던 캐스트 소개(`PreferenceScreen`, DS §2.9)가 **첫 실행에서는 한 번도 뜨지 않았다**.
새로 깐 사람은 누구를 만나는지 모른 채 100일에 들어갔다 — 그 화면이 존재하는 이유가 정확히 그것이다.

### 어떻게 고쳤나

마지막 답 → 태현의 두 줄(`'좋아. 그럼 시작이다'` → **새 줄** `'누가 있는지부터 보여 줄게'`) → 900ms →
`PreferenceScreen.show(side: 대화에서 고른 쪽)` → `시작하기` → 저장 → `newGame()` → 날짜 카드.

지킨 것 두 가지:

- **"마지막 답이 곧 시작 버튼"**(DS §2.14). 대화 안에는 여전히 시작 버튼이 없다. 늘어난 탭은 대화가 아니라
  그 **뒤**의 별도 화면에 있는, 원래부터 새 게임 흐름의 일부였던 버튼이다. 전부 건너뛴 탭 수는 4 → 6이 됐고
  (앞의 하나는 타이틀, 뒤의 하나는 캐스트), 그 값을 DS §2.14 에 적어 뒀다.
- **마지막에 한 번만 저장**. `setPlayerGender`·`setPlayerName`·`markIntroSeen`·`newGame` 은 전부
  `시작하기` 뒤에서 일어난다. 캐스트 소개가 떠 있는 동안 `c.hasSave` 는 아직 false 다(테스트가 고정).

### 되돌아오는 길

캐스트 소개에서 **뒤로** 가면 인트로의 마지막 질문으로 돌아온다. `_markCastReturn()` 이 답 직전의 대화
길이와 단계를 적어 두고, `_revertToLastQuestion()` 이 마지막 답과 그 뒤 태현의 두 줄을 지운 뒤 하단 패널을
되살린다. 이걸 안 하면 `IntroStep.starting` 의 빈 패널만 남아 **빠져나갈 길이 없는 화면**이 된다
(뒤로 버튼도 없다). 저장은 여전히 아무것도 안 된 상태라 앱을 껐다 켜면 타이틀부터 다시 시작한다.

이름·MBTI 는 저장 전이라, 캐스트 카드의 첫 메시지가 `{name}` 을 그대로 드러내지 않도록
`TextTemplate.currentName/currentMbti` 에 잠깐만 올렸다 내린다(`onboarding_gender_screen.dart` 의
`cast()` 와 같은 처리).

### 증명

`test/widget/intro_test.dart`
- `타이틀 → 문자 열기 → 대답 → 이름 → 나는? → 캐스트 소개 → 첫날(홈을 안 거친다)` — 캐스트 소개가 뜨고,
  그 시점에 `hasSave == false` · `playerName == null` 이며, `시작하기` 뒤에야 저장·시작된다.
- `캐스트 소개에서 뒤로 가면 아무것도 저장되지 않고 마지막 질문으로 돌아온다` — 뒤로 → "나는?" 패널 복귀,
  태현의 두 줄 삭제, `hasSave == false` · `playerGender == null` · `shouldShowIntro == true`,
  다시 답하면 그대로 이어짐.
- `이름 건너뛰기…` · `두 번째 세션은 홈에서 시작한다` — 기존 경로도 캐스트를 거쳐 끝까지 간다.

---

## 2. 타이틀 화면 (`title_screen.dart`, 새 파일)

유저의 말: *"앱을 처음 켯을때 바로 대화부터 나오는데 앱의 메인 인트로가 있고 그 후에 나오면 좋을것 같아요."*

### 언제 뜨는가 — **첫 실행에만** (근거)

`IntroScreen` 의 0단계로 넣었다. 즉 `GameController.shouldShowIntro`(세이브도 회차 기록도 없고 인트로를
아직 안 봄)일 때만 선다. **매 콜드 스타트가 아니다.** 이유:

1. 이 화면이 하는 일은 "무슨 앱인지" 하나뿐이고, 그건 한 번이면 된다. 돌아온 사람에게 앱 이름을 말하는
   자리는 이미 홈 헤더의 워드마크다(DS §2.1).
2. 가장 자주 지나는 길은 **열기 → 이어하기**다. 거기에 탭을 하나 더 얹는 것은 값을 못 한다.
3. `main.dart` 를 **한 줄도 고치지 않아도** ATT 규칙이 그대로 유지된다. `if (!controller.shouldShowIntro)
   unawaited(AdManager.instance.init())` 의 조건이 타이틀의 조건과 같은 식이라, 추적 동의 팝업은 여전히
   타이틀과 태현의 문자 **뒤**(`_start()` 안)에서만 뜬다. 새 Phase 도, 새 저장 필드도 없다.

전체 초기화(설정 › 저장 데이터 초기화) 뒤에는 새로 깐 것과 같으므로 타이틀도 다시 뜬다 — 의도한 동작이다.

### 어떻게 생겼나

기존 부품만 쓴다. 새 에셋은 하나도 만들지 않았다.

- 바탕: `CallBackdrop`(전화·알림 화면과 같은 항상-다크 자수정 그라데이션) + 상단 55% 장면 삽화 + 켄번즈
  8초 6%(`SceneImage(kenBurns: true)`). 그림은 `assets/scenes/title` 이 있으면 그것, 없으면 **게임의 첫
  삽화 `m01`**(밤 자취방 책상, 엎어 둔 폰의 알림 불빛 — `docs/SCENE_PROMPTS.md` S01), 둘 다 없으면
  그라데이션만(그림 0장이어도 화면이 그대로 선다).
- 글자: `100일 연애 시뮬레이션`(`labelMedium`) → `모쏠 탈출기`(`displaySmall`, 홈 워드마크와 같은 낱말) →
  `톡 한 줄로 썸부터 고백까지`(`bodyLarge`). 마지막 줄은 지어낸 문구가 아니라 **App Store 부제 그대로**다
  (`docs/STORE_LISTING.md` §1).
- 들어가는 문: 전폭 `시작하기` `FilledButton`(`Key('title-start')`).
- 모션: 워드마크 → 버튼 순으로 자기 높이의 20%만 올라오며 밝아진다(`dSlow` 안에서 `Interval` 로 겹침).
  튕김·반복 없음. 동작 줄이기면 연출 없이 완성된 화면.
- **배너 없음.**

알림 화면(`NotificationPreview`)도 같은 `CallBackdrop` 을 쓰므로, `시작하기` → 태현의 알림 카드가 바탕이
이어진 한 장면처럼 넘어간다.

### 같이 옮긴 것: 문자 도착음

`Sfx.msgIn` + medium 진동이 `initState` 에 있었다. 그대로 두면 **타이틀 위에서** 알림음이 울린다 —
화면에 없는 알림의 소리다. 알림 카드가 실제로 내려오는 `_enterNotice()` 로 옮겼다.

### 증명

`test/widget/title_test.dart` (6건) · `test/widget/intro_test.dart` (2건)
- 첫 프레임에 이름·부제·한 줄 소개·시작 버튼이 있고 `NotificationCard` 도 `BannerSlot` 도 없으며 `sfx.played` 가 비어 있다.
- `시작하기` 를 누르면 알림 카드 + `Sfx.msgIn` + `HapticKind.medium`.
- 두 번째 세션(세이브 있음)에는 `TitleScreen` 이 아예 없다.
- 그림이 없으면 `SceneImage` 없이 그대로 서고, `title` 이 없으면 `m01` 을, 둘 다 있으면 `title` 을 쓴다.
- **320×568 · 1.3배** 라이트/다크: 넘침 0, `시작하기` 하단 ≤ 568 · 높이 ≥ 44, 제목이 좌우로 안 잘림,
  `iOSTapTargetGuideline` · `textContrastGuideline` 통과.
- 동작 줄이기: 한 프레임 만에 모든 `FadeTransition` 이 1.0.

---

## 3. 아바타 → 초상화 크게 보기 (`profile_view.dart`, 새 파일)

유저의 말: *"진짜 메신져 처럼 채팅 시 상대방 사진을 누르면 확대해서도 보일 수 있도록해줘."*

### 어디를 누르면 열리나

- 말풍선 왼쪽 아바타(`ChatAvatarSlot`, 채팅·타이핑 표시)
- **통화 머리줄 아바타**(`ActiveCallView` 의 40pt 원)

채팅 `AppBar` 에는 아바타를 **넣지 않았다**. DS §2.3 이 "아바타·제목·D+N 없음" 으로 정해 두었고
§4.1 이 `AppBar 안에 CharacterAvatar 없음` 을 테스트로 고정해 두었다(`event_screen_test.dart:228`).
즉 지금 "상단 바의 아바타" 가 실제로 있는 곳은 통화 머리줄뿐이라 거기를 눌리게 했다. 채팅 상단에도
아바타를 두고 싶다면 그건 DS §2.3·§4.1 을 먼저 고쳐야 하는 별건이다(§6 미완 참고).

### 화면

`PageRouteBuilder`(투명 라우트) + `Hero`. 작은 아바타가 그대로 `AppSize.avatarHero`(200)로 커진다.
`photo_card.dart` 의 크게 보기와 같은 껍데기(SafeArea + 가운데 스크롤 + `닫기`)를 따르되 두 가지가 다르다.

1. **`showAppDialog` 를 재사용하지 못했다.** `showDialog` 가 미는 것은 `PageRoute` 가 아니고,
   `HeroController.didPush` 는 양쪽이 `PageRoute` 일 때만 비행을 시작한다. Hero 를 쓰라는 요구와
   양립하지 않아 같은 생김새를 `PageRouteBuilder` 로 한 번 더 태웠다.
2. **바탕이 스크림이 아니라 `scheme.surface` 한 장이다.** 처음엔 사진 뷰어처럼 스크림 위에 띄웠는데
   `textContrastGuideline` 이 잡았다(호칭 줄 대비 **2.24**). 사진은 캡션 한 줄이지만 프로필에는 이름·호칭·
   매력이 문단으로 들어가므로 대화가 비치면 4.5:1 을 못 넘는다(DS §4.2). 라우트 자체는 여전히 투명이라
   아래로 끌어내리면 그 뒤의 대화가 드러난다.

닫기: 화면 아무 데나 탭 · 아래로 96pt 끌기(또는 700px/s 튕기기) · `닫기` 버튼. 끌다 말면 제자리로 돌아온다.

### 무엇을 보여 주나 — "이미 아는 것" 만

| 값 | 플레이어가 어디서 이미 봤나 |
|---|---|
| 이름 · 호칭 | 캐스트 소개 §2.9 (매 새 게임) |
| 한 줄 매력(`tagline`) | 캐스트 소개 §2.9 |
| MBTI · 궁합 | 캐스트 소개 §2.9 (궁합은 내 MBTI 를 알려 줬을 때만) |
| 호감 `♥N` | 홈 사람들 줄 §2.10 |

`likes`·`mines`·`trust` 는 앱 어느 화면에도 없으므로 여기에도 없다(테스트가 `likes`/`mines` 문자열이
화면에 없음을 확인한다).

**아예 열리지 않는 경우** — 아바타가 그냥 그림이 되고 스크린리더에도 버튼이 생기지 않는다:
- 히든 미해금(그 회차 호감 ≤ 0). 홈 사람들 줄의 `???` 규칙과 같다.
- `'모르는 번호'`·`'알 수 없는 …'`(`ChatBubble.isMysteryName`).
- 캐스트 밖 조연(태현·엄마 — 초상화도 사실도 없어 열어도 빈 화면이다).

프로필을 찾는 길은 `ProfileScope`(InheritedWidget) 하나다. `event_screen.dart` 가 컨트롤러를 보고 채우고,
스코프가 없는 화면(인트로·단독 위젯 테스트)에서는 아무 아바타도 눌리지 않는다.

### 탭 타깃 44 (같이 고친 것)

아바타는 40인데 DS §4.2 는 탭 대상 44를 요구한다. 그래서 **열의 레이아웃 상자만** 44로 넓히고
(`ChatAvatarSlot.width`) 뒤따르는 간격을 `sm`(8) → `xs`(4)로 줄였다. 둘을 더한
`ChatAvatarSlot.indent` 는 48로 예전(40 + 8)과 **같아서 말풍선 왼쪽 선이 1px 도 움직이지 않는다**.
그림은 상자 왼쪽 위에 붙으므로 아바타의 화면상 위치도 그대로다. 스티커 들여쓰기(`StickerBubble.indent`)도
같은 상수를 참조하게 바꿨다. 통화 머리줄도 같은 방식(상자 44 + 간격 `md`→`sm`, 44+8 = 40+12)이다.

> 발견: `iOSTapTargetGuideline` 은 **스크롤 안에 있는 노드를 건너뛴다**(부분 스크롤 판정).
> 그래서 채팅 아바타는 가이드라인이 잡아 주지 않는다 — `profile_test.dart` 가 상자 크기를 직접 잰다.
> 통화 머리줄은 스크롤 밖이라 `layout_test.dart` 가 실제로 40pt 를 잡아냈고, 그래서 같이 고쳤다.

### 증명

`test/widget/profile_test.dart` (10건)
- 캐스트 아바타 탭 → `CharacterProfileView` 한 개, 안의 `CharacterAvatar.size == avatarHero`,
  `Hero` 한 개, 이름·호칭·매력·`♥42`·MBTI 표시, `likes`/`mines` 미표시.
- 내 MBTI 를 모르면 `CompatRow` 없음, 알려 주면 있음.
- `모르는 번호`·`엄마` 는 열리지 않음. 히든은 호감 0일 때 안 열리고 호감이 생기면 열림.
- 초상화 파일이 하나도 없어도(이니셜 원) 열림.
- 아바타 상자 44×44 · 그림 40 · `indent == avatarMd + sm` · 말풍선 좌표 `md + 48`.
- 탭 · 아래로 쓸기 · `닫기` 셋 다 닫고, 조금만 끌면 안 닫힌다.
- **320×568 · 1.3배** 라이트/다크: 넘침 0, 초상화가 화면 폭 안, `닫기` 하단 ≤ 568 · 높이 ≥ 44,
  `iOSTapTargetGuideline` · `textContrastGuideline` 통과.

---

## 4. 바뀐 파일

```
lib/ui/title_screen.dart     (새 파일)  타이틀
lib/ui/profile_view.dart     (새 파일)  프로필 크게 보기 + ProfileScope + PortraitTapTarget
lib/ui/intro_screen.dart               0단계 타이틀, 캐스트 소개, 되돌아오기, msgIn 이동
lib/ui/event_screen.dart               ProfileScope 제공(_profileFor)
lib/ui/call_view.dart                  통화 머리줄 아바타 탭 + 44 상자
lib/ui/widgets.dart                    ChatAvatarSlot 탭·44 상자, CharacterAvatar 문서·이니셜 크기
lib/ui/design_system.dart              AppSize.avatarHero = 200 (추가 4줄)
docs/DESIGN_SYSTEM.md                  §1.11 · §2.3 · §2.9 · §2.14 · §2.15(신설) · §2.16(신설) · §4.1
test/widget/title_test.dart  (새 파일)
test/widget/profile_test.dart(새 파일)
test/widget/intro_test.dart            타이틀·캐스트 단계 반영 + 320pt 흐름 검사 추가
```

`lib/main.dart` 는 **고치지 않았다**(§2 참고).

---

## 5. 검증 결과 (2026-09-26)

```
flutter analyze            → No issues found (저장소 전체)
flutter test test/widget/  → 288 passed, 2 failed
```

`test/widget/` 만 따로 돌린 숫자를 기준으로 삼는다. **저장소 전체(`flutter test`)는 이 시점에
다른 에이전트 셋이 `assets/story/*.json`·`lib/engine/`·`lib/minigames/` 를 동시에 고치고 있어
돌릴 때마다 결과가 달라진다** — 그 숫자를 이 문서의 증거로 쓰면 거짓말이 된다. 작업 시작 시점의
기준선은 `763 passed, 1 skipped, 0 failed` 였고, 그 뒤 실패한 엔진·스토리 테스트
(`deadlock_test`·`event_engine_test`·`opening_test`·`route_order_test` 등)는 전부 그쪽 작업 중간 상태다.

**위젯 실패 2건은 이 작업과 무관하다.**

| 실패 | 파일 | 성격 |
|---|---|---|
| 선택 → 결과 패널 → 계속 → 다음 이벤트/정산 | `test/widget/event_screen_test.dart` | `'큐가 비어 있으니 정산으로'` 전제가 깨짐 — 오늘 큐가 늘었다 |
| 정산 진입에 summary 큐 | `test/widget/sfx_test.dart` | 위와 같은 전제 |

확인 방법(실제로 해 봤다): `lib/ui/**` 를 `git checkout` 으로 전부 되돌리고 새 파일 둘을 지운
상태에서 같은 두 테스트를 돌리면 **같은 이유로 똑같이 실패한다**. 둘 다 `'계속'` 을 누르면 정산으로
간다는 같은 가정을 쓰는데, 스토리 데이터가 하루 큐를 늘리면서 그 가정이 깨졌다. 스토리 쪽 작업이
끝나면 저절로 풀리거나, 그 작업의 일부로 기대값을 바꿔야 한다.
`test/*.dart`(테스트 루트)는 이 작업의 소유가 아니라 손대지 않았다.

### 바꾼 기대값

기존 테스트 중 **문구·단계가 실제로 바뀌어** 고친 것은 `test/widget/intro_test.dart` 네 건뿐이다.

| 테스트 | 무엇을 바꿨나 | 왜 |
|---|---|---|
| `첫 실행은 홈이 아니라 인트로…` → `첫 프레임은 대화가 아니라 타이틀…` | 첫 프레임 기대를 알림 카드 → 타이틀로. 알림 카드·`Sfx.msgIn` 확인은 새 테스트(`타이틀의 시작하기를 누르면…`)로 분리 | 첫 프레임이 실제로 바뀐 것이 이번 작업의 요구사항이다. 소리 확인은 잃지 않았다 |
| `인트로 4탭…` → `타이틀 → … → 캐스트 소개 → 첫날` | 앞에 타이틀 탭, 뒤에 캐스트 `시작하기` 탭 추가. 캐스트가 떠 있는 동안 `hasSave == false` 를 새로 고정 | 단계가 둘 늘었다. 저장 시점이 그대로임을 더 강하게 고정했다 |
| `이름 건너뛰기…` / `두 번째 세션은 홈에서…` | 공용 헬퍼(`openIntroChat`, `startFromCast`)로 경로만 교체. 단언은 그대로 | 흐름 앞뒤가 바뀐 것뿐, 검사하려던 것은 같다 |

그 밖의 테스트는 하나도 고치지 않았다 — 레이아웃·골든 계열(`layout_test`·`scene_test`·
`event_screen_test` 의 아바타 좌표 단언 등)은 `indent` 48을 유지한 덕분에 **손대지 않고 통과한다**.

---

## 6. 미완 · 남긴 판단

1. **채팅 `AppBar` 아바타는 넣지 않았다.** DS §2.3 이 "아바타 없음" 으로 정했고 §4.1 이 테스트로 고정한다.
   진짜 메신저처럼 상단에도 두려면 DS 두 곳을 먼저 고쳐야 한다 — 표현 규격 변경이라 이번 범위 밖으로 뒀다.
   지금 눌리는 상단 아바타는 통화 머리줄이다.
2. **타이틀 전용 그림이 없다.** 지금은 `m01`(게임의 첫 삽화)을 빌려 쓴다. 나쁘지 않지만 같은 그림이
   D+1 대화 맨 위에도 한 번 더 나온다. `assets/scenes/title.webp` 를 넣으면 코드 수정 없이 그쪽이 우선한다
   (`TitleScreen.artKey`). 프롬프트는 `docs/SCENE_PROMPTS.md` S01 을 세로 여백이 넓은 구도로 바꾸면 된다.
3. **실기기 확인은 못 했다.** 위젯 테스트(320×568 · 1.3배 · 라이트/다크 · 동작 줄이기)까지가 증거다.
   Hero 비행과 켄번즈의 체감 속도는 시뮬레이터에서 한 번 눈으로 볼 값어치가 있다.
4. **프로필에 넣을 것을 더 늘릴 여지.** 지금은 "이미 본 것" 만 싣는다. 나중에 "처음 만난 날",
   "마지막으로 대화한 날" 처럼 플레이어가 겪어서 아는 사실을 더 실을 수 있다 — 엔진에 그 값이 생기면.
5. `test/widget/sfx_test.dart` · `event_screen_test.dart` 의 실패 두 건은 **스토리 데이터를 고치는 쪽이**
   기대값을 함께 봐야 한다. 이 문서 §5 의 표가 그 인수인계다.
