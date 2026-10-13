"""Builds the game's recorded sound effects from the ElevenLabs takes in audio_src/.

Each take is decoded with ffmpeg, cleaned (rumble high-pass), and then either:
  * cut into single events (footsteps, jumps, landings, splashes, calls) at the
    transients listed below, with a short pre-roll, a soft fade-in and a natural
    fade-out, then levelled to a common loudness; or
  * folded into a seamless loop (pond, stream, reel) with equal-power crossfades.

Outputs 44.1 kHz mono 16-bit WAVs to game/assets/audio/. Clips named <cue>_<n>
are variants: Sfx picks one at random (never the same twice in a row).

Run:  python tools/build_sfx.py
"""
import os
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "audio_src")
OUT = os.path.join(ROOT, "game", "assets", "audio")
SR = 44100

_cache = {}


def load(name, hp=40.0):
    """Decodes audio_src/<name>.mp3 to mono float, high-passed at `hp` Hz."""
    key = (name, hp)
    if key not in _cache:
        af = f"highpass=f={hp}:poles=2,highpass=f={hp}:poles=2"
        raw = subprocess.run(
            ["ffmpeg", "-loglevel", "error", "-i", os.path.join(SRC, name + ".mp3"),
             "-ac", "1", "-ar", str(SR), "-af", af, "-f", "s16le", "-"],
            check=True, capture_output=True).stdout
        _cache[key] = np.frombuffer(raw, np.int16).astype(np.float64) / 32768.0
    return _cache[key]


def env_db(a, win=0.002):
    n = max(1, int(win * SR))
    k = np.ones(n) / n
    return 10 * np.log10(np.convolve(a * a, k, mode="same") + 1e-12)


def onset(a, t, search=0.06):
    """Refines a rough event time to the actual attack: the first point within
    the search window where the 2 ms envelope comes within 18 dB of the local peak."""
    lo = max(0, int((t - search) * SR))
    hi = min(len(a), int((t + search * 2) * SR))
    e = env_db(a[lo:hi])
    peak = e.max()
    i = int(np.argmax(e > peak - 18))
    return (lo + i) / SR


def max_rms_db(a, win=0.02):
    n = int(win * SR)
    if len(a) <= n:
        return 20 * np.log10(np.sqrt(np.mean(a * a)) + 1e-12)
    c = np.convolve(a * a, np.ones(n) / n, mode="valid")
    return 10 * np.log10(c.max() + 1e-12)


def level(a, target_db, peak_ceiling=-1.0):
    """Sets the loudest 20 ms to `target_db` dBFS, never letting peaks clip."""
    g = 10 ** ((target_db - max_rms_db(a)) / 20)
    pk = np.abs(a).max() * g
    ceil = 10 ** (peak_ceiling / 20)
    if pk > ceil:
        g *= ceil / pk
    return a * g


def cut(name, t, length, target, hp=40.0, pre=0.012, fade_out=0.55, refine=True):
    """One event: starts `pre` before the attack, lasts `length`, the last
    `fade_out` fraction eased to silence with a cosine."""
    a = load(name, hp)
    t0 = (onset(a, t) if refine else t) - pre
    s = max(0, int(t0 * SR))
    seg = a[s:s + int(length * SR)].copy()
    seg -= np.mean(seg)
    fi = int(0.004 * SR)
    seg[:fi] *= np.sin(np.linspace(0, np.pi / 2, fi)) ** 2
    fo = int(len(seg) * fade_out)
    seg[-fo:] *= np.cos(np.linspace(0, np.pi / 2, fo)) ** 2
    return level(seg, target)


def span(name, t0, t1, target, hp=40.0, fade_in=0.006, fade_out=0.25):
    a = load(name, hp)
    seg = a[int(t0 * SR):int(t1 * SR)].copy()
    seg -= np.mean(seg)
    fi = int(fade_in * SR)
    if fi:
        seg[:fi] *= np.sin(np.linspace(0, np.pi / 2, fi)) ** 2
    fo = int(fade_out * SR)
    if fo:
        seg[-fo:] *= np.cos(np.linspace(0, np.pi / 2, fo)) ** 2
    return level(seg, target)


def xfade_join(parts, xf):
    """Concatenates with equal-power crossfades of `xf` seconds."""
    n = int(xf * SR)
    out = parts[0].copy()
    ramp = np.linspace(0, np.pi / 2, n)
    for p in parts[1:]:
        tail = out[-n:] * np.cos(ramp) + p[:n] * np.sin(ramp)
        out = np.concatenate([out[:-n], tail, p[n:]])
    return out


def make_loop(a, xf):
    """Folds the last `xf` seconds over the start so the end flows into the
    beginning with no click or level dip."""
    n = int(xf * SR)
    ramp = np.linspace(0, np.pi / 2, n)
    head = a[:n] * np.sin(ramp) + a[-n:] * np.cos(ramp)
    return np.concatenate([head, a[n:-n]])


def tame(a, over_db=7.0, ratio=5.0, win=0.008):
    """Soft-compresses moments louder than the loop's average by more than
    `over_db`, so a stray drip or gurgle doesn't jump out of an ambience bed."""
    n = int(win * SR)
    e = np.sqrt(np.convolve(a * a, np.ones(n) / n, mode="same") + 1e-12)
    avg = np.sqrt(np.mean(a * a))
    over = 20 * np.log10(e / avg) - over_db
    gain_db = np.where(over > 0, -over * (1 - 1 / ratio), 0.0)
    # Smooth the gain so it never pumps audibly.
    k = int(0.012 * SR)
    gain_db = np.convolve(gain_db, np.ones(k) / k, mode="same")
    return a * 10 ** (gain_db / 20)


def loop_from(spans, xf, target_avg, tame_db=None):
    parts = []
    for name, t0, t1, hp in spans:
        seg = load(name, hp)[int(t0 * SR):int(t1 * SR)].copy()
        seg -= np.mean(seg)
        # Even the takes out so no single one is louder than the rest.
        seg *= 10 ** ((target_avg - 20 * np.log10(np.sqrt(np.mean(seg ** 2)) + 1e-12)) / 20)
        parts.append(seg)
    a = make_loop(xfade_join(parts, xf), xf)
    if tame_db is not None:
        a = tame(a, tame_db)
    g = 10 ** ((target_avg - 20 * np.log10(np.sqrt(np.mean(a ** 2)) + 1e-12)) / 20)
    a *= g
    pk = np.abs(a).max()
    if pk > 0.9:
        a *= 0.9 / pk
    return a


def write(name, a):
    a = np.clip(a, -1.0, 1.0)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((a * 32767).astype(np.int16).tobytes())
    print(f"  {name:18s} {len(a) / SR:5.2f}s  peak {20 * np.log10(np.abs(a).max() + 1e-9):6.1f}  "
          f"loud {max_rms_db(a):6.1f}")


def series(prefix, items):
    for i, a in enumerate(items, 1):
        write(f"{prefix}_{i}", a)


# --- Event lists: (take, rough time of the hit) ------------------------------
# Times found by transient detection on each take (see PROGRESS.md, session 4).

DIRT = [("walk dirt 1", 0.748), ("walk dirt 1", 1.454), ("walk dirt 1", 2.24),
        ("walk dirt 2", 0.357), ("walk dirt 2", 1.559), ("walk dirt 2", 2.153),
        ("walk dirt 3", 1.30), ("walk dirt 3", 0.06)]
SAND = [("walk sand 3", 0.559), ("walk sand 3", 1.14), ("walk sand 3", 1.781),
        ("walk sand 3", 2.407), ("walk sand 3", 3.659), ("walk sand 3", 4.814)]
WOOD = [("walk wodden 1", 0.095), ("walk wodden 1", 0.334), ("walk wodden 1", 0.601),
        ("walk wodden 2", 0.249), ("walk wodden 2", 0.579), ("walk wodden 3", 0.175)]
# The "soft grass at night" takes are a continuous rustle with no distinct
# footfalls; the jump-on-grass takes have clean grass impacts.
GRASS = [("jump grass 1", 0.629), ("jump grass 1", 1.639), ("jump grass 3", 1.459),
         ("jump grass 4", 1.354)]
GRASS_LAND = [("jump grass 1", 1.639), ("jump grass 3", 1.459), ("jump grass 4", 1.354)]
WOOD_JUMP = [("jump dock 3", 0.062), ("jump dock 4", 0.085), ("jump dock 2", 0.342)]
WOOD_LAND = [("jump dock 4", 1.913), ("jump dock 3", 1.983), ("jump dock 2", 2.382),
             ("jump dock", 1.30)]


def build():
    os.makedirs(OUT, exist_ok=True)
    print("footsteps")
    series("step_dirt", [cut(n, t, 0.34, -20.0, hp=70) for n, t in DIRT])
    # Stone: the dirt steps with the low thump removed and a tighter tail.
    series("step_stone", [cut(n, t, 0.24, -21.0, hp=260, fade_out=0.7) for n, t in DIRT[:6]])
    series("step_sand", [cut(n, t, 0.40, -21.0, hp=70) for n, t in SAND])
    series("step_wood", [cut(n, t, 0.24, -19.0, hp=110, fade_out=0.6) for n, t in WOOD])
    series("step_grass", [cut(n, t, 0.28, -21.0, hp=110, fade_out=0.65) for n, t in GRASS])

    print("jumps and landings")
    # Push-off on grass: the rustle that swells as the feet leave the ground,
    # cut so it ends on the push.
    series("jump_grass", [span("jump grass 3", 0.0, 0.26, -22.0, hp=110, fade_in=0.08, fade_out=0.06),
                          span("jump grass 3", 0.86, 1.15, -22.0, hp=110, fade_in=0.10, fade_out=0.07),
                          span("jump grass 4", 0.0, 0.30, -22.0, hp=110, fade_in=0.10, fade_out=0.08)])
    series("jump_wood", [cut(n, t, 0.30, -21.0, hp=110, fade_out=0.6) for n, t in WOOD_JUMP])
    series("land_grass", [cut(n, t, 0.55, -16.0, hp=110) for n, t in GRASS_LAND])
    series("land_wood", [cut(n, t, 0.40, -15.0, hp=110) for n, t in WOOD_LAND])

    print("bench")
    series("sit", [span("sitting 3", 0.0, 0.62, -18.0, hp=60, fade_in=0.003, fade_out=0.3)])

    print("water")
    write("loop_water", loop_from([("calm pond 1", 0.4, 4.5, 60), ("calm pond 3", 0.4, 4.5, 60),
                                   ("calm pond 4", 0.4, 4.5, 60), ("calm pond 2", 0.4, 2.5, 60)],
                                  0.6, -27.0, tame_db=7.0))
    write("loop_stream", loop_from([("water stream 1", 0.05, 1.95, 60), ("water stream 3", 0.05, 1.95, 60),
                                    ("water stream 4", 0.05, 1.95, 60), ("water stream 2", 0.05, 1.95, 60)],
                                   0.35, -27.0, tame_db=7.0))
    series("splash", [span("fish splash 3", 0.0, 1.35, -18.0, fade_in=0.002, fade_out=0.5),
                      span("fish splash 4", 0.0, 1.45, -18.0, fade_in=0.004, fade_out=0.5),
                      span("fish splash 2", 0.12, 1.40, -18.0, fade_in=0.01, fade_out=0.5)])
    # Small plops: the sharp first drop of a splash, before the wash.
    series("plop", [span("fish splash 3", 0.0, 0.28, -18.0, fade_in=0.002, fade_out=0.16),
                    span("fish splash 4", 0.0, 0.30, -19.0, fade_in=0.003, fade_out=0.18),
                    span("fish float 1", 0.30, 0.62, -19.0, fade_in=0.004, fade_out=0.18)])
    # A hooked fish churning at the surface.
    series("thrash", [span("fish float 1", 0.0, 1.25, -19.0, fade_in=0.01, fade_out=0.45),
                      span("fish float 4", 0.0, 1.20, -19.0, fade_in=0.01, fade_out=0.45),
                      span("fish float 3", 0.0, 1.10, -20.0, fade_in=0.02, fade_out=0.45)])

    print("fishing")
    # The rod swish before the line runs out.
    series("whoosh", [span("cast 3 rod", 0.0, 0.85, -20.0, fade_in=0.004, fade_out=0.45),
                      span("cast 4 rod", 0.0, 1.05, -20.0, fade_in=0.004, fade_out=0.5),
                      span("cast 1", 0.0, 0.75, -20.0, fade_in=0.004, fade_out=0.4)])
    # Line paying out of the spool: the long run after the swish.
    write("line_out", span("cast 2", 2.0, 3.1, -22.0, fade_in=0.03, fade_out=0.35))
    write("loop_reel", loop_from([("reel in 3", 1.0, 6.5, 60)], 0.2, -26.0))

    print("wildlife")
    series("frog", [span("frog 3", 0.0, 1.75, -20.0, fade_in=0.004, fade_out=0.3),
                    span("frog 4", 0.0, 2.0, -20.0, fade_in=0.004, fade_out=0.3),
                    span("forg 2", 0.15, 2.0, -21.0, fade_in=0.01, fade_out=0.3),
                    span("frog 1", 0.2, 1.75, -21.0, fade_in=0.01, fade_out=0.3)])
    series("owl", [span("owl 2", 0.0, 1.0, -16.0, fade_in=0.004, fade_out=0.35),
                   span("owl 3", 0.04, 1.0, -16.0, fade_in=0.004, fade_out=0.25),
                   span("owl 4", 0.2, 1.0, -16.0, fade_in=0.004, fade_out=0.35)])


# Older synthetic clips these recordings replace.
OBSOLETE = (["jump", "sit", "frog", "owl", "splash", "plop", "whoosh", "reel"]
            + [f"land_{i}" for i in range(1, 4)]
            + [f"step_{s}_{i}" for s in ("grass", "dirt", "stone", "sand", "wood") for i in range(1, 9)])


def main():
    for n in OBSOLETE:
        for ext in (".wav", ".wav.import"):
            p = os.path.join(OUT, n + ext)
            if os.path.exists(p):
                os.remove(p)
    build()


if __name__ == "__main__":
    main()
