#!/usr/bin/env python3
"""생성한 그림을 앱에 넣을 크기·형식으로 바꾼다.

생성 도구가 뱉는 원본은 1536×1024 PNG 2MB 쯤이다. 62장이면 118MB — 텍스트 게임
다운로드 용량으로는 말이 안 된다. 여기서 규격 크기로 줄이고 JPEG 로 바꾼다.

형식이 JPEG 인 이유: 이 맥에 webp 인코더(cwebp·Pillow)가 없고, 초상화
(assets/portraits/*.jpg)가 이미 JPEG 라 프로젝트 관행과도 맞는다. 장면·사진·엔딩은
투명도가 필요 없다. 스티커는 투명도가 필요하므로 PNG 로 둔다(이 스크립트는 건드리지 않는다).

원본은 지우지 않고 art_src/ 로 옮긴다(git 에는 올리지 않는다). 다시 뽑을 때 쓴다.

    python3 tool/convert_art.py            # 변환
    python3 tool/convert_art.py --dry-run  # 무엇이 바뀔지만 본다
"""

from __future__ import annotations

import argparse
import pathlib
import shutil
import struct
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# 폴더별 목표 긴 변(px)과 JPEG 품질. docs/SCENE_PROMPTS.md §0 의 내보내기 크기다.
# 레티나 3배 화면에서도 카드 폭(≈390pt)보다 크므로 더 키울 이유가 없다.
TARGETS = {
    "scenes": (1200, 82),
    "photos": (800, 82),
    "endings": (1200, 82),
}

SRC_EXT = {".png", ".jpeg"}  # .jpg 는 이미 결과물 형식이라 건드리지 않는다


def png_size(path: pathlib.Path) -> tuple[int, int] | None:
    """PNG 헤더에서 크기만 읽는다(외부 의존성 없이)."""
    with path.open("rb") as f:
        head = f.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


def convert(src: pathlib.Path, dst: pathlib.Path, longest: int, quality: int) -> None:
    subprocess.run(
        [
            "sips", "-s", "format", "jpeg",
            "-s", "formatOptions", str(quality),
            "--resampleHeightWidthMax", str(longest),
            str(src), "--out", str(dst),
        ],
        check=True,
        capture_output=True,
    )


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true", help="바꾸지 않고 목록만 본다")
    args = ap.parse_args()

    if not shutil.which("sips"):
        print("sips 가 없다(맥 기본 도구). 다른 변환기를 써야 한다.", file=sys.stderr)
        return 2

    src_root = ROOT / "art_src"
    before = after = 0
    moved = 0

    for folder, (longest, quality) in TARGETS.items():
        d = ROOT / "assets" / folder
        if not d.is_dir():
            continue
        for src in sorted(d.iterdir()):
            if src.suffix.lower() not in SRC_EXT:
                continue
            dst = src.with_suffix(".jpg")
            size = png_size(src)
            dim = f"{size[0]}×{size[1]}" if size else "?"
            kb = src.stat().st_size // 1024
            before += src.stat().st_size
            print(f"  {folder}/{src.name}  {dim} {kb}KB → {dst.name} (긴 변 {longest})")
            if args.dry_run:
                continue
            convert(src, dst, longest, quality)
            after += dst.stat().st_size
            # 원본은 지우지 않고 옮긴다.
            keep = src_root / folder
            keep.mkdir(parents=True, exist_ok=True)
            shutil.move(str(src), str(keep / src.name))
            moved += 1

    if args.dry_run:
        print(f"\n--dry-run: 바꾸지 않았다. 대상 {before // 1024 // 1024}MB")
        return 0
    print(
        f"\n{moved}장 변환. {before // 1024 // 1024}MB → {after // 1024 // 1024}MB"
        f" (원본은 art_src/ 로 옮겼다)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
