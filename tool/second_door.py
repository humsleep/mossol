#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""두 번째 문 — 엄마의 소개팅을 거절/거짓말해도 지우·승현을 만난다.

docs/review/10_second_door.md 참고. 다시 돌려도 안전하다(이미 넣었으면 건너뛴다).

하는 일
 1) 새 메인 4편 삽입: m10_refused / m10_refused_m (D+25, 거절), m10_lied / m10_lied_m (D+27, 거짓말)
 2) 중립 플래그 jiwoo_met / seunghyun_met — 세 문(수락·거절·거짓말) 모두가 세운다
 3) m11·m11_m·m12·m12_m 의 trigger.flags 제거(D+29 합류점을 무조건으로)
    + m11·m11_m 의 첫 지문을 소개팅 전용에서 문 중립으로 고쳐 씀
 4) 루트 r03~r15 의 jiwoo_dated / seunghyun_dated 게이트 제거
    (D+29 합류점이 무조건이고 그 루트들의 day 하한이 30 이상이라 날짜가 순서를 보장한다)
 5) 모먼트·MBTI 잡담의 게이트를 *_intro / jiwoo_texted → *_met 로
 6) signals.json 에 새 플래그를 읽는 관찰문 추가(죽은 플래그를 만들지 않는다)
"""

from __future__ import annotations

import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import story_io as sio  # noqa: E402


# --------------------------------------------------------------------------
# 1. 새 메인 4편
# --------------------------------------------------------------------------

def narr(t):
    return {"who": "narr", "text": t}


def them(t, name=None, sticker=None):
    d = {"who": "them", "text": t}
    if name:
        d["name"] = name
    if sticker:
        d["sticker"] = sticker
    return d


def me(t):
    return {"who": "me", "text": t}


def wait(n):
    return {"who": "sys", "wait": n}


M10_REFUSED = {
    "id": "m10_refused",
    "layer": "main",
    "trigger": {"pref": "f", "flags": ["refused_mom"]},
    "character": "jiwoo",
    "day": 25,
    "weight": 1,
    "title": "정정하고 싶어서요",
    "lines": [
        narr("저장 안 된 번호. 프로필에 사진이 없다."),
        them("안녕하세요. 이 번호 맞나요. 확인부터 할게요"),
        me("…네 맞는데요"),
        them("지우예요. 어머니들끼리 잡으셨던 그 자리요"),
        them("취소된 건 아시죠"),
        wait(15),
        them("그게 제가 취소한 걸로 정리돼 있더라고요"),
        them("저희 어머니한테도, 그쪽 어머니한테도요"),
        them("정정하고 싶어서 연락드렸어요. 그게 다예요"),
    ],
    "choices": [
        {
            "text": "제가 안 나간 거 맞아요. 죄송합니다",
            "effects": {
                "stats": {"sincerity": 3},
                "affection": {"jiwoo": 3},
                "trust": {"jiwoo": 3},
                "setFlags": ["jiwoo_met", "jiwoo_no_setup"],
            },
            "reply": [
                them("…네. 그거면 됐어요"),
                them("사과받으려고 연락한 건 아닌데, 받으니까 좀 낫네요"),
            ],
        },
        {
            "text": "그쪽도 나갈 생각 없었던 거 아니에요?",
            "effects": {
                "stats": {"esteem": 1, "sense": 2},
                "affection": {"jiwoo": 1},
                "trust": {"jiwoo": -1},
                "setFlags": ["jiwoo_met", "jiwoo_no_setup"],
            },
            "reply": [
                them("없었죠. 근데 저는 나갔을 거예요"),
                them("약속이었으니까요. 그게 저랑 그쪽 차이예요"),
            ],
        },
        {
            "text": "엄마들이 정한 자리잖아요. 왜 우리가 사과해요",
            "require": {"stats": {"talk": 30}},
            "effects": {
                "stats": {"talk": 2},
                "affection": {"jiwoo": 4},
                "trust": {"jiwoo": 2},
                "setFlags": ["jiwoo_met", "jiwoo_no_setup"],
            },
            "reply": [
                them("…그렇게 말해 주는 사람은 처음이에요"),
                them("그럼 정정 문구는 '양쪽 다 안 나갔다'로 할까요"),
                narr("지우가 처음으로 ㅋ 를 하나 붙였다."),
            ],
            "critReply": [
                them("그 말 들으려고 연락한 건 아닌데요"),
                them("…들으니까 화가 좀 풀리네요. 이건 기록 안 할게요"),
            ],
        },
        {
            "text": "정정하려면 근거가 있어야죠. 제가 직접 말할게요",
            "mbti": "T",
            "effects": {
                "stats": {"sense": 3},
                "affection": {"jiwoo": 3},
                "trust": {"jiwoo": 2},
                "setFlags": ["jiwoo_met", "jiwoo_no_setup"],
            },
            "reply": [
                them("직접이요? 어머님께요?"),
                them("…일 얘기할 때 듣는 말투인데. 나쁘지 않네요"),
            ],
        },
        {
            "text": "그 얘기 듣는 내내 기분 안 좋으셨겠어요",
            "mbti": "F",
            "effects": {
                "stats": {"sincerity": 2},
                "affection": {"jiwoo": 3},
                "trust": {"jiwoo": 3},
                "setFlags": ["jiwoo_met", "jiwoo_no_setup"],
            },
            "reply": [
                them("네. 솔직히 좀 그랬어요"),
                them("그 얘기를 먼저 해 주시네요. 저는 사실관계부터 말했는데"),
            ],
        },
    ],
    "hint": 1,
    "cliffhanger": "지우: \"정정은 제가 할게요. 대신 한 번은 직접 뵙고 싶은데요.\"",
}

M10_REFUSED_M = {
    "id": "m10_refused_m",
    "layer": "main",
    "trigger": {"pref": "m", "flags": ["refused_mom"]},
    "character": "seunghyun",
    "day": 25,
    "weight": 1,
    "title": "한 번은 말해야 할 것 같아서요",
    "lines": [
        narr("저장 안 된 번호. 프로필 사진은 강아지 뒤통수다."),
        them("안녕하세요. 승현입니다. 어머님께 번호 받았습니다"),
        them("자리가 없어졌다고 들었어요. 그건 괜찮습니다"),
        wait(12),
        them("그래도 한 번은 말해야 할 것 같아서요"),
        them("저는 나가려고 했었어요"),
        them("이 말 안 하면 계속 생각날 것 같아서요. 그게 다예요"),
    ],
    "choices": [
        {
            "text": "제가 안 나간 거예요. 미안해요",
            "effects": {
                "stats": {"sincerity": 3},
                "affection": {"seunghyun": 3},
                "trust": {"seunghyun": 3},
                "setFlags": ["seunghyun_met", "seunghyun_no_setup"],
            },
            "reply": [
                them("네. 말해 줘서 고마워요"),
                them("사과까지는 안 바랐는데, 받으니까 확실히 낫네요"),
            ],
        },
        {
            "text": "왜 지금 말해요?",
            "effects": {
                "stats": {"sense": 2},
                "affection": {"seunghyun": 1},
                "setFlags": ["seunghyun_met", "seunghyun_no_setup"],
            },
            "reply": [
                them("미루면 안 할 것 같아서요"),
                them("저는 미루면 그냥 안 하는 사람이에요. 그게 싫어서요"),
            ],
        },
        {
            "text": "그럼 지금이라도 나갈게요. 날짜 주세요",
            "require": {"stats": {"talk": 30}},
            "effects": {
                "stats": {"talk": 2},
                "affection": {"seunghyun": 5},
                "trust": {"seunghyun": 3},
                "setFlags": ["seunghyun_met", "seunghyun_no_setup"],
            },
            "reply": [
                them("…지금이요?"),
                them("좋아요. 확실히"),
                them("후보 세 개 추려서 보낼게요. 고르는 건 그쪽이 해요"),
            ],
            "critReply": [
                them("…지금이요?"),
                them("좋아요. 확실히. 저 지금 병원에서 혼자 웃었어요"),
                them("후보 세 개 보낼게요. 고르는 건 그쪽이 해요"),
            ],
        },
        {
            "text": "엄마들 빼고 우리끼리 정하는 거면 나갈게요",
            "mbti": "T",
            "effects": {
                "stats": {"sense": 3},
                "affection": {"seunghyun": 3},
                "trust": {"seunghyun": 2},
                "setFlags": ["seunghyun_met", "seunghyun_no_setup"],
            },
            "reply": [
                them("그게 맞는 것 같아요. 저도 그 조건이면 편해요"),
                them("어머니 쪽에는 제가 말씀드릴게요. 확실히 끊어 둘게요"),
            ],
        },
        {
            "text": "말 안 했으면 계속 생각났을 거라는 말, 좋네요",
            "mbti": "F",
            "effects": {
                "stats": {"sincerity": 2},
                "affection": {"seunghyun": 4},
                "trust": {"seunghyun": 3},
                "setFlags": ["seunghyun_met", "seunghyun_no_setup"],
            },
            "reply": [
                them("좋다고 해 주니까 저도 좋네요"),
                them("이런 말은 보내고 나면 늘 후회했는데, 오늘은 안 그래요"),
            ],
        },
    ],
    "hint": 1,
    "cliffhanger": "승현이 날짜 후보 세 개를 보냈다. 이번엔 어머니 얘기가 없다.",
}

M10_LIED = {
    "id": "m10_lied",
    "layer": "main",
    "trigger": {"pref": "f", "flags": ["lied_to_mom"]},
    "character": "jiwoo",
    "day": 27,
    "weight": 1,
    "title": "사실관계가 안 맞아서요",
    "lines": [
        narr("토요일이 그냥 지나갔다. 아무 일도 없었다."),
        narr("일요일 오후, 저장 안 된 번호에서 톡이 왔다."),
        them("안녕하세요. 지우예요. 번호는 어머니들 통해서 받았어요"),
        them("만나는 분이 계시다고 들었어요. 축하드려요"),
        wait(12),
        them("그런데 사진 한 장만 보여 달라셨을 때 못 보여주셨다면서요"),
        them("거짓말이라는 게 아니라, 사실관계가 안 맞아서요. 직업병이에요"),
        them("솔직히 말하면 저도 안 나가고 싶었거든요. 핑계가 부러웠어요"),
    ],
    "choices": [
        {
            "text": "…없어요. 그런 사람",
            "effects": {
                "stats": {"sincerity": 4},
                "affection": {"jiwoo": 5},
                "trust": {"jiwoo": 5},
                "setFlags": ["jiwoo_met", "jiwoo_no_setup", "lied_caught"],
            },
            "reply": [
                them("알아요"),
                them("그래도 본인 입으로 들어야 다음 얘기를 하죠"),
            ],
            "critReply": [
                them("알아요. 어머님 표정이 다 말해 주던데요"),
                them("그 말 하기까지 오래 걸리셨죠. 이제 다음 얘기 해요"),
            ],
        },
        {
            "text": "있어요. 사진은 안 보여줄 거고요",
            "effects": {
                "stats": {"sincerity": -3},
                "affection": {"jiwoo": -2},
                "album": "없는 애인 끝까지 우기기",
                "setFlags": ["jiwoo_met", "jiwoo_no_setup", "lied_caught"],
            },
            "reply": [
                them("네. 그럼 그 얘기는 여기까지 할게요"),
                them("근데 취소된 자리 때문에 한 번은 뵈어야 해요"),
                them("어머니들이 안 끝내 주셔서요"),
            ],
        },
        {
            "text": "핑계 필요하시면 저 쓰셔도 돼요",
            "require": {"stats": {"talk": 30}},
            "effects": {
                "stats": {"talk": 2},
                "affection": {"jiwoo": 4},
                "trust": {"jiwoo": 2},
                "setFlags": ["jiwoo_met", "jiwoo_no_setup", "lied_caught"],
            },
            "reply": [
                them("지금 저한테 공범 하자고 하신 거예요"),
                them("변호사한테요?"),
                them("…좋아요. 한 번은 뵙죠. 조건은 만나서 얘기해요"),
            ],
        },
        {
            "text": "사실관계를 따지시면 제가 불리한데요",
            "mbti": "T",
            "effects": {
                "stats": {"sense": 3},
                "affection": {"jiwoo": 3},
                "setFlags": ["jiwoo_met", "jiwoo_no_setup", "lied_caught"],
            },
            "reply": [
                them("불리한 걸 아시네요. 그럼 얘기가 빠르죠"),
                them("저는 이기려고 연락한 게 아니라서요"),
            ],
        },
        {
            "text": "핑계가 부러웠다는 말이 더 신경 쓰이는데요",
            "mbti": "F",
            "effects": {
                "stats": {"sincerity": 2},
                "affection": {"jiwoo": 4},
                "trust": {"jiwoo": 3},
                "setFlags": ["jiwoo_met", "jiwoo_no_setup", "lied_caught"],
            },
            "reply": [
                them("…그 말을 잡으실 줄은 몰랐어요"),
                them("네. 부러웠어요. 저는 그런 말 못 지어내거든요"),
            ],
        },
    ],
    "hint": 1,
    "cliffhanger": "지우가 약속 시간을 먼저 보냈다. 장소는 법원 앞 카페다.",
}

M10_LIED_M = {
    "id": "m10_lied_m",
    "layer": "main",
    "trigger": {"pref": "m", "flags": ["lied_to_mom"]},
    "character": "seunghyun",
    "day": 27,
    "weight": 1,
    "title": "저는 그 핑계를 못 대요",
    "lines": [
        narr("토요일이 그냥 지나갔다. 아무 일도 없었다."),
        narr("일요일 오후, 저장 안 된 번호에서 톡이 왔다."),
        them("안녕하세요. 승현입니다"),
        them("만나는 분이 있다고 들었어요. 그럼 저는 여기서 끝내는 게 맞습니다"),
        wait(12),
        them("그런데 저희 어머니가 그 얘기를 하시면서 웃으시더라고요"),
        them("저희 엄마는 거짓말할 때 웃어요. 10년 봤어요"),
        them("아니면 아니라고만 해 주세요. 그럼 저는 다시 시작할 수 있어요"),
    ],
    "choices": [
        {
            "text": "…없어요. 죄송해요",
            "effects": {
                "stats": {"sincerity": 4},
                "affection": {"seunghyun": 5},
                "trust": {"seunghyun": 5},
                "setFlags": ["seunghyun_met", "seunghyun_no_setup", "lied_caught"],
            },
            "reply": [
                them("네. 확실히 들었어요"),
                them("그럼 없던 일로 하고 제가 다시 인사드릴게요. 처음부터요"),
            ],
            "critReply": [
                them("네. 확실히 들었어요"),
                them("거짓말한 사람이 먼저 말하는 건 어려운 건데요"),
                them("그럼 처음부터 다시 할게요. 안녕하세요, 승현입니다"),
            ],
        },
        {
            "text": "있어요",
            "effects": {
                "stats": {"sincerity": -3},
                "affection": {"seunghyun": -2},
                "album": "없는 애인 끝까지 우기기",
                "setFlags": ["seunghyun_met", "seunghyun_no_setup", "lied_caught"],
            },
            "reply": [
                them("알겠습니다. 축하드려요"),
                narr("답장이 딱 거기서 멈췄다."),
                them("…그래도 어머니들 정리는 해야 해서, 한 번은 뵙겠습니다"),
            ],
        },
        {
            "text": "저도 거짓말을 잘 못해요. 그래서 들켰고요",
            "require": {"stats": {"talk": 30}},
            "effects": {
                "stats": {"talk": 2},
                "affection": {"seunghyun": 4},
                "trust": {"seunghyun": 3},
                "setFlags": ["seunghyun_met", "seunghyun_no_setup", "lied_caught"],
            },
            "reply": [
                them("그럼 우리 둘 다 못하는 거네요"),
                them("잘됐어요. 저는 잘하는 사람이 제일 어렵거든요"),
            ],
        },
        {
            "text": "어머니가 웃었다는 게 근거예요?",
            "mbti": "T",
            "effects": {
                "stats": {"sense": 3},
                "affection": {"seunghyun": 2},
                "setFlags": ["seunghyun_met", "seunghyun_no_setup", "lied_caught"],
            },
            "reply": [
                them("네. 10년치 표본이에요"),
                them("진료도 그렇게 봐요. 주인 얼굴부터 봅니다"),
            ],
        },
        {
            "text": "그 말 하기까지 많이 망설이셨겠어요",
            "mbti": "F",
            "effects": {
                "stats": {"sincerity": 2},
                "affection": {"seunghyun": 4},
                "trust": {"seunghyun": 3},
                "setFlags": ["seunghyun_met", "seunghyun_no_setup", "lied_caught"],
            },
            "reply": [
                them("사흘 썼어요. 지웠다 썼다"),
                them("물어봐 줘서 고마워요. 그건 생각 못 했어요"),
            ],
        },
    ],
    "hint": 1,
    "cliffhanger": "승현: \"다시 인사드릴게요. 승현입니다.\"",
}

NEW_MAIN = [M10_REFUSED, M10_REFUSED_M, M10_LIED, M10_LIED_M]


# --------------------------------------------------------------------------

def main() -> None:
    changed = []

    # ---- events_main.json ----
    ev = sio.load("events_main.json")
    ix = sio.by_id(ev)

    # (a) 세 번째 문(수락)도 중립 플래그를 세운다.
    for eid, flag in (("m03", "jiwoo_met"), ("m03_m", "seunghyun_met")):
        c = ix[eid]["choices"][0]
        assert c["text"] == "나간다", (eid, c["text"])
        f = c["effects"].setdefault("setFlags", [])
        if flag not in f:
            f.append(flag)
            changed.append(f"{eid} 수락 선택지 +{flag}")

    # (b) D+29 합류점을 무조건으로. 소개팅 전용 지문을 문 중립으로.
    # 지우=모음 끝(를), 승현=받침(을). 조사를 손으로 맞춘다.
    for eid, name in (("m11", "지우를"), ("m11_m", "승현을")):
        e = ix[eid]
        if e["trigger"].pop("flags", None):
            changed.append(f"{eid} trigger.flags 제거")
        e["title"] = "다음 약속"
        e["lines"][0]["text"] = f"{name} 만나고 오는 길이다. 두 시간." + (
            " 나쁘지 않았다. 좋지도 않았다." if eid == "m11" else " 생각보다 괜찮았다."
        )
        e["lines"][1]["text"] = (
            "집에 오는 지하철. 다시 보자고 먼저 말할지 말지."
            if eid == "m11"
            else "집에 오는 지하철. 먼저 말할지 고민하기도 전에 폰이 울렸다."
        )
    for eid in ("m12", "m12_m"):
        if ix[eid]["trigger"].pop("flags", None):
            changed.append(f"{eid} trigger.flags 제거")

    # (c) 새 메인 4편.
    for e in NEW_MAIN:
        if e["id"] in ix:
            ev[ev.index(ix[e["id"]])] = e  # 다시 돌리면 최신 대본으로 교체한다.
            changed.append(f"~{e['id']} 갱신")
            continue
        # 날짜순 자리에 끼워 넣는다(파일이 날짜순이라 읽기 편하게).
        pos = next(
            (i for i, x in enumerate(ev) if (x.get("day") or 0) > e["day"]), len(ev)
        )
        ev.insert(pos, e)
        changed.append(f"+{e['id']} (D+{e['day']})")
    sio.save("events_main.json", ev)

    # ---- 루트 게이트 ----
    for fn, dated, met, texted in (
        ("events_route_a.json", "jiwoo_dated", "jiwoo_met", "jiwoo_texted"),
        ("route_seunghyun.json", "seunghyun_dated", "seunghyun_met", "seunghyun_texted"),
    ):
        data = sio.load(fn)
        for e in data:
            t = e.get("trigger") or {}
            fl = t.get("flags")
            if fl and dated in fl:
                fl.remove(dated)
                if not fl:
                    t.pop("flags")
                changed.append(f"{e['id']} -{dated}")
            # MBTI 잡담은 소개팅 전용 플래그 대신 중립 플래그로.
            if e["id"].endswith("_mbti_talk") and fl and texted in fl:
                fl[fl.index(texted)] = met
                changed.append(f"{e['id']} {texted}→{met}")
        sio.save(fn, data)

    # ---- 모먼트 게이트: *_intro → *_met ----
    for fn in ("events_moments.json", "route_seunghyun.json"):
        data = sio.load(fn)
        hit = False
        for e in data:
            if not e["id"].startswith("mo_"):
                continue
            fl = (e.get("trigger") or {}).get("flags") or []
            for intro, met in (("jiwoo_intro", "jiwoo_met"), ("seunghyun_intro", "seunghyun_met")):
                if intro in fl:
                    fl[fl.index(intro)] = met
                    hit = True
                    changed.append(f"{e['id']} {intro}→{met}")
        if hit:
            sio.save(fn, data)

    # ---- signals.json 관찰문 ----
    sg = sio.load("signals.json")
    add = {
        "jiwoo": {
            1: [
                ("지우가 어머니들 얘기는 이제 안 꺼낸다", ["jiwoo_no_setup"]),
                ("지우가 그날 정정 문자를 캡처해 뒀다고 했다", ["jiwoo_no_setup"]),
                ("지우가 없는 애인 얘기를 아직 놀린다", ["lied_caught"]),
            ],
            10: [
                ("지우가 소개팅으로 만난 게 아니라고 정정했다", ["jiwoo_no_setup"]),
                ("지우가 다시 보자던 날 얘기를 먼저 꺼냈다", ["jiwoo_dated"]),
            ],
        },
        "seunghyun": {
            1: [
                ("승현이 그때 안 나온 얘기를 이제 안 한다", ["seunghyun_no_setup"]),
                ("승현이 먼저 연락한 날을 아직 쑥스러워한다", ["seunghyun_no_setup"]),
                ("승현이 없는 애인 얘기에 아직 웃는다", ["lied_caught"]),
            ],
            10: [
                ("승현이 소개팅은 결국 안 했다고 정정했다", ["seunghyun_no_setup"]),
                ("승현이 다음 약속을 먼저 물어 왔다", ["seunghyun_dated"]),
            ],
        },
    }
    for cid, bands in add.items():
        for b in sg["characters"][cid]["bands"]:
            for text, flags in bands.get(b["min"], []):
                assert len(text) <= 40, (text, len(text))
                if any(isinstance(l, dict) and l.get("text") == text for l in b["lines"]):
                    continue
                b["lines"].append({"text": text, "when": {"flags": flags}})
                changed.append(f"signals {cid} {b['min']}~ +1줄")
    sio.save("signals.json", sg)

    print(f"{len(changed)}건")
    for c in changed:
        print(" ", c)


if __name__ == "__main__":
    main()
