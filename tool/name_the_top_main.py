#!/usr/bin/env python3
"""메인 줄기의 `@top` 장면이 상대 이름을 부르게 고친다 (docs/review/08_story_delivery.md §1.5).

고백·라이벌·첫 싸움·화해·권태·마지막 선택 — 100일 서사의 클라이맥스 9개가
호감 1위에게 호감을 주면서 대사에서는 "상대"·"그 사람" 이라고만 불렀다.
`tool/name_the_top.py` 와 같은 방식(정확히 일치하는 문장만 교체)으로 고친다.

    python3 tool/name_the_top_main.py
"""

from __future__ import annotations

import sys

sys.path.insert(0, __file__.rsplit("/", 1)[0])

import story_io  # noqa: E402
from name_the_top import _apply  # noqa: E402

MOMENTS: dict[str, list[tuple[str, str]]] = {
    "mo_daily_taehyun_story": [
        ("야 이거 봤냐? 그 사람 스토리", "야 이거 봤냐? {top} 스토리"),
        ("근데 그 사람이 제일 먼저 봤다. 조회 목록 1번", "근데 {top|이가} 제일 먼저 봤다. 조회 목록 1번"),
        (
            "그날 밤, 그 사람의 스토리가 하나 더 올라왔다. 이번엔 커피가 한 잔이었다.",
            "그날 밤 {top} 스토리가 하나 더 올라왔다. 이번엔 커피가 한 잔이었다.",
        ),
    ],
}

MAIN: dict[str, list[tuple[str, str]]] = {
    "m19": [
        ("퇴근길 폭우. 우산은 하나. 상대는 우산이 없다.", "퇴근길 폭우. 우산은 하나. {top|은는} 우산이 없다."),
        ("괜찮다고, 뛰어가겠다고 한다.", "{top|은는} 괜찮다고, 뛰어가겠다고 한다."),
        ("상대는 빗속으로 뛰어갔다. 우산 하나가 너무 넓었다.", "{top|은는} 빗속으로 뛰어갔다. 우산 하나가 너무 넓었다."),
        (
            "편의점에서 샀냐고, 이런 센스는 어디서 났냐고 했다.",
            "{top|이가} 편의점에서 샀냐고, 이런 센스는 어디서 났냐고 했다.",
        ),
    ],
    "m21": [
        ("지금 내 확률은 몇 퍼센트일까.", "{top}한테 지금 내 확률은 몇 퍼센트일까."),
        ("지금 한다", "지금 {top}한테 말한다"),
        ("진짜냐고 되물었다.", "{top|이가} 진짜냐고 되물었다."),
        ("자기도 언제 말하나 기다렸다고 했다.", "{top}도 언제 말하나 기다렸다고 했다."),
        ("상대가 먼저 말하게 유도", "{top|이가} 먼저 말하게 유도"),
    ],
    "m22": [
        ("상대의 SNS에 모르는 사람이 나온다. 같이 찍은 사진이다.", "{top} SNS에 모르는 사람이 나온다. 같이 찍은 사진이다."),
        ("사촌이라고 했다.", "{top|은는} 사촌이라고 했다."),
    ],
    "m26": [
        ("요즘 나한테 관심 없는 것 같다는 톡이 왔다.", "{top}한테서 톡. 요즘 나한테 관심 없는 것 같다고."),
        ("어제 세 번 물어봤는데 다 단답이었다고 했다.", "{top|이가} 어제 세 번 물어봤는데 다 단답이었다고 했다."),
        ("알았다고 했다. 자기도 좀 예민했다고.", "{top|이가} 알았다고 했다. 자기도 좀 예민했다고."),
    ],
    "m27": [
        (
            "그 뒤로 사흘, 대화가 줄었다. 뭐라고 보낼지 세 시간을 고민했다.",
            "{top|과와} 사흘, 대화가 줄었다. 뭐라고 보낼지 세 시간을 고민했다.",
        ),
        ("먼저 왔다.", "{top} 답이 먼저 왔다."),
        ("자기도 말이 심했다고 했다.", "{top}도 말이 심했다고 했다."),
    ],
    "m29": [
        ("물어볼게", "{top}한테 물어볼게"),
    ],
    "m30": [
        ("매일 같은 대화. 밥 먹었어, 뭐해, 자자.", "{top|과와} 매일 같은 대화. 밥 먹었어, 뭐해, 자자."),
        ("갑자기 뭐냐고 하면서도 좋다고 했다.", "{top|이가} 갑자기 뭐냐고 하면서도 좋다고 했다."),
        ("사실 자기도 그 생각을 했다고 했다.", "{top}도 사실 그 생각을 했다고 했다."),
    ],
    "m36": [
        ("8일 남았다.", "8일 남았다. 머릿속에 {top} 이름 하나가 남았다."),
        ("고백한다", "{top}한테 고백한다"),
        ("관계를 정리한다", "{top|과와} 정리한다"),
        ("같은 마음이었다고 했다.", "{top}도 같은 마음이었다고 했다."),
    ],
    "m40": [
        ("가장 가까운 사람에게 연락한다", "{top}한테 연락한다"),
        ("갑자기 왜 그러냐는 답이 왔다.", "{top}한테서 답. 갑자기 왜 그러냐고."),
    ],
}


def run(filename: str, table: dict[str, list[tuple[str, str]]]) -> tuple[int, list[str]]:
    events = story_io.load(filename)
    index = story_io.by_id(events)
    missing, changed = [], 0
    for eid, pairs in table.items():
        ev = index.get(eid)
        if ev is None:
            missing.append(f"{eid}: 이벤트 없음")
            continue
        hits = _apply(ev, pairs)
        for old, n in hits.items():
            if n == 0:
                missing.append(f'{eid}: 못 찾음 "{old}"')
        changed += sum(hits.values())
    if not missing:
        story_io.save(filename, events)
    return changed, missing


def main() -> int:
    total, problems = 0, []
    for filename, table in (("events_moments.json", MOMENTS), ("events_main.json", MAIN)):
        changed, missing = run(filename, table)
        total += changed
        problems += missing
    if problems:
        print("멈춤 — 바꿀 대상을 못 찾았다:", file=sys.stderr)
        for p in problems:
            print("  " + p, file=sys.stderr)
        return 1
    print(f"메인·모먼트 {len(MAIN) + len(MOMENTS)}개 · {total}곳을 {{top}} 으로 고쳤다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
