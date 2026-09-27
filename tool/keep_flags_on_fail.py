"""실패해도 "그 일은 일어났다" 는 플래그는 남긴다.

`EventEngine.applyChoice` 는 실패 분기에서 `c.fail` 만 적용하고
`c.effects.setFlags` 를 건너뛴다(`event_engine.dart:474`). 그래서 확률이나
미니게임이 붙은 선택지에서 지면, **장면은 겪었는데 겪은 적 없는 사람**이 된다.

실측(docs/review/11_claims_audit.md): `m07` 의 "자기소개를 한다"(미니게임)와
"안주만 먹는다"(확률 60)가 지면 `club_afterparty` 가 안 서고, 무작위 200회차 중
50회차(25%)가 서연 장면 2편(`seoyeon_r03`·`seoyeon_r14`)을 영구히 잃었다.

여기서 옮기는 것은 **성공 여부와 무관하게 일어난 사실**뿐이다.
빠뜨린 둘은 의도적이다 —
  * `stranger_laugh` (모르는 사람이 웃어 줬다) : 실패하면 안 웃은 것이 맞다
  * `seoyeon_banmal` (반말하기로 했다)        : 실패하면 서연이 안 받아 준 것이 맞다

다시 돌려도 안전하다.
"""

from __future__ import annotations

import story_io

# (파일, 이벤트 id, 선택지 번호, 실패해도 남겨야 할 플래그)
KEEP = [
    ("events_main.json", "m07", 0, "club_afterparty"),   # 뒤풀이에 간 건 사실
    ("events_main.json", "m07", 2, "club_afterparty"),
    ("events_main.json", "m08", 0, "junho_yeeun"),       # 준호가 말을 꺼낸 건 사실
    ("events_main.json", "m08_m", 0, "junho_geonwoo"),
    ("events_main.json", "m35", 0, "best_man"),          # 하겠다고 답한 건 사실
    ("events_main.json", "m37", 0, "taehyun_truth"),     # 태현이 털어놓은 건 사실
    ("events_daily.json", "d_open_app_match", 0, "app_installed"),  # 앱은 깔려 있다
    ("events_route_b.json", "yeeun_r07", 0, "told_junho"),          # 말한 건 사실
    ("route_geonwoo.json", "geonwoo_r07", 0, "told_junho"),
]


def main() -> None:
    files = {name: story_io.load(name) for name, *_ in KEEP}
    changed = skipped = 0
    for name, eid, idx, flag in KEEP:
        hits = [e for e in files[name] if isinstance(e, dict) and e.get("id") == eid]
        if len(hits) != 1:
            raise SystemExit(f"{eid}: {name} 에 {len(hits)}개 — 정확히 하나여야 한다")
        choice = hits[0]["choices"][idx]
        if choice.get("chance") is None and choice.get("minigame") is None:
            raise SystemExit(f"{eid}[{idx}]: 질 수 없는 선택지라 옮길 이유가 없다")
        if flag not in (choice.get("effects") or {}).get("setFlags", []):
            raise SystemExit(f"{eid}[{idx}]: 성공 쪽에 {flag} 가 없다")
        fail = choice.setdefault("fail", {})
        flags = fail.setdefault("setFlags", [])
        if flag in flags:
            skipped += 1
            continue
        flags.append(flag)
        changed += 1
        print(f"  {eid}[{idx}]  fail.setFlags += {flag}")

    for name, events in files.items():
        story_io.save(name, events)
    print(f"옮긴 곳 {changed} · 이미 되어 있던 곳 {skipped}")


if __name__ == "__main__":
    main()
