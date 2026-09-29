# 03. 채팅 UI 개편 명세 — 카톡형 말풍선 · 이름만 남는 AppBar · 상단 배너 · D+N 카드

> 2026-09-23. OVERHAUL_PLAN.md §2A·§2B·§2E 의 확정본. 기준은 DESIGN_SYSTEM.md 토큰이며 **이 문서의 숫자는 전부 토큰 이름**이다.
> 코드는 손대지 않았다. 구현자는 §6 의 DESIGN_SYSTEM 갱신을 먼저 반영하고 나서 위젯을 고친다.
> 테스터 원문: "실제 카톡을 하는 것처럼 이름 왼쪽에는 그 사람의 이미지가 나오도록. 상단은 이름만."

## 0. 현재 코드 사실 (설계의 전제)

- `Line.who` 는 `them | me | narr | sys` 넷뿐(스토리 JSON 전수: them 2013 · narr 1338 · sys 223 · me 163). **캐릭터 id 는 `who` 에 없다.**
  화자는 `Line.name`(표시 이름, 예 `태현`·`준호`·`엄마`·`서연`)이고, 없으면 이벤트의 `StoryEvent.character` 상대다.
  → 그룹 대화의 화자 구분은 `_speakerKey` 가 이미 하는 `them:${name ?? partner}` 그대로 쓴다.
- 초상화는 `PortraitRegistry.pathFor(id)` 로 **캐릭터 id** 에만 있다. `태현`·`준호`·`엄마` 같은 NPC 는 초상화가 없으므로
  `CharacterAvatar` 의 이니셜 원형(중립 강조색)으로 떨어진다. 이는 의도된 동작이다(§1.2).
- 이름 → id 는 `assets/story/characters.json` 12명(서연·하늘·지우·민재·예은·도윤·정우·다은·승현·소희·건우·유나)에서만 역산된다.
- 위젯 테스트 고정: 타이핑 표시는 `Text('…')` 정확히 한 개(`event_screen_test` 53·183행), 상대 이름 `Text('태현')` 이 하나 이상,
  선택지 `OutlinedButton` 3개. 이 셋은 유지한다.

## 1. 메시지 목록 (카톡형) — `ChatBubble`, `EventScreen._chat`

### 1.1 행 구조

상대(`them`) 줄은 3열 `Row` 다: **아바타 열 → `sm` → 본문 열(이름 + 말풍선) → `xs` → 메타 열(시각·읽음)**.
내(`me`) 줄은 좌우 반전이고 아바타 열이 없다. `narr`·`sys` 는 열 구조를 쓰지 않는다(§1.5).

| 요소 | 값 | 비고 |
|---|---|---|
| 행 좌우 여백 | `md` | 현재 `_bubble` 의 left/right 유지 |
| 행 위 간격 | 화자 바뀜 `md`, 같은 화자 연속 `xs` | 현재 규칙 유지(`isFirstOfGroup`) |
| 아바타 | `CharacterAvatar(size: AppSize.avatarMd /*40*/)` | 묶음 **첫 줄에만**. `crossAxisAlignment: start` 로 이름 줄과 윗선을 맞춘다 |
| 아바타 자리 표시 | `SizedBox(width: AppSize.avatarMd)` | 묶음 둘째 줄부터. 말풍선 왼쪽 선이 흔들리지 않게 폭만 차지한다 |
| 이름 | `labelSmall`, 색 `accent.base`, 첫 말풍선 위, 아래 `xs` | 현재의 **색 점은 제거**한다(아바타가 그 역할을 대신한다). 좌측 패딩 `xs` 유지 |
| 말풍선 최대 폭 | 화면 폭 × 0.72 | 현재 유지. 아바타 열이 생겨도 0.72 는 화면 기준이라 320pt 에서도 오른쪽에 `md` 이상 남는다 |
| 메타 열 | 폭은 내용 크기, 세로는 말풍선 **아래 끝**에 정렬(`crossAxisAlignment: end`) | §1.4 |
| 320pt 폭 | 아바타는 그대로 40 | 이니셜 글자(`labelLarge`)는 32 에서 `labelMedium` 으로 내려가므로 40 유지가 낫다. 캐스트 소개의 72→56 규칙은 여기 적용 안 함 |

Semantics: 아바타는 `ExcludeSemantics`(이름 Text 가 이미 화자를 읽어 준다). 행 전체를 `Semantics(label: '$name: $text')` 로 묶지 않는다 — 현재처럼 이름·본문이 각각 읽히는 편이 테스트·스크린리더 모두에 안전하다.

### 1.2 아바타에 무엇을 그리나 — `characterId` 해석

`ChatBubble` 에 `characterId` 를 새로 받는다(§6 시그니처). `EventScreen` 이 줄마다 정한다:

```
_speakerIdFor(Line l, StoryEvent ev):
  l.name == null            → ev.character            (상대 본인)
  l.name == 상대 이름        → ev.character
  l.name ∈ roster 이름 → id  → 그 id                    (그룹 대화에 다른 캐스트가 낀 경우)
  그 밖(태현·엄마·모르는 번호) → null                    (NPC)
```

- `accent` 도 같은 규칙: id 가 있으면 `tokens.accentFor(id)`, NPC 는 `tokens.neutralAccent`.
- NPC 는 이니셜 원형(`neutralAccent.container` 위 첫 글자). `'모르는 번호'` 는 첫 글자 `모` 가 어색하므로 `CharacterAvatar(mystery: true)` 로 그린다(사람 실루엣). 판정: 이름이 `모르는`·`알 수 없는` 으로 시작하면 mystery.
- 초상화가 있는 캐릭터도 **아바타 열 크기·테두리는 동일**(`CharacterAvatar` 가 보장). 사진 유무로 레이아웃이 달라지지 않는다.
- 그룹 대화(한 이벤트에 `name` 이 둘 이상): 화자마다 자기 아바타. `_speakerKey` 가 이름으로 묶으니 A→B→A 순서면 세 묶음, 아바타 셋. 추가 규칙 없음.

### 1.3 말풍선 모양·색 (화자별)

| 화자 | 배경 / 글자 | 테두리 | 모서리 | 정렬 |
|---|---|---|---|---|
| `them` | `bubbleTheirs` / `onBubbleTheirs` | `bubbleBorder` `hairline` | `AppRadius.bubble(mine: false, tail: isLastOfGroup)` | 왼쪽, 아바타 열 다음 |
| `me` | `bubbleMine` / `onBubbleMine` | 없음 | `AppRadius.bubble(mine: true, tail: isLastOfGroup)` | 오른쪽, 아바타 없음 |
| `narr` | 배경 없음, `narration` 이탤릭 `bodyMedium` | 왼쪽 `outlineVariant` `emphasis` 세로선 | — | 좌우 `xl`, 현재 유지 |
| `sys` | `surfaceContainerHigh` / `systemLine` `labelSmall` | 없음 | `rPill` | 가운데, 현재 유지 |

- 캐릭터 강조색은 **이름 글자와 아바타 테두리에만**. 말풍선 배경엔 쓰지 않는다(§1.6 규칙 유지).
- 그룹 대화에서 `me` 는 한 명이므로 이름 없음. 내 말풍선 위에 `'나'` 를 쓰지 않는다.
- 자유 입력(OVERHAUL §2F) 이 들어와도 내 말풍선은 이 규격 그대로다. 사용자가 친 문장이 `Line(who: 'me')` 로 들어올 뿐이다.

### 1.4 시각 · 읽음 (메타 열) — 가짜여도 규칙은 고정

카톡의 "1" 숫자 배지는 트레이드드레스라 쓰지 않는다(§4.3). 우리 표기는 **낱말 `읽음`** 하나다.

- **시각**: 묶음의 **마지막 말풍선 옆**에만. `labelSmall` 을 `AppTypography.tabular` 로, 색 `onSurfaceVariant`. 형식 `오후 9:14`(한국어 12시간, 앞 0 없음).
  - 시계는 표현 전용 가짜다. 시작 시각 = 21:00 + `(state.seed ^ state.day) % 50` 분(밤 톤, §0). 줄마다 +1분, `wait` 줄은 `wait` 초만큼 더한다. 통화·미니게임 전후로 흐르지 않는다.
  - 같은 분에 연속 묶음이 있으면 뒤 묶음의 시각은 생략(빈 `SizedBox`)한다.
- **읽음**: `me` 말풍선의 메타 열에, 시각 **위** 한 줄로 `labelSmall` `systemLine`. 조건: 그 내 말 뒤로 `them` 줄이 하나라도 공개됐을 때. 상대가 아직 답하기 전엔 아무것도 없다(빈 칸). 기존 `sys` 빈 줄의 `'읽음'` pill 과 `_WaitingBlock` 의 `'읽음 · N초째 답이 없다'` 는 그대로 둔다 — 둘 다 상대가 **내 말을** 읽었다는 뜻이라 충돌하지 않는다.
- 메타 열은 `ExcludeSemantics`. 시각은 스크린리더에 소음이다. 읽음은 `Semantics(label: '읽음')` 하나만 남긴다.
- 메타 열 폭이 말풍선 최대 폭을 잠식하지 않도록 말풍선 `ConstrainedBox` 는 메타 열 밖에서 0.72 를 잰다(현재와 같음).

### 1.5 narr · sys · 부재중 · 제목 구분줄

- `narr`·`sys`·`_MissedCall` 은 현재 규격 유지. 아바타 열 없음, 화면 폭 전체.
- **이벤트 제목**은 AppBar 에서 내려와 대화 맨 위 구분줄이 된다(§2). 새 위젯 `ChatDivider(text)`: `sys` pill 과 같은 모양(`surfaceContainerHigh`, `rPill`, `labelSmall` `systemLine`), 위 `sm` 아래 `md`, 문구 `'D+N · 제목'`. 제목이 빈 문자열이면 `'D+N'` 만.
- 목록 padding 은 현재 `top: sm, bottom: lg` 유지. 구분줄이 첫 항목이라 위 여백은 그것으로 충분하다.

### 1.6 사진 · 스티커

- **사진**(`line.photo`): 현재 경로 유지. 아바타 열 다음 본문 열에 `PhotoBubble(width: 기본 min(60%, 220))` → `xs` → 텍스트 말풍선(있을 때). 메타 열은 마지막 요소 아래 끝에 붙는다.
- **스티커**(`Line.sticker`, 미래 필드 — **레이아웃만 예약**): 본문 열에서 텍스트 말풍선 **뒤**에 `xs` 간격으로 `StickerBubble` 한 장. 배경·테두리 없음, 크기 `AppSize.sticker`(120) 정사각, 그림은 `BoxFit.contain`.
  에셋 `assets/stickers/<characterId>_<emotion>.png`(감정 4종 `joy | sulky | shy | surprised`). 에셋이 없으면 **아무것도 그리지 않는다**(깨진 상자 금지). `me` 스티커는 오른쪽 정렬, 같은 크기. 텍스트 없이 스티커만이면 이름·아바타 규칙은 말풍선과 동일.
  스티커는 정지 그림이다. 움직임이 필요하면 `_Entrance` 만 쓴다(축소 모션에서 즉시 완료).
- 사진·스티커 모두 `narr`·`sys` 줄에는 붙지 않는다.

### 1.7 타이핑 표시 — `_TypingBubble` 교체 → `TypingIndicator`

- **다음 줄이 `them`** (`ev.lines[c.revealed]`, 반응 중이면 `c.lastReply[_replyShown]`)이면 그 화자의 아바타(첫 줄 규칙 적용: 직전 공개 줄이 같은 화자면 자리 표시만) + `bubbleTheirs` 말풍선(테두리 `hairline`, `AppRadius.bubble(mine: false, tail: true)`, 안쪽 `AppInsets.bubble`).
  말풍선 안은 **`Text('…')` 한 개**(테스트 고정, 스타일 `titleMedium` `systemLine`) 에 `AnimatedOpacity` 로 0.35↔1 을 `AppMotion.dLoop`(신설, §6 §1.10) 주기로 오간다. 점 3개를 따로 그리지 않는다 — 글리프 하나로 충분하고 테스트가 그대로 산다.
- 다음 줄이 `narr`·`sys` 면 `CallTyping`(가운데 `'…'`)을 재사용한다. 지문이 "입력 중" 으로 읽히면 이상하다.
- 축소 모션: 깜빡임 생략, 정지 `'…'`(불투명도 1).
- 이름은 타이핑 말풍선 위에도 붙는다(첫 줄일 때). 그래야 "누가 치는 중인지" 가 아바타+이름으로 읽힌다.

## 2. AppBar — 이름만 (+상태 한 줄)

`_header` 를 다음으로 바꾼다. 아바타·제목·D+N pill 을 모두 걷어낸다.

| 자리 | 내용 |
|---|---|
| `title` | 2줄 `Column`(start): 이름 `titleLarge` 1줄 ellipsis → 상태 `labelSmall` `onSurfaceVariant` 1줄 |
| `titleSpacing` | `lg` (현재 유지) |
| `actions` | **없음**. D+N 은 §1.5 구분줄로 내려간다 |
| `bottom` | `AppProgressBar(height: xs)` 대화 진행도 **유지**. `fill` 은 상대 있으면 `accent.base`, 없으면 `systemLine`(현재 그대로) |
| 상대 없는 독백 이벤트 | 이름 자리에 `ev.title` `titleLarge`, 상태 줄 없음(현재 `hasPartner == false` 분기 유지) |

상태 줄 문구(전부 표현 전용, 컨트롤러 변경 없음):

| 상황 | 문구 |
|---|---|
| 대사 공개 중 · 선택지 대기 · 반응 중 | `'온라인'` |
| `_WaitingBlock`(답이 없다) 카운트다운 중 | `'자리 비움'` |
| 거절한 전화 뒤 채팅(`missedCall`) | `'부재중'` |
| 그룹 대화(`name` 이 둘 이상 등장) | `'온라인 · N명'` (N = 이벤트 안 서로 다른 `them` 화자 수 + 나) |
| 통화 화면 | `ActiveCallView` 의 `'통화 중'`/`'통화 종료'` 그대로(이미 구현) |

- 상태 줄은 **항상 있다**(비워서 높이가 들썩이지 않게). AppBar 기본 높이 안에 두 줄이 들어가는지: `titleLarge`(18×1.34) + `labelSmall`(11.5×1.28) ≈ 39 < 56. 글자 1.3배에서 ≈ 51, 여전히 들어간다. `toolbarHeight` 를 늘리지 않는다.
- Semantics: `title` 을 `Semantics(label: '$name, $status')` 로 묶고 두 Text 는 `excludeSemantics`.
- 제목이 사라지는 것에 대한 보상: §1.5 구분줄이 대화 첫 줄에서 제목을 말한다. 정산·앨범의 제목 노출은 변화 없음.
- 알림 카드(`NotificationCard`)·통화 헤더(`ActiveCallView`)는 이미 "아바타 + 이름" 이 카드 **안**에 있으므로 손대지 않는다. 테스터 지적은 AppBar 에 한정된다.

## 3. 배너 상단 이동 — `BannerSlot`, `BannerFrame`

채팅 화면(`EventScreen`)은 **계속 배너 없음**(`ad_manager.dart` 주석의 우발 클릭 정책). 통화·알림 화면도 없음.

### 3.1 자리

| 화면 | 현재 | 변경 |
|---|---|---|
| 홈 `home_screen.dart` | `bottomNavigationBar` | `body: SafeArea(child: Column([BannerSlot(edge: top, safeArea: false), Expanded(ListView)]))` — 헤더 줄(44) **위** |
| 행동 `action_screen.dart` | 〃 | `body: Column([BannerSlot(edge: top, safeArea: false), Expanded(ListView)])` — AppBar 바로 아래 |
| 정산 `summary_screen.dart` | 〃 | 〃 |
| 앨범 `album_screen.dart` | 〃 | `body: Column([BannerSlot(...), Expanded(TabBarView)])` — **TabBar 아래**, 탭을 바꿔도 고정 |
| 설정 `settings_screen.dart` | 〃 | 〃 |

- `safeArea: false` 인 이유: AppBar 가 있는 화면은 상단 인셋을 AppBar 가 먹었고, 홈은 `SafeArea` 가 이미 감싼다. 배너 틀이 다시 SafeArea 를 두르면 홈에서 인셋이 두 번 들어간다.
- `bottomNavigationBar` 는 다섯 화면 모두 제거. `BannerFrame` 의 "느슨한 제약" 주석은 `Column` 안에서는 해당 없지만, `Expanded` 가 본문을 잡으므로 `layout_test` 의 "본문 높이 > 400" 검증은 `Column` 버전으로 옮겨 다시 쓴다.

### 3.2 틀(`BannerFrame`) 모양 — `edge` 매개변수 추가

| 속성 | `edge: bottom`(현재) | `edge: top`(신설) |
|---|---|---|
| 바깥 여백 | `margin.top: sm` | `margin.bottom: sm` |
| 경계선 | 위 `outlineVariant` `hairline` | **아래** `outlineVariant` `hairline` |
| 배경 | `surfaceContainerLow` | 같음 |
| 안쪽 | 세로 `sm`, 광고 `Center` | 같음 |
| 높이 | `AdSize.banner` 50 + `sm`×2 + `hairline` | 같음. 광고 없으면 **0**(현재 규칙 유지) |

- 적응형 배너(`AdSize.getAnchoredAdaptiveBannerAdSize`)는 이번엔 쓰지 않는다. 높이가 화면마다 달라져 §2.1 높이 예산이 흔들린다.
- 높이 예산(§2.1): 320×568·1.3배·배너 있음에서 1차 버튼 하단 ≤ 568 — 배너 총 높이가 그대로라 예산은 변하지 않는다. 다만 위에서 밀리므로 히어로 카드가 아니라 **1차 버튼**이 잘리는 쪽이 된다. HOME_REDESIGN §1.5 표는 "배너 위" 로 행만 바꾼다.
- 로드되는 순간 본문이 66pt 내려앉는다. `AnimatedSize(duration: AppMotion.base(context))` 로 감싸 덜컥임을 줄이고, 축소 모션에선 즉시.

### 3.3 룰렛 시트 · 다이얼로그와의 공존

- 룰렛(`RouletteSheet.show`, `isDismissible: false`)과 `showAppDialog` 는 모달 라우트라 스크림(`scrimColor`)이 배너까지 덮는다. **그대로 둔다.** 스크림 아래 배너는 탭이 안 되고(모달 배리어), 배너를 스크림 위로 띄우는 것이 오히려 "겹침" 정책 위반이다.
- 시트·다이얼로그 **안**에 배너를 넣지 않는다. 룰렛 시트는 `isScrollControlled` 내용 높이라 배너와 세로 경쟁이 없다.
- 시트가 닫히는 순간 손가락 아래에 배너가 오면 우발 클릭이다. 룰렛의 `'시작'` 버튼은 시트 하단이고 배너는 화면 최상단이라 겹치지 않는다. 설정의 초기화 다이얼로그 버튼도 화면 중앙이라 무관.
- 홈의 헤더 설정 아이콘(44) 은 배너 바로 아래로 온다. 배너 `margin.bottom: sm` + 헤더 줄이 있으니 광고와 아이콘 사이는 `sm` 이상. 충분하지만 실기기에서 한 번 확인한다.

## 4. 풀스크린 "D+N" 날짜 카드 — 신규 `lib/ui/day_card.dart`

정산 `'다음 날로'` → (전면 광고) → **`DayCard`** → `c.endDay()` → 행동 화면 → 룰렛 시트. 호출은 `summary_screen.dart` 버튼 핸들러에서 `await showDayCard(context, day: s.day + 1, chapter: ((s.day) ~/ c.config.chapterLength) + 1)` 뒤 `endDay()`. `'엔딩 보기'`(마지막 날)면 카드 없음.
룰렛은 `ActionScreen` 의 post-frame 에서 뜨므로 카드가 **완전히 닫힌 뒤** `endDay()` 를 불러야 시트가 카드 위로 올라오지 않는다.

### 4.1 화면

`CallBackdrop` 재사용(항상 다크, `violet900 → surface` 그라데이션, 상태바 밝은 글자). 전화·알림과 같은 "밤의 사건" 톤으로 하루가 넘어간다.

가운데 정렬 `Column`(위→아래), 전체가 탭 대상(`GestureDetector` + `Semantics(button, label: 'D+N N일째, 탭해서 건너뛰기')`):

| 순서 | 내용 | 스타일 |
|---|---|---|
| 1 | 장 pill `'N장'` | `surfaceContainerHigh` `rPill`, 안쪽 `AppInsets.chip`, `labelMedium` `onSurfaceVariant` |
| | `md` | |
| 2 | `'D+N'` | `displayLarge`(40/700) 을 `AppTypography.tabular` 로, 색 `onSurface`. **displayLarge 의 첫 사용처**(§1.7 "(예비)" 해제) |
| | `sm` | |
| 3 | `'N일째 · 수요일'` | `titleMedium` `onSurfaceVariant`. 요일은 표현 전용: `['월','화','수','목','금','토','일'][(day - 1) % 7] + '요일'`. 엔진에 요일 개념을 넣지 않는다 |
| | `xxxl` | |
| 4 | `'탭해서 건너뛰기'` | `labelMedium` `onSurfaceVariant`, `ExcludeSemantics`(버튼 라벨이 이미 말한다) |

- 날씨·장 이름(OVERHAUL §2B) 은 데이터가 없다. `subtitle: String?` 슬롯만 두고 null 이면 3번 줄만 그린다. 나중에 `config.json` 에 장 제목이 생기면 pill 문구가 `'2장 · 제목'` 이 된다.
- 첫날(D+1): 정산에서 오지 않는다. 새 회차 시작(캐스트 소개 → 첫 행동 화면 진입) 직전에 같은 위젯을 `subtitle: '첫날'` 로 한 번 띄운다. 이어하기에는 띄우지 않는다.
- 좌우 여백 `screenX`. 글자 1.3배에서 `displayLarge` 52pt — 320pt 폭에 `D+120` 이 들어간다. 세로는 `CenteredScrollColumn` 으로 감싼다.

### 4.2 모션 — §1.10 과의 합의

| 단계 | 값 | 축소 모션 |
|---|---|---|
| 진입 | 바탕 페이드 `AppMotion.slow(context)` `standard`; `D+N` 은 불투명도 0→1 + `Transform.scale` 0.92→1, 같은 시간, `emphasized` 아님(`standard`) | `Duration.zero` → 즉시 표시 |
| 체류 | **`DayCard.beat = 1400ms`** 상수. 룰렛 `_spinBeat` 와 같은 이유(연출이 아니라 게임의 박자, 테스트가 기다리는 시간)로 `AppMotion` 단계가 아니다 | **유지**(1.2~1.6초 안). 탭으로 건너뛰기는 항상 가능 |
| 퇴장 | 페이드 `AppMotion.base(context)` | 즉시 |
| 탭 | 진입·체류 어디서든 즉시 퇴장 단계로 | 같음 |

OVERHAUL 의 "동작 줄이기면 페이드만" 은 §1.10 규칙(context 버전은 0 을 돌려준다)과 어긋난다. **§1.10 이 이긴다**: 축소 설정에서는 페이드도 없이 카드가 켜졌다 1.4초 뒤 꺼진다. 흔들림·스케일은 생략. 이 결정을 §1.10 에 한 줄로 남긴다(§6).

라우트: `PageRouteBuilder(opaque: true, transitionDuration: AppMotion.slow(context), reverseTransitionDuration: AppMotion.base(context))` + `FadeTransition`. `barrierDismissible` 아님(탭은 카드 자신이 받는다). 뒤로가기 제스처는 막지 않되 pop 되면 건너뛴 것으로 친다.

## 5. 구현 체크리스트 (파일 · 클래스)

1. `design_system.dart`: `AppSize`(§6 §1.11), `AppMotion.dLoop` + `loop(context)`.
2. `widgets.dart`: `ChatBubble` 에 `characterId`·`showAvatar`·`meta` 추가, 이름 옆 점 제거, 3열 Row; `BannerFrame.edge`, `BannerSlot.edge`; `ChatDivider`, `TypingIndicator`, `ChatMeta`, `StickerBubble`(에셋 없으면 빈 위젯).
3. `event_screen.dart`: `_header` 축소(§2), `_speakerIdFor`, 가짜 시계(§1.4), `_TypingBubble` → `TypingIndicator`, `ChatDivider` 를 목록 첫 항목으로, `_MissedCall` 은 그 다음.
4. `home/action/summary/album/settings_screen.dart`: `bottomNavigationBar` 제거, `body` 를 `Column` 으로(§3.1).
5. `day_card.dart` 신규 + `summary_screen.dart` 버튼 핸들러(§4).
6. 테스트: `event_screen_test`(`'…'` 하나·`'태현'` 여럿 유지, 아바타 `CharacterAvatar` 가 첫 줄에만 있는지), `layout_test` 배너 `Column` 버전, `day_card_test`(탭 건너뛰기·1.4초 자동·축소 모션 즉시).

## 6. DESIGN_SYSTEM.md 갱신 목록 (대체 문안)

**§1.7 타이포 표** — `displayLarge` 행 "쓰는 곳" `(예비)` → `날짜 카드 'D+N' (tabular)`. 한글 규칙의 tabular 목록에 `날짜 카드 D+N, 채팅 시각` 추가.

**§1.10 모션 표** — 행 추가: `| dLoop | 900ms | 타이핑 표시 깜빡임(반복). 축소 설정에서는 정지 |`. 표 아래 문단 끝에 추가:
> **박자와 모션의 구분**: 룰렛 릴(1.4초)·날짜 카드 체류(1.4초)처럼 "얼마나 머무는가" 는 모션이 아니라 게임의 박자다. 상수로 두고 축소 설정에서도 줄이지 않는다. 대신 그 사이의 진입·퇴장 연출만 `Duration.zero` 가 된다. 사용자는 언제나 탭으로 건너뛸 수 있어야 한다.

**§1.11 (신설) 치수 (`AppSize`)** —
> 4 배수 고정 치수. 간격(§1.8)이 아니라 요소의 크기다.
> `| avatarSm | 32 | 홈 신호 줄 | avatarMd | 40 | 채팅 아바타, 알림 카드, 통화 헤더 | avatarLg | 56 | 캐스트 카드(320pt) | avatarXl | 72 | 캐스트 카드 | sticker | 120 | 채팅 스티커 한 변 | banner | 50 | AdSize.banner 높이 |`
> `CharacterAvatar.size` 는 이 네 값만 받는다.

**§2 공통 문단** — "하단 `BannerSlot` 이 있는 화면은…" →
> 배너는 **화면 상단**(AppBar 바로 아래, 홈은 헤더 줄 위)에 `BannerSlot(edge: top)` 으로 둔다. 광고가 없을 때 높이 0. 채팅·통화·알림 화면에는 두지 않는다(우발 클릭 정책). 시트·다이얼로그 안에도 두지 않는다. 모달의 스크림이 배너를 덮는 것은 정상이다.

**§2.1 홈 구성** — "구성(위→아래, `ListView`, …): 헤더 줄" 앞에 `BannerSlot(top) → ` 삽입. 높이 예산 문장의 "배너 있음" 은 유지, "1차 버튼 하단 ≤ 568" 그대로.

**§2.2 행동 · §2.4 정산 · §2.6 앨범** — 구성 줄의 `AppBar(...) →` 다음에 `BannerSlot(top) →` 삽입(앨범은 `TabBar` 다음). 설정은 §4.1 표에 행 추가: `| 설정 배너 | AppBar 아래 BannerSlot(top), 행 목록은 그 아래 |`.

**§2.3 채팅** — 말풍선 두 항목과 "헤더 구분점" 문단을 다음으로 교체:
> - 상대 줄은 3열: `CharacterAvatar(avatarMd)`(묶음 첫 줄만, 그 뒤는 같은 폭 빈 칸) → `sm` → 이름(`labelSmall`, 강조색, 첫 줄만, 색 점 없음) + 말풍선 → `xs` → 메타(시각 `labelSmall` tabular `onSurfaceVariant`, 묶음 마지막 줄만; 내 말엔 그 위에 `읽음` `systemLine`). 내 줄은 반전, 아바타 없음. 말풍선 최대 폭 화면 72%, 같은 사람 연속 `xs`, 사람 바뀌면 `md`. 꼬리는 마지막 말풍선에만.
> - 아바타의 `characterId` 는 `Line.name` → 캐스트 id 역산, NPC 는 이니셜(중립색), `'모르는 번호'` 는 실루엣. 강조색은 이름 글자와 아바타 테두리에만.
> - 대화 첫 항목은 `ChatDivider('D+N · 제목')`(sys pill 모양). 이벤트 제목은 여기 한 번만 나온다.
> - 타이핑: 다음 줄이 `them` 이면 아바타 + 상대 말풍선 안 `'…'`(`dLoop` 깜빡임, 축소 설정은 정지), `narr/sys` 면 `CallTyping`.
> - 스티커(`Line.sticker`): 말풍선 뒤 `xs`, `AppSize.sticker` 정사각, 배경 없음, 에셋 없으면 그리지 않음.
> - AppBar: 이름 `titleLarge` + 상태 `labelSmall onSurfaceVariant`(`온라인`/`자리 비움`/`부재중`/`온라인 · N명`) 두 줄. 아바타·제목·D+N 없음. `bottom` 진행 막대 유지. 독백 이벤트는 제목이 이름 자리.

**§2.3.1 사진 문단** — 끝에 추가: `사진·스티커도 아바타 열 다음 본문 열에 놓이고 메타 열은 마지막 요소 아래 끝에 붙는다.`

**§2.7 룰렛** — 항목 추가: `상단 배너와 겹치지 않는다. 시트는 화면 아래에서 내용 높이만큼, 스크림이 배너를 덮는다.`

**§2.13 (신설) 날짜 카드 (`day_card.dart`)** — 본 문서 §4.1·§4.2 표를 그대로 옮긴다(장 pill → `md` → `D+N` displayLarge tabular → `sm` → `N일째 · 요일` titleMedium → `xxxl` → `탭해서 건너뛰기`; 체류 1.4초 상수, 축소 설정은 진입·퇴장 즉시).

**§3.1 시그니처** — `ChatBubble` 에 추가:
```dart
  /// 아바타 초상화를 찾을 캐릭터 id. null 이면 이니셜(NPC).
  final String? characterId;
  /// 묶음 첫 줄에 아바타를 그릴지. false 면 같은 폭의 빈 칸(연속 줄).
  final bool showAvatar;
  /// 메타 열. null 이면 빈 칸. (time: '오후 9:14', read: true → '읽음')
  final ChatMeta? meta;
```
`BannerSlot`·`BannerFrame` 에 `final BannerEdge edge; // top | bottom` 추가. `CharacterAvatar.size` 주석을 `AppSize.avatar*` 로.

**§3.2 새 컴포넌트** — 추가:
```dart
class ChatDivider extends StatelessWidget { final String text; }          // sys pill 모양의 구분줄
class ChatMeta { final String? time; final bool read; }                   // 말풍선 옆 시각·읽음
class TypingIndicator extends StatelessWidget { name, characterId, accent, showAvatar, isFirstOfGroup } // Text('…') 한 개 고정
class StickerBubble extends StatelessWidget { final String characterId; final String emotion; final bool mine; }
/// day_card.dart
class DayCard extends StatefulWidget { day, chapter, subtitle, onDone; static const beat = Duration(milliseconds: 1400); }
Future<void> showDayCard(BuildContext context, {required int day, required int chapter, String? subtitle});
```

**§4.1 고정 문구 표** — 행 추가: `| 채팅 헤더 | 상태 줄 '온라인' / '자리 비움' / '부재중', 타이핑 '…' 정확히 한 개 |`, `| 날짜 카드 | 'D+N' 단일 Text, 'N일째' 를 포함한 Text, '탭해서 건너뛰기' |`, `| 채팅 구분줄 | 'D+N · 제목' 단일 Text |`.

**§4.3 트레이드드레스** — 항목 추가: `읽음 표기는 낱말 '읽음' 뿐이다. 숫자 배지("1")·프로필 사진 옆 시각 배치 등 특정 메신저의 읽음 표기 방식을 쓰지 않는다. 아바타 원형 + 이름 + 말풍선의 3열 구조는 메신저 일반 문법이라 허용한다.`

**§5 금지 목록** — 항목 추가: `13. 채팅·통화·알림 화면과 시트·다이얼로그 안의 배너. 배너는 §2 공통 자리 하나뿐이다.`
