# 04. 코드 리뷰 — 개편 1~4단계 (78975d0 … c799c52)

- 범위: `git diff 9e5d5cc..HEAD` (12 커밋, lib 12,000 줄 중 신규·변경분). 정적 분석 `flutter analyze`: 이슈 0.
  `dart_code_metrics` 는 설정돼 있지 않아 건너뜀.
- 관점: 낯선 사람의 **첫 세션에서 죽거나 멈추거나 소리가 계속 나는 것**. 스타일은 보지 않았다.
- 검증 방법: 상위 3건은 임시 테스트(`test/_zz_review_throwaway_test.dart`, 실행 뒤 삭제)와 패키지 소스로 확인했다.
  "그럴 수도 있다" 는 쓰지 않았다 — 아래 P1 은 전부 재현 절차 또는 라인 단위 호출 순서가 붙어 있다.

## 요약 (12줄)

1. **P0 0건, P1 3건, P2 9건.** 새 코드에 즉시 크래시하는 경로는 찾지 못했다 — `!` 강제 해제는 전부 호출 조건으로 보호되고, 타이머 6개 + AnimationController 는 dispose 에서 빠짐없이 정리된다.
2. **P1-1 효과음 전체 무음 위험**: `AudioContextIOS(category: ambient, options: {mixWithOthers})` 는 audioplayers 의 assert 에 걸린다. 디버그·프로필 빌드에서는 확실히 `_ready=false`(큐 11개 전부 무음). 릴리스에서는 iOS 가 이 조합을 거부하면 같은 결과다. 한 줄 수정.
3. **P1-2 벨이 다음 이벤트까지 계속 울린다**: 전화를 거절하고 `계속` 을 누르면 `_onChange` 가 `startRing()` → 같은 틱에 `_syncEvent` 가 `stopRing()`. audioplayers 의 `stop().then(resume())` 재트리거와 경합해 플랫폼에는 `stop, stop, resume` 순으로 도착 → 루프 벨이 `_ringing=false` 상태로 계속 재생되고 `stopRing` 은 이후 no-op. 백그라운드 가거나 엔딩까지 안 꺼진다.
4. **P1-3 금칙어 오탐**: "아니 미안", "새끼손가락 걸고", "한강 간다", "역시 발이 아파", "개새벽", "전화가 꺼져 있었어", "건강 간식", "언니 미안해" 8/8 이 차단된다(테스트로 확인). 3연속이면 그 이벤트의 자유 입력이 사라진다.
5. 세이브 호환: 새 필드(`freeInputs`, `sfxOn/hapticOn`, `Line.sticker`, `Photo.image`, `StoryEvent.image`, `chapterTitles`) 는 전부 추가형·기본값 있음. 예전 세이브는 그대로 읽힌다. 단 `freeInputs` 가 List 가 아니면(자기 손상) `SaveService.load` 가 세이브를 **지운다**(기존 정책).
6. `Phase.dayStart` 미저장은 안전하다: dayStart 중 저장하는 경로(`newGame`·`endDay`·`continueGame`) 모두 `dayStarted=false` 로 쓰고, 복원은 항상 `resume` 카드로 떨어진다. 그릴 수 없는 phase 로 복원되는 경로는 없다.
7. 광고: `_showingFullScreen` 이 콜백 미도착 시 영원히 true 로 남아 그 세션의 모든 광고가 조용히 실패한다(P2). `showRewarded` 는 8초 대기 **후** 플래그를 세워 그 사이 전면 광고가 끼어들 수 있다.
8. 이미지: `cacheWidth` 는 build 안 `MediaQuery.sizeOf` 로 계산해 0 폭 가드가 있고, `errorBuilder` 는 카드를 접는다. 114장이 전부 메모리에 남는 경로는 없다(보이는 것만 디코딩, ImageCache 100MB 상한).
9. 성능: 채팅 `SingleChildScrollView+Column` 은 40 말풍선에서도 문제없다(텍스트 레이아웃은 캐시). 통화 배경 켄번즈는 `ShaderMask` 아래에서 8초간 매 프레임 saveLayer — 저사양 기기에서만 P2.
10. 분석: 파라미터 12개(Firebase 상한 25), 값은 정수·40자 절단 id·짧은 enum. 원문은 어디에도 실리지 않는다. 문제 없음.
11. 배너를 상단으로 옮기면서 `AnimatedSize` 로 본문이 66pt 내려간다 — 홈에서 `이어하기` 를 누르는 순간 로드되면 `새 게임` 을 누르게 된다(P2, 확인 다이얼로그가 있어 치명적이진 않음).
12. 회귀 테스트 5곳은 문서 끝. P1 세 건은 각각 10줄 이내 수정이다.

---

## P1 — 눈에 보이는 버그

### P1-1 · 효과음이 아예 안 난다 (디버그 확정, 릴리스 확인 필요)

`lib/audio/sfx_service.dart:142-154`

```dart
await AudioPlayer.global.setAudioContext(
  AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: const {AVAudioSessionOptions.mixWithOthers},   // ← 여기
    ),
```

`audioplayers_platform_interface-7.2.0/lib/src/api/audio_context.dart:174-184` 의 생성자 assert:

> `category == playback || playAndRecord || multiRoute || !options.contains(mixWithOthers)`
> "You can set the option `mixWithOthers` explicitly only if the audio session category is `playAndRecord`, `playback`, or `multiRoute`."

- **디버그·프로필**: `AssertionError` → `init()` 의 `catch (e)` 가 삼킴 → `_ready = false` → `onPlay` 가 즉시 return. 벨·문자음·결과음 11개 전부 무음, 로그에 `효과음 준비 실패` 한 줄만.
- **릴리스**: assert 는 사라지고 옵션이 그대로 iOS 로 간다(`AudioContext.swift:33 session.setCategory(category, options:)`). Apple 문서는 ambient 에 이 옵션을 "명시적으로 줄 수 없다" 고 한다. iOS 가 거부하면 `DarwinAudioError` → 같은 경로로 `_ready=false`. 받아 주면 릴리스만 소리가 난다.
- 실패 시나리오: 개발 중 기기 디버그 실행에서는 **절대** 소리가 나지 않으므로 소리 관련 QA 가 전부 헛돈다. 릴리스에서 거부되면 출시 앱이 무음이다.
- 최소 수정: `options` 를 비운다(ambient 는 mixWithOthers 가 암묵 포함, 무음 스위치 존중도 그대로). 그리고 `catch` 에서 `assert(false, '$e')` 로 개발 중엔 죽게 두거나 최소한 `debugPrint` 앞에 `!!!` 를 붙여 눈에 띄게 한다.

```dart
iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
```

### P1-2 · 거절한 전화의 벨이 다음 이벤트·정산까지 계속 울린다

호출 순서(전부 같은 동기 틱):

1. `_ResultPanel` `계속` → `GameController.continueAfterChoice()` → `_nextEvent()` (`game_controller.dart:1255-1274`): `lastOutcome = null`, `current = 다음 이벤트`(또는 null → summary), `notifyListeners()`.
2. `EventScreen._onChange()` (`event_screen.dart:197-207`):
   ```dart
   if (c.lastOutcome == null) {
     _picked = null;
     if (_callStage == CallStage.declined) {   // 거절 뒤 아직 declined
       _callStage = CallStage.ringing;
       _sfx.startRing();                       // ← ① 벨 시작
     }
   }
   _syncEvent();                               // ← ② id 가 바뀌었으므로 stopRing()
   ```
   `_callStage` 는 `_syncEvent` 안에서만 `active` 로 되돌아가므로(`:241`), 이 분기는 되돌리기뿐 아니라 **모든 거절 → 계속** 에서 탄다.
3. `AudioSfxService`:
   - ① `startRing()` → `_ringing = true` → `onPlay(callRing)` → `unawaited(p.stop().then((_) => p.resume()))` (`sfx_service.dart:187`)
   - ② `stopRing()` → `_ringing = false` → `unawaited(p.stop())` (`:220`)
   - audioplayers-6.8.1 `audioplayer.dart:255-279`: `stop()`·`resume()` 은 각각 `await creatingCompleter.future; await _platform.xxx(playerId)` — 직렬화 없음. ①의 `stop` 응답이 와야 `resume` 이 나가므로 플랫폼 도착 순서는 **stop(①) → stop(②) → resume(①)**. 마지막이 resume 이고 `ReleaseMode.loop` 라 벨이 무한 반복된다.
4. 이후 `stopRing()` 은 `if (!_ringing) return` (`:217`) 으로 no-op. `EventScreen.dispose()` 의 `stopRing()` 도 no-op. 정산 진입음(`summary`, P1)은 다른 소리를 안 멈춘다. 꺼지는 조건은 백그라운드(`stopAll`) 또는 엔딩(P0) 뿐.

검증: 기록용 서비스로 거절 → 다음 이벤트 notify 한 번에 `[startRing, stopRing(ringing=true)]` 가 찍히는 것을 위젯 테스트로 확인했다(같은 틱, 사이에 await 없음). 플랫폼 순서는 위 패키지 소스 기준.

최소 수정 (둘 다 권장):

- `event_screen.dart:202` 의 되돌리기 재벨 조건에 "같은 이벤트" 를 붙인다:
  ```dart
  if (_callStage == CallStage.declined && c.current?.id == _eventId) {
  ```
- `sfx_service.dart:187` 재트리거를 세대 번호로 보호해 뒤늦은 `resume` 을 버린다:
  ```dart
  final gen = ++_gen;                 // int _gen = 0; 필드
  unawaited(p.stop().then((_) {
    if (gen != _gen) return;          // 그 사이 stop/stopAll 이 왔으면 재개하지 않는다
    if (cue == Sfx.callRing && !_ringing) return;
    return p.resume();
  }));
  ```
  `stopRing`·`stopAll` 에서 `_gen++`. 같은 경합이 `cue(msgIn)` 직후 `inactive` 에도 있다(백그라운드에서 한 번 울림) — 같은 수정으로 닫힌다.

### P1-3 · 금칙어가 평범한 한국어를 막는다

`lib/engine/free_input.dart:245-256` `isBlocked` — 토큰 접두 검사 뒤에 **공백을 뺀 전체 문자열** 에 대해 2자 이상 어간을 `contains` 로 본다. 어절 경계가 사라져 이웃 낱말끼리 붙는다.

임시 테스트 결과(`isBlocked(...)` 전부 `true`):

| 입력 | 걸린 어간 | 경로 |
|---|---|---|
| 아니 미안, 내가 늦었어 | `니미` | 아**니미**안 |
| 언니 미안해 | `니미` | 언**니미**안해 |
| 새끼손가락 걸고 약속 | `새끼` | 토큰 접두 |
| 한강 간다 · 건강 간식 챙겨 | `강간` | 한**강간**다 |
| 역시 발이 아파 | `시발` | 역**시발**이 |
| 개새벽에 일어났어 | `개새` | 토큰 접두 |
| 전화가 꺼져 있었어 | `꺼져` | 토큰 접두 |

실패 시나리오: 연애 채팅에서 "아니 미안" · "새끼손가락 걸고 약속" · "한강 갈까? 아니 간다" 는 흔한 문장이다. 사용자는 "그 말은 보내지 않기로 했다" 를 보고 문장이 지워진다(`event_screen.dart:1123`). `_blockedStreak` 3회면 그 이벤트의 입력창이 사라진다(`game_controller.dart:373-376`). 분석에는 `profanity` 로 남아 지표까지 오염된다.

최소 수정:

- `free_input_lexicon.dart:164-168` `blockedPrefix` 에서 `니미`·`강간`·`시발`(→ `씨발`만 두고 `시발` 은 `^시발` 낱말 일치로)·`개새`(→ `개새끼`)·`꺼져`(→ `^꺼져`·`꺼져라`)·`새끼`(→ `^새끼`, `새끼야`) 를 낱말 일치(`blockedExact`) 또는 더 긴 어간으로 옮긴다.
- `free_input.dart:254-256` 의 compact 검사는 **띄어쓰기 변형 방지** 목적이니 3자 이상 어간만 보거나, 토큰 안에서 공백을 하나만 허용하는 정규식으로 좁힌다.
- 픽스처에 위 8문장을 "통과" 로, `씨 발`·`ㅅㅂ`·`병신아` 를 "차단" 으로 추가한다.

---

## P2 — 잠복 버그·성능

### P2-1 · `_showingFullScreen` 이 영원히 true

`lib/ads/ad_manager.dart:353-379, 421-451`. `onAdDismissedFullScreenContent`/`onAdFailedToShowFullScreenContent` 둘 다 안 오면(SDK 내부 오류, 사용자가 광고 도중 앱을 죽였다 살린 경우 콜백 유실) 플래그가 남고 `done` 도 완료되지 않는다. 이후 `showRewarded`/`showInterstitial` 은 `:417`/`:344` 에서 즉시 false → 그 세션 내내 광고 없음, `_skipWait` 는 첫 호출이 영원히 await 상태로 남는다(카운트다운은 `:487` 에서 이미 취소돼 멈춘 채, 버튼을 다시 누르면 false 를 받아 `:496` 으로 재개되니 갇히지는 않는다).

최소 수정: `_showingFullScreen = true` 를 세울 때 `DateTime` 을 같이 기록하고, `didChangeAppLifecycleState(resumed)`(`:257`) 와 두 `show*` 진입부에서 2분 이상 지났으면 강제로 false 로 되돌린다. `done.future.timeout(Duration(minutes: 2), onTimeout: () => false)` 도 함께.

### P2-2 · 리워드 대기 8초 사이에 전면 광고가 끼어든다

`showRewarded` (`:416-418`) 는 `_awaitRewarded()`(최대 8초) 를 **await 한 뒤** `:438` 에서 플래그를 세운다. 그 사이 `showInterstitial` 이 `:344` 검사를 통과한다. 두 광고가 겹치면 GMA 가 두 번째를 `onAdFailedToShowFullScreenContent` 로 거절하니 크래시는 아니지만, 사용자는 "광고를 봤는데 보상이 없다" 를 겪는다. 플래그를 `_awaitRewarded` 전에 세우고 실패 경로에서 내리면 된다. 덤: `:439` `ad_rewarded_shown` 이 `show()` 전에 찍혀 표시 실패도 "노출" 로 센다.

### P2-3 · 출석 하트가 저장되지 않는 창

`lib/game_controller.dart:1062-1064, 1077` (이 구간은 이전 커밋부터 있었다):

```dart
if (pendingHearts > 0) await _applyPendingHearts(s);   // meta.pendingHearts 를 깎고 meta 저장
...
if (pendingHearts > 0) await _save(s);                   // 남은 보류분이 있을 때만 세이브
```

`_applyPendingHearts` 가 전부 소진하면(보통) 두 번째 조건이 false 라 `s` 의 새 하트는 저장되지 않는다. 메타는 이미 깎였다. 날짜 카드(1초) + 행동 화면에서 룰렛/행동 전에 앱이 죽으면 하트가 사라진다. `dayStarted` 분기(`:1065-1073`)도 저장이 없다. 조건을 `granted > 0` 으로 바꾸거나 무조건 `_save(s)`.

### P2-4 · 손상된 `freeInputs` 타입이 세이브 전체를 지운다

`lib/engine/models.dart:1367-1370` `(j['freeInputs'] as List?)` — List 가 아니면 `TypeError` → `SaveService.load` `catch` → `p.remove(_key)` (`save_service.dart:22-26`). 임시 테스트로 확인. 항목 단위는 `FreeInputEntry.fromJson` 이 관대하다(double index·null·문자열 항목 전부 건너뜀, 확인). 앱이 스스로 쓰는 값이라 확률은 낮지만, 새 필드 하나 때문에 회차를 잃는 건 비대칭이다. `j['freeInputs'] is List ? ... : const []` 로.

### P2-5 · 미니게임 뒤 `mounted` 없이 진행

`lib/ui/event_screen.dart:1071-1085` `_ChoicePanelState._pick`: `await playMinigame(...)` 뒤 `widget.onPicked` · `c.choose(index)` 를 `mounted` 검사 없이 부른다. 같은 파일 `_confirm` (`:1165`) 은 검사한다. 미니게임 도중 이벤트가 바뀔 경로는 지금 없지만(`_ChoicePanel` 은 `ValueKey('choices-${ev.id}')`), 캡처한 `ev`·`index` 로 `c.choose` 가 **다른 이벤트에** 적용될 수 있는 형태라 `_confirm` 과 같게 맞춘다.

### P2-6 · 통화 배경 켄번즈 비용

`lib/ui/call_view.dart:_CallScenery` — `ShaderMask(dstIn)` → `Opacity(0.7)` → `SceneImage(kenBurns: true)`. `TweenAnimationBuilder` 가 8초 동안 매 프레임 `Transform.scale` 을 바꾸고, 그 위의 `ShaderMask`+`Opacity` 는 각각 saveLayer 라 화면 55% 높이 영역이 60fps 로 두 번 합성된다. 통화는 1초 타이머 `setState` 까지 겹친다. iPhone SE 급에서 통화 화면 첫 8초가 뜨거워지는 원인이 될 수 있다. `RepaintBoundary` 로 켄번즈 서브트리를 감싸고 `Opacity` 대신 `ColorFiltered`/이미지 `color` 블렌드로 레이어 하나를 줄인다.

### P2-7 · 같은 그림을 폭별로 세 번 디코딩

`SceneImage` 는 `cacheWidth = 레이아웃 폭 × DPR` 로 `ResizeImage` 키를 만든다. 같은 장면이 채팅 카드(폭−32), 크게 보기(폭−48), 통화 배경(폭) 세 폭으로 각각 디코딩돼 캐시에 세 벌 남는다(390pt·3x 기준 한 벌 ≈ 3.6MB). 상한(100MB) 안이라 사고는 아니지만, `cacheWidth` 를 화면 폭 기준 하나로 통일하면 캐시 적중이 올라간다.

### P2-8 · 상단 배너 로드 시 레이아웃 시프트

`lib/ui/widgets.dart:784-797` `BannerSlot` 이 `AnimatedSize` 로 0 → 66pt 로 열리며 홈·설정 본문 전체가 내려간다. 홈에서 `이어하기`(`home_screen.dart`) 바로 아래가 `새 게임` 이라, 로드 순간에 탭하면 다른 버튼이 눌린다. 새 게임은 확인 다이얼로그가 있어 회차 손실은 없지만 AdMob "우발적 클릭" 관점에서도 좋지 않다. 배너 자리를 미리 확보(`SizedBox(height: 50+…)`)하거나 첫 프레임 후 300ms 안에 로드되지 않으면 그 화면에서는 붙이지 않는다.

### P2-9 · 복원 진입도 "처음 보는 이벤트" 로 판정

`event_screen.dart:245` `fresh = revealed == 0 && lastOutcome == null` — `continueGame` 으로 복원한 현재 이벤트도 `revealed == 0` 이라 알림 카드·벨이 다시 나온다. 주석("복원·디버그 진입은 건너뜀")과 다르다. 전화라면 오히려 자연스럽고, 문자 알림도 해가 없어 동작 변경은 권하지 않고 주석만 고친다. 다만 `didChangeAppLifecycleState(resumed)` 재벨(`:168-173`)과 합쳐 "복원 → 벨 → 홈 → 복귀 → 벨" 이 되니 의도한 게 맞는지만 확인.

---

## 확인했고 문제없는 것 (사냥 목록 대응)

- **타이머·컨트롤러 정리**: `EventScreen` 5개 타이머(`_timer`·`_replyTimer`·`_readTimer`·`_callTimer`·`_previewTimer`) 전부 `dispose` 취소, 리스너·옵저버 제거(`:184-195`). `_ChoicePanel._lockTimer`·`FocusNode`·`TextEditingController` 정리(`:1052-1058`). `DayTransitionScreen` `_c.dispose()`. `_Entrance`·`BannerSlot`(`_retry`·`_ad`) 정리. `AudioSfxService` 타이머 4개는 `stopAll`/`_stopRingHaptics` 에서 정리. 모든 타이머 콜백이 `mounted` 를 본다.
- **setState after dispose**: `SceneCard.onFailed` 는 `mounted` 검사 뒤 `setState`, `errorBuilder` 는 post-frame 으로 미룬다. 시트 `await` 뒤 `mounted` 검사 있음(`:1200`·`:1218`·`:1248`). 광고 뒤 `context.mounted` 있음.
- **null-safety**: `chooseFree`·`confirmFree`·`undoFree` 의 `current!` 는 패널이 `linesDone`(⇒ current≠null) 일 때만 존재. `_ResultPanel` 의 `lastOutcome!` 는 `o != null` 분기 안. `_dayCardFor` 의 `state!` 는 세 호출처 모두 state 를 방금 세팅. `dayCard ??` 폴백은 상태만으로 카드를 만들고 `day` 가 0·음수여도 `(day-1) % 7` 이 Dart 에서 음수가 되지 않는다.
- **dayStart 멱등**: `beginMorning` 은 `phase != dayStart` 면 return. 탭(`_c.value = upperBound`)과 자연 완료가 같은 status 리스너를 타고, 두 번째 호출은 no-op. 상태 리스너 안 `notifyListeners` 는 빌드 중이 아니라 안전.
- **세이브 왕복**: `FreeInputEntry` `a: 1/0` ↔ `== 1 || == true`, `i`·`d` 는 `num` 허용, `PlayerMeta` `sfxOn/hapticOn` 은 `!= false`(없음·비bool → 켬), `chapterTitles` 는 `'$v'`. 예전 세이브에 없는 키는 전부 기본값.
- **자유 입력 경계**: 선택지 1~2개 → 점수·피커 정상. 전부 잠김 → `decide` 가 `locked`(`top` 보장) 또는 피커에서 전부 비활성 + `다시 쓰기`. 통화 중 → `decline` 후보 제외 + `hangUp` 시트. 미니게임 선택지 → `confirm` 시트 → 게임 → `auto=false`. 5회 상한·3연속 차단은 `_resetFreeInput` 이 이벤트마다 비우고 패널은 이벤트별 키라 잠금이 새지 않는다.
- **분석**: 이벤트 5개, 파라미터 최대 12개(상한 25), 값은 정수/`_id` 40자 절단/짧은 enum, user property 이름 14자(상한 24). 원문·이름 없음.
- **오디오 시작 비용**: `init()` 은 `unawaited` 로 스토리 로드와 병렬, `runApp` 을 막지 않는다. 11개 플레이어 생성 + 864KB 에셋 복사는 첫 프레임과 무관.
- **`inactive` → `stopAll` → `resumed` 재벨**: 5분 뒤 복귀해도 `_ringing` 이 false 라 `startRing` 이 정상 동작, 진동 20초 제한도 새로 시작. 진동 두 박자 600ms 간격은 iOS `vibrate`(~400ms) 와 겹치지 않는다.

---

## 회귀 테스트를 넣을 5곳

1. **`test/free_input_test.dart` — 금칙어 코퍼스**: 위 8문장이 `isBlocked == false`, `씨 발`·`ㅅㅂ`·`병신아`·`씨발놈아` 가 `true`. 사전을 만질 때마다 돈다.
2. **`test/widget/sfx_test.dart` — 거절 → 계속 → 다음 이벤트**: `RecordingSfxService` 에 호출 순서 로그를 추가하고, 이벤트가 바뀐 notify 한 번에 `startRing` 이 **나오지 않음** 을 단언(지금은 `[startRing, stopRing]`).
3. **`test/sfx_service_test.dart` — `AudioSfxService` 채널 모킹**: `xyz.luanpotter/audioplayers` MethodChannel 을 `TestDefaultBinaryMessengerBinding` 으로 가로채 `startRing(); stopRing();` 뒤 마지막 플랫폼 호출이 `stop` 인지(=`resume` 이 뒤따르지 않는지) 단언. 같은 테스트에서 `init()` 이 `효과음 준비 실패` 없이 `_ready` 가 되는지(= `AudioContextIOS` assert 통과) 본다 — 이것이 P1-1 의 회귀 방지선이다.
4. **`test/save_migration_test.dart` — 손상 타입**: `freeInputs: "x"`, `freeInputs: {}`, `sfxOn: "yes"`, `chapterTitles: 3` 을 넣은 JSON 이 세이브를 지우지 않고 기본값으로 읽히는지(P2-4 수정 뒤). 그리고 `continueGame` 이 `dayStarted=false` 세이브에서 `Phase.dayStart` 로, `beginMorning` 두 번 뒤 `action` 이 정확히 한 번 나오는지.
5. **`test/widget/event_screen_test.dart` — 광고 대기 중 이벤트 불변**: `_skipWait` 가 광고를 기다리는 동안(가짜 AdManager 로 8초 지연) 카운트다운이 멈춰 있고, 실패로 돌아오면 같은 초부터 재개되는지. `_showingFullScreen` 타임아웃(P2-1) 을 넣으면 그 뒤 두 번째 `showRewarded` 가 false 가 아니라 실제 시도인지도.

---

## 결론

새 코드는 구조적으로 잘 지켜졌다 — 특히 서비스 추상화(`SfxService` 기본 Noop)와 이벤트별 패널 키, `mounted` 규율은 첫 세션 크래시를 잘 막고 있다. 출시 전 반드시 고칠 것은 P1 세 건이고 전부 국소 수정이다. P1-1 은 **릴리스 TestFlight 기기에서 문자 도착음이 실제로 나는지** 한 번 확인하면 심각도가 정해진다(나지 않으면 P0 급 사용자 경험 결함). P1-2 는 QA 에서 "전화 거절 → 계속" 한 번이면 재현된다.
