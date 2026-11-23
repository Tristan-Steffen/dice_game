"""Wandhaut der Gruben: matte schwarze Paneele mit versenkten Lichtleisten.

Schreibt assets/textures/gruben_lichtleisten.png. Laengs der Wand nahtlos; die
Grubenkante liegt am OBEREN Bildrand, eine Kachel sind 6 Welt-Einheiten.
Aufruf: python tools/gen_pit_skin.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
UNIT = SIZE / 6.0           # Pixel je Welt-Einheit
PANELS = 4                  # Paneele je Kachel, je eine Leiste in der Mitte
BAR_TOP = 0.18              # Tiefe unter der Kante, Welt
BAR_BOTTOM = 1.7
BAR_HALF = 5                # halbe Breite in Pixeln
HALO = 22                   # Weichzeichner des Lichthofs
PANEL = (17, 18, 25)
LIGHT = (150, 240, 228)
HALO_TINT = (0.35, 0.9, 0.9)

pitch = SIZE // PANELS
bars = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
draw = ImageDraw.Draw(bars)
for k in range(PANELS):
    x = k * pitch + pitch // 2
    draw.rounded_rectangle((x - BAR_HALF, int(BAR_TOP * UNIT), x + BAR_HALF, int(BAR_BOTTOM * UNIT)),
                           radius=BAR_HALF, fill=LIGHT)
halo = np.asarray(bars.filter(ImageFilter.GaussianBlur(HALO)), dtype=np.float32) * 0.9
core = np.asarray(bars.filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32)

xx = np.tile(np.arange(SIZE, dtype=np.float32), (SIZE, 1))
seam = (np.minimum(xx % pitch, pitch - xx % pitch) < 1.5)[..., None]
panel = np.ones((SIZE, SIZE, 3), np.float32) * np.array(PANEL) * np.where(seam, 0.35, 1.0)
grain = np.random.default_rng(3).normal(0.0, 1.4, (SIZE, SIZE, 1))
pixels = panel + np.maximum(halo * np.array(HALO_TINT), core) + grain

target = Path(__file__).resolve().parent.parent / "assets" / "textures" / "gruben_lichtleisten.png"
Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).save(target)
print("geschrieben:", target)
