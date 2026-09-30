#!/usr/bin/env python3
"""모쏠 탈출기 효과음 11개를 처음부터 합성한다 (docs/overhaul/05_audio_haptics.md §1·§3).

외부 소리·샘플·다운로드를 전혀 쓰지 않는다. 파이썬 표준 라이브러리(math·random·wave·struct)만으로
사인 부분음을 쌓아 만든 완전한 창작물이다. 같은 코드는 언제 돌려도 비트 단위로 같은 파일을 낸다
(잡음은 큐마다 고정 시드).

    python3 tool/make_sfx.py            # assets/sfx/<큐 id>.wav 11개를 다시 만든다
    python3 tool/make_sfx.py msg_in     # 하나만
    python3 tool/make_sfx.py --check    # 만들지 않고 지금 파일의 길이·피크·라우드니스만 잰다

출력 규격(코드가 그대로 읽는 형식, 바꾸지 말 것): WAV PCM 16-bit, 44.1kHz, mono.

소리 설계 도구 상자
- 벨/틴/마림바 음색: 조화·비조화 부분음(예: 1 · 2.76 · 5.40 배)을 각자 다른 감쇠로 쌓는다.
  높은 부분음일수록 빨리 사라져 "딩" 하고 둥글게 남는다. 부분음마다 ±몇 cent 겹친 쌍을 둬
  살짝 맥놀이(코러스)가 생기게 해 사인파 특유의 납작함을 없앤다.
- 말렛 트랜지언트: 대역 통과한 잡음을 1~3ms 만 섞어 "톡" 하는 접촉감을 준다.
- 피치 스윕·포르타멘토·비브라토: 위상 누적 오실레이터로 클릭 없이 음높이를 움직인다.
- 시간 변화 저역 통과: 실패음처럼 음색이 "닫히는" 느낌을 낸다.
- 잔향: 모노 Schroeder/Freeverb 형(댐핑 콤 4 + 올패스 2). 짧은 방 크기, 젖음 6~25%.
- 마무리: 20Hz 직류 제거 → 앞뒤 페이드(클릭 방지) → ITU-R BS.1770 K-가중 라우드니스를
  목표치로 맞춤 → 룩어헤드 피크 리미터(최대 6dB 감쇠)로 샘플 피크 -1.5 dBFS 이하(트루 피크
  -1 dBTP 여유) → 16-bit 로 저장.

라우드니스 목표(05 §3 의 위계를 유지하되 폰 스피커에서 들리게 끌어올림):
    P0·P1 큐 -16 LUFS, 자주 나는 P2 큐(msg_out·wait_read — 미니게임 탭/스텝에도 쓰임) -18 LUFS.
    0.4초보다 짧은 파일은 BS.1770 블록 하나(파일 전체)로 잰다.

call_ring 은 ReleaseMode.loop 로 반복되므로 3.0초 안에서 무음으로 시작해 잔향까지 완전히
끝난 뒤 무음으로 닫힌다 — 이음매에 틈·클릭이 없다.
"""
from __future__ import annotations

import math
import os
import random
import struct
import sys
import wave

RATE = 44100
TAU = 2 * math.pi
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sfx")

CEILING_DB = -1.5  # 샘플 피크 상한. 트루 피크 -1 dBTP 에 0.5dB 여유.
MAX_GR_DB = 6.0  # 리미터가 깎아도 되는 최대치. 넘으면 목표 라우드니스보다 조용하게 둔다.


# ---------------------------------------------------------------------------
# 기본 부품
# ---------------------------------------------------------------------------


def silence(dur: float) -> list[float]:
    return [0.0] * int(round(RATE * dur))


def add(dst: list[float], src: list[float], at: float, gain: float = 1.0) -> None:
    """src 를 dst 의 at 초 위치에 더한다. 넘치는 뒷부분은 버린다."""
    o = int(round(at * RATE))
    n = min(len(src), len(dst) - o)
    for i in range(max(0, n)):
        dst[o + i] += src[i] * gain


def cents(c: float) -> float:
    return 2 ** (c / 1200)


def note(name: str) -> float:
    """'C6', 'F#5' → Hz (A4 = 440)."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semi = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        semi += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        semi -= 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semi + 12 * (octave - 4)) / 12)


def attack_curve(t: float, attack: float) -> float:
    """반코사인 어택. 0 에서 1 로 매끄럽게(클릭 없음)."""
    if t >= attack:
        return 1.0
    return 0.5 - 0.5 * math.cos(math.pi * t / attack)


# 음색 = [(주파수 배수, 진폭, 감쇠 배수)]. 감쇠 배수는 기본 tau 에 곱한다(작을수록 빨리 사라짐).
TINE = [(1.0, 1.0, 1.0), (2.0, 0.16, 0.55), (5.40, 0.07, 0.22), (8.93, 0.025, 0.12)]  # 오르골·칼림바
GLASS = [(1.0, 1.0, 1.0), (2.76, 0.20, 0.40), (5.40, 0.07, 0.18), (8.93, 0.02, 0.10)]  # 유리잔 톡
WOOD = [(1.0, 1.0, 1.0), (3.93, 0.22, 0.30), (9.2, 0.05, 0.12)]  # 부드러운 나무 막대
WARM = [(1.0, 1.0, 1.0), (2.0, 0.28, 0.6), (3.0, 0.09, 0.4), (4.0, 0.03, 0.3)]  # 둥근 배음


def struck(freq: float, tau: float, timbre=TINE, dur: float | None = None, attack: float = 0.0015,
           detune: float = 3.0, phase_seed: int = 0) -> list[float]:
    """친 소리(벨·틴·마림바). 부분음마다 지수 감쇠, ±detune cent 쌍으로 은은한 맥놀이."""
    if dur is None:
        dur = tau * 7
    n = int(RATE * dur)
    out = [0.0] * n
    rng = random.Random(phase_seed)
    for ratio, amp, dmul in timbre:
        f = freq * ratio
        if f > RATE * 0.45:
            continue
        t_k = tau * dmul
        # 이 부분음이 -80dB 아래로 떨어지면 계산을 멈춘다.
        m = min(n, int(RATE * t_k * 9.2) + 1)
        pairs = ((cents(-detune), 0.5), (cents(detune), 0.5)) if detune else ((1.0, 1.0),)
        for dmul_f, share in pairs:
            w = TAU * f * dmul_f / RATE
            ph = rng.random() * TAU
            a = amp * share
            k = math.exp(-1.0 / (RATE * t_k))
            e = 1.0
            for i in range(m):
                out[i] += a * e * math.sin(w * i + ph)
                e *= k
    na = int(RATE * attack)
    for i in range(min(na, n)):
        out[i] *= attack_curve(i / RATE, attack)
    return out


def osc(freq_fn, amp_fn, dur: float, harmonics=((1, 1.0),), phase: float = 0.0) -> list[float]:
    """위상 누적 오실레이터. freq_fn(t)·amp_fn(t) 로 스윕·비브라토·엔벨로프를 자유롭게."""
    n = int(RATE * dur)
    out = [0.0] * n
    ph = phase
    for i in range(n):
        t = i / RATE
        s = 0.0
        for h, a in harmonics:
            s += a * math.sin(ph * h)
        out[i] = s * amp_fn(t)
        ph += TAU * freq_fn(t) / RATE
    return out


def biquad(x: list[float], kind: str, fc: float, q: float = 0.707) -> list[float]:
    """RBJ 쿡북 2차 필터: lowpass · highpass · bandpass(피크 0dB)."""
    w0 = TAU * fc / RATE
    cw, sw = math.cos(w0), math.sin(w0)
    al = sw / (2 * q)
    if kind == "lowpass":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    elif kind == "highpass":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    elif kind == "bandpass":
        b0, b1, b2 = al, 0.0, -al
    else:
        raise ValueError(kind)
    a0, a1, a2 = 1 + al, -2 * cw, 1 - al
    return _biquad_raw(x, b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)


def _biquad_raw(x, b0, b1, b2, a1, a2):
    y = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, v
        y2, y1 = y1, o
        y[i] = o
    return y


def noise(dur: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(int(RATE * dur))]


def mallet(center: float, tau: float = 0.0015, seed: int = 1, q: float = 1.2) -> list[float]:
    """접촉 트랜지언트. 대역 통과 잡음에 아주 빠른 감쇠."""
    x = biquad(noise(tau * 8, seed), "bandpass", center, q)
    k = math.exp(-1.0 / (RATE * tau))
    e = 1.0
    for i in range(len(x)):
        x[i] *= e
        e *= k
    return x


def env_apply(x: list[float], fn) -> list[float]:
    return [v * fn(i / RATE) for i, v in enumerate(x)]


def lowpass_sweep(x: list[float], fc_fn) -> list[float]:
    """시간에 따라 차단 주파수가 움직이는 2단 1차 저역 통과(12dB/oct)."""
    y = [0.0] * len(x)
    s1 = s2 = 0.0
    for i, v in enumerate(x):
        g = 1 - math.exp(-TAU * fc_fn(i / RATE) / RATE)
        s1 += g * (v - s1)
        s2 += g * (s1 - s2)
        y[i] = s2
    return y


def reverb(x: list[float], wet: float, room: float = 0.5, damp: float = 0.35, tail: float = 0.0) -> list[float]:
    """모노 Freeverb 형 잔향. room 0~1 은 피드백(잔향 길이), 콤 지연은 25~31ms 대.

    tail 초만큼 뒤를 늘려 잔향이 잘리지 않게 할 수 있다(호출부에서 길이를 다시 자름).
    """
    x = x + [0.0] * int(RATE * tail)
    combs = [1116, 1188, 1277, 1356]
    aps = [556, 441]
    fb = 0.70 + 0.28 * room
    wet_sig = [0.0] * len(x)
    for d in combs:
        buf = [0.0] * d
        idx = 0
        store = 0.0
        for i, v in enumerate(x):
            o = buf[idx]
            store = o * (1 - damp) + store * damp
            buf[idx] = v + store * fb
            idx += 1
            if idx == d:
                idx = 0
            wet_sig[i] += o
    for d in aps:
        buf = [0.0] * d
        idx = 0
        for i, v in enumerate(wet_sig):
            b = buf[idx]
            o = -v + b
            buf[idx] = v + b * 0.5
            idx += 1
            if idx == d:
                idx = 0
            wet_sig[i] = o
    g = wet * 0.25  # 콤 4개 합 정규화
    return [v * (1 - wet) + w * g for v, w in zip(x, wet_sig)]


# ---------------------------------------------------------------------------
# 마무리: 직류 제거 · 페이드 · 라우드니스 · 리미터
# ---------------------------------------------------------------------------


def _k_weight(x: list[float]) -> list[float]:
    """ITU-R BS.1770-4 K 가중(고역 쉘프 + RLB 고역 통과), 44.1kHz 용 계수 계산."""
    # 고역 쉘프
    G, Q, fc = 3.999843853973347, 0.7071752369554196, 1681.974450955533
    A = 10 ** (G / 40)
    w0 = TAU * fc / RATE
    cw, al = math.cos(w0), math.sin(w0) / (2 * Q)
    sa = 2 * math.sqrt(A) * al
    b0 = A * ((A + 1) + (A - 1) * cw + sa)
    b1 = -2 * A * ((A - 1) + (A + 1) * cw)
    b2 = A * ((A + 1) + (A - 1) * cw - sa)
    a0 = (A + 1) - (A - 1) * cw + sa
    a1 = 2 * ((A - 1) - (A + 1) * cw)
    a2 = (A + 1) - (A - 1) * cw - sa
    y = _biquad_raw(x, b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)
    # 고역 통과
    Q, fc = 0.5003270373238773, 38.13547087602444
    w0 = TAU * fc / RATE
    cw, al = math.cos(w0), math.sin(w0) / (2 * Q)
    a0 = 1 + al
    return _biquad_raw(y, (1 + cw) / 2 / a0, -(1 + cw) / a0, (1 + cw) / 2 / a0, -2 * cw / a0, (1 - al) / a0)


def lufs(x: list[float]) -> float:
    """BS.1770 통합 라우드니스(모노). 400ms 블록 75% 겹침, 절대 -70 · 상대 -10 LU 게이트.
    파일이 400ms 보다 짧으면 파일 전체를 블록 하나로 본다."""
    y = _k_weight(x)
    sq = [v * v for v in y]
    blk = int(0.4 * RATE)
    hop = int(0.1 * RATE)
    if len(sq) <= blk:
        blocks = [sum(sq) / max(1, len(sq))]
    else:
        blocks = []
        acc = sum(sq[:blk])
        start = 0
        blocks.append(acc / blk)
        while start + hop + blk <= len(sq):
            acc += sum(sq[start + blk:start + blk + hop]) - sum(sq[start:start + hop])
            start += hop
            blocks.append(acc / blk)

    def ld(ms):
        return -0.691 + 10 * math.log10(ms) if ms > 0 else -200.0

    gated = [b for b in blocks if ld(b) > -70]
    if not gated:
        return -200.0
    rel = ld(sum(gated) / len(gated)) - 10
    gated = [b for b in gated if ld(b) > rel]
    return ld(sum(gated) / len(gated))


def limiter(x: list[float], ceiling: float, lookahead: float = 0.0015, release: float = 0.06) -> list[float]:
    """룩어헤드 피크 리미터(오프라인). 앞을 내다본 최소 게인 → 릴리스 → 박스 평활.
    박스 길이 = 룩어헤드이므로 어떤 샘플도 ceiling 을 넘지 않으면서 게인이 부드럽게 움직인다."""
    n = len(x)
    L = max(1, int(RATE * lookahead))
    req = [min(1.0, ceiling / abs(v)) if v else 1.0 for v in x]
    # 전방 슬라이딩 최소 m[i] = min(req[i..i+L])  (단조 덱)
    from collections import deque
    m = [1.0] * n
    dq: deque[int] = deque()
    j = 0
    for i in range(n):
        while j < n and j <= i + L:
            while dq and req[dq[-1]] >= req[j]:
                dq.pop()
            dq.append(j)
            j += 1
        while dq[0] < i:
            dq.popleft()
        m[i] = req[dq[0]]
    c = 1 - math.exp(-1.0 / (RATE * release))
    r = 1.0
    for i in range(n):
        r = min(m[i], r + (1 - r) * c)
        m[i] = r
    out = [0.0] * n
    acc = 0.0
    for i in range(n):
        acc += m[i]
        if i >= L:
            acc -= m[i - L]
        g = acc / min(i + 1, L)
        out[i] = x[i] * g
    return out


def finish(x: list[float], dur: float, target_lufs: float, fade_in: float = 0.001, fade_out: float = 0.03):
    """길이 맞춤 → 직류 제거 → 페이드 → 라우드니스 정규화 → 리미터. (samples, 정보) 반환."""
    n = int(round(RATE * dur))
    x = (x + [0.0] * n)[:n]
    x = biquad(x, "highpass", 20.0, 0.707)
    fi, fo = int(RATE * fade_in), int(RATE * fade_out)
    for i in range(fi):
        x[i] *= attack_curve(i / RATE, fade_in)
    for i in range(fo):
        x[n - 1 - i] *= 0.5 - 0.5 * math.cos(math.pi * i / fo)
    x[0] = 0.0
    x[-1] = 0.0
    ceiling = 10 ** (CEILING_DB / 20)
    peak = max(abs(v) for v in x)
    loud = lufs(x)
    gain = 10 ** ((target_lufs - loud) / 20)
    gain = min(gain, ceiling / peak * 10 ** (MAX_GR_DB / 20))
    y = limiter([v * gain for v in x], ceiling)
    return y


def write(name: str, samples: list[float]) -> str:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{name}.wav")
    ints = []
    for s in samples:
        v = int(round(max(-1.0, min(1.0, s)) * 32767))
        ints.append(v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(struct.pack("<%dh" % len(ints), *ints))
    return path


def read(path: str) -> list[float]:
    with wave.open(path, "rb") as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2 and w.getframerate() == RATE, path
        raw = w.readframes(w.getnframes())
    return [v / 32768 for v in struct.unpack("<%dh" % (len(raw) // 2), raw)]


# ---------------------------------------------------------------------------
# 큐 — 톤: 가볍다 · 진짜 같다 · 짧다. 귀엽고 포근한 메신저 느낌, 날카로움 없음.
# ---------------------------------------------------------------------------

P01 = -16.0
P2 = -18.0


def msg_in():
    """문자 도착 "띠링". D6 → A6 오르골 틴 두 음(완전5도) + A5 나무 몸통 + 말렛 톡 + 작은 방."""
    x = silence(0.45)
    add(x, mallet(3200, seed=11), 0.0, 0.10)
    add(x, struck(note("D6"), 0.055, TINE, phase_seed=1), 0.0, 0.55)
    add(x, mallet(4200, seed=12), 0.075, 0.08)
    add(x, struck(note("A6"), 0.11, TINE, phase_seed=2), 0.075, 0.75)
    add(x, struck(note("A5"), 0.07, WOOD, phase_seed=3), 0.075, 0.28)
    x = reverb(x, wet=0.14, room=0.35)
    return finish(x, 0.42, P01, fade_out=0.05)


def msg_out():
    """내 말 전송 "뽁". 물방울 같은 사인 버블: 430→1150Hz 지수 스윕, 빠른 감쇠, 톡 트랜지언트."""
    dur = 0.13

    def f(t):
        return 430 * (1150 / 430) ** min(1.0, t / 0.045)

    def a(t):
        return attack_curve(t, 0.002) * math.exp(-t / 0.028)

    x = osc(f, a, dur, harmonics=((1, 1.0), (2, 0.12)))
    add(x, mallet(2600, tau=0.0010, seed=21), 0.0, 0.06)
    x = reverb(x, wet=0.06, room=0.2)
    return finish(x, dur, P2, fade_out=0.02)


def wait_read():
    """읽음 "틱". 유리잔을 살짝 두드린 E6 한 음 + 한 옥타브 아래 부드러운 몸통."""
    x = silence(0.3)
    add(x, mallet(5200, tau=0.001, seed=31), 0.0, 0.05)
    add(x, struck(note("E6"), 0.06, GLASS, phase_seed=4), 0.0, 0.8)
    add(x, struck(note("E5"), 0.045, WARM, phase_seed=5), 0.0, 0.22)
    x = reverb(x, wet=0.12, room=0.3)
    return finish(x, 0.3, P2, fade_out=0.05)


def call_connect():
    """전화 받음 "뾱뾱↑". C6 → G6 둥근 블립 두 개, 각 음이 -35 cent 아래서 살짝 떠오른다."""
    x = silence(0.22)
    for at, nm in ((0.0, "C6"), (0.065, "G6")):
        f0 = note(nm)
        blip = osc(lambda t, f0=f0: f0 * cents(-35 * math.exp(-t / 0.008)),
                   lambda t: attack_curve(t, 0.003) * math.exp(-t / 0.04),
                   0.2, harmonics=((1, 1.0), (2, 0.18), (3, 0.05)))
        add(x, blip, at, 0.8)
    x = reverb(x, wet=0.1, room=0.25)
    return finish(x, 0.22, P01, fade_out=0.04)


def call_end():
    """통화 끝 "또-동↓". G5 → C5 둥근 두 음, 두 번째 음은 끝이 -40 cent 가라앉는다. 미니게임 시간 경고에도 쓰임."""
    x = silence(0.5)
    g5, c5 = note("G5"), note("C5")
    add(x, osc(lambda t: g5, lambda t: attack_curve(t, 0.004) * math.exp(-t / 0.07), 0.3,
               harmonics=((1, 1.0), (2, 0.25), (3, 0.07))), 0.0, 0.75)
    add(x, osc(lambda t: c5 * cents(-40 * min(1.0, t / 0.3)),
               lambda t: attack_curve(t, 0.005) * math.exp(-t / 0.12), 0.36,
               harmonics=((1, 1.0), (2, 0.25), (3, 0.07))), 0.13, 0.85)
    add(x, mallet(1800, tau=0.0015, seed=41), 0.0, 0.05)
    add(x, mallet(1400, tau=0.0015, seed=42), 0.13, 0.05)
    x = reverb(x, wet=0.12, room=0.3)
    return finish(x, 0.5, P01, fade_out=0.08)


def choice_ok():
    """선택 성공 "또로링✨". C6-E6-G6 오르골 아르페지오 + C7 FM 벨 + 시드 고정 반짝이(펜타토닉 고음)."""
    x = silence(0.62)
    for k, (at, nm, tau) in enumerate(((0.0, "C6", 0.09), (0.065, "E6", 0.09), (0.13, "G6", 0.18))):
        add(x, mallet(3200 + 300 * k, seed=51 + k), at, 0.04)
        add(x, struck(note(nm), tau, TINE, phase_seed=60 + k), at, 0.6)
    # 맨 위 C7: 비조화 FM 벨(반송:변조 = 1:3.5, 변조 지수가 감쇠) — 반짝이는 금속성, 아주 작게.
    c7 = note("C7")
    n = int(RATE * 0.4)
    bell = [0.0] * n
    for i in range(n):
        t = i / RATE
        idx = 0.7 * math.exp(-t / 0.05)
        bell[i] = math.sin(TAU * c7 * t + idx * math.sin(TAU * c7 * 3.5 * t)) * math.exp(-t / 0.13) * attack_curve(t, 0.002)
    add(x, bell, 0.195, 0.28)
    # 반짝이 버스: 펜타토닉 고음 틴 다섯 알을 따로 모아 6kHz 저역 통과 — 쨍하지 않게.
    rng = random.Random(59)
    penta = ["C", "D", "E", "G", "A"]
    glitter = silence(0.62)
    for j in range(5):
        at = 0.21 + j * 0.045 + rng.uniform(0, 0.015)
        nm = penta[rng.randrange(5)] + "7"
        add(glitter, struck(note(nm), 0.035, TINE, phase_seed=70 + j), at, 0.09 * (1 - j * 0.12))
    add(x, biquad(biquad(glitter, "lowpass", 6000), "lowpass", 6000), 0.0)
    x = reverb(x, wet=0.2, room=0.45)
    return finish(x, 0.62, P01, fade_out=0.12)


def choice_fail():
    """선택 실패 "뽀옹↓". D5 → A4 둥근 삼각파풍 두 음. 두 번째 음은 한 반음 늘어지듯 내려가며
    6Hz 비브라토, 음색은 저역 통과가 닫혀 바람 빠지듯 — 아프지 않고 귀엽게 아쉬운 소리."""
    x = silence(0.62)
    tri = ((1, 1.0), (2, 0.10), (3, 0.11), (5, 0.04))
    d5, a4 = note("D5"), note("A4")
    first = osc(lambda t: d5, lambda t: attack_curve(t, 0.006) * math.exp(-t / 0.09), 0.2, tri)
    add(x, lowpass_sweep(first, lambda t: 3500 - 1500 * min(1.0, t / 0.15)), 0.0, 0.8)
    second = osc(lambda t: a4 * cents(-100 * min(1.0, t / 0.34) ** 1.5 + 14 * math.sin(TAU * 6 * t) * min(1.0, t / 0.1)),
                 lambda t: attack_curve(t, 0.008) * math.exp(-t / 0.2), 0.45, tri)
    add(x, lowpass_sweep(second, lambda t: 3000 * math.exp(-t / 0.18) + 700), 0.14, 1.0)
    add(x, mallet(1200, tau=0.002, seed=81, q=0.9), 0.0, 0.04)
    x = reverb(x, wet=0.1, room=0.3)
    return finish(x, 0.62, P01, fade_out=0.1)


def summary():
    """하루 정산 카드 "포옥~". Fmaj7(F5 A5 C6 E6) 코러스 패드가 부드럽게 부풀고, A6 오르골 한 음이 얹힌다."""
    dur = 0.8
    x = silence(dur)
    rng = random.Random(91)
    for nm in ("F5", "A5", "C6", "E6"):
        f0 = note(nm)
        for dc in (-5, 5):
            pad = osc(lambda t, f=f0 * cents(dc): f,
                      lambda t: attack_curve(t, 0.14) * (1 - max(0.0, t - 0.25) / 0.55) ** 2,
                      dur, harmonics=((1, 1.0), (2, 0.12)), phase=rng.random() * TAU)
            add(x, pad, 0.0, 0.11)
    add(x, mallet(3800, seed=92), 0.02, 0.05)
    add(x, struck(note("A6"), 0.14, TINE, phase_seed=93), 0.02, 0.45)
    add(x, struck(note("E7"), 0.06, GLASS, phase_seed=94), 0.1, 0.08)
    x = reverb(x, wet=0.22, room=0.5)
    return finish(x, dur, P01, fade_out=0.15)


def ending():
    """엔딩 "오르골 피날레". C6-E6-G6-C7 오르골 아르페지오 → C7 FM 벨 반짝임, 그 밑에서 C5·G5·E6 패드가
    천천히 피어나 넓은 잔향으로 사라진다. 2.5초 안에 완전히 닫힌다."""
    dur = 2.5
    x = silence(dur)
    for k, (at, nm, tau) in enumerate(((0.0, "C6", 0.35), (0.16, "E6", 0.35), (0.32, "G6", 0.4), (0.50, "C7", 0.6))):
        add(x, mallet(3400 + 300 * k, seed=101 + k), at, 0.05)
        add(x, struck(note(nm), tau, TINE, dur=2.2, phase_seed=110 + k), at, 0.42)
    c7 = note("C7")
    n = int(RATE * 1.6)
    bell = [0.0] * n
    for i in range(n):
        t = i / RATE
        idx = 0.8 * math.exp(-t / 0.12)
        bell[i] = math.sin(TAU * c7 * t + idx * math.sin(TAU * c7 * 3.5 * t)) * math.exp(-t / 0.35) * attack_curve(t, 0.003)
    add(x, bell, 0.5, 0.12)
    rng = random.Random(119)
    for nm, lvl in (("C5", 0.11), ("G5", 0.09), ("E6", 0.06)):
        f0 = note(nm)
        for dc in (-4, 4):
            pad = osc(lambda t, f=f0 * cents(dc): f * cents(4 * math.sin(TAU * 4.5 * t) * min(1.0, t / 0.8)),
                      lambda t: attack_curve(t, 0.55) * math.exp(-max(0.0, t - 0.6) / 0.45),
                      dur - 0.4, harmonics=((1, 1.0), (2, 0.08)), phase=rng.random() * TAU)
            add(x, pad, 0.4, lvl)
    x = reverb(x, wet=0.28, room=0.6, damp=0.45)
    return finish(x, dur, P01, fade_out=0.35)


def day_start():
    """새 아침 "휘리~". 바람결 같은 대역 잡음이 부풀고, G5 에서 D6 으로 미끄러져 오르는 부드러운 휘파람
    (느린 어택·비브라토), 꼭대기에서 D7 틴 하나가 반짝."""
    dur = 0.7
    x = silence(dur)
    air = biquad(noise(dur, 131), "bandpass", 5500, 0.8)
    air = env_apply(air, lambda t: math.sin(math.pi * min(1.0, t / 0.6)) ** 2)
    add(x, air, 0.0, 0.05)
    g5, d6 = note("G5"), note("D6")

    def f(t):
        u = min(1.0, max(0.0, (t - 0.12) / 0.14))
        glide = 0.5 - 0.5 * math.cos(math.pi * u)
        base = g5 * (d6 / g5) ** glide
        return base * cents(10 * math.sin(TAU * 5.5 * t) * min(1.0, t / 0.3))

    whistle = osc(f, lambda t: attack_curve(t, 0.05) * (1 - max(0.0, t - 0.3) / 0.35) ** 2,
                  0.65, harmonics=((1, 1.0), (2, 0.06), (3, 0.03)))
    add(x, whistle, 0.02, 0.55)
    add(x, struck(note("D7"), 0.07, GLASS, phase_seed=132), 0.27, 0.16)
    add(x, struck(note("G6"), 0.09, TINE, phase_seed=133), 0.27, 0.22)
    x = reverb(x, wet=0.2, room=0.45)
    return finish(x, dur, P01, fade_in=0.004, fade_out=0.12)


def call_ring():
    """전화 벨 3.0초 루프 "도르르르— 도르르르—". E6/C6 오르골 트릴(12.5음/초)을 0.9초씩 두 번,
    묶음마다 살짝 부풀었다 가라앉는 셈여림. 무음 0.1s 로 시작하고 2.2s 뒤 잔향이 다 사라진 뒤 무음으로 닫힌다."""
    dur = 3.0
    x = silence(dur)
    e6, c6 = note("E6"), note("C6")
    step = 0.08
    for start in (0.10, 1.30):
        for k in range(12):
            t_rel = k * step
            shape = 0.75 + 0.25 * math.sin(math.pi * t_rel / 0.9)
            f0 = e6 if k % 2 == 0 else c6
            add(x, struck(f0, 0.05, TINE, dur=0.35, phase_seed=140 + k), start + t_rel, 0.6 * shape)
            add(x, mallet(3600, tau=0.001, seed=150 + k), start + t_rel, 0.04 * shape)
        # 묶음 밑을 받치는 C5 나무 몸통(묶음 머리에 한 번)
        add(x, struck(note("C5"), 0.12, WOOD, dur=0.6, phase_seed=160), start, 0.22)
    x = reverb(x, wet=0.1, room=0.3)
    y = finish(x, dur, P01, fade_in=0.001, fade_out=0.3)
    return y


CUES = {
    "msg_in": msg_in,
    "msg_out": msg_out,
    "wait_read": wait_read,
    "call_ring": call_ring,
    "call_connect": call_connect,
    "call_end": call_end,
    "choice_ok": choice_ok,
    "choice_fail": choice_fail,
    "summary": summary,
    "ending": ending,
    "day_start": day_start,
}


def report(name: str, x: list[float]) -> str:
    peak = max(abs(v) for v in x) or 1e-9
    return (f"{name:13s} {len(x) / RATE:5.2f}s  peak {20 * math.log10(peak):6.2f} dBFS  "
            f"{lufs(x):6.1f} LUFS  first/last {x[0]:+.4f}/{x[-1]:+.4f}")


def main(argv: list[str]) -> None:
    check = "--check" in argv
    names = [a for a in argv if not a.startswith("--")] or list(CUES)
    for name in names:
        if name not in CUES:
            sys.exit(f"알 수 없는 큐: {name}  (가능: {', '.join(CUES)})")
        if check:
            x = read(os.path.join(OUT, f"{name}.wav"))
        else:
            x = CUES[name]()
            write(name, x)
            x = read(os.path.join(OUT, f"{name}.wav"))
        print(report(name, x))


if __name__ == "__main__":
    main(sys.argv[1:])
