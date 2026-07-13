# -*- coding: utf-8 -*-
"""Prozedurale, nahtlose Würfel-Texturen für Fumble.

Alle Muster sind per Konstruktion kachelbar: Gauß-Weichzeichnung läuft über
FFT (periodische Faltung), Distanzen sind torus-gewrappt, Wellen nutzen
ganzzahlige Frequenzen. Die Texturen sind hell und kontrastarm (dunkle Ziffern
liegen im Spiel darüber) und tragen nur einen Hauch Eigenfarbe - die kräftige
Materialfarbe liefert weiterhin das Tint-System (DieMaterial.tint_for).
"""
import numpy as np
from PIL import Image
import os

S = 512
OUT = r"E:\Godot\die\assets\textures\dice"
rng = np.random.default_rng(7)


def fft_blur(img, sigma_x, sigma_y=None):
    """Periodische (= nahtlose) Gauß-Faltung. sigma_x wirkt horizontal."""
    if sigma_y is None:
        sigma_y = sigma_x
    fy = np.fft.fftfreq(S)[:, None]
    fx = np.fft.fftfreq(S)[None, :]
    g = np.exp(-2 * (np.pi ** 2) * ((sigma_x ** 2) * fx ** 2 + (sigma_y ** 2) * fy ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(img) * g))


def norm01(a):
    a = a - a.min()
    return a / max(a.ptp(), 1e-9)


def noise(sigma):
    """Weiches periodisches Rauschen 0..1."""
    return norm01(fft_blur(rng.standard_normal((S, S)), sigma))


def wrapped_dist(yy, xx, cy, cx):
    dy = np.abs(yy - cy)
    dy = np.minimum(dy, S - dy)
    dx = np.abs(xx - cx)
    dx = np.minimum(dx, S - dx)
    return np.hypot(dy, dx)


YY, XX = np.mgrid[0:S, 0:S].astype(float)


def bubbles(v, count, r_min, r_max, ring=0.05, core=0.04):
    """Kleine Blasen: dunkler Ring, heller Kern (torus-gewrappt)."""
    for _ in range(count):
        cy, cx = rng.random(2) * S
        r = rng.uniform(r_min, r_max)
        d = wrapped_dist(YY, XX, cy, cx)
        v = v - ring * np.exp(-((d - r) ** 2) / 2.0) + core * np.exp(-(d ** 2) / (r * r * 0.4))
    return v


# --- Basis: Elfenbein-Acryl mit feinen Sprenkeln --------------------------------
def tex_base():
    v = 0.965 + 0.02 * (noise(45) - 0.5)
    speck = np.zeros((S, S))
    idx = rng.integers(0, S, (1100, 2))
    speck[idx[:, 0], idx[:, 1]] = 1.0
    speck = norm01(fft_blur(speck, 1.1))
    v -= 0.07 * speck
    return v, (1.00, 0.99, 0.96)


# --- Rubin: Kristall-Facetten (gewrappte Voronoi-Zellen) -------------------------
def tex_ruby():
    pts = rng.random((26, 2)) * S
    best = np.full((S, S), 1e9)
    second = np.full((S, S), 1e9)
    region = np.zeros((S, S), dtype=int)
    for i, (py, px) in enumerate(pts):
        d = wrapped_dist(YY, XX, py, px)
        closer = d < best
        second = np.where(closer, best, np.minimum(second, d))
        region = np.where(closer, i, region)
        best = np.where(closer, d, best)
    shades = 0.9 + 0.1 * rng.random(len(pts))
    v = shades[region]
    edge = norm01(second - best)
    v = v + 0.08 * (1.0 - edge) ** 8  # helle Kanten zwischen den Facetten
    v = fft_blur(v, 1.2)
    v = 0.90 + 0.10 * norm01(v)
    return v, (1.00, 0.94, 0.95)


# --- Bernstein: warmes Harz mit Lufteinschlüssen ---------------------------------
def tex_amber():
    v = 0.92 + 0.08 * noise(60)
    v = bubbles(v, 70, 2.0, 7.0)
    return v, (1.00, 0.96, 0.90)


# --- Gold: gebürstete Folie (horizontale Striche + leichte Dellen) ---------------
def tex_gold():
    streaks = norm01(fft_blur(rng.standard_normal((S, S)), 30, 0.9))
    dents = noise(70)
    v = 0.90 + 0.08 * streaks + 0.04 * (dents - 0.5)
    return v, (1.00, 0.97, 0.86)


# --- Knochen: organische Maserung + Haarrisse ------------------------------------
def tex_bone():
    grain = norm01(fft_blur(rng.standard_normal((S, S)), 2.2, 16))
    v = 0.93 + 0.06 * grain
    cracks = np.zeros((S, S))
    for _ in range(7):
        y, x = rng.random(2) * S
        ang = rng.uniform(0, 2 * np.pi)
        for _ in range(int(rng.integers(90, 220))):
            ang += rng.normal(0, 0.16)
            y = (y + np.sin(ang)) % S
            x = (x + np.cos(ang)) % S
            cracks[int(y), int(x)] = 1.0
    cracks = norm01(fft_blur(cracks, 0.9))
    v -= 0.10 * cracks
    return v, (1.00, 0.98, 0.92)


# --- Quecksilber: fließende Wellen (ganzzahlige Frequenzen = nahtlos) ------------
def tex_mercury():
    phase = np.zeros((S, S))
    for _ in range(6):
        kx, ky = int(rng.integers(-4, 5)), int(rng.integers(-4, 5))
        if kx == 0 and ky == 0:
            kx = 2
        phase += rng.uniform(0.6, 1.0) * np.sin(2 * np.pi * (kx * XX / S + ky * YY / S) + rng.uniform(0, 2 * np.pi))
    v = 0.90 + 0.10 * norm01(fft_blur(phase, 3))
    v += 0.04 * (noise(50) - 0.5)  # weiche Glanz-Blobs
    return v, (0.96, 0.98, 1.00)


# --- Glas: Frost-Grate + wenige Bläschen -----------------------------------------
def tex_glass():
    n = noise(22)
    ridge = (1.0 - np.abs(n * 2.0 - 1.0)) ** 3  # helle Grate, wo das Rauschen kippt
    v = 0.925 + 0.055 * ridge + 0.03 * (noise(80) - 0.5)
    v = bubbles(v, 26, 1.5, 4.0, ring=0.03, core=0.03)
    return v, (0.97, 0.995, 1.00)


TEXTURES = {
    "dice_base": tex_base,
    "ruby": tex_ruby,
    "amber": tex_amber,
    "gold": tex_gold,
    "bone": tex_bone,
    "mercury": tex_mercury,
    "glass": tex_glass,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for name, fn in TEXTURES.items():
        v, hue = fn()
        v = np.clip(v, 0.0, 1.0)
        rgb = np.stack([v * hue[0], v * hue[1], v * hue[2]], axis=-1)
        img = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8))
        img.save(os.path.join(OUT, name + ".png"))
        tiles.append((name, img))
        print("ok", name)

    # Kontaktbogen (2×2 gekachelt je Textur, um die Nahtlosigkeit zu sehen)
    cell = 256
    sheet = Image.new("RGB", (cell * len(tiles), cell * 2), (20, 16, 14))
    for i, (name, img) in enumerate(tiles):
        small = img.resize((cell // 2, cell // 2), Image.LANCZOS)
        for ty in range(4):
            for tx in range(2):
                sheet.paste(small, (i * cell + tx * cell // 2, ty * cell // 2))
    sheet.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), "contact_sheet.png"))
    print("contact sheet done")


if __name__ == "__main__":
    main()
