# 개편 2 — 기존 이벤트 파급 줄 제안 (`ifFlags` / `ifNotFlags`)

> 2026-10-07 · 작성: NarrativeDesigner · 근거: 01_design.md §5.2
> 상태: **제안**. 기존 파일(`events_main.json`, `events_daily.json`, `events_special.json`)은 다른 작업과 겹치지 않게
> 이번에 손대지 않았다. 아래 줄은 모두 **더하기만** 한다(기존 줄·선택지·효과는 그대로).
> "after N" 은 그 이벤트 `lines` 의 N번 줄(0부터) **뒤에 끼운다**는 뜻이다. 여러 줄이면 적힌 순서대로 넣는다.
> 쓰인 플래그는 모두 `starts.json` 또는 `events_start.json` 이 세운다(검증기 `_checkFlagRefs` 통과 확인).

## 0. 먼저 고칠 것 (버그 성격)

| # | 이벤트 | 변경 | 이유 |
|---|---|---|---|
| 0-1 | `d_open_bet` | `trigger` 에 `"notFlags": ["start_alt"]` 추가 | 신규 시작은 D2 메인의 `next` 로 내기를 연다. 그런데 `d_open_bet` 은 일상(day 1~3, weight 5)으로도 뽑혀서 D1 에 먼저 나올 수 있다. `game_controller` 의 `next` 처리는 본 이벤트도 다시 큐에 넣으므로 **같은 내기가 두 번 나온다**. `next` 는 트리거를 보지 않으니 막아도 D2 진입은 그대로다. |
| 0-2 | `d_open_bet_2` 선택지 0 (`ㅋㅋ 다들 지켜봐 주세요`) | `effects.stats` 에 `"heat": 8` | §3.2 클래식 작은 강화. 증인 단톡이 클래식의 첫 소문 공급원. |
| 0-3 | config `actions.rest.effects.stats` | `"heat": -6` | §5.1 "잠수 = 별 지우기". config 담당 작업에 넘긴다. |

## 1. `d_open_bet` — 판돈 대사 5벌 (§3.0)

신규 시작에서는 D2 에 열리므로 첫 줄의 "오늘부터 D-100" 이 하루 어긋난다.

- line 0 `{"who":"them","name":"태현","text":"야 오늘부터 D-100이다"}` 에 `"ifNotFlags": ["start_alt"]` 추가
- after 0:
```json
{"who": "them", "name": "태현", "text": "야 하루 늦었지만 오늘부터 D-99 센다", "ifFlags": ["start_alt"]}
```
- after 2 (`하면 내가 열 마리` 뒤):
```json
{"who": "them", "name": "태현", "text": "그리고 보너스. 그 문장 주인이랑 되면 내가 따로 한 마리 더", "ifFlags": ["sc_leak"]},
{"who": "them", "name": "태현", "text": "부케 받은 사람이랑 되면 스무 마리. 이건 진심", "ifFlags": ["sc_speech"]},
{"who": "them", "name": "태현", "text": "합방에서 공개 고백하면 치킨 추가 ㅋㅋ", "ifFlags": ["sc_clip"]},
{"who": "them", "name": "태현", "text": "서진보다 먼저 100일 사진 올리면 한 마리 더", "ifFlags": ["sc_swap"]},
{"who": "them", "name": "태현", "text": "판돈 뒤집은 거 기억하지. 네가 진짜 너로 성공하면 내가 스무 마리", "ifFlags": ["taehyun_debt"]},
{"who": "them", "name": "태현", "text": "사과의 의미로 판돈은 내가 더 건다. 진짜로", "ifFlags": ["sc_ghost"], "ifNotFlags": ["taehyun_debt"]}
```

## 2. `m_mbti_chat_f` / `m_mbti_chat_m` (D4) — 두 레코드 모두 같은 줄

after 3 (`동기: ISTJ요…` 뒤):
```json
{"who": "them", "name": "신입", "text": "근데 그 '심쿵 클립' 주인 이 방에 있다던데 ㅋㅋ", "ifFlags": ["sc_clip"]},
{"who": "them", "name": "신입", "text": "축사 레전드 그분도 신입이래요 ㅋㅋㅋ", "ifFlags": ["sc_speech"]},
{"who": "narr", "text": "서진도 이 방에 있다. 자기소개 끝에 하트를 두 개 붙였다.", "ifFlags": ["sc_swap"]}
```

## 3. `m03` / `m03_m` (D5 엄마의 소개팅 통보) — 두 레코드 모두

after 3 (`사진 보냈다 확인해봐` 뒤, wait 줄 앞):
```json
{"who": "them", "name": "엄마", "text": "근데 아주머니가 너희 벌써 연락한다던데? 시도 보냈다며", "ifFlags": ["sc_ghost"]},
{"who": "narr", "text": "엄마가 보낸 사진. 사흘 동안 '내'가 시를 보낸 그 사람이다.", "ifFlags": ["sc_ghost"]}
```

## 4. `m_week1` / `m_week1_m` (D7) — 두 레코드 모두

after 3 (`치킨 열 마리가 걸렸으니까 ㅋㅋ` 뒤):
```json
{"who": "them", "name": "태현", "text": "그리고 수사본부 결론 나기 전에 네가 먼저 말해야 하니까", "ifFlags": ["sc_leak"]},
{"who": "them", "name": "태현", "text": "그리고 축사 영상 20만 찍었다. 동네가 다 보고 있다", "ifFlags": ["sc_speech"]},
{"who": "them", "name": "태현", "text": "그리고 클립 장인 2탄 예고 봤냐", "ifFlags": ["sc_clip"]},
{"who": "them", "name": "태현", "text": "그리고 서진 커플 1주년까지 51주 남음 ㅋㅋ 아 미안", "ifFlags": ["sc_swap"]},
{"who": "them", "name": "태현", "text": "그리고 내 죄를 씻으려면 네가 성공해야 돼", "ifFlags": ["sc_ghost"]}
```

## 5. `m08` / `m08_m` (D20 준호의 동창회) — 두 레코드 모두

after 2 (`근데 걔가 계속 네 얘기를 하더라 ㅋㅋ` 뒤):
```json
{"who": "them", "name": "준호", "text": "아 그리고 동창회에서 네 축사 영상 또 틀었다 ㅋㅋ 다들 대사 외움", "ifFlags": ["sc_speech"]}
```

## 6. `m10` (D26 소개팅 D-1)

after 0 (`내일이 엄마가 주선한 소개팅이다.` 뒤):
```json
{"who": "narr", "text": "시 쓰는 나 말고, 진짜 나로 나가는 첫날이다.", "ifFlags": ["sc_ghost"], "ifNotFlags": ["sc_ghost_lie"]},
{"who": "narr", "text": "상대는 아직 새벽 3시에 시를 쓰는 나를 만나러 온다.", "ifFlags": ["sc_ghost_lie"], "ifNotFlags": ["ghost_confessed"]},
{"who": "narr", "text": "털어놓고 나서 처음 보는 날이다. 오히려 덜 떨린다.", "ifFlags": ["ghost_confessed"]}
```

## 7. `m21` (D55 고백 타이밍)

after 0 (태현의 70% 지문 뒤):
```json
{"who": "narr", "text": "100일 전 알바 단톡에 잘못 보낸 문장. 이번엔 제대로 보낼 차례다.", "ifFlags": ["sc_leak"]},
{"who": "narr", "text": "이번엔 마이크가 켜진 걸 알고 말한다.", "ifFlags": ["sc_clip"]}
```

## 8. `m22` (D57 라이벌 등장)

after 1 (`손가락이 프로필을 누르려다 멈춘다.` 뒤):
```json
{"who": "narr", "text": "서진 생각이 먼저 났다가, 안 났다.", "ifFlags": ["sc_swap"]},
{"who": "narr", "text": "'100일 뒤에 보자'던 내 스토리가 떠올랐다. 지금 보니 그게 제일 유치했다.", "ifFlags": ["sc_swap_revenge"]}
```

## 9. `m24` (민재) / `m24_f` (소희) (D60 반전)

`m24` after 3 (`편의점에서` 뒤, 지문 앞):
```json
{"who": "them", "text": "그 클립 이후로 얼굴 까기가 더 무서워졌었어. 근데 너라서 깜", "ifFlags": ["sc_clip"]}
```
`m24_f` after 3 (`루미 목소리야` 뒤):
```json
{"who": "them", "text": "그래서 그 클립 처음 들었을 때 무서웠어. 근데 너는 목소리 말고 내 말을 들었잖아", "ifFlags": ["sc_clip_own"]},
{"who": "them", "text": "합성이라며 ㅋㅋ 나 그날 진짜 속상했다", "ifFlags": ["sc_clip_deny"]}
```

## 10. `m37` (D95 태현의 고백)

after 4 (`영상 보고 배운 거 그대로 말한 거야` 뒤):
```json
{"who": "them", "name": "태현", "text": "그 시도. 사실 6년 전에 내가 못 보낸 걸 너한테 보낸 거야", "ifFlags": ["sc_ghost"]},
{"who": "them", "name": "태현", "text": "해고당하고 나서 알았다. 코치가 필요했던 건 나였어", "ifFlags": ["sc_ghost_fired"]},
{"who": "them", "name": "태현", "text": "그 문장 첨삭해 줄 때 사실 좀 부러웠다. 나는 보낼 데도 없었거든", "ifFlags": ["sc_leak"]}
```

## 11. `h_junho_wedding` (D91 축사 연습)

after 0 (`축사 원고를 쓴다. 세 번 지웠다.` 뒤):
```json
{"who": "narr", "text": "이번엔 미러링을 끈다. 폰은 비행기 모드. 100일 전의 빚을 갚는 날이다.", "ifFlags": ["sc_speech"]}
```

## 12. (선택) 복수 노선 질문을 루트 대사로

`events_start.json` 의 `sc_swap_rebound`(D30~75, `sc_swap_revenge`, 호감 35 이상 1명)가 "나, 복수용이야?" 장면을 이미 독립
이벤트로 담당한다. 루트에도 한 줄 메아리를 넣고 싶다면 `seoyeon_r08`·`jeongwoo_r08` 의 첫 지문 뒤에:
```json
{"who": "narr", "text": "사진 속 내 옆자리를 보며 문득 생각했다. 이 사람한테 나는 서진에 대한 대답일까, 그냥 나일까.", "ifFlags": ["sc_swap_revenge"]}
```
(질문 자체는 루트 캐릭터의 입으로 하지 않는다 — 같은 질문이 두 번 나오지 않게.)

## 검증 메모

- 위 줄을 넣은 뒤에도 `ifFlags` 는 **줄**에만 붙으므로 §5.2 의 "조건 없는 선택지 2개 이상" 규칙과 무관하다.
- 사용 플래그: `start_alt`, `sc_leak`, `sc_speech`, `sc_clip`, `sc_clip_own`, `sc_clip_deny`, `sc_swap`, `sc_swap_revenge`,
  `sc_ghost`, `sc_ghost_lie`, `sc_ghost_fired`, `ghost_confessed`, `taehyun_debt` — 모두 세우는 곳이 있다.
- 새 한글 글자 없음(현 서브셋 coverage 로 확인).
