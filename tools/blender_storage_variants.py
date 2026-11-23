"""Fumble: drei Entwürfe für den SPEICHER (UPGRADES) als Körper (Spieler-Wunsch 2026-11-23).

Das Summen-Netz bleibt ein Kreuz aus sechs Zellen (4 x 3 Raster); in den freien Ecken rechts
sitzen sechs echte Energiespeicher (einer je Scheibe), links oben der Füllstand, links unten
die Kühlung. A = Platine mit Glaszellen, B = gefrästes Rack mit Kartuschen, C = Elko-Bank.

Aufruf (kopflos):
  blender -b -P tools/blender_storage_variants.py -- <ausgabe-ordner> [nur]
Achsen: X = Breite, Y = Tiefe (Netz-Zeile 0 bei +Y), Z = Höhe.
"""
import bpy, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_floppy_charm as fc

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
OUT = ARGS[0]

CELL = 1.0
S = 1.12                                # Zell-Teilung (DieNetView.GAP_FACTOR)
W = 4 * S + 0.4
D = 3 * S + 0.6
NET = [(1, 0), (0, 1), (1, 1), (2, 1), (3, 1), (1, 2)]
SORTS = dict(led.SORTS, sonder=led.lin("#b9a3ff"))
LANES = ["zahl", "material", "rune", "sonder"]
CHARGE = ["zahl", "material", "zahl", "rune", None, None]   # je Scheibe die Sorte ihrer Karte
CONTENT = {(0, 1): "+1", (1, 1): "+1", (2, 1): "fill", (3, 1): "+1"}
CYAN = (0.2, 0.85, 1.0)
GOLD = (1.0, 0.62, 0.16)
OFF = (0.03, 0.035, 0.045)


def cx(c):
    return (c - 1.5) * S


def cy(r):
    return (1 - r) * S


def slot(i):
    """Mitte des Speichers i: drei je freiem Zwei-Zellen-Block rechts (oben 0-2, unten 3-5)."""
    block = S + CELL
    return cx(2) - CELL * 0.5 + block * ((i % 3) + 0.5) / 3.0, cy(0 if i < 3 else 2)


def stored():
    return len([s for s in CHARGE if s])


def glow(sort, emit):
    if sort is None:
        return led.mat("Aus", OFF, 0.0, 0.35)
    return led.mat("Licht_%s_%.1f" % (sort, emit), SORTS[sort], 0.0, 0.3, emit)


def torus(parent, name, major, minor, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc,
                                     rotation=rot, major_segments=48, minor_segments=10)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    o.parent = parent
    return o


def rbox(parent, name, size, loc, material, rot):
    """Gedrehter Quader: fc.box backt den Ort ins Netz, eine Drehung danach liefe um den Ursprung."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.data.materials.append(material)
    o.parent = parent
    return o


def content(parent, c, r, z, span):
    """Was die Zelle zeigt: eine grüne Zahl oder eine gefüllte Material-Seite."""
    kind = CONTENT.get((c, r))
    if kind is None:
        return
    if kind == "fill":
        led.rounded_box(parent, "Fuellung", (span, span, 0.004), (cx(c), cy(r), z),
                        led.mat("Materialgold", (1.0, 0.72, 0.08), 0.0, 0.3, 1.6), span * 0.2,
                        0.0, 4)
        return
    t = fc.text(parent, kind, (cx(c), cy(r), z), span * 0.5, glow("zahl", 3.0), bold=True)
    t.data.extrude = 0.0


def lane_mat(i, lane):
    """Die Spur der Karten-Sorte leuchtet, die drei anderen der Scheibe bleiben farblos."""
    if CHARGE[i] == LANES[lane]:
        return glow(CHARGE[i], 3.0)
    return led.mat("SpurLeer", (0.25, 0.27, 0.32), 1.0, 0.35)


def cell_of(i):
    """Platz der Zelle einer Scheibe auf der Platine: oben liegen 3-2-1, unten 4-5-6."""
    return 2 - i if i < 3 else i


def bus_y(half, k):
    """Spur k des Flächen-Busses in der oberen (half = 1) bzw. unteren Fuge des Kreuzes."""
    return half * S * 0.5 + (k - 1.5) * 0.03


def wire(parent, pts, material, width, z, chamfer=0.07):
    """Leiterzug als Linienzug mit 45-Grad-Ecken."""
    path = [pts[0]]
    for a, b, c in zip(pts, pts[1:], pts[2:]):
        la = math.hypot(b[0] - a[0], b[1] - a[1])
        lc = math.hypot(c[0] - b[0], c[1] - b[1])
        cut = min(chamfer, la * 0.45, lc * 0.45)
        path.append((b[0] + (a[0] - b[0]) / la * cut, b[1] + (a[1] - b[1]) / la * cut))
        path.append((b[0] + (c[0] - b[0]) / lc * cut, b[1] + (c[1] - b[1]) / lc * cut))
    path.append(pts[-1])
    for a, b in zip(path, path[1:]):
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        if length < 1e-5:
            continue
        rbox(parent, "Zug", (length + width * 0.6, width, 0.003),
             ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5, z), material,
             (0, 0, math.atan2(b[1] - a[1], b[0] - a[0])))


# --- A: PLATINE - Glaszellen in Federklemmen, das Netz als gesockelte Chips ---------------

def platine(root):
    pcb = led.mat("Platine", (0.004, 0.018, 0.016), 0.2, 0.32, clearcoat=0.9)
    gold = led.mat("Gold", GOLD, 1.0, 0.25)
    tin = led.mat("Zinn", (0.7, 0.72, 0.75), 1.0, 0.25)
    ceramic = led.mat("Keramik", (0.012, 0.012, 0.015), 0.0, 0.5)
    glass = led.mat("Displayglas", (0.004, 0.008, 0.012), 0.0, 0.05, clearcoat=1.0)
    tube = led.mat("Glasrohr", (0.85, 0.93, 1.0), 0.0, 0.03, 0.0, 0.18)
    steel = led.mat("Federstahl", (0.4, 0.42, 0.46), 1.0, 0.28)
    alu = led.mat("Alu", (0.55, 0.57, 0.6), 1.0, 0.35)
    idle = led.mat("Leiterzug", (0.5, 0.36, 0.13), 1.0, 0.4)
    top = 0.06
    zt = top + 0.0015
    left, right, bot, up = -2.84, 2.84, -2.45, 2.3
    pitch = 0.03
    led.rounded_box(root, "Platine", (right - left, up - bot, top),
                    (0, (up + bot) * 0.5, top * 0.5), pcb, 0.14, 0.004, 6)
    for px in (left + 0.13, right - 0.13):
        for py in (bot + 0.13, up - 0.13):
            fc.cyl(root, "Lochring", 0.085, 0.006, (px, py, top + 0.002), gold, verts=24)
            fc.cyl(root, "Loch", 0.045, 0.008, (px, py, top + 0.003), ceramic, verts=24)
    # Die 24 Bahnen: Kontaktfinger unten, jedes Bündel läuft in die Zelle seiner Scheibe -
    # 1-3 links herum und oben herein, 4-6 gerade hinauf. Keine Bahn kreuzt eine andere.
    for i in range(6):
        gx = left + 0.5 + (right - left - 1.0) * (i + 0.5) / 6.0
        bx, by = slot(cell_of(i))
        for lane in range(4):
            lit = CHARGE[i] == LANES[lane]
            m = glow(CHARGE[i], 3.0) if lit else idle
            fx = gx + (lane - 1.5) * 0.085
            fc.box(root, "Finger", (0.05, 0.2, 0.006), (fx, bot + 0.15, top + 0.003),
                   m if lit else gold)
            if i < 3:
                j = i * 4 + lane
                ex = bx - (lane - 1.5) * 0.05
                low, side, high = -2.08 + j * pitch, left + 0.26 + j * pitch, up - 0.26 - j * pitch
                pts = [(fx, bot + 0.25), (fx, low), (side, low), (side, high), (ex, high),
                       (ex, by + 0.5)]
            else:
                ex = bx + (lane - 1.5) * 0.05
                pts = [(fx, bot + 0.25), (fx, bot + 0.45), (ex, bot + 0.45 + abs(ex - fx)),
                       (ex, by - 0.5)]
            wire(root, pts, m, 0.014, zt)
            fc.cyl(root, "Loetauge", 0.02, 0.005, (pts[-1][0], pts[-1][1], top + 0.002), gold,
                   verts=12)
    # Der FLÄCHEN-BUS: vier Spuren (eine je Sorte) in beiden Fugen des Kreuzes, rechts
    # verbunden und hinauf zum Ausgang; jede Zelle speist ihn, jeder Chip hängt daran.
    for k in range(4):
        used = LANES[k] in CHARGE
        m = glow(LANES[k], 3.0) if used else idle
        vx = 2.33 - k * pitch
        px = 2.55 - k * 0.1
        wire(root, [(-2.16, bus_y(-1, k)), (vx, bus_y(-1, k)), (vx, up - 0.62),
                    (px, up - 0.62 + (px - vx)), (px, up - 0.2)], m, 0.014, zt)
        wire(root, [(-2.16, bus_y(1, k)), (vx, bus_y(1, k))], m, 0.014, zt)
        fc.cyl(root, "Knoten", 0.02, 0.005, (vx, bus_y(1, k), top + 0.002), gold, verts=12)
        fc.box(root, "Buspad", (0.06, 0.18, 0.006), (px, up - 0.11, top + 0.003),
               m if used else tin)
        for (c, r) in NET:
            for half in (-1, 1):
                if (r == 0 and half == 1) or (r == 2 and half == -1):
                    continue
                sx = cx(c) + (k - 1.5) * 0.23
                tip = cy(r) + half * 0.47
                lane_y = bus_y(half if r == 1 else -half, k)
                fc.box(root, "Abzweig", (0.014, abs(lane_y - tip) + 0.01, 0.003),
                       (sx, (lane_y + tip) * 0.5, zt), m)
                fc.cyl(root, "Knoten", 0.016, 0.005, (sx, lane_y, top + 0.002), gold, verts=12)
    for (c, r) in NET:
        x, y = cx(c), cy(r)
        led.rounded_box(root, "Chip", (0.84, 0.84, 0.14), (x, y, top + 0.07), ceramic, 0.04,
                        0.012, 4)
        for side in (-1, 1):
            for k in range(7):
                off = (k - 3) * 0.115
                fc.box(root, "Bein", (0.07, 0.05, 0.03), (x + side * 0.44, y + off, top + 0.015),
                       tin)
                fc.box(root, "Bein", (0.05, 0.07, 0.03), (x + off, y + side * 0.44, top + 0.015),
                       tin)
        led.rounded_box(root, "Saum", (0.74, 0.74, 0.006), (x, y, top + 0.141),
                        led.mat("ZellSaum", CYAN, 0.0, 0.3, 1.4), 0.07, 0.0, 4)
        led.rounded_box(root, "Display", (0.7, 0.7, 0.01), (x, y, top + 0.143), glass, 0.06,
                        0.0, 4)
        fc.cyl(root, "Pin1", 0.022, 0.004, (x - 0.37, y + 0.37, top + 0.141), tin, verts=12)
        content(root, c, r, top + 0.15, 0.66)
    for i, sort in enumerate(CHARGE):
        x, y = slot(cell_of(i))
        z = top + 0.25
        inward = -1 if i < 3 else 1
        k = LANES.index(sort) if sort else (0 if i < 3 else 3)
        lane_y = bus_y(-inward, k)
        fc.box(root, "Abgang", (0.03, abs(lane_y - (y + inward * 0.5)) + 0.01, 0.003),
               (x, (lane_y + y + inward * 0.5) * 0.5, zt), glow(sort, 3.0) if sort else idle)
        fc.cyl(root, "Knoten", 0.024, 0.005, (x, lane_y, top + 0.002), gold, verts=12)
        fc.box(root, "Halter", (0.5, 0.94, 0.04), (x, y, top + 0.02), ceramic)
        for sy in (-1, 1):
            fc.box(root, "Klemme", (0.3, 0.025, 0.34), (x, y + sy * 0.44, top + 0.17), steel)
            fc.cyl(root, "Kappe", 0.205, 0.07, (x, y + sy * 0.36, z), tin,
                   rot=(math.radians(90), 0, 0), verts=32)
        fc.cyl(root, "Kern", 0.14, 0.62, (x, y, z), glow(sort, 2.6),
               rot=(math.radians(90), 0, 0), verts=32)
        fc.cyl(root, "Glas", 0.2, 0.66, (x, y, z), tube, rot=(math.radians(90), 0, 0), verts=32)
        fc.box(root, "Statuspad", (0.12, 0.05, 0.02), (x, y + inward * 0.52, top + 0.01),
               glow(sort, 3.0))
    # Füllstand oben links: Display und eine LED je Scheibe.
    gx, gy = cx(0), cy(0)
    led.rounded_box(root, "Anzeige", (0.9, 0.5, 0.1), (gx, gy + 0.16, top + 0.05), ceramic, 0.04,
                    0.01, 4)
    fc.box(root, "Anzeigeglas", (0.8, 0.4, 0.004), (gx, gy + 0.16, top + 0.102), glass)
    t = fc.text(root, "%d/6" % stored(), (gx, gy + 0.16, top + 0.106), 0.3,
                led.mat("Ziffern", CYAN, 0.0, 0.4, 3.0), bold=True)
    t.data.extrude = 0.0
    for i, sort in enumerate(CHARGE):
        fc.box(root, "Led", (0.09, 0.07, 0.04), (gx + (i - 2.5) * 0.15, gy - 0.3, top + 0.02),
               glow(sort, 3.5))
    # Kühlkörper unten links.
    hx, hy = cx(0), cy(2)
    fc.box(root, "Kuehlsockel", (0.9, 0.9, 0.05), (hx, hy, top + 0.025), alu)
    for k in range(9):
        fc.box(root, "Rippe", (0.05, 0.86, 0.24), (hx + (k - 4) * 0.1, hy, top + 0.17), alu)
    for k, (dx, dy) in enumerate(((2.55, -0.9), (2.55, -1.2), (2.4, -1.95), (2.6, -1.95),
                                  (2.55, 0.2), (2.55, -0.2))):
        fc.box(root, "Smd%d" % k, (0.06, 0.12, 0.035), (dx, dy, top + 0.018), ceramic)
        for e in (-1, 1):
            fc.box(root, "SmdEnde%d" % k, (0.062, 0.025, 0.037), (dx, dy + e * 0.05, top + 0.018),
                   tin)


# --- B: RACK - gefrästes Chassis, sechs Kartuschen in Schächten, Lüfter ------------------

def rack(root):
    gun = led.mat("Gussgrau", (0.05, 0.052, 0.06), 0.95, 0.3, clearcoat=0.3)
    black = led.mat("Eloxal", (0.008, 0.008, 0.011), 0.3, 0.4)
    glass = led.mat("Schwarzglas", (0.004, 0.006, 0.01), 0.0, 0.28, clearcoat=0.3)
    chrome = led.mat("Chrom", (0.85, 0.86, 0.88), 1.0, 0.1)
    gold = led.mat("Gold", GOLD, 1.0, 0.25)
    seam = led.mat("Saumlicht", CYAN, 0.0, 0.3, 2.2)
    h = 0.3
    led.rounded_box(root, "Bodensaum", (W + 0.05, D + 0.05, 0.012), (0, 0, 0.006), seam, 0.2, 0.0,
                    8)
    body = led.rounded_box(root, "Chassis", (W, D, h), (0, 0, h * 0.5 + 0.008), gun, 0.18, 0.03, 8)
    top = h + 0.008
    for (c, r) in NET:
        x, y = cx(c), cy(r)
        led.cut(body, fc.box(root, "SchnittZelle", (0.96, 0.96, 0.2), (x, y, top), black))
        led.rounded_box(root, "Zellsaum", (0.94, 0.94, 0.008), (x, y, top - 0.094), seam, 0.05,
                        0.0, 4)
        led.rounded_box(root, "Zellglas", (0.86, 0.86, 0.06), (x, y, top - 0.06), glass, 0.06,
                        0.012, 4)
        content(root, c, r, top - 0.028, 0.8)
    for i, sort in enumerate(CHARGE):
        x, y = slot(i)
        led.cut(body, fc.box(root, "SchnittSchacht", (0.58, 0.98, 0.4), (x, y, top), black))
        fc.box(root, "Schachtgrund", (0.57, 0.97, 0.006), (x, y, top - 0.196), glow(sort, 1.6))
        led.rounded_box(root, "Kartusche", (0.46, 0.86, 0.24), (x, y, top - 0.07), black, 0.06,
                        0.02, 6)
        if sort:
            led.rounded_box(root, "Fenster", (0.16, 0.5, 0.008), (x, y + 0.02, top + 0.052),
                            glow(sort, 3.2), 0.05, 0.0, 4)
        else:
            led.rounded_box(root, "Fenster", (0.16, 0.5, 0.008), (x, y + 0.02, top + 0.052), glass,
                            0.05, 0.0, 4)
            for k in range(3):
                fc.box(root, "Marke", (0.1, 0.012, 0.002), (x, y + 0.02 + (k - 1) * 0.14,
                                                           top + 0.057),
                       led.mat("MarkeMatt", (0.2, 0.22, 0.26), 0.0, 0.5, 0.2))
        led.rounded_box(root, "Griff", (0.3, 0.07, 0.035), (x, y + 0.35, top + 0.062), chrome,
                        0.02, 0.006, 4)
        fc.box(root, "Kontakt", (0.24, 0.035, 0.008), (x, y - 0.36, top + 0.052), gold)
    # Füllstand oben links: Glas mit Ziffern und Balken.
    gx, gy = cx(0), cy(0)
    led.cut(body, fc.box(root, "SchnittAnzeige", (0.92, 0.92, 0.1), (gx, gy, top), black))
    fc.box(root, "Anzeigeglas", (0.9, 0.9, 0.01), (gx, gy, top - 0.045), glass)
    t = fc.text(root, "%d/6" % stored(), (gx, gy + 0.17, top - 0.038), 0.3,
                led.mat("Ziffern", CYAN, 0.0, 0.4, 3.0), bold=True)
    t.data.extrude = 0.0
    for i, sort in enumerate(CHARGE):
        fc.box(root, "Balken", (0.1, 0.26, 0.006), (gx + (i - 2.5) * 0.135, gy - 0.2, top - 0.037),
               glow(sort, 3.2))
    # Lüfter unten links.
    hx, hy = cx(0), cy(2)
    led.cut(body, fc.cyl(root, "SchnittLuefter", 0.44, 0.4, (hx, hy, top), black))
    fc.cyl(root, "Lueftergrund", 0.43, 0.006, (hx, hy, top - 0.195), black)
    torus(root, "Luefterlicht", 0.41, 0.012, (hx, hy, top - 0.18), seam)
    fc.cyl(root, "Nabe", 0.12, 0.08, (hx, hy, top - 0.1), gun)
    for k in range(7):
        a = math.radians(k * 360.0 / 7.0)
        rbox(root, "Fluegel%d" % k, (0.3, 0.13, 0.012),
             (hx + math.cos(a) * 0.25, hy + math.sin(a) * 0.25, top - 0.1), black,
             (math.radians(24), 0, a + math.radians(20)))
    for rr in (0.2, 0.33):
        torus(root, "Gitter", rr, 0.01, (hx, hy, top - 0.02), chrome)
    for a in (45, 135):
        rbox(root, "Gitterstrebe", (0.86, 0.02, 0.012), (hx, hy, top - 0.02), chrome,
             (0, 0, math.radians(a)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            fc.cyl(root, "Schraube", 0.07, 0.03, (sx * (W * 0.5 - 0.16), sy * (D * 0.5 - 0.16),
                                                  top + 0.004), chrome, verts=6)
    # Steckerleiste vorn (sechs Buchsen zu vier Stiften) und der Bus-Abgang hinten rechts.
    for i in range(6):
        gx2 = -W * 0.5 + 0.4 + (W - 0.8) * (i + 0.5) / 6.0
        fc.box(root, "Buchse", (0.46, 0.14, 0.16), (gx2, -D * 0.5 - 0.05, 0.088), black)
        for lane in range(4):
            fc.box(root, "Stift", (0.06, 0.12, 0.008), (gx2 + (lane - 1.5) * 0.1, -D * 0.5 - 0.05,
                                                        0.172), lane_mat(i, lane))
    fc.box(root, "Busblock", (0.5, 0.14, 0.16), (W * 0.5 - 0.6, D * 0.5 + 0.05, 0.088), black)
    for lane in range(4):
        used = LANES[lane] in CHARGE
        fc.box(root, "Busstift", (0.06, 0.12, 0.008), (W * 0.5 - 0.6 + (lane - 1.5) * 0.1,
                                                       D * 0.5 + 0.05, 0.172),
               glow(LANES[lane], 3.0) if used else gold)


# --- C: ELKO-BANK - stehende Speicherdosen auf Kupferschienen, Zeigerinstrument ----------

def elkobank(root):
    tray = led.mat("Wanne", (0.01, 0.01, 0.014), 0.4, 0.45)
    rim = led.mat("Rahmenstahl", (0.12, 0.125, 0.14), 1.0, 0.3, clearcoat=0.3)
    copper = led.mat("Kupfer", (0.9, 0.36, 0.16), 1.0, 0.28)
    glass = led.mat("Schwarzglas", (0.004, 0.006, 0.01), 0.0, 0.28, clearcoat=0.3)
    chrome = led.mat("Chrom", (0.85, 0.86, 0.88), 1.0, 0.1)
    sleeve = led.mat("Mantel", (0.008, 0.01, 0.022), 0.0, 0.25, clearcoat=0.8)
    alu = led.mat("Alu", (0.6, 0.62, 0.65), 1.0, 0.3)
    seam = led.mat("Saumlicht", CYAN, 0.0, 0.3, 1.6)
    top = 0.08
    led.rounded_box(root, "Wanne", (W, D, top), (0, 0, top * 0.5), tray, 0.16, 0.006, 8)
    for sy in (-1, 1):
        fc.box(root, "Rahmen", (W - 0.3, 0.06, 0.16), (0, sy * (D * 0.5 - 0.03), 0.08), rim)
    for sx in (-1, 1):
        fc.box(root, "Rahmen", (0.06, D - 0.3, 0.16), (sx * (W * 0.5 - 0.03), 0, 0.08), rim)
    fc.box(root, "Rahmenlicht", (W - 0.4, 0.012, 0.004), (0, -D * 0.5 + 0.03, 0.162), seam)
    # Kupferschienen: je Block zwei, rechts der Sammler mit dem Bus-Abgang.
    right = W * 0.5 - 0.2
    for row in (0, 2):
        y = cy(row)
        for k in (-1, 1):
            fc.box(root, "Schiene", (S + CELL + 0.3, 0.08, 0.03), (cx(2) + S * 0.5 + 0.1,
                                                                    y + k * 0.36, top + 0.015),
                   copper)
    fc.box(root, "Sammler", (0.09, 2 * S + 0.84, 0.035), (right, 0, top + 0.018), copper)
    for row in (0, 2):
        for k in (-1, 1):
            fc.cyl(root, "Bolzen", 0.05, 0.03, (right, cy(row) + k * 0.36, top + 0.045), chrome,
                   verts=6)
    for i, sort in enumerate(CHARGE):
        x, y = slot(i)
        hgt = 0.6
        fc.cyl(root, "Kragen", 0.29, 0.05, (x, y, top + 0.025), chrome, verts=40)
        fc.cyl(root, "Dose", 0.27, hgt, (x, y, top + hgt * 0.5), sleeve, verts=40)
        fc.cyl(root, "Deckel", 0.255, 0.02, (x, y, top + hgt + 0.01), alu, verts=40)
        fc.cyl(root, "Polfenster", 0.17, 0.008, (x, y, top + hgt + 0.022),
               glow(sort, 2.8) if sort else glass, verts=40)
        for a in (0, 90):
            rbox(root, "Kerbe", (0.34, 0.014, 0.004), (x, y, top + hgt + 0.027), alu,
                 (0, 0, math.radians(a + 45)))
        for k in range(3):
            torus(root, "Ring", 0.273, 0.013, (x, y, top + 0.16 + k * 0.15), glow(sort, 3.0))
    for (c, r) in NET:
        x, y = cx(c), cy(r)
        led.rounded_box(root, "Zellsaum", (0.98, 0.98, 0.01), (x, y, top + 0.005), seam, 0.12, 0.0,
                        6)
        led.rounded_box(root, "Zellblock", (0.9, 0.9, 0.2), (x, y, top + 0.1), glass, 0.1, 0.03, 6)
        content(root, c, r, top + 0.203, 0.8)
    # Zeigerinstrument oben links.
    gx, gy = cx(0), cy(0)
    fc.cyl(root, "Skalengrund", 0.42, 0.05, (gx, gy, top + 0.025), glass, verts=48)
    torus(root, "Skalenring", 0.42, 0.02, (gx, gy, top + 0.05), chrome)
    pivot = (gx, gy - 0.16)
    for i, sort in enumerate(CHARGE):
        a = math.radians(150 - 120 * (i + 0.5) / 6.0)
        rbox(root, "Strich%d" % i, (0.11, 0.045, 0.004),
             (pivot[0] + math.cos(a) * 0.44, pivot[1] + math.sin(a) * 0.44, top + 0.053),
             glow(sort, 3.2), (0, 0, a))
    a = math.radians(150 - 120 * stored() / 6.0)
    rbox(root, "Zeiger", (0.36, 0.022, 0.006),
         (pivot[0] + math.cos(a) * 0.18, pivot[1] + math.sin(a) * 0.18, top + 0.06),
         led.mat("Zeigerlicht", (1.0, 0.45, 0.08), 0.0, 0.3, 3.0), (0, 0, a))
    fc.cyl(root, "Zeigerlager", 0.04, 0.02, (pivot[0], pivot[1], top + 0.062), chrome, verts=24)
    # Ringkern-Spule unten links, an die untere Schiene geführt.
    hx, hy = cx(0), cy(2)
    fc.cyl(root, "Spulenteller", 0.44, 0.02, (hx, hy, top + 0.01), rim, verts=48)
    torus(root, "Spule", 0.27, 0.13, (hx, hy, top + 0.15), copper)
    for k in range(18):
        a = math.radians(k * 20)
        torus(root, "Wicklung", 0.135, 0.008, (hx + math.cos(a) * 0.27, hy + math.sin(a) * 0.27,
                                               top + 0.15), tray, rot=(math.radians(90), 0, a))
    fc.cyl(root, "Spulenbolzen", 0.07, 0.3, (hx, hy, top + 0.15), chrome, verts=6)
    # Klemmleiste vorn: je Scheibe vier Klemmen auf dem Rahmen.
    for i in range(6):
        gx2 = -W * 0.5 + 0.4 + (W - 0.8) * (i + 0.5) / 6.0
        for lane in range(4):
            fc.box(root, "Klemme", (0.055, 0.055, 0.012), (gx2 + (lane - 1.5) * 0.09,
                                                           -D * 0.5 + 0.03, 0.166),
                   lane_mat(i, lane))


VARIANTS = [("A_platine", platine), ("B_rack", rack), ("C_elkobank", elkobank)]


# --- Bühne --------------------------------------------------------------------------------

def hide_softboxes():
    for o in bpy.data.objects:
        if o.type == "MESH" and o.data.materials and o.data.materials[0].name.startswith("Softbox"):
            o.hide_render = True


def place(build, x):
    root = fc.empty("Speicher")
    build(root)
    root.location = (x, 0, 0)


def render_variant(tag, build):
    for view in ("held", "spiel"):
        fc.stage((1600, 1000))
        place(build, 0.0)
        if view == "held":
            fc.camera((3.7, -6.3, 5.0), (0.0, -0.15, 0.1), 42)
        else:
            hide_softboxes()
            fc.camera((0, -3.0, 9.6), (0, -0.05, 0.1), 45)
        fc.shoot("%s_%s" % (tag, view))


def render_row():
    fc.stage((2400, 900))
    for i, (tag, build) in enumerate(VARIANTS):
        place(build, (i - 1) * 6.5)
    hide_softboxes()
    fc.camera((0, -5.0, 16.6), (0, 0.0, 0.1), 32)
    fc.shoot("0_alle_drei")


def main():
    os.makedirs(OUT, exist_ok=True)
    fc.OUT = OUT
    only = ARGS[1] if len(ARGS) > 1 else ""
    for tag, build in VARIANTS:
        if only in ("", tag):
            render_variant(tag, build)
    if only in ("", "reihe"):
        render_row()
    print("ok")


if __name__ == "__main__":
    main()
