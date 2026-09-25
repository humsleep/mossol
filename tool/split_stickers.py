#!/usr/bin/env python3
"""스티커 시트를 잘라 앱에 넣을 파일로 만든다.

넣는 곳
    art_src/sticker_sheets/<캐릭터 id>.png     2×2 시트(왼위 joy · 오른위 sulk · 왼아래 shy · 오른아래 surprise)
    art_src/sticker_singles/<파일 이름>.png     5번째 스티커(daeun_blank 등) 낱장

나오는 곳
    assets/stickers/<파일 이름>.webp           투명 배경, 384×384

하는 일: 2×2 분할 → 마젠타(#FF00FF) 배경 제거 → 빈 여백 잘라내기 → 정사각 캔버스에 맞춰
384×384 로 저장. 이미 투명한 PNG 를 주면 키잉은 건너뛴다.

왜 WebP 인가: 말풍선 옆에 배경 없이 떠야 해서 알파가 필요한데, WebP 는 알파를 그대로
보존하면서 PNG 보다 훨씬 작다. 실제 일러스트 384×384 로 재 보면 PNG 146KB · WebP q90 17KB
(8배). 52장이면 7.6MB 대 0.9MB 차이다.

    python3 tool/split_stickers.py
    python3 tool/split_stickers.py --dry-run

처음 돌리면 Pillow 를 프로젝트 전용 `.venv/` 에 자동으로 깔고 이어서 진행한다
(맥 Homebrew 파이썬은 시스템 설치를 막는다 — tool/_venv.py).
"""

from __future__ import annotations

import argparse
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from _venv import ensure  # noqa: E402

ensure("PIL", pip="Pillow")
ensure("numpy")  # 키잉을 픽셀 루프 대신 배열 연산으로(1254² × 64칸을 파이썬 루프로 돌면 느리다)

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHEETS = ROOT / "art_src" / "sticker_sheets"
SINGLES = ROOT / "art_src" / "sticker_singles"
OUT = ROOT / "assets" / "stickers"

# 시트 칸 순서. docs/STICKER_SHEETS.md 의 프롬프트가 이 배치로 그리게 한다.
CELLS = ["joy", "sulk", "shy", "surprise"]

SIDE = 384          # 최종 한 변
QUALITY = 90        # WebP 품질. 알파는 항상 무손실로 저장된다
KEY = (255.0, 0.0, 255.0)  # 빼낼 배경색

# "얼마나 마젠타인가" = min(R,B) - G. 순수 마젠타 255, 머리카락·피부·입술은 0 근처나 음수.
# 이 값이 KEY_LO 아래면 완전 불투명, KEY_HI 위면 완전 투명, 사이는 부드럽게 잇는다.
# 경계 픽셀(머리색+마젠타가 섞인 분홍)이 이 중간 구간에 떨어지므로 하드 임계값으로는
# 분홍 테두리가 남는다 — 실제로 첫 판에서 남았다.
KEY_LO = 48
KEY_HI = 200


def key_out(im):
    """마젠타 배경을 투명으로. 이미 알파가 있으면 그대로 둔다.

    1. 마젠타 정도로 부드러운 알파를 만든다.
    2. 반투명 경계 픽셀의 색에서 섞여 든 마젠타를 도로 뺀다(despill):
       보이는 색 c = a·앞색 + (1-a)·마젠타  →  앞색 = (c - (1-a)·마젠타) / a
    3. 알파를 1px 수축해 마지막 잔여 테두리를 지운다(384 로 줄이면 보이지 않는 양).
    """
    import numpy as np
    from PIL import Image, ImageFilter

    if im.mode == "RGBA" and im.getchannel("A").getextrema()[0] < 255:
        return im  # 도구가 투명 PNG 를 준 경우

    rgb = np.asarray(im.convert("RGB"), dtype=np.float32)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    m = np.minimum(r, b) - g
    alpha = np.clip((KEY_HI - m) / (KEY_HI - KEY_LO), 0.0, 1.0)

    # despill — 완전 불투명·완전 투명은 건드리지 않는다.
    a = alpha[..., None]
    key = np.array(KEY, dtype=np.float32)
    mid = (a > 0.0) & (a < 1.0)
    fg = np.where(mid, (rgb - (1.0 - a) * key) / np.maximum(a, 1e-3), rgb)
    fg = np.clip(fg, 0.0, 255.0)

    out = Image.fromarray(fg.astype(np.uint8), "RGB").convert("RGBA")
    a8 = Image.fromarray((alpha * 255.0).astype(np.uint8), "L")
    a8 = a8.filter(ImageFilter.MinFilter(3))  # 1px 수축
    out.putalpha(a8)
    return out


def finish(im, dst: pathlib.Path) -> int:
    """여백을 잘라 정사각으로 맞추고 [SIDE] 크기로 저장한다."""
    from PIL import Image

    box = im.getbbox()  # 투명 영역을 뺀 실제 그림 범위
    if box:
        im = im.crop(box)
    side = max(im.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - im.size[0]) // 2, (side - im.size[1]) // 2))
    canvas = canvas.resize((SIDE, SIDE), Image.LANCZOS)
    dst.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dst, "WEBP", quality=QUALITY, method=6, exact=True)
    return dst.stat().st_size


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true", help="쓰지 않고 목록만 본다")
    args = ap.parse_args()

    from PIL import Image

    made = total = 0
    found_any = False

    for sheet in sorted(SHEETS.glob("*.png")) if SHEETS.is_dir() else []:
        found_any = True
        char = sheet.stem
        im = Image.open(sheet)
        w, h = im.size
        for i, emo in enumerate(CELLS):
            col, row = i % 2, i // 2
            cell = im.crop((col * w // 2, row * h // 2,
                            (col + 1) * w // 2, (row + 1) * h // 2))
            dst = OUT / f"{char}_{emo}.webp"
            print(f"  {sheet.name} [{row},{col}] → {dst.name}")
            if args.dry_run:
                continue
            total += finish(key_out(cell), dst)
            made += 1

    for single in sorted(SINGLES.glob("*.png")) if SINGLES.is_dir() else []:
        found_any = True
        dst = OUT / f"{single.stem}.webp"
        print(f"  {single.name} → {dst.name}")
        if args.dry_run:
            continue
        total += finish(key_out(Image.open(single)), dst)
        made += 1

    if not found_any:
        print(f"시트가 없다. 먼저 {SHEETS.relative_to(ROOT)}/<캐릭터 id>.png 로 저장하라.\n"
              f"프롬프트는 docs/STICKER_SHEETS.md 에 있다.")
        return 1
    if args.dry_run:
        print("\n--dry-run: 쓰지 않았다.")
        return 0
    print(f"\n{made}장 저장. 합계 {total / 1024:.0f}KB · {OUT.relative_to(ROOT)}/")
    print("확인:  python3 tool/check_assets.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
