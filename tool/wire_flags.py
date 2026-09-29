#!/usr/bin/env python3
"""선택을 기억하게 만든다 — 소개팅 줄기 게이트, 뒤풀이 순서, 죽은 플래그 배선.

docs/review/07_story_flow.md (c)#2·#4·#6, 08_story_delivery.md §7.3 을 데이터 쪽에서 실행한다.

1. **소개팅 줄기 게이트**: `m03` 에서 "안 나가"(`refused_mom`)·"썸 있어"(`lied_to_mom`) 를
   고르면 `m10`(소개팅 D-1)·`m11`(애프터)·`m12` 가 더는 오지 않는다. 지금은 조건이 `null`
   이라 거절해도 D+26 에 소개팅 전날이 왔다.
2. **뒤풀이 순서**: `m07`(D+17 첫 뒤풀이)이 `club_afterparty` 를 세우고,
   `seoyeon_r03`·`seoyeon_r14` 가 그 플래그를 요구한다. 첫 뒤풀이가 끝나기 전에는 못 나온다.
   (지문도 "그다음 모임"으로 고쳐 같은 날 밤이 두 번 끝나지 않게 한다.)
3. **d_open_bet 보장**: `m01` 의 모든 선택지에 `next: d_open_bet` 을 단다. D+1 에 100% 나온다.
   `config.openingScript` 가 채워져도 `_queue.removeWhere` 덕에 두 번 나오지 않는다.
4. **죽은 플래그 배선**: 세워지기만 하고 아무도 안 읽던 플래그를 signals 관찰문과
   새 후속 이벤트 두 개(`d_fu_pact`·`d_fu_taehyun`)의 트리거로 잇는다.

    python3 tool/wire_flags.py
"""

from __future__ import annotations

import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])

import story_io  # noqa: E402

problems: list[str] = []


def note(msg: str) -> None:
    problems.append(msg)


# --------------------------------------------------------------------------- 1·2·3
def patch_main() -> int:
    events = story_io.load("events_main.json")
    ix = story_io.by_id(events)
    n = 0

    # 1. 소개팅 줄기. 엄마 소개팅을 거절·회피했으면 소개팅 자체가 없다.
    gates = {
        "m10": {"notFlags": ["refused_mom", "lied_to_mom"]},
        "m11": {"pref": "f", "flags": ["jiwoo_intro"]},
        "m11_m": {"pref": "m", "flags": ["seunghyun_intro"]},
        "m12": {"pref": "f", "flags": ["jiwoo_intro"]},
        "m12_m": {"pref": "m", "flags": ["seunghyun_intro"]},
    }
    for eid, trig in gates.items():
        ev = ix.get(eid)
        if ev is None:
            note(f"{eid} 없음")
            continue
        ev["trigger"] = trig
        n += 1

    # 2. 뒤풀이 플래그. m07 의 모든 선택지가 세운다(어떤 선택을 해도 뒤풀이에는 갔다).
    m07 = ix.get("m07")
    if m07 is None:
        note("m07 없음")
    else:
        for c in m07["choices"]:
            eff = c.setdefault("effects", {})
            flags = eff.setdefault("setFlags", [])
            if "club_afterparty" not in flags:
                flags.append("club_afterparty")
                n += 1

    # 3. d_open_bet 을 D+1 에 보장한다(m01 의 모든 갈래에서 이어진다).
    m01 = ix.get("m01")
    if m01 is None:
        note("m01 없음")
    else:
        for c in m01["choices"]:
            if c.get("next") is None:
                c["next"] = "d_open_bet"
                n += 1
            if c.get("chance") is not None or c.get("minigame") is not None:
                if c.get("failNext") is None:
                    c["failNext"] = "d_open_bet"
                    n += 1

    story_io.save("events_main.json", events)
    return n


# --------------------------------------------------------------------------- 2 (루트 쪽)
ROUTE_FIX = {
    "seoyeon_r03": {
        "flags": ["seoyeon_met", "club_afterparty"],
        "title": "두 번째 뒤풀이",
        "lines": [
            (
                "자리가 두 개 남았다. 서연 옆자리와 출입문 쪽.",
                "그날 이후 두 번째 뒤풀이. 자리가 두 개 남았다. 서연 옆자리와 출입문 쪽.",
            ),
        ],
    },
    "seoyeon_r14": {
        "flags": ["seoyeon_met", "club_afterparty"],
        "lines": [
            (
                "진실게임. 서연 차례에 화살이 나에게 왔다.",
                "몇 번째 뒤풀이인지 모르겠다. 진실게임, 서연 차례에 화살이 나에게 왔다.",
            ),
        ],
    },
}


def patch_routes() -> int:
    events = story_io.load("events_route_a.json")
    ix = story_io.by_id(events)
    n = 0
    for eid, fix in ROUTE_FIX.items():
        ev = ix.get(eid)
        if ev is None:
            note(f"{eid} 없음")
            continue
        ev["trigger"]["flags"] = fix["flags"]
        n += 1
        if "title" in fix:
            ev["title"] = fix["title"]
        for old, new in fix["lines"]:
            hit = False
            for l in ev["lines"]:
                if l.get("text") == old:
                    l["text"] = new
                    hit = True
                elif l.get("text") == new:
                    hit = True  # 이미 고쳐져 있다(다시 돌려도 안전).
            if not hit:
                note(f'{eid}: 지문 못 찾음 "{old}"')
            else:
                n += 1
    story_io.save("events_route_a.json", events)
    return n


# --------------------------------------------------------------------------- 4 (새 후속)
def them(text, name):
    return {"who": "them", "text": text, "name": name}


def me(text):
    return {"who": "me", "text": text}


def narr(text):
    return {"who": "narr", "text": text}


NEW_DAILY = [
    {
        "id": "d_fu_pact",
        "layer": "daily",
        "trigger": {
            "day": [14, 100],
            "flagsAtLeast": {"n": 1, "of": ["pact", "pact_passive"]},
        },
        "weight": 3,
        "once": True,
        "title": "협약 중간보고",
        "lines": [
            them("야 우리 협약 며칠 됐지", "준호"),
            them("나는 그날 이후로 아무 일도 없었다", "준호"),
            them("너는?", "준호"),
        ],
        "choices": [
            {
                "text": "나도 비슷해",
                "effects": {"stats": {"stress": -3, "sincerity": 1}},
                "reply": [
                    them("다행이다 ㅋㅋ 둘 다 망하면 그건 그냥 우정이지", "준호"),
                    them("그래도 진 쪽이 주선하는 건 유효하다", "준호"),
                ],
            },
            {
                "text": "한 명은 답장이 빨라졌어",
                "effects": {"stats": {"esteem": 2}, "affection": {"@top": 1}},
                "reply": [
                    them("누구. 이름. 빨리", "준호"),
                    narr("{top} 이름을 적었다가 지웠다. 아직은 내 것만 하고 싶다."),
                    them("야 지금 지운 거 다 봤다", "준호"),
                ],
            },
            {
                "text": "협약 그만하자",
                "effects": {"stats": {"esteem": 1, "reputation": -1}},
                "reply": [
                    them("왜. 불리해지니까?", "준호"),
                    them("알았어. 대신 나 혼자라도 한다", "준호"),
                ],
            },
        ],
        "hint": 1,
        "cliffhanger": "준호가 협약서에 한 줄을 더 적어 보냈다. \"기한: D-100부터.\"",
    },
    {
        "id": "d_fu_taehyun",
        "layer": "daily",
        "trigger": {
            "day": [20, 100],
            "flagsAtLeast": {"n": 1, "of": ["asked_taehyun", "doubt_taehyun"]},
        },
        "weight": 3,
        "once": True,
        "title": "나중에 얘기해 줄게",
        "lines": [
            narr("새벽 1시. 태현한테서 톡이 왔다. 용건이 없는 톡이다."),
            them("야 자냐", "태현"),
            them("너 전에 나한테 물어봤잖아. 너는 어떻게 했냐고", "태현"),
            them("사실 나 그거 대답 안 했지", "태현"),
            {"who": "sys", "wait": 6},
        ],
        "choices": [
            {
                "text": "지금 들을게",
                "effects": {"stats": {"sincerity": 2, "talk": 1}},
                "reply": [
                    them("…나 한 번도 안 해봤어", "태현"),
                    them("코치가 무면허였다 ㅋㅋ 이제 알았지", "태현"),
                    narr("조언 절반이 왜 위험했는지 이제 알 것 같다."),
                ],
            },
            {
                "text": "됐어. 그냥 자",
                "effects": {"stats": {"stress": -3, "sense": 1}},
                "reply": [
                    them("ㅋㅋ 그래", "태현"),
                    them("언젠가 네가 먼저 물어보면 그때 할게", "태현"),
                ],
            },
            {
                "text": "그럼 네 조언은 다 어디서 난 건데",
                "effects": {"stats": {"sense": 2, "esteem": 1}},
                "reply": [
                    them("영상, 커뮤니티, 남의 연애 구경", "태현"),
                    them("…그리고 네가 잘되면 그게 내 첫 사례야", "태현"),
                ],
            },
        ],
        "hint": 0,
        "cliffhanger": "태현이 새벽 2시에 '읽음'만 남기고 조용해졌다.",
    },
]


def add_daily() -> int:
    events = story_io.load("events_daily.json")
    have = {e["id"] for e in events}
    added = 0
    for ev in NEW_DAILY:
        if ev["id"] in have:
            continue  # 이미 넣었다(다시 돌려도 안전).
        events.append(ev)
        added += 1
    story_io.save("events_daily.json", events)
    return added


# --------------------------------------------------------------------------- 4 (관찰문)
# (캐릭터, 구간 index, 문장, when) — 전부 **덧붙이기**라 기존 문장은 후보에서 빠지지 않는다.
SIGNALS = [
    # m01 뒷모습 프사(mystery_pfp)
    ("seoyeon", 0, "서연 선배가 내 뒷모습 프사 얼굴이 궁금하다고 했다", ["mystery_pfp"]),
    ("daeun", 0, "다은이 내 뒷모습 프사를 저장해 뒀다고 했다", ["mystery_pfp"]),
    ("jeongwoo", 0, "정우 선배가 내 뒷모습 프사 얘기를 두 번 꺼냈다", ["mystery_pfp"]),
    ("haneul", 0, "하늘이 프사 얼굴 좀 보자고 마감 내내 졸랐다", ["mystery_pfp"]),
    # m08/m08_m 준호의 동창회(claimed_*)
    ("yeeun", 2, "예은이 준호한테 뭘 들었는지 자꾸 웃는다", ["claimed_yeeun"]),
    ("geonwoo", 2, "건우가 준호한테 뭘 들었는지 자꾸 웃는다", ["claimed_geonwoo"]),
    # m10 소개팅 준비(prepared_date / unprepared_date)
    ("jiwoo", 2, "지우가 그날 카페를 어떻게 골랐냐고 또 물었다", ["prepared_date"]),
    ("jiwoo", 2, "지우가 첫 만남 즉흥이었죠, 하고 한 번 놀렸다", ["unprepared_date"]),
    ("seunghyun", 2, "승현 씨가 그날 자리 고른 얘기를 또 꺼냈다", ["prepared_date"]),
    ("seunghyun", 2, "승현 씨가 첫날은 좀 즉흥이었죠, 하고 웃었다", ["unprepared_date"]),
    # m12 밀당(played_games)
    ("jiwoo", 3, "지우가 이틀 연락 없던 날 얘기를 아직 한다", ["played_games"]),
    ("seunghyun", 3, "승현 씨가 이틀 조용했던 날을 아직 기억한다", ["played_games"]),
    # m24/m24_f 정체(minjae_meet / sohee_meet)
    ("minjae", 4, "민재가 만날 날짜를 먼저 물어 왔다", ["minjae_meet"]),
    ("sohee", 4, "소희가 만날 날짜를 먼저 물어 왔다", ["sohee_meet"]),
    # m20·d_two_05 한 사람을 골랐다(chose_one) / m23 집중(focused)
    ("seoyeon", 4, "서연 선배가 내가 정리한 걸 아는 눈치다", ["chose_one"]),
    ("jeongwoo", 4, "정우 선배가 내가 정리한 걸 아는 눈치다", ["chose_one"]),
    ("daeun", 4, "다은이 요즘 내 얘기에 다른 이름이 없다고 했다", ["focused"]),
    ("haneul", 4, "하늘이 요즘 내 얘기에 다른 이름이 없다고 했다", ["focused"]),
    # --- 메인 후반 선택 6종 (backtrack·contented·demanded_setup·greedy·rulebook·self_focus) ---
    ("seoyeon", 5, "서연 선배가 내가 다시 연락한 날 얘기를 꺼냈다", ["backtrack"]),
    ("jeongwoo", 5, "정우 선배가 내가 다시 연락한 날 얘기를 꺼냈다", ["backtrack"]),
    ("daeun", 5, "다은이 요즘 우리 속도가 딱 좋다고 했다", ["contented"]),
    ("haneul", 5, "하늘이 요즘 우리 속도가 딱 좋다고 했다", ["contented"]),
    ("yeeun", 3, "예은이 준호한테 소개팅 조른 걸 어디서 들었다", ["demanded_setup"]),
    ("geonwoo", 3, "건우가 준호한테 소개팅 조른 걸 어디서 들었다", ["demanded_setup"]),
    ("seoyeon", 3, "서연 선배가 내 답장이 늘 비슷한 시간이라고 했다", ["rulebook"]),
    ("daeun", 3, "다은이 내 답장 시간이 너무 규칙적이라고 웃었다", ["rulebook"]),
]

# 구간이 내려간 날의 조용한 문장(`down`). 같은 형식이고 구간 번호 대신 "down" 이다.
SIGNALS_DOWN = [
    ("seoyeon", "서연 선배가 요즘 나한테 바쁜 일이 많냐고 물었다", ["greedy"]),
    ("jeongwoo", "정우 선배가 요즘 나한테 바쁜 일이 많냐고 물었다", ["greedy"]),
    ("daeun", "다은이 요즘 나 혼자 잘 지내는 것 같다고 했다", ["self_focus"]),
    ("haneul", "하늘이 요즘 나 혼자 잘 지내는 것 같다고 했다", ["self_focus"]),
]


def patch_signals() -> int:
    book = story_io.load("signals.json")
    chars = book["characters"]
    n = 0
    for cid, band, text, flags in SIGNALS:
        c = chars.get(cid)
        if c is None:
            note(f"signals: 캐릭터 {cid} 없음")
            continue
        lines = c["bands"][band]["lines"]
        if any(isinstance(l, dict) and l.get("text") == text for l in lines):
            continue
        if len(text) > 40:
            note(f"signals: 40자 초과({len(text)}) {cid} \"{text}\"")
            continue
        lines.append({"text": text, "when": {"flags": flags}})
        n += 1
    for cid, text, flags in SIGNALS_DOWN:
        c = chars.get(cid)
        if c is None:
            note(f"signals: 캐릭터 {cid} 없음")
            continue
        lines = c["down"]
        if any(isinstance(l, dict) and l.get("text") == text for l in lines):
            continue
        lines.append({"text": text, "when": {"flags": flags}})
        n += 1
    story_io.save("signals.json", book)
    return n


def main() -> int:
    counts = {
        "메인 게이트·플래그·next": patch_main(),
        "뒤풀이 루트 재게이트": patch_routes(),
        "새 후속 일상": add_daily(),
        "관찰문 배선": patch_signals(),
        "소개팅 이후 루트 게이트": patch_after_date(),
    }
    for k, v in counts.items():
        print(f"  {k}: {v}곳")
    if problems:
        print("\n확인 필요:", file=sys.stderr)
        for p in problems:
            print("  " + p, file=sys.stderr)
        return 1
    return 0




# --------------------------------------------------------------------------- 1 (여파)
# `m11`/`m11_m` 에 조건이 붙는 순간, 소개팅 루트 r03~r15 는 "m11 뒤"라는 보장을 날짜로만
# 가지고 있던 것이 깨진다(소개팅을 안 한 회차에서 m11 이 안 오는데 루트는 온다).
# 그래서 m11 이 "소개팅을 했다" 플래그를 세우고 루트가 그걸 요구하게 한다.
# test/route_order_test.dart 의 `jiwoo_r03 ← m11` 정적 검사가 이것을 고정한다.
AFTER_DATE = {
    "m11": ("jiwoo_dated", "route_jiwoo", "jiwoo"),
    "m11_m": ("seunghyun_dated", "route_seunghyun", "seunghyun"),
}


def patch_after_date() -> int:
    n = 0
    main = story_io.load("events_main.json")
    mix = story_io.by_id(main)
    for eid, (flag, _, _) in AFTER_DATE.items():
        ev = mix.get(eid)
        if ev is None:
            note(f"{eid} 없음")
            continue
        for c in ev["choices"]:
            flags = c.setdefault("effects", {}).setdefault("setFlags", [])
            if flag not in flags:
                flags.append(flag)
                n += 1
    story_io.save("events_main.json", main)

    import glob
    import json
    import os

    stages = [f"r{i:02d}" for i in range(3, 16)]
    for path in glob.glob(os.path.join(story_io.STORY, "*.json")):
        base = os.path.basename(path)
        if base in ("characters.json", "config.json", "signals.json"):
            continue
        data = json.load(open(path, encoding="utf-8"))
        if not isinstance(data, list):
            continue
        touched = False
        for e in data:
            for _, (flag, _, who) in AFTER_DATE.items():
                if any(e["id"] == f"{who}_{s}" for s in stages):
                    flags = e.setdefault("trigger", {}).setdefault("flags", [])
                    if flag not in flags:
                        flags.append(flag)
                        n += 1
                        touched = True
        if touched:
            story_io.save(base, data)
    return n


if __name__ == "__main__":
    sys.exit(main())
