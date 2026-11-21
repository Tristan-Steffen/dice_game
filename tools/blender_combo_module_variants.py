"""Fumble: ENTWÜRFE für die Module der Kombinations-Chips (2026-11-20).
  0_heute    - der Chip von heute mit drei kleinen Buchsen im Deckel (Vergleich)
  a_traeger  - Trägerplatine: Chip oben, darunter drei große Buchten mit Modul-Körpern
  b_einschub - Hot-Swap-Einschübe: drei schräge Schubfächer vorn, die Front nennt das Modul
  c_terrasse - Terrasse: Module sind Platten unter dem Chip, jede Stufe trägt ihre Zeile
Blockmodelle, Chip 1,8 x 1,0.

Aufruf (kopflos):
  blender -b -P tools/blender_combo_module_variants.py -- <ausgabe-ordner> [variante,...]
Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tischfläche bei Z = 0.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms
import blender_chip_screens as cs

led, box = dm.led, dm.box
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
CW, CD, CH = 1.8, 1.0, 0.28
COL = 2.55
dm.HEX["name"] = "#ff79c6"
dm.HEX["punkte"] = "#00ffff"
dm.HEX["mult"] = "#ffd319"
dm.HEX["relais"] = "#50fa7b"
dm.HEX["krit"] = "#ff5fa8"
dm.HEX["band"] = "#3f9bb5"

# Art -> (Kurzwert, Zeile)
KINDS = {"punkte": ("+10", "PUNKTE"), "mult": ("×2", "MULT"), "relais": ("RELAIS", "1. WÜRFEL NOCHMAL"),
         "krit": ("KRIT", "25 % · ×3")}
COMBOS = [("Sechserpasch", "60", "×15", [], False),
          ("5 of a Kind", "50", "×10", ["punkte"], False),
          ("Große Straße", "45", "×8", ["punkte", "mult", "relais"], False),
          ("Viererpasch mit Paar", "40", "×6", ["mult", "krit"], True),
          ("Full House", "28", "×4", ["relais", "punkte"], False),
          ("Kleine Straße", "22", "×4", [], False)]


def m_body(gold):
    if gold:
        return led.mat("ChipGold", (0.8, 0.55, 0.05), 0.3, 0.4, 0.9)
    return led.mat("ChipEpoxid", (0.05, 0.045, 0.075), 0.0, 0.5, clearcoat=0.3)


def m_glass():
    return led.mat("Deckelglas", (0.004, 0.005, 0.012), 0.0, 0.12, clearcoat=1.0)


def m_pocket():
    return led.mat("Tasche", (0.002, 0.002, 0.004), 0.0, 0.6)


def m_dim():
    return led.mat("Saum", (0.1, 0.12, 0.2), 0.0, 0.4, 0.5)


def m_pcb():
    return led.mat("Traeger", (0.016, 0.018, 0.03), 0.0, 0.55, clearcoat=0.4)


def txt(r, body, x, y, z, size, key, e=2.0, align="LEFT", fr=None):
    t = box.text(r, body, fr if fr is not None else dm.top(z), x, y, size, dm.glow(key, e))
    t.data.align_x = align
    return t


def prism(r, name, x0, x1, profile, material):
    """Profil (y, z) längs X gezogen."""
    n = len(profile)
    verts = [(x, y, z) for x in (x0, x1) for y, z in profile]
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = r
    return o


def chip(r, cx, cy, z0, combo, sockets=False):
    name, pts, mult, mods, gold = combo
    led.rounded_box(r, "Body", (CW, CD, CH), (cx, cy, z0 + CH * 0.5), m_body(gold), 0.06, 0.02)
    top = z0 + CH
    led.rounded_box(r, "Glas", (CW - 0.16, CD - 0.18, 0.012), (cx, cy + 0.01, top), m_glass(), 0.04,
                    0.0)
    x0 = cx - CW * 0.5 + 0.16
    txt(r, name, x0, cy + 0.2, top + 0.008, 0.2 if len(name) < 16 else 0.165, "name")
    txt(r, pts, x0, cy - 0.21, top + 0.008, 0.27, "punkte")
    txt(r, mult, x0 + 0.17 * len(pts) + 0.1, cy - 0.21, top + 0.008, 0.27, "mult")
    pins = []
    for s in (-1, 1):
        for k in (-1, 0, 1):
            pins.append((cx + s * (CW * 0.5 + 0.07), cy + k * 0.3, z0 + 0.09, 0.14, 0.2, 0.1))
    cs.boxes(r, "Pins", pins, led.mat("PinGold", (0.8, 0.55, 0.05), 0.3, 0.4, 1.2) if gold
             else cs.m_steel())
    if sockets:
        for i in range(3):
            sx, sy = cx + 0.25 + i * 0.22, cy - 0.21
            cs.boxes(r, "Buchse", [(sx, sy, top + 0.008, 0.17, 0.17, 0.006)], m_pocket())
            cs.boxes(r, "BuchseRand", cs.ring_items(sx, sy, 0.19, 0.19, 0.17, 0.17, top + 0.01,
                                                    0.008), m_dim())
            if i < len(mods):
                cs.boxes(r, "Modul", [(sx, sy, top + 0.03, 0.12, 0.12, 0.04)], cs.m_steel())
                cs.boxes(r, "ModulLicht", [(sx, sy, top + 0.052, 0.07, 0.07, 0.006)],
                         dm.glow(mods[i], 3.0))
    return top


def band(r, cx, y, z, width, key="band", e=2.2):
    cs.boxes(r, "Band", [(cx, y, z, width, 0.05, 0.05)], dm.glow(key, e))


def bus(r, rows, depth_front, depth_back):
    """Senkrechte Sammelschienen zwischen den Spalten, Stiche an die Pins."""
    lines = []
    ys = [y for _, y in rows]
    for c in range(2):
        x = (c - 0.5) * COL
        lines.append([(x, max(ys) + depth_back + 0.3), (x, min(ys) - depth_front - 0.3)])
    for cx, cy in rows:
        for k in (-1, 0, 1):
            for s in (-1, 1):
                xr = cx + s * COL * 0.5
                if abs(xr) < COL:
                    lines.append([(cx + s * (CW * 0.5 + 0.14), cy + k * 0.3), (xr, cy + k * 0.3)])
    cs.strips(r, "Bus", lines, 0.035, 0.002, led.mat("Bahn2", (0.03, 0.035, 0.07), 0.2, 0.5))


def cells(pitch):
    return [((i % 3 - 1) * COL, (0.5 - i // 3) * pitch) for i in range(6)]


# --- Modul-Körper für die Buchten (a) ---------------------------------------------------

def module_body(r, kind, x, y, z):
    steel, g = cs.m_steel(), dm.glow(kind, 3.0)
    cs.boxes(r, "Plattform", [(x, y, z + 0.02, 0.44, 0.44, 0.04)], steel)
    z += 0.04
    if kind == "punkte":
        o = dm.cyl(r, "Widerstand", 0.085, 0.3, (x, y, z + 0.1), led.mat("Keramik2", (0.5, 0.42, 0.3),
                                                                        0.0, 0.5), 48)
        o.rotation_euler = (0, math.radians(90), 0)
        for k in (-1, 0, 1):
            b = dm.cyl(r, "Ring", 0.09, 0.035, (x + k * 0.08, y, z + 0.1), g, 48)
            b.rotation_euler = (0, math.radians(90), 0)
        cs.boxes(r, "Bein", [(x - 0.18, y, z + 0.05, 0.03, 0.03, 0.1),
                             (x + 0.18, y, z + 0.05, 0.03, 0.03, 0.1)], steel)
    elif kind == "mult":
        dm.cyl(r, "Elko", 0.15, 0.2, (x, y, z + 0.1), led.mat("Elko", (0.03, 0.03, 0.05), 0.6, 0.3),
               64)
        dm.cyl(r, "ElkoLicht", 0.11, 0.012, (x, y, z + 0.205), g, 64)
        cs.boxes(r, "Kerbe", [(x, y, z + 0.213, 0.2, 0.02, 0.006), (x, y, z + 0.213, 0.02, 0.2, 0.006)],
                 led.mat("Elko", (0, 0, 0)))
    elif kind == "relais":
        led.rounded_box(r, "Relais", (0.36, 0.26, 0.17), (x, y, z + 0.085),
                        led.mat("RelaisGlas", (0.6, 0.9, 0.7), 0.0, 0.05, 0.0, 0.25), 0.03, 0.01)
        o = dm.cyl(r, "Spule", 0.06, 0.2, (x - 0.03, y, z + 0.08), led.mat("Kupfer", (0.7, 0.3, 0.12),
                                                                          1.0, 0.35), 32)
        o.rotation_euler = (0, math.radians(90), 0)
        cs.strips(r, "Pfeil", [[(x - 0.12, y), (x + 0.12, y)], [(x + 0.05, y + 0.06), (x + 0.12, y),
                                                               (x + 0.05, y - 0.06)]], 0.025,
                  z + 0.176, g)
    else:
        dm.cyl(r, "Kolben", 0.11, 0.26, (x, y, z + 0.13), led.mat("Kolben", (0.9, 0.8, 0.9), 0.0, 0.03,
                                                                 0.0, 0.2), 48)
        dm.cyl(r, "Faden", 0.035, 0.2, (x, y, z + 0.12), g, 24)
        dm.cyl(r, "Sockel", 0.13, 0.04, (x, y, z + 0.02), steel, 48)


# --- 0: heute ---------------------------------------------------------------------------

def heute():
    r = cs.root("Heute")
    rows = cells(1.7)
    for (cx, cy), combo in zip(rows, COMBOS):
        chip(r, cx, cy, 0.03, combo, True)
        band(r, cx, cy - CD * 0.5 - 0.03, 0.2, CW - 0.2, "mult" if combo[4] else "band")
    bus(r, rows, CD * 0.5, CD * 0.5)
    return "0 · HEUTE — drei Buchsen im Deckel", 1.7


# --- a: Trägerplatine --------------------------------------------------------------------

def traeger():
    r = cs.root("Traeger")
    pitch, bay = 2.3, 0.56
    rows = cells(pitch)
    for (cx, cy), combo in zip(rows, COMBOS):
        mods, gold = combo[3], combo[4]
        led.rounded_box(r, "Platine", (CW + 0.2, 1.92, 0.05), (cx, cy, 0.025), m_pcb(), 0.08, 0.01)
        chy = cy + 0.4
        chip(r, cx, chy, 0.05, combo)
        by = cy - 0.52
        for i in range(3):
            bx = cx + (i - 1) * 0.62
            cs.boxes(r, "Bucht", [(bx, by, 0.052, bay, bay, 0.006)], m_pocket())
            lit = i < len(mods)
            rim = dm.glow(mods[i], 1.6) if lit else m_dim()
            cs.boxes(r, "BuchtRand", cs.ring_items(bx, by, bay + 0.05, bay + 0.05, bay, bay, 0.062,
                                                   0.024), cs.m_steel())
            cs.strips(r, "Zuleitung", [[(bx, by + bay * 0.5 + 0.03), (bx, chy - CD * 0.5)]], 0.05,
                      0.052, rim)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    dm.cyl(r, "Schraube", 0.022, 0.012, (bx + sx * 0.235, by + sy * 0.235, 0.062),
                           cs.m_steel(), 16)
            if lit:
                module_body(r, mods[i], bx, by, 0.055)
            # Lichtleiste vorn: ein Segment je Bucht
            cs.boxes(r, "Segment", [(bx, cy - 0.94, 0.055, 0.54, 0.05, 0.03)],
                     dm.glow(mods[i], 3.0) if lit else m_dim())
        if gold:
            cs.boxes(r, "GoldSaum", cs.ring_items(cx, cy, CW + 0.3, 2.02, CW + 0.2, 1.92, 0.03, 0.06),
                     dm.glow("mult", 3.0))
    bus_rows = [(cx, cy + 0.4) for cx, cy in rows]
    bus(r, bus_rows, 1.4, 0.5)
    return "A · TRÄGERPLATINE — drei große Buchten unter dem Chip", pitch


# --- b: Einschübe ------------------------------------------------------------------------

def einschub():
    r = cs.root("Einschub")
    pitch = 1.95
    rows = cells(pitch)
    run, rise, low = 0.44, 0.33, 0.07
    ang = math.atan2(rise - low, run)
    for (cx, cy), combo in zip(rows, COMBOS):
        mods, gold = combo[3], combo[4]
        chy = cy + 0.2
        chip(r, cx, chy, 0.03, combo)
        yb = chy - CD * 0.5
        yf = yb - run
        led.rounded_box(r, "Rahmen", (CW, run + 0.06, 0.05), (cx, yb - run * 0.5 - 0.01, 0.025),
                        m_body(gold), 0.04, 0.0)
        for i in range(3):
            bx = cx + (i - 1) * 0.6
            x0, x1 = bx - 0.275, bx + 0.275
            lit = i < len(mods)
            fr = box.frame((bx, yf, low), (1, 0, 0), (0, math.cos(ang), math.sin(ang)))
            face = math.hypot(run, rise - low)
            if lit:
                key = mods[i]
                prism(r, "Schub", x0, x1, [(yb, 0.05), (yf, 0.05), (yf, low), (yb, rise)],
                      m_glass())
                short, line = KINDS[key]
                big = 0.2 if len(short) <= 3 else 0.115
                txt(r, short, 0, face * 0.58, 0, big, key, 3.0, "CENTER", fr)
                txt(r, line if len(line) < 9 else line[:9], 0, face * 0.2, 0, 0.065, key, 1.4,
                    "CENTER", fr)
                cs.boxes(r, "Griff", [(bx, yf - 0.012, 0.06, 0.5, 0.03, 0.04)], dm.glow(key, 3.0))
            else:
                cs.boxes(r, "Schacht", [(bx, yb - run * 0.5, 0.052, 0.55, run - 0.04, 0.006)],
                         m_pocket())
                cs.boxes(r, "SchachtRand", cs.ring_items(bx, yb - run * 0.5, 0.55, run - 0.04, 0.51,
                                                         run - 0.08, 0.058, 0.012), m_dim())
        cs.boxes(r, "Steg", [(cx + s * 0.3, yb - run * 0.5, 0.2, 0.03, run, 0.3) for s in (-3, -1, 1,
                                                                                         3)],
                 m_body(gold))
    bus(r, [(cx, cy + 0.2) for cx, cy in rows], 1.0, 0.5)
    return "B · EINSCHÜBE — schräge Schubfächer vorn, die Front nennt das Modul", pitch


# --- c: Terrasse -------------------------------------------------------------------------

def terrasse():
    r = cs.root("Terrasse")
    pitch, step, th = 2.1, 0.27, 0.11
    rows = cells(pitch)
    slab = led.mat("Stufe", (0.07, 0.07, 0.1), 0.7, 0.35, clearcoat=0.3)
    for (cx, cy), combo in zip(rows, COMBOS):
        mods, gold = combo[3], combo[4]
        n = len(mods)
        chy = cy + 0.3
        back, front = chy + CD * 0.5, chy - CD * 0.5
        # Landemarken der drei Plätze auf dem Filz
        for k in range(3):
            y = front - (k + 0.5) * step
            cs.boxes(r, "Marke", cs.ring_items(cx, y, CW, step - 0.04, CW - 0.04, step - 0.08, 0.004,
                                               0.006), m_dim())
        for k, key in enumerate(mods):
            y1 = front - (n - k) * step
            led.rounded_box(r, "Stufe%d" % k, (CW + 0.06, back - y1, th), (cx, (back + y1) * 0.5,
                                                                         0.02 + th * (k + 0.5)),
                            slab, 0.04, 0.008)
            z = 0.02 + th * (k + 1)
            short, line = KINDS[key]
            ym = y1 + step * 0.5
            txt(r, short, cx - CW * 0.5 + 0.1, ym, z + 0.004, 0.15, key, 3.0)
            if short != "RELAIS" or True:
                t = txt(r, line, cx + CW * 0.5 - 0.08, ym, z + 0.004, 0.085, key, 1.4, "RIGHT")
            cs.boxes(r, "Kante", [(cx, y1 - 0.012, z - th * 0.5, CW - 0.1, 0.02, 0.035)],
                     dm.glow(key, 3.0))
        z0 = 0.02 + th * n
        chip(r, cx, chy, z0, combo)
        band(r, cx, back + 0.03, z0 + 0.2, CW - 0.2, "mult" if gold else "band", 1.6)
    bus(r, [(cx, cy + 0.3) for cx, cy in rows], 1.5, 0.5)
    return "C · TERRASSE — Module sind Platten unter dem Chip, jede Stufe trägt ihre Zeile", pitch


# --- Runde 2: die FUNKTION erklärt die Wirkung ---------------------------------------------

BW, BD = CW + 0.2, 1.92
STATIONS = (-0.62, 0.0, 0.62)


def board(r, cx, cy, gold, material=None):
    led.rounded_box(r, "Platine", (BW, BD, 0.05), (cx, cy, 0.025), material or m_pcb(), 0.08, 0.01)
    if gold:
        cs.boxes(r, "GoldSaum", cs.ring_items(cx, cy, BW + 0.1, BD + 0.1, BW, BD, 0.03, 0.06),
                 dm.glow("mult", 3.0))


def value(r, key, x, y, z=0.054):
    txt(r, KINDS[key][0], x, y, z, 0.085, key, 2.0, "CENTER")


def arrow(tip, d, s):
    t, d = Vector(tip), Vector(d).normalized()
    n = Vector((-d.y, d.x))
    return [tuple(t - d * s + n * s * 0.7), tuple(t), tuple(t - d * s - n * s * 0.7)]


def lying(o):
    o.rotation_euler = (0, math.radians(90), 0)
    return o


def clear(key, a=0.3, e=0.5):
    return led.mat("Klar_%s" % key, dm.col(key), 0.0, 0.05, e, a)


def copper():
    return led.mat("Kupfer", (0.7, 0.3, 0.12), 1.0, 0.35)


def comp_cell(r, x, y, z, key):
    """Speicherzelle: sie legt Ladung dazu."""
    lying(dm.cyl(r, "Zelle", 0.1, 0.36, (x, y, z + 0.11), clear(key, 0.25, 0.2), 48))
    lying(dm.cyl(r, "Ladung", 0.07, 0.3, (x, y, z + 0.11), dm.glow(key, 3.0), 32))
    for s in (-1, 1):
        lying(dm.cyl(r, "Kappe", 0.105, 0.04, (x + s * 0.19, y, z + 0.11), cs.m_steel(), 48))


def comp_trafo(r, x, y, z, key):
    """Übertrager: wenige Windungen hinein, viele hinaus."""
    cs.boxes(r, "Kern", [(x, y, z + 0.13, 0.44, 0.07, 0.07)], led.mat("Kern", (0.03, 0.03, 0.04), 0.8,
                                                                    0.4))
    for k in range(2):
        lying(dm.cyl(r, "Primaer", 0.085, 0.03, (x - 0.17 + k * 0.045, y, z + 0.13), copper(), 32))
    for k in range(5):
        lying(dm.cyl(r, "Sekundaer", 0.15, 0.03, (x - 0.02 + k * 0.045, y, z + 0.13),
                     dm.glow(key, 2.6), 48))


def comp_loop(r, x, y, z, key, rise=0.22):
    """Relais: die Bahn läuft in einer Schleife zurück - das Signal kommt zweimal."""
    cs.boxes(r, "Schalter", [(x, y, z + 0.06, 0.2, 0.14, 0.12)], led.mat("Kern", (0, 0, 0)))
    lying(dm.cyl(r, "Spule", 0.05, 0.16, (x, y, z + 0.14), copper(), 24))
    g = dm.glow(key, 3.0)
    loop = [(x + 0.2, y), (x + 0.2, y + rise), (x - 0.2, y + rise), (x - 0.2, y)]
    cs.strips(r, "Schleife", [loop, arrow((x - 0.02, y + rise), (-1, 0), 0.06)], 0.03, z + 0.004, g)


def comp_spark(r, x, y, z, key, dome=True):
    """Funkenstrecke: manchmal schlägt es über."""
    for s in (-1, 1):
        dm.cyl(r, "Stift", 0.02, 0.12, (x + s * 0.14, y, z + 0.06), cs.m_steel(), 12)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, location=(x + s * 0.14, y, z + 0.14))
        o = bpy.context.active_object
        o.data.materials.append(cs.m_steel())
        bpy.ops.object.shade_smooth()
        o.parent = r
    zig = [(x - 0.1, y), (x - 0.05, y + 0.05), (x, y - 0.04), (x + 0.05, y + 0.05), (x + 0.1, y)]
    cs.strips(r, "Bogen", [zig], 0.022, z + 0.14, dm.glow(key, 4.0))
    if dome:
        dm.cyl(r, "Glocke", 0.21, 0.24, (x, y, z + 0.12), clear(key, 0.1, 0.1), 48)


COMPS = {"punkte": comp_cell, "mult": comp_trafo, "relais": comp_loop, "krit": comp_spark}


def run(r, xa, xb, y, w, n, e, key="punkte", z=0.053):
    offs = [0.0] if n == 1 else [-w * 0.9, w * 0.9]
    cs.strips(r, "Signal", [[(xa, y + o), (xb, y + o)] for o in offs], w, z, dm.glow(key, e))


def kette():
    r = cs.root("Kette")
    pitch = 2.3
    rows = cells(pitch)
    for (cx, cy), combo in zip(rows, COMBOS):
        mods = combo[3]
        board(r, cx, cy, combo[4])
        chy, by = cy + 0.4, cy - 0.48
        chip(r, cx, chy, 0.05, combo)
        w, n, e = 0.03, 1, 1.4
        cs.strips(r, "Signal", [[(cx - 0.93, chy - 0.5), (cx - 0.93, by), (cx - 0.84, by)]], w, 0.053,
                  dm.glow("punkte", e))
        for i, sx in enumerate(STATIONS):
            bx = cx + sx
            if i < len(mods):
                key = mods[i]
                COMPS[key](r, bx, by, 0.05, key)
                value(r, key, bx, by - 0.34)
                if key == "punkte":
                    w += 0.03
                elif key == "mult":
                    w *= 1.9
                elif key == "relais":
                    n = 2
                e += 0.9
            else:
                run(r, bx - 0.22, bx + 0.22, by, w * 0.6, n, e * 0.5)
                cs.boxes(r, "Pad", [(bx + s * 0.2, by, 0.056, 0.07, 0.11, 0.012) for s in (-1, 1)],
                         cs.m_steel())
            run(r, bx + 0.22, bx + 0.4 if i < 2 else cx + COL * 0.5, by, w, n, e)
        cs.boxes(r, "Ausgang", [(cx + 0.95, by, 0.07, 0.07, 0.3, 0.05)], cs.m_steel())
    bus(r, [(cx, cy + 0.4) for cx, cy in rows], 1.4, 0.5)
    return "D · SIGNALKETTE — das Ergebnis läuft durch die Module und wird dabei stärker", pitch


def optik():
    r = cs.root("Optik")
    pitch = 2.3
    rows = cells(pitch)
    zb = 0.13
    for (cx, cy), combo in zip(rows, COMBOS):
        mods = combo[3]
        board(r, cx, cy, combo[4])
        chy, by = cy + 0.4, cy - 0.5
        chip(r, cx, chy, 0.05, combo)
        cs.boxes(r, "Kanal", [(cx, by, 0.052, BW - 0.12, 0.6, 0.006)], m_pocket())
        cs.boxes(r, "KanalRand", cs.ring_items(cx, by, BW - 0.08, 0.64, BW - 0.12, 0.6, 0.06, 0.02),
                 cs.m_steel())
        cs.boxes(r, "Emitter", [(cx - 0.86, by, 0.11, 0.1, 0.2, 0.12)], cs.m_steel())
        cs.strips(r, "Lichtleiter", [[(cx - 0.86, chy - 0.5), (cx - 0.86, by + 0.1)]], 0.05, 0.053,
                  dm.glow("band", 2.0))
        w, n, e, spark = 0.03, 1, 1.6, False
        x = cx - 0.81
        for i, sx in enumerate(STATIONS):
            bx = cx + sx
            run(r, x, bx, by, w, n, e, "punkte", zb)
            if i < len(mods):
                key = mods[i]
                if key == "punkte":
                    cs.boxes(r, "Zusatz", [(bx - 0.14, by + 0.21, 0.1, 0.12, 0.1, 0.1)], cs.m_steel())
                    cs.strips(r, "Zustrahl", [[(bx - 0.12, by + 0.17), (bx, by)]], 0.03, zb,
                              dm.glow(key, 3.0))
                    w += 0.03
                elif key == "mult":
                    dm.cyl(r, "Kristall", 0.17, 0.22, (bx, by, 0.16), clear(key, 0.4, 1.2), 6)
                    w *= 1.9
                    e += 1.2
                elif key == "relais":
                    o = dm.cyl(r, "Prisma", 0.19, 0.2, (bx, by, 0.15), clear(key, 0.4, 1.0), 3)
                    o.rotation_euler = (0, 0, math.radians(90))
                    n = 2
                else:
                    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.14,
                                                          location=(bx, by, 0.2))
                    o = bpy.context.active_object
                    o.data.materials.append(clear(key, 0.6, 2.5))
                    o.parent = r
                    spark = True
                value(r, key, bx, by - 0.38)
                e += 0.5
            else:
                cs.boxes(r, "Halter", cs.ring_items(bx, by, 0.3, 0.3, 0.26, 0.26, 0.058, 0.01), m_dim())
            x = bx
        run(r, x, cx + 0.84, by, w, n, e, "punkte", zb)
        if spark:
            cs.strips(r, "Funken", [[(x + 0.1 + k * 0.13, by + (0.09 if k % 2 else -0.09)),
                                     (x + 0.16 + k * 0.13, by + (0.13 if k % 2 else -0.13))]
                                    for k in range(5)], 0.02, zb, dm.glow("krit", 4.0))
        cs.boxes(r, "Sammler", [(cx + 0.88, by, 0.11, 0.08, 0.34, 0.12)], cs.m_steel())
        run(r, cx + 0.92, cx + COL * 0.5, by, w * 0.8, n, e * 0.8)
    bus(r, [(cx, cy + 0.4) for cx, cy in rows], 1.4, 0.5)
    return "E · LICHTBANK — der Chip sendet einen Strahl, Optik im Kanal verändert ihn", pitch


def rechenwerk():
    r = cs.root("Rechenwerk")
    pitch, hw, hd = 1.95, 2.1, 1.5
    rows = cells(pitch)
    for (cx, cy), (name, pts, mult, mods, gold) in zip(rows, COMBOS):
        led.rounded_box(r, "Body", (hw, hd, CH), (cx, cy, 0.03 + CH * 0.5), m_body(gold), 0.06, 0.02)
        top = 0.03 + CH
        led.rounded_box(r, "Glas", (hw - 0.16, hd - 0.16, 0.012), (cx, cy, top), m_glass(), 0.04, 0.0)
        cs.boxes(r, "Pins", [(cx + s * (hw * 0.5 + 0.07), cy + k * 0.3, 0.12, 0.14, 0.2, 0.1)
                             for s in (-1, 1) for k in (-1, 0, 1)],
                 dm.glow("mult", 1.2) if gold else cs.m_steel())
        z = top + 0.008
        txt(r, name, cx - 0.9, cy + 0.5, z, 0.2 if len(name) < 16 else 0.17, "name")
        ey = cy + 0.06
        txt(r, pts, cx - 0.92, ey, z, 0.26, "punkte")
        txt(r, mult, cx - 0.12, ey, z, 0.26, "mult")
        p, m = int(pts), int(mult[1:])
        for sx, kinds, hint in ((-0.36, ("punkte",), "+"), (0.44, ("mult",), "×"),
                                (0.83, ("relais", "krit"), "")):
            bx = cx + sx
            got = [k for k in mods if k in kinds]
            if got:
                key = got[0]
                led.rounded_box(r, "Taste", (0.33, 0.36, 0.09), (bx, ey, top + 0.045),
                                led.mat("Taste", (0.02, 0.02, 0.035), 0.0, 0.35, clearcoat=0.5), 0.04,
                                0.015)
                tz = top + 0.092
                cs.boxes(r, "TastenSaum", cs.ring_items(bx, ey, 0.31, 0.34, 0.28, 0.31, tz, 0.004),
                         dm.glow(key, 2.2))
                if key == "relais":
                    loop = [(bx + 0.08, ey - 0.08), (bx + 0.08, ey + 0.08), (bx - 0.08, ey + 0.08),
                            (bx - 0.08, ey - 0.08), (bx + 0.02, ey - 0.08)]
                    cs.strips(r, "Schleife", [loop, arrow((bx + 0.04, ey - 0.08), (1, 0), 0.05)],
                              0.025, tz + 0.002, dm.glow(key, 3.0))
                else:
                    label = KINDS[key][0]
                    txt(r, label, bx, ey, tz + 0.002, 0.15 if len(label) < 4 else 0.085, key, 3.0,
                        "CENTER")
                p, m = p + (10 if key == "punkte" else 0), m * (2 if key == "mult" else 1)
            else:
                cs.boxes(r, "Platz", [(bx, ey, z, 0.31, 0.34, 0.004)], m_pocket())
                cs.boxes(r, "PlatzRand", cs.ring_items(bx, ey, 0.33, 0.36, 0.31, 0.34, z + 0.002,
                                                       0.006), m_dim())
        cs.strips(r, "Strich", [[(cx - 0.92, cy - 0.2), (cx + 0.92, cy - 0.2)]], 0.012, z, m_dim())
        dm.HEX["weiss"] = "#f2f2ff"
        txt(r, "=", cx - 0.92, cy - 0.47, z, 0.24, "weiss", 1.5)
        txt(r, str(p), cx - 0.66, cy - 0.47, z, 0.3, "punkte", 3.0)
        txt(r, "×%d" % m, cx - 0.66 + 0.19 * len(str(p)) + 0.12, cy - 0.47, z, 0.3, "mult", 3.0)
        if "relais" in mods:
            txt(r, "2×", cx + 0.9, cy - 0.47, z, 0.2, "relais", 2.5, "RIGHT")
    bus(r, rows, hd * 0.5, hd * 0.5)
    return "F · RECHENWERK — die Module sind Tasten in der Rechnung, unten steht das Ergebnis", pitch


def die_pattern(r, key, x, y, z):
    g = dm.glow(key, 2.6)
    if key == "punkte":
        cs.boxes(r, "Zellen", [(x + (a - 1.5) * 0.085, y + (b - 1.5) * 0.085, z, 0.055, 0.055, 0.004)
                               for a in range(4) for b in range(4)], g)
    elif key == "mult":
        items = []
        for s in (0.34, 0.22, 0.1):
            items += cs.ring_items(x, y, s, s, s - 0.05, s - 0.05, z, 0.004)
        cs.boxes(r, "Ringe", items, g)
    elif key == "relais":
        loop = [(x + 0.13, y - 0.13), (x + 0.13, y + 0.13), (x - 0.13, y + 0.13), (x - 0.13, y - 0.13),
                (x + 0.04, y - 0.13)]
        cs.strips(r, "Schleife", [loop, arrow((x + 0.07, y - 0.13), (1, 0), 0.06)], 0.035, z, g)
    else:
        cs.strips(r, "Stern", [[(x - 0.14, y - 0.14), (x + 0.14, y + 0.14)],
                               [(x - 0.14, y + 0.14), (x + 0.14, y - 0.14)],
                               [(x, y - 0.16), (x, y + 0.16)], [(x - 0.16, y), (x + 0.16, y)]], 0.03, z,
                  g)


def mehrkern():
    r = cs.root("Mehrkern")
    pitch = 2.3
    rows = cells(pitch)
    silicon = led.mat("Silizium", (0.02, 0.03, 0.09), 0.9, 0.12, clearcoat=1.0)
    for (cx, cy), combo in zip(rows, COMBOS):
        mods = combo[3]
        board(r, cx, cy, combo[4], cs.m_ceramic())
        chy, by = cy + 0.4, cy - 0.5
        chip(r, cx, chy, 0.05, combo)
        cs.boxes(r, "Substrat", [(cx, by, 0.052, BW - 0.14, 0.66, 0.006)],
                 led.mat("Substrat", (0.004, 0.012, 0.01), 0.0, 0.5))
        for i, sx in enumerate(STATIONS):
            bx = cx + sx
            cs.boxes(r, "Padring", cs.ring_items(bx, by, 0.56, 0.56, 0.5, 0.5, 0.056, 0.006),
                     cs.m_gold())
            if i < len(mods):
                key = mods[i]
                cs.boxes(r, "Kern", [(bx, by, 0.072, 0.4, 0.4, 0.034)], silicon)
                die_pattern(r, key, bx, by, 0.091)
                wires = []
                for k in range(-2, 3):
                    for s in (-1, 1):
                        wires.append([(bx + k * 0.07, by + s * 0.2), (bx + k * 0.07, by + s * 0.27)])
                        wires.append([(bx + s * 0.2, by + k * 0.07), (bx + s * 0.27, by + k * 0.07)])
                cs.strips(r, "Bonddraht", wires, 0.012, 0.085, cs.m_gold())
                cs.strips(r, "Leitung", [[(bx + k * 0.06, by + 0.28), (bx + k * 0.06, chy - 0.5)]
                                         for k in (-1, 0, 1)], 0.02, 0.054, dm.glow(key, 2.0))
                value(r, key, bx, by - 0.39)
            else:
                cs.strips(r, "Leer", [[(bx - 0.1, by), (bx + 0.1, by)], [(bx, by - 0.1), (bx, by + 0.1)]],
                          0.012, 0.056, m_dim())
        led.rounded_box(r, "Fenster", (BW - 0.1, 0.7, 0.07), (cx, by, 0.1),
                        led.mat("Fensterglas", (0.8, 0.9, 1.0), 0.0, 0.02, 0.0, 0.08), 0.04, 0.01)
    bus(r, [(cx, cy + 0.4) for cx, cy in rows], 1.4, 0.5)
    return "G · MEHRKERN — jedes Modul ist ein weiterer Rechenkern im Gehäuse", pitch


def uebertakter():
    r = cs.root("Uebertakter")
    pitch = 2.3
    rows = cells(pitch)
    alu = led.mat("Alu", (0.55, 0.57, 0.62), 1.0, 0.35)
    for (cx, cy), combo in zip(rows, COMBOS):
        mods = combo[3]
        board(r, cx, cy, combo[4])
        chy, by = cy + 0.4, cy - 0.5
        chip(r, cx, chy, 0.05, combo)
        slots = [[k for k in mods if k == "punkte"], [k for k in mods if k == "mult"],
                 [k for k in mods if k in ("relais", "krit")]]
        for i, sx in enumerate(STATIONS):
            bx, got = cx + sx, slots[i]
            key = got[0] if got else None
            lamp = dm.glow(key, 3.0) if key else m_dim()
            cs.boxes(r, "Anzeige", [(bx, chy - CD * 0.5 - 0.04, 0.2, 0.54, 0.05, 0.05)], lamp)
            if i == 0:
                for k in (-1, 0, 1):
                    px = bx + k * 0.17
                    if key:
                        dm.cyl(r, "Elko", 0.075, 0.26, (px, by, 0.18), led.mat("Elko", (0, 0, 0)), 32)
                        dm.cyl(r, "ElkoLicht", 0.055, 0.01, (px, by, 0.312), lamp, 32)
                    else:
                        dm.annulus(r, "ElkoPlatz", px, by, 0.054, 0.06, 0.075, m_dim(), 32)
                if key:
                    cs.strips(r, "Schiene", [[(bx, by + 0.1), (bx, chy - 0.5)]], 0.09, 0.053, lamp)
            elif i == 1:
                if key:
                    led.rounded_box(r, "Quarz", (0.4, 0.2, 0.14), (bx, by, 0.12), cs.m_steel(), 0.08,
                                    0.03)
                    wave, x0, y0 = [], bx - 0.2, by + 0.2
                    for k in range(5):
                        hi = y0 + (0.1 if k % 2 == 0 else 0.0)
                        wave += [(x0 + k * 0.1, hi), (x0 + (k + 1) * 0.1, hi)]
                    cs.strips(r, "Takt", [wave, [(bx, by + 0.34), (bx, chy - 0.5)]], 0.025, 0.053, lamp)
                else:
                    cs.boxes(r, "QuarzPlatz", cs.ring_items(bx, by, 0.42, 0.22, 0.39, 0.19, 0.054,
                                                            0.006), m_dim())
            else:
                if key:
                    cs.boxes(r, "Rippen", [(bx + (k - 3) * 0.075, by, 0.17, 0.035, 0.46, 0.24)
                                           for k in range(7)], alu)
                    cs.boxes(r, "Sockel", [(bx, by, 0.065, 0.52, 0.46, 0.03)], alu)
                    cs.boxes(r, "Heatpipe", [(bx + s * 0.13, (by + chy - 0.5) * 0.5 + 0.1, 0.09, 0.05,
                                              chy - 0.5 - by, 0.05) for s in (-1, 1)], copper())
                    cs.boxes(r, "RippenLicht", [(bx, by - 0.25, 0.08, 0.5, 0.025, 0.03)], lamp)
                else:
                    cs.boxes(r, "RippenPlatz", [(bx + (k - 3) * 0.075, by, 0.054, 0.02, 0.44, 0.006)
                                                for k in range(7)], m_dim())
            if key:
                value(r, key, bx, by - 0.39)
    bus(r, [(cx, cy + 0.4) for cx, cy in rows], 1.4, 0.5)
    return "H · ÜBERTAKTER — Strom, Takt und Kühlung: drei feste Plätze, jeder mit eigener Form", pitch


# --- Runde 3: LOGIK-GATTER ----------------------------------------------------------------

GATE_W, GATE_H = 0.46, 0.4
# je Chip: (Gatter, [(Würfelzahl, Fühler an)], Lohn)
GATES = [[],
         [("and", [("6", 1), ("1", 1)], "mult")],
         [("and", [("6", 1), ("1", 0)], "mult"), ("xor", [("6", 1), ("1", 0)], "punkte"),
          ("not", [("1", 0)], "mult")],
         [("nand", [("5", 1), ("5", 1)], "punkte"), ("or", [("2", 0), ("3", 1)], "mult")],
         [("not", [("1", 1)], "punkte"), ("or", [("6", 1), ("5", 0)], "mult")],
         []]
TRUTH = {"and": lambda a: all(a), "or": lambda a: any(a), "xor": lambda a: sum(a) == 1,
         "nand": lambda a: not all(a), "not": lambda a: not a[0]}


def arc(cx, cy, rx, ry, a0, a1, n=14):
    return [(cx + math.cos(math.radians(a0 + (a1 - a0) * i / n)) * rx,
             cy + math.sin(math.radians(a0 + (a1 - a0) * i / n)) * ry) for i in range(n + 1)]


def gate_outline(kind):
    """Schaltzeichen, Ausgang nach +Y: Umriß und Höhe der Spitze."""
    w, h = GATE_W * 0.5, GATE_H
    if kind in ("and", "nand"):
        return [(-w, 0), (w, 0)] + arc(0, h - w, w, w, 0, 180), h
    if kind == "not":
        return [(-w * 0.8, 0), (w * 0.8, 0), (0, h * 0.8)], h * 0.8
    right = [(w * (1 - t * t), h * (1 - (1 - t) ** 1.6)) for t in [i / 10 for i in range(11)]]
    left = [(-x, y) for x, y in reversed(right)]
    return arc(0, -0.16, w, 0.26, 142, 38, 10)[1:-1] + right + left, h


def poly_prism(r, name, pts, z0, z1, material):
    n = len(pts)
    verts = [(x, y, z) for z in (z0, z1) for x, y in pts]
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = r
    return o


def gate(r, kind, x, y, key, on):
    """Baut das Gatter mit Fuß bei (x, y); liefert die Höhe seines Ausgangs."""
    pts, tip = gate_outline(kind)
    world = [(x + a, y + b) for a, b in pts]
    poly_prism(r, "Gatter_" + kind, world, 0.05, 0.14,
               led.mat("GatterGlas", (0.012, 0.014, 0.03), 0.0, 0.2, clearcoat=1.0))
    g = dm.glow(key, 3.2 if on else 0.9)
    cs.strips(r, "Umriss", [world + [world[0]]], 0.03, 0.142, g)
    if kind == "xor":
        cs.strips(r, "Bogen", [[(x + a, y + b) for a, b in arc(0, -0.25, GATE_W * 0.5, 0.26, 142, 38,
                                                               10)]], 0.03, 0.054, g)
    if kind in ("nand", "not"):
        dm.annulus(r, "Blase", x, y + tip + 0.045, 0.142, 0.028, 0.055, g, 24)
        dm.cyl(r, "BlaseFuss", 0.05, 0.09, (x, y + tip + 0.045, 0.095), led.mat("GatterGlas",
                                                                               (0, 0, 0)), 24)
        tip += 0.09
    txt(r, kind.upper(), x, y + (0.13 if kind != "not" else 0.09), 0.143,
        0.075 if kind != "nand" else 0.065, key, 2.4 if on else 1.0, "CENTER")
    return tip


def gatter():
    r = cs.root("Gatter")
    pitch, depth = 2.45, 2.1
    rows = cells(pitch)
    for (cx, cy), combo, mods in zip(rows, COMBOS, GATES):
        led.rounded_box(r, "Platine", (BW, depth, 0.05), (cx, cy, 0.025), m_pcb(), 0.08, 0.01)
        if combo[4]:
            cs.boxes(r, "GoldSaum", cs.ring_items(cx, cy, BW + 0.1, depth + 0.1, BW, depth, 0.03, 0.06),
                     dm.glow("mult", 3.0))
        chy, main, base, lamp_y = cy + 0.5, cy - 0.1, cy - 0.64, cy - 0.78
        chip(r, cx, chy, 0.05, combo)
        w, e = 0.03, 1.4
        cs.strips(r, "Signal", [[(cx - 0.93, chy - 0.5), (cx - 0.93, main), (cx - 0.86, main)]], w,
                  0.053, dm.glow("punkte", e))
        x = cx - 0.86
        for i, sx in enumerate(STATIONS):
            bx = cx + sx
            run(r, x, bx, main, w, 1, e)
            x = bx
            if i >= len(mods):
                cs.boxes(r, "Platz", cs.ring_items(bx, base + 0.2, 0.5, 0.44, 0.47, 0.41, 0.054, 0.006),
                         m_dim())
                for s in (-1, 1):
                    dm.annulus(r, "FuehlerPlatz", bx + s * 0.11, lamp_y, 0.054, 0.04, 0.055, m_dim(), 24)
                continue
            kind, sensors, key = mods[i]
            on = TRUTH[kind]([lit for _, lit in sensors])
            tip = gate(r, kind, bx, base, key, on)
            offs = [0.0] if len(sensors) == 1 else [-0.11, 0.11]
            for (face, lit), o in zip(sensors, offs):
                lamp = dm.glow("weiss", 3.0) if lit else m_dim()
                dm.cyl(r, "Fuehler", 0.055, 0.03, (bx + o, lamp_y, 0.065), lamp, 24)
                cs.strips(r, "Eingang", [[(bx + o, lamp_y + 0.05), (bx + o, base + 0.02)]], 0.025,
                          0.053, lamp)
                t = txt(r, face, bx + o, lamp_y - 0.14, 0.054, 0.1, "weiss", 2.0 if lit else 0.5,
                        "CENTER")
            out = dm.glow(key, 3.0) if on else m_dim()
            cs.strips(r, "Ausgang", [[(bx, base + tip), (bx, main)]], 0.04 if on else 0.02, 0.054, out)
            txt(r, KINDS[key][0], bx + 0.06, (base + tip + main) * 0.5, 0.054, 0.085, key,
                2.4 if on else 0.6)
            if on:
                w = w + 0.03 if key == "punkte" else w * 1.9
                e += 0.9
        run(r, x, cx + COL * 0.5, main, w, 1, e)
    bus(r, [(cx, cy + 0.5) for cx, cy in rows], 1.6, 0.5)
    return "I · GATTER — Fühler lesen den Wurf, das Gatter entscheidet, ob sein Lohn zufließt", pitch


# --- Runde 4: KOMPAKT - derselbe Platz wie heute (oder weniger) ------------------------------

def readout(r, cx, cy, w, d, top, combo):
    """Deckelglas mit Name und Wertung; lange Namen brechen in zwei Zeilen."""
    name, pts, mult = combo[0], combo[1], combo[2]
    led.rounded_box(r, "Glas", (w - 0.14, d - 0.16, 0.012), (cx, cy, top), m_glass(), 0.04, 0.0)
    x0, z = cx - w * 0.5 + 0.15, top + 0.008
    if len(name) > 14:
        a, b = name.split(" ", 1)
        txt(r, a, x0, cy + 0.3, z, 0.17, "name")
        txt(r, b, x0, cy + 0.09, z, 0.17, "name")
        vy = cy - 0.24
    else:
        txt(r, name, x0, cy + 0.2, z, 0.18, "name")
        vy = cy - 0.21
    txt(r, pts, x0, vy, z, 0.25, "punkte")
    txt(r, mult, x0 + 0.16 * len(pts) + 0.1, vy, z, 0.25, "mult")


def rails(r, xs, y0, y1):
    cs.strips(r, "Bus", [[(x, y0), (x, y1)] for x in xs], 0.035, 0.002,
              led.mat("Bahn2", (0.03, 0.035, 0.07), 0.2, 0.5))


def pinlinien():
    r = cs.root("Pinlinien")
    pitch, w = 1.7, 1.3
    rows = cells(pitch)
    for (cx, cy), combo in zip(rows, COMBOS):
        mods, gold = combo[3], combo[4]
        chx = cx - 0.5
        led.rounded_box(r, "Body", (w, CD, CH), (chx, cy, 0.03 + CH * 0.5), m_body(gold), 0.06, 0.02)
        readout(r, chx, cy, w, CD, 0.03 + CH, combo)
        cs.boxes(r, "Pins", [(chx + s * (w * 0.5 + 0.07), cy + k * 0.33, 0.12, 0.14, 0.2, 0.1)
                             for s in (-1, 1) for k in (-1, 0, 1)],
                 dm.glow("mult", 1.2) if gold else cs.m_steel())
        band(r, chx, cy - CD * 0.5 - 0.03, 0.2, w - 0.2, "mult" if gold else "band")
        xp, xe = cx + 0.29, cx + COL * 0.5
        for i in range(3):
            y = cy + (1 - i) * 0.33
            run(r, cx - COL * 0.5, chx - w * 0.5 - 0.14, y, 0.02, 1, 0.6, "band", 0.003)
            if i >= len(mods):
                run(r, xp, xe, y, 0.02, 1, 0.7, "punkte", 0.003)
                cs.boxes(r, "Platz", cs.ring_items(cx + 0.88, y, 0.5, 0.24, 0.47, 0.21, 0.004, 0.006),
                         m_dim())
                continue
            key = mods[i]
            run(r, xp, cx + 0.68, y, 0.03, 1, 1.4, "punkte", 0.003)
            txt(r, KINDS[key][0], cx + 0.47, y + 0.085, 0.003, 0.085, key, 2.2, "CENTER")
            bx = cx + 0.88
            if key == "relais":
                comp_loop(r, bx, y, 0.0, key, 0.12)
            elif key == "krit":
                comp_spark(r, bx, y, 0.0, key, False)
            else:
                COMPS[key](r, bx, y, 0.0, key)
            lw = {"punkte": 0.06, "mult": 0.075}.get(key, 0.035)
            run(r, cx + 1.1, xe, y, lw, 2 if key == "relais" else 1, 2.6, "punkte", 0.003)
    rails(r, [(c - 1.5) * COL for c in range(4)], pitch * 0.5 + 0.8, -pitch * 0.5 - 0.8)
    return "J · PIN-LEITUNGEN — gleicher Platz wie heute: je Pin eine Leitung, je Leitung ein Modul", pitch


def riegel():
    r = cs.root("Riegel")
    pitch, bw, bd = 1.3, 2.4, 1.06
    rows = cells(pitch)
    top = 0.03 + 0.24
    zb = top + 0.07
    for (cx, cy), combo in zip(rows, COMBOS):
        mods, gold = combo[3], combo[4]
        led.rounded_box(r, "Riegel", (bw, bd, 0.24), (cx, cy, 0.15), m_body(gold), 0.07, 0.02)
        readout(r, cx - 0.62, cy, 1.12, bd, top, combo)
        kx, kl = cx + 0.56, 1.2
        cs.boxes(r, "Kanal", [(kx, cy, top + 0.004, kl, 0.84, 0.008)], m_pocket())
        cs.boxes(r, "KanalRand", cs.ring_items(kx, cy, kl + 0.04, 0.88, kl, 0.84, top + 0.012, 0.024),
                 dm.glow("mult", 2.0) if gold else cs.m_steel())
        cs.boxes(r, "Emitter", [(kx - kl * 0.5 + 0.05, cy, top + 0.06, 0.08, 0.22, 0.1)], cs.m_steel())
        w, n, e, spark = 0.03, 1, 1.6, False
        x = kx - kl * 0.5 + 0.09
        for i in range(3):
            bx = kx - 0.38 + i * 0.4
            run(r, x, bx, cy, w, n, e, "punkte", zb)
            if i < len(mods):
                key = mods[i]
                if key == "punkte":
                    cs.boxes(r, "Zusatz", [(bx - 0.13, cy + 0.24, top + 0.06, 0.12, 0.1, 0.1)],
                             cs.m_steel())
                    cs.strips(r, "Zustrahl", [[(bx - 0.11, cy + 0.2), (bx, cy)]], 0.03, zb,
                              dm.glow(key, 3.0))
                    w += 0.03
                elif key == "mult":
                    dm.cyl(r, "Kristall", 0.18, 0.2, (bx, cy, top + 0.1), clear(key, 0.4, 1.2), 6)
                    w *= 1.9
                    e += 1.2
                elif key == "relais":
                    o = dm.cyl(r, "Prisma", 0.2, 0.18, (bx, cy, top + 0.09), clear(key, 0.4, 1.0), 3)
                    o.rotation_euler = (0, 0, math.radians(90))
                    n = 2
                else:
                    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.15,
                                                          location=(bx, cy, top + 0.15))
                    o = bpy.context.active_object
                    o.data.materials.append(clear(key, 0.6, 2.5))
                    o.parent = r
                    spark = True
                txt(r, KINDS[key][0], bx, cy - 0.33, top + 0.012, 0.085, key, 2.2, "CENTER")
                e += 0.5
            else:
                cs.boxes(r, "Halter", cs.ring_items(bx, cy, 0.32, 0.32, 0.28, 0.28, top + 0.012, 0.008),
                         m_dim())
            x = bx
        xe = kx + kl * 0.5
        run(r, x, xe, cy, w, n, e, "punkte", zb)
        if spark:
            cs.strips(r, "Funken", [[(x + 0.08 + k * 0.05, cy + (0.1 if k % 2 else -0.1)),
                                     (x + 0.12 + k * 0.05, cy + (0.15 if k % 2 else -0.15))]
                                    for k in range(3)], 0.02, zb, dm.glow("krit", 4.0))
        cs.boxes(r, "Austritt", [(cx + bw * 0.5 + 0.02, cy, 0.15, 0.05, 0.4, 0.2)], cs.m_steel())
        run(r, cx + bw * 0.5 + 0.04, cx + COL * 0.5, cy, w * 0.8, n, e, "punkte", 0.003)
    rails(r, [(c - 1.5) * COL for c in range(1, 4)], pitch * 0.5 + 0.7, -pitch * 0.5 - 0.7)
    return "K · LICHTRIEGEL — Anzeige und Lichtkanal in EINEM Riegel, ein Viertel weniger Höhe als heute", pitch


def rack():
    r = cs.root("Rack")
    pitch, uw = 1.13, 3.78
    for i, (combo, mods) in enumerate(zip(COMBOS, GATES)):
        ux, cy = (i % 2 - 0.5) * 3.825, (1 - i // 2) * pitch
        gold = combo[4]
        led.rounded_box(r, "Einschub", (uw, 1.07, 0.05), (ux, cy, 0.025), m_pcb(), 0.05, 0.01)
        if gold:
            cs.boxes(r, "GoldSaum", cs.ring_items(ux, cy, uw + 0.06, 1.13, uw, 1.07, 0.03, 0.06),
                     dm.glow("mult", 3.0))
        chx = ux - 0.92
        led.rounded_box(r, "Body", (CW, CD, CH), (chx, cy, 0.05 + CH * 0.5), m_body(gold), 0.06, 0.02)
        readout(r, chx, cy, CW, CD, 0.05 + CH, combo)
        main, base, lamp_y = cy + 0.42, cy - 0.2, cy - 0.31
        w, e = 0.03, 1.4
        x = chx + CW * 0.5
        for k in range(3):
            bx = ux + 0.42 + k * 0.6
            run(r, x, bx, main, w, 1, e)
            x = bx
            if k >= len(mods):
                cs.boxes(r, "Platz", cs.ring_items(bx, cy - 0.02, 0.52, 0.5, 0.49, 0.47, 0.054, 0.006),
                         m_dim())
                for s in (-1, 1):
                    dm.annulus(r, "FuehlerPlatz", bx + s * 0.11, lamp_y, 0.054, 0.04, 0.055, m_dim(), 24)
                continue
            kind, sensors, key = mods[k]
            on = TRUTH[kind]([lit for _, lit in sensors])
            tip = gate(r, kind, bx, base, key, on)
            offs = [0.0] if len(sensors) == 1 else [-0.11, 0.11]
            for (face, lit), o in zip(sensors, offs):
                lamp = dm.glow("weiss", 3.0) if lit else m_dim()
                dm.cyl(r, "Fuehler", 0.055, 0.03, (bx + o, lamp_y, 0.065), lamp, 24)
                cs.strips(r, "Eingang", [[(bx + o, lamp_y + 0.05), (bx + o, base + 0.02)]], 0.025,
                          0.053, lamp)
                txt(r, face, bx + o, lamp_y - 0.14, 0.054, 0.1, "weiss", 2.0 if lit else 0.5, "CENTER")
            out = dm.glow(key, 3.0) if on else m_dim()
            cs.strips(r, "Ausgang", [[(bx, base + tip), (bx, main)]], 0.04 if on else 0.02, 0.054, out)
            txt(r, KINDS[key][0], bx + 0.07, (base + tip + main) * 0.5 - 0.02, 0.054, 0.085, key,
                2.4 if on else 0.6)
            if on:
                w = w + 0.03 if key == "punkte" else w * 1.9
                e += 0.9
        run(r, x, ux + uw * 0.5 + 0.02, main, w, 1, e)
    rails(r, [0.0, 3.825], pitch + 0.9, -pitch - 0.9)
    return "L · RACK — zwei Spalten statt drei: gleiche Fläche, großer Chip und drei große Gatter-Plätze", pitch


# --- Runde 5: alle 26 MODULE als Bauteile auf der Leitung (Plan docs/plan_modul_bauteile.md) ----

for _k, _v in {"wuerfel": "#50fa7b", "roehre": "#bf59ff", "geld": "#9ccf6a", "link": "#ff73d9",
               "energie": "#8be9fd", "rot": "#ff5555", "kopplung": "#c7f0ff", "w0": "#ffffff",
               "w1": "#ffe14d", "w2": "#ff9a2e", "w3": "#ff4530", "hell": "#f2f2ff"}.items():
    dm.HEX[_k] = _v
G = dm.glow


def dark():
    return led.mat("Dunkelteil", (0.03, 0.03, 0.045), 0.6, 0.4)


def cer():
    return led.mat("Keramik2", (0.5, 0.42, 0.3), 0.0, 0.5)


def alu():
    return led.mat("Alu", (0.55, 0.57, 0.62), 1.0, 0.35)


def ycyl(o):
    o.rotation_euler = (math.radians(90), 0, 0)
    return o


def ball(r, rad, loc, material, squash=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=rad, location=loc)
    o = bpy.context.active_object
    o.scale = (1, 1, squash)
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    o.parent = r
    return o


def cone(r, r1, r2, depth, loc, material):
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=r1, radius2=r2, depth=depth, location=loc)
    o = bpy.context.active_object
    o.rotation_euler = (0, math.radians(90), 0)
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    o.parent = r
    return o


def rings(r, x, y, z, n, rad, key=None, step=0.045):
    for i in range(n):
        lying(dm.cyl(r, "Windung", rad, 0.03, (x + i * step, y, z), G(key, 2.2) if key else copper(),
                     32))


def b_widerstand(r, x, y, z, k):
    lying(dm.cyl(r, "Koerper", 0.085, 0.34, (x, y, z + 0.1), cer(), 48))
    for i in (-1, 0, 1):
        lying(dm.cyl(r, "Ring", 0.09, 0.035, (x + i * 0.085, y, z + 0.1), G(k, 3.0), 48))


def b_spule(r, x, y, z, k):
    lying(dm.cyl(r, "Kern", 0.05, 0.46, (x, y, z + 0.11), dark(), 24))
    rings(r, x - 0.144, y, z + 0.11, 7, 0.1, "mult", 0.048)
    for s in (-1, 1):
        lying(dm.cyl(r, "Kappe", 0.062, 0.03, (x + s * 0.23, y, z + 0.11), G("punkte", 3.0), 24))


def die_row(r, x, y, z, k, lit, count=5):
    """Die Würfel der Kombination als Punktreihe: leuchtend, wen das Modul meint."""
    for i in range(count):
        px = x + (i - (count - 1) * 0.5) * 0.09
        dm.cyl(r, "Wuerfelpunkt", 0.028, 0.012, (px, y - 0.31, z + 0.006),
               G(k, 3.5) if i in lit else m_dim(), 16)
        if i in lit:
            cs.strips(r, "Zuruf", [[(px, y - 0.27), (px, y - 0.06)], arrow((px, y - 0.06), (0, 1), 0.04)],
                      0.022, z + 0.004, G(k, 3.0))


def b_vorwiderstand(r, x, y, z, k):
    cs.boxes(r, "Schiene", [(x, y + 0.15, z + 0.04, 0.52, 0.045, 0.07)], cs.m_steel())
    cs.boxes(r, "SchienenLicht", [(x, y + 0.15, z + 0.078, 0.5, 0.02, 0.006)], G(k, 3.0))
    for i in range(6):
        px = x + (i - 2.5) * 0.085
        ycyl(dm.cyl(r, "Zinken", 0.033, 0.26, (px, y, z + 0.06), cer(), 16))
        for o in (-0.05, 0.03):
            ycyl(dm.cyl(r, "Band", 0.036, 0.04, (px, y + o, z + 0.06), G(k, 3.0), 16))


def b_reihenklemme(r, x, y, z, k):
    led.rounded_box(r, "Klemme", (0.48, 0.26, 0.12), (x, y, z + 0.06),
                    led.mat("Klemme", (0.1, 0.12, 0.15), 0.0, 0.5), 0.03, 0.01)
    for i in (-1, 0, 1):
        px = x + i * 0.15
        dm.cyl(r, "Schraube", 0.05, 0.03, (px, y, z + 0.13), cs.m_steel(), 24)
        cs.boxes(r, "Schlitz", [(px, y, z + 0.147, 0.07, 0.014, 0.004)], dark())
        dm.annulus(r, "Licht", px, y, z + 0.123, 0.056, 0.075, G(k, 3.0) if i < 1 else m_dim(), 24)


def b_kondensator(r, x, y, z, k):
    dm.cyl(r, "Becher", 0.15, 0.2, (x, y, z + 0.1), dark(), 64)
    dm.cyl(r, "Deckel", 0.115, 0.012, (x, y, z + 0.205), G(k, 3.0), 64)
    cs.boxes(r, "Kerbe", [(x, y, z + 0.213, 0.2, 0.022, 0.006), (x, y, z + 0.213, 0.022, 0.2, 0.006)],
             dark())


def b_loetpunkt(r, x, y, z, k):
    cs.boxes(r, "Leiste", [(x, y, z + 0.02, 0.54, 0.18, 0.04)], cs.m_gold())
    for i in range(6):
        px = x + (i - 2.5) * 0.086
        on = i in (1, 4)
        ball(r, 0.05, (px, y, z + 0.045), G(k, 3.5) if on else cs.m_steel(), 0.75)
        dm.annulus(r, "Auge", px, y, z + 0.042, 0.052, 0.064, G(k, 2.0) if on else dark(), 24)


def b_thermistor(r, x, y, z, k):
    dm.cyl(r, "Scheibe", 0.13, 0.04, (x, y, z + 0.09), dark(), 48)
    for s in (-1, 1):
        dm.cyl(r, "Bein", 0.012, 0.08, (x + s * 0.06, y, z + 0.04), cs.m_steel(), 8)
    for i in range(4):
        cs.strips(r, "Glut", [arc(x, y, 0.155, 0.155, 135 - i * 90, 135 - i * 90 - 84)], 0.04, z + 0.112,
                  G("w%d" % i, 3.0))


def b_zaehlwerk(r, x, y, z, k):
    led.rounded_box(r, "Gehaeuse", (0.48, 0.26, 0.1), (x, y, z + 0.05),
                    led.mat("Gehaeuse", (0.06, 0.06, 0.08), 0.6, 0.4), 0.03, 0.01)
    for i, digit in enumerate("007"):
        px = x + (i - 1) * 0.13
        lying(dm.cyl(r, "Rolle", 0.085, 0.11, (px, y, z + 0.07), dark(), 32))
        txt(r, digit, px, y, z + 0.157, 0.13, k, 3.0, "CENTER")


def b_fehlerspeicher(r, x, y, z, k):
    cs.boxes(r, "Baustein", [(x, y + 0.05, z + 0.05, 0.44, 0.2, 0.08)], dark())
    cs.boxes(r, "Beine", [(x + (i - 2.5) * 0.07, y + 0.05 + s * 0.115, z + 0.02, 0.03, 0.04, 0.03)
                          for i in range(6) for s in (-1, 1)], cs.m_steel())
    dm.cyl(r, "Fenster", 0.055, 0.01, (x - 0.1, y + 0.05, z + 0.093), clear("roehre", 0.5, 0.8), 32)
    for i in range(5):
        dm.cyl(r, "Lampe", 0.026, 0.02, (x + (i - 2) * 0.09, y - 0.15, z + 0.02),
               G("rot", 3.5) if i < 2 else m_dim(), 16)


def b_anlasser(r, x, y, z, k):
    dm.cyl(r, "Kragen", 0.18, 0.05, (x, y, z + 0.025), cs.m_steel(), 48)
    dm.cyl(r, "Knopf", 0.12, 0.09, (x, y, z + 0.07), dark(), 48)
    dm.annulus(r, "Ring", x, y, z + 0.052, 0.128, 0.17, G(k, 3.0), 48)
    cs.strips(r, "Zeichen", [arc(x, y, 0.06, 0.06, 120, 420, 20), [(x, y + 0.025), (x, y + 0.09)]],
              0.02, z + 0.117, G(k, 3.0))


def loop_at(r, x, y, z, k, side):
    a, b = x + side * 0.1, x + side * 0.25
    cs.strips(r, "Schleife", [[(a, y), (a, y - 0.15), (b, y - 0.15), (b, y)],
                              arrow((b, y - 0.03), (0, 1), 0.05)], 0.028, z + 0.004, G(k, 3.0))


def b_relais(r, x, y, z, k):
    cs.boxes(r, "Sockel", [(x, y + 0.05, z + 0.02, 0.44, 0.24, 0.04)], cs.m_steel())
    lying(dm.cyl(r, "Spule", 0.08, 0.2, (x + 0.1, y + 0.05, z + 0.12), copper(), 24))
    cs.strips(r, "Zunge", [[(x + 0.18, y + 0.14), (x - 0.18, y + 0.02)]], 0.045, z + 0.21, G(k, 1.8))
    dm.cyl(r, "Kontakt", 0.045, 0.06, (x - 0.17, y + 0.02, z + 0.07), G(k, 3.5), 16)
    die_row(r, x, y, z, k, (0,))


def b_endstufe(r, x, y, z, k):
    cs.boxes(r, "Rippen", [(x + (i - 3) * 0.075, y + 0.05, z + 0.05, 0.03, 0.3, 0.1) for i in range(7)],
             alu())
    cs.boxes(r, "Blech", [(x, y + 0.05, z + 0.012, 0.5, 0.3, 0.024)], alu())
    led.rounded_box(r, "Transistor", (0.3, 0.19, 0.08), (x, y + 0.05, z + 0.14), cs.m_steel(), 0.09,
                    0.02)
    dm.cyl(r, "Auge", 0.04, 0.012, (x, y + 0.05, z + 0.184), G(k, 3.5), 24)
    die_row(r, x, y, z, k, (4,))


def b_nebenschluss(r, x, y, z, k):
    cs.boxes(r, "Schiene", [(x - 0.22, y + 0.1, z + 0.04, 0.07, 0.27, 0.07),
                            (x + 0.22, y + 0.1, z + 0.04, 0.07, 0.27, 0.07),
                            (x, y + 0.2, z + 0.04, 0.51, 0.07, 0.07)], copper())
    cs.boxes(r, "Abgriff", [(x + s * 0.09, y + 0.2, z + 0.078, 0.055, 0.055, 0.006) for s in (-1, 1)],
             G(k, 3.5))


def b_parallel(r, x, y, z, k):
    cs.boxes(r, "Schienen", [(x, y + s * 0.09, z + 0.03, 0.44, 0.045, 0.05) for s in (-1, 1)],
             cs.m_steel())
    cs.boxes(r, "Sprossen", [(x + (i - 2) * 0.09, y, z + 0.03, 0.025, 0.18, 0.03) for i in range(5)],
             cs.m_steel())
    lines = [[(x - 0.22, y + s * 0.09), (x + 0.22, y + s * 0.09)] for s in (-1, 1)]
    cs.strips(r, "Doppel", lines, 0.022, z + 0.057, G(k, 3.0))
    cs.strips(r, "Weiche", [[(x + e * 0.3, y), (x + e * 0.22, y + s * 0.09)] for e in (-1, 1)
                            for s in (-1, 1)], 0.03, z + 0.004, G(k, 2.5))


def b_verstaerker(r, x, y, z, k):
    lying(dm.cyl(r, "Glas", 0.08, 0.3, (x, y, z + 0.1), clear("roehre", 0.3, 0.3), 32))
    lying(dm.cyl(r, "Gitter", 0.035, 0.2, (x, y, z + 0.1), G(k, 3.5), 16))
    for s in (-1, 1):
        lying(dm.cyl(r, "Kappe", 0.085, 0.04, (x + s * 0.16, y, z + 0.1), cs.m_steel(), 32))


def b_hochspannung(r, x, y, z, k):
    lying(dm.cyl(r, "Glas", 0.12, 0.36, (x - 0.02, y, z + 0.14), clear("roehre", 0.3, 0.3), 48))
    lying(dm.cyl(r, "Glut", 0.05, 0.26, (x - 0.02, y, z + 0.14), G(k, 4.0), 24))
    lying(dm.cyl(r, "Fuss", 0.125, 0.05, (x - 0.22, y, z + 0.14), cs.m_steel(), 48))
    ball(r, 0.07, (x + 0.2, y, z + 0.14), cs.m_steel())
    lying(dm.cyl(r, "Korona", 0.17, 0.02, (x + 0.07, y, z + 0.14), G(k, 3.0), 48))


def b_magnetron(r, x, y, z, k):
    dm.cyl(r, "Anode", 0.16, 0.12, (x, y, z + 0.06), copper(), 64)
    slots = []
    for i in range(8):
        c, s = math.cos(math.tau * i / 8), math.sin(math.tau * i / 8)
        slots.append([(x + c * 0.055, y + s * 0.055), (x + c * 0.125, y + s * 0.125)])
    cs.strips(r, "Rosette", slots, 0.03, z + 0.122, led.mat("Schlitz", (0, 0, 0), 0.0, 0.8))
    dm.cyl(r, "Kathode", 0.04, 0.012, (x, y, z + 0.124), G(k, 4.0), 24)
    cs.boxes(r, "Magnete", [(x + s * 0.215, y, z + 0.07, 0.07, 0.3, 0.14) for s in (-1, 1)],
             cs.m_steel())
    dm.annulus(r, "Welle", x, y, z + 0.004, 0.2, 0.215, G(k, 2.5), 48)


def b_schwingkreis(r, x, y, z, k):
    rings(r, x - 0.16, y, z + 0.08, 4, 0.07, None, 0.04)
    dm.cyl(r, "Becher", 0.07, 0.14, (x + 0.11, y, z + 0.07), dark(), 32)
    dm.cyl(r, "Deckel", 0.05, 0.01, (x + 0.11, y, z + 0.143), G(k, 3.0), 32)
    cs.strips(r, "Ring", [arc(x, y, 0.26, 0.19, 0, 360, 40)], 0.025, z + 0.004, m_dim())
    cs.strips(r, "Stand", [arc(x, y, 0.26, 0.19, 90, -70, 20)], 0.03, z + 0.006, G(k, 3.5))


def b_nachbrenner(r, x, y, z, k):
    hell = led.mat("Duese3", (0.62, 0.64, 0.7), 0.3, 0.45)
    lying(dm.cyl(r, "Brennkammer", 0.1, 0.18, (x - 0.19, y, z + 0.14), hell, 32))
    cone(r, 0.1, 0.16, 0.14, (x - 0.05, y, z + 0.14), hell)
    for px in (-0.27, -0.19, -0.11):
        lying(dm.cyl(r, "Reif", 0.106, 0.022, (x + px, y, z + 0.14), dark(), 32))
    lying(dm.cyl(r, "Muendung", 0.165, 0.025, (x + 0.02, y, z + 0.14), G("w2", 3.5), 32))
    dm.cyl(r, "Scharf", 0.03, 0.02, (x - 0.19, y, z + 0.245), G("rot", 4.0), 16)
    at = x + 0.03
    for rad, half in ((0.12, 0.08), (0.085, 0.06), (0.055, 0.045)):
        cone(r, 0.025, rad, half, (at + half * 0.5, y, z + 0.14), G(k, 4.0))
        cone(r, rad, 0.025, half, (at + half * 1.5, y, z + 0.14), G(k, 4.0))
        at += half * 2
    cone(r, 0.07, 0.0, 0.2, (x + 0.13, y, z + 0.14), G("w0", 5.0))


def b_muenzpruefer(r, x, y, z, k):
    led.rounded_box(r, "Pruefer", (0.34, 0.34, 0.1), (x, y, z + 0.05), cs.m_steel(), 0.04, 0.01)
    cs.boxes(r, "Schlitz", [(x, y + 0.07, z + 0.102, 0.24, 0.04, 0.004)], dark())
    dm.cyl(r, "Muenze", 0.095, 0.02, (x + 0.02, y - 0.03, z + 0.113), cs.m_gold(), 32)
    txt(r, "$", x + 0.02, y - 0.03, z + 0.125, 0.12, k, 3.0, "CENTER")


def b_stromabnehmer(r, x, y, z, k):
    cs.boxes(r, "Fuss", [(x, y - 0.24, z + 0.04, 0.3, 0.1, 0.08)], cs.m_steel())
    dm.cyl(r, "Speicher", 0.07, 0.1, (x, y - 0.24, z + 0.09), G(k, 3.0), 24)
    arms = [[(x + s * 0.1, y - 0.22), (x + s * 0.21, y - 0.11), (x + s * 0.08, y)] for s in (-1, 1)]
    cs.strips(r, "Schere", arms, 0.04, z + 0.1, alu())
    cs.boxes(r, "Schleifer", [(x, y, z + 0.06, 0.34, 0.07, 0.06)], copper())
    cs.boxes(r, "SchleiferLicht", [(x, y, z + 0.093, 0.3, 0.025, 0.006)], G(k, 3.5))
    for s in (-1, 1):
        cs.strips(r, "Funke", [[(x + s * 0.18, y + 0.03), (x + s * 0.23, y + 0.1),
                                (x + s * 0.2, y + 0.04), (x + s * 0.28, y + 0.11)]], 0.025, z + 0.1,
                  G(k, 4.0))


def bridge(r, x, y, z, k, dx, dy):
    dm.cyl(r, "Pfosten", 0.07, 0.1, (x, y, z + 0.05), cs.m_steel(), 24)
    cs.boxes(r, "Band", [(x + dx * 0.27, y + dy * 0.27, z + 0.1, 0.54 if dx else 0.09,
                          0.54 if dy else 0.09, 0.025)], dark())
    tip = (x + dx * 0.62, y + dy * 0.62)
    cs.strips(r, "Pfeil", [[(x, y), tip], arrow(tip, (dx, dy), 0.08)], 0.035, z + 0.116, G(k, 3.5))


def b_querbruecke(r, x, y, z, k):
    bridge(r, x, y, z, k, 1, 0)


def b_laengsbruecke(r, x, y, z, k):
    bridge(r, x, y, z, k, 0, -1)


def b_kopplung(r, x, y, z, k):
    # Hologramm-Feld: das Band holt vom linken Chip, darüber steht dessen stärkstes Modul als Abbild
    # (hier: der Kondensator).
    cs.strips(r, "Band", [[(x - 0.56, y), (x - 0.2, y)]], 0.06, z + 0.03, G(k, 1.6))
    cs.strips(r, "Richtung", [arrow((x - 0.44 + i * 0.11, y), (1, 0), 0.055) for i in range(3)], 0.02,
              z + 0.034, dark())
    cs.boxes(r, "Feld", [(x + 0.03, y, z + 0.006, 0.42, 0.36, 0.012)], dark())
    ecken = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = x + 0.03 + sx * 0.2, y + sy * 0.17
            ecken.append([(cx - sx * 0.09, cy), (cx, cy), (cx, cy - sy * 0.09)])
    cs.strips(r, "Ecken", ecken, 0.025, z + 0.014, G(k, 3.0))
    geist = led.mat("Geist", dm.col("mult"), 0.0, 0.2, 0.9, 0.28)
    dm.cyl(r, "AbbildBecher", 0.14, 0.2, (x + 0.03, y, z + 0.16), geist, 48)
    dm.cyl(r, "AbbildDeckel", 0.105, 0.01, (x + 0.03, y, z + 0.265), led.mat("GeistHell",
                                                                             dm.col("mult"), 0.0, 0.2,
                                                                             2.2, 0.6), 48)
    cs.boxes(r, "AbbildKerbe", [(x + 0.03, y, z + 0.272, 0.19, 0.02, 0.004),
                                (x + 0.03, y, z + 0.272, 0.02, 0.19, 0.004)], dark())
    for i in range(4):
        dm.annulus(r, "Abtastung", x + 0.03, y, z + 0.08 + i * 0.05, 0.142, 0.15, G(k, 2.2), 48)


def b_sperrdiode(r, x, y, z, k):
    lying(dm.cyl(r, "Diode", 0.08, 0.3, (x, y + 0.07, z + 0.09), dark(), 32))
    lying(dm.cyl(r, "Ring", 0.083, 0.04, (x + 0.1, y + 0.07, z + 0.09), cs.m_steel(), 32))
    poly_prism(r, "Dreieck", [(x - 0.08, y - 0.1), (x - 0.08, y - 0.24), (x + 0.04, y - 0.17)], z,
               z + 0.01, G(k, 2.5))
    cs.strips(r, "Strich", [[(x + 0.05, y - 0.1), (x + 0.05, y - 0.24)]], 0.022, z + 0.01, G(k, 2.5))
    cs.strips(r, "Draht", [[(x - 0.18, y - 0.17), (x + 0.16, y - 0.17)]], 0.012, z + 0.004, G(k, 2.0))


def b_platine(r, x, y, z, k):
    led.rounded_box(r, "Tochter", (0.56, 0.5, 0.03), (x, y, z + 0.015),
                    led.mat("Tochter", (0.02, 0.07, 0.055), 0.0, 0.5, clearcoat=0.4), 0.03, 0.0)
    cs.boxes(r, "Kontakte", [(x + (i - 3.5) * 0.06, y - 0.22, z + 0.032, 0.035, 0.05, 0.004)
                             for i in range(8)], cs.m_gold())
    for s in (-1, 1):
        cs.boxes(r, "Halbplatz", [(x + s * 0.135, y + 0.03, z + 0.032, 0.2, 0.3, 0.004)], m_pocket())
        cs.boxes(r, "HalbRand", cs.ring_items(x + s * 0.135, y + 0.03, 0.23, 0.33, 0.2, 0.3, z + 0.036,
                                              0.012), cs.m_steel())


# (Name, Farbe, Kurzwirkung, Bauteil, Leitung danach)
MODULES = [
    ("Widerstand", "punkte", "+15 Punkte", b_widerstand, "dick"),
    ("Spule", "punkte", "+8 Punkte, +1 Mult", b_spule, "dick"),
    ("Vorwiderstand", "punkte", "+4 je Würfel", b_vorwiderstand, "dick"),
    ("Reihenklemme", "kopplung", "+5 +1 je Modul", b_reihenklemme, "dick"),
    ("Münzprüfer", "geld", "+$2", b_muenzpruefer, "gleich"),
    ("Stromabnehmer", "energie", "+1 Energie", b_stromabnehmer, "gleich"),
    None,
    ("Kondensator", "mult", "+3 Mult", b_kondensator, "hell"),
    ("Lötpunkt", "mult", "+1 Mult je Würfel", b_loetpunkt, "hell"),
    ("Thermistor", "mult", "+2 Mult je Ladung", b_thermistor, "hell"),
    ("Zählwerk", "mult", "+1 Mult, wächst", b_zaehlwerk, "hell"),
    ("Fehlerspeicher", "mult", "+1 Mult je Fumble", b_fehlerspeicher, "hell"),
    ("Anlasser", "mult", "+6 Mult, 1. Hand", b_anlasser, "hell"),
    None,
    ("Relais", "wuerfel", "1. Würfel nochmal", b_relais, "doppelt"),
    ("Endstufe", "wuerfel", "letzter nochmal", b_endstufe, "doppelt"),
    ("Nebenschluss", "wuerfel", "auch Würfel außerhalb", b_nebenschluss, "dick"),
    ("Parallelschaltung", "wuerfel", "jeder nochmal", b_parallel, "doppelt"),
    ("Querbrücke", "link", "auch rechts", b_querbruecke, "gleich"),
    ("Längsbrücke", "link", "auch darunter", b_laengsbruecke, "gleich"),
    ("Kopplung", "kopplung", "kopiert links", b_kopplung, "dick"),
    ("Verstärkerröhre", "roehre", "×1,5 Mult", b_verstaerker, "stark"),
    ("Hochspannungsröhre", "roehre", "×2 Mult", b_hochspannung, "stark"),
    ("Magnetron", "roehre", "×3 Mult, lädt", b_magnetron, "stark"),
    ("Schwingkreis", "roehre", "×1,1 Mult, wächst", b_schwingkreis, "stark"),
    ("Nachbrenner", "roehre", "×2 nach Fumble", b_nachbrenner, "stark"),
    ("Sperrdiode", "hell", "keine Drossel", b_sperrdiode, "gleich"),
    ("Erweiterungsplatine", "hell", "1 Platz wird 2", b_platine, "gleich"),
]
OUT_LINE = {"gleich": (0.03, 1, 1.4), "dick": (0.06, 1, 2.2), "hell": (0.045, 1, 3.2),
            "doppelt": (0.03, 2, 2.4), "stark": (0.085, 1, 3.4)}


def sheet(mods, title):
    r = cs.root("Bauteile")
    for i, mod in enumerate(mods):
        if mod is None:
            continue
        name, key, effect, build, style = mod
        x, y = (i % 7 - 3) * 1.08, 0.85 - (i // 7) * 1.5
        cs.boxes(r, "Platz", [(x, y, 0.01, 0.62, 0.9, 0.02)], m_pcb())
        cs.boxes(r, "PlatzRand", cs.ring_items(x, y, 0.66, 0.94, 0.62, 0.9, 0.012, 0.024), m_dim())
        run(r, x - 0.54, x + 0.3, y, 0.03, 1, 1.4, "punkte", 0.022)
        w, n, e = OUT_LINE[style]
        run(r, x + 0.28, x + 0.54, y, w, n, e, "punkte", 0.023)
        build(r, x, y, 0.02, key)
        txt(r, name, x, y - 0.6, 0.002, 0.095 if len(name) < 15 else 0.08, "hell", 1.6, "CENTER")
        txt(r, effect, x, y - 0.75, 0.002, 0.075, key, 2.2, "CENTER")
    return title, 1.25


def bauteile_oben():
    return sheet(MODULES[:14], "M · BAUTEILE 1 von 2 — jedes Modul auf seiner Leitung, Platz 0,6 × 0,9")


def bauteile_unten():
    return sheet(MODULES[14:], "M · BAUTEILE 2 von 2 — jedes Modul auf seiner Leitung, Platz 0,6 × 0,9")


REWORK = ("Vorwiderstand", "Lötpunkt", "Relais", "Endstufe", "Stromabnehmer", "Kopplung", "Nachbrenner")


def bauteile_neu():
    mods = [m for name in REWORK for m in MODULES if m is not None and m[0] == name]
    return sheet(mods, "N · ÜBERARBEITET — die sieben schwachen Bauteile, neu")


# --- Runde 6: das ganze RACK mit allen zwölf Kombinationen und allen 26 Modulen -----------------

RACK = [("Sechserpasch", "60", "×15", [], False),
        ("5 of a Kind", "50", "×10", ["Hochspannungsröhre"], False),
        ("Große Straße", "45", "×8", ["Widerstand", "Kondensator", "Relais"], False),
        ("Viererpasch mit Paar", "40", "×6", ["Zählwerk", "Verstärkerröhre"], True),
        ("Doppelter Dreierpasch", "36", "×5", ["Vorwiderstand", "Lötpunkt", "Querbrücke"], False),
        ("Drei Zweierpäsche", "32", "×5", ["Münzprüfer"], False),
        ("Viererpasch", "25", "×4", ["Spule", "Thermistor", "Längsbrücke"], False),
        ("Full House", "28", "×4", ["Endstufe", "Magnetron", "Stromabnehmer"], False),
        ("Kleine Straße", "22", "×4", ["Anlasser", "Fehlerspeicher"], False),
        ("Dreierpasch", "18", "×3", ["Kopplung", "Parallelschaltung", "Nachbrenner"], False),
        ("Zwei Paare", "15", "×3", ["Reihenklemme", "Sperrdiode"], False),
        ("Paar", "10", "×2", ["Nebenschluss", "Schwingkreis", "Sperrdiode"], False)]


def rack_bauteile():
    r = cs.root("RackBauteile")
    pitch, uw = 1.13, 3.78
    by_name = {m[0]: m for m in MODULES if m is not None}
    for i, combo in enumerate(RACK):
        ux, cy = (i % 2 - 0.5) * 3.825, (2.5 - i // 2) * pitch
        gold = combo[4]
        led.rounded_box(r, "Einschub", (uw, 1.07, 0.05), (ux, cy, 0.025), m_pcb(), 0.05, 0.01)
        if gold:
            cs.boxes(r, "GoldSaum", cs.ring_items(ux, cy, uw + 0.06, 1.13, uw, 1.07, 0.03, 0.06),
                     G("mult", 3.0))
        chx = ux - 0.92
        led.rounded_box(r, "Body", (CW, CD, CH), (chx, cy, 0.05 + CH * 0.5), m_body(gold), 0.06, 0.02)
        readout(r, chx, cy, CW, CD, 0.05 + CH, combo)
        w, n, e = 0.03, 1, 1.4
        x = chx + CW * 0.5
        for k in range(3):
            bx = ux + 0.42 + k * 0.6
            cs.boxes(r, "Platz", cs.ring_items(bx, cy, 0.56, 0.96, 0.54, 0.94, 0.054, 0.006), m_dim())
            run(r, x, bx + 0.26, cy, w, n, e, "punkte", 0.053)
            x = bx + 0.26
            if k >= len(combo[3]):
                continue
            name, key, effect, build, style = by_name[combo[3][k]]
            build(r, bx, cy, 0.05, key)
            short = effect.split(",")[0]
            txt(r, short if len(short) < 15 else short[:14], bx, cy - 0.43, 0.054, 0.062, key, 2.2,
                "CENTER")
            sw, sn, se = OUT_LINE[style]
            w, n, e = max(w, sw), max(n, sn), max(e, se)
        run(r, x, ux + uw * 0.5 + 0.02, cy, w, n, e, "punkte", 0.053)
    rails(r, [0.0, 3.825], 3.6, -3.6)
    ms.label("O · RACK mit BAUTEILEN — zwölf Kombinationen, alle 26 Module je einmal", 0.0, -3.85, 0.2)
    return "", pitch


# --- Runde 7: der GROSSE CHIP - die Module stecken wieder IM Chip --------------------------------

def placed(r, build, key, x, y, z, scale):
    """Ein Modul um seinen Fußpunkt skaliert setzen."""
    e = cs.root("Modul")
    build(e, 0.0, 0.0, 0.0, key)
    e.location = (x, y, z)
    e.scale = (scale, scale, scale)
    e.parent = r


def grosschip():
    r = cs.root("Grosschip")
    pitch, cw, cd, scale = 1.13, 3.62, 1.03, 1.15
    by_name = {m[0]: m for m in MODULES if m is not None}
    top = 0.03 + CH
    for i, (name, pts, mult, mods, gold) in enumerate(RACK):
        ux, cy = (i % 2 - 0.5) * 3.825, (2.5 - i // 2) * pitch
        led.rounded_box(r, "Body", (cw, cd, CH), (ux, cy, 0.03 + CH * 0.5), m_body(gold), 0.07, 0.02)
        cs.boxes(r, "Pins", [(ux + s * (cw * 0.5 + 0.04), cy + k * 0.3, 0.12, 0.08, 0.2, 0.1)
                             for s in (-1, 1) for k in (-1, 0, 1)],
                 G("mult", 1.2) if gold else cs.m_steel())
        # Anzeige links: Name und Wertung so groß, wie der Deckel es hergibt
        gx = ux - 1.0
        led.rounded_box(r, "Glas", (1.5, cd - 0.16, 0.012), (gx, cy, top), m_glass(), 0.04, 0.0)
        x0, z = gx - 0.66, top + 0.008
        if len(name) > 13:
            a, b = name.split(" ", 1)
            txt(r, a, x0, cy + 0.3, z, 0.19, "name")
            txt(r, b, x0, cy + 0.07, z, 0.19, "name")
            vy = cy - 0.26
        else:
            txt(r, name, x0, cy + 0.22, z, 0.22, "name")
            vy = cy - 0.2
        txt(r, pts, x0, vy, z, 0.32, "punkte")
        txt(r, mult, x0 + 0.2 * len(pts) + 0.14, vy, z, 0.32, "mult")
        # drei Buchsen im Deckel, die Leitung läuft durch sie
        w, n, e = 0.03, 1, 1.4
        x = gx + 0.75
        for k in range(3):
            bx = ux + 0.28 + k * 0.6
            cs.boxes(r, "Buchse", [(bx, cy, top + 0.003, 0.56, 0.9, 0.006)], m_pocket())
            cs.boxes(r, "BuchsenRand", cs.ring_items(bx, cy, 0.59, 0.93, 0.56, 0.9, top + 0.008, 0.016),
                     G("mult", 1.6) if gold else cs.m_steel())
            for sx in (-1, 1):
                for sy in (-1, 1):
                    dm.cyl(r, "Schraube", 0.018, 0.01, (bx + sx * 0.25, cy + sy * 0.42, top + 0.01),
                           cs.m_steel(), 12)
            run(r, x, bx + 0.28, cy, w, n, e, "punkte", top + 0.008)
            x = bx + 0.28
            if k >= len(mods):
                continue
            mname, key, effect, build, style = by_name[mods[k]]
            placed(r, build, key, bx, cy, top + 0.006, scale)
            short = effect.split(",")[0]
            txt(r, short if len(short) < 15 else short[:14], bx, cy - 0.405, top + 0.008, 0.062, key,
                2.2, "CENTER")
            sw, sn, se = OUT_LINE[style]
            w, n, e = max(w, sw), max(n, sn), max(e, se)
        run(r, x, ux + cw * 0.5, cy, w, n, e, "punkte", top + 0.008)
        band(r, ux, cy - cd * 0.5 - 0.025, 0.2, cw - 0.3, "mult" if gold else "band")
    rails(r, [-3.825, 0.0, 3.825], 3.6, -3.6)
    ms.label("P · GROSSER CHIP — der Chip füllt den ganzen Einschub, die Module stecken im Deckel", 0.0,
             -3.72, 0.17)
    return "", pitch


# --- Runde 8: drei PLATTFORMEN für die Module im Deckel -----------------------------------------

SW, SD = 0.56, 0.9


def sock_sockel(r, bx, cy, top, key, gold):
    """1 · SOCKEL: erhabener Stahlrahmen, goldenes Kontaktfeld, Keramikträger unter dem Modul."""
    cs.boxes(r, "Boden", [(bx, cy, top + 0.003, SW - 0.04, SD - 0.04, 0.006)], m_pocket())
    cs.boxes(r, "Kontakte", [(bx + (a - 2.5) * 0.08, cy + (b - 4.5) * 0.08, top + 0.008, 0.035, 0.035,
                              0.004) for a in range(6) for b in range(10)], cs.m_gold())
    cs.boxes(r, "Rahmen", cs.ring_items(bx, cy, SW + 0.03, SD + 0.03, SW - 0.05, SD - 0.05, top + 0.022,
                                        0.044), G("mult", 1.6) if gold else cs.m_steel())
    cs.boxes(r, "Hebel", [(bx, cy + SD * 0.5 - 0.005, top + 0.055, SW - 0.12, 0.03, 0.03)], alu())
    dm.cyl(r, "HebelKnopf", 0.028, 0.05, (bx + SW * 0.5 - 0.08, cy + SD * 0.5 - 0.005, top + 0.065),
           G(key, 3.0) if key else m_dim(), 16)
    if key:
        led.rounded_box(r, "Traeger", (SW - 0.1, 0.56, 0.022), (bx, cy, top + 0.021), cs.m_ceramic(),
                        0.03, 0.004)
    return top + 0.032


def sock_wanne(r, bx, cy, top, key, gold):
    """2 · LICHTWANNE: achteckige Glaswanne, ihr Rand leuchtet in der Farbe des Moduls."""
    hw, hd, c = SW * 0.5 - 0.01, SD * 0.5 - 0.01, 0.09
    pts = [(bx - hw + c, cy - hd), (bx + hw - c, cy - hd), (bx + hw, cy - hd + c), (bx + hw, cy + hd - c),
           (bx + hw - c, cy + hd), (bx - hw + c, cy + hd), (bx - hw, cy + hd - c), (bx - hw, cy - hd + c)]
    poly_prism(r, "Wanne", pts, top + 0.001, top + 0.006, m_glass())
    cs.strips(r, "Raster", [[(bx - hw + 0.04, cy + o), (bx + hw - 0.04, cy + o)]
                            for o in (-0.3, -0.15, 0.15, 0.3)], 0.006, top + 0.007, m_dim())
    rim = G(key, 3.0) if key else (G("mult", 1.2) if gold else m_dim())
    cs.strips(r, "Rand", [pts + [pts[0]]], 0.03 if key else 0.018, top + 0.009, rim)
    return top + 0.008


def sock_klemme(r, bx, cy, top, key, gold):
    """3 · KLEMMEN: kein Rahmen - das Modul klemmt mit zwei Backen auf der Leitung, darunter eine Platte."""
    jaw = G("mult", 1.6) if gold else cs.m_steel()
    cs.boxes(r, "Backen", [(bx + s * 0.25, cy, top + 0.04, 0.045, 0.2, 0.08) for s in (-1, 1)], jaw)
    cs.boxes(r, "BackenLicht", [(bx + s * 0.25, cy, top + 0.082, 0.03, 0.16, 0.006) for s in (-1, 1)],
             G(key, 3.0) if key else m_dim())
    if key:
        led.rounded_box(r, "Platte", (0.44, 0.6, 0.026), (bx, cy, top + 0.013), alu(), 0.09, 0.006)
        cs.boxes(r, "PlattenLicht", [(bx, cy - 0.285, top + 0.03, 0.26, 0.022, 0.008)], G(key, 3.0))
    else:
        pts = arc(bx, cy, 0.2, 0.28, 0, 360, 28)
        cs.strips(r, "Umriss", [pts], 0.012, top + 0.004, m_dim())
    return top + 0.03


def sock_kombi(r, bx, cy, top, key, gold):
    """Spieler-Wahl 2026-11-21: Kontaktfeld des SOCKELS, Platte der KLEMMEN - und die ganze Fassung
    ist genau so groß wie die Platte (0,44 x 0,6, runde Ecken)."""
    led.rounded_box(r, "Rahmen", (0.5, 0.66, 0.02), (bx, cy, top + 0.01),
                    G("mult", 1.6) if gold else cs.m_steel(), 0.11, 0.004)
    led.rounded_box(r, "Boden", (0.45, 0.61, 0.006), (bx, cy, top + 0.021), m_pocket(), 0.09, 0.0)
    cs.boxes(r, "Kontakte", [(bx + (a - 2) * 0.08, cy + (b - 3) * 0.08, top + 0.026, 0.035, 0.035,
                              0.004) for a in range(5) for b in range(7)
                             if not (a in (0, 4) and b in (0, 6))], cs.m_gold())
    if key:
        led.rounded_box(r, "Platte", (0.44, 0.6, 0.026), (bx, cy, top + 0.038),
                        led.mat("PlatteDunkel", (0.2, 0.21, 0.25), 0.6, 0.4), 0.09, 0.006)
        cs.boxes(r, "PlattenLicht", [(bx, cy - 0.285, top + 0.054, 0.26, 0.022, 0.008)], G(key, 3.0))
    return top + 0.053


SOCKETS = {"sockel": sock_sockel, "wanne": sock_wanne, "klemme": sock_klemme, "kombi": sock_kombi}


def rack_kombi():
    r = cs.root("RackKombi")
    for i, combo in enumerate(RACK):
        chip_big(r, (i % 2 - 0.5) * 3.825, (2.5 - i // 2) * 1.13, combo, "kombi")
    rails(r, [-3.825, 0.0, 3.825], 3.6, -3.6)
    ms.label("R · KONTAKTFELD + PLATTE — Boden des Sockels, Modulplatte der Klemmen", 0.0, -3.72, 0.17)
    return "", 1.13


def chip_big(r, ux, cy, combo, style):
    name, pts, mult, mods, gold = combo
    cw, cd, scale = 3.62, 1.03, 1.15
    by_name = {m[0]: m for m in MODULES if m is not None}
    top = 0.03 + CH
    led.rounded_box(r, "Body", (cw, cd, CH), (ux, cy, 0.03 + CH * 0.5), m_body(gold), 0.07, 0.02)
    cs.boxes(r, "Pins", [(ux + s * (cw * 0.5 + 0.04), cy + k * 0.3, 0.12, 0.08, 0.2, 0.1)
                         for s in (-1, 1) for k in (-1, 0, 1)], G("mult", 1.2) if gold else cs.m_steel())
    gx = ux - 1.0
    led.rounded_box(r, "Glas", (1.5, cd - 0.16, 0.012), (gx, cy, top), m_glass(), 0.04, 0.0)
    x0, z = gx - 0.66, top + 0.008
    if len(name) > 13:
        a, b = name.split(" ", 1)
        txt(r, a, x0, cy + 0.3, z, 0.19, "name")
        txt(r, b, x0, cy + 0.07, z, 0.19, "name")
        vy = cy - 0.26
    else:
        txt(r, name, x0, cy + 0.22, z, 0.22, "name")
        vy = cy - 0.2
    txt(r, pts, x0, vy, z, 0.32, "punkte")
    txt(r, mult, x0 + 0.2 * len(pts) + 0.14, vy, z, 0.32, "mult")
    w, n, e = 0.03, 1, 1.4
    x = gx + 0.75
    for k in range(3):
        bx = ux + 0.28 + k * 0.6
        mod = by_name[mods[k]] if k < len(mods) else None
        key = mod[1] if mod else None
        zm = SOCKETS[style](r, bx, cy, top, key, gold)
        zl = zm + 0.002 if (mod or style == "klemme") else top + 0.032
        if style == "klemme":
            cs.boxes(r, "Schiene", [((x + bx + 0.28) * 0.5, cy, top + 0.015, bx + 0.28 - x, 0.07, 0.03)],
                     cs.m_steel())
        run(r, x, bx + 0.28, cy, w, n, e, "punkte", zl)
        x = bx + 0.28
        if mod is None:
            continue
        placed(r, mod[3], key, bx, cy, zm, scale)
        txt(r, mod[2].split(",")[0][:14], bx, cy - 0.405, top + 0.012, 0.062, key, 2.2, "CENTER")
        sw, sn, se = OUT_LINE[mod[4]]
        w, n, e = max(w, sw), max(n, sn), max(e, se)
    run(r, x, ux + cw * 0.5, cy, w, n, e, "punkte", top + 0.012)
    band(r, ux, cy - cd * 0.5 - 0.025, 0.2, cw - 0.3, "mult" if gold else "band")


def plattformen():
    r = cs.root("Plattformen")
    full = ("Große Straße", "45", "×8", ["Widerstand", "Kondensator", "Relais"], False)
    part = ("Full House", "28", "×4", ["Magnetron"], False)
    titles = {"sockel": "1 · SOCKEL — Stahlrahmen, goldenes Kontaktfeld, Keramikträger",
              "wanne": "2 · LICHTWANNE — Glaswanne, der Rand leuchtet in der Farbe des Moduls",
              "klemme": "3 · KLEMMEN — kein Rahmen: das Modul klemmt auf der Leitung"}
    for i, style in enumerate(("sockel", "wanne", "klemme")):
        cy = (1 - i) * 1.75
        chip_big(r, -1.9125, cy, full, style)
        chip_big(r, 1.9125, cy, part, style)
        ms.label(titles[style], 0.0, cy + 0.72, 0.15)
    return "", 1.75


# --- Runde 9: EINZUG - in der Runde fährt die Sockelzone unter die Anzeige ----------------------
# Maße im echten Verhältnis des Spiels (Welt / 3,3): Gehäuse 3,6 x 0,86, Reihen-Teilung 1,18.

def chip_real(r, ux, cy, combo, retracted):
    name, pts, mult, mods, gold = combo
    cd, scale = 0.86, 0.9
    cw = 1.88 if retracted else 3.6
    by_name = {m[0]: m for m in MODULES if m is not None}
    top = 0.03 + CH
    left = ux - cw * 0.5
    led.rounded_box(r, "Body", (cw, cd, CH), (ux, cy, 0.03 + CH * 0.5), m_body(gold), 0.06, 0.02)
    cs.boxes(r, "Pins", [(ux + s * (cw * 0.5 + 0.04), cy + k * 0.25, 0.12, 0.08, 0.16, 0.1)
                         for s in (-1, 1) for k in (-1, 0, 1)], G("mult", 1.2) if gold else cs.m_steel())
    gw = 1.56
    led.rounded_box(r, "Glas", (gw, cd - 0.14, 0.012), (left + 0.08 + gw * 0.5, cy, top), m_glass(), 0.04,
                    0.0)
    x0, z = left + 0.17, top + 0.008
    txt(r, name, x0, cy + 0.17, z, 0.17 if len(name) < 14 else 0.125, "name")
    txt(r, pts, x0, cy - 0.17, z, 0.26, "punkte")
    txt(r, mult, x0 + 0.165 * len(pts) + 0.11, cy - 0.17, z, 0.26, "mult")
    band(r, ux, cy - cd * 0.5 - 0.025, 0.2, cw - 0.25, "mult" if gold else "band")
    if retracted:
        # drei Lampen am rechten Ende: je Sockel eine, in der Farbe seines Moduls
        for k in range(3):
            key = by_name[mods[k]][1] if k < len(mods) else None
            cs.boxes(r, "Lampe", [(left + cw - 0.12, cy + (1 - k) * 0.24, top + 0.006, 0.13, 0.18, 0.012)],
                     G(key, 3.2) if key else m_dim())
        return
    w, n, e = 0.03, 1, 1.4
    x = left + 0.08 + gw
    for k in range(3):
        bx = ux + 0.27 + k * 0.59
        mod = by_name[mods[k]] if k < len(mods) else None
        key = mod[1] if mod else None
        zm = sock_kombi(r, bx, cy, top, key, gold)
        run(r, x, bx + 0.27, cy, w, n, e, "punkte", zm + 0.002 if mod else top + 0.032)
        x = bx + 0.27
        if mod is None:
            continue
        placed(r, mod[3], key, bx, cy, zm, scale)
        sw, sn, se = OUT_LINE[mod[4]]
        w, n, e = max(w, sw), max(n, sn), max(e, se)
    run(r, x, left + cw, cy, w, n, e, "punkte", top + 0.012)


def einzug():
    r = cs.root("Einzug")
    right = 6.0
    for i, combo in enumerate(RACK):
        col, row = i % 3, i // 3
        chip_real(r, right - 0.94 - (2 - col) * 2.42, 5.0 - row * 1.18, combo, True)
        chip_real(r, right - 1.8 - (2 - col) * 4.22, -0.6 - row * 1.18, combo, False)
    for y0, y1 in ((5.45, 1.0), (-0.15, -4.6)):
        cs.boxes(r, "Grube", cs.ring_items(right + 1.35, (y0 + y1) * 0.5, 2.1, y0 - y1, 2.0, y0 - y1 - 0.1,
                                           0.01, 0.02), G("relais", 1.0))
        ms.label("WURFGRUBE", right + 1.35, (y0 + y1) * 0.5, 0.16)
    ms.label("IN DER RUNDE — Sockel eingezogen, je Modul eine Lampe", right - 3.6, 5.95, 0.2)
    ms.label("IM LADEN und an der Station — Sockel ausgefahren", right - 5.5, 0.38, 0.2)
    return "", 1.18


# --- Runde 10: STIFTE - jedes Modul IST einer der drei rechten Pins --------------------------

def pin_cap(r, x, y, key):
    """Der Pin eines Sockels ab der Gehäusekante x (Stift nach +X): leer blank, belegt in der Form
    seiner Modulfamilie."""
    z = 0.13
    if key is None:
        cs.boxes(r, "Pin", [(x + 0.07, y, 0.12, 0.14, 0.16, 0.1)], cs.m_steel())
        return
    if key in ("punkte", "kopplung"):
        lying(dm.cyl(r, "StiftKeramik", 0.07, 0.3, (x + 0.16, y, z), cer(), 24))
        for i in (-1, 0, 1):
            lying(dm.cyl(r, "StiftRing", 0.076, 0.035, (x + 0.16 + i * 0.08, y, z), G(key, 3.0), 24))
    elif key == "mult":
        lying(dm.cyl(r, "StiftBecher", 0.105, 0.24, (x + 0.13, y, z), dark(), 32))
        lying(dm.cyl(r, "StiftDeckel", 0.085, 0.02, (x + 0.255, y, z), G(key, 3.2), 32))
        lying(dm.cyl(r, "StiftBand", 0.11, 0.04, (x + 0.1, y, z), G(key, 2.4), 32))
    elif key == "wuerfel":
        cs.boxes(r, "Gabel", [(x + 0.13, y + s * 0.065, z - 0.01, 0.26, 0.05, 0.08) for s in (-1, 1)],
                 cs.m_steel())
        cs.boxes(r, "GabelSpitze", [(x + 0.29, y + s * 0.065, z - 0.01, 0.07, 0.06, 0.09) for s in (-1, 1)],
                 G(key, 3.2))
    elif key == "roehre":
        lying(dm.cyl(r, "StiftGlas", 0.095, 0.3, (x + 0.16, y, z), clear("roehre", 0.3, 0.3), 32))
        lying(dm.cyl(r, "StiftGlut", 0.045, 0.24, (x + 0.16, y, z), G(key, 4.0), 16))
        lying(dm.cyl(r, "StiftKappe", 0.1, 0.03, (x + 0.32, y, z), cs.m_steel(), 32))
    elif key == "link":
        cs.strips(r, "StiftPfeil", [[(x, y), (x + 0.34, y)], arrow((x + 0.34, y), (1, 0), 0.09)], 0.05,
                  z, G(key, 3.4))
    else:
        cs.boxes(r, "Klinge", [(x + 0.15, y, 0.1, 0.3, 0.2, 0.04)], cs.m_steel())
        cs.boxes(r, "KlingenLicht", [(x + 0.15, y, 0.123, 0.26, 0.07, 0.006)], G(key, 3.2))


# Runde 11: JEDES Modul hat seinen eigenen Pin - die Familie gibt die Form, das Modul Zeichen und
# Details. x = Gehäusekante, der Pin zeigt nach +X und ist höchstens 0,34 lang und 0,22 tief.
# Die Erweiterungsplatine entfällt (Spieler-Entscheid 2026-11-21).

def p_bar(r, x, y, key):
    """Speicher: liegender Keramikriegel mit flacher Oberseite; liefert deren Höhe."""
    led.rounded_box(r, "Riegel", (0.3, 0.15, 0.13), (x + 0.16, y, 0.125), cer(), 0.05, 0.02)
    cs.boxes(r, "Draht", [(x + 0.005, y, 0.11, 0.03, 0.05, 0.05)], cs.m_steel())
    return 0.192


def p_block(r, x, y, key):
    """Wandler: gedrungener dunkler Block mit goldener Stirn."""
    led.rounded_box(r, "Block", (0.25, 0.21, 0.17), (x + 0.13, y, 0.135), dark(), 0.05, 0.02)
    cs.boxes(r, "Stirn", [(x + 0.262, y, 0.135, 0.012, 0.17, 0.13)], G(key, 2.6))
    return 0.222


def p_fork(r, x, y, key, lit, prongs=(-0.065, 0.065)):
    """Kontakte: Gabel; lit = welche Zinken an der Spitze leuchten."""
    cs.boxes(r, "Joch", [(x + 0.04, y, 0.12, 0.08, 0.2, 0.09)], cs.m_steel())
    for i, o in enumerate(prongs):
        cs.boxes(r, "Zinke", [(x + 0.17, y + o, 0.12, 0.22, 0.045, 0.07)], cs.m_steel())
        cs.boxes(r, "Spitze", [(x + 0.305, y + o, 0.12, 0.06, 0.055, 0.085)],
                 G(key, 3.4) if i in lit else dark())
    return 0.167


def p_tube(r, x, y, key, rad=0.09, length=0.28):
    """Röhren: liegender Glaskolben mit Glutkern."""
    lying(dm.cyl(r, "Kolben", rad, length, (x + 0.02 + length * 0.5, y, 0.13), clear("roehre", 0.3, 0.3),
                 32))
    lying(dm.cyl(r, "Glut", rad * 0.45, length * 0.8, (x + 0.02 + length * 0.5, y, 0.13), G(key, 4.0), 16))
    lying(dm.cyl(r, "Fuss", rad + 0.008, 0.03, (x + 0.02, y, 0.13), cs.m_steel(), 32))


def p_blade(r, x, y, key):
    """Abgriffe und Fassungen: flache Klinge."""
    cs.boxes(r, "Klinge", [(x + 0.16, y, 0.1, 0.32, 0.2, 0.04)], cs.m_steel())
    return 0.122


def pin_widerstand(r, x, y, k):
    z = p_bar(r, x, y, k)
    cs.boxes(r, "Ring", [(x + 0.16 + i * 0.075, y, z, 0.035, 0.15, 0.006) for i in (-1, 0, 1)], G(k, 3.2))


def pin_spule(r, x, y, k):
    z = p_bar(r, x, y, k)
    cs.boxes(r, "Wicklung", [(x + 0.07 + i * 0.03, y, z, 0.016, 0.15, 0.006) for i in range(7)], copper())
    cs.boxes(r, "Kern", [(x + 0.03, y, z, 0.03, 0.13, 0.008), (x + 0.29, y, z, 0.03, 0.13, 0.008)],
             G("punkte", 3.2))
    cs.boxes(r, "Mult", [(x + 0.16, y, z + 0.006, 0.2, 0.025, 0.004)], G("mult", 3.0))


def pin_vorwiderstand(r, x, y, k):
    z = p_bar(r, x, y, k)
    cs.boxes(r, "Zinken", [(x + 0.055 + i * 0.042, y, z, 0.022, 0.11, 0.006) for i in range(6)], G(k, 3.2))


def pin_reihenklemme(r, x, y, k):
    z = p_bar(r, x, y, k)
    for i in (-1, 0, 1):
        dm.cyl(r, "Schraube", 0.035, 0.012, (x + 0.16 + i * 0.09, y, z + 0.004), cs.m_steel(), 16)
        dm.annulus(r, "Licht", x + 0.16 + i * 0.09, y, z + 0.001, 0.038, 0.05, G(k, 3.0), 16)


def pin_kondensator(r, x, y, k):
    z = p_block(r, x, y, k)
    cs.boxes(r, "Kreuz", [(x + 0.13, y, z, 0.15, 0.03, 0.006), (x + 0.13, y, z, 0.03, 0.15, 0.006)],
             G(k, 3.4))


def pin_loetpunkt(r, x, y, k):
    z = p_block(r, x, y, k)
    for a in range(3):
        for b in (-1, 1):
            ball(r, 0.027, (x + 0.07 + a * 0.06, y + b * 0.05, z), G(k, 3.4) if (a + b) % 2 else cs.m_steel(),
                 0.6)


def pin_thermistor(r, x, y, k):
    z = p_block(r, x, y, k)
    cs.boxes(r, "Glut", [(x + 0.055 + i * 0.05, y, z, 0.04, 0.17, 0.006) for i in range(4)],
             G("w0", 3.0))
    for i in range(4):
        cs.boxes(r, "Stufe", [(x + 0.055 + i * 0.05, y, z + 0.004, 0.04, 0.17, 0.004)], G("w%d" % i, 3.0))


def pin_zaehlwerk(r, x, y, k):
    z = p_block(r, x, y, k)
    cs.boxes(r, "Fenster", [(x + 0.13, y, z, 0.2, 0.13, 0.004)], m_pocket())
    t = txt(r, "07", x + 0.13, y, z + 0.004, 0.12, k, 3.4, "CENTER")


def pin_fehlerspeicher(r, x, y, k):
    z = p_block(r, x, y, k)
    dm.cyl(r, "Quarz", 0.04, 0.008, (x + 0.13, y + 0.045, z + 0.002), clear("roehre", 0.5, 0.8), 16)
    for i in range(3):
        dm.cyl(r, "Lampe", 0.022, 0.01, (x + 0.07 + i * 0.06, y - 0.055, z + 0.003),
               G("rot", 3.6) if i < 2 else m_dim(), 12)


def pin_anlasser(r, x, y, k):
    z = p_block(r, x, y, k)
    cs.strips(r, "Zeichen", [arc(x + 0.13, y, 0.055, 0.055, 120, 420, 16),
                             [(x + 0.13, y + 0.02), (x + 0.13, y + 0.085)]], 0.02, z + 0.002, G(k, 3.4))


def pin_relais(r, x, y, k):
    z = p_fork(r, x, y, k, (1,))
    lying(dm.cyl(r, "Spule", 0.045, 0.07, (x + 0.04, y, z + 0.03), copper(), 16))


def pin_endstufe(r, x, y, k):
    z = p_fork(r, x, y, k, (0,))
    cs.boxes(r, "Rippen", [(x + 0.015 + i * 0.025, y, z + 0.02, 0.012, 0.2, 0.05) for i in range(3)], alu())


def pin_nebenschluss(r, x, y, k):
    z = p_fork(r, x, y, k, (0, 1))
    cs.boxes(r, "Buegel", [(x + 0.18, y, z + 0.02, 0.05, 0.2, 0.04)], copper())


def pin_parallel(r, x, y, k):
    p_fork(r, x, y, k, (0, 1, 2, 3), (-0.085, -0.03, 0.03, 0.085))


def pin_verstaerker(r, x, y, k):
    p_tube(r, x, y, k, 0.08, 0.26)
    for i in (0, 1):
        lying(dm.cyl(r, "Gitter", 0.085, 0.012, (x + 0.12 + i * 0.08, y, 0.13), cs.m_steel(), 24))


def pin_hochspannung(r, x, y, k):
    p_tube(r, x, y, k, 0.105, 0.26)
    lying(dm.cyl(r, "Korona", 0.135, 0.02, (x + 0.16, y, 0.13), G(k, 3.4), 32))
    ball(r, 0.05, (x + 0.31, y, 0.13), cs.m_steel())


def pin_magnetron(r, x, y, k):
    p_tube(r, x, y, k, 0.085, 0.2)
    lying(dm.cyl(r, "Anode", 0.115, 0.07, (x + 0.27, y, 0.13), copper(), 32))
    cs.boxes(r, "Magnet", [(x + 0.27, y + s * 0.1, 0.13, 0.07, 0.03, 0.2) for s in (-1, 1)], cs.m_steel())


def pin_schwingkreis(r, x, y, k):
    p_tube(r, x, y, k, 0.08, 0.3)
    rings(r, x + 0.08, y, 0.13, 5, 0.092, None, 0.04)


def pin_nachbrenner(r, x, y, k):
    p_tube(r, x, y, k, 0.075, 0.14)
    cone(r, 0.07, 0.11, 0.1, (x + 0.2, y, 0.13), led.mat("Duese3", (0.62, 0.64, 0.7), 0.3, 0.45))
    cone(r, 0.085, 0.0, 0.14, (x + 0.31, y, 0.13), G(k, 4.0))
    cone(r, 0.045, 0.0, 0.09, (x + 0.29, y, 0.13), G("w0", 5.0))


def pin_muenzpruefer(r, x, y, k):
    z = p_blade(r, x, y, k)
    cs.boxes(r, "Schlitz", [(x + 0.07, y, z, 0.03, 0.15, 0.004)], G(k, 3.2))
    dm.cyl(r, "Muenze", 0.065, 0.014, (x + 0.2, y, z + 0.006), cs.m_gold(), 24)


def pin_stromabnehmer(r, x, y, k):
    z = p_blade(r, x, y, k)
    cs.boxes(r, "Schleifer", [(x + 0.29, y, z, 0.05, 0.2, 0.012)], copper())
    cs.strips(r, "Funke", [[(x + 0.06, y - 0.05), (x + 0.12, y + 0.05), (x + 0.17, y - 0.04),
                            (x + 0.23, y + 0.05)]], 0.024, z + 0.004, G(k, 4.0))


def pin_querbruecke(r, x, y, k):
    cs.boxes(r, "Fuss", [(x + 0.03, y, 0.11, 0.06, 0.14, 0.07)], cs.m_steel())
    cs.strips(r, "Pfeil", [[(x, y), (x + 0.34, y)], arrow((x + 0.34, y), (1, 0), 0.09)], 0.05, 0.15,
              G(k, 3.4))


def pin_laengsbruecke(r, x, y, k):
    cs.boxes(r, "Fuss", [(x + 0.03, y, 0.11, 0.06, 0.14, 0.07)], cs.m_steel())
    cs.strips(r, "Pfeil", [[(x, y + 0.05), (x + 0.2, y + 0.05), (x + 0.2, y - 0.12)],
                           arrow((x + 0.2, y - 0.12), (0, -1), 0.09)], 0.05, 0.15, G(k, 3.4))


def pin_kopplung(r, x, y, k):
    cs.boxes(r, "Fuss", [(x + 0.03, y, 0.11, 0.06, 0.14, 0.07)], cs.m_steel())
    cs.strips(r, "Pfeil", [[(x + 0.34, y), (x + 0.06, y)], arrow((x + 0.06, y), (-1, 0), 0.08)], 0.045,
              0.15, G(k, 3.2))
    cs.boxes(r, "Abbild", cs.ring_items(x + 0.27, y, 0.13, 0.17, 0.09, 0.13, 0.15, 0.006), G(k, 3.2))


def pin_sperrdiode(r, x, y, k):
    z = p_blade(r, x, y, k)
    poly_prism(r, "Dreieck", [(x + 0.08, y + 0.07), (x + 0.08, y - 0.07), (x + 0.2, y)], z, z + 0.006,
               G(k, 3.0))
    cs.boxes(r, "Strich", [(x + 0.215, y, z + 0.003, 0.022, 0.15, 0.006)], G(k, 3.0))


PINS = {"Widerstand": pin_widerstand, "Spule": pin_spule, "Vorwiderstand": pin_vorwiderstand,
        "Reihenklemme": pin_reihenklemme, "Kondensator": pin_kondensator, "Lötpunkt": pin_loetpunkt,
        "Thermistor": pin_thermistor, "Zählwerk": pin_zaehlwerk, "Fehlerspeicher": pin_fehlerspeicher,
        "Anlasser": pin_anlasser, "Relais": pin_relais, "Endstufe": pin_endstufe,
        "Nebenschluss": pin_nebenschluss, "Parallelschaltung": pin_parallel,
        "Verstärkerröhre": pin_verstaerker, "Hochspannungsröhre": pin_hochspannung,
        "Magnetron": pin_magnetron, "Schwingkreis": pin_schwingkreis, "Nachbrenner": pin_nachbrenner,
        "Münzprüfer": pin_muenzpruefer, "Stromabnehmer": pin_stromabnehmer,
        "Querbrücke": pin_querbruecke, "Längsbrücke": pin_laengsbruecke, "Kopplung": pin_kopplung,
        "Sperrdiode": pin_sperrdiode}


def pin_for(r, x, y, mod):
    if mod is None or mod[0] not in PINS:
        pin_cap(r, x, y, None)
    else:
        PINS[mod[0]](r, x, y, mod[1])


def pin_sample(r, x, y, mod):
    """Ein Chip-Ende mit seinem Pin, dreifach vergrößert, für das Blatt."""
    e = cs.root("Probe")
    top = 0.03 + CH
    led.rounded_box(e, "Ende", (0.5, 0.31, CH), (-0.25, 0.0, 0.03 + CH * 0.5), m_body(False), 0.03, 0.01)
    cs.boxes(e, "Kachel", [(-0.13, 0.0, top + 0.006, 0.2, 0.215, 0.012)],
             led.mat("Kachel", (0.09, 0.09, 0.12), 0.5, 0.4))
    cs.boxes(e, "KachelLicht", [(-0.21, 0.0, top + 0.014, 0.03, 0.19, 0.006)], G(mod[1], 3.2))
    pin_for(e, 0.0, 0.0, mod)
    e.location = (x, y, 0.0)
    e.scale = (3.2, 3.2, 3.2)
    e.parent = r


def stifte_blatt():
    r = cs.root("StifteBlatt")
    order = list(PINS.keys())
    by_name = {m[0]: m for m in MODULES if m is not None}
    for i, name in enumerate(order):
        mod = by_name[name]
        x, y = (i % 5 - 2) * 3.3, 4.3 - (i // 5) * 2.05
        pin_sample(r, x + 0.25, y, mod)
        txt(r, name, x, y - 0.75, 0.002, 0.14 if len(name) < 15 else 0.115, "hell", 1.6, "CENTER")
        txt(r, mod[2], x, y - 0.95, 0.002, 0.105, mod[1], 2.2, "CENTER")
    ms.label("U · STIFTE — jedes Modul sein eigener Pin: die Familie gibt die Form, das Modul das Zeichen",
             0.0, -5.75, 0.2)
    return "", 1.95


def chip_stift(r, ux, cy, combo, extended):
    name, pts, mult, mods, gold = combo
    cd, scale = 0.86, 0.9
    cw = 3.6 if extended else 1.9
    by_name = {m[0]: m for m in MODULES if m is not None}
    top = 0.03 + CH
    left, right = ux - cw * 0.5, ux + cw * 0.5
    led.rounded_box(r, "Body", (cw, cd, CH), (ux, cy, 0.03 + CH * 0.5), m_body(gold), 0.06, 0.02)
    cs.boxes(r, "PinsLinks", [(left - 0.04, cy + k * 0.25, 0.12, 0.08, 0.16, 0.1) for k in (-1, 0, 1)],
             G("mult", 1.2) if gold else cs.m_steel())
    gw = 1.52
    led.rounded_box(r, "Glas", (gw, cd - 0.14, 0.012), (left + 0.08 + gw * 0.5, cy, top), m_glass(), 0.04,
                    0.0)
    x0, z = left + 0.17, top + 0.008
    txt(r, name, x0, cy + 0.17, z, 0.17 if len(name) < 14 else 0.125, "name")
    txt(r, pts, x0, cy - 0.17, z, 0.26, "punkte")
    txt(r, mult, x0 + 0.165 * len(pts) + 0.11, cy - 0.17, z, 0.26, "mult")
    band(r, ux, cy - cd * 0.5 - 0.025, 0.2, cw - 0.25, "mult" if gold else "band")
    for k in range(3):
        mod = by_name[mods[k]] if k < len(mods) else None
        key = mod[1] if mod else None
        row = cy + (1 - k) * 0.25
        # das Stück Chip, das zum Modul gehört: eine Kachel am rechten Deckelende
        cs.boxes(r, "Kachel", [(right - 0.13, row, top + 0.006, 0.2, 0.215, 0.012)],
                 led.mat("Kachel", (0.09, 0.09, 0.12), 0.5, 0.4))
        cs.boxes(r, "KachelLicht", [(right - 0.21, row, top + 0.014, 0.03, 0.19, 0.006)],
                 G(key, 3.2) if key else m_dim())
        pin_for(r, right, row, mod)
        if not extended:
            continue
        bx = ux + 0.14 + k * 0.56
        zm = sock_kombi(r, bx, cy, top, key, gold)
        # je Sockel eine eigene Leitung zu SEINEM Pin
        cs.strips(r, "Leitung", [[(bx, cy), (bx + 0.3, row), (right - 0.24, row)]], 0.035 if key else 0.02,
                  top + 0.004, G(key, 2.6) if key else m_dim())
        if mod is not None:
            placed(r, mod[3], key, bx, cy, zm, scale)


def stifte():
    r = cs.root("Stifte")
    right = 5.6
    for i, combo in enumerate(RACK):
        col, row = i % 3, i // 3
        chip_stift(r, right - 0.95 - (2 - col) * 2.75, 5.0 - row * 1.18, combo, False)
        chip_stift(r, right - 1.8 - (2 - col) * 4.5, -0.6 - row * 1.18, combo, True)
    for y0, y1 in ((5.45, 1.0), (-0.15, -4.6)):
        cs.boxes(r, "Grube", cs.ring_items(right + 1.75, (y0 + y1) * 0.5, 2.1, y0 - y1, 2.0, y0 - y1 - 0.1,
                                           0.01, 0.02), G("relais", 1.0))
        ms.label("WURFGRUBE", right + 1.75, (y0 + y1) * 0.5, 0.16)
    ms.label("IN DER RUNDE — jedes Modul ist einer der drei rechten Pins", right - 3.9, 5.95, 0.2)
    ms.label("IM LADEN — die Sockel fahren aus, jeder hängt an SEINEM Pin", right - 6.0, 0.38, 0.2)
    return "", 1.18


WIDE = {"u_stifte_blatt": (18.6, -0.35), "t_stifte": (19.5, 0.65), "s_einzug": (18.0, 0.65), "o_rack_bauteile": (11.6, -0.25), "p_grosschip": (11.6, -0.3), "q_plattformen": (8.6, 0.1), "r_rack_kombi": (11.6, -0.3)}

NAH = {"u_stifte_blatt": [(-4.9, 3.4), (1.7, 3.4), (-1.6, -0.7), (1.7, -2.8)],
       "t_stifte": [(2.3, 4.3), (1.2, -1.3)],
       "s_einzug": [(2.6, 4.3), (1.5, -1.3)],
       "r_rack_kombi": [(-1.2, 1.7), (2.5, 0.55), (2.5, -1.7)],
       "q_plattformen": [(-1.2, 1.75), (-1.2, 0.0), (-1.2, -1.75), (2.5, 1.75), (2.5, 0.0), (2.5, -1.75)],
       "p_grosschip": [(-1.5, 1.75), (2.0, -0.55)],
       "o_rack_bauteile": [(-1.6, 1.9), (2.2, -0.3), (2.2, -2.3)], "l_rack": (1.9, 1.0), "k_riegel": (COL, 0.6), "m_bauteile_oben": (-1.6, 0.6),
       "m_bauteile_unten": (-1.6, 0.6), "n_bauteile_neu": (2.7, 0.6)}

VARIANTS = {"u_stifte_blatt": stifte_blatt, "t_stifte": stifte, "s_einzug": einzug, "r_rack_kombi": rack_kombi, "q_plattformen": plattformen, "p_grosschip": grosschip, "o_rack_bauteile": rack_bauteile, "n_bauteile_neu": bauteile_neu, "m_bauteile_oben": bauteile_oben, "m_bauteile_unten": bauteile_unten,
            "0_heute": heute, "j_pinlinien": pinlinien, "k_riegel": riegel, "l_rack": rack,
            "a_traeger": traeger, "b_einschub": einschub, "c_terrasse": terrasse,
            "i_gatter": gatter,
            "d_kette": kette, "e_optik": optik, "f_rechenwerk": rechenwerk, "g_mehrkern": mehrkern,
            "h_uebertakter": uebertakter}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    argv = sys.argv[sys.argv.index("--") + 1:]
    only = argv[1].split(",") if len(argv) > 1 else []
    for name, fn in VARIANTS.items():
        if only and name not in only:
            continue
        cam, aim = dm.empty_stage()
        for o in bpy.data.objects:
            mats = getattr(o.data, "materials", None) if o.data is not None else None
            if mats and mats[0] is not None and mats[0].name.startswith("Softbox"):
                o.location.z += 30.0
        title, pitch = fn()
        ms.label(title, 0.0, max(-pitch - 0.75, -2.72), 0.16)
        scene = bpy.context.scene
        scene.eevee.taa_render_samples = 48
        scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
        wide, wy = WIDE.get(name, (8.6, -0.25))
        ms.station(cam, aim, Vector((0.0, wy, 0)), wide * 50 / 36 * 1.02)
        scene.render.filepath = os.path.join(OUT, name + "_station.png")
        bpy.ops.render.render(write_still=True)
        spots = NAH.get(name, (COL, pitch * 0.5 - 0.15))
        spots = spots if isinstance(spots, list) else [spots]
        for k, (ax, ay) in enumerate(spots):
            aim.location = (ax, ay, 0.1)
            cam.location = (ax + 0.5, ay - 2.85, 2.6)
            cam.data.lens = 50
            scene.render.filepath = os.path.join(OUT, name + "_nah%s.png" % ("" if k == 0 else k + 1))
            bpy.ops.render.render(write_still=True)
    print("ok")
