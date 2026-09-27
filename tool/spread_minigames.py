"""초반 10일이 같은 미니게임만 내놓던 것을 흩는다.

근거와 측정은 docs/review/09_minigame_audit.md §3. 열 곳 중 여덟 곳은
"다양성" 이 아니라 **상황이 안 맞아서** 바꾸는 것이다 — 예를 들어
`seoyeon_r01` 은 지문이 "단톡이 아니라 개인톡이다" 라고 못 박는데
단톡방 미니게임이 붙어 있었다. 선택지 문구·효과는 건드리지 않는다.

다시 돌려도 안전하다(이미 바뀐 자리는 건너뛴다).
"""

from __future__ import annotations

import story_io

# (파일, 이벤트 id, 선택지 번호, 지금, 바꿀 것)
MOVES = [
    ("events_route_a.json", "seoyeon_r01", 0, "group_chat", "word_order"),
    ("events_route_a.json", "seoyeon_r00", 0, "group_chat", "reply_timing"),
    ("events_daily.json", "d_fu_lurker", 0, "group_chat", "word_order"),
    ("events_route_a.json", "jiwoo_r01", 0, "reply_timing", "word_order"),
    ("events_daily.json", "d_misc_01", 2, "group_chat", "drink_limit"),
    ("events_route_b.json", "yeeun_r01", 1, "group_chat", "drink_limit"),
    ("route_sohee.json", "sohee_r02", 1, "group_chat", "drink_limit"),
    ("events_main.json", "m04", 0, "outfit", "nerve_gauge"),
    ("events_daily.json", "d_fu_locked", 0, "profile_swipe", "read_emotion"),
    ("route_sohee.json", "sohee_r03", 0, "nerve_gauge", "read_emotion"),
]


def main() -> None:
    by_file: dict[str, list] = {}
    for name, *_ in MOVES:
        by_file.setdefault(name, [])
    for name in by_file:
        by_file[name] = story_io.load(name)

    changed, skipped = 0, 0
    for name, eid, idx, old, new in MOVES:
        events = by_file[name]
        hits = [e for e in events if isinstance(e, dict) and e.get("id") == eid]
        if len(hits) != 1:
            raise SystemExit(f"{eid}: {name} 에 {len(hits)}개 — 정확히 하나여야 한다")
        choice = hits[0]["choices"][idx]
        got = choice.get("minigame")
        if got == new:
            skipped += 1
            continue
        if got != old:
            raise SystemExit(f"{eid}.choices[{idx}]: {old} 인 줄 알았는데 {got}")
        choice["minigame"] = new
        changed += 1
        print(f"  {eid}.choices[{idx}]  {old} -> {new}")

    for name, events in by_file.items():
        story_io.save(name, events)
    print(f"바꾼 곳 {changed} · 이미 되어 있던 곳 {skipped}")


if __name__ == "__main__":
    main()
