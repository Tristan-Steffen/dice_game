"""Erzeugt die kachelbare Oberfläche der Würfel-Schatulle.

Stile: quilt (Rauten-Polster mit Nieten), hobnail (Clous de Paris), brushed (gebürstet), guilloche
(Guilloché-Wellen), deco (Art-déco-Schuppen). Jede Kachel ist nahtlos.
Schreibt <out>/<name>_albedo.png (Graustufen, multipliziert den Lack) und
<out>/<name>_normal.png (OpenGL-Normalen, wie Godot sie liest).
Aufruf: python tools/gen_case_texture.py [stil] [ausgabe-ordner] [name]
"""
import os
import sys

import numpy as np
from PIL import Image

N = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def grid():
    y, x = np.mgrid[0:N, 0:N].astype(np.float64) + 0.5
    return x / N, y / N


def quilt():
    """Rauten-Polster mit Nieten an den Kreuzungen."""
    cells, groove, stud = 2, 0.09, 0.085
    x, y = grid()
    fu = ((x + y) * cells) % 1.0
    fv = ((x - y) * cells) % 1.0
    edge = np.minimum.reduce([fu, 1.0 - fu, fv, 1.0 - fv])
    cu, cv = np.minimum(fu, 1.0 - fu), np.minimum(fv, 1.0 - fv)
    corner = np.sqrt(cu * cu + cv * cv)
    pillow = smoothstep(0.0, groove * 2.2, edge) * 0.85 + edge * 0.3
    knob = np.clip(1.0 - (corner / stud) ** 2, 0.0, 1.0) ** 0.5
    ring = smoothstep(stud, stud * 1.35, corner)
    height = np.maximum(pillow * ring, knob * 0.95)
    albedo = 0.32 + 0.68 * smoothstep(0.0, groove, edge)
    albedo *= 0.35 + 0.65 * ring
    albedo = np.where(corner < stud, 1.0, albedo)
    return height, albedo, 6.0


def hobnail():
    """Clous de Paris: feine Pyramiden im Quadratraster, wie ein Uhren-Zifferblatt."""
    cells = 8
    x, y = grid()
    fx, fy = (x * cells) % 1.0 - 0.5, (y * cells) % 1.0 - 0.5
    height = 1.0 - 2.0 * np.maximum(np.abs(fx), np.abs(fy))
    # Facetten-Licht von oben links: hell die zugewandten, gedämpft die abgewandten.
    lit = np.where(np.abs(fx) > np.abs(fy), -0.35 * np.sign(fx), -np.sign(fy))
    albedo = 0.88 + 0.08 * lit
    albedo *= 0.8 + 0.2 * smoothstep(0.0, 0.08, height)
    return height, albedo, 3.0


def guilloche():
    """Guilloché: zwei gegenläufige Wellenscharen, fein graviert wie ein Schein."""
    x, y = grid()
    lines, waves, amp = 12, 2, 0.05
    a = np.cos(2 * np.pi * (y * lines + amp * lines * np.sin(2 * np.pi * x * waves)))
    b = np.cos(2 * np.pi * (y * lines - amp * lines * np.sin(2 * np.pi * x * waves)))
    groove = np.maximum(smoothstep(0.7, 1.0, a), smoothstep(0.7, 1.0, b))
    height = 1.0 - groove
    albedo = 1.0 - 0.38 * groove
    return height, albedo, 2.0


def deco():
    """Art-déco-Schuppen: versetzte Halbbögen mit feiner Randlinie."""
    cols, rows = 4, 8
    x, y = grid()
    r = 1.0 / cols * 0.5
    best_d = np.full(x.shape, 9.0)
    owner_row = np.full(x.shape, -1.0)
    # Spätere Reihen liegen oben: die Schuppe mit dem größten Reihenindex, die den Punkt deckt.
    for row in range(-1, rows + 1):
        cy = row / rows
        shift = (row % 2) * r
        for col in range(-1, cols + 1):
            cx = col / cols + shift + r
            for ox in (-1.0, 0.0, 1.0):
                for oy in (-1.0, 0.0, 1.0):
                    d = np.sqrt((x - cx - ox) ** 2 + (y - cy - oy) ** 2)
                    take = (d < r) & ((row + oy * rows) >= owner_row)
                    best_d = np.where(take, d, best_d)
                    owner_row = np.where(take, row + oy * rows, owner_row)
    edge = (r - best_d) / r
    rim = 1.0 - smoothstep(0.0, 0.07, edge)
    inner = 1.0 - smoothstep(0.0, 0.02, np.abs(edge - 0.22))
    height = smoothstep(0.0, 0.5, edge) * 0.6 + 0.4 - rim * 0.4
    albedo = 1.0 - 0.28 * rim - 0.1 * inner
    return height, albedo, 3.0


def brushed():
    """Gebürstetes Metall: feine Riefen quer, jede Schar mit ganzzahliger Periode (kachelbar)."""
    rng = np.random.default_rng(7)
    x, y = grid()
    height = np.zeros_like(x)
    for k in range(24, 200):
        amp = rng.uniform(0.3, 1.0) / np.sqrt(k)
        wobble = 0.004 * np.sin(2 * np.pi * (x * int(rng.integers(1, 4)) + rng.uniform()))
        height += amp * np.sin(2 * np.pi * (k * (y + wobble)) + rng.uniform(0, 2 * np.pi))
    height = (height - height.min()) / (height.max() - height.min())
    albedo = 0.9 + 0.1 * (height - 0.5) * 2.0
    return height, albedo, 0.8


STYLES = {"quilt": quilt, "hobnail": hobnail, "guilloche": guilloche, "deco": deco,
          "brushed": brushed}


def write(style, out, name):
    height, albedo, gain = STYLES[style]()
    Image.fromarray((np.clip(albedo, 0, 1) * 255).astype(np.uint8), "L").save(
        os.path.join(out, name + "_albedo.png"))
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5 * gain
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5 * gain
    nx, ny, nz = -dx, dy, np.ones_like(dx)  # OpenGL: +Y nach oben im Bild
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx, ny, nz], -1) / length[..., None]
    Image.fromarray(((normal * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(
        os.path.join(out, name + "_normal.png"))


if __name__ == "__main__":
    style = sys.argv[1] if len(sys.argv) > 1 else "hobnail"
    out = sys.argv[2] if len(sys.argv) > 2 else OUT
    name = sys.argv[3] if len(sys.argv) > 3 else "case_hobnail"
    os.makedirs(out, exist_ok=True)
    write(style, out, name)
    print("ok", style)
