# 개편 2 — 2차 대본 리뷰 (줄 단위)

> 2026-10-07 · NarrativeDesigner · 브랜치 `overhaul2-starts`(커밋 전 작업본) · 게임 파일은 고치지 않았다.
>
> 범위
> - 1차 수정 반영 확인: `r1_script.md` 의 P0·P1 85행 중 52행을 현재 JSON 과 대조했다.
> - 새로 들어온 글과 바뀐 글:
>   - `d_villain_*`, `c_villain_trial`, `cameo_*`, `*_settle_open`
>   - `sc_leak_ghostread`, `sc_leak_drama`, `sc_speech_meme`, `sc_clip_sorry_back`, `sc_swap_cool_cost`, `sc_ghost_hunt_file`
>   - `jiwoo_r00_ghost`, `seunghyun_r00_ghost`, `d_street_06_m`, `d_street_09`/`_m`, `a_hustle_stream_hot`
>   - route 파일들의 r00·r01 파급 줄, `starts.json` 의 인트로 문구와 `castLines`, 이벤트 `clock`, `villain` 스탯
> - 함께 본 엔진 코드:
>   - `game_controller.dart` 의 `_noteCliffhanger`(D6, 사슬 자식 클리프행어 우선)와 `done_`·`veteran` 세우기
>   - `event_engine.dart` 의 `planDay` 순서(메인 → 위기·일상 → 루트)와 `eagerStartCharacter`(D11, **D2부터 가속 캐릭터 r00 강제**)
>   - `text_template.dart` 의 `{top}` 해소(가속 캐릭터도 `{top}` 이 될 수 있다), `story_repository.dart` 의 `firstLineOf`(첫 메시지 미리보기는 조건 없는 첫 `them` 줄)

## 표기

1차와 같다. `L3` = `lines[3]`, `C2` = `choices[2]`, `C2.reply[1]`. 인덱스는 0부터 센다.
등급 **P0** 깨짐·모순(거의 모든 회차에 보임) / **P1** 확실히 약함, 갈래 한정 모순, 캐릭터 이탈 / **P2** 다듬기.
교체안은 그대로 JSON 에 붙여 넣을 수 있게 썼다. "추가"는 바로 앞에 적은 줄 뒤에 넣는다는 뜻이다.

## 0. 요약

| 구분 | P0 | P1 | P2 | 합 |
|---|---|---|---|---|
| 회귀·새 모순(1차 수정에서 생김) | 1 | 7 | 0 | 8 |
| 새 문제(새 글·바뀐 글) | 0 | 4 | 33 | 37 |
| **합계** | **1** | **11** | **33** | **45** |

- 목소리 검사기는 위반 0건이다(아래 4절).
- `clock` 값 17개는 모두 지문의 시각과 맞는다. 다만 같은 날 앞 장면보다 이른 시각이 찍히는 순서 문제가 2건 있다(P2).
- 돈 표기는 새 글 전부 "N만원"·"N천원"이고 효과값과도 맞는다. 띄어 쓴 표기는 기존 글에만 남았다(P2 한 행).
- 12+ 기준에 걸리는 것은 없다.

---

## 1. 회귀와 새 모순 (먼저 고칠 것)

1차 수정은 각각 맞게 들어갔다. 그런데 **D11(D2부터 가속 캐릭터의 r00 을 강제로 낸다)** 과 겹치면서 새 모순이 생겼다.
r00 은 이제 거의 모든 회차에서 D1이나 D2 밤에 나온다. D2 에는 메인 다음 순서다. 그래서 "r00 이 사건보다 먼저 올 수도, 나중에 올 수도 있다"던 1차의 가정이 깨졌다.
이제 r00 은 **D2 메인 직후**에 나온다고 보고 써야 한다.

### R1 · P0 · sc_leak 첫 출근 날짜와 r00 (daeun_r00 / haneul_r00 / r01)

- 1차 수정으로 `sc_leak_d1.L3` 이 "사흘 뒤 첫 출근"(D4)이 됐고 D2·D3 클리프행어도 거기에 맞췄다.
- 그런데 r00 은 D2 밤에 나와서 "내일이 카페 알바 첫 출근이다"(daeun L0·L1), "내일 마감 조 같이야"(haneul L1), 클리프행어 "내일 5시 50분"이라고 한다.
- 같은 날 `sc_leak_d2` 에서 "저장 안 된 번호"로 "그거 누구 얘기예요?"를 보낸 사람이다. 그런데 몇 시간 뒤 "모르는 번호"로 처음 인사하고, 다은은 "그 문장은 못 본 걸로 할게요"라고 한다.
- 남성 쪽 하늘은 낮에 "이름은 출근하면 알려 줌"이라고 하고 밤에 "나 하늘"이라고 한다.
- `r01`("알바 첫날", day 3+)이 D3 에 나오면 D3 클리프행어 "첫 출근 날"(D4)과 또 엇갈린다.
- 추천 시작(`recommended`)의 2일차에 거의 매번 보이는 모순이라 P0 으로 둔다.

교체안
- `sc_leak_d2`·`sc_leak_d2_m` 의 C0~C2 `effects.setFlags` 에 `"leak_dm"` 을 더한다.
- **daeun_r00**
  - L0 에 `"ifNotFlags":["sc_leak"]` 를 단다. 그 뒤에 두 줄을 추가한다:
    - `{"who":"narr","text":"밤 10시. 첫 출근이 코앞이다. 모르는 번호로 톡이 왔다.","ifFlags":["sc_leak"],"ifNotFlags":["leak_dm"]}`
    - `{"who":"narr","text":"밤 10시. 아까 그 저장 안 된 번호에서 한 줄 더 왔다.","ifFlags":["leak_dm"]}`
  - L1 에 `"ifNotFlags":["sc_leak"]` 를 단다. 그 뒤에 추가: `{"who":"them","text":"첫 출근 날 오픈 조 같이에요. 6시 50분.","ifFlags":["sc_leak"]}`
  - L4 에 `"ifNotFlags":["leak_dm"]` 를 단다. 그 뒤에 추가: `{"who":"them","text":"아까 물어본 건 잊어요. 대답은 출근해서 들을게요.","ifFlags":["leak_dm"]}`
- **haneul_r00**
  - L0 에 `"ifNotFlags":["sc_leak"]` 를 단다. 그 뒤에 두 줄을 추가한다:
    - `{"who":"narr","text":"첫 출근이 코앞이다. 저장 안 된 번호로 톡이 왔다.","ifFlags":["sc_leak"],"ifNotFlags":["leak_dm"]}`
    - `{"who":"narr","text":"아까 그 '같은 마감 조' 번호에서 또 톡이 왔다.","ifFlags":["leak_dm"]}`
  - L1 에 `"ifNotFlags":["sc_leak"]` 를 단다. 그 뒤에 두 줄을 추가한다:
    - `{"who":"them","text":"나 하늘. 그 단톡 마감 조임. 첫 출근 날 같이야","ifFlags":["sc_leak"],"ifNotFlags":["leak_dm"]}`
    - `{"who":"them","text":"아 출근 날 알려 준다 했는데 못 참겠다 ㅋㅋ 나 하늘","ifFlags":["leak_dm"]}`
  - C0.reply[0]: `"ㅇㅋ M. 출근 날 5시 50분까지. 6시면 늦은 거임"`
  - cliffhanger: `"하늘: \"출근 날 5시 50분. 컵 위치는 내가 알려줄게.\""`
- 클래식의 캐스트 소개 미리보기(`firstLineOf` 는 조건 없는 첫 줄을 고른다)를 지키려면 `characters.json` 에 `firstLine` 을 넣는다.
  - daeun: `"내일 오픈 조 같이에요. 6시 50분."`
  - haneul: `"안녕? 나 하늘. 내일 마감 조 같이야"`
- `daeun_r01`·`haneul_r01` 의 trigger `day` 를 `[3,100]` 에서 `[4,100]` 으로 바꾼다. 클래식에는 영향이 거의 없다.

### R2 · P1 · sc_speech_d3 진상 갈래 (1차 행 "sc_speech_d3 L0, L1" 의 부작용)

L0·L1 을 `speech_self_upload` 로 가른 것은 맞게 들어갔다. 그런데 남은 줄이 내가 올린 영상을 신랑 친구가 내려 주는 장면이 된다.
- L5 "내려 드릴까요?", C0.reply[0] "오늘 밤에 내릴게요"가 그렇다.
- 전날 D2 C2("영상 내려 달라고 신랑 친구한테 DM")도 이 갈래에서는 성립하지 않는다.

교체안
- **sc_speech_d3**
  - L5 에 `"ifNotFlags":["speech_self_upload"]` 를 단다. 그 뒤에 추가: `{"who":"them","name":"신랑 친구","text":"제 원본은 아직 폰에 있어요. 묻어 둘까요? 아니면","ifFlags":["speech_self_upload"]}`
  - C0.reply[0] 에 `"ifNotFlags":["speech_self_upload"]` 를 단다. 그 뒤에 추가: `{"who":"them","name":"신랑 친구","text":"ㅋㅋ 제 건 묻을게요. 올리신 건 직접 내리세요","ifFlags":["speech_self_upload"]}`
- **sc_speech_d2**
  - C2 에 `"ifNotFlags":["speech_self_upload"]` 를 단다.
  - 새 선택지를 더한다: `{"text":"내가 올린 영상을 내린다","ifFlags":["speech_self_upload"],"effects":{"stats":{"heat":-3,"stress":2}},"next":"d_open_bet","reply":[{"who":"narr","text":"내렸다. 재업로드가 이미 세 개였다."},{"who":"narr","text":"그때 태현에게서 톡이 왔다."}]}`

### R3 · P1 · sohee_r00 L2 / minjae_r00 L1 (1차 P0 행, 부분 반영)

1차 교체안은 이 줄들을 `sc_clip` 에서 숨기는 것이었다. 지금은 조건 없이 남아 있다.
- 소희 "님 아까 서폿 좀 치던데?", 민재 "님 아까 그 판 ㄹㅇ 잘함"이 남았다.
- D1~D2 에 이미 반말로 귓속말을 주고받은 듀오가 D2 밤에 "님"으로 첫인사를 한다.
- 소희 L1 "클립 이후 처음으로 길다"도 D2 새벽의 긴 귓속말(`sc_clip_d2`)과 맞지 않는다.

교체안
- **sohee_r00**
  - L1: `{"who":"narr","text":"듀오다. 닉 말고 다른 얘기를 꺼내려는 것 같다.","ifFlags":["sc_clip"]}`
  - L2 에 `"ifNotFlags":["sc_clip"]` 를 단다. 그 뒤에 추가: `{"who":"them","text":"아까 그 판 서폿 ㄱㅊ았음 ㅋㅋ","ifFlags":["sc_clip"]}`
- **minjae_r00**
  - L1 에 `"ifNotFlags":["sc_clip"]` 를 단다. 그 뒤에 추가: `{"who":"them","text":"아까 그 판 ㄹㅇ 잘함. 클립보다 실력이 나음 ㅋㅋ","ifFlags":["sc_clip"]}`
- 미리보기를 지키려면 `characters.json` 에 `firstLine` 을 넣는다.
  - sohee: `"님 아까 서폿 좀 치던데?"`
  - minjae: `"님 아까 그 판 ㄹㅇ 잘함"`

### R4 · P1 · seoyeon_r00 (1차 P1 행, 부분 반영)

L1 에 파급 줄이 생겼지만 핵심 문장이 그대로다.
- L2 "@신입 너 지난주에 강의실 앞에서 나한테 길 물어봤던 사람 맞지?"와 클리프행어 "개인톡 알림은 아직 없다"가 남아 있다.
- D11 때문에 r00 은 D2 메인(`sc_swap_d2`, 서연이 개인톡으로 "회의 끝나고 남아. 커피 살 테니까") **바로 뒤**에 나온다. 커피를 사 준 선배가 몇 시간 뒤 단톡에서 처음 알아보는 꼴이다.

교체안
- `sc_swap_d2` C0~C2 의 `effects.setFlags` 에 `"seoyeon_met"` 을 더한다.
  - r00 의 `notFlags` 가 그 플래그라 D2 뒤에는 r00 이 나오지 않는다.
  - D1 에 먼저 나오면 단톡 첫인사 다음 D2 개인톡 순서라 자연스럽다.
  - 단계 우선순위(`nextStageEvents`)는 후보를 막지 않으므로 r01 은 그대로 이어진다.

### R5 · P1 · jeongwoo_r00 L4 (1차 P1 행의 새 문구)

"회의 때는 인사를 제대로 못 했지."는 D2 정기 회의 뒤를 전제한다. 그런데 r00 은 D1 루트 추첨(1/5)으로 회의 **전에** 나올 수 있다.
D2 뒤에 나오면 회의에서 이미 "괜찮아? 아니, 안 괜찮겠다"로 말을 건 선배의 두 번째 첫인사가 된다.

교체안
- `sc_swap_d2_m` C0~C2 의 `effects.setFlags` 에 `"jeongwoo_met"` 을 더한다.
- L4: `{"who":"them","text":"단톡이 좀 시끄럽지. 그래도 회장이라 인사는 해야 해서. 반가워.","ifFlags":["sc_swap"]}`

### R6 · P1 · jiwoo_r01 L2~L3·C0·C2 와 새 jiwoo_r00_ghost

새 `jiwoo_r00_ghost`(D1~3) 에서 지우는 이미 문자로 "이걸 첫 연락으로 칠게요"라고 했다. 그런데 `jiwoo_r01` 의 sc_ghost 파급 줄과 선택지는 이 사실을 모른다.
- 파급 줄: "이번 첫 메시지는 내 손으로 보낸다."
- C0: "안녕하세요 ㅎㅎ 소개받은 사람입니다" → 답 "저도 이런 자리는 익숙하지 않아서"
- C2 의 답: "저도 엄마 때문에 연락드린 거라서요"

승현 쪽은 `seunghyun_contact` 로 r00 을 건너뛰어서 문제가 없다. 지우 쪽에만 플래그가 없다.

교체안
- `jiwoo_r00_ghost` C0~C2 의 `effects.setFlags` 에 `"jiwoo_sms"` 를 더한다.
- **jiwoo_r01**
  - L2·L3 에 `"ifNotFlags":["jiwoo_sms"]` 를 단다. 그 뒤에 추가: `{"who":"narr","text":"문자로는 이미 며칠째다. 엄마들 소개로 다시 인사하는 건 처음이다.","ifFlags":["jiwoo_sms"]}`
  - C0.reply[0]·[1] 에 `"ifNotFlags":["jiwoo_sms"]` 를 단다. 그 뒤에 추가: `{"who":"them","text":"알아요 ㅎㅎ 문자 그분이잖아요. 엄마들이 우리보다 늦었네요","ifFlags":["jiwoo_sms"]}`
  - C2.reply[1] 에 `"ifNotFlags":["jiwoo_sms"]` 를 단다. 그 뒤에 추가: `{"who":"them","text":"앱에 문자에 이미 바쁘셨잖아요. 괜찮아요","ifFlags":["jiwoo_sms"]}`

### R7 · P1 · sc_leak_ghostread title·L2 ("읽음 6" 수정과 어긋남)

1차 수정으로 삭제 성공은 "읽음은 6에서 멈췄다", 태현에게는 "모름. 최소 여섯"이 됐다. 새 이벤트는 제목 "읽음 4의 정체", L2 "본 사람 네 명"으로 옛 숫자를 쓴다.

교체안
- title `"읽음 6의 정체"`
- L2: `{"who":"them","name":"막내","text":"삭제된 메시지 본 사람 여섯 명 신원 확보"}`

### R8 · P1 · d_brief_alt L14 / L18 (1차 P0·P1 행의 교체 문구)

D3 의 태현이 "이름은 출근해서 직접 봐라", "닉 말고 이름은 아직 모르지?"라고 한다.
그런데 D11 때문에 D2 밤 r00 에서 이미 "다은이에요"·"나 하늘"·"나 소희"·"나 민재"를 들었다.

교체안
- L14 의 `ifNotFlags` 를 `["veteran","daeun_contact","haneul_contact"]` 로 바꾼다. 그 뒤에 두 줄을 추가한다:
  - `{"who":"them","name":"태현","text":"2. {char:daeun,haneul}. 카페 알바. 어젯밤 톡 왔다며? 셀프 투표한 사람은 출근해서 맞혀 봐라","ifFlags":["sc_leak","daeun_contact"],"ifNotFlags":["veteran"]}`
  - 같은 줄에 `ifFlags` 만 `["sc_leak","haneul_contact"]` 로 바꾼 한 줄
- L18 의 `ifNotFlags` 를 `["veteran","sohee_friend","minjae_friend"]` 로 바꾼다. 그 뒤에 두 줄을 추가한다:
  - `{"who":"them","name":"태현","text":"4. {char:sohee,minjae}. 그 게임 듀오. 이름 들었다며? 이제 닉 말고 이름으로 불러라 ㅋㅋ","ifFlags":["sc_clip","sohee_friend"],"ifNotFlags":["veteran"]}`
  - 같은 줄에 `ifFlags` 만 `["sc_clip","minjae_friend"]` 로 바꾼 한 줄

---

## 2. 1차 수정 반영 확인 (P0·P1 52행 표본)

`r1_script.md` 의 P0 29행 중 24행, P1 56행 중 28행을 현재 JSON 과 대조했다.
- ✓ = 교체안대로 들어갔고 새 모순이 없다.
- ◐ = 들어갔지만 일부만 들어갔거나 새 모순이 생겼다. 1절의 회귀 번호를 붙였다.
- = = 1차와 다른 방식으로 고쳤지만 결과는 맞다.

| # | 1차 행 (이벤트 · 위치) | 1차 등급 | 결과 |
|---|---|---|---|
| 1 | sc_leak_d1 C0.reply[0]·critReply[0] | P0 | ✓ "읽음은 6에서 멈췄다" |
| 2 | sc_leak_d1a L3("최소 여섯") | P1 | ✓ (지금은 L5) · R7 이 이 숫자와 어긋난다 |
| 3 | sc_leak_d1 L3 "사흘 뒤 첫 출근" | P0 | ◐ 문구는 맞다. r00 과 부딪힌다 → R1 |
| 4 | sc_leak_d2 / _m cliff | P0 | ✓ |
| 5 | sc_leak_d3 cliff | P0 | ✓ |
| 6 | sc_leak_open_2 L3·C0·C1·C1.reply[1] | P0 | ✓ |
| 7 | sc_leak_bold_ask_m L0 | P1 | ✓ |
| 8 | daeun_r00 L3 뒤 파급 줄 | P0 | ◐ 들어갔다. D2 밤에 "모르는 번호"·"내일 첫 출근"과 같이 뜬다 → R1 |
| 9 | haneul_r00 파급 줄 | P0 | ◐ 같은 문제 → R1 |
| 10 | sc_leak_d2 / _m L5 contact 분기 | P1 | ✓ (L7·L8) |
| 11 | sc_leak_d1c L8 | P1 | ✓ |
| 12 | sc_leak_d3 L6·L8·C1.reply[2] | P1 | ✓ |
| 13 | d_brief_alt L13·L14 | P1 | ◐ D2 r00 이후라 "이름은 출근해서" 가 틀린다 → R8 |
| 14 | d_brief_alt L17·L18 | P0 | ◐ 같은 문제 → R8 |
| 15 | sohee_r00 L0~L3 | P0 | ◐ L2 "님 아까…" 가 숨겨지지 않았다 → R3 |
| 16 | minjae_r00 L1~L3 | P0 | ◐ L1 이 숨겨지지 않았다 → R3 |
| 17 | minjae_r01 L1 | P0 | ✓ |
| 18 | c_clip_truth L3~L5·C1·title | P0 | ✓ |
| 19 | c_clip_truth_m | P0 | ✓ |
| 20 | sc_clip_d3 C2.fail.album | P1 | ✓ "학과 단톡 본인 인증 실패" |
| 21 | sc_clip_d3 C3·reply | P0 | ✓ 3천원, "사람 하나를 판 값" |
| 22 | sc_clip_settle C3.reply[0] | P0 | ✓ |
| 23 | m24_f L4 | P1 | ✓ (L4·L5 두 줄) |
| 24 | sc_speech_d1c L3·L4 | P0 | ✓ |
| 25 | sc_speech_d3 L0·L1 | P1 | ◐ 가른 것은 맞다. L5·C0·D2 C2 가 남았다 → R2 |
| 26 | sc_speech_settle C3 | P1 | ✓ |
| 27 | m08 L0·L4·L5 | P1 | ✓ |
| 28 | m08_m | P1 | ✓ |
| 29 | yeeun_r00 / geonwoo_r00 | P1 | ✓ |
| 30 | sc_swap_d1a C3·reply[2] | P0 | ✓ |
| 31 | sc_swap_d3 L4 | P0 | ✓ |
| 32 | sc_swap_back C2 | P0 | ✓ "숨김 처리" |
| 33 | sc_swap_back C3 | P1 | ✓ |
| 34 | sc_swap_settle C3 | P1 | ✓ |
| 35 | sc_swap_d2 / _m L2 | P1 | = `swap_sniped` 로 가름(더 정확하다) |
| 36 | sc_swap_trainer / _m L0 | P1 | ✓ |
| 37 | yuna_r01 / doyun_r01 / h_doyun_intro | P1 | ✓ |
| 38 | seoyeon_r00 / jeongwoo_r00 | P1 | ◐ → R4·R5 |
| 39 | sc_swap_rebound L3 | P1 | ✓ |
| 40 | sc_ghost_d2 C3 | P0 | ✓ (heat 12) |
| 41 | sc_ghost_d1 L7 | P1 | ✓ |
| 42 | c_ghost_exposed L1·L2·C1 | P1 | ✓ |
| 43 | sc_ghost_settle C3.reply[0] | P1 | ✓ 1.5만원 |
| 44 | m37 L5 | P0 | ✓ |
| 45 | seunghyun_r00 L0~L1 | P1 | ✓ · 지우 쪽 첫 접촉은 새 모순 → R6 |
| 46 | m21 L1·L2 | P0·P1 | ✓ |
| 47 | m22 L2 | P1 | ✓ |
| 48 | m_week1 / _m L9 | P1 | ✓ (L9·L10) |
| 49 | d_open_bet L1(D-98) | P1 | ✓ |
| 50 | starts.json 인트로 5개 | P1 | ✓ 다섯 개 모두 사건 직전의 셋업으로 바뀌었다. D1 첫 줄과 이어진다 |
| 51 | d_street_02 L1 / d_street_01 C3 / a_hustle_* 금액 6행 | P0 | ✓ |
| 52 | d_street_05·06·07 trigger, a_hustle_flea, c_heat_spread C3, c_heat_meltdown C3, sc_leak_d1c C2·C3, sc_leak_d3 C3, sc_leak_d2 L1, sc_leak_who·_m, sc_leak_bold_ask C0, sc_leak_settle C3, 클리프행어 행(D6 엔진) | P1 | ✓ (D6: `next` 사슬 자식의 클리프행어가 이제 보인다. d1a/b/c 의 클리프행어와 D2 첫 줄이 맞물린다) |

---

## 3. 새 문제 표

| 이벤트 id | 위치 | 등급 | 문제 | 교체안 |
|---|---|---|---|---|
| sc_leak_settle_open | L7 | P1 | 정산 대체판은 호감이 40 미만일 때 뜬다. 이때 `{top}` 이 다은·하늘 본인인 경우가 흔하다(시작 보정 +4, D2 r00 강제). 그런데 "보내고 싶은 사람이 **따로** 떠올랐다"라고 한 뒤 C0.reply[2] 에서 "받는 사람은 {top}"이라고 해서 서로 부딪힌다. | `{"who":"narr","text":"그 문장을 지금 보내고 싶은 사람이 떠올랐다. 단톡 말고, 직접."}` |
| sc_leak_ghostread | C1.reply[0] | P1 | "모른다고. 그래서 안 물어본 거라고." 하지만 같은 사람이 D2 에 "그거 누구 얘기예요?"(하늘 "그거 누구 얘기야?")라고 이미 물었다. | `{"who":"narr","text":"한참 뒤 답이 왔다. 모른다고. 한 번 물어봤으니 이제 안 묻겠다고."}` |
| geonwoo_r01 | L1·L2, C0.reply[0]~[1] | P1 | sc_speech 에서 건우는 6학년 3반 동창들 앞에서 부케를 받았고 D2 에 댓글도 달았다. 그런데 동창회에서 "아무도 못 알아본다", "다들 나 모르네"라고 한다. | L1·L2 에 `"ifNotFlags":["sc_speech"]` · L0 뒤에 추가: `{"who":"narr","text":"문 앞에 키 큰 사람이 섰다. 누군가 '부케다!' 하고 외쳤다.","ifFlags":["sc_speech"]}`, `{"who":"them","text":"…부케로 기억되는 건 좀 억울한데 ㅋㅋ","ifFlags":["sc_speech"]}` · C0.reply[0]·[1] 에 `"ifNotFlags":["sc_speech"]` + `{"who":"them","text":"모른 척하는 거 다 보여 ㅋㅋ 부케 때 눈 마주쳤잖아","ifFlags":["sc_speech"]}` |
| sohee_r01 | L0, C0.reply[0] | P1 | sc_clip 에서 소희는 클립 이전부터 음성으로 듀오를 했다. 그런데 r01 은 "음성 채널 첫날"이고 답도 "첫날엔 다들 그 말 함"이다. 민재 r01 은 파급 줄이 있는데 소희 r01 에는 없다. | L0 에 `"ifNotFlags":["sc_clip"]` + `{"who":"narr","text":"클립 이후 처음 같이 켠 음성 채널. 볼륨이 기억보다 크다.","ifFlags":["sc_clip"]}` · C0.reply[0] 에 `"ifNotFlags":["sc_clip"]` + `{"who":"them","text":"ㅋㅋㅋㅋ 이거지. 클립에선 내 목소리 좋다며. 샷콜 톤은 별로야?","ifFlags":["sc_clip"]}` |
| sc_leak_ghostread | L4·L5 | P2 | 자극. 중반 갈래 이벤트의 정점이 간접 화법 지문 한 줄("봤다고 했다…")이라 감정이 오지 않는다. | L5 에 `"ifNotFlags":["daeun_contact","haneul_contact"]` · 추가: `{"who":"them","name":"{char:daeun,haneul}","text":"봤어요. 지워지기 전에.","ifFlags":["daeun_contact"]}`, `{"who":"them","name":"{char:daeun,haneul}","text":"아무한테도 말 안 했어요. 앞으로도요.","ifFlags":["daeun_contact"]}`, `{"who":"them","name":"{char:daeun,haneul}","text":"나 그거 봤다 ㅋㅋ 지워지기 전에","ifFlags":["haneul_contact"]}`, `{"who":"them","name":"{char:daeun,haneul}","text":"근데 아무한테도 말 안 함. 진짜로","ifFlags":["haneul_contact"]}` |
| sc_leak_settle_open | trigger | P2 | D3 게이트와 다르다. 다른 세 시작의 대체판은 `affection [0,39]` 로 막혀 있다. 이 판만 호감 조건이 없어서, 호감 40 이상인데 D96 까지 `sc_leak_settle` 이 안 뜨면 둘이 반반으로 경쟁한다. `leak_for_out` 회차가 늘 대체판을 보도록 일부러 비운 것이라면, 조건을 둘로 나누는 게 맞다. | 이 이벤트 trigger 에 `"affection":{"daeun":[0,39],"haneul":[0,39]}`, `"notFlags":["sc_leak_settled","leak_for_out"]` · 사본 `sc_leak_settle_out` 을 만든다(내용 동일, trigger `{"day":[90,100],"flags":["sc_leak","leak_for_out"],"notFlags":["sc_leak_settled"]}`) |
| sc_clip_settle_open | L3 | P2 | `{top}` 이 듀오 본인이면 진행자가 자기를 두고 "누구랑 톡하느라"라고 놀리는 셈이다. | `{"who":"them","name":"듀오","text":"근데 이분 요즘 답장이 느림. 누구 때문인지는 채팅창이 맞혀 보셈 ㅋㅋ"}` |
| sc_clip_sorry_back | trigger | P2 | 사과 갈래(D1 C2)에서 D3 에 진상(미공개분 판매, 듀오 "당분간 방송 쉽니다")을 고른 회차에도 듀오가 생방송으로 "사과 장인"을 칭찬한다. | trigger 에 `"notFlags":["villain_move"]` |
| sc_clip_sorry_back | C2·reply | P2 | 시청자인 내가 듀오의 "방송을 끈다". | C2: `"부끄러워서 방송 창을 닫는다"` · reply[0]: `{"who":"narr","text":"창을 닫았다. 이상하게 입꼬리가 안 내려갔다."}` |
| sc_clip_d1b | C1 effects | P2 | 결과 설계. 합성 주장이 들킨 갈래(`sc_clip_busted`)에서 듀오에게 다시 "응 합성"이라고 거짓말해도 `sc_clip_deny` 가 서지 않는다. 그래서 `c_clip_truth` 가 영영 오지 않고 그 거짓말은 대가가 없다. | C1 `effects` 에 `"setFlags":["sc_clip_deny"]` |
| sc_clip_d1c | cliffhanger | P2 | 이제 보이는 클리프행어(D6)가 "2탄 D-7"이라고 예고하지만 `sc_clip_2` 는 D25~40 에 나온다. | `"클립 장인이 프로필을 바꿨다. '2탄 준비 중. 제보 받음'."` |
| sc_clip_open_2 | trigger | P2 | `clock` 순서. D1 에는 메인 사슬(09:02~09:10) 다음에 나오는데 시계가 02:00 이라 거꾸로 간다. D2 메인(01:47) 바로 뒤에서는 딱 맞는다. | `"day":[2,3]` |
| d_open_bet | L7 | P2 | D2 에 태현이 "합방에서 공개 고백하면"이라고 한다. 합방 제안은 D3(`sc_clip_d3`)에야 온다. | `{"who":"them","name":"태현","text":"마이크 켜고 정식으로 고백하면 치킨 추가 ㅋㅋ","ifFlags":["sc_clip"]}` |
| sohee_r00 | L6 | P2 | 커뮤에서 "목소리 주인"은 클립 속 **나**를 가리킨다(`sc_clip_d1.L8`). 듀오가 자기를 그렇게 부르면 헷갈린다. | `{"who":"them","text":"클립에서 목소리 좋다던 그 사람. 이름은 처음 말함","ifFlags":["sc_clip"]}` |
| sc_speech_meme | L2 | P2 | 6학년 3반 단톡의 "동창"이 "학과 축제 현수막"을 말한다. 학과는 대학 쪽 인맥이다. | `{"who":"them","name":"과 동기","text":"야 학과 축제 현수막 봤냐 ㅋㅋㅋ","ifFlags":["sc_speech_owned"]}` |
| a_hustle_mc_sequel | L2 | P2 | `sc_speech_meme` C0(애드리브 갈래, D20~40)에서 사회를 세 건 받았다. 그런데 D25 이후 "결혼식 축사 이후 처음 잡는 마이크"라고 한다. | `{"who":"narr","text":"축사 이후 처음으로 카메라 두 대 앞에서 잡는 마이크. 손에 땀이 난다."}` |
| sc_swap_trainer / _m | trigger, sc_swap_d1c C0.reply[0] | P2 | `clock` 순서. D2 에는 메인(정기 회의) 뒤에 07:00 헬스장이 나온다. | `sc_swap_d1c` C0.reply[0]: `{"who":"them","name":"헬스장 직원","text":"모레 이 시간으로 잡아 둘게요"}` · 두 trainer trigger `"day":[3,3]`(D3 메인 01:00 → 07:00 순서가 맞는다) |
| sc_swap_settle | C1.reply[0] | P2 | `sc_swap_back` C2(숨김 처리)를 고른 회차에서 서진을 "숨김 목록에 넣었다"가 두 번째가 된다. | `{"who":"narr","text":"답장 대신 스토리 공개 범위에서 서진을 뺐다. 미련이 아니라 정리였다."}` |
| sc_ghost_d2 | L3 | P2 | `clock`. 범인 검거(`sc_ghost_d1c`)는 D1 08:20 이다. "어젯밤 잡힌 태현"이 아니다. | `{"who":"narr","text":"어제 아침 잡힌 태현이 오늘 아침 반성문 사진을 보냈다. 진짜 A4 세 장이다.","ifFlags":["sc_ghost_hunt"]}` |
| sc_ghost_d1a | cliffhanger | P2 | 이제 보이는 클리프행어가 "자기소개를 처음 읽었다"이다. 그 뒤 D1~3 의 `sc_ghost_open_2` 가 같은 자기소개를 처음 읽는 장면으로 다시 나온다. | `"상대 프로필을 처음 제대로 봤다. 출근길 사진이 전부 은행나무다."` (`sc_ghost_open_1.L1` 의 은행나무 시로 이어진다) |
| jiwoo_r00_ghost | L1, L2 | P2 | (1) 소개팅 앱 프로필에 전화번호가 있다는 설정은 12+ 앱에서 권할 습관이 아니다. 대필 설정을 살릴 기회도 놓친다. (2) 진실 갈래(`sc_ghost_truth`, D1 에 "그거 저 아니에요")에서도 "새벽에만 말이 많으시던데"라고 한다. | L1: `{"who":"them","text":"앱 말고 여기로 연락드려요. 새벽 3시에 번호 교환 누르셨더라고요."}` · L2 에 `"ifNotFlags":["sc_ghost_truth"]` + `{"who":"them","text":"아니라고 한 쪽이랑 낮에 얘기해 보고 싶어서요.","ifFlags":["sc_ghost_truth"]}` |
| seunghyun_r00_ghost | L1, L3, C0.reply[0] | P2 | 위와 같은 두 문제. 그리고 C0.reply[0] "다행이다."는 본편 r00 에서는 "속으로 할 말이었는데" 자기 수정이 붙는 시그니처다. 여기서는 설명 없이 반말이 새어 나온 것처럼 읽힌다. | L1: `{"who":"them","text":"앱 말고 문자로 연락드려도 될까요. 번호 교환은 새벽 3시에 그쪽이 먼저 누르셨습니다."}` · L3 에 `"ifNotFlags":["sc_ghost_truth"]` + `{"who":"them","text":"아니라고 하신 쪽이 궁금했어요. 낮에요.","ifFlags":["sc_ghost_truth"]}` · C0.reply[0]: `{"who":"them","text":"좋아요. 확실히."}` |
| sc_ghost_d3 / c_ghost_exposed | C2 / C1 | P2 | `villain +1` 인데 선택지에 "(진상)" 표시가 없다. 1차에서 `c_heat_spread C2` 는 같은 이유로 진상 효과를 뺐다. 기준이 하나여야 한다. | sc_ghost_d3 C2: `"(진상) 태현에게 대신 받게 한다"` · c_ghost_exposed C1: `"(진상) 태현이 한 거예요. 저는 몰랐어요"` |
| sc_ghost_hunt_file | C2, m37 | P2 | 서사 빚. 태현이 "100일 다 돼 가면 말해 줌"이라고 약속한다. 그런데 D95 `m37` 은 받는 사람 얘기를 하지 않는다. | C2 `effects` 에 `"setFlags":["ghost_file_asked"]` · m37 L6 뒤에 추가: `{"who":"them","name":"태현","text":"그 파일 누구한테 쓴 거냐고 물었지. 아직 없다. 받는 사람 칸 비워 둔 채로 6년","ifFlags":["ghost_file_asked"]}` |
| c_villain_trial | L4, L6, L3 앞 | P2 | (1) 피해자 줄이 시작 플래그만 본다. 신부가 "결혼식 피해자. 아직 화남"이라고 하지만, 신부를 건드린 진상은 `speech_self_upload` 뿐이다. 서진의 "단톡 저격 피해자"는 `swap_sniped` 뿐이다. (2) 클래식 회차에는 피해자 줄이 하나도 없다(익명·엄마만 남는다). | L4 `ifFlags` 를 `["sc_speech","speech_self_upload"]` 로 바꾼다. 추가: `{"who":"them","name":"동창","text":"6학년 3반 대표로 왔습니다. 단톡 피해자","ifFlags":["sc_speech"],"ifNotFlags":["speech_self_upload"]}` · L6 `ifFlags` 를 `["sc_swap","swap_sniped"]` 로 바꾼다. 추가: `{"who":"them","name":"서진","text":"캡처 피해자 ㅎㅎ 아니면 그냥 구경","ifFlags":["sc_swap"],"ifNotFlags":["swap_sniped"]}` · L3 앞에 추가: `{"who":"them","name":"친구","text":"내기 증인 대표입니다. 증인 단톡 피해자","ifNotFlags":["start_alt"]}` |
| d_villain_rival_ghost | L1 | P2 | "나 판 건 그렇다 쳐도"는 태현을 판 진상(D2 C3, 위기 C1)이 있을 때만 맞다. `villain` 2는 다른 진상만으로도 찬다. | `{"who":"them","name":"태현","text":"내 얘기는 됐고. 동네가 다 너 얘기다"}` |
| d_villain_rival_swap | L1, C2.reply[0] | P2 | (1) "나한테만 그런 줄 알았는데"는 서진을 직접 저격한 갈래(`swap_sniped`)에서만 맞다. (2) "이번엔 1초도"는 앞서 숨김을 했다는 전제다. 이 이벤트(D12~60)가 `sc_swap_back`(D45+)보다 먼저 올 수 있다. | L1 에 `"ifFlags":["swap_sniped"]` + `{"who":"them","name":"서진","text":"나는 너 착한 줄만 알았는데 ㅎㅎ","ifNotFlags":["swap_sniped"]}` · C2.reply[0]: `{"who":"narr","text":"숨김 버튼. 1초도 안 걸렸다."}` |
| d_villain_rival | L0 | P2 | `d_open_bet_2` 기준으로 증인방은 증인 7 + 나 + 태현 = 9명이다. | `{"who":"sys","text":"친구 단톡 (9)"}` |
| sc_leak_d1 / sc_leak_open_2 / d_villain_rival_leak | C2.reply[0] / C2.reply[0]·[1] / C2.reply[0] | P2 | 알바방은 나를 포함해 11명이다. 다른 사람은 최대 10명이 읽는다. 1차에서 "공감 열한 개"를 열 개로 고친 것과 같은 이유로 "읽음 11"은 불가능하다. | sc_leak_d1 C2.reply[0]: `"읽음 8. 9. 10."` · sc_leak_open_2 C2.reply[0]: `"신입님 빼고 열 명 전원 봤습니다."`, reply[1]: `"읽음 10의 무게를 이제야 알았다."` · d_villain_rival_leak C2.reply[0]: `"안 읽은 척했다. 읽음 10에 내 것도 들어 있었다."` |
| d_villain_fan | C2.reply[1] | P2 | `d_street_04` C3.reply[1] 의 "알려 준 대로 했다가 차단당함"과 글자까지 같은 개그다. | `{"who":"narr","text":"다음 날 팬이 '따라 했다가 단톡에서 강퇴당함' 후기를 올렸다."}` |
| a_hustle_stream_hot | C0.failReply[0] | P2 | "'렉 아니고 긴장' 밈이 2탄을 찍었다"는 `a_hustle_stream` 실패를 먼저 본 경우에만 맞다. 이 이벤트는 가중치가 3이라 먼저 나오기 쉽다. | `{"who":"narr","text":"생방송에서 말이 아홉 번 씹혔다. '렉 아니고 긴장'이 채팅창을 덮었다."}` |
| cameo_groomfriend | L3 | P2 | 앞 회차의 결말("부케 받은 사람이랑 엮였대요")을 단정한다. 앞 회차가 다른 사람과 끝났으면 틀린 말이다. | `{"who":"them","name":"신랑 친구","text":"조회수 20만. 주인공은 그 뒤로 사회 섭외만 세 건 받았대요"}` |
| cameo_clipmaster | trigger | P2 | L1 "님 요즘 좀 화제던데"인데 소문 조건이 없다. sc_ghost 의 "새벽 3시 시"는 앱 속 사적 대화인데 클립 장인이 안다. | trigger 에 `"stats":{"heat":[20,100]}` 을 더한다 |
| d_street_09 | L1 | P2 | 유나는 거짓 칭찬을 하지 않는다(CAST_BIBLE 1.6). 그런데 소문이 진상 때문에 찬 회차(`villain` ≥ 3)에서도 "좋은 쪽으로요!"라고 단정한다. | `{"who":"them","text":"헬스장 단톡에서도 회원님 얘기해요. 저는 좋은 얘기만 골라 들었어요!"}` |
| starts.json sc_leak / sc_clip | castLines | P2 | 캐스트 소개 미리보기는 r00 의 조건 없는 첫 줄이다. sc_leak 은 "내일 오픈 조 같이에요"(R1 과 같은 모순), sc_clip 은 "님 아까 서폿 좀 치던데?"(R3)를 첫 메시지로 보여 준다. | sc_leak: `"castLines":{"daeun":"그거 누구 얘기예요?","haneul":"야 신입 ㅋㅋㅋ 그거 누구 얘기야?"}` · sc_clip: `"castLines":{"sohee":"클립 백 번쯤 들었어","minjae":"나 얼굴은 안 보여 줄 건데. 그래도 돼?"}` |
| geonwoo_r01 | C0.reply[1], C2.critReply[1] | P2 | 세계관 설정. "13년"이다. CAST_BIBLE 0.4 와 sc_speech(로그라인 "20년 만에", `sc_speech_open_2` "20년이 접혔다")는 20년이다. 기존 글이지만 sc_speech 가 이 숫자를 앞에 내세웠다. | C0.reply[1]: `"하긴. 20년이면 모를 만하지"` · C2.critReply[1]: `"안녕. 진짜로. 20년 만에"` |
| (기존 글) 금액 띄어쓰기 | route_jeongwoo r00 L1·r01 C1.reply[0], route_daeun "3천 원" 4곳, events_action 1803·1834행, events_daily 로또 3곳, events_special 296행, events_moments 2287행, endings 1831행 | P2 | 돈 표기 규칙("N만원"·"N천원", 붙여 쓴다)과 다르다. 이번 범위의 새 글에는 하나도 없다. | `"N만 원"` → `"N만원"`, `"N천 원"` → `"N천원"` (예: `"이번 학기 회비는 2만원입니다."`) |

---

## 4. 목소리 검사기 (스크래치 사본)

- 사본 위치: `…/scratchpad/vc/check_voice.py`. 원본은 고치지 않았다.
- 바꾼 곳: `STORY` 를 절대 경로로 바꾸고, `EVENT_FILES` 에 `events_start.json`·`events_freedom.json` 을 더했다.
- 결과: 원본과 사본 모두 **위반 0건**이다. 1차의 8건은 모두 해소됐다.
- 경고(위반 아님, 50줄 미만이라 비율만 높게 잡힌다):
  - 화자 `다은` "…" 3/25 = 12.0%
  - 화자 `지우` 4/36 = 11.1%
  - 화자 `승현` 3/28 = 10.7%
- 태현 "캡처"는 2회로 상한과 같다. 위 표의 교체안은 태현 대사에 "캡처"·"박제"를 새로 넣지 않는다.

## 5. 플레이스루 추적 (시작 × D1 갈래)

- 일회용 스크립트: `…/scratchpad/trace.py`. 갈래의 플래그를 실제로 세우고 줄의 `ifFlags`·`ifNotFlags` 로 걸러서 출력한다.
- 추적한 경로(전부 정산까지 갔다):
  - sc_leak: 삭제·캡처·드라마 핑계·대범 4갈래(여성 2, 남성 2)
  - sc_speech: 애드리브+진상·모쏠 선언·진지 3갈래
  - sc_clip: 본인 등판·합성(성공·들킴)·사과 4갈래(여성 2, 남성 2)
  - sc_swap: 복수·쿨·헬스 3갈래
  - sc_ghost: 진실·연기·범인 검거 3갈래
- 날짜 순서는 엔진(`planDay`·D11)이 실제로 내는 순서를 따랐다: D1 메인 → 갈래 → D1~3 일상 → D2 메인 → `d_open_bet` → **가속 캐릭터 r00(D2)** → D3 메인 → `d_brief_alt` → r01 → 주차 메인 → 중반 갈래 이벤트 → 위기 → `m21`/`m37` → 정산.

| 시작 | 읽은 결과 | 걸린 곳 |
|---|---|---|
| sc_leak | D1~D3 은 단단하다. 갈래 클리프행어(D6)가 D2 첫 줄과 맞물린다. 정산까지 이어진다. | D2 밤 r00 → R1, D3 태현 정리 → R8. **캡처 갈래(`sc_leak_captured`, 대범 아님)는 중반 갈래 이벤트가 하나도 없다.** ghostread 는 캡처 갈래를 빼고, drama 는 핑계 갈래, bold_ask 는 대범 갈래 전용이라 이 갈래는 `sc_leak_who` 만 남는다(새 행 대상은 아니고 기획 빈칸으로 적어 둔다). |
| sc_speech | 축사 → 부케 → 댓글 → 2편 제안 → 밈 → 정산으로 이어진다. 갈래마다 밈 줄이 정확히 하나씩 뜬다. | 진상 갈래의 D2·D3 → R2. 동창회 r01 → geonwoo_r01 행. |
| sc_clip | 목소리 서사가 정산의 "이번엔 혼잣말이 아니었다"까지 잘 이어진다. 합성 갈래의 위기(c_clip_truth)도 제자리에 온다. | D2 밤 r00 → R3. r01 → sohee_r01 행. 합성이 들킨 갈래의 결과 빈칸 → sc_clip_d1b 행. |
| sc_swap | 서진 축(자? → 착하니까 → 헤어졌어 → 100일)이 가장 깔끔하다. 정산이 짝이 아니라 서진에 맞춰져 있어 D3 게이트가 필요 없다(대체판이 없는 것은 맞다). | D2 직후 서연 r00 → R4. 정우 r00 → R5. 체험 PT 시각 → P2 행. |
| sc_ghost | 대필 → 자백 → 통화 → 엄마 → 들킴/고백 → 태현 고백 → 정산이 시작 가운데 가장 탄탄하다. | 여성 쪽 r01 → R6. 반성문 시각 → P2 행. 파일 약속 → P2 행. |

카메오(`done_*`)·`veteran` 쪽은 다음을 확인했다.
- 플래그 이름이 엔진 등록명과 같다.
- 카메오가 자기 시작에서 빠지도록 각각 `notFlags` 가 걸려 있다.
- `d_brief_alt` 의 veteran 분기(이름 대신 "선배, 알바, 동창, 듀오, 소개팅")는 모든 시작에서 앞뒤 줄과 충돌하지 않는다.

남은 것은 카메오 두 개의 P2 행뿐이다.
