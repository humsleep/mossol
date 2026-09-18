# 모쏠 키우기 — 디자인 시스템 규격서

작성: 아트 디렉션 단계 (2026-09-16). 구현 기준 파일: `lib/ui/design_system.dart`.

이 문서는 다음 작업자들이 **해석하지 않고 그대로 따르는** 규격이다. 여기에 없는 값을
화면에서 새로 만들지 마라. 필요하면 이 문서와 `design_system.dart` 를 먼저 고친다.

---

## 0. 시각 방향

**밤에 혼자 보는 화면.** 모쏠 키우기는 한밤중 침대에서 폰 하나로 남의 연애를 대신 사는
게임이다. 그래서 화면은 형광등 아래 사무용 앱이 아니라, 불 끈 방의 조명 같아야 한다.
라이트 모드는 **따뜻한 종이 흰색**(`#FFFAF9`) 위에 브랜드 로즈(`#C2295A`)가 한 점씩 찍히는
연서(戀書)의 톤이고, 다크 모드는 **자수정빛 잉크**(`#161014`) 위에 로즈가 조명처럼 떠오르는
톤이다. 구조는 메신저를 빌린다 — 세로 스크롤, 좌우 말풍선, 하단 고정 패널. 그러나 외형은
빌리지 않는다: **노란색 계열은 팔레트에서 완전히 배제**하고(경고 상태색 하나만 예외,
상태 표시에만 사용), 말풍선은 꼬리 삼각형 없이 한쪽 모서리만 각지게 깎은 형태이며,
상대 말풍선은 흰 배경에 실선 테두리 1px 로 "종이 카드" 처럼 보이게 한다. 닮아야 할 것은
**Duolingo·Finch 같은 1인 개발 게임의 명확한 위계와 큰 터치 타깃**, 그리고 **한국 웹소설
표지의 로즈-자수정 대비**다. 피해야 할 것은 카카오톡의 노랑/말풍선 트레이드드레스,
Material 3 기본 보라(seed 자동 생성 색), 회색 텍스트 남발, 그리고 그림자 남발로 만드는
가짜 깊이다. 깊이는 그림자보다 **표면 단계(surface tier)와 테두리**로 만든다.

한 줄 요약: **따뜻한 종이와 자수정 잉크 위의 로즈. 메신저의 구조, 게임의 위계, 노랑 없음.**

---

## 1. 토큰

### 1.1 꺼내 쓰는 법

```dart
final t = context.tokens;       // AppTokens (의미색·캐릭터색·그림자·숫자 스타일)
final scheme = context.scheme;  // ColorScheme
final text = context.text;      // TextTheme
final dark = context.isDark;    // 필요할 때만. 색 분기는 토큰이 이미 해 준다.
```

`context.tokens` 는 테마에 확장이 안 붙어 있어도 밝기에 맞는 기본값으로 떨어지므로
(`AppTokens.fallback`) 위젯 테스트가 자체 `ThemeData` 를 만들어도 터지지 않는다.

### 1.2 색 — ColorScheme 역할

| 토큰 | 라이트 | 다크 | 쓰는 곳 |
|---|---|---|---|
| `primary` | `#C2295A` | `#FF8CA8` | 주 버튼, 내 말풍선(라이트), 선택 상태, 콤보 활성, 진행 막대 |
| `onPrimary` | `#FFFFFF` | `#54001D` | primary 위 글자 |
| `primaryContainer` | `#FFD9E2` | `#8C0F3A` | 크리티컬 결과 배경, 강조 카드 |
| `onPrimaryContainer` | `#47041F` | `#FFD9E2` | 위 배경의 글자 |
| `secondary` | `#6B4BA8` | `#C9B0FF` | 보조 강조(힌트, 화술 계열), 서연 액센트와 같은 계열 |
| `tertiary` | `#0F6F73` | `#6FD8DC` | 클리프행어 카드, 정보성 강조 |
| `tertiaryContainer` | `#BEEFEA` | `#0C5450` | 클리프행어 카드 배경 |
| `error` | `#B3261E` | `#FFB4AB` | 실패, 스트레스, 잠금 경고 |
| `errorContainer` | `#FFDAD5` | `#93000A` | 실패 결과 패널 배경 |
| `surface` | `#FFFAF9` | `#161014` | 화면 바탕, AppBar |
| `onSurface` | `#1C1216` | `#F2E5E7` | 본문 1차 글자 |
| `onSurfaceVariant` | `#5B4A4F` | `#D4BFC5` | 본문 2차 글자 (회색 대신 **항상 이것**) |
| `surfaceContainerLowest` | `#FFFFFF` | `#100A0E` | 상대 말풍선, 카드 안의 카드 |
| `surfaceContainerLow` | `#FFF4F4` | `#1E1519` | 카드 기본 배경, 하단 패널, **라이트의** 바텀시트·다이얼로그 |
| `surfaceContainer` | `#FAEDEE` | `#241A1E` | 선택 안 된 옵션 |
| `surfaceContainerHigh` | `#F4E7E8` | `#2F2429` | 배지 바탕, 눌린 상태, **다크의** 바텀시트·다이얼로그(모달은 바탕보다 두 단 위) |
| `surfaceContainerHighest` | `#EEE0E2` | `#3A2E33` | 비활성 배경 |
| `outline` | `#8C7A7F` | `#9C868C` | 잠금 아이콘, 시스템 줄 |
| `outlineVariant` | `#E0CFD3` | `#4E3F44` | 카드·칩·말풍선 테두리 (1px 기본선) |
| `inverseSurface` / `onInverseSurface` | `#362A2D` / `#FBEEEF` | `#F2E5E7` / `#382D30` | 스낵바, 툴팁 |

시드 자동 생성은 쓰지 않는다. 위 값은 전부 손으로 정한 값이며 `ColorScheme(...)` 에
직접 박혀 있다.

### 1.3 색 — 의미색 (`context.tokens`)

| 토큰 | 라이트 | 다크 | 쓰는 곳 |
|---|---|---|---|
| `success` / `onSuccess` | `#2F7A4D` / 흰색 | `#79D29A` / `#07301A` | 스탯 상승, 성공 배지 |
| `successContainer` / `onSuccessContainer` | `#D5F0DF` / `#0C3A21` | `#13462B` / `#D5F0DF` | 성공 결과 패널 |
| `warning` / `warningContainer` | `#A85A00` / `#FFE2C4` | `#FFBE7A` / `#5A3100` | 흑역사 임박, 주량 경고. **상태 표시 전용** |
| `danger` / `dangerContainer` | `#B3261E` / `#FFDAD5` | `#FFB4AB` / `#93000A` | 실패, 스탯 하락, 스트레스 |
| `info` / `infoContainer` | `#3A5BC7` / `#DDE4FF` | `#A8BEFF` / `#223C96` | 규칙 안내, 미니게임 설명 |

**의미색은 절대 단독으로 뜻을 전하지 않는다.** 항상 부호(`+3`/`-2`), 아이콘, 또는 낱말을
함께 둔다. `tokens.deltaColor(good: ...)` 는 색만 주므로 호출부가 부호를 붙일 책임을 진다.

### 1.4 색 — 채팅·게임 장치 (`context.tokens`)

| 토큰 | 라이트 | 다크 | 쓰는 곳 |
|---|---|---|---|
| `chatBackground` | `#FFF4F4` | `#120C10` | 이벤트 화면 대화 영역 바탕 |
| `bubbleMine` / `onBubbleMine` | `#C2295A` / 흰색 | `#A32048` / `#FFE3EA` | 내 말풍선 |
| `bubbleTheirs` / `onBubbleTheirs` | `#FFFFFF` / `#1C1216` | `#262027` / `#F2E5E7` | 상대 말풍선 |
| `bubbleBorder` | `#E0CFD3` | `#4E3F44` | 상대 말풍선 테두리 1px |
| `narration` | `#5B4A4F` | `#D4BFC5` | `who == 'narr'` 지문 |
| `systemLine` | `#8C7A7F` | `#9C868C` | `who == 'sys'` 시스템 줄 |
| `heart` / `heartEmpty` | `#C2295A` / `#E0CFD3` | `#FF8CA8` / `#4E3F44` | 하트 게이지 |
| `comboIdle` / `onComboIdle` | `#F4E7E8` / `#5B4A4F` | `#2F2429` / `#D4BFC5` | 콤보 1~2 |
| `comboFire` / `onComboFire` | `#C2295A` / 흰색 | `#FF8CA8` / `#54001D` | 콤보 3+ (물올랐다) |
| `lockedForeground` | `#8C7A7F` | `#9C868C` | 잠긴 선택지 글자·아이콘 |
| `gaugeTrack` | `#EEE0E2` | `#3A2E33` | 모든 진행 막대의 트랙 |

### 1.5 색 — 스탯 (`tokens.statColor(key)`)

| 스탯 키 | 라벨 | 라이트 | 다크 | 아이콘(권장) |
|---|---|---|---|---|
| `charm` | 매력 | `#C2295A` | `#FF8CA8` | `Icons.auto_awesome` |
| `talk` | 화술 | `#6B4BA8` | `#C9B0FF` | `Icons.chat_bubble_outline` |
| `esteem` | 자존감 | `#0F6F73` | `#6FD8DC` | `Icons.self_improvement` |
| `sense` | 눈치 | `#3A5BC7` | `#A8BEFF` | `Icons.visibility_outlined` |
| `money` | 돈 | `#2F7A4D` | `#79D29A` | `Icons.payments_outlined` |
| `stress` | 스트레스 | `#B3261E` | `#FFB4AB` | `Icons.bolt` |

스탯 6개는 색만으로 구분하지 않는다. 라벨 텍스트가 이미 있으므로 색은 보조다.
`stress` 는 값이 **오르면 나쁜** 유일한 스탯이다 (`StatBars`, `StatTile` 의 `invert` 참고).

### 1.6 색 — 캐릭터 강조색 (`tokens.accentFor(id)`)

`CharacterAccent(base, container, onContainer)` 세 쌍으로 온다.

| id | 이름 | base (라이트) | base (다크) | 성격 |
|---|---|---|---|---|
| `seoyeon` | 서연 | `#6B4BA8` 자수정 | `#C9B0FF` | 건조한 선배 |
| `haneul` | 하늘 | `#0F6F73` 청록 | `#6FD8DC` | 시끄러운 알바 동료 |
| `jiwoo` | 지우 | `#B5442A` 산호 | `#FFA88F` | 위트 있는 소개팅 상대 |
| `minjae` | 민재 | `#3A5BC7` 인디고 | `#A8BEFF` | 온라인 친구 |
| `yeeun` | 예은 | `#3F6B3A` 풀잎 | `#A2D39A` | 초등 동창 |
| `doyun` | 도윤 | `#4A6572` 슬레이트 | `#9FBCCB` | 히든, 트레이너 |
| (없음) | — | `#5B4A4F` | `#D4BFC5` | `neutralAccent` |

노란색·금색 계열은 하나도 쓰지 않는다. 캐릭터 강조색은 **이름 옆 점, 칩 테두리,
말풍선 이름 색, 앨범 카드 좌측 띠** 에만 쓴다. 말풍선 배경색으로는 쓰지 않는다
(상대 말풍선 배경은 언제나 `bubbleTheirs`).

### 1.7 타이포그래피

서체: **Pretendard** (OFL 1.1) 번들. 굵기 4종(400/500/600/700). `fontFamilyFallback` 에
`Apple SD Gothic Neo` → `Noto Sans KR` → `Malgun Gothic` 을 명시했다.

| 역할 | TextTheme 키 | 크기/행간/자간/굵기 | 쓰는 곳 |
|---|---|---|---|
| 디스플레이 | `displayLarge` | 40 / 1.15 / −1.0 / 700 | (예비) |
| | `displayMedium` | 34 / 1.18 / −0.8 / 700 | 엔딩 등급 `S`~`F` |
| | `displaySmall` | 28 / 1.22 / −0.6 / 700 | 홈 타이틀 "모쏠 키우기" |
| 헤드라인 | `headlineLarge` | 26 / 1.26 / −0.5 / 700 | (예비) |
| | `headlineMedium` | 23 / 1.30 / −0.4 / 700 | 엔딩 이름, 미니게임 큰 수치 |
| | `headlineSmall` | 20 / 1.32 / −0.3 / 700 | 미니게임 결과 ("크리티컬!") |
| 타이틀 | `titleLarge` | 18 / 1.34 / −0.3 / 600 | AppBar 제목, 미니게임 제목, 시트 제목 |
| | `titleMedium` | 16 / 1.40 / −0.2 / 600 | 섹션 헤더, 결과 헤드라인 |
| | `titleSmall` | 14 / 1.42 / −0.1 / 600 | 작은 섹션 헤더, 탭 라벨, 리스트 제목 |
| 본문 | `bodyLarge` | 16 / 1.60 / −0.2 / 400 | 에필로그, 홈 부제, 긴 설명 |
| | `bodyMedium` | 14.5 / 1.60 / −0.15 / 400 | 기본 본문, 카드 내용 |
| | `bodySmall` | 12.5 / 1.50 / −0.1 / 400 | 보조 설명 (색은 `onSurfaceVariant`) |
| 라벨 | `labelLarge` | 15 / 1.30 / −0.1 / 600 | 버튼 |
| | `labelMedium` | 13 / 1.30 / 0 / 600 | 칩, 메타 정보 |
| | `labelSmall` | 11.5 / 1.28 / +0.1 / 600 | 배지, 가장 작은 라벨 |
| 숫자 | `tokens.numericSmall` | 12.5 / 600 / **tabular** | 스탯 값, 확률, 카운트 |
| | `tokens.numericMedium` | 15 / 700 / **tabular** | 하트 타이머, D+N, 정산 수치 |
| | `tokens.numericLarge` | 28 / 700 / **tabular** | 미니게임 큰 숫자 ("3잔"), 등급 |
| 말풍선 | `tokens.bubbleText` | 15 / 1.55 / −0.2 / 400 | 채팅 본문 전용 |
| 배지 | `tokens.badgeText` | 12.5 / 1.25 / −0.1 / 700 | 콤보·결과 배지 |

**한글 규칙**
- 큰 글자는 자간을 좁힌다(−0.3 ~ −1.0). 라틴 기준 기본 자간은 한글에서 헐렁해 보인다.
- 본문 행간은 **1.6 고정**. 대사·에필로그도 1.55 이상.
- 줄바꿈이 어색해지는 것을 막기 위해 `softWrap` 기본값을 유지하고, 말풍선·카드 폭을
  화면의 72% 이하로 제한한다.
- **tabular figures 를 쓰는 곳**: 스탯 막대 오른쪽 값, 하트 타이머(`MM:SS`), `D+N`,
  확률 `%`, 정산 변화량, 앨범 `N / 20`, 미니게임 점수·카운트다운. 줄마다 숫자 폭이
  달라지면 흔들려 보인다. 반대로 문장 안에 섞인 숫자(대사, 에필로그)는 tabular 를
  쓰지 않는다 — 문장에서는 비례 숫자가 더 자연스럽다.

### 1.8 간격 (`AppSpace`, `AppInsets`)

4 배수만 쓴다. 표에 없는 숫자를 화면에 적으면 리뷰에서 반려한다.

| 토큰 | 값 | 쓰는 곳 |
|---|---|---|
| `xxs` | 2 | 아이콘과 숫자 사이 미세 조정 |
| `xs` | 4 | 라벨과 값 사이 |
| `sm` | 8 | 리스트 항목 사이, 아이콘-텍스트 |
| `md` | 12 | 같은 묶음 안 요소 사이 (`gap`) |
| `lg` | 16 | 카드 안쪽 (`cardPad`), 패널 좌우 |
| `xl` | 20 | 화면 좌우 여백 (`screenX`) |
| `xxl` | 24 | 섹션 사이 (`sectionGap`) |
| `xxxl` | 32 | 히어로 블록 아래 |
| `huge` | 40 | 홈 타이틀과 버튼 묶음 사이 |
| `minTouch` | 44 | 터치 대상 최소 한 변 |

기본값: **화면 가장자리 20**, **카드 안쪽 16**, **요소 사이 12**, **리스트 항목 사이 8**,
**섹션 사이 24**. `AppInsets.screen / screenX / card / cardTight / panel / chip / bubble`
를 쓰고 `EdgeInsets.all(16)` 처럼 직접 쓰지 않는다.

### 1.9 모서리 · 테두리 · 그림자

| 토큰 | 값 | 쓰는 곳 |
|---|---|---|
| `AppRadius.xs` | 6 | 진행 막대, 말풍선 꼬리 쪽 모서리 |
| `AppRadius.sm` | 10 | 작은 배지, 텍스트 버튼 |
| `AppRadius.md` | 14 | 버튼, 리스트 행, 옵션 |
| `AppRadius.lg` | 20 | 카드, 다이얼로그, 패널 |
| `AppRadius.xl` | 28 | 바텀시트 상단, 히어로 카드 |
| `AppRadius.pill` | 999 | 칩, 콤보 배지, 하트 묶음 |
| `AppRadius.bubble(mine:)` | 18, 꼬리쪽 6 | 말풍선 |
| `AppBorderWidth.hairline` | 1 | 기본 테두리 (`outlineVariant`) |
| `AppBorderWidth.emphasis` | 2 | 선택·추천 상태 (`primary`) |
| `AppBorderWidth.focus` | 3 | 포커스 링 |
| `tokens.shadowCard` | y2 blur10 α6% / 다크 α25% | 카드 |
| `tokens.shadowRaised` | y6 blur18 | 떠 있는 요소, 강조 카드 |
| `tokens.shadowSheet` | y−6 blur28 | 바텀시트, 하단 패널 상단 |

**다크 모드에서는 그림자가 거의 보이지 않는다.** 모달 시트·다이얼로그는 다크에서 바탕보다 두 단 위
(`surfaceContainerHigh`) + 상단 1px 테두리, 스크림 α0.62(라이트 α0.48). 다크에서 깊이는 표면 단계
(`surfaceContainerLow` → `High`)와 `outlineVariant` 테두리로 만든다. 그래서 카드
elevation 은 다크에서 0, 라이트에서 1 이다. 그림자를 두 겹 이상 쌓지 마라.

### 1.10 모션 (`AppMotion`)

| 토큰 | 값 | 쓰는 곳 |
|---|---|---|
| `dInstant` | 90ms | 눌림 피드백 |
| `dFast` | 140ms | 색·불투명도 전환 |
| `dBase` | 220ms | 기본 진입/퇴장, 배지 변화 |
| `dSlow` | 320ms | 결과 패널, 카드 등장 |
| `dSheet` | 380ms | 바텀시트 |
| `standard` | `easeOutCubic` | 기본 |
| `emphasized` | `easeOutBack` | 콤보·배지 팝 |
| `gauge` | `easeInOutCubic` | 게이지 증감 |

**축소 모션 대응**: 화면에서는 반드시 `AppMotion.base(context)` 같은 context 버전을
쓴다. 시스템 "동작 줄이기"(`MediaQuery.disableAnimationsOf`)가 켜지면 `Duration.zero`
를 돌려주므로 애니메이션이 즉시 완료된다. 상수 버전(`dBase`)은 context 를 못 구하는
곳에서만. 반복 애니메이션(룰렛 릴, 스윕바)은 **게임 판정에 필요하므로 멈추지 않는다**.
대신 `AppMotion.curve(context)` 로 커브만 `linear` 로 낮추고, 깜빡임·흔들림
(shake, flash)은 축소 설정에서 완전히 생략한다.

---

## 2. 화면별 레이아웃 지침

공통: 세로 전용. 모든 화면은 `SafeArea` 안. 화면 좌우 여백 20. 하단 `BannerSlot` 이
있는 화면은 광고가 없을 때 높이 0 이어야 한다(현재 동작 유지).

### 2.1 홈 (`home_screen.dart`)

상세 규격은 `docs/HOME_REDESIGN.md` §1. 여기는 요약이다. 둘이 다르면 HOME_REDESIGN 이 맞다.

- **주인공**: 히어로 카드(첫 실행: 소개 카드 / 세이브 있음: 이어하기 카드)와 그 아래 1차 버튼 하나.
- **배경**: 헤더 워드마크, 자원 줄(하트), 출석 줄, 사람들 스트립, 앨범 카드. 설정은 헤더 우측 아이콘.
- 구성(위→아래, `ListView`, 패딩 20/16/20/24): 헤더 줄(높이 44, `모쏠 키우기` `titleLarge` + 설정
  `IconButton`) → `md` → 히어로 카드 → `lg` → [세이브 있음만] 자원 줄(`HeartsRow` + `광고로 +1`
  TextButton, 한 줄 고정) → `md` → 출석 줄(`RewardStrip`) → `md` → 1차 버튼(`이어하기` 또는 `새 게임`
  FilledButton) → [세이브 있음] `sm` + `새 게임` TextButton → `sectionGap` → `SectionHeader('사람들')`
  + `CastStrip` → `sectionGap` → 앨범 `AppCard(onTap)`(`'앨범  N / M'` 단일 Text + `EndingTierDots` +
  다음 엔딩 힌트).
- 세이브가 없으면 `새 게임` 이 1차 버튼 자리에 온다. 빈자리를 남기지 않는다.
- **상단 여백 40% 와 로즈 방사 그라데이션은 폐지.** 배경은 `surface` 단색. 빈 공간으로 만든 여백은
  실기기에서 휑함으로 읽혔다.
- 높이 예산: 320×568 · 글자 1.3배 · 배너 있음에서 1차 버튼 하단 ≤ 568. 이를 위해 카드 안 텍스트는
  전부 `maxLines` 를 건다(예고 2줄, 소개 헤드라인 2줄, 단계 1줄). 예산표는 HOME_REDESIGN §1.5.
- 캐릭터는 `CastStrip` 으로 호감 순 가로 한 줄. 히든(도윤)은 해금 전 `???` + 실루엣 아바타, 항상 맨 뒤.
- 화면당 `primaryContainer` 면은 하나: 첫 실행은 소개 카드, 세이브 있음은 미수령 출석 줄.

### 2.2 행동 선택 (`action_screen.dart`)
- **주인공**: "오늘 뭘 할까" 아래 행동 카드 목록.
- **배경**: 하트/콤보 줄, 스탯 막대, 관계 칩.
- 구성(위→아래): AppBar(`D+N  ·  N장`) → 상태 줄(`HeartsRow` + `ComboBadge`) → `md`
  → 클리프행어 카드(있을 때만, `tertiaryContainer`) → `lg` → `StatBars(compact: true)`
  → `sectionGap` → `SectionHeader('관계')` + 캐릭터 칩 Wrap → `sectionGap`
  → `SectionHeader('오늘 뭘 할까')` + 행동 `AppListRow` 목록(사이 `listGap`).
- `StatBars` 의 돈 행은 막대 없이 숫자(`numericMedium`)만, 맨 아래에 구분선 위로 둔다
  (HOME_REDESIGN §4). `Stat.maxOf` 는 손대지 않는다.
- 행동 행은 높이 최소 64, 제목 `titleSmall`, 설명 `bodySmall` 2줄까지, 우측 `chevron_right`.
  글자 1.3배에서 3줄이 되어도 깨지지 않도록 고정 높이를 주지 마라.
- 클리프행어는 하루의 감정 연결선이다. 좌측에 `tertiary` 3px 띠를 두고 라벨 "어젯밤:" 은
  같은 Text 안에 유지한다(테스트가 `textContaining('어젯밤:')` 로 찾는다).

### 2.3 채팅 이벤트 (`event_screen.dart`)
- **주인공**: 말풍선 흐름. 화면의 최소 45% 를 대화가 차지한다.
- **배경**: AppBar, 하단 패널의 껍데기.
- 대화 영역 배경은 `tokens.chatBackground` 로 화면 바탕과 **한 단 구분**한다.
- 말풍선: 최대 폭 화면의 72%, 세로 간격 같은 사람 연속 `xs`, 사람이 바뀌면 `md`.
  상대 이름은 첫 말풍선 위에만(`labelSmall`, 캐릭터 강조색). 꼬리는 마지막 말풍선에만.
- `narr` 지문은 좌우 여백 `xl`, 가운데 정렬 아님, `narration` 색, 이탤릭 유지.
- `sys` 줄은 가운데 정렬 pill(배경 `surfaceContainerHigh`, `labelSmall`, `systemLine`).
- 대기 중 "답이 없다" 줄은 pill 안에 카운트다운 숫자를 `numericSmall` 로. 그 아래
  광고 버튼은 TextButton.icon 유지.
- 하단 패널(`_ChoicePanel` / `_ResultPanel`): 배경 `surfaceContainerLow`, 상단에
  `tokens.shadowSheet`, 상단 모서리 `AppRadius.lg`, 최대 높이 화면의 55%(현재 값 유지),
  내부 스크롤. 결과 패널은 tone 에 따라 배경이 바뀐다
  (크리티컬 `primaryContainer` / 실패 `errorContainer` / 성공·기본 `surfaceContainerLow`).
- 선택지는 `ChoiceButton` 하나로 통일하되 **내부는 반드시 `OutlinedButton`** 이어야 한다
  (§4.1 테스트 고정 사항).

### 2.4 하루 정산 (`summary_screen.dart`)
- **주인공**: 오늘 바뀐 수치. 변화량이 가장 크게 읽혀야 한다.
- **배경**: 절대 수치, 하단 메타("흑역사 N개").
- 구성: AppBar(`D+N 정산`) → `StatBars(delta:)` → `sectionGap` →
  `SectionHeader('관계 변화')` + `StatTile` 목록 → 클리프행어 카드 → `xxl`
  → 1차 버튼(`다음 날로` / `엔딩 보기`) → `sm` → 메타 한 줄.
- 관계 변화는 문장 나열 대신 `StatTile`(라벨 / 값 / 부호+변화량) 로 정렬한다.
  라벨(`'서연 호감'`)과 변화량(`'+4'`)은 `StatTile(label:, delta:, good:)` 로 나눠 변화량을 앞세운다.
- 변화량은 색 + 부호 + 화살표 아이콘 3중으로 표시한다.

### 2.5 엔딩 (`ending_screen.dart`)
- **주인공**: 엔딩 이름(`headlineMedium`)과 등급 카드의 알파벳(`displayMedium` +
  `numericLarge` 계열 tabular).
- **배경**: 티어 라벨, 회차 메타, 버튼.
- 구성: 중앙 정렬 컬럼 → 티어 라벨(pill, `primary`) → `xs` → 엔딩 이름 → `lg`
  → 에필로그(`bodyLarge`, 행간 1.65) → `xxxl` → 등급 카드(`AppCard`, tone accent)
  → `xxl` → `N회차 시작`(Filled) → `sm` → `홈으로`(Text).
- 등급 카드는 화면에서 유일하게 `shadowRaised` 를 쓸 수 있는 요소다.
- 내용이 길면 `CenteredScrollColumn` 으로 감싸 1.3배 글꼴에서도 넘치지 않게 한다.

### 2.6 앨범 (`album_screen.dart`)
- **주인공**: 수집 진행도(상단)와 카드 목록.
- **배경**: 탭 바, 티어 라벨.
- 상단에 진행도 블록: `N / 20` (`numericMedium`) + `AppProgressBar`. 문자열
  `'2 / 20'`, `'1 / 30'` 형식을 그대로 유지한다(테스트 고정).
- 흑역사 카드: 좌측 번호 원형(`errorContainer`), 본문 `bodyMedium`, 카드 사이 `listGap`.
- 엔딩 카드: 획득이면 이름 + 에필로그 + 티어 pill(캐릭터/티어 색), 미획득이면 `???` +
  힌트, 전체 불투명도 낮추기 대신 **글자색만** `lockedForeground` 로. 자물쇠 아이콘 유지.
- 빈 상태는 `AppEmptyState` 로 통일한다(현재 private `_Empty` 를 대체).

### 2.7 룰렛 시트 (`roulette_sheet.dart`)
- **주인공**: 결과 슬롯 카드 하나.
- **배경**: 제목, 설명, 버튼.
- 시트 상단 모서리 `AppRadius.xl`, 배경은 테마 기본(라이트 `surfaceContainerLow`, 다크
  `surfaceContainerHigh`, 상단 1px `outlineVariant`), 드래그 핸들 없음
  (닫기 불가한 시트이므로 드래그 가능처럼 보이면 안 된다).
- 슬롯 카드 높이는 고정 132 대신 `minHeight: 132` 로 두고 글자 확대에 따라 늘어나게 한다.
- 결과 tone: 좋으면 `successContainer` + 상승 아이콘, 나쁘면 `dangerContainer` +
  하락 아이콘. 돌리기 전은 `surfaceContainerHighest` + `?` (시트 배경보다 한 단 위. 다크 시트가
  `High` 로 올라가면서 같이 올렸다).
- 회전 중에는 `dim` 상태를 불투명도 0.6 대신 **색 채도 낮춤 + 블러 없음** 으로 표현하고,
  축소 모션 설정에서는 중간 프레임 없이 결과만 보여 준다.

### 2.8 미니게임 (`minigames/*`)
- **주인공**: `child` 로 들어오는 놀이판. 상단 제목/설명은 2줄 이내로 물러난다.
- **배경**: 제목, 설명, 타이머.
- `MinigameScaffold` 가 구조를 전담한다: 제목 블록(패딩 `AppInsets.screenX` + 상단 `lg`)
  → 타이머(`AppProgressBar`, 남은 시간 30% 미만이면 `danger`) → 본문(`Expanded`)
  → 결과 블록.
- 결과 연출: 본문을 0.5 불투명도로 내리고 결과 배지를 띄운다. 배경색은
  크리티컬 `primaryContainer` / 성공 `surfaceContainerHigh` / 실패 `errorContainer`.
  **문구 `크리티컬!` / `성공` / `실패` 는 절대 바꾸지 않는다**(테스트 고정).
- 모든 탭 대상은 최소 44×44. 원형 버튼(`_RoundBtn` 류)은 지름 최소 64.
- 선택 목록은 `MinigameOption` 만 쓴다. 게임마다 `Container` + `BoxDecoration` 을
  새로 만들지 마라.

---

## 3. 공용 컴포넌트 규격

`lib/ui/widgets.dart` (게임 화면 공용) 와 `lib/minigames/minigame.dart` (미니게임 공용)
에 구현한다. **아래 시그니처를 그대로 구현한다.** 매개변수 추가·삭제가 필요하면 먼저
이 문서를 고친다.

### 3.1 기존 컴포넌트 (수정)

```dart
/// 채팅 말풍선. who 에 따라 4가지 모습(them/me/narr/sys).
class ChatBubble extends StatelessWidget {
  final Line line;
  final String partnerName;

  /// 상대 이름·꼬리에 쓸 캐릭터 강조색. null 이면 tokens.neutralAccent.
  final CharacterAccent? accent;

  /// 같은 사람이 연속으로 말하는 묶음의 첫 줄인지. 이름 표시 여부를 결정한다.
  final bool isFirstOfGroup;

  /// 묶음의 마지막 줄인지. 꼬리(각진 모서리) 여부를 결정한다.
  final bool isLastOfGroup;

  const ChatBubble({
    super.key,
    required this.line,
    required this.partnerName,
    this.accent,
    this.isFirstOfGroup = true,
    this.isLastOfGroup = true,
  });
}

/// 스탯 6개 막대. delta 가 있으면 값 옆에 변화량을 함께 보여 준다.
class StatBars extends StatelessWidget {
  final GameState state;
  final Map<String, int>? delta;

  /// true 면 행 높이와 글자를 한 단 줄인다(행동 화면 상단용).
  final bool compact;

  /// 보여 줄 스탯 키. null 이면 Stat.visible 전체.
  final List<String>? keys;

  const StatBars({
    super.key,
    required this.state,
    this.delta,
    this.compact = false,
    this.keys,
  });
}

/// 하트 게이지 + 다음 회복 타이머.
class HeartsRow extends StatelessWidget {
  final int hearts;
  final int max;
  final Duration nextIn;

  /// false 면 타이머 문구를 숨긴다(폭이 좁은 자리용).
  final bool showTimer;

  const HeartsRow({
    super.key,
    required this.hearts,
    required this.max,
    required this.nextIn,
    this.showTimer = true,
  });
}

/// 콤보(물오름) 배지.
class ComboBadge extends StatelessWidget {
  final int combo;
  final bool onFire;

  /// true 면 패딩과 글자를 한 단 줄인다(결과 패널 안쪽용).
  final bool dense;

  const ComboBadge({
    super.key,
    required this.combo,
    required this.onFire,
    this.dense = false,
  });
}

/// 배너 광고 자리. 광고가 없으면 높이 0 을 유지해야 한다.
class BannerSlot extends StatefulWidget {
  /// false 면 SafeArea 를 감싸지 않는다(이미 SafeArea 안일 때).
  final bool safeArea;

  const BannerSlot({super.key, this.safeArea = true});
}
```

```dart
/// 미니게임 껍데기.
class MinigameScaffold extends StatefulWidget {
  final String title;
  final String instruction;
  final Widget child;
  final MinigameResult? result;
  final VoidCallback? onFinished;

  /// 남은 시간 0.0~1.0. null 이면 타이머 숨김.
  final double? timeLeft;

  /// 본문 아래에 고정되는 조작부(예: "여기까지" / "한 잔 더").
  /// 스크롤과 함께 밀려 올라가면 안 되는 버튼은 여기에 둔다.
  final Widget? footer;

  /// 제목 우측 pill. 난이도에 영향을 주는 스탯을 알려 줄 때 쓴다. 예: '눈치 22'.
  final String? badge;

  const MinigameScaffold({
    super.key,
    required this.title,
    required this.instruction,
    required this.child,
    this.result,
    this.onFinished,
    this.timeLeft,
    this.footer,
    this.badge,
  });
}

/// 미니게임 선택 버튼의 상태.
enum MinigameOptionTone { neutral, correct, wrong }

class MinigameOption extends StatelessWidget {
  final String label;
  final String? sub;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  /// 좌측 아이콘·번호 등. 없으면 좌측 여백 없음.
  final Widget? leading;

  /// 우측 짧은 라벨(가격, 순서 등). numericSmall 로 렌더한다.
  final String? trailingLabel;

  /// 정답 공개 연출. correct 는 success, wrong 은 danger 테두리를 쓴다.
  final MinigameOptionTone tone;

  const MinigameOption({
    super.key,
    required this.label,
    this.sub,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
    this.leading,
    this.trailingLabel,
    this.tone = MinigameOptionTone.neutral,
  });
}
```

### 3.2 새 컴포넌트 (`lib/ui/widgets.dart` 에 추가)

```dart
/// 섹션 제목. 화면 안 묶음의 시작을 알린다.
class SectionHeader extends StatelessWidget {
  final String title;

  /// 우측 보조 텍스트(진행도 등). numericSmall 로 렌더한다.
  final String? trailingText;

  /// trailingText 대신 위젯을 넣을 때.
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailingText,
    this.trailing,
  });
}

/// 의미 톤. 색 + 아이콘 + 부호를 한 벌로 묶는다.
enum AppTone { neutral, success, warning, danger, info, brand }

/// 라벨 · 값 · 변화량을 한 줄로 보여 주는 타일. 정산·결과에서 쓴다.
class StatTile extends StatelessWidget {
  final String label;

  /// 절대값. 없으면 변화량만 보여 준다.
  final String? value;

  /// 부호를 포함한 변화량 문자열. 예: '+4', '-2'.
  final String? delta;

  /// delta 의 방향이 좋은지. null 이면 중립(회색)으로 둔다.
  final bool? good;

  final IconData? icon;

  /// 좌측 색 점에 쓸 색. 스탯이면 tokens.statColor(key).
  final Color? accent;

  const StatTile({
    super.key,
    required this.label,
    this.value,
    this.delta,
    this.good,
    this.icon,
    this.accent,
  });
}

/// 빈 상태. 아이콘 + 제목 + 설명 + (선택) 행동.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });
}

/// 결과 배지. 성공/실패/크리티컬을 색과 아이콘으로 동시에 알린다.
class ResultBadge extends StatelessWidget {
  final AppTone tone;

  /// 짧은 라벨. 미니게임에서는 '크리티컬!' / '성공' / '실패' 를 그대로 넘긴다.
  final String label;

  /// 한 줄 설명. 없으면 라벨만.
  final String? detail;

  /// null 이면 tone 에 맞는 기본 아이콘을 쓴다.
  final IconData? icon;

  /// true 면 배지를 가운데 정렬하고 라벨을 headlineSmall 로 키운다.
  final bool large;

  const ResultBadge({
    super.key,
    required this.tone,
    required this.label,
    this.detail,
    this.icon,
    this.large = false,
  });
}

/// 진행 막대. LinearProgressIndicator 를 직접 쓰지 말고 이걸 쓴다.
class AppProgressBar extends StatelessWidget {
  /// 0.0~1.0. 범위를 벗어나면 내부에서 clamp 한다.
  final double value;

  final double height;

  /// null 이면 scheme.primary.
  final Color? fill;

  /// null 이면 tokens.gaugeTrack.
  final Color? track;

  /// 스크린리더용. 예: '매력 42 / 100'. 색만으로 의미를 전하지 않기 위해 필수.
  final String semanticLabel;

  const AppProgressBar({
    super.key,
    required this.value,
    required this.semanticLabel,
    this.height = 8,
    this.fill,
    this.track,
  });
}

/// 캐릭터 칩. 호감·신뢰를 한 줄로 보여 준다.
///
/// 주의: 본문은 반드시 하나의 Text 로 `'$name ♥$affection ✓$trust'` 형태를 유지한다.
/// 위젯 테스트가 `textContaining('서연 ♥12')` 로 찾는다.
class CharacterChip extends StatelessWidget {
  final String name;
  final int affection;
  final int trust;

  /// null 이면 tokens.neutralAccent.
  final CharacterAccent? accent;

  /// 이번 회차에 아직 만나지 않은 캐릭터.
  final bool dimmed;

  final VoidCallback? onTap;

  const CharacterChip({
    super.key,
    required this.name,
    required this.affection,
    required this.trust,
    this.accent,
    this.dimmed = false,
    this.onTap,
  });
}

/// 집안 카드. 기본 Card 대신 이걸 쓴다.
class AppCard extends StatelessWidget {
  final Widget child;

  /// null 이면 AppInsets.card.
  final EdgeInsetsGeometry? padding;

  /// 배경·테두리 톤. neutral 은 surfaceContainerLow.
  final AppTone tone;

  /// 좌측 3px 띠에 쓸 색. 캐릭터·스탯 소속을 표시할 때.
  final Color? accentStripe;

  /// null 이 아니면 눌릴 수 있는 카드가 된다(InkWell, 최소 높이 56).
  final VoidCallback? onTap;

  /// true 면 shadowRaised 를 쓴다. 화면에 하나만 허용한다.
  final bool raised;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.tone = AppTone.neutral,
    this.accentStripe,
    this.onTap,
    this.raised = false,
  });
}

/// 목록 한 줄. Card + ListTile 조합을 대체한다.
class AppListRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;

  /// 우측 위젯. null 이고 showChevron 이 true 면 chevron_right.
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool showChevron;

  /// 잠긴 항목. 글자색을 lockedForeground 로 내리고 onTap 을 무시한다.
  final bool locked;

  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.locked = false,
  });
}

/// 하단 고정 패널. 이벤트 화면의 선택지·결과 패널 껍데기.
class BottomPanel extends StatelessWidget {
  final Widget child;

  /// 배경 톤. 결과에 따라 brand(크리티컬) / danger(실패) / neutral.
  final AppTone tone;

  /// 화면 높이 대비 최대 비율. 기본 0.55.
  final double maxHeightFactor;

  const BottomPanel({
    super.key,
    required this.child,
    this.tone = AppTone.neutral,
    this.maxHeightFactor = 0.55,
  });
}

/// 이벤트 선택지 버튼.
///
/// 주의: 내부 구현은 반드시 OutlinedButton 이어야 하고, choice 텍스트가
/// 그 자손 Text 로 있어야 한다. 위젯 테스트가
/// `find.widgetWithText(OutlinedButton, text)` 와 `find.byType(OutlinedButton)`
/// 개수로 검증한다. 선택지 영역에 다른 OutlinedButton 을 추가하지 마라.
class ChoiceButton extends StatelessWidget {
  final String text;

  /// null 이면 잠김(비활성). OutlinedButton.onPressed 로 그대로 넘긴다.
  final VoidCallback? onPressed;

  /// 잠긴 이유. 예: '자존감 30↑'. 문구는 컨트롤러가 준 값을 그대로 쓴다.
  final String? lockedReason;

  /// 미니게임 라벨(예: '표정 읽기') 또는 확률 문구(예: '60%').
  final String? trailingLabel;

  /// 좌측 아이콘. 잠금·미니게임 표시에 쓴다.
  final IconData? leadingIcon;

  /// 광고로 공개한 추천 선택지. 테두리를 emphasis 로 올린다.
  final bool recommended;

  /// trailingLabel 의 톤. 미니게임은 brand, 확률은 neutral,
  /// 물오름 보정된 확률은 success.
  final AppTone trailingTone;

  const ChoiceButton({
    super.key,
    required this.text,
    this.onPressed,
    this.lockedReason,
    this.trailingLabel,
    this.leadingIcon,
    this.recommended = false,
    this.trailingTone = AppTone.neutral,
  });
}
```


```dart
/// 캐릭터 이니셜 원형 아바타. 사진 대신 강조색 + 이름 첫 글자 (§4.3).
class CharacterAvatar extends StatelessWidget {
  final String name;

  /// null 이면 tokens.neutralAccent.
  final CharacterAccent? accent;

  /// 32 · 40 · 56 만 쓴다.
  final double size;

  /// 히든 미해금. 글자 대신 Icons.person_outline, 배경 surfaceContainerHigh.
  final bool mystery;

  const CharacterAvatar({
    super.key,
    required this.name,
    this.accent,
    this.size = 40,
    this.mystery = false,
  });
}

/// CastStrip 한 칸의 데이터.
class CastEntry {
  final String id;
  final String name;

  /// null 이면 ♥ 줄을 그리지 않는다(세이브 없음).
  final int? affection;
  final bool mystery;

  const CastEntry({
    required this.id,
    required this.name,
    this.affection,
    this.mystery = false,
  });
}

/// 캐릭터 가로 한 줄(홈). 정렬은 호출부가 끝내서 넘긴다. 항목 폭 56, 사이 md.
class CastStrip extends StatelessWidget {
  final List<CastEntry> entries;

  const CastStrip({super.key, required this.entries});
}

/// 홈 이어하기 카드. 회차·진행·어젯밤 예고·가장 가까운 사람.
class ContinueCard extends StatelessWidget {
  final int run;
  final int chapter;
  final int day;
  final int totalDays;

  /// null 이면 '아직 아무 일도 없었다. 오늘부터다.' 라벨 '어젯밤:' 은 항상 붙는다.
  final String? cliffhanger;

  /// null 이면 '아직 아무와도 가까워지지 않았다'.
  final String? topName;
  final int topAffection;
  final CharacterAccent? topAccent;

  const ContinueCard({
    super.key,
    required this.run,
    required this.chapter,
    required this.day,
    required this.totalDays,
    this.cliffhanger,
    this.topName,
    this.topAffection = 0,
    this.topAccent,
  });

  /// 세이브 요약을 아직 못 읽은 첫 프레임용.
  const ContinueCard.placeholder({super.key})
      : run = 0, chapter = 0, day = 0, totalDays = 100,
        cliffhanger = null, topName = null, topAffection = 0, topAccent = null;
}

/// 출석 보상 줄의 상태.
enum RewardStripState { unclaimed, unclaimedBonus, claimed }

/// 홈 출석 보상 줄. 미수령이면 primaryContainer + '받기', 수령이면 중립 + 체크.
class RewardStrip extends StatelessWidget {
  final RewardStripState state;
  final int streakDays;

  /// unclaimedBonus 에서 부제에 붙는 보너스 문구. 예: '룰렛 재도전권 +1'.
  final String? bonusLabel;

  /// 세이브 없이 받아 둔 하트. 0 보다 크면 수령 상태 부제가 바뀐다.
  final int pendingHearts;

  /// unclaimed / unclaimedBonus 에서 필수.
  final Future<void> Function()? onClaim;

  const RewardStrip({
    super.key,
    required this.state,
    required this.streakDays,
    this.bonusLabel,
    this.pendingHearts = 0,
    this.onClaim,
  });
}

/// 엔딩 등급별 획득 점. 순서 happy → good → solo → bad → hidden 고정.
class EndingTierDots extends StatelessWidget {
  /// tier → (획득, 전체).
  final Map<String, (int, int)> counts;

  const EndingTierDots({super.key, required this.counts});
}

/// 홈·행동·설정의 showDialog 를 대신한다. 스크림 불투명도를 시트와 맞춘다.
Future<T?> showAppDialog<T>(BuildContext context, {required WidgetBuilder builder});
```

`AppListRow` 에 매개변수 하나 추가:

```dart
/// danger 면 제목·leading 아이콘 색을 tokens.danger 로. 배경은 그대로.
/// neutral | danger 만 지원. locked 가 true 면 tone 을 무시한다.
final AppTone tone;   // 기본 AppTone.neutral
```

### 3.3 유지하는 것

- `CenteredScrollColumn` — 시그니처 변경 없음. 작은 화면 + 큰 글꼴 대응의 핵심이라
  미니게임 본문은 계속 이걸로 감싼다.
- `MinigameResult`, `MinigameContext`, `playMinigame`, `minigameRegistry` — 로직이라
  손대지 않는다.

---

## 4. 반드시 지킬 제약

### 4.1 위젯 테스트가 고정한 구조·문구

아래는 바꾸면 테스트가 깨진다. 표현을 바꿀 때도 이 조건을 만족시켜라.

| 고정 대상 | 조건 |
|---|---|
| 선택지 버튼 | `OutlinedButton` 타입, 선택지 텍스트가 자손 Text. 한 이벤트에 정확히 선택지 개수만큼만 존재 |
| 잠금 표시 | `Icons.lock_outline` + 잠금 이유 문구(`'자존감 30↑'`) 를 별도 Text 로 |
| 미니게임 선택지 | `Icons.sports_esports_outlined` + `minigameLabels` 값(예 `'표정 읽기'`) |
| 하트 | 빈 하트는 `Icons.favorite_border`, 최대 개수만큼. `'다음 하트'` 를 포함한 Text 하나 |
| 콤보 | 콤보 3 이상일 때 `'물올랐다 3'` 정확히 |
| 클리프행어 | `'어젯밤: ...'` 를 포함한 Text |
| 캐릭터 칩 | `'서연 ♥12 ✓0'` 형태의 단일 Text |
| 앨범 진행도 | `'2 / 20'`, `'1 / 30'` 형태 단일 Text. 자물쇠 `Icons.lock_outline`, 획득 `Icons.check_circle` |
| 미니게임 결과 | `'크리티컬!'` / `'성공'` / `'실패'` 정확히 |
| 결과 패널 | `'크리티컬! 호감 2배'`, `'실패…'`, `'물올랐다!'`, `'성공'`, `'계속'` |
| 정산 | AppBar `'D+1 정산'`, `'오늘의 변화'`, `'서연 호감'` + `'+4'`, 스탯 변화 `'+3'` |
| 행동 화면 AppBar | `'D+1  ·  1장'` (공백 2개 + 중점) |
| 룰렛 | `'오늘의 운'`, `'돌리기'`, `'시작'`, `'한 번 더 (광고)'` |
| 광고 문구 | `'광고 보고 하트 받기'`, `'광고 보고 기다리지 않기'`, `'10초 전으로 (광고)'`, `'태현에게 물어보기 (광고)'`, `'광고를 불러오지 못했어요'` |
| 앨범 아이콘 | AppBar 액션은 `Icons.photo_album_outlined` |
| 빈 앨범 | `'아직 흑역사가 없다'` |
| 홈 버튼 | `'새 게임'`, `'이어하기'` 각각 정확히 한 개의 Text. 다른 Text 가 이 문구와 완전히 같으면 안 된다 |
| 홈 앨범 카드 | `'앨범  N / M'`(공백 2개) 단일 Text |
| 홈 예고 | `'어젯밤: ...'` 단일 Text(행동 화면과 같은 규칙) |

`test/widget/helpers.dart` 의 `wrapApp` 은 아직 자체 `ThemeData` 를 만든다. QA 단계에서
`AppTheme.light` / `AppTheme.dark` 로 교체해야 화면이 실제 테마로 검증된다.
(`context.tokens` 는 그때까지도 안전하게 기본값으로 동작한다.)

### 4.2 접근성

- 모든 탭 대상 **최소 44×44**. 버튼 테마는 이미 최소 높이 52(1차) / 44(TextButton) 를 준다.
  직접 만든 탭 영역은 `SizedBox`/`Padding` 으로 44 를 확보하라.
- **글자 확대 1.3배에서 깨지지 않기**: 고정 `height` 금지(`SizedBox(height: 132)` 같은
  것은 `ConstrainedBox(minHeight:)` 로), `Row` 안 긴 텍스트는 `Expanded`/`Flexible` +
  `maxLines` + `TextOverflow.ellipsis`, 세로로 모자라면 스크롤(`CenteredScrollColumn`).
- **색만으로 의미 전달 금지**: 상승/하락은 색 + 부호 + 아이콘, 성공/실패는 색 + 문구,
  잠금은 색 + 자물쇠 아이콘, 선택 상태는 색 + 테두리 굵기 + 체크 아이콘.
- 진행 막대·하트·스탯에는 `semanticLabel` 또는 `Semantics(label:)` 을 붙인다.
  아이콘 반복(하트 5개)은 `ExcludeSemantics` 로 묶고 부모에 요약 라벨을 준다.
- 라이트/다크 양쪽에서 본문 대비 4.5:1 이상. 2차 텍스트는 `onSurfaceVariant` 를 쓰고
  그보다 흐린 색을 본문에 쓰지 않는다.

### 4.3 상표 · 트레이드드레스

- 노란색 계열을 브랜드·표면·말풍선·버튼에 쓰지 않는다. `warning` 계열은 상태 표시 전용.
- 말풍선에 삼각 꼬리를 그리지 않는다. 모서리 하나만 각지게 깎는다.
- 특정 메신저의 시스템 문구·아이콘·레이아웃(친구 목록 탭 바, 노란 말풍선, 특유의
  읽음 표기 방식)을 흉내내지 않는다. 우리 시스템 줄은 중립 pill 이다.
- 캐릭터 프로필 이미지 자리에는 실제 사진 대신 강조색 이니셜 원형을 쓴다.

---

## 5. 금지 목록

1. **기본 `Card` 를 그대로 쓰기** → `AppCard`. 기본 `ListTile` 을 `Card` 안에 넣기 → `AppListRow`.
2. **색 하드코딩** — `Colors.*`, `Color(0x...)` 는 `design_system.dart` 밖에서 금지.
   `Colors.grey`, `Colors.green.shade700`, `Colors.pink.shade400` 은 지금 코드에 남아 있는
   위반 사례이며 각각 `onSurfaceVariant`, `tokens.success`, `tokens.heart` 로 바꾼다.
3. **회색 텍스트 남발** — 2차 정보는 `onSurfaceVariant` 한 단만. 3단 이상 흐리게 쌓지 마라.
   본문에 `outline` 색을 쓰지 마라(테두리·시스템 줄 전용).
4. **`LinearProgressIndicator` 직접 사용** → `AppProgressBar`.
5. **표에 없는 간격·모서리 숫자** — `EdgeInsets.all(28)`, `BorderRadius.circular(16)` 처럼
   체계 밖 숫자를 쓰지 마라. 20/16/12/8 과 6/10/14/20/28 만 존재한다.
6. **`Theme.of(context).colorScheme.primary` 를 장식용으로 남발** — primary 는 화면당
   강조 1~2곳. 나머지는 표면 단계와 테두리로 위계를 만든다.
7. **화면마다 컴포넌트 스타일 재정의** — `FilledButton.styleFrom(...)` 을 화면에서 다시
   쓰지 마라. 테마가 이미 정의했다. 예외가 필요하면 이 문서에 근거를 남긴다.
   허용된 예외(HOME_REDESIGN 참고): ① `RewardStrip` 안 `받기` 버튼 최소 높이 44(카드 안 보조 버튼),
   ② 홈 2차 `새 게임` TextButton 의 `foregroundColor: onSurfaceVariant`(1차와 무게 차이),
   ③ 설정 초기화 확인 다이얼로그의 `지우기` FilledButton `backgroundColor: error`(파괴적 확인).
8. **고정 높이로 텍스트 담기** — 1.3배 글꼴에서 잘린다.
9. **그림자 두 겹 이상, 다크 모드에서 그림자로 깊이 만들기.**
10. **애니메이션 상수 직접 쓰기** — `Duration(milliseconds: 250)` 대신 `AppMotion.base(context)`.
11. **화면에 보이는 한국어 문구 임의 변경** — 테스트가 문구로 위젯을 찾는다. 바꿀 근거가
    있으면 이 문서의 §4.1 을 먼저 고치고 QA 단계와 함께 처리한다.
12. **엔진·컨트롤러·광고·스토리 데이터 수정** — 표현 계층만 손댄다.

---

## 6. 서체 번들 현황

| 항목 | 값 |
|---|---|
| 서체 | Pretendard 1.3.9 (OTF, static) |
| 라이선스 | SIL Open Font License 1.1 — 상업 배포 가능. 전문은 `assets/fonts/Pretendard-LICENSE.txt` |
| 번들 굵기 | 400 Regular / 500 Medium / 600 SemiBold / 700 Bold |
| 용량 | 4종 합계 약 6.2 MB (6,318,784 바이트, 라이선스 파일 포함) |
| 대체 서체 | Apple SD Gothic Neo → Noto Sans KR → Malgun Gothic |

굵기를 더 늘리지 마라. 800/900 이 필요해 보이면 700 + 크기 확대로 해결한다.
용량이 문제가 되면 subset(한국어 상용 2,780자 + 라틴) 으로 줄이는 길이 있으나,
스토리 텍스트에 드문 한자·기호가 섞일 수 있어 지금은 전체 세트를 유지한다.
