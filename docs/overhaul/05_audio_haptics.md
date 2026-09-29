# 05. 사운드·햅틱 명세 — "문자·전화가 오면 소리와 진동"

> 2026-09-23. OVERHAUL_PLAN.md §0-C, §2C 의 확정본. 대상: iOS(iPhone) 먼저, Android 는 같은 API 로 뒤따름.
> 현재 코드에는 오디오·햅틱 코드와 패키지가 전혀 없다(pubspec 확인). 이 문서는 구현 전 명세이며 코드는 건드리지 않았다.
> 톤 세 단어: **가볍다 · 진짜 같다 · 짧다**. 카톡·아이폰 UI 소리가 주는 기대치(짧고, 밝고, 낮은 음량) 아래에 둔다.

## 1. 큐 목록 (12개)

우선순위: P0 = 다른 소리를 멈추고 단독 재생, P1 = 일반, P2 = 잔소리(P0 재생 중엔 건너뜀). 진동은 내장 `HapticFeedback` 기준(§2).

| # | 큐 id | 상황 | 트리거 지점 (파일 · 위젯/메서드) | 길이 | 반복 | 우선 | 진동 |
|---|---|---|---|---|---|---|---|
| 1 | `msg_in` | 문자 도착(알림 카드) | `event_screen.dart` `_EventScreenState._syncEvent` 에서 `_previewOpen = true` 로 세우는 분기. 동작 줄이기로 카드가 생략돼도 소리·진동은 낸다 | 0.4s | 없음 | P1 | `mediumImpact` 1회 |
| 2 | `call_ring` | 전화 벨 | `_syncEvent` 에서 `_callStage = CallStage.ringing` 세울 때 시작. `_onChange` 의 declined→ringing 복귀(되돌리기 광고)에도 시작. 정지: `_acceptCall`, `_declineCall`, `_syncEvent` 가 다른 이벤트로 넘어갈 때, `dispose`, 앱 백그라운드 | 3.0s 루프 파일 | 받거나 거절할 때까지 | P0 | 벨 케이던스 루프(§2.3) |
| 3 | `call_connect` | 전화 받음 | `_acceptCall()` 첫 줄 | 0.2s | 없음 | P1 | `lightImpact` |
| 4 | `call_end` | 통화 종료·거절 | `_declineCall()`; `_startCallClock` 의 `_callEnded` 분기(`t.cancel()` 직후) | 0.5s | 없음 | P1 | `mediumImpact` |
| 5 | `bubble_in` | 상대 말풍선 등장 | `_scheduleReveal` 의 타이머 콜백(타이핑 → 줄 공개); `_syncReply` 의 `_replyTimer` 콜백. 250ms 안에 연속되면 한 번만 | 0.12s | 없음 | P2 | 없음 |
| 6 | `bubble_out` | 내 말 전송 | `_ChoicePanel._pick` 의 `onPicked(...)` 직전 | 0.12s | 없음 | P2 | `selectionClick` |
| 7 | `wait_read` | 읽씹 대기 끝(읽음) | `_finishWait()` 첫 줄 | 0.3s | 없음 | P2 | `lightImpact` |
| 8 | `choice_ok` | 선택 성공 결과 패널 | `_onChange` 에서 `c.lastOutcome` 이 null→값 으로 바뀐 순간, `success == true` | 0.6s | 없음 | P1 | `mediumImpact` |
| 9 | `choice_fail` | 선택 실패 결과 패널 | 위와 같음, `success == false` | 0.6s | 없음 | P1 | `heavyImpact` |
| 10 | `summary` | 정산 카드 등장 | `main.dart` 의 Phase 전환(`Phase.summary` 진입). `SummaryScreen` 은 Stateless 이므로 화면이 아니라 컨트롤러 phase 변화를 듣는 `SfxService.onPhase` 한 곳에서 처리 | 0.8s | 없음 | P1 | `lightImpact` |
| 11 | `ending` | 엔딩 화면 | 같은 자리, `Phase.ending` 진입. 다른 소리 전부 정지 | 2.5s | 없음 | P0 | `heavyImpact` → 120ms → `lightImpact` |
| 12 | `day_start` | 날짜 전환 전체화면(§2B 신설) | 신설 `DayTransitionScreen.initState` | 0.7s | 없음 | P1 | `lightImpact` |

제외한 것: 미니게임 효과음, 버튼 탭음(iOS 기본 UI 관성상 무음), 배경음악(없음. 채팅 시뮬은 침묵이 리얼함).
동시성 규칙: 큐당 플레이어 1개, 같은 큐 재트리거는 처음부터 다시(`stop → resume`). P0 재생 중 P2 는 버린다.

## 2. 패키지 결정

### 2.1 효과음 재생 — `audioplayers` 채택

| 패키지 | 2026-09 상태(pub.dev) | iOS 짧은 효과음에 대한 평가 |
|---|---|---|
| **audioplayers** 6.8.1 | blue-fire 검증 퍼블리셔, 2개월 전 갱신, 150pt | `AudioContextIOS(category: ambient, options: {mixWithOthers})` 한 줄로 **무음 스위치 존중 + 사용자 음악과 섞임**. 플레이어를 미리 만들어 `setSource` 로 프리로드하면 `resume()` 지연 ≈ 10–30ms. 짧은 파일 여러 개 병렬 재생에 맞음 |
| just_audio 0.10.6 | ryanheise 검증, 활발 | 스트리밍·플레이리스트 지향. 세션 카테고리는 `audio_session` 을 따로 붙여야 하고 플레이어 하나가 AVPlayer 하나라 12개 큐면 무겁다. 배경음악이 생기면 그때 검토 |
| flame_audio 2.12.2 | flame-engine 검증 | 내부가 audioplayers. Flame 의존만 늘고 얻는 것 없음 |
| soundpool 2.4.1 | **discontinued**(3년 전) | 저지연 목적엔 이상적이었으나 유지 중단. 불가 |

결정 근거: (1) 지연 — 프리로드 방식으로 충분(카톡도 ~50ms 급). (2) 무음 스위치 — ambient 카테고리를 패키지 API 로 지원. (3) 인터럽션 — 실제 전화가 오면 iOS 가 세션을 중단시키고 플레이어가 멈춘다. 우리는 이에 더해 `AppLifecycleState.inactive/paused` 에서 `stopAll()` 을 호출해 벨 루프·진동 타이머를 끊고, `resumed` 에서 EventScreen 의 상태(`_callStage == ringing`)를 보고 벨만 다시 건다. 백그라운드 재생은 하지 않는다(`UIBackgroundModes` 에 audio 를 넣지 않는다 — 게임 벨이 잠금화면에서 울리면 심사·사용자 모두 싫어한다). (4) 건강도 — 다운로드·갱신 빈도 모두 최상위.

설정 호출(앱 시작 1회):
```dart
await AudioPlayer.global.setAudioContext(AudioContext(
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient,
      options: const {AVAudioSessionOptions.mixWithOthers}),
  android: const AudioContextAndroid(usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification, audioFocus: AndroidAudioFocus.none),
));
```
`ambient` 는 무음 스위치가 켜지면 소리가 안 난다 — 이것이 의도. 스위치를 무시하는 `playback` 카테고리는 쓰지 않는다(§4 주의와 동일).

### 2.2 진동 — 내장 `HapticFeedback` 채택

| 후보 | 상태 | 판단 |
|---|---|---|
| **`HapticFeedback`(flutter/services)** | 내장 | iOS 매핑: `lightImpact/mediumImpact/heavyImpact` → UIImpactFeedbackGenerator, `selectionClick` → UISelectionFeedbackGenerator, `vibrate` → `kSystemSoundID_Vibrate`(약 0.4–0.5s 의 실제 모터 진동). 의존성 0, 테스트 스텁 쉬움. **채택** |
| vibration 3.2.1 | 미검증 업로더, 활발 | `pattern`/`intensities` 가 Core Haptics 기기에서 동작. 지속시간·패턴 제어가 필요해지면(Android 대응 때) 검토. 지금은 보류 |
| haptic_feedback 0.6.5 | 검증 퍼블리셔 | `success/warning/error/rigid/soft` 추가. 내장으로 부족할 때만 |

Core Haptics 제약: Flutter 내장 API 로는 임의 파형(AHAP)을 못 만든다. 벨 케이던스는 Dart 타이머로 `vibrate()` 를 반복해 만든다. `vibrate()` 는 한 번 호출당 길이가 고정(≈0.45s)이고 겹쳐 호출하면 무시되므로 간격을 500ms 이상 둔다.

### 2.3 벨 케이던스 (iOS)

아이폰 기본 벨 진동 느낌(두 번 울리고 쉼)을 흉내 낸다. 한 주기 2.6s, 벨 파일 루프(3.0s)와 굳이 맞추지 않는다 — 실제 전화도 소리와 진동이 어긋난다.
```dart
// t=0 vibrate, t=600ms vibrate, t=2600ms 다시 시작. 받기·거절·dispose·백그라운드에서 cancel.
_ringTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
  HapticFeedback.vibrate();
  Timer(const Duration(milliseconds: 600), HapticFeedback.vibrate);
});
```
첫 주기는 `Timer.periodic` 이 한 주기 뒤에 시작하므로 시작 시 한 번 직접 실행한다. `msg_in` 은 `mediumImpact` 한 번(진짜 문자는 짧게 한 번 "툭").

## 3. 에셋 계획

- **폴더·이름**: `assets/sfx/<큐 id>.<ext>` (`msg_in.wav`, `call_ring.m4a` …). pubspec 에 `- assets/sfx/` 추가. 큐 id 와 파일명은 1:1, 코드에는 `Sfx.msgIn` 같은 enum 만 두고 경로는 서비스 안에서만 만든다.
- **포맷**: `.ogg` 는 iOS AVFoundation 이 재생 못 한다 — **쓰지 않는다**. 0.5초 이하 큐(`bubble_*`, `wait_read`, `call_connect`, `msg_in`)는 **WAV 16-bit 44.1kHz mono** (디코드 지연 0, 합계 < 300KB). 그 외(`call_ring`, `choice_*`, `summary`, `ending`, `day_start`)는 **AAC .m4a 44.1kHz mono 96kbps**. `.caf` 는 iOS 전용이라 Android 를 생각해 배제.
- **루프 파일**: `call_ring.m4a` 는 AAC 인코더 지연(priming) 때문에 루프 경계에 틈이 생긴다. 벨은 3.0s 안에 "따르릉—쉼" 이 끝나고 무음으로 시작·끝나게 만들어 틈이 안 들리게 한다. 안 되면 벨만 WAV 로.
- **라우드니스**: 통합 라우드니스 `call_ring`/`ending` **-16 LUFS**, P1 큐 **-18 LUFS**, P2 큐(`bubble_*`, `wait_read`) **-23 LUFS**, 전부 **True Peak ≤ -1 dBTP**. 카톡 알림음보다 살짝 아래를 노린다. 코드 볼륨은 1.0 고정(파일에서 맞춘다). 검수: `ffmpeg -i f -af ebur128 -f null -`.
- **출처 (상업 사용 가능, 크레딧 불필요)**:
  1. **freesound.org** — 검색에서 라이선스 필터 `Creative Commons 0` 만. 다운로드 페이지 URL·작성자·날짜를 기록.
  2. **Kenney.nl** — "UI Audio", "Interface Sounds" 팩, CC0. 말풍선·확정음 후보.
  3. **Pixabay** (Sound Effects) — Pixabay Content License: 상업 사용·수정 가능, 크레딧 불필요. 단 **원본 그대로 재배포 금지** → 앱 안에서 큐로 쓰는 건 가능, 소스 저장소 공개 시 주의.
  4. **OpenGameArt.org** — 라이선스 필터 CC0 만. (CC-BY 는 크레딧 의무가 생기므로 이번엔 제외.)
  벨·엔딩처럼 정체성이 걸린 소리는 DAW 로 직접 만드는 것(사인파 2음 벨 등)이 가장 안전하다.
- **라이선스 파일**: `assets/sfx/LICENSES.md` — 파일명 · 출처 URL · 작성자 · 라이선스 · 받은 날짜 · 가공 여부. Pretendard 처럼 pubspec 에 에셋으로 넣고 설정 > 정보 > 라이선스 화면에서 보여 준다. 기록 없는 파일은 커밋하지 않는다.
- **절대 쓰지 말 것**: Apple 시스템 사운드(Tri-tone, Opening, Reflection, Marimba 등 iOS 벨·알림음, `/System/Library/Audio` 추출본), 카카오톡 알림음("카톡", "카카오톡" 음성 포함)과 그 유사 편곡, 삼성·LINE 등 다른 메신저의 알림음, "royalty-free" 라고만 적힌 출처 불명 파일. 상표·저작권 양쪽 문제이며 심사 거절 사유가 된다.

## 4. `SfxService` API 스케치

설정은 `PlayerMeta` 에 `sfxOn`, `hapticOn`(둘 다 기본 true) 필드를 **추가만** 하고 `settings_screen.dart` 「게임」 섹션에 `SwitchListTile` 두 개(`Key('settings-sfx')`, `Key('settings-haptic')`)를 둔다. 세이브 호환은 `save_migration_test.dart` 규칙 그대로.

```dart
enum Sfx { msgIn, callRing, callConnect, callEnd, bubbleIn, bubbleOut,
  waitRead, choiceOk, choiceFail, summary, ending, dayStart }
enum Haptic { light, medium, heavy, selection, buzz }

/// 효과음·진동의 유일한 입구. UI 는 이 API 만 부르고 패키지를 직접 만지지 않는다.
abstract class SfxService {
  static SfxService instance = NoopSfxService(); // 테스트 기본값. main() 에서 교체.
  bool sfxOn = true, hapticOn = true;            // PlayerMeta 에서 읽어 채움
  Future<void> preload();                        // 앱 시작: 세션 카테고리 + 12개 플레이어 setSource
  void play(Sfx cue);                            // 처음부터 재생. P0 중이면 P2 는 무시
  void loop(Sfx cue);                            // callRing 전용. 이미 돌면 무시
  void stop(Sfx cue);
  void stopAll();                                // 백그라운드·엔딩·dispose
  void haptic(Haptic h);                         // hapticOn 이 false 면 no-op
  void ringHaptics(bool on);                     // §2.3 케이던스 타이머 on/off
  void onLifecycle(AppLifecycleState s);         // inactive/paused → stopAll + ringHaptics(false)
}

class AudioplayersSfxService extends SfxService with WidgetsBindingObserver {
  final _players = <Sfx, AudioPlayer>{};
  Timer? _ring;
  @override Future<void> preload() async {
    await AudioPlayer.global.setAudioContext(/* §2.1 */);
    for (final c in Sfx.values) {
      final p = AudioPlayer()..setReleaseMode(c == Sfx.callRing ? ReleaseMode.loop : ReleaseMode.stop);
      await p.setSource(AssetSource('sfx/${c.file}'));   // 무음 스위치는 세션이 처리, 코드에서 따로 안 본다
      _players[c] = p;
    }
    WidgetsBinding.instance.addObserver(this);
  }
  @override void play(Sfx c) { if (!sfxOn) return; final p = _players[c]!; p.stop(); p.resume(); }
  @override void haptic(Haptic h) { if (!hapticOn) return; switch (h) {
    case Haptic.light: HapticFeedback.lightImpact(); case Haptic.medium: HapticFeedback.mediumImpact();
    case Haptic.heavy: HapticFeedback.heavyImpact(); case Haptic.selection: HapticFeedback.selectionClick();
    case Haptic.buzz: HapticFeedback.vibrate(); } }
  // loop/stop/stopAll/ringHaptics/onLifecycle 은 §1·§2.3 규칙대로. 생략.
}
```

호출 예: `_acceptCall()` → `SfxService.instance..stop(Sfx.callRing)..ringHaptics(false)..play(Sfx.callConnect)..haptic(Haptic.light)`.

**위젯 테스트 스텁**: `SfxService.instance` 는 기본이 `NoopSfxService` 라 기존 테스트는 손대지 않아도 된다(audioplayers 채널을 안 건드리니 `MissingPluginException` 없음). 큐가 나갔는지 검증할 때는 `test/widget/helpers.dart` 에 `RecordingSfxService`(`List<Sfx> played`, `List<Haptic> haptics`)를 두고 `setUp` 에서 `SfxService.instance = RecordingSfxService()`, `tearDown` 에서 Noop 으로 복구. 검증 예: 전화 이벤트를 열면 `played` 에 `callRing` 이 있고 받기 버튼 후 `callConnect` 가 뒤따른다; 되돌리기 후 다시 `callRing`. `HapticFeedback` 은 `SystemChannels.platform` 을 타므로 스텁 없이도 테스트에서 조용히 무시된다.

## 5. 실기기 QA 체크리스트 (iPhone)

- [ ] **무음 스위치 ON**: 문자·전화 모두 소리 없음, 진동은 남음. 스위치 OFF 로 바꾸면 다음 큐부터 바로 소리.
- [ ] **효과음 OFF·진동 ON** / **효과음 ON·진동 OFF** / 둘 다 OFF: 설정 토글이 앱 재시작 후에도 유지.
- [ ] **접근성 > 진동 끄기**(시스템): 앱은 정상, 진동만 사라짐. 크래시·예외 없음.
- [ ] **음악 재생 중(Apple Music/Spotify)**: 앱을 열어도 음악이 안 끊기고 효과음이 위에 섞인다. 벨 루프 중에도 음악 유지.
- [ ] **Bluetooth 이어폰/스피커**: 큐가 BT 로 나가고 지연이 체감 200ms 이내. 연결 해제 시 다음 큐가 내장 스피커로 돌아옴, 벨 루프 끊김 없음.
- [ ] **실제 전화 수신(벨 울리는 도중)**: 게임 벨·진동 즉시 정지. 통화 거절/종료 후 복귀하면 게임 벨이 **다시** 울린다(받기 전 상태 유지).
- [ ] **실제 전화 수신(일반 대화 중)**: 복귀 후 큐가 정상. 무음 상태로 남지 않음(세션 재활성).
- [ ] **홈으로 나가기/앱 전환**: 벨·진동 즉시 정지, 잠금화면·백그라운드에서 절대 안 울림. 복귀하면 벨 재개.
- [ ] **되돌리기 광고**: 거절 → 리워드 광고 → 복귀 시 벨 재시작. 광고 재생 중엔 우리 소리 0.
- [ ] **전면 광고 전후**: 광고 소리가 끝난 뒤 큐가 정상 볼륨. 광고 SDK 가 세션 카테고리를 바꿔 놓았으면 `resumed` 에서 `setAudioContext` 재호출.
- [ ] **연타**: 선택지 빠르게 누르기, 말풍선 연속 공개 — 소리 겹침·잘림 없음, 프레임 드랍 없음(Xcode Instruments 로 오디오 스레드 확인).
- [ ] **오래 방치**: 벨을 5분 울려도 진동 타이머·메모리 누수 없음(Instruments Leaks).
- [ ] **저전력 모드 / 집중 모드**: 큐 정상(집중 모드는 앱 내부 소리에 영향 없음을 확인).
- [ ] **볼륨 0 + 무음 스위치 OFF**: 소리 없음, 진동 유지. 볼륨 버튼으로 올리면 즉시 반영.
- [ ] **동작 줄이기 ON**: 알림 카드가 생략돼도 `msg_in` 소리·진동은 난다(§1 #1).
