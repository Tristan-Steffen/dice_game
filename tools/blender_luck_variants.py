"""Fumble: drei ENTWÜRFE für die Station GLÜCK als Bauteil der Platine (2026-11-24).
  a - ABSCHIRMHAUBE: goldene HF-Haube mit Fenster über dem Sockel, das Kreuz als sechs Pad-Felder
  b - RESONATOR: der Würfel im liegenden Quarzglas zwischen zwei Elektroden, Seiten als Chip-Reihe
  c - NULLKRAFT-SOCKEL: ZIF-Sockel mit Hebel, das Kreuz als EIN Chip, Pegel als DIP-Schalter
Gebaut in Welt-Einheiten (Grundriß 6,2 × 15,2, Würfelkante 1,53), gerendert mal S.

Aufruf (kopflos):
  blender -b -P tools/blender_luck_variants.py -- <ausgabe-ordner> [ansicht,...]
Ansichten: a_schraeg, a_oben, a_detail, a_zustaende (ebenso b_, c_), vergleich; ein Präfix wie
"a" wählt alle einer Variante.
Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tisch Z = 0.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms
import blender_chip_screens as cs

led, box = dm.led, dm.box
S = 0.25
W, H = 6.2, 15.2
EDGE = 1.53
dm.HEX["smaragd"] = "#1ee05c"
dm.HEX["licht"] = "#ffd36a"
dm.HEX["lampe"] = "#8cff8c"
dm.HEX["bernstein"] = "#ffb347"

PIPS = [[], [(0, 0)], [(-1, -1), (1, 1)], [(-1, -1), (0, 0), (1, 1)],
        [(-1, -1), (1, -1), (-1, 1), (1, 1)], [(-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)],
        [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)]]
SPOTS = [(-1, -1), (1, -1), (-1, 0), (0, 0), (1, 0), (-1, 1), (1, 1)]
NET = [[-1, 1, -1, -1], [3, 0, 2, 5], [-1, 4, -1, -1]]
# Seite -> (Normale, u, v) mit u × v = Normale
FACE_AXES = {0: ((0, 0, 1), (1, 0, 0), (0, 1, 0)), 1: ((0, 1, 0), (-1, 0, 0), (0, 0, 1)),
             2: ((1, 0, 0), (0, 1, 0), (0, 0, 1)), 3: ((-1, 0, 0), (0, -1, 0), (0, 0, 1)),
             4: ((0, -1, 0), (1, 0, 0), (0, 0, 1)), 5: ((0, 0, -1), (1, 0, 0), (0, -1, 0))}


def state(name, faces, last, luck, prev, nxt, bonus, home=True):
    return {"name": name, "faces": faces, "last": last, "luck": luck, "share": (luck - prev) / (nxt - prev),
            "keeps": 0, "next": nxt, "exp": ("%.1f" % (sum(faces) / 6.0)).replace(".", ","), "bonus": bonus, "home": home}


START = state("START · alle Seiten 1", [1] * 6, -1, 0, 0, 1, False)
MITTE = state("MITTE · Glück 25, Auge bei 28", [3, 1, 2, 2, 1, 3], 3, 25, 21, 28, False)
SPAET = state("SPÄT · Glück 214, Freie Hand", [6, 5, 3, 6, 2, 4], 0, 214, 210, 231, True)
WEG = dict(MITTE, name="UNTERWEGS · Sitz leer", home=False, keeps=2)
STATES = [START, MITTE, SPAET, WEG]


# --- Materialien ---------------------------------------------------------------------------

def m_pcb():
    return led.mat("Platine", (0.004, 0.024, 0.015), 0.0, 0.7)


def m_silk():
    return led.mat("Siebdruck", (0.72, 0.78, 0.7), 0.0, 0.6, 0.3)


def m_bahn():
    return led.mat("Bahnzug", (0.012, 0.06, 0.035), 0.2, 0.4, clearcoat=0.5)


def m_gold():
    return led.mat("GoldHell", (0.9, 0.64, 0.22), 0.85, 0.26, 0.1)


def m_die():
    return led.mat("Wuerfelgold", (0.95, 0.66, 0.2), 0.8, 0.24, 0.14, clearcoat=0.4)


def m_lack():
    return led.mat("Schwarzlack", (0.006, 0.006, 0.008), 0.0, 0.1, clearcoat=1.0)


def m_glas():
    return led.mat("Rauchglas", (0.01, 0.012, 0.014), 0.0, 0.04, clearcoat=1.0)


def m_mulde():
    return led.mat("Mulde", (0.002, 0.01, 0.007), 0.0, 0.5)


def m_white():
    return led.mat("Schieber", (0.75, 0.76, 0.78), 0.0, 0.35, 0.25)


# --- Werkzeuge -----------------------------------------------------------------------------

def discs(parent, name, items, r, material, segs=24):
    """Viele flache Scheiben als EIN Mesh: items = (Mitte, u, v), Normale u × v."""
    verts, faces = [], []
    for c, u, v in items:
        c, u, v = Vector(c), Vector(u), Vector(v)
        n = len(verts)
        for i in range(segs):
            t = math.tau * i / segs
            verts.append(tuple(c + u * math.cos(t) * r + v * math.sin(t) * r))
        faces.append(list(range(n, n + segs)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = parent
    return o


def flat(x, y, z):
    return ((x, y, z), (1, 0, 0), (0, 1, 0))


def silk(r, body, x, y, size, z=0.004):
    return cs.text(r, body, x, y, z, size, m_silk(), "Druck_" + body)


def pips_flat(r, name, value, x, y, z, cell, lit_key="smaragd", recess=False, e=2.6):
    """Augen einer Seite flach auf (x, y): Zelle cell, versenkte Plätze auf Wunsch."""
    spread, rad = cell * 0.29, cell * 0.095
    if recess:
        discs(r, name + "Mulden", [flat(x + a * spread, y + b * spread, z + 0.001) for a, b in SPOTS],
              rad * 1.3, m_mulde())
    lit = [flat(x + a * spread, y + b * spread, z + 0.003) for a, b in PIPS[value]]
    if lit:
        discs(r, name + "Augen", lit, rad, dm.glow(lit_key, e * 0.75))


SEG = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
       "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}


def seg_width(text, h):
    return sum((0.46 * h if c == "1" else 0.82 * h) if c.isdigit() else 0.3 * h for c in text)


def seg_text(r, name, text, x, y, z, h, key):
    """Sieben-Segment-Zeile mittig auf (x, y); unbeleuchtete Segmente glimmen."""
    w, t = 0.5 * h, 0.12 * h
    cur = x - seg_width(text, h) * 0.5
    lit, off = [], []
    for c in text:
        if not c.isdigit():
            lit.append((cur + 0.12 * h, y - h * 0.55, z, t * 1.1, t * 2.4, 0.006))
            cur += 0.3 * h
            continue
        one = c == "1"
        cx = cur + (-0.04 * h if one else 0.41 * h)
        geo = {"a": (cx, y + h / 2, w, t), "g": (cx, y, w, t), "d": (cx, y - h / 2, w, t),
               "f": (cx - w / 2, y + h / 4, t, h / 2 - t * 0.6), "b": (cx + w / 2, y + h / 4, t, h / 2 - t * 0.6),
               "e": (cx - w / 2, y - h / 4, t, h / 2 - t * 0.6), "c": (cx + w / 2, y - h / 4, t, h / 2 - t * 0.6)}
        for s, (sx, sy, sw, sh) in geo.items():
            if s in SEG[c]:
                lit.append((sx, sy, z, sw, sh, 0.006))
            elif not one:
                off.append((sx, sy, z, sw, sh, 0.006))
        cur += 0.46 * h if one else 0.82 * h
    cs.boxes(r, name + "An", lit, dm.glow(key, 2.8))
    if off:
        cs.boxes(r, name + "Aus", off, dm.glow(key, 0.03))


def seg_window(r, name, text, x, y, h, key, bezel=None, z=0.0, pad=0.22):
    """Segment-Fenster: Rauchglas in einer Einfassung, darin die Zeile."""
    w = seg_width(text, h) + pad * 2
    hh = h + pad * 2
    if bezel is not None:
        led.rounded_box(r, name + "Rahmen", (w + 0.16, hh + 0.16, 0.1), (x, y, z + 0.05), bezel, 0.08, 0.02)
    led.rounded_box(r, name + "Glas", (w, hh, 0.12), (x, y, z + 0.06), m_glas(), 0.05, 0.01)
    seg_text(r, name, text, x, y, z + 0.123, h, key)
    return w


def die(parent, faces, loc, rot=(0.4, 0.0, 0.35)):
    """Der Glückswürfel: Gold, gerundet, versenkte Smaragd-Augen."""
    r = cs.root("Glueckswuerfel")
    r.parent = parent
    hf = EDGE * 0.5
    led.rounded_box(r, "Koerper", (EDGE, EDGE, EDGE), (0, 0, 0), m_die(), 0.22, 0.2)
    spread, rad = hf * 0.52, hf * 0.19
    hole, lit = [], []
    for f in range(6):
        n, u, v = (Vector(a) for a in FACE_AXES[f])
        for a, b in PIPS[faces[f]]:
            c = n * (hf + 0.002) + u * a * spread + v * b * spread
            hole.append((c, u, v))
            lit.append((c + n * 0.003, u, v))
    discs(r, "Fassung", hole, rad * 1.22, led.mat("Augengrund", (0.01, 0.03, 0.02), 0.0, 0.3))
    discs(r, "Augen", lit, rad, dm.glow("smaragd", 2.2))
    r.location = loc
    r.rotation_mode = "ZYX"
    r.rotation_euler = rot
    return r


def net_pos(face, x0, y0, step):
    for row, cols in enumerate(NET):
        for col, f in enumerate(cols):
            if f == face:
                return x0 + (col - 1.5) * step, y0 + (1 - row) * step
    return x0, y0


def base(r, title="U9 GLÜCK"):
    """Bestückungsdruck, Ecken der Fassung, drei Züge zum Bus."""
    hx, hy, k, t = W * 0.5, H * 0.5, 0.7, 0.05
    corners = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            corners.append([(sx * hx, sy * (hy - k)), (sx * hx, sy * hy), (sx * (hx - k), sy * hy)])
    cs.strips(r, "Ecken", corners, t, 0.003, m_silk())
    silk(r, title, -1.45, hy - 0.45, 0.42)
    xs = (-1.2, 0.0, 1.2)
    cs.boxes(r, "Pads", [(x, -hy + 0.3, 0.012, 0.42, 0.5, 0.024) for x in xs], cs.m_gold())
    lines = [[(x, -hy + 0.3), (x, -hy - 0.9), (x + 0.5 * (i - 1), -hy - 1.4)] for i, x in enumerate(xs)]
    cs.strips(r, "Zuege", lines, 0.16, 0.004, m_bahn())
    cs.strips(r, "Bus", [[(-hx - 1.4, -hy - 1.65), (hx + 1.4, -hy - 1.65)]], 0.42, 0.004, m_bahn())
    cs.boxes(r, "BusPads", [(x + 0.5 * (i - 1), -hy - 1.55, 0.01, 0.3, 0.3, 0.02) for i, x in enumerate(xs)],
             cs.m_gold())
    discs(r, "Vias", [flat(x, -hy - 0.55, 0.006) for x in (-2.1, 2.1)], 0.12, cs.m_gold())


def lamp(r, name, x, y, on, key="lampe"):
    dm.cyl(r, name + "Sockel", 0.36, 0.14, (x, y, 0.07), m_lack(), 48)
    dm.cyl(r, name + "Ring", 0.3, 0.04, (x, y, 0.16), m_gold(), 48)
    dm.cyl(r, name + "Kalotte", 0.24, 0.1, (x, y, 0.2),
           dm.glow(key, 3.0) if on else led.mat("LampeAus", (0.02, 0.05, 0.03), 0.0, 0.1, clearcoat=1.0), 48)


# --- A · ABSCHIRMHAUBE ---------------------------------------------------------------------

def build_a(r, st):
    base(r)
    cy = 3.85
    can = led.rounded_box(r, "Haube", (5.6, 5.1, 0.7), (0, cy, 0.35), m_gold(), 0.18, 0.04)
    led.cut(can, led.rounded_box(r, "Fenster", (4.5, 4.0, 2.0), (0, cy, 0.35), m_gold(), 0.35, 0.0))
    # Lochreihe der Haube und Lichtleiter im Fensterrand
    holes = [flat(x, cy + s * 2.28, 0.702) for s in (-1, 1) for x in [(-2.4 + i * 0.4) for i in range(13)]]
    holes += [flat(s * 2.53, cy + (-1.6 + i * 0.4), 0.702) for s in (-1, 1) for i in range(9)]
    discs(r, "Loecher", holes, 0.07, m_mulde(), 16)
    cs.boxes(r, "Lichtleiter", cs.ring_items(0, cy, 4.62, 4.12, 4.5, 4.0, 0.7, 0.02), dm.glow("smaragd", 1.4))
    dm.cyl(r, "Sockel", 0.95, 0.24, (0, cy, 0.12), m_lack(), 64)
    dm.annulus(r, "SockelGold", 0, cy, 0.242, 0.78, 0.95, m_gold())
    dm.annulus(r, "SockelLicht", 0, cy, 0.244, 0.6, 0.72, dm.glow("smaragd", 2.2 if st["home"] else 0.6))
    if st["home"]:
        die(r, st["faces"], (0, cy, 1.75))
    # das Kreuz: sechs Pad-Felder mit versenkten LEDs
    cell, step, y0 = 1.16, 1.3, -0.75
    for f in range(6):
        x, y = net_pos(f, 0, y0, step)
        last = f == st["last"]
        cs.boxes(r, "Pad%d" % f, [(x, y, 0.02, cell, cell, 0.04)], m_lack())
        cs.boxes(r, "PadRand%d" % f, cs.ring_items(x, y, cell + 0.1, cell + 0.1, cell, cell, 0.03, 0.06),
                 dm.glow("licht", 2.6) if last else m_gold())
        if last:
            cs.boxes(r, "PadKrone%d" % f, cs.ring_items(x, y, cell + 0.3, cell + 0.3, cell + 0.18, cell + 0.18,
                                                        0.02, 0.04), m_gold())
        pips_flat(r, "Seite%d" % f, st["faces"][f], x, y, 0.04, cell, recess=True)
    # Ø, Pegel, Bonus
    seg_window(r, "Erwartung", st["exp"], 0.9, -3.95, 0.62, "licht", m_gold())
    silk(r, "Ø WAHLEN", -1.5, -3.95, 0.34)
    yb = -5.25
    seg_window(r, "Glueck", str(st["luck"]), -2.25, yb, 0.36, "smaragd", pad=0.14)
    seg_window(r, "Schwelle", str(st["next"]), 2.3, yb, 0.36, "licht", pad=0.14)
    n, lit = 10, round(st["share"] * 10)
    cs.boxes(r, "BalkenGrund", [(0.05, yb, 0.02, 2.75, 0.62, 0.04)], m_lack())
    cs.boxes(r, "BalkenAn", [(-1.18 + i * 0.27, yb, 0.05, 0.19, 0.42, 0.02) for i in range(lit)],
             dm.glow("smaragd", 2.6))
    cs.boxes(r, "BalkenAus", [(-1.18 + i * 0.27, yb, 0.05, 0.19, 0.42, 0.02) for i in range(lit, n)],
             dm.glow("smaragd", 0.08))
    cs.strips(r, "Marke", [[(1.5, yb - 0.42), (1.5, yb + 0.42)]], 0.06, 0.06, dm.glow("licht", 2.6))
    silk(r, "GLÜCK", -2.25, yb - 0.62, 0.22)
    silk(r, "AUGE BEI", 2.3, yb - 0.62, 0.22)
    lamp(r, "Bonus", -1.75, -6.55, st["bonus"])
    silk(r, "FREIE HAND", 0.55, -6.55, 0.38)


# --- B · RESONATOR -------------------------------------------------------------------------

def build_b(r, st):
    base(r)
    cy, cz, rad = 4.2, 1.55, 1.42
    tube = dm.cyl(r, "Quarzglas", rad, 4.0, (0, cy, cz),
                  led.mat("Quarzglas", (0.7, 0.95, 0.88), 0.0, 0.03, 0.0, 0.12), 96)
    tube.rotation_euler = (0, math.radians(90), 0)
    tube.data.materials[0].show_transparent_back = False
    for s in (-1, 1):
        cap = dm.cyl(r, "Elektrode", 1.55, 0.46, (s * 2.23, cy, cz), m_gold(), 96)
        cap.rotation_euler = (0, math.radians(90), 0)
        face = dm.cyl(r, "ElektrodeLicht", 0.9, 0.02, (s * 1.99, cy, cz), dm.glow("smaragd", 2.2), 64)
        face.rotation_euler = (0, math.radians(90), 0)
        band = dm.cyl(r, "Band", rad + 0.03, 0.07, (s * 1.55, cy, cz), dm.glow("smaragd", 1.0), 96)
        band.rotation_euler = (0, math.radians(90), 0)
        cs.boxes(r, "Wiege", [(s * 2.23, cy, 0.25, 0.7, 2.6, 0.5)], m_lack())
    if st["home"]:
        die(r, st["faces"], (0, cy, cz), (0.4, 0.0, 0.35))
    # sechs Seiten-Chips längs der Station
    cell, x0, top = 0.98, -1.25, 1.95
    for f in range(6):
        y = top - f * 1.08
        last = f == st["last"]
        if last:
            cs.boxes(r, "Krone%d" % f, cs.ring_items(x0, y, cell + 0.34, cell + 0.2, cell + 0.2, cell + 0.06,
                                                     0.02, 0.04), dm.glow("licht", 2.6))
        led.rounded_box(r, "Chip%d" % f, (cell, cell * 0.9, 0.22), (x0, y, 0.13), m_lack(), 0.04, 0.02)
        cs.boxes(r, "Beine%d" % f, [(x0 + s * (cell * 0.5 + 0.06), y + k * 0.25, 0.04, 0.14, 0.08, 0.06)
                                    for s in (-1, 1) for k in (-1, 0, 1)], cs.m_steel())
        pips_flat(r, "Seite%d" % f, st["faces"][f], x0, y, 0.24, cell * 0.92)
        silk(r, str(f + 1), x0 - 1.0, y, 0.42)
    # Pegel: Kondensator-Säule, die sich von unten füllt
    x1, n, pitch, y_low = 1.55, 7, 0.62, -2.85
    lit = round(st["share"] * n)
    for i in range(n):
        y = y_low + i * pitch
        led.rounded_box(r, "Kond%d" % i, (1.05, 0.44, 0.3), (x1, y, 0.15),
                        dm.glow("smaragd", 1.9) if i < lit else led.mat("KondAus", (0.03, 0.06, 0.05), 0.0, 0.3,
                                                                       clearcoat=0.6), 0.03, 0.03)
        cs.boxes(r, "Kappe%d" % i, [(x1 + s * 0.6, y, 0.15, 0.16, 0.46, 0.32) for s in (-1, 1)], cs.m_steel())
    ytop = y_low + n * pitch - 0.1
    cs.boxes(r, "Schwelle", [(x1, ytop, 0.05, 1.5, 0.16, 0.1)], dm.glow("licht", 2.4))
    seg_window(r, "SchwelleZahl", str(st["next"]), x1, ytop + 0.55, 0.36, "licht", pad=0.12)
    seg_window(r, "Glueck", str(st["luck"]), x1, y_low - 0.85, 0.36, "smaragd", pad=0.12)
    silk(r, "GLÜCK", x1, y_low - 1.45, 0.24)
    # Fuß: zwei Lichtleiter-Fenster
    yf = -5.75
    for name, x, wd in (("Erwartung", -1.45, 2.5), ("Bonus", 1.5, 2.6)):
        on = name == "Erwartung" or st["bonus"]
        led.rounded_box(r, name + "Leiter", (wd, 1.5, 0.16), (x, yf, 0.08),
                        led.mat("Acryl", (0.1, 0.16, 0.14), 0.0, 0.05, 0.0, 0.5), 0.12, 0.02)
        cs.boxes(r, name + "Kante", cs.ring_items(x, yf, wd, 1.5, wd - 0.1, 1.4, 0.17, 0.02),
                 dm.glow("smaragd" if name == "Erwartung" else "lampe", 2.2 if on else 0.12))
    seg_text(r, "Erwartung", st["exp"], -1.45, yf + 0.1, 0.17, 0.62, "licht")
    cs.text(r, "FREIE HAND", 1.5, yf + 0.1, 0.17, 0.34,
            dm.glow("lampe", 2.8) if st["bonus"] else dm.glow("lampe", 0.1), "BonusSchrift")
    silk(r, "Ø WAHLEN", -1.45, yf - 1.05, 0.28)
    silk(r, "BONUS", 1.5, yf - 1.05, 0.28)


# --- C · NULLKRAFT-SOCKEL ------------------------------------------------------------------

def build_c(r, st):
    base(r)
    sx, sy, side = -0.35, 4.35, 3.7
    led.rounded_box(r, "Sockel", (side, side, 0.36), (sx, sy, 0.18), m_gold(), 0.08, 0.03)
    cs.boxes(r, "Deckplatte", [(sx, sy, 0.38, side - 0.4, side - 0.4, 0.04)], m_lack())
    grid = [flat(sx + (i - 4.5) * 0.33, sy + (j - 4.5) * 0.33, 0.402) for i in range(10) for j in range(10)]
    discs(r, "Kontakte", grid, 0.07, cs.m_gold(), 12)
    cs.boxes(r, "Pin1", [(sx - side * 0.5 + 0.35, sy + side * 0.5 - 0.35, 0.39, 0.2, 0.2, 0.02)],
             dm.glow("smaragd", 2.4))
    cs.boxes(r, "Rahmenlicht", cs.ring_items(sx, sy, side - 0.32, side - 0.32, side - 0.4, side - 0.4, 0.4, 0.01),
             dm.glow("smaragd", 1.4 if st["home"] else 0.3))
    # der Hebel: zu = liegt an der Flanke, offen = steht auf
    pivot = cs.root("Hebel")
    pivot.parent = r
    cs.boxes(pivot, "Stange", [(0, 1.7, 0, 0.16, 3.4, 0.16)], m_gold())
    cs.boxes(pivot, "Griff", [(0.3, 3.4, 0, 0.6, 0.18, 0.18)], m_gold())
    cs.boxes(pivot, "GriffKappe", [(0.65, 3.4, 0, 0.18, 0.22, 0.22)], m_lack())
    pivot.location = (sx + side * 0.5 + 0.16, sy - side * 0.5 + 0.05, 0.22)
    pivot.rotation_euler = (0 if st["home"] else math.radians(78), 0, 0)
    if st["home"]:
        die(r, st["faces"], (sx, sy, 1.6))
    # das Kreuz als EIN Chip mit sechs Fenstern
    cy = -0.75
    led.rounded_box(r, "Chip", (5.7, 4.55, 0.32), (0, cy, 0.18), led.mat("Epoxid2", (0.014, 0.015, 0.018),
                                                                         0.0, 0.4, clearcoat=0.4), 0.08, 0.03)
    cs.boxes(r, "Beine", [(s * 2.98, cy - 1.9 + k * 0.38, 0.05, 0.3, 0.14, 0.08)
                          for s in (-1, 1) for k in range(11)], cs.m_steel())
    cell, step, x0 = 1.08, 1.24, 0.0
    for f in range(6):
        x, y = net_pos(f, x0, cy + 0.05, step)
        last = f == st["last"]
        led.rounded_box(r, "Fenster%d" % f, (cell, cell, 0.04), (x, y, 0.34), m_glas(), 0.08, 0.0)
        cs.boxes(r, "FensterRand%d" % f, cs.ring_items(x, y, cell + 0.08, cell + 0.08, cell, cell, 0.345, 0.03),
                 dm.glow("licht", 2.6) if last else led.mat("Laser2", (0.2, 0.2, 0.22), 0.0, 0.6))
        pips_flat(r, "Seite%d" % f, st["faces"][f], x, y, 0.36, cell)
    ex, ey = 1.85, cy + 0.05 - step
    seg_window(r, "Erwartung", st["exp"], ex, ey + 0.05, 0.5, "licht", z=0.3, pad=0.14)
    cs.text(r, "Ø WAHLEN", ex, ey - 0.52, 0.345, 0.22, led.mat("Laser", (0.36, 0.36, 0.4), 0.0, 0.6, 0.2))
    cs.text(r, "RNG-6", ex, cy + 0.05 + step + 0.1, 0.345, 0.3, led.mat("Laser", (0.36, 0.36, 0.4), 0.0, 0.6, 0.2))
    # Pegel: DIP-Schalter, die nächste Schwelle ist der goldene
    yd, n = -4.15, 8
    lit = round(st["share"] * n)
    led.rounded_box(r, "DipGehaeuse", (5.0, 1.2, 0.3), (0, yd, 0.15),
                    led.mat("DipBlau", (0.012, 0.03, 0.09), 0.0, 0.3, clearcoat=0.6), 0.05, 0.02)
    for i in range(n):
        x = -2.1 + i * 0.6
        thr = i == n - 1
        cs.boxes(r, "DipSchacht%d" % i, [(x, yd, 0.3, 0.38, 0.82, 0.02)],
                 dm.glow("licht", 1.6) if thr else (dm.glow("smaragd", 1.4) if i < lit else m_mulde()))
        on = i < lit
        cs.boxes(r, "DipSchieber%d" % i, [(x, yd + (0.2 if on else -0.2), 0.36, 0.3, 0.34, 0.1)],
                 m_gold() if thr else m_white())
        silk(r, str(i + 1), x, yd - 0.82, 0.24)
    silk(r, "ON", -2.85, yd + 0.3, 0.2)
    yr = -5.65
    seg_window(r, "Glueck", str(st["luck"]), -1.4, yr, 0.38, "smaragd", pad=0.14)
    seg_window(r, "Schwelle", str(st["next"]), 1.4, yr, 0.38, "licht", pad=0.14)
    silk(r, "GLÜCK", -1.4, yr - 0.6, 0.22)
    silk(r, "AUGE BEI", 1.4, yr - 0.6, 0.22)
    # Bonus: Steckbrücke - gesteckt leuchtet sie
    jx, jy = -1.7, -6.75
    cs.boxes(r, "Leiste", [(jx, jy, 0.12, 0.9, 0.42, 0.24)], m_lack())
    cs.boxes(r, "Stifte", [(jx + s * 0.22, jy, 0.35, 0.08, 0.08, 0.5) for s in (-1, 1)], m_gold())
    if st["bonus"]:
        led.rounded_box(r, "Bruecke", (0.84, 0.4, 0.36), (jx, jy, 0.48), dm.glow("lampe", 2.4), 0.05, 0.03)
    else:
        led.rounded_box(r, "Bruecke", (0.84, 0.4, 0.36), (jx + 0.22, jy, 0.62),
                        led.mat("BrueckeAus", (0.03, 0.05, 0.04), 0.0, 0.3, clearcoat=0.6), 0.05, 0.03)
    silk(r, "FREIE HAND", 0.75, jy, 0.36)


# --- C2 · NULLKRAFT-SOCKEL, Runde 2 ---------------------------------------------------------

def jumper(r, name, x, y, on):
    cs.boxes(r, name + "Leiste", [(x, y, 0.1, 0.95, 0.44, 0.2)], m_lack())
    cs.boxes(r, name + "Stifte", [(x + s * 0.24, y, 0.32, 0.1, 0.1, 0.44) for s in (-1, 1)], m_gold())
    if on:
        led.rounded_box(r, name + "Bruecke", (0.9, 0.46, 0.34), (x, y, 0.42), dm.glow("lampe", 2.6), 0.05, 0.03)


def build_c2(r, st):
    base(r)
    home = st["home"]
    sx, sy, side = -0.2, 4.65, 4.2
    led.rounded_box(r, "Sockel", (side, side, 0.4), (sx, sy, 0.2), m_gold(), 0.1, 0.03)
    cs.boxes(r, "Deckplatte", [(sx, sy, 0.42, side - 0.44, side - 0.44, 0.04)], m_lack())
    # Kontakte nur im Randband, die Mitte ist der ruhige Sitz
    n, step = 11, 0.33
    grid = [flat(sx + (i - 5) * step, sy + (j - 5) * step, 0.442) for i in range(n) for j in range(n)
            if min(i, j, n - 1 - i, n - 1 - j) < 2]
    discs(r, "Kontakte", grid, 0.07, cs.m_gold(), 12)
    dm.cyl(r, "Sitz", 1.22, 0.02, (sx, sy, 0.45), m_mulde(), 64)
    dm.annulus(r, "SitzRing", sx, sy, 0.462, 1.02, 1.16, dm.glow("smaragd" if home else "licht", 2.2 if home else 0.9), 64)
    if home:
        dm.annulus(r, "SitzKern", sx, sy, 0.462, 0.0, 0.5, dm.glow("smaragd", 0.5), 48)
    cs.boxes(r, "Pin1", [(sx - side * 0.5 + 0.36, sy + side * 0.5 - 0.36, 0.43, 0.22, 0.22, 0.02)],
             dm.glow("smaragd", 2.4))
    # der Hebel: verriegelt liegt er an der Flanke, sein Knauf leuchtet grün; offen steht er auf, bernstein
    pivot = cs.root("Hebel")
    pivot.parent = r
    cs.boxes(pivot, "Stange", [(0, 1.8, 0, 0.3, 3.6, 0.26)], m_gold())
    dm.cyl(pivot, "Knauf", 0.36, 0.34, (0, 3.75, 0), m_lack(), 40)
    dm.cyl(pivot, "KnaufLicht", 0.24, 0.36, (0, 3.75, 0), dm.glow("smaragd" if home else "licht", 2.6), 40)
    cs.boxes(r, "HebelLager", [(sx + side * 0.5 + 0.3, sy - side * 0.5 + 0.2, 0.2, 0.6, 0.6, 0.4)], m_gold())
    pivot.location = (sx + side * 0.5 + 0.3, sy - side * 0.5 + 0.2, 0.42)
    pivot.rotation_euler = (0 if home else math.radians(70), 0, 0)
    if home:
        die(r, st["faces"], (sx, sy, 1.75))
    # sechs Abtast-Züge vom Sockel in den Chip: je Seite einer
    cy = -0.55
    xs = [(k - 2.5) * 0.42 for k in range(6)]
    cs.strips(r, "Abtastung", [[(x, sy - side * 0.5), (x, cy + 2.3)] for x in xs], 0.12, 0.004, cs.m_gold())
    cs.strips(r, "AbtastLicht", [[(x, sy - side * 0.5), (x, cy + 2.3)] for x in xs], 0.035, 0.007,
              dm.glow("smaragd", 1.2 if home else 0.15))
    # das Kreuz als EIN Chip mit sechs Fenstern
    led.rounded_box(r, "Chip", (5.7, 4.55, 0.32), (0, cy, 0.18), led.mat("Epoxid2", (0.014, 0.015, 0.018),
                                                                         0.0, 0.4, clearcoat=0.4), 0.08, 0.03)
    cs.boxes(r, "Beine", [(s * 2.98, cy - 1.9 + k * 0.38, 0.05, 0.3, 0.14, 0.08)
                          for s in (-1, 1) for k in range(11)], cs.m_steel())
    cell, step = 1.12, 1.26
    for f in range(6):
        x, y = net_pos(f, 0.0, cy + 0.05, step)
        last = f == st["last"]
        led.rounded_box(r, "Fenster%d" % f, (cell, cell, 0.04), (x, y, 0.34), m_glas(), 0.08, 0.0)
        cs.boxes(r, "FensterRand%d" % f, cs.ring_items(x, y, cell + 0.1, cell + 0.1, cell, cell, 0.345, 0.03),
                 dm.glow("licht", 2.8) if last else led.mat("Laser2", (0.2, 0.2, 0.22), 0.0, 0.6))
        pips_flat(r, "Seite%d" % f, st["faces"][f], x, y, 0.36, cell, recess=True)
    ex, ey = 1.9, cy + 0.05 - step
    seg_window(r, "Erwartung", st["exp"], ex, ey + 0.08, 0.52, "licht", z=0.3, pad=0.14)
    cs.text(r, "Ø WAHLEN", ex, ey - 0.5, 0.345, 0.22, led.mat("Laser", (0.5, 0.5, 0.55), 0.0, 0.6, 0.3))
    # Pegel in EINER Zeile: Glück - Schalterbank - Schwelle
    yd, n = -4.2, 10
    lit = round(st["share"] * (n - 1))
    led.rounded_box(r, "DipGehaeuse", (3.7, 1.15, 0.3), (0, yd, 0.15),
                    led.mat("DipBlau", (0.012, 0.03, 0.09), 0.0, 0.3, clearcoat=0.6), 0.05, 0.02)
    for i in range(n):
        x = (i - (n - 1) * 0.5) * 0.35
        thr = i == n - 1
        on = i < lit
        cs.boxes(r, "DipSchacht%d" % i, [(x, yd, 0.3, 0.24, 0.84, 0.02)],
                 dm.glow("licht", 1.8) if thr else (dm.glow("smaragd", 1.6) if on else m_mulde()))
        cs.boxes(r, "DipSchieber%d" % i, [(x, yd + (0.22 if on else -0.22), 0.36, 0.2, 0.32, 0.1)],
                 m_gold() if thr else m_white())
    seg_window(r, "Glueck", str(st["luck"]), -2.5, yd, 0.36, "smaragd", pad=0.12)
    seg_window(r, "Schwelle", str(st["next"]), 2.5, yd, 0.36, "licht", pad=0.12)
    silk(r, "GLÜCK", -2.5, yd - 0.8, 0.22)
    silk(r, "NÄCHSTES AUGE", 1.75, yd - 0.8, 0.22)
    # Bonus: zwei Steckbrücken - gesteckt leuchten sie, sonst stehen nur die blanken Stifte
    jy = -6.05
    jumper(r, "Frei", -2.5, jy, st["bonus"])
    silk(r, "FREIE HAND", -1.0, jy, 0.27)
    jumper(r, "Einbau", 0.6, jy, st["keeps"] > 0)
    silk(r, "EINBAU", 1.8, jy, 0.27)
    if st["keeps"] > 0:
        seg_window(r, "Einbauten", str(st["keeps"]), 2.72, jy, 0.34, "lampe", pad=0.1)


VARIANTS = {"a": ("A · ABSCHIRMHAUBE", build_a), "b": ("B · RESONATOR", build_b),
            "c": ("C · NULLKRAFT-SOCKEL", build_c), "c2": ("C2 · NULLKRAFT-SOCKEL", build_c2)}


# --- Bühne und Ansichten -------------------------------------------------------------------

def stage():
    cam, aim = dm.empty_stage()
    for o in bpy.data.objects:
        mats = getattr(o.data, "materials", None) if o.data is not None else None
        if mats and mats[0] is not None and mats[0].name.startswith("Softbox"):
            o.hide_render = True
        if mats and mats[0] is not None and mats[0].name == "Filz":
            o.data.materials[0] = m_pcb()
        if o.type == "LIGHT":
            o.data.energy = 260
            o.data.size = 24
    scene = bpy.context.scene
    scene.eevee.taa_render_samples = 48
    scene.eevee.bloom_threshold = 1.0
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    return cam, aim


def station(key, st, x=0.0, y=0.0):
    r = cs.root("Station_" + key)
    VARIANTS[key][1](r, st)
    r.location = (x, y, 0.001)
    r.scale = (S, S, S)
    return r


def shoot(cam, aim, path, target, eye, lens=50, ortho=None):
    aim.location = target
    cam.location = eye
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = "PERSP"
        cam.data.lens = lens
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


SCHRAEG = ((0, -0.15, 0), (0, -3.0, 9.4), 50)


def view(key, kind, out):
    cam, aim = stage()
    path = os.path.join(out, "%s_%s.png" % (key, kind))
    if kind == "zustaende":
        for i, st in enumerate(STATES):
            x = (i - 1.5) * 2.15
            station(key, st, x)
            ms.label(st["name"], x, -2.75, 0.115)
        shoot(cam, aim, path, (0, -0.25, 0), (0, -3.4, 12.6), 50)
        return
    station(key, MITTE)
    if kind == "schraeg":
        shoot(cam, aim, path, *SCHRAEG)
    elif kind == "oben":
        shoot(cam, aim, path, (0, -0.1, 0), (0, -0.1, 12), ortho=7.6)
    else:
        shoot(cam, aim, path, (0, 0.55, 0.15), (0.6, -1.45, 3.4), 50)


def view_vergleich(out):
    cam, aim = stage()
    for i, key in enumerate("abc"):
        x = (i - 1) * 2.45
        station(key, MITTE, x)
        ms.label(VARIANTS[key][0], x, -2.75, 0.14)
    shoot(cam, aim, os.path.join(out, "vergleich.png"), (0, -0.45, 0), (0, -3.7, 11.6), 50)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
    out = argv[0]
    os.makedirs(out, exist_ok=True)
    only = argv[1].split(",") if len(argv) > 1 else []
    jobs = ["%s_%s" % (k, v) for k in VARIANTS for v in ("schraeg", "oben", "detail", "zustaende")]
    jobs.append("vergleich")
    for job in jobs:
        if only and not any(job == o or job.startswith(o + "_") for o in only):
            continue
        if job == "vergleich":
            view_vergleich(out)
        else:
            key, kind = job.split("_")
            view(key, kind, out)
    print("ok")
