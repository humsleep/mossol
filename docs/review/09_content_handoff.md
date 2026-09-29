# 09. 콘텐츠 → 엔진·테스트 인계서

> 2026-09-26 · narrative. **`lib/**` · `test/**` · `assets/story/config.json` 은 한 줄도 안 건드렸다.**
> 내가 고친 것은 `assets/story/*.json`(config 제외)과 `tool/**` 뿐이다.
> 여기 적은 것은 **다른 담당이 해 줘야 데이터가 제대로 도는 일**이다. 결과 요약은 `09_content_fixes.md`.

---

## 1. `config.json` — `openingScript` 에 넣어 달라 (엔진 담당)

`config.json` 은 내 파일이 아니라서 비워 둔 채로 두었다. 지금 값은 `"openingScript": []` 다.

```json
"openingScript": ["m01", "d_open_bet"]
```

**순서가 중요하다. `m01` 이 반드시 첫 번째다.** `planDay` 가 대본을 메인 블록보다 먼저 깔기 때문에
(`event_engine.dart` `usesOpeningScript` → `openingScriptEvents`), 대본 첫 칸이 `m01` 이 아니면
`test/opening_test.dart:434` 의 `expect(c.current!.id, 'm01')` 과
`test/event_engine_test.dart` 의 "1일차는 프사 고르기 메인 이벤트로 시작한다" 가 깨진다.

`d_open_bet_2` 는 넣지 말 것 — `d_open_bet` 의 1·3번 선택지에서만 `next` 로 이어지는 2단 장면이고,
대본에 넣으면 2번을 고른 회차에도 나온다.

### 이 목록이 비어 있어도 전제는 나온다 (이중 안전장치)

`m01` 의 **모든 선택지에 `next: "d_open_bet"`**(확률 선택지는 `failNext` 도) 를 달아 두었다.
그래서 `openingScript` 가 비어 있어도, 2회차 이후라도, D+1 에 100% 나온다.
둘 다 켜져도 **중복 재생되지 않는다** — `game_controller.dart:1397` 의
`_queue.removeWhere((e) => e.id == next.id)` 가 큐에서 먼저 빼고 맨 앞에 꽂는다.

### 못 한 것: `d_open_bet` 을 `layer: "main"` 으로 올리기

**의도적으로 안 했다. 지금 데이터·테스트에서는 불가능하다.** 두 군데가 막는다.

1. `story_repository.dart:395-403` — 같은 날 main 은 쪽(`pref`)별로 하나씩만. `m01`(day 1, pref 없음)이
   이미 1일차를 쓰고 있어서 `d_open_bet` 을 main·day 1 로 만들면 `main 날짜 중복` 으로 검증이 죽는다.
2. `test/opening_test.dart:154-160` — `openingDaily` 10개(`d_open_bet` 포함)에 대해
   **`layer == EventLayer.daily`**, `trigger.day.min == 1`, `day.max ∈ [3,4]`, `weight ∈ [3,5]` 를 고정한다.
   레이어를 바꾸면 이 테스트가 깨진다.

`m01` 을 2일차로 미는 우회로도 `expect(plan.first.id, 'm0$day')`(day 1·2)가 막는다.
**그래서 "메인 레이어로 승격" 대신 "메인에서 `next` 로 끌어오기 + 대본 첫 칸"** 으로 같은 보장을 만들었다.
정말로 레이어를 올리려면 `opening_test` 의 `openingDaily` 분리와 1·2일차 단정을 먼저 고쳐야 한다.

---

## 2. `test/**` — 콘텐츠가 늘어서 숫자가 바뀐 곳 (테스트 담당)

**전부 하드코딩된 개수·할당량이다. 데이터 검증(`StoryBundle.validate`)은 통과한다.**
내가 `test/` 를 못 건드려서 숫자만 적어 둔다.

| 파일·줄 | 지금 단정 | 바꿀 값 | 왜 |
|---|---|---|---|
| `test/event_engine_test.dart:54` | `expect(baseEvents().length, 393)` | **399** | 메인 4편(`m_brief`·`m_brief_m`·`m_week1`·`m_week1_m`) + 일상 2편(`d_fu_pact`·`d_fu_taehyun`) |
| `test/event_engine_test.dart:116` | 레이어별 분량 `main: 55`, `daily: 117` | **`{main: 59, route: 189, daily: 119, crisis: 16, hidden: 16}`** | 위와 같음. `mo_` 를 뺀 `baseEvents()` 기준으로 직접 세어 확인했다 |
| `test/opening_test.dart:298-301` | 1~3일차 `daily` 개수 `day <= 2 ? 2 : 3` | **`2`** (또는 3일차를 예외로) | D+3 에 메인(`m_brief`)이 생겨서 `openingMinEventsPerDay = 4` 를 메인1+일상2+루트1 로 채운다. 08 §7.3 이 예고한 그대로다 |

`opening_test` 3일차 건은 **회귀가 아니라 의도한 개선**이다 —
지금까지 D+3 은 플롯이 0개인 날이었고(`08_story_delivery.md` §1.2), 거기에 캐스트 소개를 넣은 것이 이 작업의 핵심이다.

### 2.1 숫자가 아니라 **전제**가 바뀐 곳 하나 — 판단이 필요하다

`test/event_engine_test.dart:315` **`호감도 구간에 빈 곳이 없다`** 는 새로 실패한다.
메시지: `지우 30일차 호감 0 구간에 이벤트 없음`.

이 테스트는 **플래그가 하나도 없는** 상태로 12명 전원이 30·50·80·95일차 × 호감 0~90 에서
루트 후보를 갖는지 본다. 기준선에서 지우·승현이 그 칸을 채운 건 **`jiwoo_r03`~`r15` 에 조건이
하나도 없었기 때문**이다 — 즉 소개팅을 안 해도 소개팅 상대의 루트가 도는 상태였고, 그게 07 (c)#6 이다.

소개팅 줄기를 게이트하면 이 전제는 **설계상 성립하지 않는다**. 둘 중 하나를 골라야 한다.

1. **지금대로 두고 테스트의 전제를 고친다** — 소개팅 상대(`jiwoo`·`seunghyun`)는
   `jiwoo_intro`/`seunghyun_intro` 가 선 상태에서만 검사하도록 예외를 둔다. **내가 권하는 쪽이다.**
2. 루트 게이트를 되돌린다 — 그러면 이 테스트는 통과하지만
   `route_order_test` 의 `정적 검사`(`jiwoo_r03 ← m11` 외 23건)가 대신 깨지고,
   "소개팅을 거절해도 소개팅 상대와 사귄다"가 돌아온다.

**어느 쪽을 골라도 실패 하나는 남는다.** 나는 이야기가 맞는 쪽(1)을 택해 데이터를 그렇게 두었다.

---

## 3. 엔진에 있으면 좋겠는 것 (없어도 지금 데이터는 돈다)

### 3.1 `Line.name` 에도 자리표시자를 적용해 달라

`models.dart:513` `Line.mapText` 가 `name: name` 으로 **이름 칸은 치환하지 않고 넘긴다.**
그래서 캐릭터가 정해지지 않은 일상(`character: null`)의 `who: "them"` 줄은
`l.name ?? partner` 에서 `partner` 가 빈 문자열이라 **말풍선 위 이름이 비어 있다**
(`event_screen.dart:735`). 이것이 07 (c)#7 "누가 말하는지 화면에 없다"의 남은 절반이다.

지금은 `name` 에 `{top}` 을 못 쓰므로, 상대 이름을 **지문(`text`)에서만** 부르게 썼다.
`mapText` 가 `name: f(name)` 이 되면 `"name": "{top}"` 을 쓸 수 있고, 데이트·카톡 일상 40개의
말풍선 머리에도 이름이 붙는다. 그때 내가 데이터를 다시 훑겠다.

### 3.2 `require.flags` 의 잠금 사유

`conditions.dart:87` `Requirement.describe()` 가 스탯·호감·신뢰만 문장으로 만든다.
플래그 조건이 붙은 선택지는 **사유가 빈 문자열인 채 잠겨** 보인다(`event_engine.dart:281`).
그래서 이번 작업에서 "지난 선택을 기억하는 선택지"를 `require.flags` 로 만들지 않고
전부 이벤트 트리거·관찰문(`signals.json`)으로 풀었다. 잠금 사유가 생기면 선택지 단위로도 쓸 수 있다.

### 3.3 `{top}` 은 잘 받았다

`text_template.dart` 의 `{top}`·조사·`{top||대체어}` 3단 해소(1위 → 이벤트 캐릭터 → `그 사람`)가
필요한 그대로였다. 데이터에서 쓴 조사는 `{top}`(맨몸), `{top|이가}`, `{top|은는}`, `{top|과와}`,
`{top||대체어}` 다섯 가지다.

---

## 4. 판단이 필요한 것 — 소개팅 루트 도달률 (루트 순서 담당)

`m11`/`m11_m` 에 조건이 붙으면서, 소개팅 루트 `jiwoo_r03`~`r15`·`seunghyun_r03`~`r15` 26개도
`jiwoo_dated`/`seunghyun_dated` 를 요구하게 했다(`09_content_fixes.md` §4.1).
`정적 검사: 뒤 이벤트 트리거가 앞 이벤트를 보장한다` 는 **이것 때문에 통과한다.**

대신 `route_order_test` 의 도달성 수치가 바뀌었다. HEAD 데이터로 기준선을 만들어 비교한 결과:

| `[m]` r15 미도달 (17 MBTI 중) | 기준선 | 지금 |
|---|---|---|
| seunghyun | 5 | **17** |
| jeongwoo · geonwoo | 17 · 17 | 17 · 17 |
| haneul | 16 | 17 |
| doyun | 0 | 4 |

`[f]` 는 기준선과 **완전히 같다**(yuna·seoyeon·jiwoo·daeun 각 17). 실패하는 테스트 4개도 기준선과 같다.

승현이 5 → 17 이 된 이유는 기준선에서 `seunghyun_r03`~`r15` 에 **조건이 하나도 없어서**
소개팅을 한 적 없이도 루트를 끝까지 걸을 수 있었기 때문이다. 셋 중 하나를 골라야 한다.

1. `test/sim_balance_test.dart` 의 `FocusStrategy` 가 `m03_m`·`m03` 에서 소개팅을 수락하게 한다
   (공략 대상이 `jiwoo`/`seunghyun` 일 때 `*_intro` 를 세우는 선택지에 가산점). **내가 권하는 쪽이다.**
2. `r03`~`r15` 의 요구를 `*_dated` → `*_intro` 로 낮춘다. 도달률은 돌아오지만
   **정적 검사가 다시 깨진다**(`*_intro` 는 `m03` 이 세우므로 `m11` 을 보장하지 못한다).
3. 지금대로 둔다 — "소개팅을 안 하면 그 루트는 없다"를 설계로 확정하고, 도달성 테스트의
   기대치를 `pref`·플래그 조건에 맞게 고친다.

haneul 16→17, doyun 0→4 는 게이트와 무관하다. D+3·D+7 에 메인 2편이 들어가며 난수 흐름이 밀린 결과다.

---

## 5. 내가 남겨 둔 데이터 문제 (다음 사람용)

- **거절 회차의 D+26·D+29 가 빈다.** `m10`·`m11` 을 `refused_mom`/`lied_to_mom` 으로 막았으므로
  소개팅을 거절한 회차는 그 이틀에 메인이 없다. 대체 장면 `m10_refused`(day 25 또는 27, main)가
  있으면 좋다 — 같은 날(26·29)에는 못 둔다(`main 날짜 중복`).
- **죽은 플래그 26종이 남아 있다.** 전부 메인 밖이다(루트·일상·특수). 목록과 이유는
  `09_content_fixes.md` §4. `python3 tool/flag_audit.py --dead` 로 언제든 다시 셀 수 있다.
- **`m22` 의 클리프행어가 "그 남자"로 고정이다.** 남성향 회차에서는 라이벌이 여성이어야 한다.
  쪽별 분기가 필요해 이번에는 손대지 않았다.
