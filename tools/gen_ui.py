"""Generates the parchment UI kit for Lantern Hollow into game/assets/ui/.

    python tools/gen_ui.py

Everything is drawn at 4x and downsampled for clean anti-aliasing. Cards and
buttons are 9-patch textures (Godot StyleBoxTexture); the margins used in
ui.gd are noted next to each one. Palette follows the UI concepts: warm
parchment, moss-green buttons with gold trim, navy ink.
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "ui"
OUT.mkdir(parents=True, exist_ok=True)
SS = 4  # supersampling

PAPER = (241, 230, 204)
PAPER_DARK = (230, 214, 178)
BURN = (160, 124, 78)
GREEN = (62, 88, 52)
GREEN_DARK = (40, 60, 36)
GREEN_LIGHT = (84, 116, 68)
GOLD = (214, 172, 86)
GOLD_LIGHT = (246, 214, 138)
GOLD_DARK = (128, 92, 38)
INK = (34, 46, 62)

rng = np.random.default_rng(7)
random.seed(7)


def noise(w, h, scale, seed=0):
    """Smooth value noise in 0..1 (blurred random field)."""
    r = np.random.default_rng(seed)
    small = r.random((max(2, h // scale), max(2, w // scale)))
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(img.filter(ImageFilter.GaussianBlur(scale * 0.25)), dtype=np.float32) / 255.0


def save(img, name, size=None):
    if size:
        img = img.resize(size, Image.LANCZOS)
    img.save(OUT / name)
    print("wrote", name, img.size)


# --- Paper --------------------------------------------------------------------------

def paper_texture(w, h, edge=26, rough=5, seed=1, shade=1.0):
    """Parchment rectangle with mottling, fibers, burnt edges and a ragged outline."""
    base = np.zeros((h, w, 3), np.float32)
    mott = noise(w, h, 48, seed) * 0.6 + noise(w, h, 12, seed + 1) * 0.4
    for c in range(3):
        base[..., c] = PAPER_DARK[c] + (PAPER[c] - PAPER_DARK[c]) * (0.35 + 0.65 * mott)
    # Fine grain and fibers.
    grain = rng.normal(0, 3.2, (h, w))
    base += grain[..., None]
    fib = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(fib)
    for _ in range(int(w * h / 900)):
        x, y = random.uniform(0, w), random.uniform(0, h)
        a = random.uniform(0, math.pi)
        ln = random.uniform(6, 22)
        d.line([(x, y), (x + math.cos(a) * ln, y + math.sin(a) * ln)], fill=random.randint(20, 60), width=1)
    fib = np.asarray(fib.filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0
    base -= fib[..., None] * 18
    # Distance to the (ragged) edge drives the burn and alpha.
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dist = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy])
    wobble = (noise(w, h, 10, seed + 5) - 0.5) * 2 * rough + (noise(w, h, 3, seed + 6) - 0.5) * rough * 0.7
    d2 = dist + wobble
    burn = np.clip(1 - d2 / edge, 0, 1) ** 1.7
    spots = np.clip((noise(w, h, 30, seed + 9) - 0.66) * 3.0, 0, 1) * 0.1
    for c in range(3):
        base[..., c] = base[..., c] * (1 - burn * 0.55 - spots) + BURN[c] * (burn * 0.55 + spots)
    base *= shade
    alpha = np.clip((d2 - rough * 0.6) * 0.9, 0, 1) * 255
    rgba = np.dstack([np.clip(base, 0, 255), alpha]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def rivet(d, cx, cy, r):
    """Small domed brass stud."""
    d.ellipse([cx - r, cy - r + SS, cx + r + SS, cy + r + 2 * SS], fill=(90, 66, 34, 70))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD_DARK)
    d.ellipse([cx - r * 0.82, cy - r * 0.86, cx + r * 0.78, cy + r * 0.74], fill=GOLD)
    d.ellipse([cx - r * 0.5, cy - r * 0.6, cx + r * 0.1, cy - r * 0.05], fill=GOLD_LIGHT)


def with_shadow(img, blur=10, offset=(0, 6), opacity=0.45, pad=18):
    w, h = img.size
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    a = img.split()[3]
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sh.paste((20, 14, 8, int(255 * opacity)), (pad + offset[0], pad + offset[1]), a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(sh)
    canvas.alpha_composite(img, (pad, pad))
    return canvas


def card():
    # 9-patch margins: 56 on all sides (rivets sit inside the corners). Includes an 18px shadow pad.
    s = 448
    img = paper_texture(s, s, edge=34, rough=4, seed=3)
    d = ImageDraw.Draw(img)
    for cx, cy in [(24, 24), (s - 24, 24), (24, s - 24), (s - 24, s - 24)]:
        rivet(d, cx, cy, 7)
    save(with_shadow(img), "card.png")


def plate(name, w, h, kind, seed):
    """Button / chip plates. 9-patch margins: 22 left/right, 20 top/bottom."""
    W, H = w * SS, h * SS
    if kind == "paper":
        img = paper_texture(w, h, edge=12, rough=1.6, seed=seed, shade=1.02).resize((W, H), Image.BICUBIC)
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([5 * SS, 5 * SS, W - 5 * SS, H - 5 * SS], radius=5 * SS, outline=(176, 146, 96, 200), width=int(1.2 * SS))
    else:
        top, bot = (GREEN_LIGHT, GREEN) if kind == "green_hover" else (GREEN, GREEN_DARK)
        if kind == "green_press":
            top, bot = GREEN_DARK, GREEN_DARK
        grad = np.linspace(0, 1, H)[:, None, None]
        arr = np.array(top, np.float32) * (1 - grad) + np.array(bot, np.float32) * grad
        arr = np.repeat(arr, W, axis=1)
        arr += (noise(W, H, 60, seed)[..., None] - 0.5) * 7
        img = Image.fromarray(np.dstack([np.clip(arr, 0, 255), np.full((H, W), 255)]).astype(np.uint8), "RGBA")
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], radius=7 * SS, fill=255)
        img.putalpha(mask)
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([1 * SS, 1 * SS, W - 1 * SS, H - 1 * SS], radius=7 * SS, outline=GOLD_DARK, width=int(1.5 * SS))
        d.rounded_rectangle([3 * SS, 3 * SS, W - 3 * SS, H - 3 * SS], radius=6 * SS, outline=GOLD, width=int(2 * SS))
        d.rounded_rectangle([5.5 * SS, 5.5 * SS, W - 5.5 * SS, H - 5.5 * SS], radius=5 * SS, outline=(255, 236, 170, 70), width=SS)
    d = ImageDraw.Draw(img)
    for cx, cy in [(11, 11), (w - 11, 11), (11, h - 11), (w - 11, h - 11)]:
        rivet(d, cx * SS, cy * SS, 3.4 * SS)
    img = img.resize((w, h), Image.LANCZOS)
    save(with_shadow(img, blur=4, offset=(0, 3), opacity=0.35, pad=6), name)


def key_badge():
    # 9-patch margins: 12. Dark green keycap with a cream rim.
    w = h = 48
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 2 * SS, W - 1, H - 1], radius=8 * SS, fill=(18, 30, 20, 255))
    d.rounded_rectangle([0, 0, W - 1, H - 3 * SS], radius=8 * SS, fill=GREEN_DARK)
    d.rounded_rectangle([3 * SS, 3 * SS, W - 3 * SS, H - 6 * SS], radius=6 * SS, outline=(230, 220, 190, 220), width=int(1.4 * SS))
    save(img.resize((w, h), Image.LANCZOS), "key.png")


# --- Ornaments and icons ---------------------------------------------------------------

def leaf_poly(cx, cy, length, width, angle, n=24):
    pts = []
    for i in range(n + 1):
        t = i / n
        wv = math.sin(math.pi * t) ** 0.85 * width * (1 - 0.25 * t)
        pts.append((t * length, wv))
    for i in range(n, -1, -1):
        t = i / n
        wv = math.sin(math.pi * t) ** 0.85 * width * (1 - 0.25 * t)
        pts.append((t * length, -wv * 0.92))
    ca, sa = math.cos(angle), math.sin(angle)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]


def draw_leaf(d, cx, cy, length, width, angle, fill, vein):
    d.polygon(leaf_poly(cx, cy, length, width, angle), fill=fill)
    ex, ey = cx + math.cos(angle) * length * 0.92, cy + math.sin(angle) * length * 0.92
    d.line([(cx, cy), (ex, ey)], fill=vein, width=max(1, int(length * 0.045)))


def sprig(size, color, vein, name, leaves=3, curve=0.25):
    """Stem with paired leaves and a tip leaf, like the concept's leaf emblem."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = (S * 0.5, S * 0.94)
    tip = (S * 0.52, S * 0.1)
    pts = []
    for i in range(21):
        t = i / 20
        x = base[0] + (tip[0] - base[0]) * t + math.sin(t * math.pi) * S * curve * 0.25
        y = base[1] + (tip[1] - base[1]) * t
        pts.append((x, y))
    d.line(pts, fill=color, width=max(2, int(S * 0.035)), joint="curve")
    for k in range(leaves):
        t = 0.3 + 0.5 * k / max(1, leaves - 1) if leaves > 1 else 0.5
        x, y = pts[int(t * 20)]
        ln = S * (0.36 - 0.08 * t)
        draw_leaf(d, x, y, ln, ln * 0.33, -math.pi / 2 - 0.95 + 0.1 * t, color, vein)
        draw_leaf(d, x, y, ln * 0.95, ln * 0.31, -math.pi / 2 + 0.95 - 0.1 * t, color, vein)
    draw_leaf(d, pts[-3][0], pts[-3][1], S * 0.24, S * 0.08, -math.pi / 2 + 0.08, color, vein)
    save(img, name, (size, size))


def coin_icon():
    s = 64
    S = s * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    d.ellipse([c - S * 0.44, c - S * 0.42, c + S * 0.44, c + S * 0.46], fill=(100, 66, 20, 150))
    d.ellipse([c - S * 0.44, c - S * 0.46, c + S * 0.44, c + S * 0.42], fill=GOLD_DARK)
    d.ellipse([c - S * 0.4, c - S * 0.43, c + S * 0.4, c + S * 0.37], fill=(232, 178, 64))
    d.ellipse([c - S * 0.3, c - S * 0.33, c + S * 0.3, c + S * 0.27], outline=(178, 126, 36), width=int(S * 0.03))
    d.ellipse([c - S * 0.28, c - S * 0.36, c - S * 0.02, c - S * 0.16], fill=(255, 230, 150, 200))
    save(img, "coin.png", (s, s))


def bait_icon():
    """Leaf-wrapped bait bundle (the keeper wraps bait in a leaf)."""
    s = 64
    S = s * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for a, l, col in [(-2.2, 0.46, (58, 92, 52)), (-1.0, 0.46, (70, 104, 58)), (-1.6, 0.5, (88, 124, 70))]:
        draw_leaf(d, S * 0.5, S * 0.86, S * l, S * l * 0.42, a, col, (150, 180, 120))
    d.ellipse([S * 0.36, S * 0.5, S * 0.64, S * 0.74], fill=(150, 112, 62))
    d.ellipse([S * 0.4, S * 0.53, S * 0.52, S * 0.62], fill=(190, 152, 96))
    d.line([(S * 0.34, S * 0.72), (S * 0.66, S * 0.66)], fill=(214, 190, 140), width=int(S * 0.035))
    save(img, "bait.png", (s, s))


def gear_icon():
    s = 64
    S = s * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = S / 2
    pts = []
    for i in range(16):
        a = i / 16 * math.tau
        r = S * (0.44 if i % 2 == 0 else 0.33)
        for da in (-0.1, 0.1):
            pts.append((c + math.cos(a + da) * r, c + math.sin(a + da) * r))
    d.polygon(pts, fill=(238, 226, 196))
    d.ellipse([c - S * 0.3, c - S * 0.3, c + S * 0.3, c + S * 0.3], fill=(238, 226, 196))
    d.ellipse([c - S * 0.12, c - S * 0.12, c + S * 0.12, c + S * 0.12], fill=(0, 0, 0, 0))
    save(img, "gear.png", (s, s))


def check_icon():
    s = 32
    S = s * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([S * 0.04, S * 0.04, S * 0.96, S * 0.96], fill=(70, 120, 60))
    d.line([(S * 0.27, S * 0.52), (S * 0.43, S * 0.68), (S * 0.74, S * 0.34)], fill=(245, 240, 220), width=int(S * 0.11), joint="curve")
    save(img, "check.png", (s, s))


def lantern_icon():
    """Gold lantern with laurel sprigs for the title crest."""
    w, h = 160, 120
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = W / 2
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([cx - 38 * SS, 30 * SS, cx + 38 * SS, 104 * SS], fill=(255, 190, 90, 120))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(14 * SS)))
    d = ImageDraw.Draw(img)
    d.arc([cx - 8 * SS, 2 * SS, cx + 8 * SS, 18 * SS], 180, 360, fill=GOLD, width=3 * SS)
    d.polygon([(cx - 22 * SS, 30 * SS), (cx + 22 * SS, 30 * SS), (cx + 15 * SS, 18 * SS), (cx - 15 * SS, 18 * SS)], fill=GOLD)
    d.rounded_rectangle([cx - 20 * SS, 30 * SS, cx + 20 * SS, 86 * SS], radius=8 * SS, fill=(255, 214, 128))
    d.rounded_rectangle([cx - 20 * SS, 30 * SS, cx + 20 * SS, 86 * SS], radius=8 * SS, outline=GOLD_DARK, width=3 * SS)
    for x in (-7, 7):
        d.line([(cx + x * SS, 32 * SS), (cx + x * SS, 84 * SS)], fill=(200, 140, 50), width=2 * SS)
    d.ellipse([cx - 7 * SS, 46 * SS, cx + 7 * SS, 68 * SS], fill=(255, 250, 220))
    d.polygon([(cx - 24 * SS, 86 * SS), (cx + 24 * SS, 86 * SS), (cx + 16 * SS, 96 * SS), (cx - 16 * SS, 96 * SS)], fill=GOLD)
    # Laurels.
    for side in (-1, 1):
        for k in range(4):
            x = cx + side * (40 + k * 11) * SS
            y = (92 - k * 12) * SS
            draw_leaf(d, x, y, 22 * SS, 7 * SS, -math.pi / 2 + side * (0.9 - k * 0.12), GOLD, GOLD_DARK)
    save(img, "lantern.png", (w, h))


def ribbon():
    """Green bookmark ribbon with a notched tail and a gold leaf emblem."""
    w, h = 56, 140
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    body = [(0, 0), (W, 0), (W, H), (W / 2, H - 16 * SS), (0, H)]
    d.polygon(body, fill=GREEN)
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.rectangle([0, 0, 6 * SS, H], fill=(0, 0, 0, 50))
    sd.rectangle([W - 6 * SS, 0, W, H], fill=(0, 0, 0, 70))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(body, fill=255)
    img.alpha_composite(Image.composite(shade, Image.new("RGBA", (W, H)), mask))
    d = ImageDraw.Draw(img)
    for x in (4 * SS, W - 5 * SS):
        d.line([(x, 0), (x, H - 4 * SS)], fill=GOLD, width=int(1.3 * SS))
    stitch_y = 0
    while stitch_y < H - 30 * SS:
        d.line([(9 * SS, stitch_y), (9 * SS, stitch_y + 4 * SS)], fill=(170, 190, 140, 120), width=SS)
        d.line([(W - 10 * SS, stitch_y), (W - 10 * SS, stitch_y + 4 * SS)], fill=(170, 190, 140, 120), width=SS)
        stitch_y += 8 * SS
    # Leaf emblem.
    ex, ey = W / 2, H * 0.62
    d.line([(ex, ey + 18 * SS), (ex, ey - 16 * SS)], fill=GOLD_LIGHT, width=2 * SS)
    for k, yy in enumerate((ey + 6 * SS, ey - 4 * SS)):
        draw_leaf(d, ex, yy, 15 * SS, 5 * SS, -math.pi / 2 - 0.8, GOLD_LIGHT, GOLD_DARK)
        draw_leaf(d, ex, yy, 15 * SS, 5 * SS, -math.pi / 2 + 0.8, GOLD_LIGHT, GOLD_DARK)
    draw_leaf(d, ex, ey - 12 * SS, 12 * SS, 4 * SS, -math.pi / 2, GOLD_LIGHT, GOLD_DARK)
    img = img.resize((w, h), Image.LANCZOS)
    save(with_shadow(img, blur=3, offset=(2, 3), opacity=0.4, pad=6), "ribbon.png")


def divider():
    w, h = 320, 24
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cy = H / 2
    col = (150, 116, 60, 230)
    d.line([(10 * SS, cy), (W / 2 - 18 * SS, cy)], fill=col, width=int(1.2 * SS))
    d.line([(W / 2 + 18 * SS, cy), (W - 10 * SS, cy)], fill=col, width=int(1.2 * SS))
    for sx in (-1, 1):
        x = W / 2 + sx * 12 * SS
        d.polygon([(x - 3 * SS, cy), (x, cy - 3 * SS), (x + 3 * SS, cy), (x, cy + 3 * SS)], fill=col)
    draw_leaf(d, W / 2, cy + 5 * SS, 11 * SS, 3.6 * SS, -math.pi / 2 - 0.6, GOLD_DARK, GOLD)
    draw_leaf(d, W / 2, cy + 5 * SS, 11 * SS, 3.6 * SS, -math.pi / 2 + 0.6, GOLD_DARK, GOLD)
    draw_leaf(d, W / 2, cy + 4 * SS, 10 * SS, 3 * SS, -math.pi / 2, GOLD_DARK, GOLD)
    save(img, "divider.png", (w, h))


def emblem():
    """Round parchment medallion with a leaf, for the speaker in dialogue."""
    s = 96
    S = s * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2 * SS, 4 * SS, S - 2 * SS, S], fill=(80, 60, 30, 90))
    d.ellipse([2 * SS, 2 * SS, S - 2 * SS, S - 4 * SS], fill=(236, 224, 196), outline=(170, 138, 86), width=int(2 * SS))
    d.ellipse([8 * SS, 8 * SS, S - 8 * SS, S - 10 * SS], outline=(200, 176, 128), width=SS)
    img2 = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dd = ImageDraw.Draw(img2)
    cx, base, top = S / 2, S * 0.78, S * 0.24
    dd.line([(cx, base), (cx + 2 * SS, top)], fill=GREEN, width=int(2.4 * SS))
    for yy, ln in ((S * 0.62, 26), (S * 0.47, 22)):
        draw_leaf(dd, cx + SS, yy, ln * SS, ln * 0.36 * SS, -math.pi / 2 - 0.85, GREEN, (130, 160, 110))
        draw_leaf(dd, cx + SS, yy, ln * SS, ln * 0.36 * SS, -math.pi / 2 + 0.85, GREEN, (130, 160, 110))
    draw_leaf(dd, cx + 2 * SS, S * 0.34, 18 * SS, 6 * SS, -math.pi / 2, GREEN, (130, 160, 110))
    img.alpha_composite(img2)
    save(img, "emblem.png", (s, s))


def slider_parts():
    # Track (9-patch 8): recessed parchment groove. Fill (9-patch 8): moss green. Grabber: brass-rimmed knob.
    w, h = 64, 16
    W, H = w * SS, h * SS
    t = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(t)
    d.rounded_rectangle([0, 2 * SS, W - 1, H - 2 * SS], radius=6 * SS, fill=(205, 186, 150), outline=(160, 130, 86), width=SS)
    d.rounded_rectangle([SS, 3 * SS, W - SS, 6 * SS], radius=3 * SS, fill=(170, 146, 106, 120))
    save(t, "slider_track.png", (w, h))
    f = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(f)
    d.rounded_rectangle([0, 2 * SS, W - 1, H - 2 * SS], radius=6 * SS, fill=GREEN, outline=GREEN_DARK, width=SS)
    d.rounded_rectangle([2 * SS, 4 * SS, W - 2 * SS, 7 * SS], radius=3 * SS, fill=(120, 150, 100, 110))
    save(f, "slider_fill.png", (w, h))
    s = 36
    S = s * SS
    g = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    d.ellipse([2 * SS, 4 * SS, S - 2 * SS, S - 0], fill=(40, 28, 12, 110))
    d.ellipse([2 * SS, 2 * SS, S - 2 * SS, S - 3 * SS], fill=GOLD_DARK)
    d.ellipse([4 * SS, 4 * SS, S - 4 * SS, S - 5 * SS], fill=GOLD)
    d.ellipse([7 * SS, 7 * SS, S - 7 * SS, S - 8 * SS], fill=GREEN)
    d.ellipse([10 * SS, 9 * SS, S - 16 * SS, S - 18 * SS], fill=(120, 150, 100))
    save(g, "slider_grabber.png", (s, s))


def check_box(on):
    s = 36
    S = s * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([2 * SS, 2 * SS, S - 2 * SS, S - 2 * SS], radius=6 * SS, fill=(225, 210, 176), outline=(150, 120, 74), width=int(1.6 * SS))
    if on:
        d.rounded_rectangle([7 * SS, 7 * SS, S - 7 * SS, S - 7 * SS], radius=3 * SS, fill=GREEN)
        d.line([(11 * SS, 18 * SS), (16 * SS, 24 * SS), (26 * SS, 12 * SS)], fill=(245, 236, 210), width=int(3 * SS), joint="curve")
    save(img, "check_on.png" if on else "check_off.png", (s, s))


def book():
    """Open journal: leather cover, two parchment pages and a spine shadow. 9-patch margins: 70."""
    w, h = 1000, 640
    cover = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(cover)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=26, fill=(92, 58, 36))
    leather = (noise(w, h, 14, 21) - 0.5) * 40
    arr = np.asarray(cover, np.float32)
    arr[..., :3] += leather[..., None]
    cover = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(cover)
    d.rounded_rectangle([6, 6, w - 7, h - 7], radius=22, outline=(150, 108, 62), width=2)
    pages = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    left = paper_texture(w // 2 - 22, h - 40, edge=30, rough=2, seed=31)
    right = paper_texture(w // 2 - 22, h - 40, edge=30, rough=2, seed=32)
    pages.alpha_composite(left, (22, 20))
    pages.alpha_composite(right, (w // 2, 20))
    # Spine shading toward the gutter.
    spine = np.zeros((h, w), np.float32)
    xs = np.arange(w, dtype=np.float32)
    g = np.exp(-((xs - w / 2) / 34.0) ** 2) * 120
    spine[:, :] = g[None, :]
    shade = Image.fromarray(np.dstack([np.zeros((h, w, 3)), spine]).astype(np.uint8), "RGBA")
    pa = pages.split()[3]
    pages.alpha_composite(Image.composite(shade, Image.new("RGBA", (w, h)), pa))
    cover.alpha_composite(pages)
    d = ImageDraw.Draw(cover)
    for cx, cy in [(30, 28), (w - 30, 28), (30, h - 28), (w - 30, h - 28)]:
        d.polygon([(cx - 16 if cx < w / 2 else cx + 16, cy), (cx, cy - 16 if cy < h / 2 else cy + 16),
                   (cx - 16 if cx < w / 2 else cx + 16, cy - 16 if cy < h / 2 else cy + 16)], fill=GOLD)
        rivet(d, cx, cy, 6)
    save(with_shadow(cover, blur=14, offset=(0, 10), opacity=0.5, pad=24), "book.png")


def vignette():
    """Soft dark wash behind the title menu so cream text reads over the live scene."""
    w, h = 512, 64
    xs = np.linspace(0, 1, w)
    a = np.clip(1 - xs / 0.95, 0, 1) ** 1.6 * 200
    arr = np.zeros((h, w, 4), np.uint8)
    arr[..., 0], arr[..., 1], arr[..., 2] = 8, 14, 26
    arr[..., 3] = a[None, :].astype(np.uint8)
    save(Image.fromarray(arr, "RGBA"), "vignette.png")


def bobber_icon():
    """Bobber with ripples for the 'A little tug!' card."""
    w, h = 220, 120
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = W / 2, H * 0.68
    for k, (rx, ry) in enumerate(((100, 22), (76, 16), (52, 11))):
        d.ellipse([cx - rx * SS, cy - ry * SS, cx + rx * SS, cy + ry * SS], outline=(214, 172, 86, 200 - k * 30), width=int(1.6 * SS))
    d.ellipse([cx - 34 * SS, cy - 8 * SS, cx + 34 * SS, cy + 8 * SS], fill=(150, 190, 200, 120))
    d.chord([cx - 18 * SS, cy - 40 * SS, cx + 18 * SS, cy - 4 * SS], 180, 360, fill=(200, 50, 40))
    d.chord([cx - 18 * SS, cy - 40 * SS, cx + 18 * SS, cy - 4 * SS], 0, 180, fill=(240, 232, 214))
    d.ellipse([cx - 7 * SS, cy - 34 * SS, cx - 1 * SS, cy - 28 * SS], fill=(255, 210, 200))
    d.line([(cx, cy - 40 * SS), (cx, cy - 50 * SS)], fill=(50, 40, 30), width=2 * SS)
    for a in (-0.5, 0.0, 0.5):
        x0, y0 = cx + math.sin(a) * 30 * SS, cy - 60 * SS - math.cos(a) * 2 * SS
        d.line([(x0, y0), (x0 + math.sin(a) * 9 * SS, y0 - math.cos(a) * 9 * SS)], fill=(214, 172, 86), width=int(2.4 * SS))
    save(img, "bobber.png", (w, h))


if __name__ == "__main__":
    card()
    plate("btn_paper.png", 220, 64, "paper", 11)
    plate("btn_green.png", 220, 64, "green", 12)
    plate("btn_green_hover.png", 220, 64, "green_hover", 13)
    plate("btn_green_press.png", 220, 64, "green_press", 14)
    plate("chip.png", 160, 52, "paper", 15)
    key_badge()
    sprig(64, GREEN, (140, 170, 120), "leaf.png")
    sprig(64, GOLD, GOLD_DARK, "leaf_gold.png")
    sprig(64, (238, 226, 196), (160, 180, 140), "leaf_cream.png")
    sprig(64, (160, 160, 140), (210, 210, 190), "leaf_faded.png")
    coin_icon()
    bait_icon()
    gear_icon()
    check_icon()
    lantern_icon()
    ribbon()
    divider()
    emblem()
    slider_parts()
    check_box(True)
    check_box(False)
    book()
    vignette()
    bobber_icon()
