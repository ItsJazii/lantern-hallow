"""Rigs and animates the small spirit creatures (background Blender).

    blender --background --factory-startup --python tools/rig_creature.py -- \
        --creature fox --in models_raw/clean/fox.glb --out game/assets/models/fox.glb [--preview DIR]

Each creature gets a tiny skeleton and smooth, shape-based weights (their
bodies are simple blobs, so explicit region masks give cleaner squash and
stretch than automatic skinning), then keyframed actions:
  fox:          idle (loop), happy, drink
  moss_spirit:  idle (loop), talk (loop), happy
  blue_spirit:  idle (loop), talk (loop), happy
  rabbit:       idle, eat, alert (loops), hop
  frog:         idle (loop), croak, jump
  owl:          idle (loop), hoot, ruffle, fly (loop); Head left unkeyed for the game
  duck:         swim (loop), peep
  koi/moonfin:  swim, flop (loops)
  butterfly:    flap, rest (loops)
Coordinates are Blender's (Z up, creature faces -Y = +Z in Godot).
"""
import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--creature", required=True)
ap.add_argument("--in", dest="src", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--preview", default="")
args = ap.parse_args(argv)
FPS = 24
X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def ss(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def s(t, cycles=1.0, phase=0.0):
    return math.sin((t * cycles + phase) * math.tau)


# --- Creature definitions ------------------------------------------------------------
# bones: name -> (head, tail, parent). weights(p) -> {bone: weight} (normalized later).

def fox_weights(p):
    tail = ss(0.0, 0.06, p.x) * ss(-0.06, 0.05, p.y) * (1 - ss(0.41, 0.46, p.z))
    if p.z < 0.19:
        tail *= ss(0.07, 0.13, p.x) * ss(0.02, 0.08, p.y)
    head = ss(0.33, 0.39, p.z) * (1 - tail)
    ear = ss(0.51, 0.56, p.z) * head
    body = max(0.0, 1 - tail - head)
    t1 = tail * (1 - ss(0.17, 0.24, p.z))
    t3 = tail * ss(0.30, 0.36, p.z)
    t2 = max(0.0, tail - t1 - t3)
    w = {"Body": body, "Head": head - ear, "Tail1": t1, "Tail2": t2, "Tail3": t3}
    w["EarL" if p.x < -0.04 else "EarR"] = ear
    return w


def fox_idle(t):
    twitch = math.exp(-((t - 0.62) * 22) ** 2)  # one quick ear flick per loop
    return {
        "Body": {"scale": (1 + 0.012 * s(t, 2), 1 + 0.018 * s(t, 2), 1 + 0.012 * s(t, 2))},
        "Head": {"rot": [(Z, 9 * s(t, 1, 0.1)), (X, 4 * s(t, 1, 0.35)), (Y, 5 * s(t, 1, 0.6))]},
        "EarL": {"rot": [(Y, -14 * twitch), (X, 3 * s(t, 2))]},
        "EarR": {"rot": [(X, 3 * s(t, 2, 0.3))]},
        "Tail1": {"rot": [(Z, 8 * s(t, 1))]},
        "Tail2": {"rot": [(Z, 10 * s(t, 1, 0.12))]},
        "Tail3": {"rot": [(Z, 12 * s(t, 1, 0.24)), (X, 5 * s(t, 1, 0.3))]},
    }


def fox_happy(t):
    b = math.sin(t * math.pi)
    wag = s(t, 4) * b
    return {
        "Root": {"loc": (0, 0, 0.05 * abs(math.sin(t * math.pi * 2)))},
        "Head": {"rot": [(X, -14 * b), (Y, 10 * s(t, 1.5))]},
        "EarL": {"rot": [(X, -10 * b)]}, "EarR": {"rot": [(X, -10 * b)]},
        "Tail1": {"rot": [(Z, 22 * wag)]}, "Tail2": {"rot": [(Z, 26 * wag)]}, "Tail3": {"rot": [(Z, 30 * wag)]},
    }


def fox_drink(t):
    d = math.sin(min(t / 0.3, 1.0) * math.pi / 2) if t < 0.75 else math.cos((t - 0.75) / 0.25 * math.pi / 2)
    lap = s(t, 5) * d
    return {
        "Body": {"rot": [(X, 10 * d)]},
        "Head": {"rot": [(X, 32 * d + 4 * lap)]},
        "EarL": {"rot": [(X, 12 * d)]}, "EarR": {"rot": [(X, 12 * d)]},
        "Tail3": {"rot": [(Z, 10 * s(t, 2))]},
    }


def moss_weights(p):
    ear = ss(0.46, 0.52, p.z)
    w = {"Body": 1 - ear}
    w["EarL" if p.x > 0 else "EarR"] = ear
    return w


def moss_idle(t):
    br = s(t, 2)
    return {
        "Body": {"scale": (1 + 0.02 * br, 1 + 0.02 * br, 1 - 0.025 * br), "rot": [(Y, 3 * s(t, 1))]},
        "EarL": {"rot": [(Y, -8 * s(t, 2, 0.1)), (X, 4 * s(t, 1))]},
        "EarR": {"rot": [(Y, 8 * s(t, 2, 0.35)), (X, 4 * s(t, 1, 0.5))]},
    }


def moss_talk(t):
    return {
        "Body": {"scale": (1 + 0.03 * s(t, 3), 1 + 0.03 * s(t, 3), 1 - 0.04 * s(t, 3)), "rot": [(Y, 6 * s(t, 1)), (X, 3 * s(t, 2))]},
        "EarL": {"rot": [(Y, -16 * s(t, 3, 0.1))]},
        "EarR": {"rot": [(Y, 16 * s(t, 3, 0.25))]},
    }


def moss_happy(t):
    hop = math.sin(t * math.pi)
    squash = 1 - 0.12 * math.cos(t * math.pi * 2) * (1 - hop)
    return {
        "Root": {"loc": (0, 0, 0.12 * hop)},
        "Body": {"scale": (2 - squash, 2 - squash, squash)},
        "EarL": {"rot": [(Y, -25 * hop)]}, "EarR": {"rot": [(Y, 25 * hop)]},
    }


def blue_weights(p):
    curl = ss(0.49, 0.56, p.z)
    curl2 = ss(0.62, 0.68, p.z)
    arm = ss(0.17, 0.23, abs(p.x)) * ss(0.12, 0.17, p.z) * (1 - ss(0.34, 0.39, p.z))
    body = max(0.0, 1 - curl - arm)
    w = {"Body": body, "Curl1": curl * (1 - curl2), "Curl2": curl * curl2}
    w["ArmL" if p.x > 0 else "ArmR"] = arm
    return w


def blue_idle(t):
    br = s(t, 2)
    return {
        "Body": {"scale": (1 + 0.02 * br, 1 + 0.02 * br, 1 - 0.02 * br)},
        "Curl1": {"rot": [(X, 6 * s(t, 1)), (Y, 5 * s(t, 1, 0.3))]},
        "Curl2": {"rot": [(X, 8 * s(t, 1, 0.15))]},
        "ArmL": {"rot": [(Y, 10 * s(t, 2))]}, "ArmR": {"rot": [(Y, -10 * s(t, 2, 0.1))]},
    }


def blue_talk(t):
    return {
        "Body": {"rot": [(Y, 7 * s(t, 1)), (X, 4 * s(t, 2))], "scale": (1, 1, 1 + 0.03 * s(t, 3))},
        "Curl1": {"rot": [(Y, 10 * s(t, 2, 0.2))]},
        "ArmL": {"rot": [(Y, 28 + 18 * s(t, 3))]}, "ArmR": {"rot": [(Y, -20 - 14 * s(t, 3, 0.5))]},
    }


def blue_happy(t):
    b = math.sin(t * math.pi)
    return {
        "Root": {"rot": [(Z, 360 * ss(0.05, 0.8, t))], "loc": (0, 0, 0.08 * b)},
        "Curl1": {"rot": [(X, -15 * b)]}, "Curl2": {"rot": [(X, -20 * b)]},
        "ArmL": {"rot": [(Y, 55 * b)]}, "ArmR": {"rot": [(Y, -55 * b)]},
    }


CREATURES = {
    "fox": {
        "bones": {
            "Root": ((0, 0, 0), (0, 0, 0.08), None),
            "Body": ((-0.1, 0.02, 0.02), (-0.07, -0.05, 0.34), "Root"),
            "Head": ((-0.06, -0.06, 0.36), (-0.06, -0.14, 0.55), "Body"),
            "EarL": ((-0.15, -0.06, 0.53), (-0.18, -0.05, 0.70), "Head"),
            "EarR": ((0.06, -0.05, 0.52), (0.10, -0.04, 0.62), "Head"),
            "Tail1": ((0.06, 0.15, 0.08), (0.17, 0.18, 0.2), "Body"),
            "Tail2": ((0.17, 0.18, 0.2), (0.2, 0.15, 0.32), "Tail1"),
            "Tail3": ((0.2, 0.15, 0.32), (0.16, 0.1, 0.42), "Tail2"),
        },
        "weights": fox_weights,
        "actions": [("idle", 4.0, fox_idle, True), ("happy", 1.6, fox_happy, False), ("drink", 2.4, fox_drink, False)],
    },
    "moss_spirit": {
        "bones": {
            "Root": ((0, 0, 0), (0, 0, 0.06), None),
            "Body": ((0, 0, 0.0), (0, 0, 0.46), "Root"),
            "EarL": ((0.07, 0, 0.47), (0.17, 0, 0.64), "Body"),
            "EarR": ((-0.07, 0, 0.47), (-0.17, 0, 0.64), "Body"),
        },
        "weights": moss_weights,
        "actions": [("idle", 3.0, moss_idle, True), ("talk", 1.5, moss_talk, True), ("happy", 0.9, moss_happy, False)],
    },
    "blue_spirit": {
        "bones": {
            "Root": ((0, 0, 0), (0, 0, 0.06), None),
            "Body": ((0, 0, 0.0), (0, 0, 0.5), "Root"),
            "Curl1": ((0, 0, 0.5), (0.0, 0, 0.62), "Body"),
            "Curl2": ((0, 0, 0.62), (0.06, 0, 0.75), "Curl1"),
            "ArmL": ((0.18, 0, 0.26), (0.34, 0, 0.24), "Body"),
            "ArmR": ((-0.18, 0, 0.26), (-0.34, 0, 0.24), "Body"),
        },
        "weights": blue_weights,
        "actions": [("idle", 3.5, blue_idle, True), ("talk", 1.8, blue_talk, True), ("happy", 1.6, blue_happy, False)],
    },
}


# --- Wildlife ---------------------------------------------------------------------------
# All face -Y (Godot +Z). Sizes are real-world meters after prepare_model.

def twitch(t, at, width=0.03):
    return math.exp(-((t - at) / width) ** 2)


def rabbit_weights(p):
    head = ss(0.1, 0.125, p.z)
    ear = ss(0.205, 0.235, p.z) * ss(0.012, 0.03, abs(p.x))
    tail = ss(0.085, 0.1, p.y) * ss(0.025, 0.04, p.z) * (1 - head)
    body = max(0.0, 1 - head - tail)
    w = {"Body": body, "Head": max(0.0, head - ear), "Tail": tail}
    w["EarL" if p.x < 0 else "EarR"] = ear
    return w


def rabbit_idle(t):
    nose = s(t, 18) * (twitch(t, 0.2, 0.06) + twitch(t, 0.7, 0.05))
    return {
        "Body": {"scale": (1 + 0.015 * s(t, 3), 1 + 0.02 * s(t, 3), 1 + 0.01 * s(t, 3))},
        "Head": {"rot": [(X, 1.6 * nose), (Z, 6 * s(t, 1, 0.2))]},
        "EarL": {"rot": [(Z, 8 * s(t, 1)), (X, -6 * twitch(t, 0.45, 0.04))]},
        "EarR": {"rot": [(Z, -6 * s(t, 1, 0.3)), (X, 4 * s(t, 2))]},
        "Tail": {"rot": [(Z, 10 * twitch(t, 0.85, 0.04))]},
    }


def rabbit_eat(t):
    chew = s(t, 6)
    return {
        "Body": {"rot": [(X, 10)], "scale": (1, 1, 1 + 0.01 * s(t, 2))},
        "Head": {"rot": [(X, 30 + 3 * chew), (Z, 4 * s(t, 1))]},
        "EarL": {"rot": [(X, -14), (Z, 6 * s(t, 1))]},
        "EarR": {"rot": [(X, -12), (Z, -5 * s(t, 1, 0.4))]},
    }


def rabbit_alert(t):
    return {
        "Body": {"rot": [(X, -12)], "scale": (1, 1, 1.05)},
        "Head": {"rot": [(X, -10), (Z, 14 * s(t, 1))]},
        "EarL": {"rot": [(X, 6), (Z, 14 * s(t, 1, 0.1))]},
        "EarR": {"rot": [(X, 6), (Z, -14 * s(t, 1, 0.35))]},
    }


def rabbit_hop(t):
    # Push off (nose up, body long), tuck in the air, land nose-down.
    pitch = -18 * math.cos(t * math.pi)
    air = math.sin(t * math.pi)
    return {
        "Body": {"rot": [(X, pitch)], "scale": (1, 1 + 0.1 * air, 1 - 0.06 * air)},
        "Head": {"rot": [(X, -0.5 * pitch)]},
        "EarL": {"rot": [(X, -30 * air)]}, "EarR": {"rot": [(X, -30 * air)]},
        "Tail": {"rot": [(X, -20 * air)]},
    }


def frog_weights(p):
    head = ss(0.058, 0.072, p.z)
    throat = ss(-0.04, -0.055, p.y) * ss(0.035, 0.045, p.z) * (1 - ss(0.07, 0.08, p.z)) * (1 - ss(0.025, 0.035, abs(p.x)))
    leg = ss(0.045, 0.058, abs(p.x)) * (1 - ss(0.05, 0.062, p.z)) * ss(-0.03, -0.015, p.y)
    body = max(0.0, 1 - head - throat - leg)
    w = {"Body": body, "Head": max(0.0, head - throat), "Throat": throat}
    w["LegL" if p.x < 0 else "LegR"] = leg
    return w


def frog_idle(t):
    gulp = 1 + 0.12 * max(0.0, s(t, 4))  # buccal pumping, a frog's quiet breathing
    look = 5 * ss(0.4, 0.5, t) * (1 - ss(0.8, 0.9, t))
    return {
        "Body": {"scale": (1 + 0.01 * s(t, 1), 1, 1 + 0.008 * s(t, 1))},
        "Head": {"rot": [(Z, look)]},
        "Throat": {"scale": (gulp, gulp, gulp)},
    }


def frog_croak(t):
    sac = 1 + 0.75 * max(0.0, math.sin(t * math.pi * 2)) ** 0.7
    return {
        "Body": {"scale": (1 + 0.04 * (sac - 1), 1, 1 - 0.03 * (sac - 1))},
        "Head": {"rot": [(X, -6 * (sac - 1))]},
        "Throat": {"scale": (sac, sac * 0.9, sac)},
    }


def frog_jump(t):
    crouch = ss(0.0, 0.18, t) * (1 - ss(0.18, 0.3, t))
    kick = ss(0.2, 0.42, t)
    return {
        "Root": {"loc": (0, 0, -0.012 * crouch)},
        "Body": {"rot": [(X, -25 * kick + 8 * crouch)]},
        "Head": {"rot": [(X, -10 * kick)]},
        "LegL": {"rot": [(X, -70 * kick + 15 * crouch)]},
        "LegR": {"rot": [(X, -70 * kick + 15 * crouch)]},
    }


def owl_weights(p):
    head = ss(0.19, 0.215, p.z)
    wing = ss(0.085, 0.11, abs(p.x)) * (1 - ss(0.18, 0.21, p.z)) * ss(0.02, 0.05, p.z) * (1 - head)
    tail = ss(0.05, 0.09, p.y) * (1 - ss(0.1, 0.14, p.z)) * (1 - ss(0.05, 0.08, abs(p.x))) * (1 - head)
    body = max(0.0, 1 - head - wing - tail)
    w = {"Body": body, "Head": head, "Tail": tail}
    w["WingL" if p.x < 0 else "WingR"] = wing
    return w


def owl_idle(t):
    br = s(t, 2)
    return {
        "Body": {"scale": (1 + 0.012 * br, 1 + 0.012 * br, 1 + 0.008 * br)},
        "Tail": {"rot": [(Z, 6 * twitch(t, 0.6, 0.03))]},
    }


def owl_hoot(t):
    puff = sum(twitch(t, c, 0.07) for c in (0.25, 0.6))
    return {
        "Body": {"rot": [(X, 9 * puff)], "scale": (1 + 0.07 * puff, 1 + 0.06 * puff, 1 - 0.02 * puff)},
        "Tail": {"rot": [(X, -14 * puff)]},
    }


def owl_ruffle(t):
    burst = ss(0.0, 0.2, t) * (1 - ss(0.45, 0.8, t))
    shake = s(t, 7) * burst
    return {
        "Body": {"scale": (1 + 0.12 * burst, 1 + 0.12 * burst, 1 + 0.05 * burst), "rot": [(Z, 6 * shake)]},
        "WingL": {"rot": [(Y, 14 * burst)]}, "WingR": {"rot": [(Y, -14 * burst)]},
        "Tail": {"rot": [(Z, 12 * shake)]},
    }


def owl_fly(t):
    flap = s(t, 1)
    spread = 75 + 40 * flap
    return {
        "Root": {"loc": (0, 0, -0.01 * flap)},
        "Body": {"rot": [(X, 28)]},
        "WingL": {"rot": [(Y, spread)]}, "WingR": {"rot": [(Y, -spread)]},
        "Tail": {"rot": [(X, -25)]},
    }


def duck_weights(p):
    head = ss(0.054, 0.066, p.z) * (1 - ss(0.0, 0.02, p.y))
    tail = ss(0.04, 0.055, p.y) * ss(0.035, 0.05, p.z)
    body = max(0.0, 1 - head - tail)
    return {"Body": body, "Head": head, "Tail": tail}


def duck_swim(t):
    return {
        "Body": {"rot": [(Y, 2.5 * s(t, 2)), (X, 1.5 * s(t, 2, 0.25))]},
        "Head": {"rot": [(Z, 16 * s(t, 1)), (X, 5 * twitch(t, 0.4, 0.05))]},
        "Tail": {"rot": [(Z, 14 * s(t, 4) * (twitch(t, 0.7, 0.08) + 0.3))]},
    }


def duck_peep(t):
    b = math.sin(t * math.pi)
    return {
        "Head": {"rot": [(X, -18 * b), (Z, 8 * s(t, 2))]},
        "Body": {"scale": (1, 1, 1 + 0.04 * b)},
        "Tail": {"rot": [(Z, 18 * s(t, 3))]},
    }


def fish_weights(spine):
    """Weights along the body axis (Y) between successive spine joints."""
    names = [n for n, _ in spine]
    ys = [y for _, y in spine]

    def w(p):
        out = {}
        for i, n in enumerate(names):
            a = ss(ys[i] - 0.012, ys[i] + 0.012, p.y) if i > 0 else 1.0
            b = 1 - ss(ys[i + 1] - 0.012, ys[i + 1] + 0.012, p.y) if i + 1 < len(ys) else 1.0
            out[n] = max(0.0, a * b)
        return out
    return w


def koi_weights(p):
    w = fish_weights([("Head", -0.21), ("Body", -0.09), ("Tail1", 0.0), ("Tail2", 0.06), ("Tail3", 0.12)])(p)
    fin = ss(0.05, 0.065, abs(p.x)) * (1 - ss(0.05, 0.07, p.z)) * ss(-0.12, -0.1, p.y) * (1 - ss(-0.04, -0.02, p.y))
    for k in w:
        w[k] *= 1 - fin
    w["FinL" if p.x < 0 else "FinR"] = fin
    return w


def moonfin_weights(p):
    return fish_weights([("Head", -0.17), ("Body", -0.08), ("Tail1", 0.02), ("Tail2", 0.07), ("Tail3", 0.11)])(p)


def fish_swim(amp=1.0, straighten=(0.0, 0.0)):
    def f(t):
        def seg(a, lag):
            return a * amp * s(t, 1, -lag)
        return {
            "Head": {"rot": [(Z, seg(3, 0.0))]},
            "Body": {"rot": [(Z, seg(-4, 0.08))]},
            "Tail1": {"rot": [(Z, seg(10, 0.16))]},
            "Tail2": {"rot": [(Z, straighten[0] + seg(15, 0.24))]},
            "Tail3": {"rot": [(Z, straighten[1] + seg(20, 0.32))]},
            "FinL": {"rot": [(Y, 18 * s(t, 2))]},
            "FinR": {"rot": [(Y, -18 * s(t, 2, 0.1))]},
        }
    return f


def fish_flop(straighten=(0.0, 0.0)):
    def f(t):
        bend = s(t, 3)
        return {
            "Head": {"rot": [(Z, -12 * bend)]},
            "Body": {"rot": [(Z, 8 * bend)]},
            "Tail1": {"rot": [(Z, 22 * bend)]},
            "Tail2": {"rot": [(Z, straighten[0] + 28 * bend)]},
            "Tail3": {"rot": [(Z, straighten[1] + 30 * bend)]},
        }
    return f


def butterfly_weights(p):
    wing = ss(0.005, 0.012, abs(p.x))
    w = {"Body": 1 - wing}
    w["WingL" if p.x < 0 else "WingR"] = wing
    return w


def butterfly_flap(t):
    a = 28 + 46 * s(t, 1)
    return {
        "Root": {"loc": (0, 0, -0.004 * s(t, 1))},
        "WingL": {"rot": [(Y, a)]}, "WingR": {"rot": [(Y, -a)]},
    }


def butterfly_rest(t):
    # Basking: wings fold up together, then ease open and hold.
    a = 78 * (1 - ss(0.1, 0.35, t)) + 78 * ss(0.7, 0.95, t) + 8
    return {"WingL": {"rot": [(Y, a)]}, "WingR": {"rot": [(Y, -a)]}}


MOONFIN_STRAIGHT = (14.0, 12.0)

CREATURES.update({
    "rabbit": {
        "bones": {
            "Root": ((0, 0, 0), (0, 0, 0.04), None),
            "Body": ((0, 0.04, 0.02), (0, -0.03, 0.11), "Root"),
            "Head": ((0, -0.03, 0.11), (0, -0.06, 0.2), "Body"),
            "EarL": ((-0.03, -0.03, 0.21), (-0.045, -0.02, 0.31), "Head"),
            "EarR": ((0.035, -0.02, 0.21), (0.07, 0.0, 0.29), "Head"),
            "Tail": ((0, 0.09, 0.06), (0, 0.125, 0.06), "Body"),
        },
        "weights": rabbit_weights,
        "actions": [("idle", 3.0, rabbit_idle, True), ("eat", 2.4, rabbit_eat, True),
                    ("alert", 2.0, rabbit_alert, True), ("hop", 0.32, rabbit_hop, False)],
    },
    "frog": {
        "bones": {
            "Root": ((0, 0, 0), (0, 0, 0.03), None),
            "Body": ((0, 0.02, 0.0), (0, -0.01, 0.06), "Root"),
            "Head": ((0, -0.01, 0.06), (0, -0.02, 0.13), "Body"),
            "Throat": ((0, -0.045, 0.055), (0, -0.068, 0.055), "Head"),
            "LegL": ((-0.05, 0.02, 0.03), (-0.06, 0.05, 0.005), "Body"),
            "LegR": ((0.05, 0.02, 0.03), (0.06, 0.05, 0.005), "Body"),
        },
        "weights": frog_weights,
        "actions": [("idle", 3.0, frog_idle, True), ("croak", 0.8, frog_croak, False), ("jump", 0.55, frog_jump, False)],
    },
    "owl": {
        "bones": {
            "Root": ((0, 0, 0), (0, 0, 0.05), None),
            "Body": ((0, 0, 0.02), (0, 0, 0.2), "Root"),
            "Head": ((0, 0, 0.2), (0, 0, 0.36), "Body"),
            "WingL": ((-0.09, 0.0, 0.19), (-0.12, 0.06, 0.04), "Body"),
            "WingR": ((0.09, 0.0, 0.19), (0.12, 0.06, 0.04), "Body"),
            "Tail": ((0, 0.05, 0.07), (0, 0.15, 0.01), "Body"),
        },
        "weights": owl_weights,
        "skip_keys": ["Head"],  # the game turns the head itself
        "actions": [("idle", 4.0, owl_idle, True), ("hoot", 1.6, owl_hoot, False),
                    ("ruffle", 1.0, owl_ruffle, False), ("fly", 0.6, owl_fly, True)],
    },
    "duck": {
        "bones": {
            "Root": ((0, 0, 0), (0, 0, 0.02), None),
            "Body": ((0, 0.03, 0.0), (0, -0.02, 0.055), "Root"),
            "Head": ((0, -0.025, 0.058), (0, -0.03, 0.125), "Body"),
            "Tail": ((0, 0.045, 0.045), (0, 0.066, 0.068), "Body"),
        },
        "weights": duck_weights,
        "actions": [("swim", 2.4, duck_swim, True), ("peep", 0.5, duck_peep, False)],
    },
    "koi": {
        "bones": {
            "Root": ((0, 0, 0), (0, 0, 0.05), None),
            "Head": ((0, -0.21, 0.12), (0, -0.09, 0.12), "Root"),
            "Body": ((0, -0.09, 0.12), (0, 0.0, 0.12), "Head"),
            "Tail1": ((0, 0.0, 0.12), (0, 0.06, 0.12), "Body"),
            "Tail2": ((0, 0.06, 0.12), (0, 0.12, 0.13), "Tail1"),
            "Tail3": ((0, 0.12, 0.13), (0, 0.21, 0.14), "Tail2"),
            "FinL": ((-0.05, -0.08, 0.05), (-0.09, -0.06, 0.02), "Head"),
            "FinR": ((0.05, -0.08, 0.05), (0.09, -0.06, 0.02), "Head"),
        },
        "weights": koi_weights,
        "actions": [("swim", 1.4, fish_swim(), True), ("flop", 0.5, fish_flop(), True)],
    },
    "moonfin": {
        "bones": {
            "Root": ((0, 0, 0), (0, 0, 0.05), None),
            "Head": ((0, -0.17, 0.08), (0, -0.08, 0.08), "Root"),
            "Body": ((0, -0.08, 0.08), (0, 0.02, 0.08), "Head"),
            "Tail1": ((0, 0.02, 0.08), (0.005, 0.07, 0.07), "Body"),
            "Tail2": ((0.005, 0.07, 0.07), (0.025, 0.11, 0.07), "Tail1"),
            "Tail3": ((0.025, 0.11, 0.07), (0.068, 0.17, 0.08), "Tail2"),
        },
        "weights": moonfin_weights,
        "actions": [("swim", 1.1, fish_swim(1.0, MOONFIN_STRAIGHT), True),
                    ("flop", 0.45, fish_flop(MOONFIN_STRAIGHT), True)],
    },
    "butterfly": {
        "bones": {
            "Root": ((0, 0, 0), (0, 0, 0.01), None),
            "Body": ((0, 0.02, 0.008), (0, -0.02, 0.008), "Root"),
            "WingL": ((-0.006, 0, 0.009), (-0.045, 0, 0.009), "Body"),
            "WingR": ((0.006, 0, 0.009), (0.045, 0, 0.009), "Body"),
        },
        "weights": butterfly_weights,
        "actions": [("flap", 0.28, butterfly_flap, True), ("rest", 4.0, butterfly_rest, True)],
    },
})

cfg = CREATURES[args.creature]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args.src)
body = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]

arm_data = bpy.data.armatures.new(args.creature + "_rig")
rig = bpy.data.objects.new(args.creature + "_rig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for name, (head, tail, parent) in cfg["bones"].items():
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = Vector(head), Vector(tail)
    if parent:
        b.parent = arm_data.edit_bones[parent]
    b.align_roll(Vector((0, -1, 0)) if abs(b.vector.z) > abs(b.vector.y) else Vector((0, 0, 1)))
bpy.ops.object.mode_set(mode="OBJECT")

# Shape-based weights.
groups = {name: body.vertex_groups.new(name=name) for name in cfg["bones"]}
for v in body.data.vertices:
    p = body.matrix_world @ v.co
    w = {k: max(0.0, val) for k, val in cfg["weights"](p).items()}
    total = sum(w.values()) or 1.0
    for k, val in w.items():
        if val / total > 0.001:
            groups[k].add([v.index], val / total, "REPLACE")
body.parent = rig
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = rig

pose = rig.pose.bones
for pb in pose:
    pb.rotation_mode = "QUATERNION"


def local_rot(name, axis, degrees):
    rest = rig.data.bones[name].matrix_local.to_3x3()
    q = Quaternion(Vector(axis), math.radians(degrees))
    return (rest.inverted() @ q.to_matrix() @ rest).to_quaternion()


def key_frame(frame, spec):
    for pb in pose:
        if pb.name in cfg.get("skip_keys", []):
            continue
        bspec = spec.get(pb.name, {})
        q = Quaternion()
        for axis, deg in bspec.get("rot", []):
            q = local_rot(pb.name, axis, deg) @ q
        pb.rotation_quaternion = q
        pb.scale = Vector(bspec.get("scale", (1, 1, 1)))
        loc = Vector(bspec.get("loc", (0, 0, 0)))
        # Location keys are given in armature space; convert to the bone's rest frame.
        pb.location = rig.data.bones[pb.name].matrix_local.to_3x3().inverted() @ loc
        pb.keyframe_insert("rotation_quaternion", frame=frame, group=pb.name)
        pb.keyframe_insert("scale", frame=frame, group=pb.name)
        pb.keyframe_insert("location", frame=frame, group=pb.name)


rig.animation_data_create()
actions = []
for name, length, sampler, loop in cfg["actions"]:
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    frames = int(length * FPS)
    for f in range(0, frames + 1, 2):
        key_frame(f, sampler(f / frames))
    if loop:
        key_frame(frames, sampler(0.0))
    act.frame_range = (0, frames)
    actions.append(act)
    rig.animation_data.action = None
for a in actions:
    track = rig.animation_data.nla_tracks.new()
    track.name = a.name
    track.strips.new(a.name, 0, a)
    track.mute = True

Path(args.out).parent.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB", export_animations=True,
                          export_animation_mode="NLA_TRACKS", export_skins=True, export_yup=True,
                          export_force_sampling=True)
print("CREATURE_DONE", args.creature, [a.name for a in actions])

if args.preview:
    out = Path(args.preview)
    out.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = 360
    scene.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.07, 0.12, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.5
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    dims = body.dimensions
    size = max(dims) * 1.5
    cam.data.ortho_scale = size
    cam.data.clip_start = 0.001
    centre = Vector((0, 0, dims.z * 0.5))
    cam.location = centre + Vector((0.9, -2.2, 0.55)).normalized() * size * 4
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for a in actions:
        rig.animation_data.action = a
        n = int(a.frame_range[1])
        for i, f in enumerate((0, n // 4, n // 2)):
            scene.frame_set(f)
            scene.render.filepath = str(out / f"{args.creature}_{a.name}_{i}.png")
            bpy.ops.render.render(write_still=True)
