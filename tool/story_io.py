"""assets/story/*.json 을 원래 서식(들여쓰기 1칸, 한글 그대로) 그대로 읽고 쓴다.

`signals.json` 만 끝에 줄바꿈이 있다. 그 차이까지 보존한다.
"""

from __future__ import annotations

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORY = os.path.join(ROOT, "assets", "story")

# 끝에 줄바꿈을 두는 파일.
_TRAILING_NL = {"signals.json"}


def path(name: str) -> str:
    return os.path.join(STORY, name)


def load(name: str):
    with open(path(name), encoding="utf-8") as f:
        return json.load(f)


def save(name: str, data) -> None:
    out = json.dumps(data, ensure_ascii=False, indent=1)
    if name in _TRAILING_NL:
        out += "\n"
    with open(path(name), "w", encoding="utf-8") as f:
        f.write(out)


def by_id(events: list) -> dict:
    return {e["id"]: e for e in events}
