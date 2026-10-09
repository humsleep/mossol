# 개편 2 — 3차 대본 리뷰 (줄 단위)

> 2026-10-08 · NarrativeDesigner · 브랜치 `overhaul2-starts`(커밋 전 작업본) · 게임 파일은 고치지 않았다.
>
> 범위
> - 2차 행 확인: `r2_script.md` 의 P0·P1 12행 전부와 P2 33행 전부를 현재 JSON 과 실제 플레이 추적으로 대조했다.
> - 2차 수정에서 새로 들어오거나 바뀐 글 전부(아래 "본 것" 참고).
> - 추적: 실제 엔진(`GameController`)을 스크래치 사본에서 돌려 528회차를 100일 끝까지 플레이했다. 대사는 화면과 같은 규칙으로 걸렀다(`ifFlags`·`ifNotFlags`·`register`·`humor`·`{top}`·`{char:}`). 말풍선 시계도 화면 규칙(`clockStartFor`, E7)으로 찍었다.
> - 목소리 검사기는 스크래치 사본으로 돌렸다.
>
> 본 것
> - `sc_leak_mid`, `sc_clip_mid`, `sc_ghost_mid`, `sc_speech_reunion`
> - 정산 전부(`*_settle`, `*_settle_m`, `*_settle_open`, `sc_leak_settle_out`)와 `m36`·`m37`
> - 진상 승리 25곳(`leak_rigged`, `speech_self_upload`, `swap_sniped`, `v_*` 22개)과 그 대가(`d_villain_rival_*`, `c_villain_trial`, `d_villain_fan`, `villain_legend`)
> - r00·r01 첫 접촉 줄(`leak_dm`, `swap_senior_met`, `jiwoo_sms`), `characters.json` 의 `firstLine`, `starts.json` 의 `castLines`
> - 보상·소문 수치 변경, 돈 표기 정리, `infamous`·`wedding_guest`

## 표기

1·2차와 같다. `L3` = `lines[3]`, `C2` = `choices[2]`, `C2.reply[1]`. 인덱스는 0부터 센다(현재 파일 기준).
등급 **P0** 깨짐·모순(거의 모든 회차에 보임) / **P1** 확실히 약함, 갈래 한정 모순, 캐릭터 이탈 / **P2** 다듬기.
교체안은 그대로 JSON 에 붙여 넣을 수 있게 썼다. "추가"는 바로 앞에 적은 줄 뒤에 넣는다는 뜻이다.
교체안은 엔진 수정 없이 들어간다. 엔진으로도 풀 수 있는 것은 따로 적었다.

## 0. 요약

| 구분 | P0 | P1 | P2 | 합 |
|---|---|---|---|---|
| 회귀·미해결(2차 수정에서 생기거나 덜 들어감) | 1 | 2 | 0 | 3 |
| 새 문제(새 글·바뀐 글) | 0 | 4 | 17 | 21 |
| **합계** | **1** | **6** | **17** | **24** |

- **P0·P1 목록**
  - R3-1 (P0) `daeun_r01`·`haneul_r01`: sc_leak 에서 첫 출근 **당일**에 "첫 출근 전날"이라고 나온다.
  - R3-2 (P1) `jeongwoo_r00`: sc_swap 남성 쪽 D2 밤에 두 번째 첫인사를 한다(2차 R5 가 반만 들어감).
  - R3-3 (P1) 고정 시각 장면 5종: E7 이후 지문의 시각과 말풍선 시각이 100% 어긋난다.
  - N-1 (P1) `sc_leak_settle_out`: D90 에 m36 보다 **먼저** 나온다. 정반대 두 줄과 정반대 두 선택지가 함께 뜬다.
  - N-2 (P1) m36 고백 성공 뒤의 대체판 정산: leak·ghost 에서 고백을 처음 하는 장면이 한 번 더 나온다.
  - N-3 (P1) m36 "아무것도 안 함" 뒤의 `sc_speech_settle_open`: "대화방은 92일째에 멈췄다" 다음에 "어제 {top}과 찍은 사진"이 나온다.
  - N-4 (P1) m36 정리·거절 뒤 정산이 "보낼 사람은 없다"고 못 박는데, 엔딩은 그 사람과의 해피가 그대로 난다(집중 플레이 80/80).
- 2차 행 확인 결과
  - P0·P1 12행: ✓ 9, 다른 방식으로 해결(=) 1(R4), 반만 해결(◐) 2(R1 → R3-1, R5 → R3-2).
  - P2 33행: ✓ 30, = 1, 수정은 들어갔지만 E7 때문에 효과가 없음(◐) 2(`sc_clip_open_2`, `sc_swap_trainer`) → R3-3.
- 진상 대가 줄은 모두 맞는 플래그를 읽는다.
  - 다만 고유 플래그 2개(`v_mom_content`, `v_stream_gossip`)는 읽는 곳이 없다.
  - 한 줄(`d_villain_rival_speech.L4`)은 사건의 장소를 틀리게 말한다.
- 돈 표기: 띄어 쓴 금액이 0건이다. 효과값과 글의 금액은 25곳 모두 맞는다. `a_hustle_stream` C2 는 출연료 1만원 + 썰값 1.5만원 = 25 로 맞는다.
- 12+: 걸리는 것이 없다. 술·성적 표현·실명 노출이 없다. 진상 승리 장면에는 모두 대가 줄이 붙어 있다.
- 목소리 검사기: 위반 0건이다(4절).

---

## 1. 회귀와 미해결 (먼저 고칠 것)

### R3-1 · P0 · daeun_r01 / haneul_r01 "첫 출근 전날" (2차 R1 의 다른 방식 수정이 만든 회귀)

2차 교체안은 r01 trigger 를 `[4,100]` 으로 미루는 것이었다. 수정은 그 대신 sc_leak 줄을 "첫 출근 **전날** 오후/저녁"으로 바꿨다.
그런데 r01 은 실제로 D3(32%)나 **D4(68%)** 에 나온다(sc_leak 88회차 추적).
- 오프닝 D3 루트 칸은 균등 추첨이다.
- D4 부터는 호감 1위가 루트 칸을 받는다. 시작 보정 +4 가 있는 다은·하늘이 거의 1위다.
- 그런데 D3 의 클리프행어가 "첫 출근 날. 가게 앞에 누가 먼저 와 있다."이다(D1 L3 "사흘 뒤 첫 출근" → D4).
- 결과: 추천 시작의 회차 대부분에서 첫 출근 **당일** 밤에 "첫 출근 전날 저녁. 교육 겸 들른 가게…"가 뜬다.

추적 원문(`sc_leak-m-b0-s0-conf-focus`)
```
~ cliff: 첫 출근 날. 가게 앞에 누가 먼저 와 있다.
== D4
-- haneul_r01 [route] 오후 9:50
    narr: 첫 출근 전날 저녁. 교육 겸 들른 가게에서 마감 조 하늘이 말을 걸었다.
```

교체안
- **daeun_r01**
  - trigger `"day"`: `[3,100]` → `[4,100]`
  - L1: `{"who":"narr","text":"첫 출근 날. 가게 앞에 먼저 와 있던 사람이 다은이었다. 선반마다 노란 포스트잇이 붙어 있다.","ifFlags":["sc_leak"]}` (D3 클리프행어를 바로 받는다)
- **haneul_r01**
  - trigger `"day"`: `[3,100]` → `[4,100]`
  - L1: `{"who":"narr","text":"첫 출근 날 마감. 가게 앞에 먼저 와 있던 사람이 하늘이었다.","ifFlags":["sc_leak"]}`
- **daeun_r00** (같은 날짜 축의 잔여 줄. D2 에 나오므로 "내일"은 첫 출근이 아니다)
  - C1.reply[1] (문자열): `{"who":"them","text":"…그거 좀 웃기네요. 내일 봐요.","ifNotFlags":["sc_leak"]}`
  - 추가: `{"who":"them","text":"…그거 좀 웃기네요. 출근 날 봐요.","ifFlags":["sc_leak"]}`
  - C1.fail.album: `"첫 출근 앞두고 새벽 드립 헛스윙"`
- 클래식은 r01 이 하루 늦게 열리는 것 말고는 바뀌지 않는다.

### R3-2 · P1 · jeongwoo_r00 (2차 R5 미해결)

2차 R5 는 두 가지였다. L4 문구를 고치고, `sc_swap_d2_m` 에 `jeongwoo_met` 을 세우는 것이다. 문구만 들어갔다.
그래서 sc_swap 남성 쪽 44회차 중 36회차에서 다음 순서가 그대로 나온다(추적 `sc_swap-m-b0-s0-conf-focus`).
1. D2 아침: 정우가 회의 중 개인톡을 보낸다. "괜찮아? 아니, 안 괜찮겠다" → "남을게요" → "고마워. 사탕 있어."
2. 같은 날 밤 `jeongwoo_r00`: "1분 뒤, 개인톡 알림이 떴다." → "…회장이라 인사는 해야 해서. **반가워.**"

여성 쪽 `seoyeon_r00` 은 `swap_senior_met` 로 갈라 놓았다(P2 15번 참고). 같은 방식으로 맞춘다.

교체안 (jeongwoo_r00)
- L4 에 `"ifNotFlags":["swap_senior_met"]` 를 더한다(`ifFlags:["sc_swap"]` 는 그대로).
- 추가: `{"who":"them","text":"공지는 공지고. 아까 정리 도와줘서 고마웠어. 하하.","ifFlags":["swap_senior_met"]}`
- C2 에 `"ifNotFlags":["swap_senior_met"]` 를 단다("신입한테 전부 이렇게 보내세요?"는 이미 따로 챙김을 받은 뒤라 성립하지 않는다).

### R3-3 · P1 · 고정 시각 장면 5종의 지문·말풍선 시각 불일치 (E7 과 겹친 회귀)

E7(같은 날 시계는 거꾸로 가지 않는다) 때문에, 메인 사슬이 아닌데 `clock` 을 가진 장면은 앞 장면 뒤로 밀린다.
그런데 지문이 시각을 직접 말한다. 추적에서 아래 장면은 나올 때마다 **전부** 밀렸다.

| 장면 | 지문 | 화면 시각 | 밀린 횟수 |
|---|---|---|---|
| `c_heat_meltdown` | "새벽 4시. 알림 999+." | 오전 10:00~10:07 | 38/38 |
| `sc_clip_open_2` | "새벽 두 시. 게임 아이콘이…" | 오후 12:09~1:01 | 12/12 |
| `c_clip_truth` / `_m` | "새벽 세 시. 소희의 목소리가…" / "새벽 세 시. 민재가…" | 오후 12:13 | 8/8 |
| `sc_swap_trainer` / `_m` | "아침 7시 헬스장." | 오후 12:30~12:39 | 10/10 |

- 2차 P2 교체안(`sc_clip_open_2` 를 D2~3 으로, trainer 를 D3 으로)은 들어갔다.
- 그런데 D2·D3 메인 뒤에 `d_open_bet`·`d_brief_alt` 사슬과 일상이 먼저 오기 때문에 효과가 없다.
- D1 사슬 자식(`sc_leak_d1a` 01:20→01:27 등)도 몇 분 밀린다. 지문에 시각이 없어 문제는 없다.

교체안 (대본만으로 푼다. 지문에서 시각을 빼고 `clock` 을 지운다)
- **c_heat_meltdown**: `"clock"` 삭제 · L0 `{"who":"narr","text":"알림 999+. 밤사이 쌓인 숫자다."}`
- **sc_clip_open_2**: `"clock"` 삭제 · title `"다시 그 게임"` · L0 `{"who":"narr","text":"게임 아이콘이 오늘따라 크다."}`
- **c_clip_truth**: `"clock"` 삭제 · L0 `{"who":"narr","text":"소희의 목소리가 평소보다 한 톤 낮다."}`
- **c_clip_truth_m**: `"clock"` 삭제 · L0 `{"who":"narr","text":"민재가 평소보다 늦게 접속했다."}`
- **sc_swap_trainer** / **sc_swap_trainer_m**: `"clock"` 삭제 · L0 `{"who":"narr","text":"헬스장. 데스크 직원이 비어 있던 트레이너를 불러 세웠다."}`
- **sc_swap_d1c** C0.reply[0]: `{"who":"them","name":"헬스장 직원","text":"모레로 잡아 둘게요. 시간은 트레이너가 맞춘대요"}`
- 엔진으로 풀려면: `planDay` 가 고른 하루 큐를 `clock` 이 있는 장면부터 시각순으로 세운다(메인 사슬 다음). 그러면 위 지문을 살릴 수 있다. 엔진 담당이 고르면 이 행의 교체안은 필요 없다.

---

## 2. 2차 행 확인

- ✓ = 교체안대로 들어갔고 새 모순이 없다.
- = = 다른 방식으로 고쳤고 결과가 맞다.
- ◐ = 들어갔지만 일부만 들어갔거나 새 모순이 생겼다.

### 2.1 P0·P1 12행 (전부)

| r2 행 | 결과 |
|---|---|
| R1 sc_leak 첫 출근·r00 | ◐ `leak_dm`(D2 C0~C2), daeun·haneul r00 갈래, `firstLine`, haneul 클리프행어는 모두 ✓. r01 날짜만 다른 방식으로 고쳐서 회귀 → **R3-1** |
| R2 sc_speech_d3 진상 갈래 | ✓ L5/L6, C0.reply[0]/[1], D2 C2/C3 모두 들어갔다. 추적에서 자기 업로드 갈래가 처음부터 끝까지 이어진다 |
| R3 sohee_r00 / minjae_r00 | ✓ |
| R4 seoyeon_r00 | = `seoyeon_met` 대신 `swap_senior_met` 와 L3("이건 단톡용 인사고. 커피는 잘 마셨고?")로 풀었다. r00 클리프행어는 D1·D2 메인 클리프행어가 덮어서 보이지 않는다. 남은 다듬기 → P2 15번 |
| R5 jeongwoo_r00 | ◐ L4 만 들어갔다 → **R3-2** |
| R6 jiwoo_r01 / `jiwoo_sms` | ✓ 추적에서 r00_ghost 는 D2(40/44), r01 은 D6~7 에 나온다. "문자로는 이미 며칠째다"가 맞다 |
| R7 sc_leak_ghostread | ✓ 제목 "읽음 6의 정체", L2 "여섯 명" |
| R8 d_brief_alt | ✓ L14~L16, L20~L22. 추적: "2. 하늘. 카페 알바. 어젯밤 톡 왔다며?" |
| sc_leak_settle_open L7 | ✓ (지금 L10 "그 문장을 지금 보내고 싶은 사람이 떠올랐다. 단톡 말고, 직접."). 다만 m36 결과와 새로 부딪친다 → N-1·N-2 |
| sc_leak_ghostread C1 | ✓ |
| geonwoo_r01 | ✓ L1·L2 "부케다!", C0.reply[1]. "20년"도 함께 고쳤다 |
| sohee_r01 | ✓ L1, C0.reply[1] |

### 2.2 P2 33행 (전부)

| r2 행 | 결과 |
|---|---|
| sc_leak_ghostread L4·L5 | ✓ (L6~L9 대사 네 줄) |
| sc_leak_settle_open trigger / `_out` 사본 | = 사본은 만들었다. open 은 호감 대신 `leak_for_out` 으로 갈랐다. 다만 `_out` 의 날짜가 새 문제를 만든다 → N-1 |
| sc_clip_settle_open L3 | ✓ (지금 L5) |
| sc_clip_sorry_back trigger | ✓ `notFlags:["villain_move"]` |
| sc_clip_sorry_back C2 | ✓ "부끄러워서 방송 창을 닫는다" |
| sc_clip_d1b C1 | ✓ `sc_clip_deny` |
| sc_clip_d1c cliffhanger | ✓ "2탄 준비 중. 제보 받음" |
| sc_clip_open_2 trigger | ◐ D2~3 으로 옮겼지만 여전히 밀린다 → R3-3 |
| d_open_bet L7 | ✓ "마이크 켜고 정식으로 고백하면 치킨 추가" |
| sohee_r00 L6 | ✓ (L6·L7) |
| sc_speech_meme L2 | ✓ "과 동기" |
| a_hustle_mc_sequel L2 | ✓ |
| sc_swap_trainer / sc_swap_d1c | ◐ D3·"모레"로 맞췄지만 밀린다 → R3-3 |
| sc_swap_settle C1.reply[0] | ✓ |
| sc_ghost_d2 L3 | ✓ "어제 아침 잡힌 태현이" |
| sc_ghost_d1a cliffhanger | ✓ 은행나무 |
| jiwoo_r00_ghost L1·L2 | ✓ |
| seunghyun_r00_ghost | ✓ (L1, L3/L4, C0 "좋아요. 확실히.") |
| sc_ghost_d3 C2 / c_ghost_exposed C1 "(진상)" | ✓ |
| sc_ghost_hunt_file / m37 | ✓ `ghost_file_asked` → m37 L7 |
| c_villain_trial 피해자 줄 | ✓ L3, L5/L6, L8/L9 |
| d_villain_rival_ghost L1 | ✓ |
| d_villain_rival_swap L1·C2 | ✓ |
| d_villain_rival L0 | ✓ "(9)" |
| 읽음 11 → 10 (3곳) | ✓ |
| d_villain_fan C2.reply[1] | ✓ |
| a_hustle_stream_hot failReply | ✓ |
| cameo_groomfriend L3 | ✓ |
| cameo_clipmaster trigger | ✓ `heat [20,100]` |
| d_street_09 L1 | ✓ |
| starts.json castLines | ✓ 다섯 시작 모두 |
| geonwoo_r01 "13년" → "20년" | ✓ C0.reply[0], C2.critReply[1] |
| 금액 띄어쓰기 | ✓ 남은 것 0건("오백 원 동전", "천 원짜리 두 장"은 화폐 이름이라 그대로 둔다) |

---

## 3. 새 문제

### N-1 · P1 · sc_leak_settle_out 이 m36 보다 먼저 나온다

trigger 가 `"day":[90,100]` 이고 가중치가 30이라 거의 언제나 **D90** 에 뜬다. 추적에서 `leak_for_out` 24회차가 전부 D90 이었다.
이때는 m36 플래그가 하나도 없다. 그래서 `ifNotFlags` 로 서로를 막던 줄과 선택지가 **둘 다** 보인다.
```
narr: 그 문장을 지금 보내고 싶은 사람이 떠올랐다. 단톡 말고, 직접.
narr: 보낼 사람은 없다. 그래도 문장은 남았다.
> [C0] 정답은 단톡 말고 직접 보냅니다 … 받는 사람은 다은. 세 번 확인했다.
(같은 화면에 C1 "정답은 제 메모장에 둡니다"도 열려 있다)
```
이틀 뒤 m36 이 같은 고백을 다시 묻는다. 같은 날 `d_bet_settle_double` 까지 겹쳐 D90 에 정산이 두 번 나온다.

교체안
- **sc_leak_settle_out** trigger `"day"`: `[90,100]` → `[93,100]`

### N-2 · P1 · m36 고백 성공(`m36_confessed`) 뒤의 대체판 정산

대체판(`*_settle_open`, `_out`)은 시작 짝의 호감이 55 미만이거나 m36 상대가 다른 사람일 때 뜬다. 그런데 `m36_confessed` 를 `m36_idle` 과 같은 쪽으로 묶었다.
그래서 사흘 전에 "같은 마음인 건 진작이었어"라는 답을 받은 사람이 고백을 처음 하는 장면을 또 본다.
- leak (추적 `sc_leak-f-r4-conf-random`): m36 에서 유나에게 고백했고 성공했다. 그런데 D96 정산의 C0.reply 가 "그날 밤 그 문장을 다시 썼다. 받는 사람은 유나. … '근데 넌 모르겠지'는 지웠다. 이제는 알게 할 거니까."이다.
- ghost (추적 `sc_ghost-f-b0-s0-conf-focus`): m36 에서 다은에게 고백했고 성공했다. m36 L14 는 "이번 문장은 대신 써 줄 사람이 없다"였다. 그런데 D96 정산의 C1 은 "다은에게 **처음으로** 내 문장을 보낸다"이다.
- clip·speech 대체판은 고백 성공과 부딪치지 않는다.

교체안
- **sc_leak_settle_open**, **sc_leak_settle_out** (두 이벤트에 똑같이)
  - L10 의 `ifNotFlags` → `["m36_parted","m36_rejected","m36_confessed"]`
  - 추가: `{"who":"narr","text":"그 문장은 며칠 전 이미 한 사람에게 갔다. 단톡만 모를 뿐이다.","ifFlags":["m36_confessed"]}`
  - C0 의 `ifNotFlags` → `["m36_parted","m36_rejected","m36_confessed"]`
  - C0 뒤에 새 선택지를 더한다:
    `{"text":"정답은 이미 직접 보냈습니다","ifFlags":["m36_confessed"],"effects":{"stats":{"sincerity":3,"heat":-5},"trust":{"@top":3},"setFlags":["sc_leak_settled"]},"reply":[{"who":"them","name":"막내","text":"헐 ㅋㅋ 단톡 말고 직접 갔다고요?"},{"who":"them","name":"점장","text":"업무방입니다. 축하합니다."},{"who":"narr","text":"'근데 넌 모르겠지'는 이제 틀린 문장이다. {top|은는} 안다."}]}`
- **sc_ghost_settle_open**
  - C1 의 `ifNotFlags` → `["m36_parted","m36_rejected","m36_confessed"]`
  - C1 뒤에 새 선택지를 더한다:
    `{"text":"{top}에게 오늘 하루를 내 문장으로 보낸다","ifFlags":["m36_confessed"],"effects":{"stats":{"sincerity":3,"talk":2},"affection":{"@top":2},"setFlags":["sc_ghost_settled"]},"reply":[{"who":"narr","text":"고백은 며칠 전에 했다. 이번 건 그냥 오늘 얘기다. 새벽 3시 말고, 오후에."},{"who":"narr","text":"{top|이가} 답장 대신 전화를 걸어 왔다."}]}`

### N-3 · P1 · m36 "아무것도 하지 않는다"(`m36_idle`) 뒤의 sc_speech_settle_open

m36 C2 의 답은 "아무것도 보내지 않았다. 대화방은 92일째에 멈췄다."이다.
그런데 sc_speech 대체판은 `m36_idle` 을 고백 성공과 같은 쪽으로 묶었다. 그래서 이 갈래에서 다음이 뜬다.
- L3 "요즘 스토리에 같이 나오는 사람 누구임?"
- L7 "어제 {top|과와} 찍은 사진 한 장."
- C0 "축사 2편 주인공", reply "5분 뒤 {top|이가} 톡을 보냈다."

sc_speech 에서 m36 을 비운 회차는 모두 이 대체판을 본다(추적 20/20).
leak·clip·ghost 의 idle 쪽 줄은 "떠올랐다", "누구 때문인지", "아직" 같은 말이라 성립한다.

교체안 (sc_speech_settle_open)
- L3: `"ifNotFlags"` 를 지우고 `"ifFlags":["m36_confessed"]`
- L4: `"ifNotFlags":["m36_confessed"]`
- L7: `"ifNotFlags"` 를 지우고 `"ifFlags":["m36_confessed"]`
- L8: `"ifNotFlags":["m36_confessed"]`
- C0, C1: `"ifNotFlags"` 를 지우고 `"ifFlags":["m36_confessed"]`
- C2: `"ifNotFlags":["m36_confessed"]`

### N-4 · P1 · m36 정리·거절 뒤 "혼자"를 못 박는 정산 → 해피 엔딩

새 대체판은 정리(`m36_parted`)·거절(`m36_rejected`) 갈래에서 혼자 남았다고 말한다.
- leak L11: "보낼 사람은 없다. 그래도 문장은 남았다."
- speech L8: "요즘 스토리엔 혼자 찍은 사진뿐이다."
- clip C2: "듣는 사람이 없어도"

그런데 해피 엔딩 24개의 `when` 은 m36 을 보지 않는다. 집중 플레이(짝 호감을 올리는 봇)는 m36 결과와 관계없이 **80/80 해피**였다.
- 정리: "{top}과 정리한다" → "고마웠다는 말은 진심이야" → D96 "보낼 사람은 없다" → D100 에필로그 "전부 {name}."
- 거절은 m36 C0 의 45% 실패 확률로 생긴다. 고백한 플레이어의 거의 절반이 이 길을 탄다.

정리 → 해피는 클래식에도 있던 구조다. 이번에 대본이 그 사이에 "혼자" 줄을 넣으면서 바로 앞뒤로 부딪치게 됐다.

교체안
- 엔딩(기획 결정 필요): `endings.json` 의 tier `happy` 24개 `when` 에 `"notFlags":["m36_parted"]` 를 더한다. 거절은 "지금은 대답 못 하겠어"라 나중에 이어져도 성립하므로 막지 않는다.
- 대본(엔딩 결정과 무관하게 넣는다): **sc_leak_settle_open**, **sc_leak_settle_out** 의 L11 을 두 줄로 나눈다.
  - `{"who":"narr","text":"대답은 아직 오지 않았다. 문장은 지우지 않았다.","ifFlags":["m36_rejected"]}`
  - `{"who":"narr","text":"정리하자고 한 건 나였다. 문장은 남겨 두기로 했다.","ifFlags":["m36_parted"]}`
  - C1.reply[1]: `{"who":"narr","text":"지금 보낼 데가 없어도 문장은 남았다. 이번엔 지우지 않았다."}`

### P2 표

| # | 이벤트 id | 위치 | 문제 | 교체안 |
|---|---|---|---|---|
| 1 | sc_leak_settle / _m | C0, C0.reply[2] | 부계정 몰표 갈래(`leak_rigged`)에서는 L6 이 "1위 점장님"이다. 그런데 C0 이 "1위 맞습니다", reply[2] 가 "1위가 단톡에 처음으로 글을 올렸다"이다. | C0 text: `"결과 공개. 셀프 투표한 사람, 맞습니다. 대답도 이미 들었고요"` · reply[2]: `{"who":"narr","text":"셀프 투표한 사람이 단톡에 처음으로 글을 올렸다. 한 줄이었다."}` |
| 2 | sc_leak_settle / _m / _open / _out | L0 | D1 부터 방 이름은 "(수사본부)"다(`sc_leak_d2`, `d_villain_rival_leak`, `sc_leak_mid`). 정산 L0 만 "(11)"로 돌아간다. open C3 은 "단톡 이름이 원래대로 돌아갔다"라고 해서 직전까지 수사본부였다는 전제다. | 네 곳 L0: `{"who":"sys","text":"카페 알바방 (수사본부) · 공지"}` |
| 3 | sc_leak_settle_open | L6, C2 | trigger 가 `leak_for_out` 을 막으므로 `ifFlags:["leak_for_out"]` 인 L6·C2 는 이 이벤트에서 절대 보이지 않는다(`_out` 에만 필요). | open 의 L6·C2 를 지운다(`_out` 은 그대로) |
| 4 | sc_leak_settle / sc_speech_settle / sc_clip_settle / sc_ghost_settle (+_m) | trigger, L7(leak)·L4(speech)·L2(ghost) | "며칠 전 개인톡으로 먼저 말했다", "며칠 전 둘이서만 한 대답"은 m36 고백 상대가 시작 짝이라는 전제다. trigger 는 짝 호감 ≥55 와 `m36_confessed` 만 본다. 다른 사람이 1위라 그 사람에게 고백했으면 틀린다. 추적에서는 0/74 였다(드묾). | 엔진 계약을 더한다: trigger `"top":["daeun","haneul"]`(호감 1위가 이 안에 있을 때만). 각 정산에 시작 짝 둘을 적는다. 엔진을 건드리지 않으려면 그대로 둔다 |
| 5 | sc_ghost_settle / _m | L2 | "며칠 전엔 **말로** 들었으니까"라고 한다. m36 고백은 기본이 톡이다("읽음. 그리고 긴 침묵."). 전화는 크리티컬일 때뿐이다. | `{"who":"them","name":"{char:jiwoo,seunghyun}","text":"며칠 전 고백은 잘 받았어요. 이번엔 그쪽 문장으로 한 편 받고 싶어요. 새벽 3시 말고, 지금."}` |
| 6 | c_villain_trial | L0, L22, C2.reply[1] | 방 인원 "(9)"와 "아홉 명이 동시에 '입력 중'"이 고정이다. 실제 발언자 수는 갈래마다 다르다. 클래식 진상 회차는 태현·친구·익명 셋·엄마뿐인데도 "아홉 명"이다. sc_leak 진상 회차는 아홉을 넘는다. | L0: `{"who":"sys","text":"'재판' 단톡방 · 피고인 1"}` · L22: `{"who":"narr","text":"피고인만 빼고 전원이 동시에 '입력 중'이다."}` · C2.reply[1]: `{"who":"narr","text":"댓글 1위: '피해자가 한 방 가득인데 마녀사냥?'"}` |
| 7 | c_villain_trial | L20 앞 | 진상 승리 고유 플래그 `v_stream_gossip`(a_hustle_stream C2)과 `v_mom_content`(d_street_03 C3)를 읽는 곳이 없다. 대가 없는 승리다. | L20 앞에 추가: `{"who":"them","name":"익명","text":"이름만 가린 방송 썰 주인공입니다. 다 알아들었어요","ifFlags":["v_stream_gossip"]}` · L20 에 `"ifNotFlags":["v_mom_content"]` · 추가: `{"who":"them","name":"엄마","text":"엄마 말투 스티커 수익은 엄마 몫이다. 밥은 먹고 다니니","ifFlags":["v_mom_content"]}` |
| 8 | d_villain_rival_speech | L4 | `v_roast` 는 `sc_speech_invite` C3(동창 **결혼식** 사회에서 신랑 흑역사 폭로)이다. 그런데 신랑 친구가 "**돌잔치** 폭로 코너"라고 한다. | `{"who":"them","name":"신랑 친구","text":"동창 결혼식 폭로 코너 영상도 제 단톡까지 왔고요","ifFlags":["v_roast"]}` |
| 9 | d_street_08 | C3.reply[0] | 대가 줄 두 곳(`d_villain_rival.L4`, `c_villain_trial.L13`)과 `d_villain_fan.L4` 가 "'되요' 50번"을 근거로 든다. 그런데 승리 장면에는 맞춤법 얘기가 없다. 복선을 심는다. | `{"who":"narr","text":"칭찬 글 50개. 전부 '진짜 멋있는 사람 되요'로 끝났다. 익명 게시판 인기글 1위가 바뀌었다."}` |
| 10 | d_villain_rival_leak | L2, L3 | `v_maknae_notice` 만 있는 회차는 "첨부 1" 없이 "첨부 2"가 나온다. | L2 text: `"첨부. 부계정 열 개 투표 기록"` · L3 text: `"첨부. 제 작년 메시지 공지 건. 아직 안 잊음"` |
| 11 | villain_legend | epilogueMbti.SP | "천원은 안 받았다"는 `v_paid_selfie` 를 고른 회차에서만 뜻이 통한다. 에필로그는 조건을 달 수 없다. | `"편의점 알바생이 먼저 인사했다. 사진은 공짜로 찍어 줬다."` |
| 12 | sc_speech_reunion | L0 | 동창회는 이미 `yeeun_r01`·`geonwoo_r01`(D4 무렵 폐교 소식 동창회)에 한 번 나왔다. D65 의 "6학년 3반 동창회"가 첫 동창회처럼 읽힌다. | `{"who":"sys","text":"6학년 3반 (21) · 두 번째 동창회"}` |
| 13 | sc_ghost_mid | L1 | 진실 갈래(`sc_ghost_truth`, D1 "그거 저 아니에요")와 자백 갈래(`ghost_confessed`)에서도 엄마가 "그 집 어머니가 **너 시** 얘기만 한 시간 했어 … 엄마는 몰랐는데"라고 한다. | L1 에 `"ifNotFlags":["sc_ghost_truth","ghost_confessed"]` · 추가: `{"who":"them","name":"엄마","text":"미용실에서 그 집 어머니를 만났다. 시는 친구가 썼다며? 그래도 그 집 애는 네 문자가 더 좋대","ifFlags":["sc_ghost_truth"]}` · 같은 줄을 `"ifFlags":["ghost_confessed"],"ifNotFlags":["sc_ghost_truth"]` 로 한 번 더 |
| 14 | sc_clip_settle_open | L2 | L1(`sc_clip_guest`)이 "합방 게스트로 시작한 자리가 고정석이 됐다"인데, 바로 다음에 듀오가 "오늘 특별 손님"이라고 소개한다. | L2 에 `"ifNotFlags":["sc_clip_guest"]` · 추가: `{"who":"them","name":"듀오","text":"오늘도 고정 손님. 그 클립 주인공 ㅋㅋ","ifFlags":["sc_clip_guest"]}` |
| 15 | seoyeon_r00 | L3, C2 | (2차 R4 의 남은 다듬기) L4 가 "단톡방 전원이 보고 있다"인데 L3 이 단톡에서 "커피는 잘 마셨고?"를 묻는다. 둘만의 일을 공개해 버린다. C2 "아닌 것 같은데요"는 몇 시간 전 커피를 같이 마신 선배에게 할 수 없는 답이다. | L3: `{"who":"them","text":"이건 단톡용 인사. 커피 얘기는 개인톡에서.","ifFlags":["swap_senior_met"]}` · C2 에 `"ifNotFlags":["swap_senior_met"]` |
| 16 | sc_leak_d2 / sc_leak_d2_m | L8 | D1 에 r00 으로 번호를 저장한 회차는 L8 이 "어제 저장한 그 번호다"이다. 그런데 화자 이름표는 L9~L12 내내 "저장 안 된 번호"다. 추적 16/88. | 두 이벤트 L8: `{"who":"narr","text":"그리고 개인톡. 어제 그 번호다. 저장 버튼을 아직 안 눌렀다.","ifFlags":["daeun_contact"]}` (`_m` 은 `"ifFlags":["haneul_contact"]`) |
| 17 | haneul_r00 | L7 | sc_leak 의 카페에는 "점장"이 있다. 단톡에서 계속 말하는 사람이다. 하늘만 "사장님이 물어보래"라고 한다. | L7 에 `"ifNotFlags":["sc_leak"]` · 추가: `{"who":"them","text":"앞치마 사이즈 뭐야? 점장님이 물어보래","ifFlags":["sc_leak"]}` |

---

## 4. 목소리 검사기 (스크래치 사본)

- 사본: `…/scratchpad/r3/vc/check_voice.py`. 원본은 고치지 않았다.
- 바꾼 곳
  - `STORY` 를 절대 경로로 바꿨다.
  - `EVENT_FILES` 에 `events_start.json`·`events_freedom.json` 을 더했다. 원본은 이 두 파일을 읽지 않는다.
- 결과: 사본과 원본 모두 **위반 0건**이다.
- 경고(위반 아님. 50줄 미만이라 비율만 높다)는 2차와 같다.
  - `다은` "…" 3/25 = 12.0%
  - `지우` 4/36 = 11.1%
  - `승현` 3/28 = 10.7%
  - 이번 교체안은 이 세 사람에게 "…"를 더하지 않는다.
- 시그니처: 태현 "캡처" 2회로 상한과 같다. 교체안의 태현 대사에는 "캡처"·"박제"가 없다.
- 새 글 목소리 판정(검사기 밖, 직접 읽음)
  - 점장 "업무방입니다", 막내 "ㅋㅋ"·보고서 말투, 신랑 친구, 클립 장인, 서진 "ㅎㅎ", 다은 단문 존댓말, 하늘 반말 "ㅋㅋ", 지우·승현 존댓말: 모두 기준선 안이다.
  - 진상 승리 리액션(narr)이 "통했다"로 끝나고 대가는 뒤로 미룬다. E4 의도대로다.

## 5. 플레이스루 추적

- 방법
  - `lib`·`assets` 를 스크래치(`…/scratchpad/r3/repo`)에 복사했다.
  - `test/trace_test.dart` 를 썼다. 실제 `GameController` 로 하루를 시작하고, 선택하고, 하루를 끝낸다.
  - 장면마다 보이는 줄, 고른 선택지, 결과 반응 줄, 말풍선 시각, 클리프행어를 텍스트로 남겼다(`…/scratchpad/r3/traces/*.txt`, 528개).
- 격자: 시작 6개(클래식 포함) × 선호 f/m × D1 갈래 4 × 사슬 자식 갈래 2 × m36 결과 4 → 시작마다 64회차.
  - m36 의 성패는 강제로 정했다.
  - 나머지 선택은 짝 호감을 올리는 쪽(집중)으로 골랐다.
- 보충: 시작마다 무작위 봇 12회차, 진상 봇 12회차를 더 돌렸다. 진상 봇은 "(진상)"이 보이면 고르고, 아니면 집중으로 고른다.
- 각 시작은 D1 의 모든 갈래를 지난다. 예: sc_leak 은 삭제·드라마·대범 × `leak_for_out` 유무.

정산 결과 (시작 × m36, 회차 수)

| 시작 | 고백 성공 | 거절 | 정리 | 안 함 | 2막(D55~80) 노출 |
|---|---|---|---|---|---|
| sc_leak | settle 16 · open 4 · **out@D90 4** | open 16 · **out@D90 8** | open 16 · **out@D90 4** | open 12 · **out@D90 8** | 85/88 |
| sc_speech | settle 20 · open 4 | open 24 | open 20 | open 20 | 87/88 |
| sc_clip | settle 20 · open 4 | open 24 | open 20 | open 20 | 80/88 |
| sc_ghost | settle 18 · open 6 | open 24 | open 20 | open 20 | 73/88 |
| sc_swap | settle@D90 24 | settle@D90 24 | settle@D90 20 | settle@D90 20 | (back 으로 대신) |

- 시작별 읽은 결과
  - **sc_leak**: D1~D3 은 단단하다. `leak_dm` 덕분에 D2 밤 r00 이 낮의 "저장 안 된 번호"를 정확히 이어받는다.
    - D4 r01 → R3-1
    - `leak_for_out` 정산 → N-1
    - 고백 성공 대체판 → N-2
    - 2차에서 빈칸이던 캡처 갈래는 `sc_leak_mid` 가 채웠다.
  - **sc_speech**: 축사 → 부케 → 2편 → 밈 → 동창회(2막) → 정산이 끊김 없이 간다.
    - idle 대체판 → N-3
    - 동창회 중복 → P2 12번
  - **sc_clip**: 2막(오프 정모)의 세 갈래가 정산의 L4~L6 으로 모두 돌아온다.
    - 새벽 장면 시각 → R3-3
    - 고정석 → P2 14번
  - **sc_swap**: 서진 축 정산은 m36 과 부딪치지 않는다(짝을 말하지 않는다).
    - D2 정우 → R3-2
    - 서연 → P2 15번
    - 헬스장 시각 → R3-3
  - **sc_ghost**: 문자 첫 접촉(D2) → 엄마 소개(D6) → 2막 미용실 → 정산이 매끄럽다.
    - 고백 성공 대체판 → N-2
    - 진실 갈래 엄마 줄 → P2 13번
  - **클래식**: m36 플래그를 읽는 줄이 없다. 2차 이후 변화가 없다.
- 공통
  - 정리·거절 뒤 해피 엔딩 → N-4
  - 진상 봇 72회차의 대가 줄은 모두 맞는 플래그로 떴다. 재판 인원 → P2 6번. 읽히지 않는 플래그 → P2 7번
- 범위 밖 관찰(엔진·기획 담당에게 넘긴다)
  - 진상 봇이 진상 선택을 쌓아도 신규 시작 60회차의 엔딩이 60/60 해피였다(집중 봇과 같다). 진상이 해피를 거의 막지 못한다.
  - `sc_ghost` 여성 쪽 진실 갈래(`b0-s0`)에서 `jiwoo_r02`(trigger D27~28 고정)를 놓쳤다. 그 뒤 지우 호감이 0까지 떨어지고 루트가 멈췄다.
