# 몰입 개편 계획 — "게임이지만 실제 같아야 한다"

> 2026-09-23 작성. TestFlight 첫 테스트 피드백에서 출발. 목표는 App Store 게임 랭킹 Top 10 진입이지만,
> 이 문서는 그 전제조건인 **몰입 개편**만 다룬다. ASO·마케팅은 별도(STORE_LISTING.md, LAUNCH_GUIDE.md).
> 진행은 agency-agents 로 한다(§5). 기준 문서: DESIGN_SYSTEM.md, ROADMAP.md, CAST_BIBLE.md.

## 0. 테스트 피드백 원문 → 항목

| # | 피드백 | 항목 | 결정 |
|---|---|---|---|
| A | 카톡처럼 이름 왼쪽에 그 사람 이미지, 상단은 이름만 | 채팅 UI | 한다 |
| B | 날짜가 바뀌면 전체화면으로 "2일째 / Day 2" | 날짜 전환 | 한다 |
| C | 문자·전화가 오면 효과음, 필요하면 실제 진동 | 사운드·햅틱 | 한다 |
| D | 텍스트만 나와서 집중이 안 됨 → 이미지·GIF | 장면 삽화 | 코드 슬롯 + 프롬프트 문서. **그림은 사용자가 생성** |
| E | 배너를 상단에 | 광고 배치 | 한다(채팅 화면 제외, 정책) |
| F | 채팅으로 직접 입력해 스토리 잇기 | 자유 입력 | **제한형**: LLM 없이 입력 → 의도 매핑 → 기존 선택지 |
| G | 벤치마킹: AI 채팅 앱, 프린세스 메이커 | 연구 | 설계 단계에서 |

## 1. 현재 코드 기준 (2026-09-23)

- 채팅: `lib/ui/event_screen.dart`. AppBar 에 `CharacterAvatar` + 이름 + 이벤트 제목. 말풍선은 `_speakerKey` 로 같은 화자를 묶지만 아바타 없음.
- 날짜: `GameController.startDay` → `Phase.event`/`Phase.summary`. 정산(`summary_screen.dart`) → 행동(`action_screen.dart`) 사이에 전환 화면 없음.
- 사운드·햅틱: 코드·패키지 모두 없음. 오디오 관련 import 0.
- 이미지: `assets/portraits/<id>.jpg` 12장, `PortraitRegistry` 로 있으면 쓰고 없으면 이니셜. 장면 삽화 슬롯 없음.
- 배너: `BannerSlot` 이 홈·행동·정산·앨범·설정의 `bottomNavigationBar`. 채팅 화면엔 없음(선택지 옆 배너 = AdMob 우발 클릭 정책 위반, `ad_manager.dart` 주석).
- 선택지: 이벤트당 3개 고정, `require`/`chance`/`minigame`.

## 2. 항목별 확정 설계 (2026-09-23 연구 단계 종료)

세부는 `docs/overhaul/01~07` 에 있고, 여기는 **확정본과 문서 간 충돌의 결정**만 적는다.
충돌 결정: Day 카드는 02 방식(`Phase.dayStart`), 타이핑은 04 방식(반복 깜빡임 없음, "쓰다 지움" 1회), 시계는 02 방식(이벤트 시간대), 효과음은 05 목록에서 `bubble_in` 제외.

### A. 채팅 UI (카톡형) — `03_chat_ui_spec.md` §1·§2, `04` #3·#4·#5·#7·#16
- 상대 줄 3열: `CharacterAvatar(AppSize.avatarMd=40)`(묶음 첫 줄만, 이후는 같은 폭 빈 칸) → `sm` → 이름(`labelSmall` 강조색, 색 점 제거)+말풍선 → `xs` → 메타(시각·읽음). 내 줄은 반전, 아바타 없음.
- 아바타 id: `Line.name` → 캐스트 id 역산(`_speakerIdFor`), NPC 는 이니셜(중립색), `'모르는 번호'` 는 실루엣.
- AppBar: 이름 `titleLarge` + 상태 `labelSmall`(`온라인`/`자리 비움`/`부재중`/`온라인 · N명`). 아바타·제목·D+N pill 제거. 제목은 대화 첫 항목 `ChatDivider('D+N · 제목')`.
- 메타 열: 시각은 묶음 마지막 말풍선 옆 `오후 4:12`(02 P1 시간대: 이벤트 i 에 09/12/16/21 슬롯 + 줄당 1분 + wait), `읽음` 은 낱말만(숫자 배지 금지) — 보낸 뒤 500ms(실패 톤 1500ms) 뒤 표시 → 그 뒤 타이핑.
- 타이핑: `_TypingBubble` 에 화자 아바타 추가, `Text('…')` 한 개 유지, 깜빡임 없음. 긴 대사 앞 "쓰다 지움"(… → 사라짐 → …) 이벤트당 1회. them 지연 `clamp(600+글자×18, 800, 2400)`.
- 스티커 슬롯 `Line.sticker`(`AppSize.sticker=120`, 에셋 없으면 안 그림). 사진은 현행.
- 나중에(P2): 헤더 상태줄에 관계 단계 문구(01 #3), 아바타 탭 → 프로필(01 #4).

### B. 날짜 전환 카드 — `02_game_loop.md` §2, 시각은 `03` §4.1
- `Phase.dayStart`(저장 안 함) + `DayCard`(메모리) + `beginMorning()`(멱등). `endDay()`→`dayStart[next]`→`action`(룰렛 자동), `newGame()`→`[first]`, `continueGame(dayStarted=false)`→`[resume]`. 엔딩 날은 카드 없음. 광고 순서는 광고→`endDay()`→카드.
- 내용: `수요일 · 흐림`(요일 `(day-1)%7`, 날씨 `stableSeed`) → `D+N`(`displayLarge` tabular, 첫 사용처) → `N일째 아침` / 장 첫날은 `2장 · 제목`(`config.json` `chapterTitles` 선택) → 예고(`endDay` 진입 시 `tomorrowHint` 를 `_resetDay` 전에 옮김) → 밤사이 한 줄 → `탭해서 넘기기`.
- 시간: `AnimationController` 하나로 1.4s(first 2.2s, resume 1.0s), 첫 350ms 탭 무시. **Timer 금지**(`pumpAndSettle` 이 통과해야 14개 위젯 테스트가 산다). 동작 줄이기: 진입·퇴장 즉시, 체류는 그대로.
- 배경 `CallBackdrop`. 소리 `day_start` + `lightImpact`. 고정 문구 `'D+N'` 단독 Text, `'N일째'`, `'탭해서 넘기기'`, `Key('day-card')`. 기존 `'D+1  ·  1장'`·`'오늘의 운'` 과 충돌 금지.
- 같이 가는 것: P1 하루 시계(A 와 한 PR), P3 아침 행동 메아리(별도 소형). P2 장 제목 5줄은 작가 작업.

### C. 사운드·햅틱 — `05_audio_haptics.md`, 연출은 `04` §2.1·§2.2
- `audioplayers` 6.x, `AudioContextIOS(ambient, mixWithOthers)` — 무음 스위치 존중, 백그라운드 재생 없음. 진동은 내장 `HapticFeedback` 만.
- 큐 11개: `msg_in`(medium) · `call_ring`(루프, 진동 2.6s 주기 2연타, 20s 뒤 진동 자동 정지) · `call_connect`(light) · `call_end`(medium) · `msg_out`(selection) · `wait_read`(light) · `choice_ok`(medium) · `choice_fail`(heavy) · `summary`(light) · `ending`(P0, heavy→light) · `day_start`(light). 말풍선 도착음 없음.
- `SfxService` 추상 + `NoopSfxService` 기본(위젯 테스트 무영향) + `RecordingSfxService`(테스트). 설정에 효과음·진동 토글(`PlayerMeta` 추가 필드), 나중에 대사 속도 `보통/빠르게`.
- 에셋: `assets/sfx/`, ≤0.5s 는 WAV, 나머지 m4a, `.ogg` 금지, LICENSES.md 필수. 애플·카톡 소리 금지. **1차 구현은 합성 톤(placeholder)으로 하고 실제 효과음은 사용자가 CC0 에서 교체.**
- 검토(나중): 전화 받기 10초 카운트다운(01 권고 1, 게임 규칙 변경이라 보류).

### D. 장면 삽화·스티커 — `06_scene_plan.md`, 프롬프트 `docs/SCENE_PROMPTS.md`
- 3종: 장면(3:2, 이벤트 위 카드·통화 배경), 사진 메시지(4:3, `photo.icon` 12종 실제 그림 + `photo.image` 덮어쓰기), 스티커(1:1 투명, 12×4 + 4명은 5번째). 엔딩은 캐릭터당 히어로 1장(+공용 3).
- 원칙: 얼굴은 스티커에만(초상화 기반), 장면·사진은 뒷모습·손·소품. 글자 0. 12+. 하루 최대 1장.
- 데이터: `image`(이벤트·엔딩), `sticker`(줄), `photo.image` — 전부 선택 필드. `assets/scenes|photos|stickers|endings/`. `PortraitRegistry` 와 같은 매니페스트 레지스트리. 없으면 지금과 동일(자리도 안 잡음). 총 ~113장 ~11MB, GIF 없음.
- 나중에(01 권고 5): 호감도 단계 해금 이미지·앨범 연동.

### E. 배너 상단 — `03` §3
- `BannerSlot(edge: top, safeArea: false)` 를 홈(헤더 줄 위)·행동·정산·앨범(TabBar 아래)·설정 body `Column` 첫 줄에. `bottomNavigationBar` 제거. `BannerFrame.edge` 추가(아래 경계선, `margin.bottom: sm`). 고정 `AdSize.banner`, `AnimatedSize`.
- 채팅·통화·알림·시트·다이얼로그 안 금지. 모달 스크림이 배너를 덮는 건 정상. 광고 빈도는 늘리지 않는다(01 반면교사).

### F. 자유 입력(제한형) — `07_free_input.md`
- `lib/engine/free_input.dart` 순수 함수: 음절 바이그램 Dice(선택지 0.40 + 반응 0.15) + 의도 태그 Jaccard 0.35(효과값에서도 태그 도출 — 선택지 40% 가 행동문) + 문체 0.10, 극성 페널티.
- 자동 확정 s1 ≥ 0.38 & 여유 ≥ 0.12(chance/minigame/잠김은 항상 1탭 확인), 아니면 "이런 뜻이에요?" 3택. 동점은 무작위 금지.
- UX: 버튼 3개 유지 + 아래 입력창, 키보드 올라오면 버튼은 칩 줄. 내 말풍선엔 친 문장 그대로. 무료 되돌리기 이벤트당 1회(자동 확정건만). 결과 패널에 `→ 원문` 캡션.
- 저장 `GameState.freeInputs`(최근 30, ≤80자, 추가만). 분석은 구조 지표만, 원문 전송 금지. 픽스처 `test/fixtures/free_input.json`(15 이벤트 × 3문장), 저분리 이벤트 리포트 `tool/intent_report.py`, 선택 필드 `intent`.

### G. 벤치마킹 — `01_benchmark.md`
- 권고 순서 C → A → B → F → D. Top 10 을 찍은 두 국내 사례는 형식의 신선함으로 올라가 과금·광고로 내려왔다.
- 제타가 2026 베타로 "선택지 + 직접 작성" 하이브리드에 도달 — F 설계와 동형.

## 3. 구현 순서 (확정)

| 단계 | 내용 | 파일 | 에이전트 |
|---|---|---|---|
| 1 | **C+E**: `SfxService`·큐 11개·합성 placeholder 에셋·설정 토글 + 배너 상단 이동 | `lib/audio/`, `settings_screen`, `widgets(BannerFrame)`, 5개 화면, `event_screen` 훅, pubspec | Mobile App Builder |
| 2 | **A+B**: 3열 말풍선·아바타·헤더·구분줄·시계·읽음·타이핑·"쓰다 지움" + `Phase.dayStart`·`DayCard`·`DayTransitionScreen` + DESIGN_SYSTEM 갱신 | `event_screen`, `widgets(ChatBubble…)`, `design_system(AppSize)`, `game_controller`, `day_card.dart`, `main.dart` | Mobile App Builder (+UI Designer 검수) |
| 3 | **F**: 매처·픽스처·입력창·되돌리기·지표 | `engine/free_input*.dart`, `event_screen`, `models(GameState)`, `tool/intent_report.py` | Mobile App Builder + Narrative Designer(픽스처 검증) |
| 4 | **D 슬롯**: 레지스트리·JSON 필드·삽화 카드·스티커·사진 실제 그림 (그림은 사용자가 `SCENE_PROMPTS.md` 로 생성) | `portraits.dart` 확장, `models`, `photo_card`, `event_screen` | Mobile App Builder |
| 각 단계 뒤 | `flutter analyze`, `flutter test`(회귀 0), 시뮬레이터 확인, Reality Checker 검수, 커밋 | | Reality Checker |

## 4. 하지 않는 것 / 주의

- 채팅 화면 배너 (정책).
- 447개 이벤트 전부 삽화 (비용). 없는 이벤트는 지금처럼.
- 풀 LLM (이번 개편 밖).
- 진동은 사용자가 끌 수 있어야 하고, 무음 스위치를 무시하면 안 된다.
- 기존 세이브 호환: JSON 에 필드를 **추가만** 한다(`save_migration_test.dart`).

## 5. 에이전트 배정 (agency-agents)

설치됨: Agents Orchestrator, UI Designer, Frontend Developer, Reality Checker, Ad Creative Strategist, Reddit Community Builder, AI Code Security Auditor.

추가(사용자가 agency-agents 앱에서 켬):

| 에이전트 | 맡는 것 |
|---|---|
| `engineering-mobile-app-builder` | Flutter 구현 전체 (A·B·C·E·F) |
| `game-designer` | 하루 루프·프린세스 메이커식 구조 진단, B 연출 |
| `narrative-designer` | 대사 톤, 스티커·삽화가 붙을 장면 선정, F 의 의도 매핑 어휘 |
| `design-whimsy-injector` | 마이크로 인터랙션(타이핑, 읽음, 전화 벨 연출) |
| `design-image-prompt-engineer` | `docs/SCENE_PROMPTS.md` 스티커·삽화 프롬프트 |
| `design-visual-storyteller` | 어떤 장면에 그림이 붙어야 하는지, 그림의 역할 |
| `game-audio-engineer` | 효과음 목록·톤·햅틱 패턴, 에셋 출처 |
| `product-trend-researcher` | G 벤치마킹 |
| `marketing-app-store-optimizer` | Top 10 — 개편 뒤 스토어 자산 |

Reality Checker 는 각 단계 끝에 "실제로 되는가" 를 본다. UI Designer 는 DESIGN_SYSTEM.md 갱신.
