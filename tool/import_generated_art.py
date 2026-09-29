#!/usr/bin/env python3
"""docs/image_prompts 로 만든 그림(PNG)을 앱에 넣을 형식·이름으로 옮긴다.

한 번에 하는 일:
1. 이름 확인 — docs/image_prompts/*.md 가 기대하는 파일과 assets/ 의 PNG 를 대조한다.
2. 사진 이름 맞추기 — 프롬프트 문서는 `<이벤트 id>`, `_2`, `_3` … (lines → 선택지의 reply →
   failReply → critReply 순)으로 지었고, 앱(tool/link_photos.py)은 `<이벤트 id>_<n>`
   (n 은 0부터, lines → reply → critReply → failReply 순)으로 찾는다. 같은 사진 줄끼리 짝지어
   이름을 바꾼다. 이미 그 자리에 그림이 있으면(예전 배치) 기존 그림을 두고 새 그림은 art_src/ 로만 보관한다.
3. 위기·히든 컷 — `assets/events/<이벤트 id>.png` 는 앱의 장면 삽화 자리 `assets/scenes/` 로 옮긴다.
4. WebP q90 — **해상도는 그대로** 두고 형식만 바꾼다(PNG 2~3MB → WebP 150~300KB, 눈으로 차이 없음).
5. 흑역사 도장 — 배경이 칠해져 나온 도장(흰 종이·가짜 체크무늬)은 빨간 잉크만 남기고 투명하게 만든다.
6. 원본 PNG 는 지우지 않고 art_src/<폴더>/ 로 옮긴다(git 제외).

멱등이다: 이미 옮긴 파일은 다시 건드리지 않는다. 사진을 옮긴 뒤 tool/link_photos.py 를 돌려
대본의 사진 줄에 `photo.image` 를 잇는다.

    python3 tool/import_generated_art.py --dry-run
    python3 tool/import_generated_art.py
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import shutil
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _venv import ensure  # noqa: E402

ensure("PIL", pip="Pillow")
ensure("numpy")
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
SRC = ROOT / "art_src"
QUALITY = 90

# 새 그림이 들어오는 폴더. events 는 scenes 로 합친다.
FOLDERS = ["endings", "photos", "scenes", "expressions", "keyart", "events", "stamps"]


def expected_files() -> set[str]:
    """프롬프트 문서가 기대하는 `assets/...png` 경로."""
    want = set()
    docs = ROOT / "docs" / "image_prompts"
    prefix = {"01_endings.md": "assets/endings/", "02_photos.md": "assets/photos/"}
    for md in sorted(docs.glob("*.md")):
        for m in re.finditer(r"^#{3,4} .*?`([^`]+\.png)`", md.read_text(encoding="utf-8"), re.M):
            name = m.group(1)
            want.add(name if name.startswith("assets/") else prefix.get(md.name, "") + name)
    return want


def photo_renames() -> dict[str, str]:
    """프롬프트 문서 이름(확장자 뺀 것) → 앱 이름(`<id>_<n>`)."""
    out = {}
    for path in sorted((ASSETS / "story").glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            continue
        for ev in data:
            if not isinstance(ev, dict) or "choices" not in ev and "lines" not in ev:
                continue

            def shots(order):
                got = []
                for l in ev.get("lines", []):
                    if isinstance(l, dict) and isinstance(l.get("photo"), dict):
                        got.append(id(l["photo"]))
                for ch in ev.get("choices", []):
                    for key in order:
                        for l in ch.get(key) or []:
                            if isinstance(l, dict) and isinstance(l.get("photo"), dict):
                                got.append(id(l["photo"]))
                return got

            doc_order = shots(("reply", "failReply", "critReply"))
            app_order = shots(("reply", "critReply", "failReply"))
            for k, pid in enumerate(doc_order):
                doc_name = ev["id"] if k == 0 else f"{ev['id']}_{k + 1}"
                out[doc_name] = f"{ev['id']}_{app_order.index(pid)}"
    return out


# 도장 잉크색(투명 배경으로 잘 나온 도장들의 평균). 배경을 지운 도장도 이 한 색으로 맞춘다.
STAMP_INK = (207, 38, 67)


def stamp_alpha(im: Image.Image) -> Image.Image:
    """빨간 잉크만 남기고 나머지(흰 종이·가짜 체크무늬 배경)는 투명하게.

    생성 도구가 "투명 배경"을 회색 체크무늬 그림으로 그려 넣는 일이 있어 흰색만 지우면 안 된다.
    빨강 정도(R - max(G, B))를 알파로 쓰면 잉크의 번짐·거친 질감이 그대로 남는다.
    """
    a = np.asarray(im.convert("RGB")).astype(float)
    red = a[..., 0] - np.maximum(a[..., 1], a[..., 2])
    out = np.zeros(a.shape[:2] + (4,), np.uint8)
    out[..., :3] = STAMP_INK
    out[..., 3] = (np.clip((red - 25) / 85, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    have = {str(p.relative_to(ROOT)) for d in FOLDERS for p in (ASSETS / d).glob("*.png")}
    want = expected_files()
    missing = sorted(want - have)
    extra = sorted(have - want)
    print(f"기대 {len(want)}장 · 들어온 PNG {len(have)}장 · 빠짐 {len(missing)} · 모르는 이름 {len(extra)}")
    for m in missing:
        print("  빠짐:", m)
    for m in extra:
        print("  모르는 이름(그대로 변환만):", m)

    renames = photo_renames()
    kept_old = []
    plan = []  # (원본 png, 결과 webp 또는 None=보관만, 알파 처리 여부)
    for rel in sorted(have):
        src = ROOT / rel
        folder, stem = src.parent.name, src.stem
        if folder == "photos":
            new = renames.get(stem)
            if new is None:
                print("  사진 줄을 못 찾음(이름 그대로):", rel)
                new = stem
            dst = ASSETS / "photos" / f"{new}.webp"
            if any((ASSETS / "photos" / f"{new}{ext}").exists() for ext in (".webp", ".jpg")):
                kept_old.append(f"{stem} → {new}")
                plan.append((src, None, False))
                continue
        elif folder == "events":
            dst = ASSETS / "scenes" / f"{stem}.webp"
        else:
            dst = src.with_suffix(".webp")
        plan.append((src, dst, folder == "stamps"))

    before = after = 0
    for src, dst, alpha in plan:
        before += src.stat().st_size
        keep = SRC / src.parent.name / src.name
        if a.dry_run:
            print(f"  {src.relative_to(ROOT)} → {dst.relative_to(ROOT) if dst else '(보관만)'}")
            continue
        if dst is not None:
            im = Image.open(src)
            if alpha:
                # 제대로 투명하게 나온 도장은 그대로, 배경이 칠해져 나온 도장만 잉크를 뽑는다.
                im = im if im.mode == "RGBA" and im.getpixel((2, 2))[3] == 0 else stamp_alpha(im)
                im.save(dst, "WEBP", quality=QUALITY, method=6, exact=False)
            else:
                im.convert("RGB").save(dst, "WEBP", quality=QUALITY, method=6)
            after += dst.stat().st_size
        keep.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), keep)

    if kept_old:
        print(f"이미 그림이 있는 사진 자리 {len(kept_old)}곳은 기존 그림을 두고 새 그림은 art_src/photos 에만 보관:")
        for k in kept_old:
            print("  ", k)
    if not a.dry_run:
        print(f"변환 {sum(1 for _, d, _ in plan if d)}장: {before / 1e6:.1f}MB → {after / 1e6:.1f}MB (원본은 art_src/)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
