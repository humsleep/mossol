#!/usr/bin/env python3
"""메인 신규 2편을 events_main.json 에 넣는다 (docs/review/08_story_delivery.md §7.3 ★1·★2).

- `m_brief` / `m_brief_m` (D+3): 태현이 "네가 마주칠 사람 다섯"을 **이름과 역할로** 훑는다.
  캐스트 소개 화면은 첫 회차 경로에 없어서 아무도 못 본다 — 그 자리를 픽션 안에서 메운다.
- `m_week1` / `m_week1_m` (D+7): 1주차 정산. `{top}` 으로 **지금 제일 가까운 사람을 호명**하고
  D-93 과 내기를 다시 말한다.

메인은 같은 날에 쪽별(f·m) 하나씩만 둘 수 있다(story_repository.dart `main 날짜 중복`).
D+3·D+7 은 지금 비어 있는 날이다(메인이 박힌 날: 1,2,4,5,8,11,…).

    python3 tool/add_main_brief.py
"""

from __future__ import annotations

import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])

import story_io  # noqa: E402


def them(text, name="태현"):
    return {"who": "them", "text": text, "name": name}


def me(text):
    return {"who": "me", "text": text}


def narr(text):
    return {"who": "narr", "text": text}


def brief(eid, pref, roster, gossip):
    """태현의 캐스트 브리핑. [roster] 는 (번호 줄) 다섯 개."""
    return {
        "id": eid,
        "layer": "main",
        "trigger": {"pref": pref},
        "day": 3,
        "weight": 1,
        "title": "태현의 정리",
        "lines": [
            them("야 나 어제 새벽에 네 인간관계 정리했다"),
            them("엑셀로"),
            me("그걸 왜 해"),
            them("코치가 선수 파악은 해야지 ㅋㅋ"),
            them("들어봐. 앞으로 네가 마주칠 사람 다섯이다"),
            *[them(line) for line in roster],
            me("다섯 번째는 처음 듣는데"),
            them(gossip),
            narr("어제까지는 그냥 알림이 뜨는 이름들이었다."),
        ],
        "choices": [
            {
                "text": "누가 제일 가능성 있는데",
                "effects": {"stats": {"sense": 2}},
                "reply": [
                    them("그걸 알면 내가 왜 아직 혼자겠냐"),
                    them("근데 이 중에 한 명은 이미 너한테 먼저 말 걸었다"),
                    them("그거부터 답장해"),
                ],
            },
            {
                "text": "네가 뭔데 남의 인간관계를 정리해",
                "require": {"stats": {"esteem": 20}},
                "effects": {"stats": {"esteem": 2, "talk": 1}},
                "reply": [
                    them("코치지 뭐긴 뭐야"),
                    them("코치비는 치킨으로 받는다. 이미 걸어놨고 ㅋㅋ"),
                ],
            },
            {
                "text": "다섯 명이나 있었어?",
                "effects": {"stats": {"sincerity": 2, "esteem": 1}},
                "reply": [
                    them("있는 게 아니라 스쳐 지나가는 거야 지금은"),
                    them("만드는 건 네가 하는 거고"),
                    narr("다섯 개의 이름을 메모장에 옮겨 적었다."),
                ],
            },
            {
                "text": "이름 좀 그만 부르고 사진 보내봐",
                "effects": {"stats": {"charm": 1, "sincerity": -1}},
                "reply": [
                    them("야"),
                    them("그렇게 시작하면 100일 뒤에도 똑같아"),
                ],
            },
        ],
        "hint": 0,
        "cliffhanger": "태현이 엑셀 파일을 보냈다. 시트 이름이 'D-97'이다.",
    }


def week1(eid, pref, closing):
    return {
        "id": eid,
        "layer": "main",
        "trigger": {"pref": pref},
        "day": 7,
        "weight": 1,
        "title": "1주차 정산",
        "lines": [
            them("1주차 정산이다"),
            them("오늘로 D-93"),
            me("그걸 왜 네가 세고 있어"),
            them("치킨 열 마리가 걸렸으니까 ㅋㅋ"),
            them("일주일 결산. 프사 바꿨고, 단톡에서 말 텄고"),
            them("네 대화방 맨 위에 지금 누가 있냐"),
            narr("대화방 목록을 위에서부터 봤다. {top||아직 위에 아무도 없다}."),
            them("일주일이면 한 명은 위로 올라오는 게 정상이다"),
            them(closing),
        ],
        "choices": [
            {
                "text": "{top} 쪽으로 좀 더 해 볼게",
                "effects": {"stats": {"sense": 1}, "affection": {"@top": 2}},
                "reply": [
                    them("오 결정 빠르네"),
                    them("대신 나머지한테 어정쩡하게 굴지 마라. 그게 제일 최악이야"),
                ],
                "critReply": [
                    them("오 결정 빠르네"),
                    narr("그날 밤, {top}한테서 먼저 톡이 왔다. 뭐 하냐고."),
                ],
            },
            {
                "text": "아직 모르겠어. 더 볼래",
                "effects": {"stats": {"esteem": 2, "stress": 2}},
                "reply": [
                    them("그것도 방법이지"),
                    them("근데 93일이다. 무한하지 않아"),
                ],
            },
            {
                "text": "일주일 만에 뭘 알아",
                "effects": {"stats": {"sincerity": 2}},
                "reply": [
                    them("맞는 말이다"),
                    them("근데 아무것도 안 하면 93일 뒤에도 똑같은 말 할걸"),
                ],
            },
            {
                "text": "너는 일주일 동안 뭐 했는데",
                "effects": {"stats": {"talk": 2}},
                "reply": [
                    them("나? 나야 뭐…"),
                    them("…야 지금 네 얘기 하는 중이잖아 ㅋㅋ"),
                    narr("태현은 또 자기 얘기를 피했다. 두 번째다."),
                ],
            },
        ],
        "hint": 0,
        "cliffhanger": "태현의 상태 메시지가 바뀌었다. \"D-93. 치킨 아직 대기 중\"",
    }


NEW = [
    brief(
        "m_brief",
        "f",
        [
            "1. 서연 선배. 동아리. 단톡에서 너만 콕 집은 그 사람",
            "2. 다은. 네 알바 선임. 영수증 뒷면에 그림 그리는 애",
            "3. 예은. 초등학교 동창. 네 흑역사 지분 80프로",
            "4. 소희. 그 게임 듀오. 샷콜하던 목소리 주인",
            "5. 지우. 너희 엄마가 밀고 있는 소개팅 상대. 변호사래",
        ],
        "우리 엄마랑 너희 엄마가 같은 미용실 다녀. 나도 듣기 싫었다",
    ),
    brief(
        "m_brief_m",
        "m",
        [
            "1. 정우 선배. 동아리 회장. 공지는 딱딱한데 개인톡은 서툰 사람",
            "2. 하늘. 네 알바 동료. 국밥값 반반 하자는 애",
            "3. 건우. 초등학교 동창. 말없이 전학 갔다가 돌아온 짝꿍",
            "4. 민재. 그 게임 듀오. 새벽 두 판 하고 얼굴은 안 까는 애",
            "5. 승현. 너희 엄마가 밀고 있는 소개팅 상대. 수의사래",
        ],
        "우리 엄마랑 너희 엄마가 같은 미용실 다녀. 나도 듣기 싫었다",
    ),
    week1("m_week1", "f", "93일 남았다. 이제 다섯 명이 아니라 한두 명이야"),
    week1("m_week1_m", "m", "93일 남았다. 이제 다섯 명이 아니라 한두 명이야"),
]


def main() -> int:
    events = story_io.load("events_main.json")
    have = {e["id"] for e in events}
    dupes = [e["id"] for e in NEW if e["id"] in have]
    if dupes:
        print(f"멈춤 — 이미 있는 id: {dupes}", file=sys.stderr)
        return 1

    # 다른 파일과도 id 가 겹치면 안 된다(엔진은 모든 파일을 한 풀로 합친다).
    import glob
    import json
    import os

    for path in glob.glob(os.path.join(story_io.STORY, "*.json")):
        base = os.path.basename(path)
        if base in ("characters.json", "config.json", "signals.json", "events_main.json"):
            continue
        for e in json.load(open(path, encoding="utf-8")):
            if e.get("id") in {n["id"] for n in NEW}:
                print(f"멈춤 — {base} 에 같은 id 가 있다: {e['id']}", file=sys.stderr)
                return 1

    # 메인은 day 순서로 두는 것이 읽기 좋다. m02(day 2) 뒤, m_mbti_chat(day 4) 앞에 끼운다.
    for ev in NEW:
        at = next(
            (i for i, e in enumerate(events) if (e.get("day") or 0) > ev["day"]),
            len(events),
        )
        events.insert(at, ev)

    story_io.save("events_main.json", events)
    print(f"메인 {len(NEW)}편 추가: {', '.join(e['id'] for e in NEW)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
