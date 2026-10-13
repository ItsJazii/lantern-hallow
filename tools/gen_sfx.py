"""Physically-inspired sound effects for Lantern Hollow (replaces the first,
beepy set). Music and ambience loops stay in gen_audio.py.

    python tools/gen_sfx.py

Every sound is modelled on how the real one is made:
  footsteps  heel strike + toe roll, each exciting the surface: grass is a
             cloud of tiny blade snaps over a soft rustle, packed dirt a
             gritty scuff, sand a fine squeaky crunch, planks a knock that
             rings a few wooden modes (and now and then creaks)
  splashes   an impact burst followed by bubbles: decaying sines whose pitch
             rises as they shrink (Minnaert resonance), then droplets
  reel       a pawl ratchet: tiny metal clicks speeding up
  bench      stick-slip wood creak under load + cloth rustle
  ui         paper and wood clicks rather than electronic beeps
Six variants per footstep surface so walking never sounds looped.
"""
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_audio as ga  # noqa: E402  (primitives + writer)

SR = ga.SR
band, place, reverb, fade, write, t_axis, adsr = ga.band, ga.place, ga.reverb, ga.fade, ga.write, ga.t_axis, ga.adsr


def rng_for(seed):
    return np.random.default_rng(seed)


def lowpass(x, hi):
    return band(x, 15, hi)


def env_exp(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(t / max(attack, 1e-4), 1.0) * np.exp(-np.maximum(t - attack, 0) / decay)


def grains(r, dur, count, lo, hi, centers, spread, gmin=0.001, gmax=0.004, amp=(0.2, 1.0)):
    """A cloud of tiny noise grains (blade snaps, grit) gathered around `centers`."""
    x = np.zeros(int(dur * SR))
    for _ in range(count):
        c = centers[r.integers(len(centers))]
        at = max(0.0, r.normal(c, spread))
        g = r.uniform(gmin, gmax)
        n = max(8, int(g * SR))
        grain = r.standard_normal(n) * np.hanning(n)
        place(x, grain, at, r.uniform(*amp))
    return band(x, lo, hi)


def thump(r, dur, at, hi=180, decay=0.035, amp=1.0):
    x = np.zeros(int(dur * SR))
    n = int(0.12 * SR)
    burst = r.standard_normal(n) * env_exp(n, 0.002, decay)
    place(x, lowpass(burst, hi), at, amp)
    return x


def modes(dur, at, freqs, decays, amps, r, detune=0.03):
    x = np.zeros(int(dur * SR))
    t = t_axis(dur - at)
    for f, d, a in zip(freqs, decays, amps):
        f *= 1 + r.uniform(-detune, detune)
        place(x, np.sin(2 * np.pi * f * t + r.uniform(0, 6.28)) * np.exp(-t / d) * a, at)
    return x


def heel_toe(r):
    heel = r.uniform(0.0, 0.006)
    toe = heel + r.uniform(0.06, 0.1)
    return heel, toe


# --- Footsteps ------------------------------------------------------------------------

def step_grass(i):
    r = rng_for(100 + i)
    d = 0.42
    heel, toe = heel_toe(r)
    x = thump(r, d, heel, 160, 0.03, 0.55) + thump(r, d, toe, 220, 0.02, 0.3)
    # Blades bending and snapping, mostly at the heel, more as the toe rolls.
    x += grains(r, d, 140, 1800, 9000, [heel + 0.02, toe + 0.02], 0.03, amp=(0.05, 0.4)) * 0.9
    rustle = r.standard_normal(int(d * SR)) * env_exp(int(d * SR), 0.015, 0.09)
    x += band(rustle, 900, 6000) * 0.22
    return fade(x, 0.002, 0.08)


def step_dirt(i):
    r = rng_for(200 + i)
    d = 0.36
    heel, toe = heel_toe(r)
    x = thump(r, d, heel, 200, 0.03, 0.8) + thump(r, d, toe, 260, 0.025, 0.45)
    x += grains(r, d, 70, 500, 4500, [heel + 0.01, toe + 0.015], 0.02, 0.0008, 0.003, (0.1, 0.6)) * 0.8
    scuff = r.standard_normal(int(d * SR)) * env_exp(int(d * SR), 0.01, 0.05)
    x += band(scuff, 400, 2800) * 0.25
    return fade(x, 0.002, 0.06)


def step_sand(i):
    r = rng_for(300 + i)
    d = 0.4
    heel, toe = heel_toe(r)
    x = thump(r, d, heel, 150, 0.04, 0.5) + thump(r, d, toe, 180, 0.03, 0.25)
    x += grains(r, d, 260, 1200, 7000, [heel + 0.03, toe + 0.03], 0.035, 0.0005, 0.0015, (0.05, 0.3)) * 1.1
    hiss = r.standard_normal(int(d * SR)) * env_exp(int(d * SR), 0.03, 0.1)
    x += band(hiss, 1500, 6000) * 0.12
    return fade(x, 0.002, 0.08)


def step_wood(i):
    r = rng_for(400 + i)
    d = 0.6
    heel, toe = heel_toe(r)
    x = thump(r, d, heel, 260, 0.02, 0.7) + thump(r, d, toe, 320, 0.015, 0.35)
    # Hollow planks over water: a few low wooden modes that ring briefly.
    base = r.uniform(0.9, 1.1)
    fr = [92 * base, 168 * base, 287 * base, 455 * base, 760 * base]
    dc = [0.09, 0.06, 0.045, 0.03, 0.02]
    am = [0.45, 0.35, 0.25, 0.15, 0.08]
    x += modes(d, heel, fr, dc, am, r) + modes(d, toe, fr, [v * 0.7 for v in dc], [a * 0.45 for a in am], r)
    x += grains(r, d, 20, 1500, 6000, [heel, toe], 0.008, amp=(0.05, 0.2)) * 0.5
    if i in (2, 5):
        x += creak(r, d, toe + 0.03, 0.18) * 0.18
    return fade(reverb(x, 0.35, 0.08)[: int(d * SR)], 0.002, 0.1)


def creak(r, dur, at, length, f0=None):
    """Stick-slip friction: a train of tiny impulses with a wandering rate,
    coloured by a couple of wood resonances."""
    x = np.zeros(int(dur * SR))
    t = 0.0
    f0 = f0 or r.uniform(70, 140)
    while t < length:
        rate = f0 * (1 + 0.35 * np.sin(2 * np.pi * 3 * t / length) + r.uniform(-0.1, 0.1))
        place(x, np.array([1.0, -0.6, 0.2]), at + t, r.uniform(0.6, 1.0) * np.sin(np.pi * t / length))
        t += 1 / rate
    return band(x, 250, 3200) + band(x, 600, 1100) * 1.5


def footsteps():
    for i in range(1, 7):
        write(f"step_grass_{i}", step_grass(i), -9)
        write(f"step_dirt_{i}", step_dirt(i), -9)
        write(f"step_stone_{i}", step_dirt(i), -9)  # older name used by some surfaces
        write(f"step_sand_{i}", step_sand(i), -10)
        write(f"step_wood_{i}", step_wood(i), -8)


def jump_land():
    r = rng_for(7)
    d = 0.35
    # Push-off: a quick scuff and clothes moving.
    x = thump(r, d, 0.0, 200, 0.02, 0.5)
    x += band(r.standard_normal(int(d * SR)), 600, 4000) * np.sin(np.pi * t_axis(d) / d) ** 2 * 0.2
    write("jump", fade(x, 0.002, 0.08), -12)
    for i in range(1, 4):
        r = rng_for(70 + i)
        d = 0.5
        y = thump(r, d, 0.0, 140, 0.05, 1.0) + thump(r, d, 0.035, 200, 0.03, 0.6)
        y += grains(r, d, 160, 1500, 8000, [0.01, 0.04], 0.025, amp=(0.05, 0.4)) * 0.8
        write(f"land_{i}", fade(y, 0.002, 0.1), -8)


# --- Bench, UI ---------------------------------------------------------------------------

def sit():
    r = rng_for(11)
    d = 1.1
    x = creak(r, d, 0.05, 0.35, 85) * 0.5 + creak(r, d, 0.55, 0.22, 110) * 0.3
    cloth = r.standard_normal(int(d * SR)) * np.sin(np.pi * np.clip(t_axis(d) / 0.6, 0, 1)) ** 2
    x += band(cloth, 700, 5000) * 0.18
    x += thump(r, d, 0.18, 150, 0.06, 0.6)
    write("sit", fade(reverb(x, 0.4, 0.1)[: int(d * SR)], 0.003, 0.2), -10)


def ui():
    r = rng_for(21)
    # A soft wooden "tok" for buttons: two little resonances, very short.
    d = 0.09
    x = modes(d, 0.0, [1150, 2650], [0.012, 0.007], [1.0, 0.4], r, 0.0)
    x += band(r.standard_normal(int(d * SR)) * env_exp(int(d * SR), 0.0005, 0.004), 2000, 8000) * 0.3
    write("ui_tick", fade(x, 0.0005, 0.02), -14)
    # Dialogue blip: a soft, low marimba-ish pop rather than a beep.
    d = 0.14
    x = modes(d, 0.0, [523, 1570, 2780], [0.05, 0.02, 0.01], [1.0, 0.25, 0.1], r, 0.0)
    write("blip", fade(x, 0.001, 0.03), -14)


# --- Water ---------------------------------------------------------------------------------

def bubble(r, radius_mm, dur=None):
    """A single bubble: Minnaert frequency, rising as it shrinks, fast decay."""
    f0 = 3260.0 / max(radius_mm, 0.3)
    dur = dur or min(0.08, 0.004 + radius_mm * 0.012)
    t = t_axis(dur)
    f = f0 * (1 + 0.1 * f0 / 1000 * t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t / (dur * 0.35))


def splash_sound(r, d, size):
    x = np.zeros(int(d * SR))
    n = int(d * SR)
    impact = r.standard_normal(n) * env_exp(n, 0.002, 0.05 * size)
    x += band(impact, 300, 5000) * 0.6 * size
    x += band(impact, 80, 300) * 0.5 * size
    for k in range(int(35 * size)):
        at = abs(r.normal(0.05, 0.12 * size))
        rad = r.uniform(1.5, 6.0) * (0.6 + 0.4 * size)
        place(x, bubble(r, rad), at, r.uniform(0.1, 0.45))
    for k in range(int(14 * size)):
        place(x, bubble(r, r.uniform(0.6, 1.4)), r.uniform(0.15, 0.6) * size + 0.1, r.uniform(0.05, 0.2))
    return x


def water():
    r = rng_for(31)
    d = 1.1
    write("splash", fade(reverb(splash_sound(r, d, 1.0), 0.6, 0.12)[: int(d * SR)], 0.001, 0.2), -7)
    d = 0.5
    x = splash_sound(rng_for(32), d, 0.35)
    place(x, bubble(rng_for(33), 4.0, 0.09), 0.01, 0.9)
    write("plop", fade(x, 0.001, 0.1), -8)
    # Pour: a stream of tea, many small bubbles over a soft flow.
    r = rng_for(34)
    d = 1.9
    x = band(r.standard_normal(int(d * SR)), 500, 3000) * 0.15
    for k in range(260):
        place(x, bubble(r, r.uniform(1.0, 3.0)), r.uniform(0.05, d - 0.1), r.uniform(0.05, 0.25))
    x *= np.minimum(t_axis(d) / 0.15, 1.0) * np.minimum((d - t_axis(d)) / 0.3, 1.0)
    write("pour", fade(x, 0.02, 0.2), -9)


# --- Fishing ---------------------------------------------------------------------------------

def fishing():
    r = rng_for(41)
    # Cast: a line swishing through the air.
    d = 0.55
    t = t_axis(d)
    raw = r.standard_normal(len(t))
    x = band(raw, 900, 5000) * np.sin(np.pi * t / d) ** 3 * 0.7 + band(raw, 300, 900) * np.sin(np.pi * t / d) ** 4 * 0.4
    write("whoosh", fade(x, 0.01, 0.05), -12)
    # Reel: pawl ratchet clicks, accelerating then easing.
    d = 1.1
    x = np.zeros(int(d * SR))
    tt = 0.02
    while tt < d - 0.03:
        click = modes(0.02, 0.0, [3100, 5200, 7600], [0.003, 0.002, 0.0015], [1.0, 0.5, 0.25], r, 0.05)
        place(x, click, tt, r.uniform(0.5, 0.9))
        tt += 1 / (16 + 22 * np.sin(np.pi * tt / d))
    x += band(r.standard_normal(len(x)), 150, 600) * 0.04
    write("reel", fade(x, 0.002, 0.05), -12)


# --- Tea, coins ------------------------------------------------------------------------------

def ceramic_and_coin():
    r = rng_for(51)
    d = 0.6
    x = modes(d, 0.0, [2210, 4930, 8180, 10450], [0.12, 0.07, 0.04, 0.025], [1.0, 0.5, 0.25, 0.1], r, 0.01)
    write("clink", fade(x, 0.0005, 0.05), -12)
    d = 0.8
    x = np.zeros(int(d * SR))
    for k, at in enumerate((0.0, 0.07, 0.12)):
        c = modes(d - at, 0.0, [4120, 6390, 9010, 11900], [0.18, 0.12, 0.08, 0.05], [1.0, 0.6, 0.35, 0.2], r, 0.04)
        place(x, c, at, 0.8 - k * 0.2)
    write("coin", fade(reverb(x, 0.6, 0.12)[: int(d * SR)], 0.0005, 0.1), -12)


# --- Night creatures ------------------------------------------------------------------------

def creatures():
    r = rng_for(61)
    # Frog: a quick train of glottal pulses through a throat-sac formant ("rrribbit").
    d = 0.7
    x = np.zeros(int(d * SR))
    for k in range(2):
        start = 0.02 + k * 0.28
        n = int(0.16 * SR)
        rate = r.uniform(58, 70) if k == 0 else r.uniform(66, 78)
        tt = 0.0
        pulses = np.zeros(n)
        while tt < 0.16:
            place(pulses, np.array([1.0, 0.5, -0.3]), tt, 1.0)
            tt += 1 / rate
        voiced = band(pulses, 300, 900) * 1.2 + band(pulses, 1100, 1900) * 0.6
        voiced *= np.sin(np.pi * np.arange(n) / n) ** 0.7
        place(x, voiced, start, 1.0 if k == 0 else 0.8)
    write("frog", fade(reverb(x, 0.9, 0.15)[: int(1.2 * SR)], 0.002, 0.15), -9)
    # Owl: two soft breathy hoots, the second lower and longer.
    d = 2.2
    x = np.zeros(int(d * SR))
    for k, (f, at, ln) in enumerate(((410, 0.0, 0.32), (375, 0.5, 0.65))):
        t = t_axis(ln)
        tone = np.sin(2 * np.pi * (f + 8 * np.sin(2 * np.pi * 5 * t)) * t) * np.sin(np.pi * t / ln) ** 1.5
        breath = band(r.standard_normal(len(t)), 300, 1200) * np.sin(np.pi * t / ln) ** 2 * 0.12
        place(x, tone + breath, at, 1.0)
    write("owl", fade(reverb(x, 2.0, 0.3)[: int(2.6 * SR)], 0.01, 0.3), -11)
    # Duckling peep: a short rising-falling chirp with a little rasp.
    d = 0.25
    t = t_axis(0.12)
    f = 2800 + 900 * np.sin(np.pi * t / 0.12)
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / 0.12) ** 1.2
    tone += 0.25 * np.sin(2 * np.pi * np.cumsum(f * 2) / SR) * np.sin(np.pi * t / 0.12) ** 2
    x = np.zeros(int(d * SR))
    place(x, tone, 0.0)
    write("peep", fade(reverb(x, 0.4, 0.1)[: int(0.4 * SR)], 0.002, 0.05), -12)


if __name__ == "__main__":
    footsteps()
    jump_land()
    sit()
    ui()
    water()
    fishing()
    ceramic_and_coin()
    creatures()
