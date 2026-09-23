#!/usr/bin/env python3
"""효과음 placeholder 11개를 합성한다 (docs/overhaul/05_audio_haptics.md §1·§3).

표준 라이브러리(wave·math)만 쓴다. 다운로드 없음. 출력은 assets/sfx/<큐 id>.wav,
16-bit 44.1kHz mono, 피크 약 -12 dBFS. 실제 CC0 효과음으로 교체되기 전까지의 자리표시자다.

    python3 tool/make_placeholder_sfx.py

벨(call_ring)은 3.0초 "따르릉—쉼" 이 무음으로 시작·끝나서 ReleaseMode.loop 에서 틈이 안 들린다.
"""
from __future__ import annotations

import math
import os
import struct
import wave

RATE = 44100
PEAK = 10 ** (-12 / 20)  # -12 dBFS ≈ 0.251
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sfx")


def env(t: float, dur: float, attack: float = 0.005, release: float = 0.06) -> float:
    """짧은 어택·릴리스 사다리꼴. 딸깍임 없이 끝나게."""
    if t < attack:
        return t / attack
    if t > dur - release:
        return max(0.0, (dur - t) / release)
    return 1.0


def tone(t: float, freq: float, harmonics: tuple[float, ...] = (1.0,)) -> float:
    s = 0.0
    for i, a in enumerate(harmonics, start=1):
        s += a * math.sin(2 * math.pi * freq * i * t)
    return s / sum(harmonics)


def render(dur: float, fn) -> list[float]:
    n = int(RATE * dur)
    return [fn(i / RATE) for i in range(n)]


def segment(start: float, dur: float, fn):
    """start 초부터 dur 초 동안만 fn 을 내고 나머지는 0 인 함수."""

    def f(t: float) -> float:
        u = t - start
        if u < 0 or u >= dur:
            return 0.0
        return fn(u) * env(u, dur)

    return f


def mix(*fns):
    return lambda t: sum(f(t) for f in fns)


def normalize(samples: list[float]) -> list[float]:
    peak = max(abs(s) for s in samples) or 1.0
    return [s / peak * PEAK for s in samples]


def write(name: str, samples: list[float]) -> None:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{name}.wav")
    data = struct.pack("<%dh" % len(samples), *(int(max(-1.0, min(1.0, s)) * 32767) for s in samples))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print(f"{path}  {len(samples) / RATE:.2f}s")


# ---- 큐별 소리. 전부 밝고 짧고 조용하게(카톡·아이폰 UI 소리 아래). ----


def msg_in():
    # 0.4s: 두 음 "띠-딩" (E6 → A6). 문자 도착.
    return render(0.4, mix(
        segment(0.0, 0.16, lambda u: tone(u, 1318.5, (1, 0.3))),
        segment(0.14, 0.26, lambda u: tone(u, 1760.0, (1, 0.25)) * (1 - u * 0.5)),
    ))


def call_ring():
    # 3.0s 루프: 무음 0.1 → 트릴 0.9 → 쉼 0.3 → 트릴 0.9 → 무음 0.8. 옛 전화 벨(20Hz 떨림).
    def trill(u: float) -> float:
        am = 0.5 + 0.5 * math.sin(2 * math.pi * 20 * u)
        return am * (tone(u, 880.0, (1, 0.4, 0.15)) + tone(u, 1046.5, (1, 0.3)) * 0.7)

    return render(3.0, mix(
        segment(0.1, 0.9, trill),
        segment(1.3, 0.9, trill),
    ))


def call_connect():
    # 0.2s: 짧은 "틱" 한 음.
    return render(0.2, segment(0.0, 0.18, lambda u: tone(u, 987.8, (1, 0.5)) * (1 - u * 3)))


def call_end():
    # 0.5s: 낮은 두 음 내려감 (G5 → C5). 끊김.
    return render(0.5, mix(
        segment(0.0, 0.2, lambda u: tone(u, 784.0, (1, 0.3))),
        segment(0.22, 0.26, lambda u: tone(u, 523.3, (1, 0.3)) * (1 - u * 1.5)),
    ))


def msg_out():
    # 0.12s: 위로 슉 (600 → 1400 Hz 스윕).
    def sweep(u: float) -> float:
        f = 600 + (1400 - 600) * (u / 0.12)
        return math.sin(2 * math.pi * f * u)

    return render(0.12, segment(0.0, 0.12, sweep))


def wait_read():
    # 0.3s: 부드러운 한 음 (C6) 페이드.
    return render(0.3, segment(0.0, 0.3, lambda u: tone(u, 1046.5, (1, 0.2)) * (1 - u * 2.5)))


def choice_ok():
    # 0.6s: 올라가는 세 음 (C6 E6 G6).
    return render(0.6, mix(
        segment(0.0, 0.16, lambda u: tone(u, 1046.5, (1, 0.3))),
        segment(0.15, 0.16, lambda u: tone(u, 1318.5, (1, 0.3))),
        segment(0.30, 0.30, lambda u: tone(u, 1568.0, (1, 0.3)) * (1 - u * 2)),
    ))


def choice_fail():
    # 0.6s: 내려가는 두 음, 살짝 탁한 배음 (A4 → E4).
    return render(0.6, mix(
        segment(0.0, 0.22, lambda u: tone(u, 440.0, (1, 0.6, 0.3))),
        segment(0.24, 0.36, lambda u: tone(u, 329.6, (1, 0.6, 0.3)) * (1 - u * 1.8)),
    ))


def summary():
    # 0.8s: 정산 카드. 화음 (C5+E5+G5) 페이드 인·아웃.
    return render(0.8, segment(0.0, 0.8, lambda u: (
        tone(u, 523.3) + tone(u, 659.3) + tone(u, 784.0)
    ) / 3 * math.sin(math.pi * u / 0.8)))


def ending():
    # 2.5s: 종 같은 긴 두 음 (C6 → G6), 긴 릴리스.
    def bell(u: float, f: float) -> float:
        return tone(u, f, (1, 0.5, 0.25, 0.1)) * math.exp(-u * 1.6)

    return render(2.5, mix(
        segment(0.0, 2.4, lambda u: bell(u, 1046.5)),
        segment(0.5, 2.0, lambda u: bell(u, 1568.0) * 0.8),
    ))


def day_start():
    # 0.7s: 아침. 올라가는 두 음 (G5 → D6), 부드럽게.
    return render(0.7, mix(
        segment(0.0, 0.3, lambda u: tone(u, 784.0, (1, 0.2)) * (1 - u)),
        segment(0.25, 0.45, lambda u: tone(u, 1174.7, (1, 0.2)) * (1 - u * 1.5)),
    ))


CUES = {
    "msg_in": msg_in,
    "call_ring": call_ring,
    "call_connect": call_connect,
    "call_end": call_end,
    "msg_out": msg_out,
    "wait_read": wait_read,
    "choice_ok": choice_ok,
    "choice_fail": choice_fail,
    "summary": summary,
    "ending": ending,
    "day_start": day_start,
}


def main() -> None:
    for name, fn in CUES.items():
        write(name, normalize(fn()))


if __name__ == "__main__":
    main()
