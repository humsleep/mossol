#!/usr/bin/env python3
"""안 열리는 트리거를 연다 (docs/review/12_engine_handoff.md §1).

측정: `tool/unseen_dailies.dart` — 100일 완주 30회차(시드 5 × 선호 2 × 전략 3)에서
1회성 일상 101개 중 **평균 31.7개가 한 번도 안 읽힌다.** 그중 26.9개는 추첨 운이 아니라
**후보로조차 못 올라온다.**

후보조차 못 되는 26.9개를 뜯어 보면 넷으로 갈린다.

  (가) 설계상 당연한 것 — 선호 반대쪽 쌍 7개, 이 회차에 없는 캐릭터의 `*_mbti_talk` 6개,
       내기 정산 3종 중 안 고른 2개. 합 15개. **못 연다. 열면 안 된다.**
  (나) 2회차 전용 — `yuna_mbti_talk`(히든 유나 루트는 `run: [2,99]`). 1회차 측정에
       안 잡히는 게 맞다. **안 건드린다.**
  (다) **테스트가 못 박은 설계** — 오프닝 10개(`d_open_*`)의 `day: [1,3]` 과
       후속 3개(`d_fu_*`)의 `day: [4,20]`·`flags` 한 개. 창을 넓혀 봤더니
       `test/opening_test.dart` 의 "4일차 이후 격리"·"기존 풀 잠식 없음" 이 깨졌다.
       내 파일이 아닌 테스트가 지키는 결정이라 **되돌렸다.** 실측한 이득은
       `docs/review/13_content_handoff.md` §1 에 숫자로 적어 넘긴다.
  (라) **그냥 막혀 있는 것** — 아래 표. 이 스크립트가 여는 것이 이것이다.

전부 **값이 정확히 일치할 때만** 바꾸고, 하나라도 안 맞으면 파일을 쓰지 않고 멈춘다
(`tool/stop_reruns.py` 와 같은 규칙).

사용: python3 tool/open_triggers.py [--dry]
"""

from __future__ import annotations

import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])

import story_io  # noqa: E402

DRY = "--dry" in sys.argv
problems: list[str] = []
changes: list[str] = []


def set_trigger(ev: dict, before: dict, after: dict, why: str) -> None:
    if ev.get("trigger") != before:
        problems.append(f"{ev['id']} trigger 가 예상과 다르다: {ev.get('trigger')}")
        return
    ev["trigger"] = after
    changes.append(f"  트리거 {ev['id']:<22} {why}")


def set_line(ev: dict, i: int, before: str, after: str, why: str) -> None:
    if ev["lines"][i].get("text") != before:
        problems.append(f"{ev['id']} lines[{i}] 가 예상과 다르다: {ev['lines'][i].get('text')}")
        return
    ev["lines"][i]["text"] = after
    changes.append(f"  대사   {ev['id']:<22} {why}")


def add_flag(ev: dict, ci: int, flag: str, why: str) -> None:
    fx = ev["choices"][ci].setdefault("effects", {})
    flags = fx.setdefault("setFlags", [])
    if flag in flags:
        problems.append(f"{ev['id']} choices[{ci}] 에 이미 {flag} 가 있다")
        return
    flags.append(flag)
    changes.append(f"  플래그 {ev['id']:<22} choices[{ci}] +{flag} — {why}")


daily = story_io.load("events_daily.json")
d = story_io.by_id(daily)


# --- 1. 그 번호, 다시 — 실측 0/30 회차 --------------------------------------
#
# `d_fu_stranger` 는 `stranger_laugh` 를 요구한다. 그 플래그는 `d_open_wrong_number_2`
# (체인 이벤트)의 **세 선택지 중 하나**에서만 섰다. 부모를 뽑고(24/30) → 그 부모의
# 첫 선택지를 고르고 → 여기서 또 특정 선택지를 골라야 하므로 도달률이 1/9 이하다.
#
# 낯선 번호가 **다시 말을 거는** 데 필요한 건 "늦지 마세요"라는 특정 문장이 아니라
# **내가 답장을 했다는 사실**이다. 그래서 세 선택지 전부가 같은 플래그를 세운다.
# (트리거는 안 건드린다 — `test/opening_test.dart:506` 이 `trigger.flags == ['stranger_laugh']`
#  와 `day [4,20]` 을 못 박고 있다.)
for ci in (0, 2):
    add_flag(d["d_open_wrong_number_2"], ci, "stranger_laugh", "답장을 했다는 사실")
# 첫 줄이 '말씀대로'(= 특정 선택지)를 전제했다. 어느 답장에도 맞는 문장으로.
set_line(
    d["d_fu_stranger"],
    0,
    "저 그날 안 늦었어요 ㅋㅋ 말씀대로",
    "저 그날 결국 안 늦었어요 ㅋㅋ",
    "'말씀대로' 가 세 선택지 중 하나만 가리켰다",
)


# --- 2. 도달 불가능한 스탯 조건 ----------------------------------------------
#
# 실측 D+20 이후 스탯 분포(30회차 × 80일):
#   esteem  p05=62 p25=98 p50=100      ← `[0, 35]` 은 사실상 못 넘는다
#   stress  p05=0  p25=0  p50=6  p75=40  p95=77
#   money   p05=12 p25=117 p50=201 p75=346
#
# 2-a. 픽업 영상 3연작(`d_temp_01` → `d_temp_02`(w8) → `d_temp_06`(w6))이 통째로 죽어 있다.
#      입구인 `d_temp_01` 이 `esteem [0,35]` 을 요구하는데 D+20 이후 자존감 하위 5%가 62다.
#      실측 후보 2/30 회차. 조건을 **없앤다** — 알고리즘은 자존감을 안 보고 들이민다.
#      게다가 "자존감이 이미 낮은 사람에게만 유혹을 보여 준다"는 건 선택 설계로도 틀렸다.
#      **유혹은 아직 안 넘어간 사람에게 와야 선택이 된다.**
set_trigger(
    d["d_temp_01"],
    {"day": [20, 100], "stats": {"esteem": [0, 35]}},
    {"day": [18, 100]},
    "2/30 · esteem[0,35] 은 D+20 이후 도달 불가(p05=62) → 조건 삭제",
)

# 2-b. '들통'(`d_temp_06`)은 `pickup_1`(= 영상대로 밀당한다)만 읽었다. 그런데 이 장면이
#      말하는 건 "채널에 내 흔적이 남아 SNS 추천에 떴다"이므로 **댓글을 단 것도 같다.**
#      `d_temp_01` 의 '댓글을 단다'가 세우는 `pickup_comment` 를 새로 두고 둘 중 하나로 연다.
add_flag(d["d_temp_01"], 2, "pickup_comment", "채널에 댓글 = 내 계정이 채널에 남는다")
set_trigger(
    d["d_temp_06"],
    {"day": [30, 100], "flags": ["pickup_1"]},
    {"day": [30, 100], "flagsAtLeast": {"n": 1, "of": ["pickup_1", "pickup_comment"]}},
    "1/30 → 댓글을 단 회차에서도 들통난다",
)
set_line(
    d["d_temp_06"],
    0,
    "픽업 영상 채널을 구독한 게 SNS 추천에 떴다.",
    "픽업 영상 채널에 남긴 흔적이 SNS 추천에 떴다.",
    "'구독' 이 한쪽 선택지만 가리켰다",
)

# 2-c. 잠결 전화 — 11/30. `stress [40,100]` 은 위 분포에서 상위 25% 근처라 저스트레스
#      회차에서는 100일 내내 안 열린다. 새벽 2시에 전화를 걸어 놓고 기억을 못 하는 데
#      스트레스 40이 꼭 필요하진 않다.
set_trigger(
    d["d_drink_04"],
    {"day": [20, 100], "stats": {"stress": [40, 100]}},
    {"day": [20, 100], "stats": {"stress": [25, 100]}},
    "11/30 · stress 40 → 25",
)

# 2-d. 용돈 — 21/30. `money [0,100]`(= 10만원 미만)인데 D+35 이후 잔고 중앙값이 201 이다.
#      엄마가 10만원을 내미는 장면이 성립하는 선은 그보다 넉넉하다.
set_trigger(
    d["d_family_04"],
    {"day": [35, 100], "stats": {"money": [0, 100]}},
    {"day": [35, 100], "stats": {"money": [0, 150]}},
    "21/30 · money 상한 100 → 150",
)


# --- 3. 반복 풀의 깊이 — 조건 때문에 풀에 못 들어오는 반복 일상 둘 ------------
#
# 재방송 비율의 분모는 "그 회차에 낼 수 있는 일상 종류"다. 반복 가능한 24개 중 둘은
# 스탯 조건 때문에 회차의 3분의 1에서만 풀에 든다 — 그만큼 나머지가 더 자주 돌아온다.
#
# `d_kakao_07` 새벽 감성 메시지 — 후보 10/30. `stress [50,100]` 은 상위 10% 다.
#   "새벽 4시. 잠이 안 온다" 는 스트레스 35에서도 맞는다.
set_trigger(
    d["d_kakao_07"],
    {"day": [25, 100], "stats": {"stress": [50, 100]}},
    {"day": [25, 100], "stats": {"stress": [35, 100]}},
    "반복 풀 · stress 50 → 35 (후보 10/30)",
)
# `d_date_04` 예산 초과(후보 25/30)도 같은 이유로 `money [0,160]` 으로 넓혔다가 **되돌렸다.**
# 이건 회차에 여러 번 나오는 반복 일상이고 실패하면 −20 이라, 넓히니 200시드 실측에서
# D+100 잔고가 288 → 260, `c_money_fight` 가 101 → 118 로 움직였다. 후보 3회차를 더 얻는
# 대가로 경제를 건드리는 거래는 안 받는다(`tool/stop_reruns.py` §1.4 가 같은 실수를 기록해 뒀다).


if problems:
    print("멈춤 — 예상과 다른 값이 있다. 파일을 쓰지 않았다.")
    for p in problems:
        print("  !", p)
    raise SystemExit(1)

print(f"트리거·대사·플래그 {len(changes)}곳")
for c in changes:
    print(c)
if DRY:
    print("(--dry: 파일을 쓰지 않았다)")
else:
    story_io.save("events_daily.json", daily)
    print("events_daily.json 저장")
