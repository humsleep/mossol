#!/usr/bin/env python3
"""개편 2 그림을 받은 그대로 앱에 넣는다(docs/overhaul2/art_board.html 의 번호 기준).

ChatGPT 에서 받은 PNG 를 `art_inbox/` 에 `01.png` ~ `15.png` 로 넣고 돌린다.
이름에 번호 대신 id 가 들어 있어도 된다(`sc_leak_d1.png`, `01_sc_leak_d1.png` 등).

한 장마다 하는 일:
1. 가운데를 기준으로 3:2 로 자른다(ChatGPT 가 정사각형이나 세로로 줘도 맞춘다).
2. 가로 1200px 로 줄여 WebP q90 으로 `assets/scenes/` 또는 `assets/endings/` 에 저장한다.
   엔딩의 `image` 대체 그림 필드는 그대로 둬도 된다(앱은 `<엔딩 id>` 파일을 먼저 찾는다).
3. 원본 PNG 는 지우지 않고 `art_src/overhaul2/` 로 옮긴다(git 제외).

이미 있는 그림을 다시 넣으면 새 그림으로 바꾼다(다시 뽑은 경우).

    python3 tool/import_overhaul2_art.py --dry-run   # 무엇을 할지만 본다
    python3 tool/import_overhaul2_art.py
"""

from __future__ import annotations

import argparse
import pathlib
import re
import shutil
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _venv import ensure  # noqa: E402

ensure("PIL", pip="Pillow")
from PIL import Image  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
INBOX = ROOT / "art_inbox"
KEEP = ROOT / "art_src" / "overhaul2"

# docs/overhaul2/art_board.html 과 같은 순서(tool/image_studio/build_overhaul2.py 의 ORDER).
ORDER = [
    "sc_leak_d1", "sc_speech_d1", "sc_clip_d1", "sc_swap_d1", "sc_ghost_d1",
    "sc_leak_d3", "sc_clip_d3", "sc_speech_d2", "sc_swap_d2",
    "influencer", "infamous", "m36_waiting", "m36_letgo", "villain_legend",
    "sc_ghost_d2",
]
ENDINGS = {"influencer", "infamous", "m36_waiting", "m36_letgo", "villain_legend"}
# 선호별로 이벤트가 나뉜 장면은 같은 그림을 그 이름으로도 둔다(앱은 `<이벤트 id>` 로 찾는다).
ALSO = {"sc_swap_d2": ["sc_swap_d2_m"]}
WIDTH = 1200  # convert_art.py: 가장 큰 아이폰의 카드 폭 1176px 를 덮는다.


def target_of(path: pathlib.Path) -> str | None:
    stem = path.stem.lower()
    for key in sorted(ORDER, key=len, reverse=True):  # sc_leak_d1 보다 긴 이름을 먼저 본다
        if key in stem:
            return key
    m = re.match(r"\s*0*(\d{1,2})(?!\d)", stem)
    if m and 1 <= int(m.group(1)) <= len(ORDER):
        return ORDER[int(m.group(1)) - 1]
    return None


def dest_of(key: str) -> pathlib.Path:
    folder = "endings" if key in ENDINGS else "scenes"
    return ROOT / "assets" / folder / f"{key}.webp"


def convert(src: pathlib.Path, dst: pathlib.Path) -> tuple[int, int]:
    with Image.open(src) as im:
        im = im.convert("RGB")
        w, h = im.size
        # 가운데 기준 3:2
        if w / h > 1.5:
            nw = round(h * 1.5)
            im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
        elif w / h < 1.5:
            nh = round(w / 1.5)
            im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
        if im.width > WIDTH:
            im = im.resize((WIDTH, round(WIDTH / 1.5)), Image.LANCZOS)
        im.save(dst, "WEBP", quality=90, method=6)
        return im.size


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    INBOX.mkdir(exist_ok=True)
    files = sorted(p for p in INBOX.iterdir() if p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"})
    if not files:
        print(f"art_inbox/ 가 비어 있다. 받은 PNG 를 {INBOX.relative_to(ROOT)}/01.png 처럼 넣는다.")
    seen: dict[str, pathlib.Path] = {}
    for f in files:
        key = target_of(f)
        if key is None:
            print(f"  ? {f.name}: 번호(01~15)나 이름을 알 수 없어 건너뜀")
            continue
        if key in seen:
            print(f"  ! {f.name}: {seen[key].name} 와 같은 자리({key}) — 건너뜀")
            continue
        seen[key] = f
        dst = dest_of(key)
        verb = "교체" if dst.exists() else "추가"
        if args.dry_run:
            print(f"  {f.name} → {dst.relative_to(ROOT)} ({verb})")
            continue
        size = convert(f, dst)
        for twin in ALSO.get(key, []):
            shutil.copyfile(dst, dst.with_name(f"{twin}.webp"))
        KEEP.mkdir(parents=True, exist_ok=True)
        shutil.move(str(f), str(KEEP / f"{ORDER.index(key) + 1:02d}_{key}{f.suffix.lower()}"))
        print(f"  {f.name} → {dst.relative_to(ROOT)} {size[0]}×{size[1]} {dst.stat().st_size // 1024}KB ({verb})")

    print("\n현황")
    for i, key in enumerate(ORDER, 1):
        mark = "✓" if dest_of(key).exists() else ("필수" if i <= 5 else "-")
        print(f"  {i:02d} {key:<15} {mark}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
