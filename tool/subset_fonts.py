#!/usr/bin/env python3
"""Pretendard 서브셋 생성기.

tool/fonts_src/Pretendard-*.otf (원본, git 미추적) → assets/fonts/Pretendard-*.otf (서브셋).
같이 assets/fonts/coverage.txt 를 쓰고, test/font_subset_test.dart 가 그 파일과
소스(assets/story/*.json, lib/**/*.dart, ios/Runner/Info.plist)의 한글 집합을 비교한다.

포함 범위
  - 기본 라틴 U+0020–007E, Latin-1 보충 U+00A0–00FF
  - 일반 구두점 U+2000–206F (… “” ‘’ 등), 원화 ₩ U+20A9
  - 화살표 U+2190–21FF, 기타 기호 U+2600–26FF, 딩뱃 U+2700–27BF
  - CJK 기호·구두점 U+3000–303F, 한글 자모 U+3131–318E (ㆍ U+318D 포함)
  - 한글 음절: KS X 1001 2350자 ∪ 프로젝트 소스에서 실제로 쓰인 음절 전부

새 한글이 추가되면:  python3 tool/subset_fonts.py
(fonttools 가 없으면 uv 로 자동 실행: uvx --from fonttools pyftsubset)
"""
from __future__ import annotations

import glob
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "tool", "fonts_src")
OUT_DIR = os.path.join(ROOT, "assets", "fonts")
WEIGHTS = ["Regular", "Medium", "SemiBold", "Bold"]
DOWNLOAD_URL = "https://github.com/orioncactus/pretendard/releases (Pretendard-1.x.zip → public/static/*.otf)"

# 한글 음절을 긁을 소스. test/font_subset_test.dart 와 같은 목록을 유지할 것.
SOURCE_GLOBS = [
    "assets/story/*.json",
    "lib/**/*.dart",
    "ios/Runner/Info.plist",
]

STATIC_RANGES = [
    (0x0020, 0x007E),  # 기본 라틴
    (0x00A0, 0x00FF),  # Latin-1 보충 (· U+00B7 포함)
    (0x2000, 0x206F),  # 일반 구두점
    (0x20A9, 0x20A9),  # ₩
    (0x2190, 0x21FF),  # 화살표
    (0x2600, 0x26FF),  # 기타 기호 (♥ ★ 등)
    (0x2700, 0x27BF),  # 딩뱃 (❤ ✓ 등)
    (0x3000, 0x303F),  # CJK 기호·구두점
    (0x3131, 0x318E),  # 한글 호환 자모 (ㆍ U+318D 포함)
]

# 남길 OpenType 기능. 코드에서 FontFeature 를 새로 쓰면 여기에도 추가한다.
LAYOUT_FEATURES = "kern,tnum,pnum,locl,ccmp,mark,mkmk"

# 반드시 들어 있어야 하는 낱자. 범위에 이미 포함되지만 검증 목적으로 따로 적는다.
MUST_HAVE = "₩…“”‘’·ㆍ"

HANGUL = re.compile(r"[가-힣]")


def ksx1001_syllables() -> set[int]:
    """KS X 1001 완성형 한글 2350자. EUC-KR 행 16–40(0xB0–0xC8)에 있는 음절."""
    out = set()
    for cp in range(0xAC00, 0xD7A4):
        try:
            b = chr(cp).encode("euc_kr")
        except UnicodeEncodeError:
            continue
        if len(b) == 2 and 0xB0 <= b[0] <= 0xC8 and 0xA1 <= b[1] <= 0xFE:
            out.add(cp)
    assert len(out) == 2350, len(out)
    return out


def source_syllables() -> set[int]:
    out: set[int] = set()
    for pattern in SOURCE_GLOBS:
        for path in glob.glob(os.path.join(ROOT, pattern), recursive=True):
            with open(path, encoding="utf-8") as f:
                out.update(ord(c) for c in HANGUL.findall(f.read()))
    return out


def unicode_set() -> set[int]:
    cps: set[int] = set()
    for lo, hi in STATIC_RANGES:
        cps.update(range(lo, hi + 1))
    cps.update(ksx1001_syllables())
    cps.update(source_syllables())
    cps.update(ord(c) for c in MUST_HAVE)
    return cps


def to_ranges(cps: set[int]) -> str:
    """pyftsubset --unicodes= 형식 (U+XXXX-YYYY, 쉼표 구분)."""
    xs = sorted(cps)
    parts = []
    i = 0
    while i < len(xs):
        j = i
        while j + 1 < len(xs) and xs[j + 1] == xs[j] + 1:
            j += 1
        parts.append(f"U+{xs[i]:04X}" if i == j else f"U+{xs[i]:04X}-{xs[j]:04X}")
        i = j + 1
    return ",".join(parts)


def pyftsubset_cmd() -> list[str]:
    if shutil.which("pyftsubset"):
        return ["pyftsubset"]
    for uvx in ("uvx", os.path.expanduser("~/.local/bin/uvx")):
        if shutil.which(uvx) or os.path.exists(uvx):
            return [uvx, "--from", "fonttools", "pyftsubset"]
    sys.exit("pyftsubset 도 uvx 도 없습니다. `pip install fonttools` 또는 uv 를 설치하세요.")


def main() -> int:
    missing = [w for w in WEIGHTS if not os.path.exists(os.path.join(SRC_DIR, f"Pretendard-{w}.otf"))]
    if missing:
        print(f"원본이 없습니다: {', '.join(f'Pretendard-{w}.otf' for w in missing)}")
        print(f"{SRC_DIR}/ 에 원본 OTF 를 넣어 주세요. 내려받기: {DOWNLOAD_URL}")
        return 1

    cps = unicode_set()
    unicodes = to_ranges(cps)
    cmd = pyftsubset_cmd()
    os.makedirs(OUT_DIR, exist_ok=True)

    before = after = 0
    for w in WEIGHTS:
        src = os.path.join(SRC_DIR, f"Pretendard-{w}.otf")
        dst = os.path.join(OUT_DIR, f"Pretendard-{w}.otf")
        subprocess.run(
            cmd + [
                src,
                f"--output-file={dst}",
                f"--unicodes={unicodes}",
                # 앱이 쓰는 OpenType 기능만 남긴다(커닝, 표 숫자, 합성 자모, 한글 locl).
                # `*` 로 두면 ss/cv 대체 글리프 450개가 딸려 들어와 굵기당 50KB 가 늘고,
                # --desubroutinize 는 CFF 압축을 풀어 다시 50KB 를 더한다. 둘 다 쓰지 않는다.
                f"--layout-features={LAYOUT_FEATURES}",
                "--name-IDs=*",
                "--notdef-outline",
            ],
            check=True,
        )
        before += os.path.getsize(src)
        after += os.path.getsize(dst)
        print(f"{w:9s} {os.path.getsize(src)/1024:8.0f} KB → {os.path.getsize(dst)/1024:6.0f} KB")

    # 실제 cmap 에 들어갔는지 확인하고, 그 결과로 coverage.txt 를 쓴다.
    covered = cmap_intersection(cmd, [os.path.join(OUT_DIR, f"Pretendard-{w}.otf") for w in WEIGHTS])
    lacking = sorted(cps - covered)
    lacking_hangul = [c for c in lacking if 0xAC00 <= c <= 0xD7A3]
    if lacking_hangul:
        sys.exit(f"원본에 없는 한글 음절 {len(lacking_hangul)}자: {''.join(map(chr, lacking_hangul))}")
    for ch in MUST_HAVE:
        if ord(ch) not in covered:
            sys.exit(f"필수 문자 {ch!r} U+{ord(ch):04X} 가 서브셋에 없습니다")

    write_coverage(covered)
    print(f"합계 {before/1024/1024:.2f} MB → {after/1024/1024:.2f} MB, 코드포인트 {len(covered)}개")
    return 0


def cmap_intersection(cmd: list[str], paths: list[str]) -> set[int]:
    """네 굵기 모두에 있는 코드포인트. fonttools 를 같은 환경에서 불러 cmap 을 읽는다."""
    script = (
        "import sys;from fontTools.ttLib import TTFont\n"
        "s=None\n"
        "for p in sys.argv[1:]:\n"
        "  c=set(TTFont(p).getBestCmap().keys()); s=c if s is None else s&c\n"
        "print(' '.join(map(str,sorted(s))))\n"
    )
    if cmd[0] == "pyftsubset":
        runner = [sys.executable, "-c", script]
    else:
        runner = [cmd[0], "--from", "fonttools", "python", "-c", script]
    out = subprocess.run(runner + paths, check=True, capture_output=True, text=True).stdout
    return {int(x) for x in out.split()}


def fnv1a64(text: str) -> str:
    """test/font_subset_test.dart 의 _fnv1a64 와 같은 계산. 손으로 고친 파일을 잡는 용도라 암호학적일 필요 없음."""
    h = 0xCBF29CE484222325
    for b in text.encode("utf-8"):
        h = ((h ^ b) * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return f"{h:016x}"


def write_coverage(covered: set[int]) -> None:
    """한 줄에 코드포인트 하나(16진). 첫 줄은 본문의 FNV-1a 64 해시. 테스트가 이 파일을 읽는다."""
    lines = [f"{cp:04X}" for cp in sorted(covered)]
    digest = fnv1a64("\n".join(lines))
    with open(os.path.join(OUT_DIR, "coverage.txt"), "w", encoding="utf-8") as f:
        f.write(f"# fnv1a64 {digest}\n")
        f.write("# tool/subset_fonts.py 가 생성. 손으로 고치지 말 것.\n")
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    sys.exit(main())
