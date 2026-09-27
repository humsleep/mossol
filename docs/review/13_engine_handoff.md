# 13 · 엔진에서 나가는 요청 (2026-09-27)

`docs/review/13_engine_fixes.md` 의 작업에서 **내 파일 밖**으로 나가는 것만 모았다.
엔진 쪽은 끝났고 테스트도 다 초록이다(§7). 아래 1번을 넣기 전에는 `register: "polite"` 줄이
아무에게도 보이지 않으므로, **1번이 먼저다.**

---

## 1. `assets/story/characters.json` — `politeness` 세 줄 (작가)

**세 명에게 한 줄씩만 더한다. 나머지 9명은 아무것도 적지 않는다**(없으면 `casual` = 반말).

| id | 이름 | 더할 줄 | 근거 |
|---|---|---|---|
| `jiwoo` | 지우 | `"politeness": "polite",` | NAME_GUIDE §4 "존댓말, 호칭 없음, 그쪽" |
| `seunghyun` | 승현 | `"politeness": "polite",` | 같은 표 "끝까지 존댓말, 제안형" |
| `doyun` | 도윤 | `"politeness": "polite",` | 같은 표 "존댓말, 회원님" — r09 는 호칭만 바뀌고 말높임은 끝까지 존댓말 |

- **필드 이름**: `politeness` (캐릭터 객체의 최상위, `humor` 옆).
- **허용 값**: `"casual"` | `"polite"` — 이 둘뿐이다. 없으면 `"casual"`.
- **다은·유나는 적지 않는다.** 둘은 r07·r08 에서 존댓말→반말로 갈아타는데, 이 필드를 보는
  줄 조건은 그 전환이 끝난 뒤(D+25 이후)의 씬에만 쓰이므로 **전환 후 값**인 `casual` 이 맞다.
  이유 전문은 13_engine_fixes §2.1 과 `lib/engine/models.dart` 의 `Politeness` 주석.

```json
{
  "id": "jiwoo",
  "name": "지우",
  "gender": "f",
  "role": "blinddate",
  "humor": "witty",
  "politeness": "polite",
  "...": "나머지 필드는 그대로"
}
```

**오타는 앱을 막는다.** 값이 둘 중 하나가 아니면 검증기가
`캐릭터 politeness 는 casual|polite: jiwoo -> "…"` 로 거부한다. 단 **필드 이름을 틀리면**
(`politness`) 조용히 기본값으로 떨어진다 — 넣은 뒤 `flutter test test/voice_test.dart` 가 아니라
아무 테스트나 한 번 돌려 앱이 뜨는지 보고, 지우 루트에서 `register: "polite"` 줄이 실제로
화면에 나오는지 한 번 확인해 주면 확실하다.

## 2. `assets/story/events_main.json` — 다시 써도 된다 (작가)

`m21`·`m26`·`m27`(그리고 `m30`·`m36`·`m19`)에 `humor`·`register` 를 달 수 있다.
스키마·완성 예제·주의사항은 **13_engine_fixes.md §1·§2·§5** 에 전부 있다. 요약만:

- `"humor": "loud"` 또는 `"humor": ["dry","witty"]` — 값은 `dry loud witty meme warm`.
  **다섯 값을 다 덮어야 한다**(안 덮으면 앱이 안 뜬다). `warm` 은 "1위 없음" 회차도 함께 먹는다.
- `"register": "casual" | "polite"` — 줄에도 선택지에도 달 수 있다.
- 선택지를 두 벌로 쓸 때 **`effects`·`chance`·`require`·`minigame`·`next`·`intent` 는 글자 그대로
  같게** 맞춰야 한다. 엔진이 검사하지 않는 유일한 곳이다.
- 12_main_rewrite §3 의 N1~N6(종결어미 금지 등)은 **조건을 안 쓴 줄에만** 계속 걸린다.

## 3. `assets/story/events_daily.json` — 05_writing S2(나) 도 이 필드로 풀린다 (작가)

S2 가 요청한 "일상 28개의 반응을 존댓말/반말 두 벌로 쓰고 엔진이 `@top` 의 말높임으로 고른다" 가
그대로 된다. `@top` 과 `register` 가 보는 사람이 같은 사람이다(`EventEngine.voiceOf`).
엔진 추가 작업 없음. 견적 4h 로 잡혀 있던 엔진 몫은 이번에 갚았다.

## 4. UI · 미니게임 — 할 것 없음

거르기를 `MbtiView` 안에 넣었기 때문에 `GameController.current` 와 `EventEngine.choicesFor` 가
이미 걸러진 것을 준다. `lib/ui/`·`lib/minigames/` 는 한 줄도 바꾸지 않았고 바꿀 필요도 없다.

## 5. 참고: 남의 미완성 데이터로 테스트 5개가 깨져 있다 (일상 담당 에이전트)

작업 트리의 `assets/story/events_daily.json` 때문에 아래가 실패한다. **내 변경과 무관함을
격리 워크트리에서 증명했다**(엔진 0변경 + 이 데이터 = 똑같이 5개 실패, 13_engine_fixes §7).

- `opening_test`: `d_open_groupchat` 의 `trigger.day` 가 `[1, 3]` → `[1, 45]` 로 바뀌어
  "일상 오프닝은 day [1, 3~4]" 와 "4일차 이후 격리" 셋이 깨진다.
- `rerun_share_test`: 일상 변형 24개가 늘면서 "예전 엔진" 쪽 재방송 비율이 25% 미만(22.6%)으로
  떨어져 전후 비교 전제가 무너진다 — 기준선 상수를 손볼 필요가 있어 보인다.
