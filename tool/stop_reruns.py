#!/usr/bin/env python3
"""재방송·시간역행·무명 선택지 수선 (docs/review/11_story_verdict.md §4-1·4-5·4-6).

네 가지를 한 번에 한다. 전부 **문장이 정확히 일치할 때만** 바꾸고,
하나라도 못 찾으면 파일을 쓰지 않고 멈춘다(`tool/name_the_top.py` 와 같은 규칙).

1. `once` 재배치 — 자기 대본이 "처음"·"바뀐다"라고 말하는 일상 12개를 `once: true` 로,
   상황이 실제로 반복되는 중립 일상 11개를 새로 `once: false` 로(반복 풀 25 → 24).
2. 뒤 메인이 도입하는 사실을 앞당겨 쓰던 장면 게이트(뒤풀이 4·SNS 첫 디엠 2·소개팅 앱 1)
   와 대사 재작성 3(준호 여친·태현 무면허·뒤풀이 정류장).
3. 선택 시점에 상대를 알 수 없던 선택지 6개에 지목 문장·선택지 문구.
4. 반복이 앞뒤 안 맞던 네 줄 손질(국밥·월급날·노래방·새벽 운동).

사용: python3 tool/stop_reruns.py [--dry]
"""

from __future__ import annotations

import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])

import story_io  # noqa: E402

# --- 1. once 재배치 -------------------------------------------------------

# 자기 대본이 1회성이라고 말하는 것. 두 번째 재생이 픽션과 어긋난다.
ONCE_TRUE = {
    "d_meet_01": "같은 층 이웃과 '처음' 인사한다",
    "d_meet_03": "앱 첫 매칭 · 자기소개를 다시 쓴다",
    "d_sns_01": "그 새벽의 스토리 다섯 개 + 다음 날 DM",
    "d_sns_01_m": "'3주 만에' 올라온 스토리",
    "d_sns_03": "프사를 노을로 바꾼다(고정 사실 변경)",
    "d_misc_01": "MBTI 첫 공표 · fake_e(고정 사실)",
    "d_misc_03": "'3년 만에' 옷을 산다",
    "d_work_02": "조별과제를 끝낸다 · '다음 조별과제도 같이 해요'",
    "d_temp_04": "small_lie(고정 사실) · 그 거짓말 하나",
    "d_family_03": "엄마 검열로 프사가 바뀐다(고정 사실)",
    "d_friend_01": "played_games(고정 사실) · 사흘 잠수",
    "d_friend_02": "준호의 놀이공원 사진 50장 · '아직 38장 남았는데'",
}

# 상황이 실제로 되풀이되는 것. 두 번째 재생이 픽션과 어긋나지 않는다.
ONCE_FALSE = {
    "d_kakao_05": "오타 답장 대참사",
    "d_kakao_07": "새벽 감성 메시지 앞에서 망설인다",
    "d_meet_02": "준호가 끌고 간 자리, 옆 테이블",
    "d_meet_07": "도서관 옆자리 포스트잇",
    "d_date_02": "막차 20분 전",
    "d_date_04": "계산서가 예상의 두 배",
    "d_date_05": "사진을 다시 찍어 달란다",
    "d_friend_06": "단톡방에서 그 사람 얘기가 나온다",
    "d_work_01": "회식 자리의 '애인 없냐'",
    # 스트레스 배출 쪽 둘. 버킷 A 로 닫은 12개가 전부 스트레스 중립이라 남은 풀이
    # 스트레스 쪽으로 기울었다(실측: D+100 평균 49 → 68). 이 둘로 되돌린다.
    "d_luck_04": "단골 국밥집 사장님의 계란 (스트레스 -18)",
    "d_work_03": "발표가 끝나고 박수 (스트레스 -3)",
    "d_date_03": "비, 우산 하나 (이미 false — 유지)",
    # 월급날은 100일에 세 번 오는 게 사실이고, 이 게임의 유일한 돈 수도꼭지다.
    # once:true 로 돌려 보니 D+100 평균 잔고가 222 → 0, c_money_fight 가 71 → 104 로 늘었다
    # (tool/sim_out/sim_balance_report.txt 로 실측). 그래서 반복으로 두고 1회성 문장만 고쳤다.
    "d_work_06": "월급날 (이미 false — 유지, 경제 수도꼭지)",
    # 국밥은 이 게임의 스트레스 배출 밸브다(-12 분기). once:true 로 돌려 보니
    # D+100 스트레스 평균이 49 → 68, c_burnout 이 464 → 587 로 늘었다. 반복으로 두고
    # 1회성 문장(준호 "너 이제 그런 사이야?")만 고쳤다.
    "d_drink_05": "아침 국밥 (이미 false — 유지, 스트레스 배출 밸브)",
}

# --- 2. 게이트 ------------------------------------------------------------

# m07(D+17, 동아리 '첫' 뒤풀이)이 club_afterparty 를 세운다. 그 전에는 나올 수 없다.
CLUB_GATE = ["d_drink_01", "d_drink_02", "d_drink_03", "d_drink_06"]

# m06/m06_m(D+14, '첫 디엠')보다 먼저 그 사람 스토리를 보고 DM 을 받던 것.
DAY_MIN = {"d_sns_01": 15, "d_sns_01_m": 15, "d_meet_03": 24}

# --- 3~4. 문장 교체 -------------------------------------------------------
# (파일, 이벤트, 경로, 전, 후). 경로는 아래 _get/_set 이 읽는다.
EDITS: list[tuple[str, str, str, str, str]] = [
    # --- d_fu_taehyun: m37(D+95 태현의 고백)의 핵심 문장을 D+20에 미리 말하고 있었다.
    (
        "events_daily.json",
        "d_fu_taehyun",
        "choices[0].reply[0].text",
        "…나 한 번도 안 해봤어",
        # wait 다음 줄은 "…" 로 시작하지 않는다(tool/voice_rules.json afterWait) —
        # 기준선에 있던 위반 1건도 여기서 같이 사라진다.
        "그 조언들 어디서 났냐면 말이야",
    ),
    (
        "events_daily.json",
        "d_fu_taehyun",
        "choices[0].reply[1].text",
        "코치가 무면허였다 ㅋㅋ 이제 알았지",
        "아니다. 그건 나중에. 하나만 말하면 나 무면허야",
    ),
    (
        "events_daily.json",
        "d_fu_taehyun",
        "choices[0].reply[2].text",
        "조언 절반이 왜 위험했는지 이제 알 것 같다.",
        "무엇이 무면허인지는 말하지 않았다. 조언 절반이 왜 위험했는지는 알 것 같다.",
    ),
    # --- 반복이 앞뒤 안 맞던 네 줄
    (
        "events_daily.json",
        "d_drink_05",
        "choices[2].reply[0].text",
        "? 너 이제 그런 사이야?",
        "? 국밥집에 그 사람을 부른다고?",
    ),
    (
        "events_daily.json",
        "d_work_06",
        "choices[0].reply[0].text",
        "통장 이름을 '데이트 자금'으로 바꾸는 데 5분 걸렸다.",
        "'데이트 자금' 통장에 이번 달 몫을 옮겼다. 숫자가 조금 든든해졌다.",
    ),
    (
        "events_daily.json",
        "d_date_07",
        "choices[1].text",
        "발라드에 도전한다",
        "다른 노래에 도전한다",
    ),
    (
        "events_daily.json",
        "d_misc_05",
        "choices[2].reply[0].text",
        "알람을 지웠다. '매일 05:30' 반복 설정까지 전부.",
        "알람을 지웠다. 반복 설정까지 전부. 그러고는 다음 주 월요일로 하나를 새로 맞췄다.",
    ),
    # --- 무명 선택지 6개: 선택지 문구
    (
        "events_daily.json",
        "d_meet_03",
        "choices[0].text",
        "신중하게 고른다",
        "그 분위기 쪽으로 신중하게 고른다",
    ),
    (
        "events_daily.json",
        "d_meet_05",
        "choices[2].text",
        "선배가 해 줬던 대로 한다",
        "문가의 선배가 해 줬던 대로 한다",
    ),
    (
        "events_daily.json",
        "d_friend_04",
        "choices[0].text",
        "좋아요",
        "좋아요. 소개는 소개니까",
    ),
    (
        "events_daily.json",
        "d_family_02",
        "choices[1].text",
        "조언을 구한다",
        "그 동창 얘기를 꺼내며 조언을 구한다",
    ),
    (
        "events_daily.json",
        "d_work_04",
        "choices[0].text",
        "만나본다",
        "그래도 만나본다",
    ),
    (
        "events_daily.json",
        "d_temp_05",
        "choices[1].text",
        "계속 계산한다",
        "전부에게 똑같이 답한다",
    ),
    # --- 뒤 메인이 도입하는 사실을 앞당겨 쓰던 대사 2
    (
        "events_route_a.json",
        "haneul_r14",
        "lines[0].text",
        "준호가 여친을 데리고 카페에 왔다.",
        "준호가 과 친구 둘을 데리고 카페에 왔다.",
    ),
    (
        "events_special.json",
        "c_drunk_confession",
        "lines[0].text",
        "동아리 뒤풀이가 새벽에 끝났다. 막차는 방금 떠났다.",
        "술자리가 새벽에 끝났다. 막차는 방금 떠났다.",
    ),
]

# 선택 시점에 상대를 지목하는 지문. (이벤트, 넣을 자리 index, 문장)
NARR_INSERTS: list[tuple[str, int, str]] = [
    ("d_meet_03", 1, "손이 한 프로필에서 멈췄다. 엄마가 밀던 그 사람과 분위기가 비슷하다."),
    ("d_meet_05", 2, "문가에 동아리 선배가 서 있다. 내 말투를 가르쳐 준 사람이다."),
    ("d_friend_04", 2, "소개라는 말에 엄마가 밀던 그 사람 이름이 먼저 떠올랐다."),
    ("d_family_02", 3, "아빠가 갑자기 6학년 얘기를 꺼냈다. 우유 사건, 그 동창."),
    ("d_work_04", 2, "과장이 사진을 내민다. 소개라는 말에 엄마가 밀던 그 사람이 먼저 떠올랐다."),
]


# --- 실행 ----------------------------------------------------------------


class Stop(Exception):
    pass


def _walk(ev, path: str):
    """`choices[0].reply[1].text` 같은 경로의 (담을 것, 키) 를 돌려준다."""
    node = ev
    parts = path.split(".")
    for p in parts[:-1]:
        if "[" in p:
            name, idx = p[:-1].split("[")
            node = node[name][int(idx)]
        else:
            node = node[p]
    last = parts[-1]
    if "[" in last:
        name, idx = last[:-1].split("[")
        return node[name], int(idx)
    return node, last


def main(argv) -> int:
    dry = "--dry" in argv
    files = {}

    def load(name):
        if name not in files:
            files[name] = story_io.load(name)
        return files[name]

    daily = load("events_daily.json")
    by = story_io.by_id(daily)
    log: list[str] = []

    # 1. once
    for eid, why in ONCE_TRUE.items():
        e = by.get(eid) or _missing(eid)
        if e.get("once") is True:
            log.append(f"once:true  {eid:14s} (이미 true) {why}")
            continue
        if e.get("once") is not False:
            # 키가 아예 없으면 기본값이 true 다 — 내가 세웠다고 착각하면 안 된다.
            raise Stop(f"{eid}: once 키가 없다(기본 true) — 전제가 바뀌었다")
        e["once"] = True
        log.append(f"once:true  {eid:14s} {why}")
    for eid, why in ONCE_FALSE.items():
        e = by.get(eid) or _missing(eid)
        if e.get("once") is False:
            log.append(f"once:false {eid:14s} (이미 false) {why}")
            continue
        if "once" in e:
            raise Stop(f"{eid}: 이미 once={e['once']!r} — 전제가 바뀌었다")
        # 새 키는 weight 뒤에(d_open_* 와 같은 자리).
        items = list(e.items())
        e.clear()
        for k, v in items:
            e[k] = v
            if k == "weight":
                e["once"] = False
        if "once" not in e:
            e["once"] = False
        log.append(f"once:false {eid:14s} {why}")

    # 2. 게이트
    for eid in CLUB_GATE:
        e = by.get(eid) or _missing(eid)
        t = e.setdefault("trigger", {})
        flags = t.setdefault("flags", [])
        if "club_afterparty" in flags:
            log.append(f"gate       {eid:14s} (이미 있음)")
            continue
        flags.append("club_afterparty")
        log.append(f"gate       {eid:14s} flags += club_afterparty  (m07 D+17)")
    for eid, dmin in DAY_MIN.items():
        e = by.get(eid) or _missing(eid)
        day = e["trigger"]["day"]
        if day[0] == dmin:
            log.append(f"day        {eid:14s} (이미 {dmin})")
            continue
        log.append(f"day        {eid:14s} {day[0]} → {dmin}")
        day[0] = dmin

    # 3. 지문 삽입
    for eid, at, text in NARR_INSERTS:
        e = by.get(eid) or _missing(eid)
        lines = e["lines"]
        if any(l.get("text") == text for l in lines):
            log.append(f"narr       {eid:14s} (이미 있음)")
            continue
        if at > len(lines):
            raise Stop(f"{eid}: lines 가 {len(lines)}개뿐인데 {at} 자리에 넣으라고 한다")
        lines.insert(at, {"who": "narr", "text": text})
        log.append(f"narr       {eid:14s} lines[{at}] += {text[:28]}…")

    # 4. 문장 교체
    for fname, eid, path, before, after in EDITS:
        data = load(fname)
        e = story_io.by_id(data).get(eid)
        if e is None:
            raise Stop(f"{fname}: {eid} 가 없다")
        holder, key = _walk(e, path)
        cur = holder[key]
        if cur == after:
            log.append(f"text       {eid:14s} {path} (이미 바뀜)")
            continue
        if cur != before:
            raise Stop(f"{fname}:{eid}.{path}\n  기대: {before!r}\n  실제: {cur!r}")
        holder[key] = after
        log.append(f"text       {eid:14s} {path}")

    print("\n".join(log))
    print(f"\n총 {len(log)}건 · 파일 {len(files)}개")
    if dry:
        print("(--dry: 쓰지 않았다)")
        return 0
    for name, data in files.items():
        story_io.save(name, data)
    print("썼다: " + ", ".join(sorted(files)))
    return 0


def _missing(eid):
    raise Stop(f"events_daily.json: {eid} 가 없다")


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except Stop as exc:
        print(f"멈춤 — 아무것도 쓰지 않았다\n  {exc}", file=sys.stderr)
        sys.exit(1)
