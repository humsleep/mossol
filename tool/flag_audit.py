#!/usr/bin/env python3
"""플래그 감사 — assets/story/*.json 에서 세워지는 플래그와 읽히는 플래그를 대조한다.

읽는 곳: 이벤트/엔딩의 `trigger`·`when` 안 `flags`/`notFlags`/`flagsAtLeast.of`,
         선택지 `require` 안 같은 키, `signals.json` 의 `when.flags`/`when.notFlags`.
세우는 곳: 선택지 `effects.setFlags`/`fail.setFlags`(+`clearFlags`).

사용:
    python3 tool/flag_audit.py            # 요약
    python3 tool/flag_audit.py --dead     # 세워지지만 안 읽히는 것만
    python3 tool/flag_audit.py --ghost    # 읽히지만 아무 데서도 안 세워지는 것만
"""

from __future__ import annotations

import glob
import json
import os
import sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORY = os.path.join(ROOT, "assets", "story")

# 엔진이 직접 세우는 플래그(effects.dart:145-147). 데이터에 setFlags 가 없어도 살아 있다.
ENGINE_SET = {"album_10", "album_20", "album_30"}


def _cond_flags(cond, where, readers):
    if not isinstance(cond, dict):
        return
    for key in ("flags", "notFlags"):
        for f in cond.get(key) or []:
            readers[f].append(where)
    fc = cond.get("flagsAtLeast")
    if isinstance(fc, dict):
        for f in fc.get("of") or []:
            readers[f].append(where + ".flagsAtLeast")


def scan():
    setters: dict[str, list[str]] = defaultdict(list)
    readers: dict[str, list[str]] = defaultdict(list)

    for path in sorted(glob.glob(os.path.join(STORY, "*.json"))):
        base = os.path.basename(path)
        if base in ("characters.json", "config.json"):
            continue
        data = json.load(open(path, encoding="utf-8"))
        if base == "signals.json":
            _scan_signals(data, base, readers)
            continue
        if not isinstance(data, list):
            continue
        for e in data:
            eid = e.get("id", "?")
            where = f"{base}:{eid}"
            _cond_flags(e.get("trigger"), where + ".trigger", readers)
            _cond_flags(e.get("when"), where + ".when", readers)
            for i, c in enumerate(e.get("choices") or []):
                cw = f"{where}.choices[{i}]"
                _cond_flags(c.get("require"), cw + ".require", readers)
                for slot in ("effects", "fail"):
                    eff = c.get(slot) or {}
                    for f in eff.get("setFlags") or []:
                        setters[f].append(cw + f".{slot}")
                    for f in eff.get("clearFlags") or []:
                        setters[f].append(cw + f".{slot}(clear)")
    return setters, readers


def _scan_signals(data, base, readers):
    """signals.json 은 중첩 dict/list 가 섞여 있어 통째로 훑는다."""

    def walk(node, path):
        if isinstance(node, dict):
            if "when" in node:
                _cond_flags(node["when"], f"{base}:{path}.when", readers)
            for k, v in node.items():
                walk(v, f"{path}.{k}" if path else k)
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, f"{path}[{i}]")

    walk(data, "")


def main(argv):
    setters, readers = scan()
    dead = sorted(f for f in setters if f not in readers)
    ghost = sorted(f for f in readers if f not in setters and f not in ENGINE_SET)
    live = sorted(f for f in setters if f in readers)

    if "--dead" in argv:
        for f in dead:
            print(f"{f}\t{len(setters[f])}곳\t{', '.join(setters[f][:4])}")
        return 0
    if "--ghost" in argv:
        for f in ghost:
            print(f"{f}\t{len(readers[f])}곳\t{', '.join(readers[f][:4])}")
        return 0

    total = len(set(setters) | set(readers))
    print(f"플래그 총 {total}종")
    print(f"  세우고 읽는다      {len(live)}")
    print(f"  세우고 안 읽는다   {len(dead)}  (죽은 플래그)")
    print(f"  읽는데 안 세운다   {len(ghost)}  (유령 플래그)")
    if dead:
        print("\n[죽은 플래그]")
        for f in dead:
            print(f"  {f:28s} {len(setters[f])}곳")
    if ghost:
        print("\n[유령 플래그]")
        for f in ghost:
            print(f"  {f:28s} {len(readers[f])}곳  {readers[f][0]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
