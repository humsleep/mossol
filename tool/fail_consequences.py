#!/usr/bin/env python3
"""미니게임을 지면 이야기가 달라진다 — `failNext` 46개와 뒷일 장면 10개.

측정(작업 전): 미니게임 선택지 **191개 중 `failNext` 가 0개.** 내 파일에 167개가 있고
나머지 24개는 `events_main.json`(담당 다름 → `docs/review/13_content_handoff.md` §3).
실패해도 대사 두 줄(`failReply`)만 다르고 **그날 이후가 똑같다.** 미니게임이 '지연이 붙은
탭' 이 되는 건 여기서다.

## 무엇을 했나

1. **뒷일 장면 10개를 새로 썼다** (`events_moments.json`, id `mo_fail_*`).
   - 전부 `trigger: {"day": [0, 0]}` — **추첨에 절대 안 들어온다.** `failNext` 로만 열린다
     (`d_open_bet_2` 가 쓰는 그 방식이다). 그래서 하루 계획·가중치·밸런스에 영향이 없다.
   - 전부 **모먼트**다(사진 카드 또는 알림). 실패가 형식을 깬다 —
     "실패했으니 숫자가 조금 깎였다"가 아니라 **다음 화면이 다른 모양으로 온다.**
   - `events_moments.json` 에 두는 이유: `test/event_engine_test.dart:54` 의
     `expect(baseEvents().length, 403)` 이 `mo_` 접두사를 세지 않는다. 내 파일이 아닌
     테스트를 건드리지 않고 장면을 늘릴 수 있는 자리가 여기뿐이다(규격 §3 도 이 접두사다).
   - `once: false` · `layer: "daily"` 다. **고른 게 아니라 테스트 둘이 양쪽에서 막아
     남은 한 조합이다** — 이유와 부작용(소프트락 방지선 계수가 24 → 34 로 읽힌다)은
     §1 주석에 적었다.

2. **`failNext` 46개를 걸었다.** 뒷일 장면 하나가 여러 실패를 받는데, **픽션이 맞는
   자리에만 걸었다.** 예를 들어 `mo_fail_misread`(설명 없이 온 사진)는 `read_emotion` 실패
   7곳에 걸었지만 `d_friend_07`(준호가 눈치챈 장면)과 `d_luck_04`(국밥집 사장님)에는 안 걸었다 —
   그 둘은 상대가 사진을 보낼 사람이 아니다.

3. **실패에 관계 이동을 적었다(22곳).** 규칙은 둘이다.
   - **상대가 보는 실패**(술자리에서 선을 넘음, 단톡에서 못 막음)는 **−1**.
   - **성공 보상이 큰 고백·편지 장면**(성공 +6~10)은 **+1~2** — 말은 꼬였지만 시도한 건 보인다.
     0 과 10 사이가 전부 아니면 아무것도인 것보다 낫다. **벌이 아니라 차이다.**
   - 나머지(혼자만 아는 타이밍·말 순서 실패)는 그대로 뒀다. 성공이 주는 값과 0 의 차이가
     이미 결과다.

사용: python3 tool/fail_consequences.py [--dry]
"""

from __future__ import annotations

import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])

import story_io  # noqa: E402


# 말풍선 머리에 쓰는 '이번 회차 호감 1위'. `Line.mapText` 가 `name` 도 치환한다
# (`events_main.json` 이 같은 방식으로 164곳에서 쓴다). 상대가 누구인지 장면마다
# 달라지는 뒷일(`mo_fail_capture` 서연/부장, `mo_fail_meme_missed` 단톡/상대)에는
# **쓰지 않는다** — 그쪽은 이름을 비워 두는 게 맞다(`d_kakao_03`·`d_meet_02` 와 같다).
TOP = "{top}"


def n(t: str) -> dict:
    return {"who": "narr", "text": t}


def them(t: str, name: str | None = None) -> dict:
    return {"who": "them", "text": t} if name is None else {"who": "them", "text": t, "name": name}


def wait(s: int) -> dict:
    return {"who": "sys", "wait": s}


def photo(icon: str, caption: str, t: str | None = None, who: str = "them", name: str | None = None) -> dict:
    l: dict = {"who": who, "photo": {"icon": icon, "caption": caption}}
    if t is not None:
        l["text"] = t
    if name is not None:
        l["name"] = name
    return l


def ch(text: str, stats: dict, reply: list[str], album: str | None = None) -> dict:
    fx: dict = {"stats": stats}
    if album is not None:
        fx["album"] = album
    return {"text": text, "effects": fx, "reply": reply}


# --- 1. 뒷일 장면 10개 -------------------------------------------------------
# 공통: trigger day [0,0](추첨 제외) · weight 1 · **`once: false`** · **layer daily**.
#
# 이 두 값은 고른 게 아니라 **테스트 둘이 양쪽에서 못 박은 것**이다.
#
#  - `once: true` 로 두면 `test/rerun_share_test.dart` 의 "once 이벤트는 한 번도
#    재등장하지 않는다" 가 깨진다. `next`/`failNext` 로 들어온 이벤트는 `_available` 을
#    안 지나므로 `once` 가 안 걸리고, 뒷일 장면 하나가 여러 실패를 받으니 한 회차에
#    두 번 열린다(실측: `mo_fail_late_dawn×3`).
#  - `once: false` 로 두면 같은 테스트의 다음 줄이 **두 번 읽힌 것은 전부 `daily` 층**
#    이어야 한다고 못 박는다(`rerun_share_test.dart:299`). 그래서 `route` 도 안 된다.
#
# 남는 조합이 `once: false` + `layer: daily` 하나뿐이다. **부작용 하나를 적어 둔다:**
# `StoryBundle.repeatableDaily` 가 `layer == daily && !once` 를 세고 그 수가 소프트락
# 방지선(`_checkRepeatables`)인데, 여기에 **뽑히지도 않는**(창이 `[0,0]`) 장면 10개가
# 얹혀 24개 → 34개로 읽힌다. 진짜 뽑히는 반복 일상은 여전히 24개다. 다음 사람이 34을
# 믿고 `once: true` 를 더 붙이면 안 된다 → 엔진에 한 줄 요청을 넣었다
# (`repeatableDaily` 에서 창이 닫힌 이벤트 제외) — `docs/review/13_content_handoff.md` §4.
AFTERMATH = [
    {
        "id": "mo_fail_capture",
        "layer": "daily",
        "once": False,
        "trigger": {"day": [0, 0]},
        "weight": 1,
        "title": "캡처는 안 지워진다",
        "lines": [
            n("두 시간 뒤. 사진 한 장이 왔다."),
            photo("street", "지웠다고 믿었던 화면", "이거 아직 갖고 있는데"),
            wait(5),
            them("어떻게 해 줄까"),
        ],
        "choices": [
            ch("지워 주세요. 부탁이에요", {"sincerity": 2, "esteem": -1},
               ["알았어. 지웠다", "근데 한 번은 웃었다"]),
            ch("갖고 있어도 돼요", {"esteem": 3, "stress": -3},
               ["…배짱 좋네", "그럼 나만 아는 걸로 할게"]),
            ch("(읽고 아무 말도 안 한다)", {"stress": 8},
               ["답 없네", "알았어. 나도 없던 일로"], album="지워지지 않은 화면 한 장"),
        ],
        "hint": 1,
    },
    {
        "id": "mo_fail_drunk_replay",
        "layer": "daily",
        "once": False,
        "trigger": {"day": [0, 0]},
        "weight": 1,
        "title": "다음 날 오후 한 시",
        "lines": [
            n("다음 날 오후 1시. 동아리 단톡에 알림 열두 개."),
            photo("night", "어제 그 자리 영상", "레전드 남았다 ㅋㅋㅋ", name="준호"),
            them("지워 달라는 사람 벌써 두 명 있음", "준호"),
        ],
        "choices": [
            ch("지워 줘. 진심으로 부탁한다", {"esteem": 1, "reputation": 1},
               ["내렸다", "근데 캡처는 못 막는다"]),
            ch("ㅋㅋ 남겨 둬", {"esteem": 3, "reputation": -1},
               ["그래 이게 너지", "다음 뒤풀이 사회는 너다"]),
            ch("어제 뭐라고 했는지만 알려 줘", {"sense": 2, "stress": 4},
               ["몰라도 되는 게 있어", "…진짜 몰라도 돼"]),
        ],
        "hint": 0,
    },
    {
        "id": "mo_fail_stranger_saw",
        "layer": "daily",
        "once": False,
        "trigger": {"day": [0, 0]},
        "weight": 1,
        "title": "얼어붙은 걸 본 사람",
        "preview": "혹시 아까 저한테 말 걸려고 하셨어요?",
        "lines": [
            n("그날 밤. 저장 안 된 번호로 톡이 왔다."),
            them("혹시 아까 저한테 말 걸려고 하셨어요?", "모르는 번호"),
            wait(4),
            them("표정이 그래 보여서요 ㅋㅋ", "모르는 번호"),
        ],
        "choices": [
            ch("네. 근데 입이 안 떨어졌어요", {"esteem": 3, "sincerity": 2},
               ["다음엔 제가 먼저 걸게요", "그럼 공평하죠"]),
            ch("아니에요. 착각이세요", {"esteem": -1, "stress": 4},
               ["아 그래요?", "그럼 제가 이상한 사람이네요 ㅋㅋ"]),
            ch("번호는 어떻게 아셨어요?", {"sense": 2, "talk": 1},
               ["아까 두고 가신 종이에 적혀 있었어요", "돌려드릴까요?"]),
        ],
        "hint": 0,
    },
    {
        "id": "mo_fail_intro_capture",
        "layer": "daily",
        "once": False,
        "trigger": {"day": [0, 0]},
        "weight": 1,
        "title": "돌아다니는 한 줄",
        "lines": [
            n("다음 날. 준호가 사진 한 장을 보냈다."),
            photo("street", "과 단톡 캡처 한 장", "이거 너지", name="준호"),
            them("세 번째 방에서 받았어", "준호"),
        ],
        "choices": [
            ch("누가 캡처한 거야", {"stress": 4, "sense": 1},
               ["몰라", "유명해진 거 축하한다"]),
            ch("ㅋㅋ 그게 뭐 어때", {"esteem": 3, "reputation": 1},
               ["그렇게 나오면 재미없는데", "인정. 쿨하다"]),
            ch("그 방에 나도 넣어 줘", {"talk": 2, "reputation": 1},
               ["뭐?", "…넣었다. 니가 제일 이상해"]),
        ],
        "hint": 1,
    },
    {
        "id": "mo_fail_mirror_shot",
        "layer": "daily",
        "once": False,
        "trigger": {"day": [0, 0]},
        "weight": 1,
        "title": "거울 앞 한 장",
        "lines": [
            n("집에 와서 거울 앞에 섰다. 한 장 찍어 보냈다."),
            photo("selfie", "오늘의 결과물", "이거 괜찮아?", who="me"),
            wait(5),
            them("솔직히 말해도 돼?", "준호"),
        ],
        "choices": [
            ch("솔직히 말해", {"sense": 3, "esteem": -1},
               ["2주 뒤엔 괜찮아질 거야", "그때까지 모자 쓰고 다녀"]),
            ch("아니 그냥 괜찮다고 해 줘", {"stress": -3, "esteem": 2},
               ["괜찮아", "진심은 아니지만 괜찮아"]),
            ch("(사진을 지운다)", {"charm": 1, "stress": 4},
               ["뭐야 지웠어?", "나 아직 보고 있었는데"], album="지운 거울 사진 한 장"),
        ],
        "hint": 0,
    },
    {
        "id": "mo_fail_half_sent",
        "layer": "daily",
        "once": False,
        "trigger": {"day": [0, 0]},
        "weight": 1,
        "title": "반은 내가 냈어",
        "lines": [
            n("집에 오는 길. 폰이 두 번 울렸다."),
            photo("ticket", "입금 알림 한 줄", "반 보냈어", name=TOP),
            them("다음엔 내가 고를게. 싼 데로", TOP),
        ],
        "choices": [
            ch("미안. 내가 계산을 잘못했어", {"sincerity": 3, "esteem": -1},
               ["알아", "다음에 싸게 먹으면 돼"]),
            ch("안 받아도 되는데", {"sincerity": 2, "money": -10},
               ["받아", "그게 내가 편해"]),
            ch("다음엔 진짜 내가 낼게", {"talk": 1, "esteem": 2},
               ["기억해 둘게", "메모했다 ㅋㅋ"]),
        ],
        "hint": 2,
    },
    {
        "id": "mo_fail_misread",
        "layer": "daily",
        "once": False,
        "trigger": {"day": [0, 0]},
        "weight": 1,
        "title": "설명 없이 온 사진",
        "lines": [
            n("세 시간 뒤. 사진 한 장이 왔다. 설명은 없다."),
            photo("sky", "아무것도 없는 하늘", name=TOP),
            wait(6),
            them("아니야. 그냥 보냈어", TOP),
        ],
        "choices": [
            ch("무슨 일 있었어?", {"sense": 2},
               ["아까 내가 한 말", "그거 그런 뜻 아니었어"]),
            ch("나 아까 잘못 알아들었지", {"sense": 3, "sincerity": 2},
               ["응", "근데 다시 물어봐 줘서 됐어"]),
            ch("(사진에 하트만 누른다)", {"stress": 3},
               ["…", "그래. 그것도 답이지"]),
        ],
        "hint": 1,
    },
    {
        "id": "mo_fail_late_dawn",
        "layer": "daily",
        "once": False,
        "trigger": {"day": [0, 0]},
        "weight": 1,
        "title": "내가 쓰는 동안",
        "lines": [
            n("답장을 지웠다 쓰는 동안 위에 줄이 하나 더 올라왔다."),
            them("아 자는구나", TOP),
            wait(8),
            photo("night", "새벽 3시 창밖", "이거 보여 주고 싶었는데", name=TOP),
        ],
        # 스탯은 실측으로 다시 잡았다. 이 장면은 회차당 2.5번 열리는 최다 트래픽이라
        # 첫 선택지에 스트레스를 얹으면 그것만으로 회차 스트레스가 +7 쌓인다
        # (전략 `first` 의 번아웃 엔딩이 58.5% → 67.0% 로 튀었다). 제때 받은 쪽은
        # 값이 없고, 놓친 쪽(아침에 답한다)에만 작게 남긴다.
        "choices": [
            ch("안 자. 지금 봤어", {"talk": 1, "esteem": 1},
               ["진짜?", "그럼 아직 안 늦었네"]),
            ch("미안. 보고 있었는데 못 봤어", {"sincerity": 2},
               ["괜찮아", "내일 또 보여 줄게"]),
            ch("(아침에 답한다)", {"stress": 2, "sense": -1},
               ["그 하늘 없어졌어", "다음엔 깨워도 돼?"], album="아침에 답한 새벽 사진"),
        ],
        "hint": 0,
    },
    {
        "id": "mo_fail_call_cut",
        "layer": "daily",
        "once": False,
        "trigger": {"day": [0, 0]},
        "weight": 1,
        "title": "1분 12초",
        "lines": [
            n("통화가 끊겼다. 30초 뒤에 사진 한 장이 왔다."),
            photo("game", "통화 기록 1분 12초", "우리 방금 뭐라고 한 거지", name=TOP),
            them("글로 다시 말해 줄래?", TOP),
        ],
        "choices": [
            ch("글로 다시 쓸게. 천천히", {"talk": 2, "sincerity": 2},
               ["응 기다릴게", "이번엔 안 끊어"]),
            ch("전화로 다시 하자", {"talk": 1, "stress": 5},
               ["그럼 이번엔 네가 걸어", "심호흡하고"]),
            ch("없던 일로 하자", {"stress": -3, "esteem": -2},
               ["…그래", "근데 나는 기억할 거야"], album="1분 12초, 없던 일로"),
        ],
        "hint": 0,
    },
    {
        "id": "mo_fail_meme_missed",
        "layer": "daily",
        "once": False,
        "trigger": {"day": [0, 0]},
        "weight": 1,
        "title": "3초 늦었다",
        "lines": [
            n("3초 늦었다. 위에 다른 짤이 먼저 떠 있다."),
            photo("game", "내 짤 바로 위의 짤", "이게 더 웃기네 미안"),
            them("네 것도 나쁘진 않았어. 순서가 나빴어"),
        ],
        "choices": [
            ch("다음엔 내가 먼저", {"talk": 1, "sense": 1},
               ["기대는 안 함", "근데 기다릴게"]),
            ch("짤 폴더 좀 공유해 줘", {"sense": 3},
               ["이건 영업 비밀인데", "…보냈다"]),
            ch("(내 짤을 삭제한다)", {"stress": 3, "esteem": -1},
               ["왜 지워", "아 나 저장했는데"], album="3초 늦어서 지운 짤"),
        ],
        "hint": 1,
    },
]


# --- 1b. 뒷일 장면의 변형 대사 2벌씩 -----------------------------------------
#
# 뒷일 장면은 `once: false` 라 한 회차에 두 번 이상 열린다(실측: 회차당 8번쯤 열리고
# 그중 4~5번이 이미 읽은 장면이었다). 그래서 **원본 + 변형 2벌 = 3벌**을 붙였다 —
# `EventEngine.variantOf` 가 본 횟수로 돌리므로 세 번째로 볼 때까지 글자가 안 겹친다.
# 사진 줄 유무는 원본과 같게 맞춰야 한다(`_checkVariants`).
AFTERMATH_VARIANTS: dict[str, list[list[dict]]] = {
    "mo_fail_capture": [
        [
            n("자기 전에 알림이 하나 왔다."),
            photo("street", "안 지워진 화면", "아직 안 지웠어"),
            wait(5),
            them("지울까 말까"),
        ],
        [
            n("다음 날 아침. 사진이 먼저 왔다."),
            photo("street", "어제의 그 화면", "나 이거 왜 갖고 있지"),
            wait(4),
            them("네가 정해"),
        ],
    ],
    "mo_fail_drunk_replay": [
        [
            n("오후 2시에 눈을 떴다. 단톡 알림 스물한 개."),
            photo("night", "어제 그 자리 사진", "박제 완료 ㅋㅋㅋ", name="준호"),
            them("네가 제일 많이 나와", "준호"),
        ],
        [
            n("다음 날. 준호가 먼저 사진을 보냈다."),
            photo("night", "어제 그 테이블", "이거 봐도 돼?", name="준호"),
            them("보고 나면 하루가 길어질 거야", "준호"),
        ],
    ],
    "mo_fail_stranger_saw": [
        [
            n("두 시간 뒤. 모르는 번호로 톡이 왔다."),
            them("아까 저 쪽 보고 계셨죠?", "모르는 번호"),
            wait(4),
            them("눈이 세 번 마주쳤어요 ㅋㅋ", "모르는 번호"),
        ],
        [
            n("밤 11시. 저장 안 된 번호."),
            them("아까 하려던 말 있으셨어요?", "모르는 번호"),
            wait(5),
            them("지금 들어도 되는데요", "모르는 번호"),
        ],
    ],
    "mo_fail_intro_capture": [
        [
            n("이틀 뒤. 준호가 링크 대신 사진을 보냈다."),
            photo("street", "캡처의 캡처", "세 번째 방에서 받았어", name="준호"),
            them("원본이 어디서 나온 건지는 아무도 몰라", "준호"),
        ],
        [
            n("준호가 사진 한 장을 보내고 바로 읽음만 남겼다."),
            photo("street", "단톡 한 줄 캡처", "너 맞지?", name="준호"),
            them("아니라고 하면 내가 아니라고 해 줄게", "준호"),
        ],
    ],
    "mo_fail_mirror_shot": [
        [
            n("현관 거울 앞. 각도를 세 번 바꿔 찍었다."),
            photo("selfie", "세 번째 각도", "이게 제일 나은 거야", who="me"),
            wait(5),
            them("진짜 이게 제일 나아?", "준호"),
        ],
        [
            n("방에 들어와 불을 켜고, 한 장 찍어 보냈다."),
            photo("selfie", "형광등 아래 오늘", "봐 줘", who="me"),
            wait(4),
            them("음", "준호"),
        ],
    ],
    "mo_fail_half_sent": [
        [
            n("버스에서 폰이 울렸다. 송금 알림이다."),
            photo("ticket", "송금 알림 한 줄", "정확히 반", name=TOP),
            them("계산기까지 썼어", TOP),
        ],
        [
            n("집 앞에서 알림을 봤다."),
            photo("ticket", "입금 내역 한 줄", "이건 내 몫", name=TOP),
            them("다음은 내가 정할게. 싼 데로", TOP),
        ],
    ],
    "mo_fail_misread": [
        [
            n("밤에 사진 한 장이 왔다. 글은 없다."),
            photo("street", "불 꺼진 가게 앞", name=TOP),
            wait(6),
            them("그냥. 여기 지나가서", TOP),
        ],
        [
            n("두 시간 동안 아무 말 없다가 사진만 왔다."),
            photo("food", "다 식은 밥 한 그릇", name=TOP),
            wait(6),
            them("아까는 말이 잘 안 됐어", TOP),
        ],
    ],
    "mo_fail_late_dawn": [
        [
            n("쓰고 지우고 쓰는 동안 위에 줄이 두 개 더 올라왔다."),
            them("아 바쁘구나", TOP),
            wait(8),
            photo("night", "새벽 두 시 길", "이거 지금밖에 못 봐", name=TOP),
        ],
        [
            n("입력창을 비우자마자 새 줄이 떴다."),
            them("됐어 자", TOP),
            wait(7),
            photo("sky", "구름 없는 밤하늘", "혼자 봤다", name=TOP),
        ],
    ],
    "mo_fail_call_cut": [
        [
            n("통화가 끊겼다. 다시 걸까 하는 동안 사진이 왔다."),
            photo("game", "부재중 표시 두 개", "내가 두 번 걸었어", name=TOP),
            them("근데 이번엔 글로 하자", TOP),
        ],
        [
            n("마지막 말이 반쯤 끊겼다. 화면에 사진이 떴다."),
            photo("game", "통화 기록 47초", "47초 동안 무슨 말을 한 거지", name=TOP),
            them("천천히 써 줘도 돼", TOP),
        ],
    ],
    "mo_fail_meme_missed": [
        [
            n("보내기를 누른 순간, 위에 다른 짤이 올라와 있었다."),
            photo("game", "0.4초 차이", "한 발 늦었네"),
            them("타이밍은 연습이 안 돼"),
        ],
        [
            n("내 짤 위에 이미 세 개가 쌓였다."),
            photo("game", "묻혀 버린 내 짤", "나는 네 것도 봤어"),
            them("아무도 안 봤지만 내가 봤어"),
        ],
    ],
}

for _ev in AFTERMATH:
    _v = AFTERMATH_VARIANTS[_ev["id"]]
    _base_photo = any("photo" in l for l in _ev["lines"])
    for _s in _v:
        assert any("photo" in l for l in _s) == _base_photo, _ev["id"]
    _ev["variants"] = [{"lines": s} for s in _v]


# --- 2. failNext 46개 --------------------------------------------------------
# (파일, 이벤트 id, 선택지 인덱스) → 뒷일 장면 id.
# 픽션이 맞는 자리에만 걸었다. 안 건 자리는 모듈 주석 참고.
FAIL_NEXT: dict[str, list[tuple[str, str, int]]] = {
    "mo_fail_capture": [
        ("events_daily.json", "d_kakao_01", 0),   # 서연 방 오발송, 5초 삭제 실패
        ("events_daily.json", "d_kakao_02", 0),   # 회사 단톡 오발송, 삭제 실패
    ],
    "mo_fail_drunk_replay": [
        ("events_daily.json", "d_drink_01", 0),   # MT 진실게임, 선을 넘은 드립
        ("events_daily.json", "d_drink_02", 2),   # 텐션 관리 두 번 더
        ("events_daily.json", "d_drink_03", 0),   # 선배의 마이크
        ("events_daily.json", "d_drink_06", 0),   # 2차에 남기
    ],
    "mo_fail_stranger_saw": [
        ("events_daily.json", "d_open_hello", 0),  # 옆자리에 먼저 인사
        ("events_daily.json", "d_meet_02", 0),     # 옆 테이블에 말 걸기
    ],
    "mo_fail_intro_capture": [
        ("events_daily.json", "d_open_groupchat", 0),  # 단톡 자기소개
        ("events_daily.json", "d_fu_lurker", 0),       # 눈팅 호명, 지금이라도 한 줄
    ],
    "mo_fail_mirror_shot": [
        ("events_daily.json", "d_misc_02", 2),      # 미용실 '알아서 해주세요'
        ("events_daily.json", "d_misc_03", 2),      # 3년 만의 옷
        ("events_daily.json", "d_open_outfit", 0),  # 옷장 앞 20분
        ("events_special.json", "h_mirror_again", 2),  # 다시 거울 앞에서
    ],
    "mo_fail_half_sent": [
        ("events_daily.json", "d_date_01", 0),
        ("events_daily.json", "d_date_04", 0),
        ("events_daily.json", "d_two_04", 1),
        ("events_route_a.json", "haneul_r09", 0),
        ("events_route_a.json", "jiwoo_r05", 0),
        ("route_daeun.json", "daeun_r09", 0),
        ("route_seunghyun.json", "seunghyun_r01", 0),
    ],
    "mo_fail_misread": [
        ("events_daily.json", "d_drink_04", 1),
        ("events_route_a.json", "jiwoo_r06", 0),
        ("route_geonwoo.json", "geonwoo_r06", 0),
        ("route_jeongwoo.json", "jeongwoo_r05", 0),
        ("route_sohee.json", "sohee_r03", 0),
        ("events_route_b.json", "doyun_r06", 0),
        ("route_seunghyun.json", "seunghyun_r04", 0),
    ],
    "mo_fail_late_dawn": [
        ("events_daily.json", "d_kakao_03", 0),
        ("events_daily.json", "d_kakao_05", 0),
        ("events_daily.json", "d_kakao_06", 0),
        ("events_route_a.json", "seoyeon_r15", 0),
        ("route_jeongwoo.json", "jeongwoo_r15", 0),
        ("events_route_a.json", "jiwoo_r07", 0),
        ("route_seunghyun.json", "seunghyun_r07", 0),
    ],
    "mo_fail_call_cut": [
        ("events_daily.json", "d_kakao_08", 0),
        ("events_route_b.json", "minjae_r11", 0),
        ("route_sohee.json", "sohee_r10", 0),
        ("route_seunghyun.json", "seunghyun_r08", 1),
        ("events_route_a.json", "jiwoo_r08", 1),
        ("route_geonwoo.json", "geonwoo_r07", 0),
    ],
    "mo_fail_meme_missed": [
        ("events_daily.json", "d_open_meme", 0),
        ("events_route_a.json", "haneul_r10", 0),
        ("route_daeun.json", "daeun_r05", 0),
        ("events_route_b.json", "yeeun_r08", 1),
        ("events_route_a.json", "jiwoo_r04", 0),
    ],
}


# --- 3. 실패에 적는 관계 이동 22곳 -------------------------------------------
# (파일, id, 선택지) → fail.affection. 이유는 세 갈래다(모듈 주석 §3).
FAIL_AFFECTION: list[tuple[str, str, int, dict, str]] = [
    # (가) 상대가 보는 실패 — 술자리에서 선을 넘거나, 단톡에서 못 막았다.
    ("events_daily.json", "d_drink_06", 0, {"@top": -1}, "같은 드립 세 번, 그 사람이 옆에 있었다"),
    ("events_daily.json", "d_friend_06", 0, {"@top": -1}, "뒷담화를 못 막았고 그 방을 본인이 본다"),
    ("events_route_a.json", "seoyeon_r03", 0, {"*": -1}, "선배 앞에서 주량을 넘겼다"),
    ("events_route_b.json", "yeeun_r01", 1, {"*": -1}, "첫 술자리에서 선을 넘었다"),
    ("route_sohee.json", "sohee_r02", 1, {"*": -1}, "같은 자리에서 주량을 넘겼다"),
    ("events_route_b.json", "minjae_r05", 1, {"*": -1}, "단톡에서 본인 얘기를 놓쳤다"),
    ("events_route_b.json", "yeeun_r12", 0, {"*": -1}, "단톡에서 본인 얘기를 놓쳤다"),
    ("events_route_b.json", "yeeun_r14", 1, {"*": -1}, "단톡에서 본인 얘기를 놓쳤다"),
    ("route_geonwoo.json", "geonwoo_r14", 1, {"*": -1}, "단톡에서 본인 얘기를 놓쳤다"),
    # (나) 성공 보상이 큰 고백·편지 — 말은 꼬였어도 시도한 건 보인다. 전부 아니면 0 보다 낫다.
    ("events_daily.json", "d_twist_05", 1, {"yeeun": 2}, "성공 +10 · 20년 늦은 답장을 더듬더듬"),
    ("events_daily.json", "d_twist_05_m", 1, {"geonwoo": 2}, "성공 +10 · 쪽지에 더듬더듬 답한다"),
    ("events_route_a.json", "seoyeon_r09", 0, {"*": 1}, "성공 +6 · 말은 못 했지만 얼굴이 다 말했다"),
    ("route_jeongwoo.json", "jeongwoo_r09", 0, {"*": 1}, "성공 +6"),
    ("events_route_b.json", "minjae_r03", 0, {"*": 1}, "성공 +5"),
    ("route_daeun.json", "daeun_r10", 0, {"*": 1}, "성공 +8"),
    ("route_geonwoo.json", "geonwoo_r01", 1, {"*": 1}, "성공 +4"),
    ("events_route_b.json", "yeeun_r09", 0, {"*": 2}, "성공 +9"),
    ("route_geonwoo.json", "geonwoo_r09", 0, {"*": 2}, "성공 +9"),
    ("route_geonwoo.json", "geonwoo_r12", 0, {"*": 2}, "성공 +8"),
    ("events_route_b.json", "doyun_r08", 2, {"*": 1}, "성공 +7"),
    ("events_route_b.json", "minjae_r11", 0, {"*": 2}, "성공 +10 · 통화가 꼬여도 걸었다는 건 남는다"),
    ("events_route_a.json", "haneul_r10", 0, {"*": 1}, "성공 +8"),
]


DRY = "--dry" in sys.argv
problems: list[str] = []
files: dict[str, list] = {}
index: dict[str, dict] = {}


def load(name: str) -> None:
    if name in files:
        return
    files[name] = story_io.load(name)
    for e in files[name]:
        index[e["id"]] = e


for name in {f for v in FAIL_NEXT.values() for f, _, _ in v} | {f for f, *_ in FAIL_AFFECTION}:
    load(name)
load("events_moments.json")

# 1. 뒷일 장면 추가
added = 0
for ev in AFTERMATH:
    if ev["id"] in index:
        problems.append(f"이미 있는 id: {ev['id']}")
        continue
    files["events_moments.json"].append(ev)
    index[ev["id"]] = ev
    added += 1

# 2. failNext
edges = 0
for dest, srcs in FAIL_NEXT.items():
    for name, eid, ci in srcs:
        ev = index.get(eid)
        if ev is None:
            problems.append(f"없는 이벤트: {eid}")
            continue
        c = ev["choices"][ci]
        if not c.get("minigame"):
            problems.append(f"{eid} choices[{ci}] 에 미니게임이 없다")
            continue
        if c.get("failNext"):
            problems.append(f"{eid} choices[{ci}] 에 이미 failNext 가 있다")
            continue
        c["failNext"] = dest
        edges += 1

# 3. 실패의 관계 이동
affs = 0
for name, eid, ci, aff, _why in FAIL_AFFECTION:
    ev = index.get(eid)
    if ev is None:
        problems.append(f"없는 이벤트: {eid}")
        continue
    c = ev["choices"][ci]
    if not c.get("minigame"):
        problems.append(f"{eid} choices[{ci}] 에 미니게임이 없다")
        continue
    fl = c.setdefault("fail", {})
    if fl.get("affection"):
        problems.append(f"{eid} choices[{ci}] 실패에 이미 affection 이 있다: {fl['affection']}")
        continue
    fl["affection"] = aff
    affs += 1

if problems:
    print("멈춤 — 파일을 쓰지 않았다.")
    for p in problems:
        print("  !", p)
    raise SystemExit(1)

vsets = sum(len(v) for v in AFTERMATH_VARIANTS.values())
print(f"뒷일 장면 {added}개(변형 {vsets}벌) · failNext {edges}개 · 실패 관계 이동 {affs}곳")
if DRY:
    print("(--dry: 파일을 쓰지 않았다)")
else:
    for name, data in files.items():
        story_io.save(name, data)
    print("저장:", ", ".join(sorted(files)))
