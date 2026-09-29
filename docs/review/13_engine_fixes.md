# 13 · 상대의 목소리로 줄을 고른다 — 엔진 작업 보고 (2026-09-27)

`docs/review/12_main_rewrite.md` **§5.3** 의 요청 **E1**(`Line.humor`)과 **E2**(말높임)를 만들었다.
고친 파일은 `lib/engine/` 넷(`models.dart` · `mbti.dart` · `event_engine.dart` · `story_repository.dart`)과
새 테스트 `test/voice_test.dart` 하나다. **`characters.json` 은 작가 파일이므로 건드리지 않았다** —
채워야 할 값은 §3 과 `docs/review/13_engine_handoff.md` 에 적었다.

한 줄 요약: **이제 한 줄에 `"humor"` 와 `"register"` 를 달 수 있고, 그 줄은 호감 1위가 누구냐에 따라
화면에 나거나 안 난다. 그리고 다섯 값 중 하나라도 덮지 않으면 앱이 뜨지 않는다.**

작가가 세운 진단(§5.1~5.3)은 전부 맞았다. 확인한 것:

- `Line` 의 조건 필드는 `mbti`·`noMbti`·`compat` 셋뿐이었고, 앞 둘은 **플레이어** 조건이다.
- `compat` 은 `character` 없는 이벤트에서 검증기가 막는다(`story_repository.dart` `_checkGate`).
- `characters.json` 12명 전원 `humor` 가 채워져 있다 — `dry` 2(서연·승현) · `loud` 3(하늘·소희·유나) ·
  `witty` 2(지우·건우) · `meme` 2(민재·다은) · `warm` 3(예은·정우·도윤). 실제로 다시 세어 봤다.
- `politeness` 필드는 없었다. 지금도 없다 — 작가가 채울 자리다.

---

## 1. `Line.humor` — 한 비트를 다섯 목소리로

```json
{"who": "them", "name": "{top}", "text": "답을 쓰다 지우는 중", "humor": ["dry", "witty"]}
{"who": "them", "name": "{top}", "text": "헐 잠깐만 심장 좀", "humor": "loud"}
```

- 값은 `dry` `loud` `witty` `meme` `warm` (= `characters.json` 의 `humor`, `Humor.values`).
- **문자열 하나도 되고 목록도 된다** — `"humor": "loud"` = `"humor": ["loud"]`. 조건 하나가 대부분이라
  대괄호를 강요하지 않는다(`reply` 가 문자열 하나를 한 줄로 받는 것과 같은 관용).
- 없으면 조건 없음 = 누구에게나 보인다.

**무엇을 보는가.** `EventEngine.voiceOf(state, event)` 가 돌려주는 캐릭터의 `humor` 다. 그 해소 규칙은
`{top}` 의 이름 규칙(`EventEngine.topNameFor`)과 **글자 그대로 같다**:

1. 이 회차 호감 1위(`@top` 효과와 같은 사람) → 2. 이벤트가 지목한 `character` → 3. 없음.

같아야 하는 이유는 하나다. 말풍선 머리에 `지우` 가 찍히는데 대사를 서연의 농담 코드로 고르면,
이 기능이 고치려던 어긋남이 자리만 옮긴 것이 된다. 테스트가 이 둘을 한 줄에서 같이 본다
(`voice_test.dart` "`{top}` 이 부르는 사람과 같은 사람을 본다").

**1위가 없는 회차**(아무와도 호감이 0, `{top}` 이 "그 사람" 이 되는 회차)는 `warm` 으로 본다.
`lib/minigames/minigame.dart` 의 `MinigameContext.humor` 가 이미 `partner?.humor ?? 'warm'` 이므로
새 규칙이 아니고, 무엇보다 이래야 `humor` 조건이 **전함수**가 된다 — 다섯 값만 덮으면 빈 화면이 없다.

## 2. 말높임 — `politeness`(사람) + `register`(줄)

```json
{"who": "them", "name": "{top}", "text": "지금 나올 수 있어?",   "register": "casual"}
{"who": "them", "name": "{top}", "text": "지금 나오실 수 있어요?", "register": "polite"}
```

| 어디 | 필드 | 값 | 기본값 |
|---|---|---|---|
| `characters.json` 의 캐릭터 | `politeness` | `casual` \| `polite` | `casual` |
| `Line` · `Choice` | `register` | `casual` \| `polite` | 없음(조건 없음) |

이름이 둘인 이유: 하나는 **사람의 성질**이고 하나는 **줄의 성질**이다. 값 집합은 같다.
(작가 문서 두 곳이 각각 이 두 이름으로 요청했다 — 12_main_rewrite §5.3 E2 의 `politeness`,
05_writing S2(나) 의 `register`. 둘 다 그대로 쓴다.)

### 2.1 정적 필드로 끝냈다 — 그 이유를 명시한다

작가가 짚은 복잡성은 사실이다. 다은(r07 이후) · 유나(r08 이후)는 루트 중간에 존댓말에서 반말로
갈아탄다(도윤 r09 는 호칭만 `회원님`→`{name|씨}` 로 바뀌고 말높임은 끝까지 존댓말이다).
그런데 **이 기능이 닿는 모든 자리에서 정적 값이 맞다.**

- `register` 조건은 **상대가 정해지지 않은 씬**을 위해 있다. 상대가 정해진 씬은 작가가 그 입에 맞춰
  한 벌만 쓰므로 조건을 달 일이 없다.
- 상대가 정해지지 않은 씬은 `{top}` 이 성립할 만큼 호감이 쌓인 뒤에 열린다. 문제의 씬 세 개는
  D+55(`m21`) · D+64(`m26`) · D+67(`m27`) 이고, 다은 r07 은 D+25 이후, 유나 r08 은 그 근처다.
  **전환은 이미 끝나 있다.**
- 그래서 `characters.json` 에는 **전환 후**의 값을 적는다. 다은·유나는 `casual`(안 적으면 기본값).

전환 플래그까지 보는 동적 판정은 이 기능이 풀려는 문제를 하나도 더 풀지 못하면서
`characters.json` 에 루트 플래그를 끌어들인다. **맞는 좁은 기능이 반쯤 지은 일반 기능보다 낫다.**
같은 문장이 `lib/engine/models.dart` 의 `Politeness` 주석에 한국어로 박혀 있다 — 다음 사람이
"왜 정적이냐" 를 다시 묻지 않게.

### 2.2 05_writing S2 와 같은 설계인가 — 그렇다

S2(나)는 일상 28개(`d_date`·`d_two`·`d_temp` 계열)의 반응을 존댓말/반말 두 벌로 쓰고
**엔진이 `@top` 의 말높임으로 고르게** 해 달라고 요청했다. `@top` 은 `topCharacterOf` 이고
`voiceOf` 의 1순위가 바로 그것이다. **같은 필드가 두 문서를 다 갚는다** — 일상 반응 줄에
`register` 를 달면 그대로 작동한다. 새 엔진 작업은 없다.

### 2.3 `Choice` 에도 달았다

12_main_rewrite §6-3 의 지적("선택지가 전부 반말이라 지우·승현·도윤에게 반말로 사과한다")은
선택지에 같은 필드를 달면 풀린다. 달았다.

```json
{"text": "미안했어. 내가 부족했어",    "register": "casual", "effects": {"affection": {"@top": 3}}}
{"text": "미안했어요. 제가 부족했어요", "register": "polite", "effects": {"affection": {"@top": 3}}}
```

**주의 — 엔진이 검사하지 않는 것 하나.** 두 벌의 `effects`·`fail`·`chance`·`require`·`minigame`·
`next`·`intent` 는 **직접 같게 맞춰야 한다.** 한쪽에만 미니게임을 달면 지우를 공략한 플레이어만
다른 게임을 하게 되고, 검증기는 그것을 잡지 않는다(두 줄이 "같은 선택지의 두 벌" 인지 엔진이
알 방법이 없다). 문구만 바꾸고 나머지는 복사하는 것을 규칙으로 삼는다.

`humor` 도 `Choice` 에 받지만 **권하지 않는다.** 선택지는 플레이어가 하는 말이라 농담 코드로
가르면 "무슨 말을 했는지" 자체가 갈리고, 자유 입력 사전(`intent`)까지 다섯 벌이 된다.
말높임은 뜻이 같은 기계적 변환이라 안전하고, 농담 코드는 그렇지 않다. 필드를 막지 않은 이유는
막으면 JSON 의 `humor` 가 **조용히 무시되어** 선택지 다섯 개가 한꺼번에 뜨기 때문이다.

---

## 3. 작가가 채울 것 — `characters.json` (내 파일 아님)

**세 명에게 한 줄씩만 더한다.** 나머지 9명은 아무것도 적지 않는다(기본값이 `casual`).

| id | 이름 | 더할 것 | 근거 |
|---|---|---|---|
| `jiwoo` | 지우 | `"politeness": "polite"` | NAME_GUIDE §4 "존댓말, 호칭 없음, 그쪽" |
| `seunghyun` | 승현 | `"politeness": "polite"` | 같은 표 "끝까지 존댓말, 제안형" |
| `doyun` | 도윤 | `"politeness": "polite"` | 같은 표 "존댓말, 회원님"(r09 는 호칭만 바뀐다) |

```json
{
  "id": "jiwoo",
  "name": "지우",
  "gender": "f",
  "role": "blinddate",
  "humor": "witty",
  "politeness": "polite"
}
```

- **값 오타는 앱을 막는다.** `"polite요"` 처럼 둘 중 하나가 아닌 값은 검증기가 거부한다
  (`캐릭터 politeness 는 casual|polite`). 조용히 기본값으로 떨어져 지우가 100일 내내 반말을
  하는 일이 없게 일부러 엄격하게 잡는다. `humor` 도 같이 검사한다.
- **다만 필드 이름을 틀리면**(`politness`) 그건 그냥 모르는 칸이라 무시되고 기본값이 된다.
  넣은 뒤 지우 루트에서 `register: "polite"` 줄이 실제로 화면에 나오는지 한 번 봐 주면 확실하다.
- 다은·유나는 **적지 않는다**(§2.1).

---

## 4. 검증기 — 무음 씬을 다시 만들 수 없게

이게 이번 작업의 핵심이다. 조건으로 줄을 갈라 놓고 **한 값을 빠뜨리면 그 값을 가진 캐릭터를
공략한 플레이어만 빈 화면**을 본다. 그게 바로 11_story_verdict **4-7**("감정의 척추 12개를 상대가
한 마디도 안 한다")이 지적한 무음 씬이고, 조건으로 되살아나면 **테스트 971개 중 아무것도
눈치채지 못한다** — 데이터가 문법적으로 멀쩡하니까.

`StoryBundle.validate` 가 이제 이벤트마다 **경우의 수 전부**를 돌린다(`_viewCases`).

| 축 | 경우 | 언제 펼치는지 |
|---|---|---|
| 플레이어 | 17가지(모름 + 16유형) | `mbti`·`noMbti`·`compat` 이 하나라도 있을 때 |
| 상대 목소리 | 13가지(**1위 없음** + 캐릭터 12명) | `humor`·`register` 가 하나라도 있을 때 |

각 경우에서 아래가 비면 `StateError` 다.

1. `lines` (원래 있었는데 0줄) → `1위 나리(witty·polite) 플레이어에게 대사가 0줄: m21`
2. **`variants` 묶음마다** → `… 대사가 0줄: m21.variants[0]`
3. 선택지 개수(원래 2개 이상이면 2개 이상) → `… 선택지가 0개(최소 2): m21`
4. `reply`·`failReply`·`critReply` → `… 반응이 0줄: m21 "먼저 사과한다".reply`
5. 전화(`format: "call"`)의 `decline` 선택지

설계 판단 셋을 적어 둔다.

- **1위 후보를 회차 선호로 좁히지 않았다.** `trigger.pref: "f"` 이벤트도 `preference: "all"` 회차에서는
  열리고, 그 회차에는 남성 캐릭터가 1위일 수 있다(`absentIds("all")` 이 아무도 빼지 않는다).
  좁히면 검증이 거짓말을 한다. 그래서 `pref` 와 무관하게 12명 전원을 돌린다.
- **"1위 없음" 도 한 경우다.** `warm`·`casual` 로 본다(§1). 그래서 `humor` 를 쓸 때는
  `warm` 을 반드시 덮어야 한다 — 다섯 값을 다 쓰면 자동으로 덮인다.
- **오류 문구가 누가 못 보는지 말한다.** `1위 나리(witty·polite)` 처럼 이름과 두 축을 같이 찍는다.
  작가가 스택 트레이스를 읽지 않고 "지우 줄이 없구나" 를 바로 알 수 있어야 한다.
- 변형 묶음은 전에는 `{mbti}` 검사도 받지 않았다. 이번에 같이 넣었다(같은 `lines()` 루프).

### 4.1 값 오타

- `humor` 조건에 모르는 값 → `humor 조건은 dry|loud|witty|meme|warm: m21.lines[0] -> "funny"`
- 같은 값 두 번 → `humor 조건에 같은 값이 두 번`
- `register` 에 모르는 값 → `register 는 casual|polite: …`
- 캐릭터의 `humor`·`politeness` → §3

### 4.2 트리거에는 상대 축을 달지 않았다

일부러다. 1위의 농담 코드로 **이벤트**를 가르면 `planDay` 가 조건을 만족하는 main 을 전부 큐에
넣으므로 같은 날 후보가 5벌로 늘고, 상호배타도 보장되지 않는다(12_main_rewrite §5.2 가 같은
결론이다). **가르는 자리는 줄이지 이벤트가 아니다.**

---

## 5. 작가용 완성 예제 — `m21` 고백 씬

`character` 가 없는 씬 그대로다. 아무것도 더 배선하지 않는다.

```json
{
  "id": "m21",
  "layer": "main",
  "day": 55,
  "title": "고백 타이밍",
  "lines": [
    { "who": "narr", "text": "태현이 말했다. 고백은 확률이 70%를 넘을 때 하는 거라고." },

    { "who": "them", "name": "{top}", "text": "아까부터 좀 조용한 것 같아서", "humor": ["dry", "witty"] },
    { "who": "them", "name": "{top}", "text": "야 무슨 일 있지 ㅋㅋ", "humor": "loud" },
    { "who": "them", "name": "{top}", "text": "[짤] 뭔가 할 말 있는 사람.jpg", "humor": "meme" },
    { "who": "them", "name": "{top}", "text": "오늘 좀 말이 없던데", "humor": "warm" },

    { "who": "narr", "text": "{top}한테 지금 내 확률은 몇 퍼센트일까." },
    { "who": "sys", "wait": 15 }
  ],
  "choices": [
    {
      "text": "지금 {top}한테 말한다",
      "register": "casual",
      "chance": 70,
      "effects": { "affection": { "@top": 5 } },
      "reply": [
        { "who": "them", "name": "{top}", "text": "…" },
        { "who": "them", "name": "{top}", "text": "지금 손이 떨려서", "register": "casual" },
        { "who": "them", "name": "{top}", "text": "지금 손이 떨려서요", "register": "polite" }
      ],
      "critReply": [
        { "who": "them", "name": "{top}", "text": "언제 말하나 기다리고 있었는데" },
        { "who": "them", "name": "{top}", "text": "지금 나올 수 있어?", "register": "casual" },
        { "who": "them", "name": "{top}", "text": "지금 나오실 수 있어요?", "register": "polite" }
      ]
    },
    {
      "text": "지금 {top}한테 말할게요",
      "register": "polite",
      "chance": 70,
      "effects": { "affection": { "@top": 5 } },
      "reply": [
        { "who": "them", "name": "{top}", "text": "…" },
        { "who": "them", "name": "{top}", "text": "지금 손이 떨려서요" }
      ],
      "critReply": [
        { "who": "them", "name": "{top}", "text": "언제 말하나 기다리고 있었는데" },
        { "who": "them", "name": "{top}", "text": "지금 나오실 수 있어요?" }
      ]
    },
    { "text": "며칠 더 본다" }
  ]
}
```

읽는 법 넷.

1. `lines` 의 상대 말풍선 네 줄이 **다섯 값을 다 덮는다**(`["dry","witty"]` 가 둘을 먹는다).
   하나라도 빠지면 앱이 안 뜬다.
2. `register` 두 벌을 쓴 `reply` 는 **조건 없는 줄 `…` 을 함께 둔다** — 조건 없는 줄은 누구에게나
   남으므로 박자(말풍선 개수)가 양쪽에서 같아진다.
3. 선택지 두 벌은 `register` 만 다르고 **`chance`·`effects` 가 글자 그대로 같다**(§2.3 주의).
   `며칠 더 본다` 처럼 말높임이 안 드러나는 선택지는 한 벌로 둔다.
4. `{top}` 은 그대로 쓴다. 이름과 목소리가 같은 사람이라는 것은 엔진이 보장한다(§1).

**12_main_rewrite §3 의 N1~N6 규약은 이제 선택이다.** `register` 를 쓴 줄은 종결어미를 써도 되고
`나`/`저` 를 써도 된다. 규약은 **조건을 안 쓴 줄**(= 12명 전원이 보는 줄)에만 계속 걸린다.
§6-2 의 `-는지` 반복도 `humor` 로 갈라 쓰면 자동으로 풀린다.

---

## 6. 무엇을 어떻게 고쳤나 (코드)

| 파일 | 바꾼 것 |
|---|---|
| `lib/engine/models.dart` | `Humor` · `Politeness` 상수 클래스, `Line.humor`/`register`, `Choice.humor`/`register`, `CharacterDef.politeness`, 스칼라/목록 둘 다 받는 `_strListOrOne`. `isGated` 를 `isPlayerGated`(mbti·compat) + `isVoiceGated`(humor·register)로 쪼갰다 |
| `lib/engine/mbti.dart` | `MbtiView` 에 `humor`·`politeness` 를 더하고 `MbtiView.of(..., voice:)` 로 만든다. `_allowsVoice` 가 줄·선택지의 상대 축을 본다. `MbtiFilter` 에 `hasPlayerGates`·`hasVoiceGates` |
| `lib/engine/event_engine.dart` | `voiceOf(state, event)` — `{top}` 과 같은 해소 규칙. `mbtiView` 가 그것을 넘긴다 |
| `lib/engine/story_repository.dart` | `_viewCases`(17 × 13), 검증기 메시지, 변형 묶음 검사, `humor`·`register` 값 검사, 캐릭터 `humor`·`politeness` 값 검사 |

**거르는 자리를 늘리지 않았다.** 상대 축을 `MbtiView` 안에 넣었기 때문에 이미 거르기를 지나던 곳
(`EventEngine.viewFor` → `GameController.current`, `EventEngine.choicesFor`)이 자동으로 같이 거른다.
**그래서 `lib/ui/` 와 `lib/game_controller.dart` 는 한 줄도 바뀌지 않았다.** 두 번째 거르개를 만들면
빠뜨릴 자리가 늘고, 이 저장소는 그 방식으로 세 번 물렸다(12_audio_fixes).

클래스 이름 `MbtiView` 는 그대로 뒀다. 이름은 이제 반만 맞지만, 바꾸면 다른 에이전트가 동시에
고치는 파일의 참조까지 흔들린다. 주석에 "축 두 개" 를 적어 뒀다.

---

## 7. 검사 — 실제 숫자

```
$ flutter analyze
No issues found! (ran in 7.8s)

$ flutter build ios --simulator --no-codesign
✓ Built build/ios/iphonesimulator/Runner.app
```

`flutter test` 는 **두 숫자를 따로 적는다.** 같은 세션에서 다른 에이전트가
`assets/story/events_daily.json` 을 고치는 중이고(작업 트리에 722줄 추가 — 일상 변형 24개와
`d_open_groupchat` 트리거 `day [1,3] → [1,45]`), 그 때문에 데이터 전제를 읽는 테스트 5개가 깨져 있다.

| | 결과 |
|---|---|
| **격리 워크트리**(HEAD + 내 엔진 변경 + 새 테스트, 스토리 데이터는 HEAD) | **971 passed · 1 skipped · 0 failed** |
| 작업 트리 `flutter test`(남의 미완성 `events_daily.json` 포함) | 966 passed · 1 skipped · **5 failed** |

기준선 956 → 971 = **내가 더한 15개**, 실패 0.

**남은 5개가 내 것이 아님을 증명했다.** 격리 워크트리를 HEAD(엔진 변경 **0**)로 두고
작업 트리의 `events_daily.json` 만 복사해 넣었더니 **똑같은 5개가 똑같이 깨졌다.**

```
opening_test: 4일차 이후 기존 풀 잠식 없음 / 일상 오프닝은 4일차부터 후보에 들지 않는다
              오프닝 플래그 후속은 4~20일차 / 일상 오프닝은 day [1, 3~4]  ← Actual: 45
rerun_share_test: 100일 완주 재방송 비율 (Expected: > 0.25, Actual: 0.2256)
```

`d_open_groupchat` 의 `trigger.day` 는 내 변경이 읽지도 쓰지도 않는 값이다.

### 7.1 새 테스트 15개를 하나씩 되돌려 깨뜨렸다

`test/voice_test.dart` 15개. 격리 워크트리에서 엔진을 한 곳씩 되돌리고 실패를 받아 적었다.

| 되돌린 곳 | 깨진 테스트 | 실패 문구(발췌) |
|---|---|---|
| **R1** `allowsLine` 의 `_allowsVoice` 호출 | **11 / 15** | `Expected: ['건조']` / `Actual: ['건조', '시끌', '재치', '짤', '다정']` — 조건이 죽으면 다섯 줄이 한꺼번에 뜬다. 검증기 쪽도 같이 죽는다: `Expected: throws StateError … contains '대사가 0줄'` / `Actual: <Closure: () => StoryBundle>` |
| **R2** `allowsChoice` 의 `_allowsVoice` 호출 | 2 | `Expected: ['미안했어. 내가 부족했어', '아무 말도 안 한다']` / `Actual: [… , '미안했어요. 제가 부족했어요', …]` |
| **R3** `mbtiView` 가 `voice:` 를 안 넘김 | 6 | `Expected: ['지금 나오실 수 있어요?']` / `Actual: ['지금 나올 수 있어?']` — 1위가 지우여도 전원 반말이 된다. `Expected: ['건조']` / `Actual: ['나머지']` |
| **R4** `_viewCases` 의 1위 13가지 → 1가지 | 3 | `Expected: throws … contains '1위 나리(witty·polite)'` / `Actual: <Closure: () => StoryBundle>` — **구멍 난 데이터가 그냥 통과한다** |
| **R5** 변형 묶음 검사 | 1 | `Expected: throws … contains 'm21.variants[0]'` / `Actual: <Closure: () => StoryBundle>` |
| **R6** `_checkGate` 의 값 검사 | 1 | `Expected: throws … contains 'humor 조건은'` / `Actual: <Closure: () => StoryBundle>` |
| **R7** 캐릭터 `humor`·`politeness` 검사 | 1 | `Expected: throws … contains '캐릭터 politeness 는 casual\|polite'` / `Actual: <Closure: () => StoryBundle>` |

되돌리기를 풀면 15/15 초록으로 돌아온다. R4 가 이 작업에서 가장 중요한 줄이다 —
그것만 없으면 **구멍 난 데이터가 조용히 통과하고**, 그게 바로 이 기능이 고치려는 버그다.

### 7.2 테스트가 무엇을 지키는지

| # | 테스트 | 지키는 것 |
|---|---|---|
| 1 | 다섯 값이 각자 자기 줄만 본다 | `humor` 5분기 |
| 2 | 1위가 없으면 warm | 전함수 보장 |
| 3 | 한 줄이 여러 값을 | `["dry","witty"]` |
| 4 | 조건 없는 줄은 누구에게나 | 기존 데이터 무해 |
| 5 | 반말 9 / 존댓말 3 | `register` 분기 + 1위 없음은 반말 |
| 6 | 선택지 문구도 상대에 맞춰 | `Choice.register`(§6-3) |
| 7 | `{top}` 이 부르는 사람과 같은 사람 | `voiceOf` == `topNameFor`, 1위 > `character` |
| 8 | humor 한 값이 빠지면 거부 | **무음 방지**, 오류가 이름을 찍는다 |
| 9 | register 한 쪽이 빠지면 거부 | 같음 |
| 10 | 반응이 비는 것도 | `reply`/`failReply`/`critReply` |
| 11 | 선택지가 한쪽 말높임만 | 선택지 개수 |
| 12 | 변형 묶음도 덮여야 | `variants` |
| 13 | MBTI 축과 겹쳐도 각각 | 17 × 13 곱 |
| 14 | 모르는 값은 거부 | 오타 |
| 15 | 캐릭터 값 오타는 거부 + 안 적으면 반말 | 오타 · 기본값 |

---

## 8. 못 한 것 · 남는 위험

1. **`characters.json` 에 값이 아직 없다.** 내 파일이 아니다. 지금은 12명 전원 `casual` 로 읽히므로
   `register: "polite"` 줄은 **아무에게도 보이지 않는다** — 작가가 §3 의 세 줄을 넣기 전에
   `polite` 줄만 쓰면 검증기가 "1위 지우 … 대사가 0줄" 로 잡는다(즉 조용히 실패하지 않는다).
   **§3 을 먼저 넣고 대사를 쓰는 순서를 권한다.**
2. **E3(`character` 없는 이벤트의 `compat` 허용)은 하지 않았다.** 작가가 "있으면 좋은 것" 으로
   분류했고, 궁합은 플레이어 MBTI × 상대 MBTI 라 **1위가 바뀌면 같은 씬의 온도가 뒤집힌다**
   (호감이 엎치락뒤치락하는 D+55 구간에서 특히). 지금 두 축으로 충분한지 먼저 써 보고
   판단하는 편이 낫다고 보고 남겼다. 하려면 `_checkGate` 의 `hasCharacter` 가지를 풀고
   `_viewCases` 에서 1위 MBTI 로 궁합을 계산하면 된다 — 자리는 다 만들어져 있다.
3. **선택지 두 벌의 효과가 같은지 엔진이 검사하지 않는다**(§2.3). 사람이 지켜야 한다.
4. **`humor`·`register` 를 둘 다 건 줄이 아무에게도 안 갈 수 있다.** `{"humor":"meme","register":"polite"}`
   는 그런 캐릭터가 없어서 영원히 안 보인다. 그 줄이 묶음의 유일한 줄이면 검증기가 잡지만,
   덤으로 붙은 줄이면 조용히 낭비된다. 값 조합표(§2 표 · 12_main_rewrite §5.3 E2 표)를 보고 쓴다.
5. 일상 167개(11 의 4-8)와 `m21`·`m26`·`m27` 다시 쓰기는 **작가 작업**이다. 엔진은 준비됐다.
