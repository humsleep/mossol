#!/usr/bin/env python3
"""생성한 그림을 앱에 넣을 크기·형식으로 바꾼다.

생성 도구가 뱉는 원본은 1536×1024 PNG 2MB 쯤이다. 62장이면 118MB — 텍스트 게임
다운로드 용량으로는 말이 안 된다.

**크기**: 화면이 실제로 쓰는 픽셀만큼만 넣는다. 가장 큰 아이폰(Pro Max 440pt)에서
장면·엔딩 카드는 `화면 폭 - screenX*2 = 392pt`, 3배 화면이면 1176px 다. 확대 뷰어도
같은 폭(`- xl*2`)이라 **1200px 이면 전부 덮는다.** 사진 창은 화면 폭의 60% → 792px,
그래서 800px. 이보다 큰 원본을 넣어도 기기가 줄여 그릴 뿐 보이는 것은 같다.

**형식**: WebP q90. 같은 1200px 에서 실측(PSNR, 높을수록 원본에 가깝다):

    JPEG q82   88KB / 40.5dB      WebP q80   39KB / 39.9dB
    JPEG q90  127KB / 42.2dB      WebP q90   70KB / 42.4dB

WebP q90 이 JPEG q90 급 화질을 절반 크기로 낸다. 투명도가 필요한 스티커도 같은 형식을
쓸 수 있다(이 스크립트는 stickers/ 를 건드리지 않는다 — 알파를 살려 따로 넣는다).

WebP 인코더는 처음 돌릴 때 프로젝트 전용 `.venv/` 에 자동으로 깔린다(tool/_venv.py).
`cwebp` 가 이미 있으면 그걸 쓰고, 둘 다 안 되면 sips 로 JPEG 를 만든다(용량 1.5배).

원본은 지우지 않고 art_src/ 로 옮긴다(git 제외). 다시 뽑을 때 쓴다.

    python3 tool/convert_art.py            # 변환
    python3 tool/convert_art.py --dry-run  # 무엇이 바뀔지만 본다
    python3 tool/convert_art.py --quality 95
"""

from __future__ import annotations

import argparse
import pathlib
import shutil
import struct
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _venv import ensure  # noqa: E402

if not shutil.which("cwebp"):
    ensure("PIL", pip="Pillow")

ROOT = pathlib.Path(__file__).resolve().parent.parent

# 폴더별 목표 긴 변(px). 위 주석의 계산값이다.
LONGEST = {"scenes": 1200, "photos": 800, "endings": 1200}

SRC_EXT = {".png", ".jpg", ".jpeg"}  # 결과 형식(.webp)은 건드리지 않는다


def png_size(path: pathlib.Path) -> tuple[int, int] | None:
    """PNG 헤더에서 크기만 읽는다(외부 의존성 없이)."""
    with path.open("rb") as f:
        head = f.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def encoder() -> str:
    """쓸 수 있는 인코더. webp 가 가능하면 webp, 아니면 jpeg."""
    try:
        from PIL import features  # noqa: F401

        if features.check("webp"):
            return "pillow"
    except ImportError:
        pass
    if shutil.which("cwebp"):
        return "cwebp"
    return "sips"


def convert(src: pathlib.Path, longest: int, quality: int, how: str) -> pathlib.Path:
    if how == "pillow":
        from PIL import Image

        dst = src.with_suffix(".webp")
        im = Image.open(src).convert("RGB")
        im.thumbnail((longest, longest), Image.LANCZOS)
        im.save(dst, "WEBP", quality=quality, method=6)
        return dst
    if how == "cwebp":
        dst = src.with_suffix(".webp")
        subprocess.run(
            ["cwebp", "-q", str(quality), "-resize", str(longest), "0",
             "-m", "6", str(src), "-o", str(dst)],
            check=True, capture_output=True,
        )
        return dst
    dst = src.with_suffix(".jpg")
    subprocess.run(
        ["sips", "-s", "format", "jpeg", "-s", "formatOptions", str(quality),
         "--resampleHeightWidthMax", str(longest), str(src), "--out", str(dst)],
        check=True, capture_output=True,
    )
    return dst


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true", help="바꾸지 않고 목록만 본다")
    ap.add_argument("--quality", type=int, default=90, help="압축 품질(기본 90)")
    args = ap.parse_args()

    how = encoder()
    if how == "sips" and not shutil.which("sips"):
        print("쓸 수 있는 변환기가 없다. pip install Pillow 를 하라.", file=sys.stderr)
        return 2
    if how == "sips":
        print("! WebP 인코더가 없어 JPEG 로 만든다(용량 1.5배). pip install Pillow 권장.\n")

    src_root = ROOT / "art_src"
    before = after = moved = 0

    for folder, longest in LONGEST.items():
        d = ROOT / "assets" / folder
        if not d.is_dir():
            continue
        for src in sorted(d.iterdir()):
            if src.suffix.lower() not in SRC_EXT:
                continue
            size = png_size(src)
            dim = f"{size[0]}×{size[1]}" if size else "?"
            kb = src.stat().st_size // 1024
            before += src.stat().st_size
            print(f"  {folder}/{src.name}  {dim} {kb}KB → 긴 변 {longest}, {how} q{args.quality}")
            if args.dry_run:
                continue
            dst = convert(src, longest, args.quality, how)
            after += dst.stat().st_size
            if dst != src:  # 형식이 바뀌었으면 원본을 치운다
                keep = src_root / folder
                keep.mkdir(parents=True, exist_ok=True)
                shutil.move(str(src), str(keep / src.name))
            moved += 1

    if args.dry_run:
        print(f"\n--dry-run: 바꾸지 않았다. 대상 {before // 1024 // 1024}MB")
        return 0
    print(
        f"\n{moved}장 변환. {before // 1024 // 1024}MB → {after / 1024 / 1024:.1f}MB"
        f" (원본은 art_src/ 에 있다)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
