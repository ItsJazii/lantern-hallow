"""Synthesizes Lantern Hollow's placeholder audio (original, script-generated).

Writes 16-bit WAVs into game/assets/audio/. Everything here is procedural, so
there are no third-party licenses involved. Replace any file with a recorded or
composed clip of the same name and the game picks it up automatically.

    python tools/gen_audio.py
"""
from pathlib import Path
import wave

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "audio"
rng = np.random.default_rng(7)


# --- primitives ----------------------------------------------------------------

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def band(x, lo, hi):
    """Brick-wall-ish band filter with soft edges via FFT (circular)."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    lo_w = 1 / (1 + np.exp(-(f - lo) / max(lo * 0.15, 5)))
    hi_w = 1 / (1 + np.exp((f - hi) / max(hi * 0.15, 5)))
    return np.fft.irfft(spec * lo_w * hi_w, n=len(x))


def noise(dur, lo=20, hi=20000):
    return band(rng.standard_normal(int(dur * SR)), lo, hi)


def adsr(n, a=0.005, d=0.2, curve=1.0):
    t = np.arange(n) / SR
    env = np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-np.maximum(t - a, 0) / max(d, 1e-4) * curve)
    return env


def glide(f0, f1, dur, shape="exp"):
    n = int(dur * SR)
    if shape == "exp":
        f = f0 * (f1 / f0) ** np.linspace(0, 1, n)
    else:
        f = np.linspace(f0, f1, n)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def bell(freq, dur, decay=0.8, partials=((1, 1.0), (2.76, 0.35), (5.4, 0.12), (8.9, 0.04))):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, amp in partials:
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / (decay / ratio ** 0.6))
    return out * (1 - np.exp(-t / 0.002))


def piano(freq, dur, vel=0.7):
    """Soft felt-piano-ish tone: few harmonics, fast-ish decay, felt thump."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for k, a in ((1, 1.0), (2, 0.42), (3, 0.16), (4, 0.07), (5, 0.03)):
        inharm = 1 + 0.0003 * k * k
        out += a * np.sin(2 * np.pi * freq * k * inharm * t + rng.uniform(0, 6.28)) * np.exp(-t * (0.9 + 0.7 * k))
    out *= 1 - np.exp(-t / 0.006)
    thump = band(rng.standard_normal(len(t)), 60, 900) * np.exp(-t / 0.015) * 0.06
    return (out + thump) * vel


def pluck(freq, dur, vel=0.5, damping=0.996):
    """Karplus-Strong plucked string."""
    n = int(dur * SR)
    period = int(SR / freq)
    buf = band(rng.standard_normal(period * 4), 100, 4000)[:period]
    out = np.zeros(n)
    for i in range(n):
        v = buf[i % period]
        out[i] = v
        buf[i % period] = damping * 0.5 * (v + buf[(i + 1) % period])
    return out * vel / (np.max(np.abs(out)) + 1e-9)


def place(dst, src, at, gain=1.0, circular=False):
    i = int(at * SR)
    if circular:
        idx = (np.arange(len(src)) + i) % len(dst)
        np.add.at(dst, idx, src * gain)
    else:
        end = min(len(dst), i + len(src))
        if i < len(dst):
            dst[i:end] += src[: end - i] * gain


def reverb(x, seconds=2.2, wet=0.25, circular=False, seed=1):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    ir = r.standard_normal(n) * np.exp(-np.arange(n) / SR / (seconds / 6.5))
    ir = band(ir, 200, 7000)
    ir /= np.sqrt(np.sum(ir ** 2))
    if circular:
        L = len(x)
        irp = np.zeros(L)
        irp[: min(n, L)] = ir[: min(n, L)]
        y = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(irp), n=L)
    else:
        L = len(x) + n
        y = np.fft.irfft(np.fft.rfft(x, L) * np.fft.rfft(ir, L), n=L)
        x = np.pad(x, (0, n))
    return x * (1 - wet) + y * wet


def fade(x, fin=0.003, fout=0.02):
    x = x.copy()
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def normalize(x, peak_db=-3.0):
    peak = np.max(np.abs(x)) + 1e-9
    return x * (10 ** (peak_db / 20) / peak)


def write(name, x, peak_db=-3.0, stereo=None):
    OUT.mkdir(parents=True, exist_ok=True)
    if stereo is not None:
        left, right = x, stereo
        g = 10 ** (peak_db / 20) / (max(np.max(np.abs(left)), np.max(np.abs(right))) + 1e-9)
        data = np.stack([left * g, right * g], axis=1)
        channels = 2
    else:
        data = normalize(x, peak_db)
        channels = 1
    pcm = np.clip(data * 32767, -32768, 32767).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("wrote", name)


# --- one-shot effects ------------------------------------------------------------

def footsteps():
    for i in range(1, 4):
        d = 0.16
        g = noise(d, 250 + i * 40, 2600 - i * 200) * adsr(int(d * SR), 0.004, 0.03)
        g += noise(d, 80, 300) * adsr(int(d * SR), 0.002, 0.02) * 0.6
        write(f"step_grass_{i}", fade(g), -6)
        s = noise(d, 900 + i * 150, 7000) * adsr(int(d * SR), 0.001, 0.018)
        s += np.sin(2 * np.pi * (110 + i * 12) * t_axis(d)) * adsr(int(d * SR), 0.001, 0.025) * 0.5
        write(f"step_stone_{i}", fade(s), -6)
        w = np.sin(2 * np.pi * (125 + i * 15) * t_axis(d)) * adsr(int(d * SR), 0.002, 0.05)
        w += noise(d, 350, 2200) * adsr(int(d * SR), 0.001, 0.02) * 0.5
        write(f"step_wood_{i}", fade(w), -6)


def ui_sounds():
    t = t_axis(0.09)
    blip = np.sin(2 * np.pi * 760 * t) * adsr(len(t), 0.004, 0.035) + 0.3 * np.sin(2 * np.pi * 1520 * t) * adsr(len(t), 0.003, 0.02)
    write("blip", fade(blip), -9)
    t = t_axis(0.06)
    write("ui_tick", fade(np.sin(2 * np.pi * 1250 * t) * adsr(len(t), 0.001, 0.012)), -10)


def chimes():
    x = np.zeros(int(1.4 * SR))
    for k, n in enumerate((84, 88, 91)):
        place(x, bell(midi(n), 1.1, 0.5), k * 0.07, 0.6)
    write("leaf_pickup", fade(reverb(x, 1.6, 0.25)), -5)

    x = np.zeros(int(3.0 * SR))
    for k, n in enumerate((53, 57, 60, 65, 69)):
        place(x, piano(midi(n), 2.6, 0.7), k * 0.075)
    place(x, bell(midi(81), 2.0, 0.9), 0.35, 0.18)
    write("quest_complete", fade(reverb(x, 2.4, 0.3)), -4)

    x = np.zeros(int(1.0 * SR))
    place(x, bell(1976, 0.7, 0.25), 0.0, 0.7)
    place(x, bell(2637, 0.8, 0.3), 0.07, 0.6)
    write("coin", fade(reverb(x, 1.0, 0.18)), -6)

    x = np.zeros(int(1.6 * SR))
    for k, n in enumerate((72, 79, 84)):
        place(x, piano(midi(n), 1.3, 0.6), k * 0.09)
    place(x, bell(midi(88), 1.2, 0.6), 0.22, 0.25)
    write("reward", fade(reverb(x, 1.6, 0.25)), -5)

    x = np.zeros(int(1.2 * SR))
    for k in range(9):
        n = rng.choice([84, 86, 88, 91, 93, 96])
        place(x, bell(midi(n), 0.6, 0.18), k * 0.055, 0.5 - k * 0.03)
    write("sparkle", fade(reverb(x, 1.2, 0.3)), -7)


def tea():
    d = 1.9
    t = t_axis(d)
    gurgle = 0.6 + 0.4 * np.sin(2 * np.pi * (9 + 3 * np.sin(2 * np.pi * 0.7 * t)) * t)
    pour = noise(d, 450, 2600) * gurgle * adsr(len(t), 0.15, 1.2)
    write("pour", fade(pour, 0.05, 0.3), -7)
    steam = noise(d, 2800, 9000) * np.sin(np.pi * t / d) ** 1.5
    write("steam", fade(steam), -12)
    t = t_axis(0.45)
    clink = sum(a * np.sin(2 * np.pi * f * t) * np.exp(-t / dcy) for f, a, dcy in ((2380, 1.0, 0.09), (3910, 0.6, 0.06), (5620, 0.35, 0.04), (7400, 0.15, 0.03)))
    write("clink", fade(clink, 0.001), -8)


def creatures():
    x = np.zeros(int(0.5 * SR))
    a = glide(650, 1050, 0.12) * adsr(int(0.12 * SR), 0.01, 0.07)
    b = glide(900, 1300, 0.14) * adsr(int(0.14 * SR), 0.01, 0.08)
    place(x, a, 0.0)
    place(x, b, 0.16, 0.9)
    write("moss_chirp", fade(reverb(x, 0.6, 0.15)), -7)

    x = np.zeros(int(0.6 * SR))
    for k, (f0, f1, at) in enumerate(((620, 940, 0.0), (760, 1020, 0.17))):
        d = 0.13
        base = glide(f0, f1, d)
        tone = base + 0.4 * glide(f0 * 2, f1 * 2, d) + 0.15 * glide(f0 * 3, f1 * 3, d)
        place(x, tone * adsr(int(d * SR), 0.008, 0.06), at, 0.8 - k * 0.15)
    write("fox_happy", fade(reverb(x, 0.6, 0.15)), -8)

    x = np.zeros(int(2.4 * SR))
    place(x, bell(midi(84), 2.0, 1.1), 0.0, 0.7)
    place(x, bell(midi(88), 1.8, 1.0), 0.16, 0.45)
    write("blue_bell", fade(reverb(x, 1.8, 0.3)), -6)


def fishing():
    d = 0.5
    t = t_axis(d)
    center = 400 + 1500 * np.sin(np.pi * t / d)
    x = np.zeros(len(t))
    raw = rng.standard_normal(len(t))
    # Approximate a sweeping band by mixing three fixed bands with moving weights.
    for lo, hi, mid in ((250, 700, 450), (700, 1600, 1100), (1600, 3500, 2300)):
        w = np.exp(-((center - mid) / 600) ** 2)
        x += band(raw, lo, hi) * w
    write("whoosh", fade(x * np.sin(np.pi * t / d) ** 2), -8)

    d = 0.22
    plop = glide(560, 170, d) * adsr(int(d * SR), 0.002, 0.05)
    plop += noise(d, 600, 4000) * adsr(int(d * SR), 0.001, 0.012) * 0.3
    write("plop", fade(reverb(plop, 0.5, 0.12)), -6)

    x = np.zeros(int(2.0 * SR))
    place(x, bell(midi(81), 1.6, 0.9), 0.0, 0.7)
    place(x, bell(midi(88), 1.6, 0.9), 0.2, 0.7)
    write("bite", fade(reverb(x, 1.4, 0.2)), -4)

    d = 1.05
    x = np.zeros(int(d * SR))
    tt = 0.0
    k = 0
    while tt < d - 0.05:
        click = noise(0.012, 1500, 6000) * adsr(int(0.012 * SR), 0.0005, 0.003)
        place(x, click, tt, 0.5)
        tt += 1 / (22 + 16 * tt / d)
        k += 1
    tone = glide(300, 620, d) * 0.25 * np.sin(np.pi * t_axis(d) / d)
    x[: len(tone)] += tone
    write("reel", fade(x), -9)

    d = 0.9
    t = t_axis(d)
    raw = rng.standard_normal(len(t))
    hi = band(raw, 1500, 7000) * np.exp(-t / 0.08)
    lo = band(raw, 200, 1500) * np.exp(-t / 0.22)
    x = hi * 0.7 + lo
    for k in range(6):
        b = glide(rng.uniform(350, 600), rng.uniform(800, 1300), 0.04) * adsr(int(0.04 * SR), 0.002, 0.015)
        place(x, b, 0.12 + k * rng.uniform(0.04, 0.09), 0.25)
    write("splash", fade(reverb(x, 0.8, 0.15)), -6)


def lanterns():
    x = np.zeros(int(1.8 * SR))
    whoosh = noise(0.6, 200, 1200) * np.sin(np.pi * t_axis(0.6) / 0.6) ** 2
    place(x, whoosh, 0.0, 0.5)
    place(x, bell(midi(79), 1.4, 0.8), 0.25, 0.55)
    place(x, bell(midi(86), 1.3, 0.8), 0.37, 0.4)
    write("lantern_light", fade(reverb(x, 1.6, 0.3)), -6)

    x = np.zeros(int(4.5 * SR))
    for k in range(16):
        n = rng.choice([77, 79, 81, 84, 86, 89, 91, 93])
        place(x, bell(midi(n), 1.8, 1.0), k * 0.19 + rng.uniform(0, 0.05), 0.45)
    write("lantern_release", fade(reverb(x, 2.6, 0.35)), -5)

    d = 0.55
    t = t_axis(d)
    env = np.abs(np.sin(np.pi * t / d)) * (0.6 + 0.4 * np.sin(2 * np.pi * 13 * t))
    write("sit", fade(noise(d, 900, 4500) * env), -12)


# --- loops (built circularly so they repeat without a seam) ------------------------

def loop_night():
    L = 40.0
    n = int(L * SR)
    left = np.zeros(n)
    right = np.zeros(n)
    t = np.arange(n) / SR
    for ch, seed in ((left, 1), (right, 2)):
        r = np.random.default_rng(seed)
        breeze = band(r.standard_normal(n), 60, 650)
        lfo = 0.55 + 0.45 * np.sin(2 * np.pi * (1 / 20) * t + seed) * np.sin(2 * np.pi * (1 / 8) * t + seed * 2)
        ch += breeze * lfo * 0.5
    for c in range(5):
        f = rng.uniform(4300, 5400)
        pan = rng.uniform(0.15, 0.85)
        period = rng.uniform(0.9, 1.6)
        tt = rng.uniform(0, period)
        chirp_t = t_axis(0.03)
        pulse = np.sin(2 * np.pi * f * chirp_t) * np.sin(np.pi * chirp_t / 0.03)
        while tt < L:
            if rng.random() < 0.8:
                for p in range(rng.integers(2, 5)):
                    at = tt + p * 0.055
                    place(left, pulse, at, 0.035 * (1 - pan), circular=True)
                    place(right, pulse, at, 0.035 * pan, circular=True)
            tt += period * rng.uniform(0.85, 1.2)
    write("loop_night", left, -10, stereo=right)


def water_loop(name, L, lo, hi, bubble_rate, mod_speed, peak):
    n = int(L * SR)
    t = np.arange(n) / SR
    left = band(rng.standard_normal(n), lo, hi)
    right = band(rng.standard_normal(n), lo, hi)
    # Modulation frequencies are whole cycles over L so the loop stays seamless.
    mod = 0.6 + 0.4 * np.sin(2 * np.pi * round(mod_speed * L) / L * t) * np.sin(2 * np.pi * round(mod_speed * 2.7 * L) / L * t)
    left *= mod
    right *= mod[::-1]
    count = int(L * bubble_rate)
    for _ in range(count):
        d = rng.uniform(0.02, 0.06)
        b = glide(rng.uniform(300, 700), rng.uniform(700, 1600), d) * adsr(int(d * SR), 0.002, d / 3)
        at = rng.uniform(0, L)
        g = rng.uniform(0.05, 0.18)
        pan = rng.uniform(0, 1)
        place(left, b, at, g * (1 - pan) * 3, circular=True)
        place(right, b, at, g * pan * 3, circular=True)
    mono = (left + right) * 0.5
    write(name, mono, peak)


# --- music --------------------------------------------------------------------------

BPM = 70
BEAT = 60 / BPM
BAR = 4 * BEAT

CHORDS = {
    "Fmaj7": (41, (57, 60, 64)),
    "Am7": (45, (55, 60, 64)),
    "Bbmaj7": (46, (57, 62, 65)),
    "C6": (48, (55, 57, 64)),
    "Dm7": (50, (53, 57, 60)),
    "Gm7": (43, (53, 58, 62)),
    "Csus": (48, (53, 55, 60)),
    "Fadd9": (41, (55, 57, 60, 65)),
}

PROG = ["Fmaj7", "Am7", "Bbmaj7", "C6", "Fmaj7", "Dm7", "Gm7", "Csus"]

MELODY_A = [
    [(1, 72, 1), (2, 69, 1), (3, 72, 1.5)],
    [(0.5, 76, 1.5), (2, 74, 1), (3, 72, 1)],
    [(0, 74, 2), (2.5, 77, 1.5)],
    [(0, 76, 1), (1, 74, 1), (2, 72, 2)],
    [(1, 81, 1), (2, 79, 1), (3, 77, 1)],
    [(0, 76, 2), (2, 74, 1), (3, 72, 1)],
    [(0, 74, 1.5), (1.5, 77, 0.5), (2, 74, 2)],
    [(0, 72, 3)],
]
MELODY_B = [
    [(0.5, 77, 1), (1.5, 76, 0.5), (2, 72, 2)],
    [(1, 76, 1), (2, 79, 2)],
    [(0, 77, 1.5), (1.5, 74, 0.5), (2, 72, 1), (3, 74, 1)],
    [(0, 76, 3)],
    [(0.5, 72, 0.5), (1, 77, 1), (2, 81, 1), (3, 79, 1)],
    [(0, 77, 1.5), (2, 76, 1), (3, 74, 1)],
    [(0, 74, 1), (1, 72, 1), (2, 70, 2)],
    [(0, 72, 2), (2.5, 67, 0.5), (3, 69, 1)],
]


def render_bars(prog, melody, length, circular, pluck_double=False, bells=True):
    n = int(length * SR)
    left = np.zeros(n)
    right = np.zeros(n)
    for b, name in enumerate(prog):
        bass, tones = CHORDS[name]
        start = b * BAR
        place(left, piano(midi(bass), BAR + 1.5, 0.55), start, 1.0, circular)
        place(right, piano(midi(bass), BAR + 1.5, 0.55), start, 1.0, circular)
        # Gently broken chord.
        for k, note in enumerate(tones):
            at = start + (0.5 + k * 0.5) * BEAT
            v = 0.32 - k * 0.03
            pan = 0.35 + 0.3 * (k / max(len(tones) - 1, 1))
            tone = piano(midi(note), 3.0, v)
            place(left, tone, at, 1 - pan, circular)
            place(right, tone, at, pan, circular)
        # Warm pad underneath.
        pad_t = t_axis(BAR + 1.0)
        pad = np.zeros_like(pad_t)
        for note in tones:
            f = midi(note - 12)
            pad += np.sin(2 * np.pi * f * pad_t) + 0.5 * np.sin(2 * np.pi * f * 1.003 * pad_t)
        pad *= np.minimum(pad_t / 1.0, 1) * np.minimum((BAR + 1.0 - pad_t) / 1.0, 1) * 0.025
        place(left, pad, start, 1.0, circular)
        place(right, pad, start, 1.0, circular)
        for beat, note, dur in melody[b]:
            at = start + beat * BEAT
            tone = piano(midi(note), dur * BEAT + 1.8, 0.5)
            place(left, tone, at, 0.55, circular)
            place(right, tone, at, 0.45, circular)
            if pluck_double:
                pl = pluck(midi(note), 1.6, 0.18)
                place(left, pl, at + 0.01, 0.4, circular)
                place(right, pl, at + 0.01, 0.6, circular)
        if bells and b % 4 == 3:
            place(right, bell(midi(tones[-1] + 24), 2.0, 1.2), start + 3 * BEAT, 0.05, circular)
            place(left, bell(midi(tones[-1] + 24), 2.0, 1.2), start + 3 * BEAT, 0.03, circular)
    return left, right


def music_main():
    prog = PROG + PROG
    melody = MELODY_A + MELODY_B
    L = len(prog) * BAR
    left, right = render_bars(prog, melody, L, circular=True, pluck_double=False)
    # Second half gets a plucked-string doubling an octave up for variety.
    plucks_l = np.zeros_like(left)
    plucks_r = np.zeros_like(right)
    for b, bar_mel in enumerate(MELODY_B):
        for beat, note, dur in bar_mel:
            at = (len(PROG) + b) * BAR + beat * BEAT
            pl = pluck(midi(note + 12), 1.4, 0.12)
            place(plucks_l, pl, at, 0.35, True)
            place(plucks_r, pl, at, 0.55, True)
    left += plucks_l
    right += plucks_r
    left = reverb(left, 2.8, 0.3, circular=True, seed=3)
    right = reverb(right, 2.8, 0.3, circular=True, seed=4)
    write("music_main", left, -7, stereo=right)


def music_ending():
    prog = ["Bbmaj7", "C6", "Am7", "Dm7", "Bbmaj7", "Csus", "Fadd9", "Fadd9"]
    melody = [
        [(0, 77, 2), (2, 74, 2)],
        [(0, 76, 1), (1, 79, 1), (2, 81, 2)],
        [(0, 79, 2), (2, 76, 2)],
        [(0, 77, 1), (1, 76, 1), (2, 74, 2)],
        [(0, 74, 1.5), (1.5, 77, 0.5), (2, 81, 2)],
        [(0, 79, 2), (2, 76, 1), (3, 79, 1)],
        [(0, 77, 4)],
        [],
    ]
    L = len(prog) * BAR + 4.0
    left, right = render_bars(prog, melody, L, circular=False, pluck_double=True)
    for k, n in enumerate((89, 93, 96, 101)):
        place(left, bell(midi(n), 3.0, 1.6), 6 * BAR + 0.4 + k * 0.25, 0.06)
        place(right, bell(midi(n), 3.0, 1.6), 6 * BAR + 0.5 + k * 0.25, 0.08)
    left = reverb(left, 3.2, 0.32, seed=5)
    right = reverb(right, 3.2, 0.32, seed=6)
    fade_n = int(3.0 * SR)
    for ch in (left, right):
        ch[-fade_n:] *= np.linspace(1, 0, fade_n)
    write("music_ending", left, -6, stereo=right)


def night_creatures():
    # Frog: two throaty pulses with a fast nasal flutter.
    x = np.zeros(int(0.6 * SR))
    for k, (f0, at) in enumerate(((210, 0.0), (185, 0.2))):
        d = 0.14
        t = t_axis(d)
        tone = sum(a * np.sin(2 * np.pi * f0 * h * t) for h, a in ((1, 1.0), (2, 0.6), (3, 0.35), (5, 0.15)))
        tone *= 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 32 * t))
        place(x, tone * adsr(len(t), 0.01, 0.06), at, 0.9 - k * 0.2)
    write("frog", fade(reverb(band(x, 120, 2500), 0.8, 0.2)), -8)
    # Owl: a soft breathy "hoo ... hoo-hoo".
    x = np.zeros(int(2.2 * SR))
    for at, d, f in ((0.0, 0.45, 360), (0.7, 0.22, 340), (1.0, 0.5, 330)):
        t = t_axis(d)
        env = np.sin(np.pi * t / d) ** 1.5
        tone = np.sin(2 * np.pi * f * t * (1 - 0.04 * t / d)) + 0.12 * np.sin(2 * np.pi * 2 * f * t)
        breath = band(rng.standard_normal(len(t)), 250, 900) * 0.18
        place(x, (tone + breath) * env, at, 0.8)
    write("owl", fade(reverb(x, 2.2, 0.35)), -9)
    # Duckling: a tiny rising peep.
    x = np.zeros(int(0.4 * SR))
    for at in (0.0, 0.16):
        d = 0.09
        tone = glide(2600, 3400, d) + 0.3 * glide(5200, 6800, d)
        place(x, tone * adsr(int(d * SR), 0.005, 0.04), at, 0.8)
    write("peep", fade(reverb(x, 0.5, 0.15)), -10)


if __name__ == "__main__":
    footsteps()
    ui_sounds()
    chimes()
    tea()
    creatures()
    fishing()
    lanterns()
    loop_night()
    water_loop("loop_water", 24.0, 120, 900, 1.6, 0.12, -10)
    water_loop("loop_stream", 16.0, 250, 3200, 6.0, 0.3, -10)
    water_loop("loop_kettle", 8.0, 70, 500, 9.0, 0.5, -12)
    music_main()
    music_ending()
    night_creatures()
    # The realistic effects (footsteps, splashes, ui, creatures...) in gen_sfx.py
    # replace the simple ones above.
    import gen_sfx
    for f in (gen_sfx.footsteps, gen_sfx.jump_land, gen_sfx.sit, gen_sfx.ui, gen_sfx.water,
              gen_sfx.fishing, gen_sfx.ceramic_and_coin, gen_sfx.creatures):
        f()
    # Recorded takes (audio_src/) replace the synthetic footsteps, water,
    # fishing and wildlife sounds wherever a recording exists.
    import build_sfx
    build_sfx.main()
