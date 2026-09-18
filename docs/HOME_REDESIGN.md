# 모쏠 키우기 — 홈 v2 · 설정 · 다크 시트 · 돈 스탯 규격서

작성: UI 디자인 단계 (2026-09-18). 상위 규격: `docs/DESIGN_SYSTEM.md`(이하 DS).
이 문서는 프런트엔드 개발자가 **해석하지 않고 그대로** 구현하는 규격이다. 여기 없는 값은
DS 토큰 표에서만 가져온다. 둘 다에 없는 값이 필요하면 구현하지 말고 이 문서를 먼저 고친다.

근거가 된 실기기 캡처: `docs/screenshots/01_home.png`(휑한 홈), `02_roulette.png`(시트 구분),
`04_action.png`(돈 막대가 빈 채로 보임).

---

## 0. 범위와 데이터 계약

### 0.1 손대는 파일

| 파일 | 작업 |
|---|---|
| `lib/ui/home_screen.dart` | 전면 재작성 (§1) |
| `lib/ui/settings_screen.dart` | 신설 (§2) |
| `lib/ui/design_system.dart` | `bottomSheetTheme`, `dialogTheme` 값 변경 (§3) |
| `lib/ui/widgets.dart` | `StatBars` 돈 행 변경 (§4), 새 컴포넌트 6개 추가 (§5), `AppListRow` 매개변수 1개 추가 (§5.7) |
| `lib/main.dart` | Pretendard 라이선스를 `LicenseRegistry` 에 등록 (§2.4) |
| `docs/DESIGN_SYSTEM.md` | §2.1 교체, §3.2 추가 — 이 문서와 함께 이미 반영됨 |

건드리지 않는 것: 엔진, 컨트롤러의 게임 로직, 광고 로직, `BannerSlot`, 스토리 데이터,
`Stat.maxOf` (엔진 소속).

### 0.2 홈이 읽는 데이터 (리텐션 엔지니어와의 계약)

홈은 아래 값만 읽는다. 이름은 **제안**이며 리텐션 엔지니어가 다른 이름을 쓰면 홈 쪽에서
맞춘다. 단, **의미와 null 규칙은 그대로** 지켜야 한다.

| 값 | 타입 | 출처(제안) | null/기본 |
|---|---|---|---|
| `hasSave` | bool | `GameController.hasSave` (기존) | — |
| `summary` | `SaveSummary?` | `GameController.saveSummary` — 세이브 **파일만 읽어서** 만든 요약. `state` 를 복원하지 않아도 채워져 있어야 한다 | 세이브 없음 → null |
| `summary.run` | int | `GameState.run` | — |
| `summary.day` | int | `GameState.day` | — |
| `summary.totalDays` | int | `config.totalDays` (100) | — |
| `summary.chapter` | int | `GameState.chapter(config)` | — |
| `summary.lastCliffhanger` | String? | `GameState.lastCliffhanger` | 첫날 → null |
| `summary.topCharacterId` | String? | 호감 최고 캐릭터 id. 동점이면 `bundle.characters` 순서 | 전원 0 → null |
| `summary.topAffection` | int | 위 캐릭터의 호감 | 0 |
| `summary.affectionOf(id)` | int | 캐릭터별 호감 | 0 |
| `hearts` / `maxHearts` | int | `GameController.hearts`, `config.maxHearts` (5). **세이브 없으면 하트 줄을 그리지 않는다** | — |
| `nextHeartIn` | Duration | `GameController.nextHeartIn` | 만땅이면 `Duration.zero` |
| `meta.streakDays` | int | `PlayerMeta.streakDays` | 0 |
| `meta.checkedInToday` | bool | `PlayerMeta.lastCheckInDate == 오늘` | false |
| `meta.pendingHearts` | int | `PlayerMeta.pendingHearts` (세이브 없을 때 받은 하트) | 0 |
| `meta.rerollTickets` | int | `PlayerMeta.rerollTickets` | 0 |
| `claimCheckIn()` | `Future<CheckInResult>` | 출석 보상 수령. 결과: `hearts` (+1), `bonus` (연속 3일/7일 추가 보상 문구용, null 가능) | — |
| `endingAlbum` | `List<String>` | 기존 | 빈 리스트 |
| `bundle.endings` | `List<Ending>` | 기존. 30개, tier ∈ {happy 6, good 7, solo 3, bad 12, hidden 2} | — |
| `endingHint(Ending)` | String | `album_screen.dart` 의 `_hintFor` 를 **public 함수로 끌어올린다** (`endingHintFor(e, c)`). 홈과 앨범이 같은 문장을 쓴다 | — |

> 중요: 현재 `GameController.init()` 은 `hasSave` 만 세우고 `state` 는 `continueGame()` 때
> 복원한다. 그래서 지금 홈은 세이브가 있어도 D+N 을 못 그린다(`_Progress` 가 빈 상자를 돌려준다).
> 홈 v2 는 `saveSummary` 없이는 성립하지 않는다. 리텐션 엔지니어가 `init()` 에서
> `save.load()` 를 한 번 더 읽어 요약을 만들거나, `state` 를 미리 복원하는 것 중 하나를 해야 한다.
> 요약이 아직 null 인 프레임(앱 첫 프레임)은 §1.4 "요약 대기" 변형으로 그린다.

---

## 1. 홈 화면 v2 (`lib/ui/home_screen.dart`)

### 1.1 설계 원칙

- **첫 실행 사용자**: 3초 안에 "아침에 할 일 고르고, 밤에 톡 하고, 100일 뒤 엔딩" 이 읽혀야 한다.
  → 소개 카드 한 장(B-1)이 그 일을 한다. 장식 그림 없이 아이콘 + 한 줄 셋.
- **복귀 사용자**: "어젯밤 예고" 와 "출석 보상" 이 `이어하기` 를 누르게 한다.
  → 이어하기 카드(B-2)에 클리프행어, 그 바로 아래 출석 줄(D), 그 아래 1차 버튼(E).
  눈이 위에서 내려오다가 버튼에 닿는 순서다.
- **1차 버튼은 여전히 하나**. `이어하기` 또는 `새 게임`. 나머지는 전부 한 단 이상 뒤로.
- **상단 블록 높이 상한**: 320×568 · 글자 1.3배 · 배너 있음에서도 1차 버튼 하단이 568 안에
  들어온다 (§1.5 예산표). 이를 위해 헤더는 44, 하트 줄은 한 줄, 카드 본문 텍스트는 `maxLines` 를 건다.
- 기존 `_topSpace`(상단 40% 여백)와 `_RoseGlow` 는 **삭제**한다. 빈 공간으로 만든 "여백의 미" 가
  실제로는 휑함으로 읽혔다(01_home.png). 배경은 `scheme.surface` 단색.

### 1.2 화면 뼈대

```
Scaffold(
  backgroundColor: scheme.surface,           // 테마 기본. 그라데이션 없음
  body: SafeArea(
    child: ListView(                          // 세로 스크롤. 짧으면 스크롤 안 됨
      padding: EdgeInsets.fromLTRB(screenX 20, screenY 16, screenX 20, xxl 24),
      children: [ A, gap, B, gap, C?, gap, D, gap, E, sectionGap, F, sectionGap, G ],
    ),
  ),
  bottomNavigationBar: BannerSlot(),          // 그대로
)
```

블록 사이 간격은 §1.3 각 블록 끝에 적힌 "아래 간격" 을 쓴다. `ConstrainedBox(minHeight:)` 로
화면을 억지로 채우지 않는다 — 내용이 짧으면 아래가 비어도 된다(배너가 있어 실제로는 거의 안 빈다).

### 1.3 블록 목록과 규격

| # | 블록 | 컴포넌트 | 세이브 없음 | 세이브 있음 |
|---|---|---|---|---|
| A | 헤더 줄 | 홈 내부 `_Header` | 있음 | 있음 |
| B | 히어로 카드 | B-1 `_IntroCard`(홈 내부) / B-2 `ContinueCard`(공용) | B-1 | B-2 |
| C | 자원 줄 | `HeartsRow` + `TextButton.icon` (홈 내부 `_ResourceRow`) | **없음** | 있음 |
| D | 출석 줄 | `RewardStrip`(공용) | 있음 | 있음 |
| E | 1차 버튼 묶음 | `FilledButton`, `TextButton` | `새 게임` | `이어하기` + `새 게임` |
| F | 사람들 | `SectionHeader` + `CastStrip`(공용) | 있음(수치 없음) | 있음(♥N) |
| G | 앨범 | `AppCard(onTap)` + `EndingTierDots`(공용) | 있음 | 있음 |

세이브 있음에서 C 가 B 보다 **아래** 인 이유: 하트는 "지금 이어할 수 있나" 의 답이지 화면의
주인공이 아니다. 예고(B)가 먼저 마음을 잡고, 하트(C)와 출석(D)이 "지금 할 수 있다" 를 확인해 주고,
버튼(E)이 온다.

#### A. 헤더 줄 `_Header`

- 높이 **44** 고정(`SizedBox(height: AppSpace.minTouch)`). 글자 1.3배에서도 44 — 워드마크는
  `titleLarge`(18) 라 1.3배(23.4×1.34≈31)에서 44 안에 든다.
- 구성: `Row` → 좌측 `Text('모쏠 키우기', style: text.titleLarge)` → `Spacer` → 우측
  `IconButton(icon: Icons.settings_outlined, tooltip: '설정')` → `SettingsScreen` push.
- 워드마크 색 `onSurface`. 로즈로 물들이지 않는다(primary 는 버튼 몫).
- 아래 간격: `md` 12.

#### B-1. 소개 카드 `_IntroCard` (세이브 없음)

`AppCard(tone: AppTone.brand)` — 화면에서 `primaryContainer` 를 쓰는 유일한 면.

```
Column(crossAxisAlignment: start)
  Text('100일 프로젝트', labelSmall, color: onPrimaryContainer)            // 눈썹
  gap xs 4
  Text('100일 뒤, 이 남자는 달라져 있을까', headlineMedium, color: onPrimaryContainer,
       maxLines: 2, overflow: ellipsis)
  gap md 12
  _Step(Icons.wb_twilight,          '아침: 오늘 할 일 하나 고르기')
  gap sm 8
  _Step(Icons.chat_bubble_outline,  '밤: 메신저로 대화하기')
  gap sm 8
  _Step(Icons.auto_stories_outlined,'100일: 엔딩 30개 중 하나')
```

- `_Step` = `Row` → `Icon(size 18, color: onPrimaryContainer)` → `sm` 8 → `Expanded(Text(bodyMedium,
  color: onPrimaryContainer, maxLines: 1, overflow: ellipsis))`.
- 카드 패딩 기본(`AppInsets.card` 16). 그림자 없음(`raised: false`). 다크에서는 `primaryContainer`
  `#8C0F3A` 위에 `onPrimaryContainer` `#FFD9E2` — 대비 8.6:1.
- 아래 간격: `lg` 16.

#### B-2. 이어하기 카드 `ContinueCard` (세이브 있음) — 공용 컴포넌트 §5.4

```
AppCard(tone: neutral, accentStripe: scheme.tertiary)     // 클리프행어 카드와 같은 청록 띠
  Row
    Text('2회차 · 3장', labelMedium)                          // 회차 · 장
    Spacer
    Text('D+37 / 100', tokens.numericMedium)                 // tabular
  gap sm 8
  AppProgressBar(value: day/totalDays, height: 6(xs+2), semanticLabel: '진행도 37일 / 100일')
  gap md 12
  Row(crossAxisAlignment: start)
    Icon(Icons.bedtime_outlined, 18, color: scheme.tertiary)  // 위쪽 xxs 패딩
    gap md 12
    Expanded(Text('어젯밤: {lastCliffhanger}', bodyMedium, maxLines: 2, overflow: ellipsis))
  gap md 12
  Row
    CharacterAvatar(id: topCharacterId, name:, size: 32)
    gap sm 8
    Expanded(Text('서연 ♥42', labelMedium, color: onSurface, maxLines: 1))
    Text('가장 가까운 사람', labelSmall)                      // onSurfaceVariant
```

- `lastCliffhanger == null`(첫날 저장): 예고 줄 텍스트 = `'어젯밤: 아직 아무 일도 없었다. 오늘부터다.'`
  (라벨 `어젯밤:` 을 유지해 줄 모양이 흔들리지 않게 한다).
- `topCharacterId == null`(전원 호감 0): 마지막 Row 를 `Row(Icon(Icons.people_outline, 18,
  onSurfaceVariant), sm, Text('아직 아무와도 가까워지지 않았다', bodySmall))` 로 바꾼다.
  아바타를 회색으로 그리지 않는다 — "없음" 을 색으로 말하지 않는다.
- `'서연 ♥42'` 는 **하나의 Text** 로 유지한다(향후 테스트가 `textContaining('서연 ♥')` 로 찾을 수 있게).
- 아래 간격: `lg` 16.

#### C. 자원 줄 `_ResourceRow` (세이브 있음만)

```
Row
  Expanded(HeartsRow(hearts:, max:, nextIn:, showTimer: true))   // 기존 컴포넌트 그대로
  if (hearts < max) ...[
    gap sm 8,
    TextButton.icon(
      icon: Icon(Icons.play_circle_outline, 18),
      label: Text('광고로 +1'),
      onPressed: 리워드 광고 → 성공 시 c.grantHeart(), 실패 시 SnackBar('광고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.')
    ),
  ]
```

- `HeartsRow` 는 `Expanded` 안에서 타이머 텍스트가 `Flexible + ellipsis` 로 줄어들므로 320 폭에서
  한 줄을 유지한다. **Wrap 을 쓰지 않는다**(두 줄이 되면 §1.5 예산이 깨진다).
- 버튼 문구 `'광고로 +1'` 은 홈 전용 짧은 문구다. `Semantics(label: '광고 보고 하트 받기')` 를 붙인다.
  행동 화면 다이얼로그의 `'광고 보고 하트 받기'` 문구는 그대로 둔다(§4.1 고정).
- 하트 만땅: 버튼 없음, `HeartsRow` 가 타이머를 스스로 숨긴다. 줄 높이 44 유지.
- 아래 간격: `md` 12.

#### D. 출석 줄 `RewardStrip` — 공용 컴포넌트 §5.5

| 상태 | 배경/테두리 | 좌측 아이콘 | 제목(titleSmall) | 부제(bodySmall) | 우측 |
|---|---|---|---|---|---|
| 미수령 | `primaryContainer` / `primary` 1px | `Icons.card_giftcard`, `onPrimaryContainer` | `출석 보상 하트 +1` | `연속 {streakDays}일째` (streak 0 → `오늘부터 출석`) | `FilledButton(child: Text('받기'))` 높이 44(테마 52 를 `SizedBox(height: 44)` 로 감싸지 말고 `FilledButton.styleFrom(minimumSize: Size(64, 44))` — 컴포넌트 내부에서만 재정의, DS §5.7 예외 근거: 카드 안 보조 버튼) |
| 미수령 · 보너스 날(3일/7일) | 동일 | `Icons.redeem` | `연속 {n}일 보너스` | `하트 +1 · {bonus}` ({bonus} = 3일: 리텐션 엔지니어 정의 문구, 7일: `룰렛 재도전권 +1`) | `받기` |
| 수령 완료 | `surfaceContainerLow` / `outlineVariant` 1px | `Icons.check_circle`, `tokens.success` | `오늘 출석 완료` | `연속 {streakDays}일째 · 내일 또 +1` | 없음 |
| 수령 완료 · 세이브 없음 · pendingHearts>0 | 동일 | 동일 | `오늘 출석 완료` | `하트 +{pendingHearts} 은 새 게임을 시작하면 들어온다` | 없음 |

- 높이: `ConstrainedBox(minHeight: 56)`. 패딩 `AppInsets.cardTight`(16/12). 모서리 `AppRadius.rMd`.
- `받기` 탭 → `claimCheckIn()` → 성공 시 `AppMotion.base` 동안 배경이 `primaryContainer` →
  `surfaceContainerLow` 로 `AnimatedContainer` 전환, 아이콘 교체. 실패(이미 수령) → 그냥 수령 상태로.
- 하트가 만땅인데 미수령: **그래도 받을 수 있다**. 초과분 처리는 리텐션 엔지니어 규칙
  (`pendingHearts` 또는 버림)을 따르고 UI 는 관여하지 않는다. 부제에 `(하트가 가득하면 다음 회복 때 반영)` 같은
  설명을 **붙이지 않는다** — 설명이 길어지면 줄이 두 줄이 된다.
- 아래 간격: `md` 12.

#### E. 1차 버튼 묶음

```
세이브 있음:
  FilledButton(child: Text('이어하기'))                 // 폭 stretch, 높이 테마 52
  gap sm 8
  TextButton(child: Text('새 게임'))                    // 높이 테마 44, 색 onSurfaceVariant 로 낮춤
세이브 없음:
  FilledButton(child: Text('새 게임'))
```

- `새 게임`(세이브 있음)은 **OutlinedButton 에서 TextButton 으로 내린다**. 52 → 44 로 8 아끼고,
  2차 버튼이 1차와 같은 폭·같은 무게로 나란히 서지 않게 한다. 색은
  `TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant)` — 컴포넌트가 아닌 화면에서의
  재정의이므로 DS §5.7 에 예외로 적었다(홈 2차 버튼 한 곳).
- 세이브 있을 때 `새 게임` 확인 다이얼로그 문구·동작은 현재 코드 그대로
  (`'새 게임'` / `'진행 중인 회차가 지워집니다. 시작할까요?'` / `'취소'` / `'시작'`).
- 테스트 고정: `find.text('새 게임')`, `find.text('이어하기')` 가 각각 정확히 한 개. 다른 어떤 Text 도
  이 두 문구와 **정확히 같으면 안 된다**(부분 포함은 괜찮다).
- 아래 간격: `sectionGap` 24.

#### F. 사람들 `SectionHeader` + `CastStrip` — 공용 컴포넌트 §5.2, §5.3

- `SectionHeader(title: '사람들', trailing: Text('호감 순', labelMedium))`. 세이브 없음이면
  `title: '등장인물'`, trailing 없음.
- `CastStrip(entries: [...])` — 가로 스크롤 한 줄. 항목 폭 56, 항목 사이 `md` 12, 좌우 패딩 0
  (ListView 의 screenX 안에 들어감). 스크롤 힌트로 마지막 항목이 우측에서 살짝 잘려 보이면 좋지만
  강제하지 않는다.
- 정렬: 세이브 있음 → 호감 내림차순, 동점은 `bundle.characters` 순. 세이브 없음 → `bundle.characters` 순.
- 히든(도윤): `affectionOf('doyun') > 0` 이면 보통 항목, 아니면 **항상 맨 뒤**에 `mystery` 항목
  (이름 `'???'`, 아바타는 사람 실루엣 아이콘, 수치 없음). 세이브 없음에서도 `???` 로 보여 "여섯 번째가
  있다" 를 알린다.
- 항목 구성(세로): `CharacterAvatar(size 40)` → `xs` 4 → 이름 `labelSmall`(onSurface, maxLines 1) →
  `xxs` 2 → `♥N`(`tokens.numericSmall`) — 세이브 없음이면 이 줄 없음. `'♥N'` 은 이름과 **별개 Text**.
- 탭: v2 에서는 없음(`onTap: null`). 프로필 화면이 생기면 붙인다.
- 아래 간격: `sectionGap` 24.

#### G. 앨범 카드 `AppCard(onTap → AlbumScreen)` + `EndingTierDots` — §5.6

```
AppCard(onTap:)
  Row
    Icon(Icons.photo_album_outlined, 20, onSurfaceVariant)
    gap sm 8
    Expanded(Text('앨범  {n} / {m}', tokens.numericMedium))     // 공백 2개. 단일 Text. 테스트 고정
    Icon(Icons.chevron_right, 20, onSurfaceVariant)
  gap md 12
  EndingTierDots(counts: {happy: (2,6), good: (1,7), solo: (0,3), bad: (3,12), hidden: (0,2)})
  gap md 12
  Row(crossAxisAlignment: start)
    Icon(Icons.lightbulb_outline, 16, tokens.info)
    gap sm 8
    Expanded(Text('다음 엔딩 힌트 · {hint}', bodySmall, maxLines: 2, overflow: ellipsis))
```

- `{hint}` 선택 규칙: `bundle.endings` 순서로 훑어 **미획득이면서 tier ∉ {bad, hidden}** 인 첫 엔딩의
  `endingHintFor(e, c)`. 그런 엔딩이 없으면(해피·굿·솔로를 다 봤으면) 힌트 줄 대신
  `Text('남은 건 배드 엔딩과 히든뿐이다', bodySmall)`. 30개를 다 봤으면 `'모든 엔딩을 봤다'`.
- 엔딩 0개: 점이 전부 비고 힌트는 정상 노출(힌트가 첫 목표가 된다).
- 흑역사 수는 홈에 **넣지 않는다**(앨범 안에서 본다). 홈은 엔딩 컬렉션만.
- 아래 간격: 없음(ListView 하단 패딩 24).

### 1.4 상태 매트릭스

| 상태 | A | B | C | D | E | F | G |
|---|---|---|---|---|---|---|---|
| 첫 실행(세이브 없음, 엔딩 0) | ○ | B-1 | × | 미수령 `오늘부터 출석` | `새 게임` | 등장인물, 수치 없음, 도윤 `???` | 0/30, 점 전부 빈 것, 힌트 |
| 세이브 없음 · 엔딩 N>0 (회차 끝난 뒤) | ○ | B-1 | × | 상태대로 | `새 게임` | 등장인물 | N/30 |
| 세이브 있음 · 요약 대기(`summary == null` 인 첫 프레임) | ○ | B-2 를 `ContinueCard.placeholder()` 로: 눈썹 `'저장된 회차'`, 진행 막대 0, 예고 `'어젯밤: 불러오는 중…'`, 마지막 줄 생략 | 하트 줄 그리되 `hearts` 는 0 으로 두지 말고 **줄 자체를 생략** | ○ | `이어하기` + `새 게임` | ○ | ○ |
| 세이브 있음 · 하트 만땅 | ○ | B-2 | HeartsRow 만, 타이머·버튼 없음 | ○ | ○ | ○ | ○ |
| 세이브 있음 · 하트 부족(0~4) | ○ | B-2 | HeartsRow + 타이머 + `광고로 +1` | ○ | ○ | ○ | ○ |
| 세이브 있음 · 하트 0 | 위와 같음. `이어하기` 는 **비활성화하지 않는다** — 행동 화면에서 기존 "하트가 없어요" 다이얼로그가 처리 | | | | | | |
| 출석 미수령 / 수령 | — | — | — | §D 표 | — | — | — |
| 광고 미지원 환경(`AdManager.supported == false`) | — | — | `광고로 +1` 버튼 생략 | — | — | — | — |

### 1.5 높이 예산 — 320×568, 글자 1.3배, 배너 있음(50 + 위 8 + 아래 8 + 선 1)

| 항목 | 세이브 있음 · 출석 미수령 | 세이브 없음 |
|---|---|---|
| 상태바(SafeArea top) | 20 | 20 |
| ListView 상단 패딩 | 16 | 16 |
| A 헤더 | 44 | 44 |
| 간격 | 12 | 12 |
| B 카드 | B-2: 16 + 20(회차/D+N 줄) + 8 + 6 + 12 + 60(예고 2줄, 14.5×1.6×1.3≈30/줄) + 12 + 32 + 16 = **182** | B-1: 16 + 19(눈썹) + 4 + 78(헤드라인 2줄, 23×1.3×1.3≈39/줄) + 12 + 26×3 + 8×2 + 16 = **239** |
| 간격 | 16 | 16 |
| C 자원 줄 | 44 | — |
| 간격 | 12 | — |
| D 출석 줄 | 56 | 56 |
| 간격 | 12 | 12 |
| E 1차 버튼 하단 | 52 | 52 |
| **1차 버튼 하단 y** | **466** | **467** |
| 배너 | 67 | 67 |
| 합계 | 533 ≤ 568 ✓ | 534 ≤ 568 ✓ |

여유 34. `새 게임` 2차 버튼(8 + 44)은 세이브 있음에서 화면 밖(577)으로 밀려도 된다 — 요구는
1차 버튼까지다. **예고 `maxLines: 2`, 헤드라인 `maxLines: 2`, `_Step` `maxLines: 1` 을 빼면 이 표가
깨진다.** 위젯 테스트 `layout_test.dart` 의 "홈: … 시작 버튼이 첫 화면에 보인다" 는 배너 없는 조건이라
더 여유롭다.

### 1.6 테스트 고정 사항 (홈에서 지킬 것)

| 대상 | 조건 |
|---|---|
| `'새 게임'` | 정확히 이 문구의 Text 하나. 세이브 없으면 FilledButton, 있으면 TextButton |
| `'이어하기'` | 세이브 있을 때만, 정확히 하나, FilledButton |
| `'앨범  N / M'` | 공백 두 개, 단일 Text. `textContaining('앨범  1 /')` 로 찾는다 |
| 탭 타깃 | 모든 탭 대상 44×44 이상(`iOSTapTargetGuideline`) — `CastStrip` 항목은 탭이 없으므로 제외되지만 `IconButton`, `받기`, `광고로 +1` 은 44 확보 |
| 대비 | `textContrastGuideline` — 모든 텍스트 4.5:1. `primaryContainer` 위 글자는 반드시 `onPrimaryContainer` |

### 1.7 카피 표 (홈 전체)

| 위치 | 문구 |
|---|---|
| A 워드마크 | `모쏠 키우기` |
| A 설정 툴팁 | `설정` |
| B-1 눈썹 | `100일 프로젝트` |
| B-1 헤드라인 | `100일 뒤, 이 남자는 달라져 있을까` |
| B-1 단계 1/2/3 | `아침: 오늘 할 일 하나 고르기` / `밤: 메신저로 대화하기` / `100일: 엔딩 30개 중 하나` |
| B-2 회차 줄 | `{run}회차 · {chapter}장` |
| B-2 진행 | `D+{day} / {totalDays}` |
| B-2 예고 | `어젯밤: {lastCliffhanger}` / 첫날 `어젯밤: 아직 아무 일도 없었다. 오늘부터다.` / 대기 `어젯밤: 불러오는 중…` |
| B-2 최고 호감 | `{name} ♥{affection}` + 우측 `가장 가까운 사람` / 전원 0 `아직 아무와도 가까워지지 않았다` |
| C 충전 버튼 | `광고로 +1` (Semantics `광고 보고 하트 받기`) |
| C 실패 스낵바 | `광고를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.` |
| D | §1.3 D 표 |
| E | `이어하기` / `새 게임` |
| F 헤더 | `사람들` + `호감 순` / 세이브 없음 `등장인물` |
| F 히든 | `???` |
| G 제목 | `앨범  {n} / {m}` |
| G 힌트 | `다음 엔딩 힌트 · {hint}` / `남은 건 배드 엔딩과 히든뿐이다` / `모든 엔딩을 봤다` |

---

## 2. 설정 화면 (`lib/ui/settings_screen.dart` 신설)

### 2.1 뼈대

```
Scaffold(
  appBar: AppBar(title: Text('설정')),                     // 뒤로가기 자동
  body: ListView(
    padding: EdgeInsets.fromLTRB(screenX 20, screenY 16, screenX 20, xxl 24),
    children: [
      SectionHeader(title: '개인정보'),
      [행 1], listGap 8, [행 2],
      sectionGap 24,
      SectionHeader(title: '정보'),
      [행 3], listGap, [행 4], listGap, [행 5],
      sectionGap 24,
      SectionHeader(title: '데이터'),
      [행 6],
      xxl 24,
      Text('© 2026 모쏠 키우기', bodySmall, textAlign: center)
    ],
  ),
  bottomNavigationBar: BannerSlot(),                       // 설정에도 배너를 둔다(다른 화면과 동일)
)
```

모든 행은 `AppListRow`. 섹션에 행이 하나도 없으면(행 1 이 숨겨져 행 2 만 남는 경우는 있어도 0개는 없음)
섹션 헤더도 숨긴다.

### 2.2 항목 순서·문구

| # | 조건 | `title` | `subtitle` | `leading` | `trailing` | 탭 |
|---|---|---|---|---|---|---|
| 1 | `AdManager.instance.privacyOptionsRequired == true` 일 때만(`FutureBuilder`, 대기 중엔 숨김) | `개인정보 설정` | `광고 개인 맞춤 동의를 바꿉니다` | `Icon(Icons.shield_outlined)` | 기본 chevron | `AdManager.instance.showPrivacyOptions()` |
| 2 | 항상 | `개인정보처리방침` | `외부 브라우저에서 열립니다` | `Icon(Icons.policy_outlined)` | `Icon(Icons.open_in_new, 18)` | `AppLinks.privacyPolicy` 열기 (§2.3) |
| 3 | 항상 | `오픈소스 라이선스` | `사용한 라이브러리와 서체의 라이선스` | `Icon(Icons.description_outlined)` | chevron | `showLicensePage(context:, applicationName: '모쏠 키우기', applicationVersion: AppMeta.versionLabel)` |
| 4 | 항상 | `서체` | `Pretendard · SIL Open Font License 1.1` | `Icon(Icons.text_fields)` | `Text('OFL', labelMedium)` | 없음(`onTap: null`, `showChevron: false`) |
| 5 | 항상 | `앱 버전` | 없음 | `Icon(Icons.info_outline)` | `Text(AppMeta.versionLabel, tokens.numericSmall)` 예 `0.1.0 (1)` | 없음(`showChevron: false`) |
| 6 | 항상 | `저장 데이터 초기화` | `회차 · 하트 · 출석 · 엔딩 앨범이 모두 지워집니다` | `Icon(Icons.delete_outline)` | chevron | §2.5 확인 다이얼로그 |

- 행 6 은 `AppListRow(tone: AppTone.danger)` (§5.7 에서 추가하는 매개변수). 제목·leading 아이콘 색이
  `tokens.danger`. 배경은 그대로 `surfaceContainerLow` — 빨간 카드로 만들지 않는다.
- leading 아이콘은 전부 `size 22`, 색 `onSurfaceVariant`(행 6 만 danger). 행동 화면의 `_ActionGlyph`
  같은 원형 배경은 쓰지 않는다 — 설정은 게임 장면이 아니다.

### 2.3 상수·의존성

```dart
/// lib/app_meta.dart (신설)
abstract final class AppMeta {
  static const version = '0.1.0';          // pubspec 과 손으로 맞춘다. package_info_plus 도입 전까지
  static const build = '1';
  static const versionLabel = '$version ($build)';
}

abstract final class AppLinks {
  /// 배포 전 실제 URL 로 교체. placeholder 상태로 스토어에 올리지 않는다.
  static const privacyPolicy = 'https://example.com/mossol/privacy';
}
```

- 외부 링크는 `url_launcher` 를 `pubspec.yaml` 에 추가해 `launchUrl(uri, mode: LaunchMode.externalApplication)`.
  실패(`false` 반환) 시 `AlertDialog(title: '링크를 열 수 없어요', content: SelectableText(url),
  actions: [TextButton('닫기')])` — 사용자가 주소를 복사할 수 있게.
- `package_info_plus` 는 지금 넣지 않는다. 버전 상수 하나로 충분하고, 심사에 필요한 건 표기 자체다.

### 2.4 Pretendard 라이선스 등록 (`lib/main.dart`)

```dart
LicenseRegistry.addLicense(() async* {
  final text = await rootBundle.loadString('assets/fonts/Pretendard-LICENSE.txt');
  yield LicenseEntryWithLineBreaks(const ['Pretendard'], text);
});
```

`runApp` 전에 한 번. 그러면 행 3 의 라이선스 페이지에 Pretendard 가 포함되고, 행 4 는 "여기 있다" 를
알려 주는 표기 역할만 한다.

### 2.5 저장 데이터 초기화 확인 다이얼로그

```
AlertDialog(
  title: Text('저장 데이터를 지울까요?'),
  content: Text('진행 중인 회차, 하트, 출석 기록, 엔딩 앨범({n}개)과 흑역사가 모두 지워집니다. 되돌릴 수 없어요.'),
  actions: [
    TextButton(child: Text('취소')),
    FilledButton(
      style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
      child: Text('지우기'),
    ),
  ],
)
```

- `{n}` = `c.endingAlbum.length`. 0이면 `엔딩 앨범(0개)` 그대로 — 숫자가 있어야 "내 것이 지워진다" 가 실감난다.
- `지우기` 의 `styleFrom` 은 DS §5.7 예외(파괴적 확인 버튼 한 곳). 다른 곳에서 복제하지 않는다.
- 확인 후: `SaveService.clear()`, 엔딩 앨범 키 삭제, `MetaService` 초기화(리텐션 엔지니어의 `reset()`),
  `c.hasSave = false`, `c.endingAlbum = []`, `notifyListeners()`. 그리고 `Navigator.pop` 으로 홈 복귀 후
  `SnackBar(content: Text('저장 데이터를 지웠어요'))`.
- 취소·뒤로가기·바깥 탭은 전부 취소로 처리(`barrierDismissible` 기본값 유지).

---

## 3. 다크 바텀시트 · 다이얼로그 표면 수정 (`lib/ui/design_system.dart`)

### 3.1 문제

다크에서 시트 배경 `surfaceContainerLow #1E1519` 와 화면 `surface #161014` 의 명도차가 거의 없고,
스크림 50% 로 어두워진 뒤 화면(≈`#0B0809`)과도 한 단 차이라 시트가 "떠 있는 판" 으로 읽히지 않는다
(`02_roulette.png` 는 라이트라 괜찮아 보이지만 다크 실기기에서 재현됨).

### 3.2 규칙

**다크에서 떠 있는 표면(모달 시트·다이얼로그)은 화면 바탕보다 두 단 위(`surfaceContainerHigh`)를 쓴다.**
라이트는 종이 위에 종이라 한 단(`surfaceContainerLow`)으로 충분하다. 추가로 두 테마 모두 상단 1px
테두리를 둔다 — 라이트에서는 거의 안 보이지만 배너 프레임·하단 패널과 규칙이 같아진다.

### 3.3 `BottomSheetThemeData` — 이 값으로 교체

```dart
bottomSheetTheme: BottomSheetThemeData(
  backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
  modalBackgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
  surfaceTintColor: Colors.transparent,
  shadowColor: scheme.shadow,
  modalBarrierColor: scheme.scrim.withValues(alpha: isDark ? 0.62 : 0.48),
  elevation: 0,
  modalElevation: 0,
  showDragHandle: false,                       // 기본은 없음. 닫을 수 있는 시트만 호출부에서 true
  dragHandleColor: scheme.outline,             // outlineVariant → outline (다크 #9C868C, 바탕 대비 3.2:1)
  dragHandleSize: const Size(36, 4),
  clipBehavior: Clip.antiAlias,
  shape: RoundedRectangleBorder(
    borderRadius: AppRadius.sheet,
    side: BorderSide(color: scheme.outlineVariant, width: AppBorderWidth.hairline),
  ),
),
```

| 항목 | 라이트 | 다크 |
|---|---|---|
| 시트 배경 | `surfaceContainerLow` `#FFF4F4` (변경 없음) | `surfaceContainerHigh` `#2F2429` (← `#1E1519`) |
| 스크림 | `#000000` α 0.48 (← 0.50) | `#000000` α 0.62 (← 0.50) |
| 상단 테두리 | `outlineVariant` `#E0CFD3` 1px | `outlineVariant` `#4E3F44` 1px |
| 드래그 핸들(쓰는 시트만) | `outline` `#8C7A7F`, 36×4 | `outline` `#9C868C`, 36×4 |
| 그림자 | 없음 | 없음 |

- 룰렛 시트는 `enableDrag: false` 이므로 핸들을 계속 **안 쓴다**(DS §2.7 유지).
- 다크 시트 위 카드: 룰렛 `_SlotCard` idle 배경이 `surfaceContainerHigh` 인데 시트도 같은 색이 되므로
  **idle 카드 배경을 `surfaceContainerHighest`(`#3A2E33`) 로 한 단 올린다**(라이트는 `#EEE0E2`). 테두리
  `outlineVariant` 는 그대로. 결과 카드(성공/위험 컨테이너)는 변경 없음.
- 시트 안 `FilledButton`·`OutlinedButton` 은 변경 없음. `OutlinedButton` 배경 `surfaceContainerLowest`
  `#100A0E` 가 `#2F2429` 위에서 오히려 더 또렷해진다.

### 3.4 `DialogThemeData` — 같은 규칙 적용

```dart
dialogTheme: DialogThemeData(
  backgroundColor: isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
  surfaceTintColor: Colors.transparent,
  elevation: 0,
  shadowColor: scheme.shadow,
  shape: RoundedRectangleBorder(
    borderRadius: AppRadius.rLg,
    side: BorderSide(color: scheme.outlineVariant, width: AppBorderWidth.hairline),
  ),
  // titleTextStyle / contentTextStyle / actionsPadding / insetPadding 은 현재 값 유지
),
```

`showDialog` 의 `barrierColor` 는 기본값(`Colors.black54`, α 0.54)이라 시트와 다르다. 홈·행동·설정의
`showDialog` 호출에 `barrierColor: context.scheme.scrim.withValues(alpha: context.isDark ? 0.62 : 0.48)`
를 넘긴다. 세 곳뿐이므로 헬퍼 `showAppDialog<T>(context, builder)` 를 `widgets.dart` 에 만들어 쓴다(§5.8).

### 3.5 `BottomPanel`(이벤트 화면 하단 패널) — 이번엔 손대지 않는다

모달이 아니라 화면의 일부라 스크림이 없고, 상단 테두리 + `shadowSheet` 로 이미 구분된다.
다크에서도 여전히 흐릿하다는 QA 가 나오면 그때 `surfaceContainer`(한 단)로 올린다. 지금은 건드리지 않는다.

---

## 4. 돈 스탯 표시 (`StatBars`)

### 4.1 결정: **돈은 막대를 그리지 않는다. 숫자만.**

- 이유: 돈은 능력치가 아니라 **잔고**다. 상한(`Stat.maxOf` 9999)은 저장 안전장치이지 목표가 아니고,
  게임 안의 흐름(시작 30, 알바 +15, 지출 −5~−40, 이벤트 극단 ±450)에서 막대는 초반에 빈 채, 후반에
  의미 없는 길이로 보인다. 소프트 캡(예: 300) 막대도 검토했으나 "300 이 찼다" 는 정보가 결정에 쓰이지
  않고, 캡을 넘긴 뒤엔 다시 만땅 막대가 된다. 숫자 하나가 정확하다.
- `Stat.maxOf` 는 엔진이므로 **건드리지 않는다**. 세이브 호환·엔진 테스트에 영향이 없다.

### 4.2 `StatBars` 변경점

1. 기본 순서를 바꾼다: `keys ?? Stat.visible` → `keys ?? _defaultOrder` 로,
   `_defaultOrder = [charm, talk, esteem, sense, stress, money]`. 돈이 **맨 아래**로 간다.
   (`Stat.visible` 자체는 엔진 소속이라 그대로.)
2. 돈 행 바로 위에 구분선: `Padding(vertical: xs 4, child: Divider())` — 테마 `dividerTheme`(1px,
   `outlineVariant`). 막대 다섯 줄과 "잔고 한 줄" 이 다른 종류임을 형태로 말한다. `keys` 에 돈이
   없거나 돈이 첫 행이면 구분선도 없다.
3. 돈 행 레이아웃: 라벨 칸(아이콘 + `돈`, 다른 행과 같은 `labelW`) → `sm` 8 → `Expanded(SizedBox())`
   (막대 자리는 비운다, 트랙도 그리지 않는다) → `sm` 8 → 값 칸.
4. 값 칸: 절대값 `'$value'` 를 **`tokens.numericMedium`**(15/700) 으로 — 다른 행의 `numericSmall` 보다
   한 단 크다. 막대가 없는 만큼 숫자가 정보의 전부라서다. `compact` 에서도 `numericMedium`. 값 칸 폭은
   다른 행과 같은 `valueW` 를 쓴다(우측 정렬이 흔들리지 않게).
5. 변화량(`delta`)은 다른 행과 **완전히 같은 방식**: 화살표(14) + `signed(d)`(`numericMedium`,
   `deltaColor`) + `sm` + 절대값. 절대값 색은 변화량이 있으면 `onSurfaceVariant`, 없으면 `onSurface`
   (기존 규칙 그대로).
6. `Semantics(label: '돈 $value')` — `/ 9999` 를 읽지 않는다. delta 가 있으면 `value: '+15'`.
7. 애니메이션: 막대가 없으니 `TweenAnimationBuilder` 도 없다. 숫자는 즉시 바뀐다.

### 4.3 다른 화면과의 일관성

| 화면 | 돈 표기 | 변경 |
|---|---|---|
| 행동 화면 `StatBars(compact: true)` | `돈 ······· 30` (구분선 위, 숫자 15/700) | §4.2 적용으로 자동 |
| 정산 화면 `StatBars(delta:)` | `돈  ↑ +15  45` | 자동. 변화량 색·부호·화살표 3중 규칙 동일 |
| 룰렛 `_EffectChip` | `↑ 돈 +40` | 변경 없음 |
| 결과 패널 델타 칩 | `↑ 돈 +15` | 변경 없음 |
| `StatTile` | 돈에 쓰이지 않음 | 변경 없음 |

`Stat.label(money) == '돈'` 그대로. 단위(`원`, `만`)는 붙이지 않는다 — 이벤트 문구("길에서 주운 5만원" 이
+40)와 수치의 환율이 정해져 있지 않다.

---

## 5. 새 컴포넌트 · 변경 컴포넌트 API (`lib/ui/widgets.dart`)

DS §3.2 에 같은 시그니처가 추가되어 있다. 여기서는 시각 규격을 덧붙인다.

### 5.1 `CharacterAvatar`

```dart
/// 캐릭터 이니셜 원형. 실제 사진 대신 강조색 + 이름 첫 글자.
class CharacterAvatar extends StatelessWidget {
  final String name;          // 첫 글자를 쓴다. '서연' → '서'
  final CharacterAccent? accent;  // null → tokens.neutralAccent
  final double size;          // 32 | 40 | 56 만 쓴다
  final bool mystery;         // 히든 미해금. 글자 대신 Icons.person_outline
  const CharacterAvatar({super.key, required this.name, this.accent, this.size = 40, this.mystery = false});
}
```

| 상태 | 배경 | 테두리 1px | 내용 |
|---|---|---|---|
| 기본 | `accent.container` | `accent.base` | `name[0]`, `labelLarge` 700, 색 `accent.onContainer`. size 32 → `labelMedium` 700, size 56 → `titleLarge` 700 |
| mystery | `surfaceContainerHigh` | `outlineVariant` | `Icons.person_outline`, `size × 0.5`, 색 `lockedForeground` |

`Semantics(label: mystery ? '아직 만나지 않은 사람' : name)`. `ExcludeSemantics` 로 글자를 감싼다.

### 5.2 `CastEntry` (데이터)

```dart
class CastEntry {
  final String id;
  final String name;
  final int? affection;       // null 이면 ♥ 줄을 그리지 않는다(세이브 없음)
  final bool mystery;
  const CastEntry({required this.id, required this.name, this.affection, this.mystery = false});
}
```

### 5.3 `CastStrip`

```dart
/// 캐릭터 가로 한 줄. 정렬은 호출부가 끝내서 넘긴다.
class CastStrip extends StatelessWidget {
  final List<CastEntry> entries;
  const CastStrip({super.key, required this.entries});
}
```

- `SingleChildScrollView(scrollDirection: horizontal, clipBehavior: Clip.none)` 안에 `Row`.
  `ListView.builder` 를 쓰지 않는다(6개뿐이고 고정 높이가 필요 없어야 한다).
- 항목: `SizedBox(width: 56)` → `Column(min)`: `CharacterAvatar(40)` / `xs` / 이름 `labelSmall`
  `onSurface` `maxLines 1` `ellipsis` `textAlign center` / (`affection != null`) `xxs` / `'♥$affection'`
  `numericSmall`. 항목 간 `md` 12.
- mystery 항목: 이름 `'???'`, 색 `lockedForeground`, ♥ 줄 없음.
- 항목당 `Semantics(label: '$name 호감 $affection')`, mystery 는 `'아직 만나지 않은 사람'`.

### 5.4 `ContinueCard`

```dart
class ContinueCard extends StatelessWidget {
  final int run;
  final int chapter;
  final int day;
  final int totalDays;
  final String? cliffhanger;        // null → '아직 아무 일도 없었다. 오늘부터다.'
  final String? topName;            // null → '아직 아무와도 가까워지지 않았다'
  final int topAffection;
  final CharacterAccent? topAccent;
  const ContinueCard({...});
  /// 요약을 아직 못 읽은 첫 프레임용.
  const ContinueCard.placeholder({super.key});
}
```

시각 규격은 §1.3 B-2. `placeholder` 는 눈썹 `'저장된 회차'`, 우측 `'D+— / 100'` 대신 아무것도 없음,
막대 0, 예고 `'어젯밤: 불러오는 중…'`, 마지막 Row 생략.

### 5.5 `RewardStrip`

```dart
enum RewardStripState { unclaimed, unclaimedBonus, claimed }

class RewardStrip extends StatelessWidget {
  final RewardStripState state;
  final int streakDays;
  final String? bonusLabel;         // unclaimedBonus 에서 부제에 붙는 보너스 문구
  final int pendingHearts;          // 세이브 없음 · 수령 완료에서 0 보다 크면 부제가 바뀐다
  final Future<void> Function()? onClaim;  // unclaimed* 에서 필수
  const RewardStrip({...});
}
```

시각 규격·문구는 §1.3 D 표. 탭 대상은 `받기` 버튼만(줄 전체는 탭 불가 — 줄을 눌러 받게 하면
"뭘 눌렀는지" 가 불분명해진다).

### 5.6 `EndingTierDots`

```dart
/// 등급별 획득 점. 순서는 happy → good → solo → bad → hidden 고정.
class EndingTierDots extends StatelessWidget {
  /// tier → (획득, 전체)
  final Map<String, (int, int)> counts;
  const EndingTierDots({super.key, required this.counts});
}
```

- 등급 한 줄: `SizedBox(width: 32, Text(라벨, labelSmall))` → `sm` 8 → `Expanded(Wrap(spacing: xs 4,
  runSpacing: xs 4, children: 점 m개))` → `sm` 8 → `Text('n/m', numericSmall)`.
- 라벨: `해피` / `굿` / `솔로` / `배드` / `히든` (앨범 `_tier` 와 같은 낱말).
- 점: 지름 8. 획득 = `primary` 채움. 미획득 = `gaugeTrack` 채움 + `outlineVariant` 1px.
  히든 미획득은 미획득 점 대신 `Icons.lock_outline` 8 이 아니라 **같은 빈 점** — 8px 에 자물쇠는 안 읽힌다.
- 줄 간격 `xs` 4. 다섯 줄 합계 ≈ 76(글자 1.0), 배드 12개 점은 폭 140 에 다 들어간다(12×8 + 11×4 = 140).
  280 폭 화면에서 Wrap 은 한 줄에 그친다.
- `Semantics(label: '해피 엔딩 6개 중 2개, 굿 엔딩 7개 중 1개, …')` 를 컴포넌트 전체에 하나, 점들은 `ExcludeSemantics`.

### 5.7 `AppListRow` 변경 — `tone` 추가

```dart
class AppListRow extends StatelessWidget {
  // ... 기존 필드 ...
  /// danger 면 제목·leading 아이콘 색을 tokens.danger 로. 배경은 바꾸지 않는다.
  final AppTone tone;   // 기본 AppTone.neutral. neutral | danger 만 지원, 나머지는 neutral 로 취급
}
```

`locked` 가 true 면 `tone` 을 무시한다(잠금이 우선).

### 5.8 `showAppDialog` 헬퍼

```dart
Future<T?> showAppDialog<T>(BuildContext context, {required WidgetBuilder builder}) =>
    showDialog<T>(
      context: context,
      barrierColor: context.scheme.scrim.withValues(alpha: context.isDark ? 0.62 : 0.48),
      builder: builder,
    );
```

홈 `_confirmNewGame`, 행동 화면 `_start` 의 하트 다이얼로그, 설정 §2.5 가 이걸 쓴다.
`barrierDismissible` 등 다른 인자가 필요해지면 그때 추가한다.

---

## 6. 구현 순서와 검수

### 6.1 순서

1. `design_system.dart` §3 (테마 값만, 10분). 룰렛 idle 카드 색 한 줄.
2. `widgets.dart` §4 `StatBars` 돈 행 + §5.7 `AppListRow.tone` + §5.8 헬퍼. 기존 위젯 테스트 통과 확인.
3. `widgets.dart` §5.1~5.6 새 컴포넌트.
4. `settings_screen.dart` §2 + `app_meta.dart` + `main.dart` 라이선스 등록 + `url_launcher`.
5. `home_screen.dart` §1. 리텐션 엔지니어의 `saveSummary`/`PlayerMeta` 접근자가 아직 없으면
   홈 안에 `_HomeData` 어댑터를 두고 거기서만 컨트롤러를 만진다 — 이름이 바뀌어도 한 곳만 고친다.
6. `album_screen.dart` 의 `_hintFor` → `endingHintFor` public 승격.

### 6.2 검수 체크리스트

- [ ] 320×568 · 1.3배 · 라이트/다크에서 `이어하기`/`새 게임` 하단 ≤ 568 (배너 없음 조건은 테스트, 배너 있음은 시뮬레이터 iPhone SE 1세대로 눈 확인)
- [ ] `flutter test` 전부 통과. 특히 `layout_test`(탭 타깃·대비), `screens_test`(`'앨범  1 /'`), `flow_test`(`'새 게임'` 탭 → 다이얼로그)
- [ ] 다크 룰렛 시트: 시트가 뒤 화면과 두 단 이상 밝고, idle 카드가 시트보다 한 단 밝다
- [ ] 다크 `새 게임` 확인 다이얼로그: 배경 `#2F2429`, 테두리 보임
- [ ] 행동 화면 스탯: 돈이 맨 아래, 구분선 있음, 막대 없음, 숫자 15/700
- [ ] 정산 화면: 돈 변화량이 다른 행과 같은 열에 정렬
- [ ] 홈에서 `Colors.*`, `Color(0x…)`, `EdgeInsets.all(숫자)` 검색 결과 0
- [ ] 설정: 개인정보 설정 행은 UMP 가 required 일 때만. iOS 시뮬레이터(비EEA)에서는 안 보이는 것이 정상
- [ ] VoiceOver: 하트 줄, 진행 막대, 등급 점, 아바타에 라벨이 읽힌다
