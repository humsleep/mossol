# 02. 하루 루프 진단과 날짜 전환(B) 설계

> 2026-09-23 · game-designer. 상위 문서 OVERHAUL_PLAN.md §2-B, ROADMAP.md §1·§3, MOMENTS_SPEC.md.
> 코드 기준: `lib/game_controller.dart`(`Phase`, `startDay`, `endDay`, `tomorrowHint`), `lib/ui/action_screen.dart`,
> `summary_screen.dart`, `roulette_sheet.dart`, `lib/engine/retention.dart`(`TomorrowPeek`). 설계만 다루고 코드는 바꾸지 않았다.
> 숫자는 전부 가설이다. `[PLACEHOLDER]` 는 시뮬레이터에서 손으로 잡아 본 뒤 확정한다.

## 1. 진단 — 지금의 하루가 "작업"이 되는 지점

### 1.1 프린세스 메이커의 루프와 나란히 놓기

| 단계 | 프린세스 메이커 | 모쏠 탈출기 (지금) | 차이가 만드는 느낌 |
|---|---|---|---|
| 계획 | 한 달 일정 3칸을 **플레이어가** 짠다. 비용·피로·수입이 표에 보인다 | 룰렛(운) → 아침 행동 6개 중 1개. 효과는 `desc` 한 줄 | PM 은 "내가 정한 한 달". 우리는 하루의 첫 입력이 **슬롯머신**이고, 행동은 +1·+2 짜리 다이얼 |
| 시간이 흐름 | 딸이 일하는 그림이 10일 단위로 지나간다. **시간이 보인다** | 없음. 이벤트가 끝나는 순간 다음 이벤트가 "지금" 도착 | 하루 안에 시계가 없다. 톡 4개가 한 화면에서 연달아 오니 "하루"가 아니라 "큐" |
| 결과 | 월말 스탯 보고 + 그 달의 사건 | 정산(스탯 변화·관계 카드·클리프행어·내일 예고) | 여기는 이미 PM 급. 문제는 그 뒤 |
| 달이 바뀜 | 달력이 넘어가고 계절·축제·생일이 온다 | "다음 날로" → (전면 광고) → AppBar 글자만 `D+1`→`D+2` → 룰렛 시트가 위에 뜸 | **밤이 지나간 감각이 0**. 날짜 경계의 감정 박자를 광고가 차지하거나 아무것도 없다 |
| 달력 닻 | 월·계절·축제·수확제·나이 | `chapter` 숫자(20일 단위, 이름 없음). 요일·계절 없음 | 100일이 전부 같은 날. "오늘이 며칠인지" 를 기억할 이유가 없다 |

### 1.2 화면·순간별로 몰입이 새는 곳

- **L1 · 정산 → 행동 (가장 큼).** `summary_screen.dart:139` 에서 광고 → `endDay()` → `phase = Phase.action` → `ActionScreen.initState` 가 곧바로 `RouletteSheet` 를 모달로 띄운다. 플레이어 눈에는 "정산 카드 → 광고 → 룰렛" 이다. 잠들고 일어난 적이 없다. **B 가 고치는 자리.**
- **L2 · 룰렛이 행동보다 먼저.** 하루의 첫 입력이 운이라 "내 하루" 가 아니라 "뽑기" 로 시작한다. 다만 `rouletteDay`·시뮬레이터(`sim_balance_test.dart:731`) 가 "룰렛 → 행동" 순서를 고정하고 있어 **순서는 유지**한다. 대신 B 카드가 앞에 서면 룰렛은 "아침 운세" 자리로 내려간다.
- **L3 · 아침 행동의 결과가 안 보인다.** 헬스장을 골라도 그 자리에서 아무 일도 안 일어나고, 밤 정산에서 이벤트 변화와 섞여 나온다. 원인→결과 끈이 끊겨 있어 행동이 "설정값 고르기" 로 느껴진다. PM 은 딸이 일하는 그림으로 이 끈을 잇는다. (§3-P3)
- **L4 · 하루 안에 시각이 없다.** 알림 카드도 `'지금'`, 말풍선에도 시각이 없다. AI 채팅 앱·카톡은 시각이 있어서 "저녁에 온 톡" 이 된다. (§3-P1)
- **L5 · 100일이 서로 구별되지 않는다.** `chapter` 는 `D+21  ·  2장` 처럼 숫자만. 요일·주말·장 제목이 없어 "오늘은 뭔가 다르다" 가 모먼트(MOMENTS_SPEC)에만 기대고 있다. (§3-P2)
- 잘 되고 있는 것(건드리지 말 것): 관계 변화 카드가 숫자보다 먼저 뜨는 정산, 클리프행어, `tomorrowHint` 예고, 모먼트 가중치, 하트 1개 = 하루.

## 2. 항목 B — 날짜 전환 카드 설계

### 2.1 위치와 상태 전이

`Phase` 에 `dayStart` 를 **추가**한다(저장하지 않는 값이므로 세이브 무관). 카드는 "하루가 아직 시작되지 않은 상태(`dayStarted == false`)로 진입하는 모든 길목" 에 선다.

```
[지금]
home ─newGame─────────────▶ action(룰렛 자동) ─startDay─▶ event ─…─▶ summary ─[광고]─endDay─┬─▶ action(D+N+1, 룰렛)
home ─continue(dayStarted=F)▶ action                                                         └─▶ ending
home ─continue(dayStarted=T)▶ event | summary

[개편]
home ─newGame─────────────▶ dayStart[first] ─▶ action(룰렛) ─startDay─▶ event ─…─▶ summary ─[광고]─endDay─┬─▶ dayStart[next] ─▶ action(룰렛)
home ─continue(dayStarted=F)▶ dayStart[resume] ─▶ action                                                    └─▶ ending (카드 없음)
home ─continue(dayStarted=T)▶ event | summary   (변경 없음 — 하루 도중 복귀는 카드 없이 남은 이벤트로)
```

- 광고 순서는 그대로 **광고 → `endDay()` → 카드**. 카드 뒤에 광고를 두면 "아침 → 광고 → 룰렛" 이 되어 L1 을 다시 만든다. 카드에는 배너·전면 광고 모두 없다(전환 화면 광고는 정책 위험, 1.4초 배너는 무의미).
- 엔딩으로 가는 날(`isFinished`·즉시 엔딩)은 카드를 건너뛰고 `Phase.ending`. 버튼 문구가 이미 `'엔딩 보기'` 다.
- 컨트롤러 변경(개념): `endDay()`/`newGame()`/`continueGame()` 이 `phase = Phase.action` 대신 `dayCard = DayCard(...)`, `phase = Phase.dayStart`. 새 메서드 `beginMorning()` 은 `phase == Phase.dayStart` 일 때만 `phase = Phase.action` + `notifyListeners()`. **멱등** — 타이머와 탭이 동시에 불러도 두 번 넘어가지 않는다. `main.dart` 의 `switch(controller.phase)` 와 `debug_gallery.dart` 에 `Phase.dayStart => DayTransitionScreen(c)` 를 더한다.
- `ActionScreen.initState` 의 룰렛 자동 열기는 그대로. 카드가 사라지고 행동 화면이 첫 프레임을 그리면 지금처럼 룰렛이 뜬다. 즉 플레이어 순서는 **카드(밤이 지남) → 룰렛(아침 운) → 행동(내 결정)**.

### 2.2 카드가 담는 것 (위에서 아래로)

| 줄 | 내용 | 출처 | 없으면 |
|---|---|---|---|
| ① 캡션 | `수요일 · 흐림` | 요일 = `['월','화','수','목','금','토','일'][(day-1) % 7]`. 날씨 = `EventEngine.stableSeed(seed, day, 'weather') % 100` → 0–54 맑음, 55–79 흐림, 80–99 비. 5장(81일~)은 "비" 자리에 "눈" | 항상 있음 |
| ② 주인공 | `D+7` (displayLarge, 카드 중앙) | `s.day` | 항상 |
| ③ 부제 | 보통 날 `7일째 아침`. **장의 첫날**(1·21·41·61·81)은 `2장 · {장 제목}` 을 ②보다 크게 강조 | `s.chapter(config)`, 장 제목은 `config.json` 에 `chapterTitles: [5개]` 선택 필드(없으면 `2장`) | 제목 없으면 숫자만 |
| ④ 예고 | `오늘 서연에게서 연락이 올 것 같다` + 있으면 아래 작은 따옴표 줄 `"어제 그거 봤어?"` | `endDay()` 진입 시, `_resetDay()` 로 지우기 **전에** `tomorrowHint` 를 읽어 `DayCard.hint` 에 옮겨 둔다. 문장은 `TomorrowPeek.todayLineFor(name)` 신설(`lineFor` 의 "내일" → "오늘"). preview 는 `c.sayOrNull` 로 이름 치환. 기존 `TomorrowLine` 위젯 재사용(아바타 포함) | 줄 자체를 뺀다. 지어낸 문장으로 채우지 않는다 |
| ⑤ 밤사이 | `밤사이 지우와 조금 멀어졌다` (bodySmall, 2차 색, 최대 1줄) | `s.overnightShifts` 첫 항목(`characters.json` 순, `SaveSummary.overnightOf` 와 같은 규칙). 이미 `signals.rollover` 가 만든 문장 | 없으면 뺀다 |
| ⑥ 힌트 | `탭해서 넘기기` (하단, 40% 불투명) | 고정 문구 | 항상 |

- 배경은 캐릭터 색이 아니라 중립 surface. 주말(토·일)만 `tokens` 의 따뜻한 틴트를 6~8% 얹는다 `[PLACEHOLDER]`. 장의 첫날은 틴트를 조금 더 진하게.
- 접근성: 카드 루트에 `Semantics(liveRegion: true, label: '7일째 아침, 수요일, 흐림')`. ④·⑤ 는 일반 Text 로 읽힌다. 글자 확대 1.3배에서 ①~⑥ 이 한 화면에 들어가야 한다(⑤는 넘치면 생략).
- 사운드·햅틱(항목 C 와 접점): 카드 등장 시 `HapticFeedback.lightImpact` 1회, 효과음은 오디오 에이전트가 "아침" 톤으로 1개(선택). 룰렛·문자 효과음과 겹치지 않게 카드가 완전히 사라진 뒤 룰렛이 뜬다.

### 2.3 시간·건너뛰기·동작 줄이기

| 변형 | 진입 | 표시 시간 | 탭 무시 구간 | 줄 구성 |
|---|---|---|---|---|
| `next` | `endDay()` (2일째부터) | **1.4초** 자동 진행 `[PLACEHOLDER 1.2–1.6]` | 첫 **350ms** 는 탭 무시(`'다음 날로'` 를 누른 손가락의 두 번째 탭 방지) | ①②③④⑤⑥ |
| `first` | `newGame()` (D+1) | **2.2초** `[PLACEHOLDER]` | 350ms | ① `월요일 · 맑음`, ② `D+1`, ③ `{run}회차 · 첫날` + `1장 · {제목}`, ④ 대신 `c.previousRunLine`(있을 때만, "지난 판엔 …"), ⑥. 예고·밤사이 없음 |
| `resume` | `continueGame()` 이고 `dayStarted == false` | **1.0초** | 350ms | ①②③⑥ 만. `tomorrowHint` 는 이미 지워졌고 `lastCliffhanger` 는 행동 화면 `'어젯밤: …'` 이 보여 준다(중복 금지) |

- 애니메이션: 220ms 페이드인(`AppMotion.base`) → 홀드 → 220ms 페이드아웃 → `beginMorning()`. 페이드아웃 시작과 동시에 탭은 무시.
- **구현 방식 제약(테스트 때문에 중요):** 전체 시간을 `AnimationController(duration: 표시 시간)` 하나로 돌리고 `status == completed` 에서 `beginMorning()` 을 부른다. `Timer` 로 만들면 `test/widget/helpers.dart:123 spinRouletteSheet` 의 `pumpAndSettle()` 이 카드를 넘기지 못해 `flow_test` 등 14개 파일이 `'오늘의 운'` 을 못 찾는다. AnimationController 면 `pumpAndSettle` 이 자연스럽게 통과한다.
- 동작 줄이기(`AppMotion.reduced`): 페이드 없이 정지된 카드를 **1.0초**(first 는 1.6초) 보여 주고 같은 컨트롤러로 넘긴다(`Duration.zero` 로 만들면 안 된다 — 카드가 한 프레임도 안 보인다). 탭 건너뛰기는 동일.
- 앱이 백그라운드로 갔다 오면 컨트롤러를 그 자리에서 이어 간다. 카드 중에 프로세스가 죽어도 세이브는 이미 `endDay()` 뒤 상태라 재실행 시 `resume` 변형으로 같은 날 아침이 나온다(손해 없음).

### 2.4 문구·구조 계약 (위젯 테스트와의 경계)

- 카드에는 `'D+1  ·  1장'`(공백 2개), `'D+1 정산'`, `'오늘의 운'`, `'어젯밤: '` 을 **그대로 담지 않는다**. ②는 `'D+7'` 단독 Text, ③은 별도 Text.
- 카드가 보이는 동안 `ActionScreen`·`RouletteSheet` 는 트리에 없어야 한다(`Phase` 로 갈리므로 자연히 만족).
- 새로 고정할 문구: 주인공 `'D+{n}'`, 부제 `'{n}일째 아침'`, 첫날 `'{run}회차 · 첫날'`, 예고 `'오늘 {name}에게서 연락이 올 것 같다'`, 힌트 `'탭해서 넘기기'`. `Key('day-card')` 를 루트에.
- `flow_test.dart:89` 의 `'다음 날로'` 탭 뒤 `spinRouletteSheet` 는 수정 없이 통과해야 한다(2.3 의 컨트롤러 조건). 카드 전용 테스트는 `pump(350ms)` 뒤 탭 → `Phase.action` 확인, 350ms 안 탭 → 여전히 `dayStart` 확인, 동작 줄이기에서 1.0초 뒤 자동 진행 확인.

## 3. 콘텐츠 없이 "실제 같음" 을 올리는 루프 변경 3개

기각: 자유 이동·시간표형 오픈 월드(ROADMAP §3), 그리고 OVERHAUL_PLAN G 의 "아침 행동을 이번 주 계획으로 확장" 도 **이번엔 하지 않는다** — 하트 1개 = 하루 라는 경제(ROADMAP §0), 시뮬레이터의 하루 단위 전략, "매일 조금씩" 리텐션이 전부 하루 단위 결정에 묶여 있다. 7일 계획은 이 셋을 한꺼번에 건드린다.

### P1. 하루 안의 시계 (이벤트 시각 도장)
- 오늘 큐의 i 번째 이벤트에 시간대를 배정: 4개면 `09:xx · 12:xx · 16:xx · 21:xx`, 3개면 `10 · 15 · 21`, 2개면 `12 · 20`, 1개면 `19`. 분은 `stableSeed(seed, day, 'clock$i') % 60`. 카드 ① 은 `07:30`, 정산 AppBar 옆에 `23:00` 을 작게 — 하루가 아침에서 밤으로 흐른다.
- 표시: 알림 카드의 `'지금'` 을 그 시각으로(테스트 문구 `'지금'` 은 알림 카드 고정 문구 — 시각은 **별도 Text** 로 덧붙인다), 상대 말풍선 그룹 첫 줄과 내 말풍선에 카톡처럼 `오후 4:12`. 읽씹 `wait` 은 시계를 눈에 띄게 돌린다(`+30분`). `call` 은 밤 시간대(21:xx)에 우선 배정 — 계획 순서는 바꾸지 않고 **라벨만** 뒤 시간대로 붙인다.
- 비용: 대본 0, 에셋 0, 코드 소(위젯 2개 + 시각 계산 1함수). 엔진·세이브 무관. 항목 A(채팅 UI) 와 같은 파일이라 A 와 함께 구현.

### P2. 달력 닻 — 요일·주말·장 제목
- 요일·날씨는 B 카드(§2.2 ①)로 이미 생긴다. 여기에 (a) 장의 첫날 카드를 "제목 카드" 로 키우고, (b) 주말은 카드 틴트 + P1 시간대를 한 칸 늦춤(`10 · 14 · 18 · 22`), (c) 행동 화면 AppBar 뒤에 요일 한 글자(`D+7  ·  1장` 은 그대로 두고 **별도 Text** `수`).
- 비용: 장 제목 5줄(`config.json` `chapterTitles`, 작가 30분, 예: 1장 "처음 보는 사람들", 5장 "마지막 스무 날" `[PLACEHOLDER]`), 에셋 0, 코드 소. 엔진 무관 — 요일·날씨·주말은 **트리거·효과·계획에 절대 넣지 않는다**(§4).

### P3. 아침 행동의 메아리
- `startDay` 뒤 첫 이벤트 화면 **위에** 얇은 카드 1장: `헬스장에 다녀왔다 · 매력 +1 · 스트레스 +4`. 문장은 `DayAction.desc` 를 재사용하고 수치는 `engine.applyAction` 의 델타(이미 `dayDelta` 에 합쳐지는 값)를 그대로 칩으로. 1.2초 뒤 접히거나 첫 말풍선이 뜨면 위로 밀린다. L3 의 원인→결과 끈을 잇는다.
- 비용: 대본 0(6개 `desc` 재사용; 원하면 과거형 6줄), 에셋 0, 코드 소. `dayDelta` 값은 표시만 하고 다시 적용하지 않는다(이중 적용 금지).

읽음 표시 `1` 이 사라지는 연출·타이핑 인디케이터는 루프가 아니라 말풍선 단위라 항목 A/whimsy 쪽 문서로 넘긴다.

## 4. 바꾸면 안 되는 것

### 4.1 세이브 호환 (`test/save_migration_test.dart`)
- `GameState` JSON 은 **필드 추가만**. 이번 설계는 새 필드가 **0개**다: 요일은 `day` 에서, 날씨는 `seed`+`day` 에서, 장 제목은 config 에서, 예고·밤사이는 `endDay` 시점 메모리(`DayCard`)에서 나온다. `Phase.dayStart` 는 저장하지 않는다.
- 혹시 필드를 더할 때: 없으면 기본값(`fromJson` 69–84행 — 예전 세이브 → `toJson` 왕복이 같아야 하므로 기본값도 결정적으로 직렬화), 모르는 필드는 무시(194행), `double` 로 온 정수 허용(99행).
- `dayStarted == true` 인 세이브는 카드 없이 남은 `dayQueue` 로 복귀(`continueGame` 727–735행 그대로). `lastHeartMs` 없는 세이브 → 하트 만땅 규칙 유지.
- `config.json` 의 `chapterTitles` 는 선택 필드. `GameConfig.fromJson` 은 없으면 빈 목록.

### 4.2 밸런스 (`test/sim_balance_test.dart`, 200시드 × 11전략)
- 시뮬레이터는 `spinRoulette → applyAction → planDay → (선택) → endDay` 를 엔진 직접 호출로 돈다(731·735·763·878행). **이 순서와 엔진 함수의 의미를 바꾸지 않는다.** 카드·시계·요일은 전부 UI 층.
- 요일·날씨·시간대·주말이 `Trigger`·`Requirement`·`Effects`·`planDay` 가중치·`spinRoulette` 표·`endDay`(미연락 −1, 스트레스 −3, `day+1`)에 들어가면 시드별 결과가 흔들리고 "선호 밖 엔딩 0" 검증이 의미를 잃는다. **표시 전용**으로 못 박는다.
- 그대로 두는 숫자: `totalDays 100`, `chapterLength 20`, `maxHearts 5`, `heartRegenMinutes 15`, 하루 하트 1개, `earlyAffection`, 오프닝 3일 × 4이벤트, 모먼트 가중치(3일차부터, 2일 간격, ×3), 행동 6개 효과값, MBTI 배수.
- `tomorrowHint` 는 사본에서 미리 보는 값이라 실제 내일에 영향이 없다(`TomorrowPeek.peek`) — 카드가 이 값을 읽어도 계획은 바뀌지 않는다. `_tomorrow` 캐시 키(`day|seen|cliffhanger`)는 그대로.

### 4.3 화면 계약
- DESIGN_SYSTEM §4.1 고정 문구 전부. 특히 `'D+1  ·  1장'`, `'D+1 정산'`, `'오늘의 운'`/`'돌리기'`/`'시작'`, `'다음 날로'`, `'어젯밤: '`, 알림 카드 `'지금'`.
- 전면 광고는 `'다음 날로'` 탭 직후(`AdManager.canShowInterstitial(day)` 정책) 그대로. 카드·룰렛에 광고 추가 금지. 채팅 화면 배너 없음 유지.
- `analytics.dayReach` 는 `endDay` 안에서 그대로. 카드용 이벤트는 추가하지 않는다(퍼널에 불필요).

## 5. 구현 순서 제안
1. `Phase.dayStart` + `DayCard` + `beginMorning()` + `DayTransitionScreen`(`next` 변형만) → 기존 위젯 테스트 전부 통과 확인.
2. `first`·`resume` 변형, 동작 줄이기, 탭 가드 테스트.
3. `chapterTitles`(config, 선택) + 장의 첫날 강조.
4. P1 시계는 항목 A 와 한 PR, P3 메아리는 별도 소형 PR. P2 (b)(c) 는 P1 뒤.

## 변경 이력
- v1 (2026-09-23): 초안. 진단 5지점, B 상태 전이·카드 내용·시간·테스트 계약, 루프 변경 3개, 불변 목록.
