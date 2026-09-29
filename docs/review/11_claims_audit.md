# 11. 주장 감사 — 네 에이전트의 자기 보고를 코드·데이터·직접 돌린 측정으로 되짚었다

> 2026-09-27 · 적대적 검증(read-only). 대상: `09_engine_fixes.md` · `09_content_fixes.md`(+`09_content_handoff.md`)
> · `09_ui_fixes.md` · `09_minigame_audit.md` · `10_second_door.md`.
>
> **이 문서를 쓰는 것 말고는 저장소를 한 줄도 안 고쳤다.** 내가 돌린 검증 하니스는 저장소 사본
> (`<scratchpad>/repo/test/zz_audit*_test.dart`)에 있고, 저장소에는 넣지 않았다.

---

## 0. 한 줄 결론

**보고서의 큰 주장은 대체로 사실이다.** 내가 독립적으로 다시 잰 숫자 네 개가 전부 재현됐고,
테스트도 대부분 진짜로 돌아가는(합성 목이 아닌) 검사였다. `743개가 통과하는데 실제 오디오는
한 번도 안 돌았던` 종류의 사기는 이번에는 **없다.**

다만 **새로 만든 영구 잠금 한 건**을 찾았다. 보고서가 명시적으로 "전부"라고 쓴 문장이 거짓이고,
그걸 잡아야 할 정적 검사가 정확히 그 자리에서 눈을 감고 있다.

| 등급 | 건수 |
|---|---|
| 확인됨 | 16 |
| 과장됨(사실이지만 틀이 부풀었거나 문서가 실제와 어긋남) | 6 |
| **거짓** | **2** |
| 확인 불가 | 2 |

---

## 1. 내가 실제로 돌린 것

```
$ flutter test                     # 저장소 그대로
01:32 +849 ~1: All tests passed!

$ flutter analyze
No issues found! (ran in 4.0s)
```

그 위에 **저장소를 복사해** 내 하니스 네 개를 따로 돌렸다(보고서가 쓴 시뮬레이터를 재사용하지
않고 처음부터 다시 썼다).

| 하니스 | 잰 것 |
|---|---|
| `AUDIT 1` | 두 번째 문 완전성 — 선호 3종 × `m03` 답 3종 × 시드 40 = **360회차**, D+1~D+32 |
| `AUDIT 2` | 일상 냉각 — 선호 2쪽 × 시드 60 × **40일**(보고서는 20일) = 120회차 |
| `AUDIT 3` | 초반 10일 미니게임 종류 — 120회차 |
| `AUDIT 4~6` | `m01 → d_open_bet` 보장 — 엔진 단독 / 컨트롤러 / 2회차 |
| `AUDIT 7~9` | `club_afterparty`·`jiwoo_dated` 의 실패 경로, 무작위 플레이어 200회차 |

---

## 2. 주장 → 판정

### 2.1 "테스트가 증명한다" 류

| # | 주장 | 판정 | 근거 |
|---|---|---|---|
| T1 | 09_engine §C "`route_order_test` 에 3개 추가 — 시뮬레이션에서 **후보 건너뜀 0**" | **확인됨** | 테스트가 `planDay` 전에 `candidates(route)` 의 캐릭터별 최소 단계를 **따로 계산**해 놓고, 실제로 나간 이벤트의 단계와 비교한다. 동어반복이 아니다. 직접 돌린 출력: `[f] 루트 3544개 / 60회차 — 후보 건너뜀 0개` · `[m] 루트 3618개 / 60회차 — 후보 건너뜀 0개` |
| T2 | 09_engine §B "`engine_fixes_test` B 5개 — 실제 데이터 60회차에서 14일 내 재등장 0. **대조군도 같이 돈다**" | **확인됨** | 대조군(`dailyCooldownDays: 0`)이 같은 파일에 있고 `expect(repeated, greaterThan(20))` 으로 **냉각을 끄면 실패하는지**까지 본다. 데이터 덕에 저절로 통과하는 테스트가 아니다 |
| T3 | 09_engine §D "합성 번들로 컨트롤러를 **실제로 하루 굴려** 클리프행어 확인" | **확인됨** | `GameController` 를 띄우고 `startDay` → `choose`/`continueAfterChoice` 루프를 실제로 돈 뒤 `c.cliffhanger`·`state.lastCliffhanger` 를 본다. 메인이 없는 날은 `'루트 훅2'` 까지 확인한다 |
| T4 | 09_engine §E "`openingScript` 6개 — 빈 목록이면 계획이 한 글자도 안 바뀜 …" | **과장됨** | 테스트 자체는 정직하고 진짜다. 다만 **그 기능이 현재 꺼져 있다**: `assets/story/config.json` 의 `openingScript` 는 `[]` 이고, 테스트도 `expect(real.config.openingScript, isEmpty)` 로 그 사실을 고정한다. 즉 §E 는 "(c)#4 30.3% 문제를 고쳤다"가 아니라 **아무도 안 쓰는 장치를 만들었다**. 실제 보장은 콘텐츠 쪽 `m01.next` 가 한다(§2.2 C2) |
| T5 | 09_minigame "`minigame_games_test` 32개 — 고친 자리마다 하나씩" | **확인됨** | 표본으로 읽은 것들(`화술이 낮아도 이길 수 있는 판`, `한 번 엇갈린 판은 실패가 아니다`, `전부 제 순서대로 누르면 크리티컬`)은 전부 **실제 위젯을 펌프하고 탭해서** `MinigameResult.success/critical` 을 본다. 목이 아니다 |
| T6 | 09_ui "`title_test` 6건 · `profile_test` 10건 · `intro_test` 4건" | **확인됨** | `intro_test` 는 타이틀 탭 → 알림 탭 → 이름 → 성별 → **캐스트 소개**까지 실제로 눌러 가고, 캐스트가 떠 있는 동안 `hasSave == false`·`playerName == null` 을 **새로 고정**했다(기존보다 강해졌다) |
| T7 | 09_ui "`sfx.played` 로 소리를 확인" | **확인 불가(부분)** | `RecordingSfxService extends SfxService` 로 `onPlay` 만 가로챈다 — 즉 "컨트롤러가 큐를 울렸다"까지만 증명하고 **실제 오디오 출력은 여전히 테스트 밖**이다. 과거 사고(`NoopSfxService` 로 743개 통과)와 같은 층에 남아 있다. 실기기 1회 확인이 필요하다 |
| T8 | 10_second_door "테스트 실패 5 → 2, 남은 2개는 개수 하드코딩" | **확인됨(이미 해소)** | 그 2개는 그 뒤에 누군가 고쳤다. `git diff test/event_engine_test.dart` 가 `393 → 403`, `main: 55 → 63`, `daily: 117 → 119` 으로 바뀐 것을 보여 주고 지금은 0 실패다 |

### 2.2 "이만큼 쟀다" 류 — 내가 다시 쟀다

| # | 주장 | 판정 | 내가 잰 값 |
|---|---|---|---|
| M1 | 09_engine §B "20일 × 시드 30 × 2쪽(60회차)에서 **14일 안에 재등장 0**" | **확인됨(더 센 조건에서도)** | 40일 × 시드 60 × 2쪽 = 120회차. `최소 간격 = 14 (pref=f seed=1 d_misc_01 13일→27일)`. 간격 분포 `{14:151, 15:117, 16:82, 17:101, 18:84, 19:60}` — 13 이하가 **0개** |
| M2 | 09_engine §C "시드 60 × 2쪽(120회차, **루트 6,770개**)에서 선후 위반 0" | **확인됨(숫자만 살짝 옛날)** | 지금 데이터로는 `3544 + 3618 = 7,162개`(콘텐츠가 늘어 6,770에서 올라갔다). **위반 0 은 그대로** |
| M3 | 10_second_door §4.3 "지우 `[f]` r15 미도달 **17/17 → 0/17**, 승현 `[m]` **17/17 → 0/17**" | **확인됨** | `flutter test` 가 직접 찍는다. `[f] jiwoo` 0.58~0.88 · `[m] seunghyun` 0.42~0.71 — 17종 전부 0 초과 |
| M4 | 09_minigame §3-3 "제안 적용 시 초반 10일 **최소 6종**, 평균 8.47, 6종 이상 100%" | **확인됨** | 내 측정(120회차, 미니게임 붙은 선택지를 고르는 플레이어): `최소 6 · 평균 8.45 · 최대 11`, `6종 이상 본 회차 120/120`, 1위 `nerve_gauge 19.2%`. 보고서(8.47 / 18%)와 소수점만 다르다 |
| M5 | 09_content §3 "100일 내기는 D+1 에 **100% 나온다**" | **확인됨** | 컨트롤러로 선호 3종 × `m01` 세 선택지 × (확률 선택지는 실패까지) 12경로 전부 `m01 → d_open_bet`. 2회차도 확인. **단, 엔진만으로는 28.5%**(`planDay` 만으로 D+1 에 `d_open_bet`: 57/200) — 보장 전체가 `GameController` 의 `next` 처리에 얹혀 있고, 엔진 시뮬레이션(`route_order_test`·`sim_balance_test`)은 `next` 를 타지 않는다. 회귀를 잡는 테스트는 `widget/event_screen_test` **한 줄뿐**이다 |
| M6 | 09_content §1 "`@top` 으로 호감을 움직이면서 이름을 안 부르는 이벤트가 **0개**" | **확인됨** | 전수 검사 결과 `[]`. `{top}` 을 쓰는 이벤트 66개(일상 41 · 특수 13 · 메인 11 · 모먼트 1) |
| M7 | 10_second_door §4.5 "플래그 211종 / 읽힘 182 / 죽음 26 / 유령 1" | **확인됨** | `python3 tool/flag_audit.py` → `플래그 총 211종 / 세우고 읽는다 182 / 죽은 26 / 유령 1`. 유령 `burnout_x3` 은 감사 도구의 오탐이다 — `event_engine.dart:573` 이 실제로 세운다 |
| M8 | 09_engine §C "남은 번호 역행 회차당 f 29.5 → **17.7** · m 28.3 → **15.9**(약 40% 감소)" | **과장됨** | 지금 값은 f `997/60 = 16.6` · m `976/60 = 16.3` 으로 주장과 맞는다. 하지만 **비율로 쓰면 f 997/3544 = 28.1%** — 루트 장면 네 개 중 하나 이상이 여전히 번호를 거슬러 나간다. "40% 감소"는 사실이지만 **남은 28%를 가린다**. 테스트 상한도 `22/회차` 로 느슨하다 |
| M9 | 09_minigame §3-4 "`date_course` 는 초반에 **한 번도 안 나온다**" | **과장됨** | 내 120회차 측정에서 `date_course` 가 14번 나왔다. 초반 부재 종류는 **0개**다(보고서는 1개라고 적었다). 좋은 쪽으로 틀렸다 |

### 2.3 두 번째 문(10_second_door) 구조 검증 — 가장 비싼 주장

**주장**: 루트 게이트(`*_dated` 26곳)와 `m11`/`m11_m`/`m12`/`m12_m` 의 `trigger.flags` 를 없애고,
순서는 날짜가 보장한다. 지우를 못 만난 회차에서 `m11` 이 도는 일은 없다.

**판정: 확인됨.** 정적으로도, 360회차 시뮬레이션으로도 구멍이 없다.

정적 근거:

```
m10_refused   day=25  {"pref":"f","flags":["refused_mom"]}      character=jiwoo
m10_refused_m day=25  {"pref":"m","flags":["refused_mom"]}      character=seunghyun
m10           day=26  {"notFlags":["refused_mom","lied_to_mom"]}
m10_lied      day=27  {"pref":"f","flags":["lied_to_mom"]}
m10_lied_m    day=27  {"pref":"m","flags":["lied_to_mom"]}
m11           day=29  {"pref":"f"}       m11_m day=29 {"pref":"m"}
```

- **문이 망라적이다.** `m03`/`m03_m` 의 세 선택지가 각각 `jiwoo_intro+jiwoo_met` / `refused_mom` /
  `lied_to_mom` 을 세운다. 세 집합이 `m10`(둘 다 아님) · `m10_refused`(거절) · `m10_lied`(거짓말)를
  빠짐없이 덮는다. 어느 답도 안 한 상태는 존재할 수 없다(아래).
- **굶길 수 없다.** `planDay` 는 `for (final e in candidates(s, EventLayer.main)) add(e);` — 그날 조건이
  맞는 메인을 **전부** 넣는다(추첨이 아니다). `StoryBundle.validate` 의 "main 날짜 중복" 규칙이
  D+25/26/27 에 쪽별 1개씩만 있도록 강제하고, 실제로 그렇다. 하루를 중간에 끝낼 길도 없다 —
  `endDay` 는 `_queue` 가 빈 `Phase.summary` 에서만 불리고, 앱을 껐다 켜도 `s.dayQueue` 가 복원된다.
  하트가 없으면 **하루가 시작되지 않을 뿐** 건너뛰지 않는다.
- **`preference: "all"` 구멍도 없다.** `Preference.side(all) == female` 이라 `all` 회차는 f 쪽 장면을
  받는다(`m03` → `m10*` → `m11`).

시뮬레이션 근거 (`AUDIT 1`, 선호 3종 × `m03` 답 3종 × 시드 40 = 360회차):

```
pref=f   m03pick=0 runs=40 문={m10: 40}            합류(m11)=40   못만나고합류=0
pref=f   m03pick=1 runs=40 문={m10_refused: 40}    합류(m11)=40   못만나고합류=0
pref=f   m03pick=2 runs=40 문={m10_lied: 40}       합류(m11)=40   못만나고합류=0
pref=m   m03pick=1 runs=40 문={m10_refused_m: 40}  합류(m11_m)=40 못만나고합류=0
pref=all m03pick=2 runs=40 문={m10_lied: 40}       합류(m11)=40   못만나고합류=0
                                    (9줄 전부 동일한 모양)
```

`m11` 이 재생되는 순간 `jiwoo_met`(또는 `seunghyun_met`)이 **360/360 에서 이미 서 있다.**

**곁다리로 확인한 것**: `m11` 의 첫 지문이 `지우를 만나고 오는 길이다`·`승현을 만나고 오는 길이다`
로 받침이 맞게 고쳐져 있고, `m12`·`m12_m` 본문에도 소개팅 어휘가 남아 있지 않다(문 중립이 맞다).

### 2.4 소유권·범위 주장

| # | 주장 | 판정 | 근거 |
|---|---|---|---|
| S1 | 09_minigame §3 "**JSON 은 건드리지 않았다**. 이 절은 담당자에게 넘기는 요청이다" | **거짓(문서가 실제와 어긋남)** | 제안한 재배치 **10곳이 전부 작업 트리에 적용돼 있다.** HEAD 대비: `group_chat 23→17` · `word_order 16→19` · `drink_limit 6→9` · `read_emotion 12→14` · `outfit 8→7` · `profile_swipe 5→4` — 제안 표와 정확히 일치한다. 적용 도구 `tool/spread_minigames.py` 도 트리에 있는데 그 문서의 §6 "쓴 도구" 표에는 없다. **결과는 좋다(M4 재현). 문제는 어느 보고서도 이 변경을 '내가 했다'고 적지 않은 것** — 리뷰어가 추적할 수 없는 변경이다 |
| S2 | 09_ui "`lib/main.dart` 는 고치지 않았고 ATT 는 여전히 인트로 뒤에만 뜬다" | **확인됨** | `main.dart:67` `if (!controller.shouldShowIntro) unawaited(AdManager.instance.init());` 그대로. 첫 실행 경로의 ATT 는 `intro_screen.dart:319` 즉 캐스트 `시작하기` 뒤 `_start()` 안에서만 돈다. 타이틀은 `IntroStep.title` 로 들어가 조건이 같다 |
| S3 | 09_ui "그 밖의 테스트는 하나도 고치지 않았다" | **확인됨** | `git diff --stat test/` 상 삭제 32줄은 전부 `intro_test`(24) + 데이터 숫자(8)다. 삭제된 테스트 파일·테스트 케이스는 없다 |
| S4 | 09_content §4.2 "`m07` 의 **다섯 선택지 전부**가 `club_afterparty` 를 세운다(어떤 선택을 해도 뒤풀이에는 갔다)" | **거짓** | §3 참고. 실패 경로에서 안 선다 |
| S5 | 09_content §4.1 "`m11`·`m11_m` 의 **모든 선택지가** `jiwoo_dated`/`seunghyun_dated` 를 세우고" | **거짓(다만 10 이 우연히 무력화)** | `m11[0] 바로 연락한다` 는 `chance: 50` 인데 `fail.setFlags` 가 없다. 실패하면 `jiwoo_dated` 가 안 선다. **09 의 설계대로였다면 절반의 회차에서 지우 루트 13편이 통째로 사라졌을 것이다.** 10 이 `*_dated` 게이트를 빼면서 피해가 관찰문 한 줄로 줄었다 |

---

## 3. 보고서에 없는 것 — 내가 새로 찾은 영구 잠금

### 3.1 무엇인가

09_content §4.2 가 `seoyeon_r03`(두 번째 뒤풀이) · `seoyeon_r14`(뒤풀이 진실게임)에
`club_afterparty` 게이트를 **새로 넣었다.** HEAD 에는 없던 조건이다.

```
HEAD      seoyeon_r03 {"affection":{"*":[0,45]}, "day":[18,100], "flags":["seoyeon_met"]}
지금      seoyeon_r03 {"affection":{"*":[0,45]}, "day":[18,100], "flags":["seoyeon_met","club_afterparty"]}
```

그런데 그 플래그의 **유일한 세터인 `m07` 이 실패 경로에서 안 세운다.**

```
m07 [0] 자기소개를 한다     · 성공 → club_afterparty=O (minigame nerve_gauge)
m07 [0] 자기소개를 한다     · 실패 → club_afterparty=X (minigame nerve_gauge)
m07 [2] 안주만 먹는다       · 성공 → club_afterparty=O (chance 60)
m07 [2] 안주만 먹는다       · 실패 → club_afterparty=X (chance 60)
```

`EventEngine.applyChoice` 의 실패 분기는 `c.fail` 만 적용하고 `c.effects.setFlags` 를 건너뛴다.
`m07` 의 `fail` 에는 `setFlags` 가 없다.

**무작위 플레이어 200회차 측정:**

```
m07 재생 200/200 · club_afterparty 보유 150/200 (75.0%)
seoyeon_r03 본 회차 139/200
```

즉 **회차의 25%가 D+17 에 미니게임을 지거나 60% 판정에 실패한 것만으로 서연 장면 두 편을
영구히 잃는다.** 화면에는 아무 신호도 없다. 가장 자연스러운 선택지(`자기소개를 한다`)가
바로 그 미니게임 뒤에 있다.

### 3.2 왜 안 잡혔나 — 가드가 그 자리에서 눈을 감는다

`test/route_order_test.dart` 에 정확히 이걸 잡으라고 만든 검사가 있다:

```dart
test('정적 검사: 루트 진행 플래그는 모든 선택지(실패 포함)에서 세워진다', () {
  ...
  for (final x in set[f] ?? <String>{}) {
    final e = bundle.eventById[x]!;
    if (e.layer != EventLayer.route) continue;   // ← 여기
    if (!guaranteedFlags(e).contains(f)) bad.add('$x 가 $f 를 일부 경로에서만 세움');
  }
```

**세터가 루트가 아니면 건너뛴다.** `club_afterparty` 를 세우는 것은 `m07`(main)이므로 검사 밖이다.
`route_order_test` 의 `focus` 봇은 `m07` 에서 실패하는 선택지를 잘 안 골라 `seoyeon_r03` 열람률이
94% 로 나오고, 그래서 시뮬레이션도 안 잡는다.

### 3.3 같은 모양이 10곳 더 있다

전수 조사(§7 의 스크립트 그대로 — 실패할 수 있는 선택지가 성공 분기에서만 세우는데,
다른 이벤트의 `trigger.flags` 가 그걸 요구하는 경우). 출력 11줄 중 `club_afterparty` 를 뺀 10줄:

```
m07                   0 자기소개를 한다                 ['club_afterparty']
m07                   2 안주만 먹는다                   ['club_afterparty']
m08                   0 아 그래? 안부 전해줘            ['junho_yeeun']
m08_m                 0 아 그래? 안부 전해줘            ['junho_geonwoo']
m35                   0 한다고 한다                     ['best_man']
m37                   0 그럼 3개월 동안 뭐였어          ['taehyun_truth']
geonwoo_r07           0 건우야, 방금 그 말 진담이야?    ['told_junho']
yeeun_r07             0 나 예은이 좋아해                ['told_junho']
d_open_wrong_number_2 1 약속 잘 다녀오세요. 늦지 마시고요 ['stranger_laugh']
d_open_app_match      0 취향대로 골라 본다              ['app_installed']
seoyeon_r04           1 그럼 이제 반말할게. 서연아      ['seoyeon_banmal']
```

무게순으로 추리면:

| 플래그 | 유일/주요 세터 | 실패하면 잃는 것 | 이번 회차에 생겼나 |
|---|---|---|---|
| `club_afterparty` | `m07` (미니게임 · chance 60) | `seoyeon_r03` `seoyeon_r14` | **예 — 새 잠금** |
| `junho_yeeun` | `m08` (`group_chat` 미니게임) | `yeeun_r03` `yeeun_r07` → `h_yeeun_junho` | 아니오(HEAD 부터) |
| `junho_geonwoo` | `m08_m` (`group_chat`) | `geonwoo_r03` `geonwoo_r07` → `h_geonwoo_junho` | 아니오 |
| `app_installed` | `d_open_app_match` (`profile_swipe`) | `d_fu_locked` | 아니오 |
| `stranger_laugh` | `d_open_wrong_number_2` (chance 60) | `d_fu_stranger` | 아니오 |
| `best_man` | `m35` (`word_order`) | 히든 `h_junho_wedding` | 아니오 |
| `taehyun_truth` | `m37` (`nerve_gauge`) | 히든 `h_taehyun_date` | 아니오 |
| `told_junho` | `yeeun_r07`·`geonwoo_r07` (`call_rhythm`) | 히든 `h_yeeun_junho`·`h_geonwoo_junho` | 아니오 |
| `seoyeon_banmal` | `seoyeon_r04[1]` (chance 75) + 다른 2곳 | `mo_seoyeon_call_dawn`(세터가 셋이라 가벼움) | 아니오 |
| `jiwoo_dated` | `m11[0]` (chance 50) | (10 이후) 관찰문 1줄 | 예(피해는 줄었다) |

기존분이 실제로 새는 것도 `route_order_test` 출력이 그대로 보여 준다 — `focus` 로 파고들어도
`yeeun r03 64% · r07 64%`, `geonwoo r03 46% · r07 48%`. 시뮬레이터 미니게임 성공률이 60%인 것과
정확히 맞아떨어진다. **즉 이건 이미 살아 있는 손실이고, 이번 회차가 서연 두 편을 거기에 얹었다.**

---

## 4. "못 한 것" 들 — 묻힌 정도 판정

| 보고서가 적은 것 | 실제 무게 | 판정 |
|---|---|---|
| 10 §5 "거절 회차는 `jiwoo_r01`·`jiwoo_r02`·`seunghyun_r00`~`r02` 를 못 본다. 의도다" | 맞다. 다만 **반대쪽(수락 경로)은 시뮬레이션 커버리지가 0%** 다. `focus` 봇은 `statSum` 이 stress 를 음수로 치는 탓에 `m03` 에서 **언제나 '안 나가'** 를 고른다(`sim_balance_test.dart:112-124`). 그래서 열람률 표에 `jiwoo r01/r02 = 0%`, `seunghyun r00/r01/r02 = 0%` 가 찍힌다. **"0/17 도달"은 전부 새 거절 문으로 얻은 값이고, 수락 경로의 도달성은 아무도 안 쟀다** | 보고서보다 나쁨(측정 공백) |
| 10 §5 "`d_twist_04` 제목이 `소개팅 상대의 정체` — 그대로 뒀다" | 제목뿐이 아니다. `characters.json` 의 `jiwoo.title`·`seunghyun.title` 이 **`"소개팅 상대"`** 이고, 09_ui 가 이번에 만든 **프로필 크게 보기(`profile_view.dart`)가 이름 옆에 호칭을 크게 띄운다.** 캐스트 소개·홈 사람들 줄에도 나온다. 거절·거짓말 회차에서 소개팅은 없었는데 앱이 세 군데에서 "소개팅 상대"라고 부른다 — **이번 UI 작업이 노출을 늘렸다** | 보고서보다 나쁨 |
| 09_content §6 "`m22` 클리프행어의 '그 남자'" | 여전히 `m22 | trigger null | cliff: 그 남자는 사촌이었다.` — 쪽 분기 없이 남성향 회차에도 그대로 나간다 | 적힌 대로 |
| 09_engine §E / 09_content §3 `openingScript` | `config.json` 의 값은 `[]`. **기능은 있고 전원은 안 들어왔다.** 보장은 `m01.next` 가 하고 있으니 동작상 문제는 없지만, 두 보고서가 같은 문제를 각자 고쳤다고 적어 겹쳐 보인다 | 틀이 부풀었음 |
| 09_ui §6 "실기기 확인 못 했다" | 정직하다. T7(소리)과 합치면 **실기기 1회 확인이 출시 전 필수 항목** | 적힌 대로 |
| 죽은 플래그 26종 | 재현됨(`flag_audit.py`). 전부 메인 밖이고 출시 차단 사유는 아니다 | 적힌 대로 |
| 09_engine §C "남은 번호 역행" | M8 참고 — 28%다 | 틀이 부풀었음 |

---

## 5. 살짝 약해진 단언 (763 → 849 사이에 지워진 것 점검)

`git diff test/` 전량을 읽었다. **삭제된 테스트 파일·케이스는 없고**, 기대값을 고친 곳은 다섯 군데다.

| 파일 | 변경 | 판정 |
|---|---|---|
| `opening_test.dart:299` | `greaterThanOrEqualTo(day <= 2 ? 2 : 3)` → `greaterThanOrEqualTo(2)` | **문제 없음.** 그 루프는 1~3일차만 돈다. 1·2일차는 원래 2였으므로 실질 완화는 3일차 하나뿐이고, `m_brief` 가 일상 한 칸을 가져간 것이 원인이라는 주석도 정확하다 |
| `event_screen_test.dart:116` | `expect(c.phase, Phase.summary)` → `Phase.event` + `expect(c.current!.id, 'd_open_bet')` | **오히려 강해졌다.** 다만 `m01 → d_open_bet` 보장의 **유일한 회귀 가드**가 이 한 줄이 됐다(M5) |
| `sfx_test.dart:205` | `bundle.eventById['m01']` → `events.firstWhere(뒤가 없는 첫 이벤트)` | 단언은 그대로. 데이터 순서에 기대는 약한 선택이지만 검사 내용은 안 줄었다 |
| `event_engine_test.dart` | `393→403`, `main 55→63`, `daily 117→119` | 콘텐츠가 실제로 늘었다. 내가 센 값과 일치 |
| `intro_test.dart` | 타이틀·캐스트 단계 반영 | 단언이 **늘었다**(`hasSave == false`, `playerName == null`, `BannerSlot` 없음) |

---

## 6. 출시 전에 고쳐야 할 것 (중요도 순)

1. **`m07` 의 `club_afterparty` 를 실패 경로에서도 세운다.** (또는 `seoyeon_r03`·`seoyeon_r14` 의
   게이트를 되돌린다.) 지금 **회차의 25%가 서연 장면 두 편을 영구히 잃는다.** 이번 회차가 만든
   잠금이고, 고치는 비용은 JSON 두 줄(`m07` 선택지 0·2의 `fail.setFlags` 에 `club_afterparty` 추가)이다.
2. **같은 모양 7곳을 한 번에 훑는다.** `junho_yeeun`·`junho_geonwoo` 는 이미 회차의 36~54%에서
   예은·건우 장면 두 편씩과 히든 하나를 날리고 있다(열람률 표가 증거다). 최소한
   **`fail.setFlags` 로 진행 플래그를 보존하는 규칙**을 정하고 일괄 적용할 것.
3. **`route_order_test` 의 정적 검사에서 `if (e.layer != EventLayer.route) continue;` 를 뺀다.**
   1·2를 고쳐도 이 줄이 남아 있으면 다음에 또 같은 구멍이 열린다. 이 한 줄이 이번 사고의 원인이다.
4. **`characters.json` 의 `jiwoo.title`·`seunghyun.title` = `"소개팅 상대"`.** 두 번째 문을 만들어 놓고
   앱은 세 화면(프로필·캐스트 소개·홈)에서 계속 소개팅이라고 부른다. `"변호사"`·`"수의사"` 처럼
   직업으로 바꾸거나 `no_setup` 플래그로 갈라야 한다. `d_twist_04` 제목도 같이.
5. **실기기 1회 확인** — 소리(T7: 테스트는 `SfxService.onPlay` 까지만 증명한다)와 새 타이틀·프로필
   Hero·켄번즈. 09_ui 도 미완으로 남겨 둔 항목이다.
6. **`m22` 클리프행어 쪽 분기**(`그 남자는 사촌이었다`) — 남성향 회차에서 성별이 안 맞는다.
7. **`m01 → d_open_bet` 회귀 가드 보강.** 지금 보장은 컨트롤러의 `next` 처리 한 곳에 얹혀 있고
   테스트는 한 줄이다. 세 선택지 × 확률 실패까지 도는 테스트로 고정할 것(내 `AUDIT 5` 를 그대로 옮기면 된다).
8. **수락 경로 도달성 측정.** `focus` 봇이 `m03` 에서 항상 거절하는 탓에 지우·승현의 수락 경로
   (`r00`~`r02`)가 열람률 0%다. `ROUTE_*` 환경변수 하나로 수락을 강제하는 변형을 추가할 것.
9. **문서 정합** — `09_minigame_audit.md §3` 의 "JSON 은 건드리지 않았다"는 사실과 다르다.
   `tool/spread_minigames.py` 가 이미 적용됐음을 §3·§6 에 적을 것.
10. (선택) 번호 역행 28%. 지금 테스트 상한은 `22/회차`(현재 16.3~16.6)다. 출시를 막을 일은 아니지만
    "40% 감소"라는 표현은 다음 문서에서 절대값으로 바꾸는 게 정직하다.

---

## 7. 부록 — 재현 방법

```bash
# 저장소 그대로
flutter test                 # 849 통과 · 1 건너뜀 · 0 실패
flutter analyze              # No issues found
python3 tool/flag_audit.py   # 211 / 182 / 26 / 1

# 두 번째 문·냉각·미니게임 다양성(내 하니스는 저장소 사본에만 있다)
#   AUDIT 1 두 번째 문 360회차     AUDIT 2 냉각 120회차 × 40일
#   AUDIT 3 미니게임 120회차        AUDIT 5 m01→d_open_bet 12경로
#   AUDIT 7~9 club_afterparty 실패 경로 · 무작위 200회차
```

실패 경로에서 새는 플래그 전수 조사(저장소에서 바로 돌아간다):

```bash
python3 - <<'PY'
import json,glob,os
events=[]
for p in glob.glob('assets/story/*.json'):
    b=os.path.basename(p)
    if b in ('characters.json','config.json','signals.json','endings.json'): continue
    d=json.load(open(p,encoding='utf-8'))
    if isinstance(d,list): events += [(b,e) for e in d if isinstance(e,dict)]
required=set()
for b,e in events:
    t=e.get('trigger') or {}
    required |= set(t.get('flags') or []) | set((t.get('flagsAtLeast') or {}).get('of') or [])
for b,e in events:
    for i,c in enumerate(e.get('choices') or []):
        if c.get('chance') is None and c.get('minigame') is None: continue
        lost = (set((c.get('effects') or {}).get('setFlags') or [])
                - set((c.get('fail') or {}).get('setFlags') or [])) & required
        if lost: print(e['id'], i, c['text'][:24], sorted(lost))
PY
```
