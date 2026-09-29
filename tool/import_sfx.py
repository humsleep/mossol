#!/usr/bin/env python3
"""받아 온 효과음을 앱 규격으로 바꿔 넣는다.

넣는 곳   art_src/sfx_src/<큐 id>.<아무 형식>   (mp3 · wav · m4a · aiff · flac …)
나오는 곳 assets/sfx/<큐 id>.wav                WAV 16-bit 44.1kHz mono

하는 일: 형식 변환(afconvert) → 앞뒤 무음 잘라내기 → 피크 정규화 → 길이 확인.
`call_ring` 은 반복 재생되므로 시작·끝을 0 으로 페이드해 이음매에서 "틱" 소리가 나지 않게 한다.

큐 이름은 `lib/audio/sfx_service.dart` 의 `Sfx` enum 과 1:1 이다. 이름이 틀리면 알려 준다.
일부만 넣어도 된다 — 넣은 것만 바꾸고 나머지는 그대로 둔다.

    python3 tool/import_sfx.py            # 넣기
    python3 tool/import_sfx.py --dry-run  # 무엇이 바뀔지만 본다
    python3 tool/import_sfx.py --peak -9  # 더 크게(기본 -12 dBFS)

바꾼 뒤에는 **assets/sfx/LICENSES.md 의 해당 줄을 실제 출처로 고친다.** 그 파일은 앱의
오픈소스 라이선스 화면에 그대로 나오므로, 출처를 안 적으면 표시가 거짓이 된다.
"""

from __future__ import annotations

import argparse
import array
import pathlib
import subprocess
import sys
import wave

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art_src" / "sfx_src"
OUT = ROOT / "assets" / "sfx"

# 큐 id → (권장 길이 상한 초, 반복 재생인가). 05_audio_haptics.md §1 의 표와 같다.
CUES = {
    "msg_in": (0.8, False),
    "call_ring": (4.0, True),
    "call_connect": (0.5, False),
    "call_end": (1.0, False),
    "msg_out": (0.4, False),
    "wait_read": (0.6, False),
    "choice_ok": (1.2, False),
    "choice_fail": (1.2, False),
    "summary": (1.5, False),
    "ending": (3.5, False),
    "day_start": (1.5, False),
}

RATE = 44100
SILENCE = 0.002  # 이 진폭(1.0 기준) 아래는 무음으로 보고 잘라낸다
FADE_MS = 8      # 루프 큐의 시작·끝 페이드


def to_wav(src: pathlib.Path, dst: pathlib.Path) -> None:
    """어떤 형식이든 WAV 16-bit 44.1kHz mono 로. macOS 기본 afconvert 를 쓴다."""
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}", "-c", "1", str(src), str(dst)],
        check=True, capture_output=True,
    )


def load(path: pathlib.Path) -> array.array:
    with wave.open(str(path), "rb") as w:
        return array.array("h", w.readframes(w.getnframes()))


def save(path: pathlib.Path, samples: array.array) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(samples.tobytes())


def process(s: array.array, peak_db: float, loop: bool) -> array.array:
    limit = int(SILENCE * 32767)
    # 앞뒤 무음 잘라내기 — 도착음이 늦게 나면 "반응이 느리다" 로 느껴진다.
    start, end = 0, len(s)
    while start < end and abs(s[start]) < limit:
        start += 1
    while end > start and abs(s[end - 1]) < limit:
        end -= 1
    s = s[start:end] if end > start else s

    # 피크 정규화.
    top = max((abs(v) for v in s), default=1) or 1
    target = 32767 * (10 ** (peak_db / 20.0))
    gain = target / top
    s = array.array("h", (max(-32768, min(32767, int(v * gain))) for v in s))

    if loop:
        # 이음매 클릭 방지: 시작·끝을 0 으로 짧게 페이드.
        n = min(int(RATE * FADE_MS / 1000), len(s) // 2)
        for i in range(n):
            f = i / n
            s[i] = int(s[i] * f)
            s[-1 - i] = int(s[-1 - i] * f)
    return s


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dry-run", action="store_true", help="쓰지 않고 목록만 본다")
    ap.add_argument("--peak", type=float, default=-12.0, help="목표 피크 dBFS (기본 -12)")
    args = ap.parse_args()

    if not SRC.is_dir() or not any(SRC.iterdir()):
        print(f"넣을 파일이 없다. {SRC.relative_to(ROOT)}/ 에 <큐 id>.<형식> 으로 두어라.\n"
              f"큐 id: {', '.join(CUES)}")
        return 1

    tmp = ROOT / ".venv" / "sfx_tmp.wav"
    tmp.parent.mkdir(parents=True, exist_ok=True)
    done = unknown = 0

    for src in sorted(SRC.iterdir()):
        if src.name.startswith(".") or src.is_dir():
            continue
        cue = src.stem
        if cue not in CUES:
            print(f"  ? {src.name} — 모르는 큐 이름이라 건너뛴다")
            unknown += 1
            continue
        max_s, loop = CUES[cue]
        dst = OUT / f"{cue}.wav"
        if args.dry_run:
            print(f"  {src.name} → {dst.name}")
            continue
        try:
            to_wav(src, tmp)
        except subprocess.CalledProcessError as e:
            print(f"  ! {src.name} 변환 실패: {e.stderr.decode()[:120]}", file=sys.stderr)
            continue
        s = process(load(tmp), args.peak, loop)
        save(dst, s)
        secs = len(s) / RATE
        flag = ""
        if secs > max_s:
            flag = f"  ← 권장 {max_s}s 보다 길다. 짧게 자르는 편이 낫다"
        if loop and secs < 1.0:
            flag = "  ← 벨이 너무 짧아 반복이 티난다"
        print(f"  {src.name} → {dst.name}  {secs:.2f}s {dst.stat().st_size // 1024}KB{flag}")
        done += 1

    tmp.unlink(missing_ok=True)
    if args.dry_run:
        print("\n--dry-run: 쓰지 않았다.")
        return 0
    print(f"\n{done}개 교체{f' · 이름 모름 {unknown}개' if unknown else ''}.")
    print("들어 보기:  python3 tool/play_sfx.py")
    print("출처 기록:  assets/sfx/LICENSES.md 의 해당 줄을 실제 출처로 고칠 것 (앱 라이선스 화면에 그대로 나온다)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
