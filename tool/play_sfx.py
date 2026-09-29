#!/usr/bin/env python3
"""효과음을 게임에서 들리는 순서·맥락으로 하나씩 들려준다.

    python3 tool/play_sfx.py            # 전부
    python3 tool/play_sfx.py msg_in     # 하나만
    python3 tool/play_sfx.py --call     # 전화 흐름만(벨 → 받음 → 종료)

맥 기본 `afplay` 를 쓴다. 시뮬레이터가 아니라 맥 스피커로 나므로 진동은 확인할 수 없다 —
진동은 실기기(TestFlight)에서만 확인된다.
"""

from __future__ import annotations

import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
SFX = ROOT / "assets" / "sfx"

# 순서 = 하루를 플레이하며 듣게 되는 순서. 설명은 언제 나는 소리인지.
ORDER = [
    ("day_start", "날짜 전환 카드 — 아침이 밝는다"),
    ("msg_in", "문자 도착 — 알림 카드가 툭 내려앉는 순간 (진동 medium)"),
    ("msg_out", "내 답장 전송 — 선택지를 누르는 순간 (진동 selection)"),
    ("wait_read", "읽씹 대기가 끝남 — '읽음' 이 뜨는 순간"),
    ("choice_ok", "선택 성공 — 결과 패널 (진동 medium)"),
    ("choice_fail", "선택 실패 — 결과 패널 (진동 heavy)"),
    ("call_ring", "전화 벨 — 받거나 거절할 때까지 반복 (진동 2.6초 주기 2연타)"),
    ("call_connect", "전화 받음"),
    ("call_end", "통화 종료 · 거절"),
    ("summary", "하루 정산 카드"),
    ("ending", "엔딩 — 다른 소리를 전부 멈춘다 (진동 heavy → light)"),
]

CALL_FLOW = ["call_ring", "call_connect", "call_end"]


def play(cue: str, note: str = "") -> None:
    p = SFX / f"{cue}.wav"
    if not p.exists():
        print(f"  ! {cue}.wav 없음")
        return
    print(f"  ▶ {cue:14} {note}")
    subprocess.run(["afplay", str(p)])


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    notes = dict(ORDER)

    if "--call" in sys.argv:
        print("전화 흐름 (벨은 실제로는 받을 때까지 반복된다)")
        for cue in CALL_FLOW:
            play(cue, notes.get(cue, ""))
            time.sleep(0.3)
        return 0

    if args:
        for cue in args:
            play(cue, notes.get(cue, ""))
        return 0

    print(f"효과음 {len(ORDER)}개를 게임 순서대로 재생한다. 중간에 끊으려면 Ctrl+C.\n")
    for cue, note in ORDER:
        play(cue, note)
        time.sleep(0.45)  # 소리끼리 겹치지 않게
    print("\n바꾸고 싶은 소리를 골랐으면:")
    print("  1. art_src/sfx_src/<큐 id>.mp3 (형식 무관) 로 저장")
    print("  2. python3 tool/import_sfx.py")
    print("  3. assets/sfx/LICENSES.md 에 출처 기록")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print()
