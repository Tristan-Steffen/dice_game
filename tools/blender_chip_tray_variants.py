"""Fumble: ENTWURF - die Station CHIPS als Bauteil der Platine (2026-11-24), drei Fassungen.
  a_schieberegister - Stahlrahmen, hinterleuchtete Wert-Kappen, Gabel-Lichtschranke, Hubmagnet-Riegel
  b_feeder          - je Rinne die Spur eines Gurt-Feeders: Zahnrad-Fenster, Etikett, Abnahme-Klappe
  c_speicherbank    - je Rinne ein Speicher-Steckplatz mit weißen Riegeln, Prägung und LED-Leiste
Maßstab: Blender = Welt × 0,25 (Grube 10,36 × 15,20 Welt = 2,59 × 3,8).

Aufruf (kopflos):
  blender -b -P tools/blender_chip_tray_variants.py -- <ausgabe-ordner> [ansicht,...]
Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tischfläche bei Z = 0.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms
import blender_chip_screens as cs

led = dm.led
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."

S = 0.25
PW, PH = 10.36 * S, 15.20 * S
X0, X1, Y0, Y1 = -PW * 0.5, PW * 0.5, -PH * 0.5, PH * 0.5
PY = PH / 7.0
R, HC = 0.9 * S, 0.28 * S
PITCH = (0.28 + 0.02) * S
TR = 0.94 * S
TILT = math.radians(6.0)
TOP_CLEAR = 0.1 * S
DEPTH = 3.6 * S
GATE_T, GATE_AIR, GATE_H = 0.12 * S, (0.03 + 0.9 * 0.1046) * S, 0.99 * S
FLOOR_T = 0.12 * S
SLOT_TOP = 0.85 * S
L = PW / math.cos(TILT)
GATE_S = L - GATE_T - GATE_AIR
ENTRY_S = 0.17
FLOOR0 = -(TOP_CLEAR + 2 * R)

VALUES = [1, 5, 25, 100, 500, 2500, 10000]
RATIOS = [5, 5, 4, 5, 5, 4]
CAP = 20
LABELS = ["1", "5", "25", "100", "500", "2,5K", "10K"]
# Farben aus ChipStackView.DENOMINATIONS: (Neon, Körper, Akzent)
CHIP = {1: ("#2f9ff0", (0.05, 0.11, 0.32), (0.24, 0.66, 0.98)),
        5: ("#fe5f55", (0.40, 0.05, 0.09), (1.0, 0.37, 0.33)),
        25: ("#3ef08a", (0.03, 0.22, 0.11), (0.34, 0.95, 0.58)),
        100: ("#ffcf40", (0.06, 0.05, 0.08), (1.0, 0.80, 0.30)),
        500: ("#b56cff", (0.20, 0.06, 0.34), (0.74, 0.46, 1.0)),
        2500: ("#ff9a2e", (0.42, 0.16, 0.02), (1.0, 0.62, 0.22)),
        10000: ("#e8eef8", (0.50, 0.52, 0.58), (0.86, 0.92, 1.0))}
for _v, (_h, _b, _a) in CHIP.items():
    dm.HEX["c%d" % _v] = _h
dm.HEX["weiss"] = "#e6e9f2"
dm.HEX["bernstein"] = "#ffb347"
dm.HEX["kuehl"] = "#8be9fd"


def belegung(money):
    """Die Regel des Spiels: von unten gefüllt, jede Rinne bis CAP, erst der Überschuß tauscht."""
    counts, units = [0] * 7, max(money, 0)
    for r in range(6):
        k = RATIOS[r]
        res = units % k
        counts[r] = res + k * ((min(CAP, units) - res) // k)
        units = (units - counts[r]) // k
    counts[6] = units
    return counts


def srgb(c):
    return tuple(v ** 2.2 for v in c)


# --- Materialien ---------------------------------------------------------------------------

def m_board():
    return led.mat("Masse", (0.006, 0.03, 0.018), 0.0, 0.55, 0.35, clearcoat=0.3)


def m_mask():
    return led.mat("Zugmaske", (0.02, 0.1, 0.05), 0.2, 0.45, 0.6, clearcoat=0.3)


def m_silk():
    return led.mat("Druck", (0.78, 0.8, 0.72), 0.0, 0.6, 0.45)


def m_gold():
    return led.mat("PadGold", (0.83, 0.6, 0.22), 1.0, 0.3, 0.05)


def m_lining():
    return led.mat("Rinnenhaut", (0.014, 0.02, 0.026), 0.4, 0.35, 0.4, clearcoat=0.5)


def m_pit():
    return led.mat("Grubenwand", (0.01, 0.014, 0.018), 0.0, 0.6, 0.3)


def m_black():
    return led.mat("Lack", (0.01, 0.01, 0.012), 0.0, 0.25, 0.15, clearcoat=1.0)


def m_dim():
    return led.mat("Dunkelglas", (0.004, 0.004, 0.006), 0.0, 0.05, clearcoat=1.0)


def chip_mats(v):
    hx, body, acc = CHIP[v]
    return (led.mat("ChipKoerper%d" % v, srgb(body), 0.0, 0.35, 1.6, clearcoat=0.6),
            led.mat("ChipAkzent%d" % v, srgb(acc), 0.0, 0.3, 0.9),
            led.mat("ChipSeite%d" % v, srgb(body), 0.0, 0.3, 0.75, clearcoat=0.8))


# --- Grundformen ---------------------------------------------------------------------------

def mesh_obj(parent, name, verts, faces, mats, mat_idx=None, smooth=False):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    for m in mats:
        mesh.materials.append(m)
    if mat_idx:
        for poly, k in zip(mesh.polygons, mat_idx):
            poly.material_index = k
    if smooth:
        for poly in mesh.polygons:
            poly.use_smooth = True
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    return o


def chips(parent, name, value, pts, lift=None):
    """Hochkante Chips, Achse längs lokal X, als EIN Netz: Rand mit vier Einlagen, zwei Deckel."""
    n = 28
    verts, faces, idx = [], [], []
    for i, (cx, cy, cz) in enumerate(pts):
        b = len(verts)
        for sx in (-HC * 0.5, HC * 0.5):
            for k in range(n):
                t = math.tau * k / n
                verts.append((cx + sx, cy + math.cos(t) * R, cz + math.sin(t) * R))
        for k in range(n):
            j = (k + 1) % n
            faces.append([b + k, b + j, b + n + j, b + n + k])
            idx.append(1 if (k + 3 + (i % 2) * 3) % 7 == 0 else 0)
        faces.append([b + k for k in range(n)][::-1])
        idx.append(2)
        faces.append([b + n + k for k in range(n)])
        idx.append(2)
    return mesh_obj(parent, name, verts, faces, chip_mats(value), idx, True)


def half_pipe(parent, name, x0, x1, radius, material, z=0.0):
    n = 20
    verts, faces = [], []
    for x in (x0, x1):
        for k in range(n + 1):
            t = math.pi + math.pi * k / n
            verts.append((x, math.cos(t) * radius, z + math.sin(t) * radius))
    for k in range(n):
        faces.append([k, k + 1, n + 2 + k, n + 1 + k])
    return mesh_obj(parent, name, verts, faces, [material], smooth=True)


def ring(cx, cy, ox, oy, ix, iy, z, h):
    return cs.ring_items(cx, cy, ox, oy, ix, iy, z, h)


def rank_y(r):
    return Y0 + PY * (r + 0.5)


def to_world(s, lz, y=0.0):
    """Ein Punkt der Rinne (Länge s, Höhe lz über der Achse) im Rahmen der Station."""
    ax = X0 + TR * math.sin(TILT)
    az = FLOOR0 + TR * math.cos(TILT)
    return (ax + s * math.cos(TILT) + lz * math.sin(TILT), y, az - s * math.sin(TILT) + lz * math.cos(TILT))


def gutter_frame(parent, r):
    g = cs.root("Rinne%d" % r)
    g.parent = parent
    g.location = to_world(0, 0, rank_y(r))
    g.rotation_euler = (0, TILT, 0)
    return g


def slot_s(i):
    return GATE_S - HC * 0.5 - i * PITCH


FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "fonts", "AnonymousPro-Bold.ttf")


def txt(parent, body, x, y, z, size, material, name="Text"):
    t = cs.text(parent, body, x, y, z, size, material, name)
    if os.path.exists(FONT):
        t.data.font = bpy.data.fonts.load(FONT, check_existing=True)
    return t


# --- die gemeinsame Mechanik -----------------------------------------------------------------

def base(st, counts, state, steg_top=0.0):
    """Grube, Rinnen, Stege bis steg_top (lokal über der Achse) und die Chips samt Zustand.
    state: None oder "carry" (Rinne 0 gibt fünf ab, Rinne 1 bekommt einen aus dem Tisch)."""
    w = 0.03
    cs.boxes(st, "Grubenwand", [(X0 - w * 0.5, 0, -DEPTH * 0.5, w, PH + 2 * w, DEPTH),
                                (0, Y0 - w * 0.5, -DEPTH * 0.5, PW, w, DEPTH),
                                (0, Y1 + w * 0.5, -DEPTH * 0.5, PW, w, DEPTH),
                                (X1 + w * 0.5, 0, -SLOT_TOP * 0.5, w, PH + 2 * w, SLOT_TOP)], m_pit())
    cs.boxes(st, "Tasche", [(X1 + 0.3, 0, -DEPTH * 0.5 - SLOT_TOP * 0.5, 0.5, PH, DEPTH - SLOT_TOP),
                            (0, 0, -DEPTH - 0.01, PW, PH, 0.02)], led.mat("Nacht", (0.002, 0.002, 0.003), 0.0, 0.9))
    gates = {}
    for r in range(7):
        g = gutter_frame(st, r)
        half_pipe(g, "Rinne", 0, L + 0.25, TR, m_lining())
        n = counts[r]
        pts = []
        if state == "carry" and r == 0:
            pts = [(slot_s(i), 0, R - TR) for i in range(5, 5 + n - 5)]
            pts += [(GATE_S + 0.01, 0, R - TR - 0.02), (GATE_S + 0.085, 0, R - TR - 0.035)]
        else:
            shown = min(n, 24)
            pts = [(slot_s(i), 0, R - TR) for i in range(shown)]
        if state == "carry" and r == 1:
            pts.append((ENTRY_S, 0, R - TR - R * 0.9))
        if pts:
            chips(g, "Chips%d" % r, VALUES[r], pts)
        gates[r] = g
    # Stege zwischen und neben den Rinnen
    sw = PY - 2 * TR + 0.008
    for k in range(8):
        g = cs.root("Steg%d" % k)
        g.parent = st
        g.location = to_world(0, 0, Y0 + PY * k)
        g.rotation_euler = (0, TILT, 0)
        h = TR + FLOOR_T + steg_top
        cs.boxes(g, "Steg", [((L + 0.25) * 0.5, 0, steg_top - h * 0.5, L + 0.25, sw if 0 < k < 7 else sw * 0.5, h)],
                 STEG[0])
    return gates


STEG = [None]
# Halbe Breite der Platinen-Kachel je Station; Stationen stehen 2 × TILE auseinander.
TILE = 2.3
GROUND = [TILE]


def ground(st, hole, extra=()):
    """Massefläche mit Loch (x0, y0, x1, y1), Bestückungsdruck, drei Züge zum Haupt-Bus."""
    x0, y0, x1, y1 = hole
    hw, hh = GROUND[0], 6.0
    t = 0.04
    cs.boxes(st, "Masse", [((x0 - hw) * 0.5, 0, -t * 0.5, hw + x0, hh * 2, t),
                           ((x1 + hw) * 0.5, 0, -t * 0.5, hw - x1, hh * 2, t),
                           ((x0 + x1) * 0.5, (y1 + hh) * 0.5, -t * 0.5, x1 - x0, hh - y1, t),
                           ((x0 + x1) * 0.5, (y0 - hh) * 0.5, -t * 0.5, x1 - x0, hh + y0, t)], m_board())


def bus(st, x, y_top, label_at):
    """Drei Züge nach unten zum Haupt-Bus, Gold-Pads an beiden Enden, Druck U8 CHIPS."""
    yb = y_top - 0.55
    lines, pads = [], []
    for k in range(3):
        xx = x + (k - 1) * 0.09
        lines.append([(xx, y_top - 0.04), (xx, yb + 0.05 + k * 0.0)])
        pads.append((xx, y_top - 0.04, 0.002, 0.06, 0.07, 0.004))
    for k in range(3):
        yy = yb - k * 0.09
        lines.append([(-TILE, yy), (TILE, yy)])
        pads.append((x + (k - 1) * 0.09, yy, 0.002, 0.06, 0.06, 0.004))
    cs.strips(st, "Zuege", lines, 0.035, 0.001, m_mask())
    cs.boxes(st, "Pads", pads, m_gold())
    txt(st, "U8 CHIPS", label_at[0], label_at[1], 0.001, 0.13, m_silk(), "U8")


# --- A: SCHIEBEREGISTER ----------------------------------------------------------------------

def variant_a(st, counts, state):
    steel = cs.m_steel()
    STEG[0] = led.mat("StegStahl", (0.22, 0.23, 0.26), 1.0, 0.4, 0.03)
    hx0, hx1 = X0 - 0.5, X1 + 0.36
    fy = 0.11
    ground(st, (X0, Y0, X1, Y1))
    gates = base(st, counts, state)
    # Stahlrahmen samt Kopfspalte
    frame = led.rounded_box(st, "Rahmen", (hx1 - hx0, PH + 2 * fy, 0.05), ((hx0 + hx1) * 0.5, 0, 0.025), steel,
                            0.06, 0.01)
    led.cut(frame, led.rounded_box(st, "RahmenLoch", (PW, PH, 0.3), (0, 0, 0), steel, 0.01, 0.0))
    cs.boxes(st, "Innensaum", ring(0, 0, PW + 0.012, PH + 0.012, PW, PH, 0.046, 0.008),
             led.mat("Saumlicht", srgb((0.55, 0.7, 0.85)), 0.0, 0.3, 0.6))
    # Takt-Schiene mit sieben Abgängen
    tx = hx0 + 0.07
    clk = dm.glow("kuehl", 0.9)
    lines = [[(tx, Y0 + 0.05), (tx, Y1 - 0.05)]]
    lines += [[(tx, rank_y(r)), (X0 - 0.4, rank_y(r))] for r in range(7)]
    cs.strips(st, "Takt", lines, 0.016, 0.0515, clk)
    cs.boxes(st, "Taktknoten", [(tx, rank_y(r), 0.053, 0.03, 0.03, 0.004) for r in range(7)], clk)
    # Wert-Kappen
    for r in range(7):
        v = VALUES[r]
        y = rank_y(r)
        cx = X0 - 0.2
        led.rounded_box(st, "Kappe%d" % r, (0.36, PY - 0.09, 0.04), (cx, y, 0.07), steel, 0.04, 0.012)
        led.rounded_box(st, "Fenster%d" % r, (0.3, PY - 0.15, 0.006), (cx, y, 0.09), m_dim(), 0.03, 0.0)
        cs.boxes(st, "KappenSaum%d" % r, ring(cx, y, 0.3, PY - 0.15, 0.284, PY - 0.166, 0.0935, 0.002),
                 dm.glow("c%d" % v, 1.1))
        txt(st, LABELS[r], cx, y, 0.0935, 0.17 if len(LABELS[r]) < 4 else 0.13, dm.glow("c%d" % v, 2.2), "Wert%d" % r)
    # Gabel-Lichtschranke je Rinne am Einlauf
    fork = m_black()
    for r in range(7):
        g = gates[r]
        s = ENTRY_S + 0.02
        cs.boxes(g, "Gabel", [(s, sy * (TR + 0.025), -0.01, 0.06, 0.035, 0.17) for sy in (-1, 1)] +
                 [(s - 0.04, 0, 0.085, 0.03, 2 * TR + 0.085, 0.03)], fork)
        hit = state == "carry" and r == 1
        cs.boxes(g, "Strahl", [(s, 0, 0.03, 0.008, 2 * TR + 0.02, 0.008)],
                 dm.glow("bernstein" if hit else "weiss", 2.4 if hit else 0.9))
    # Hubmagnet-Riegel rechts
    for r in range(7):
        g = gates[r]
        open_ = state == "carry" and r == 0
        dz = -GATE_H * 0.9 if open_ else 0.0
        cs.boxes(g, "Riegel", [(GATE_S + GATE_T * 0.5, 0, -TR + GATE_H * 0.5 + dz, GATE_T, 2 * R, GATE_H)],
                 led.mat("Riegelstahl", (0.6, 0.62, 0.66), 1.0, 0.25, 0.1))
        y = rank_y(r)
        mx = X1 + 0.13
        dm.cyl(st, "Spule%d" % r, 0.085, 0.11, (mx, y, 0.105),
               led.mat("Spulenkupfer", (0.8, 0.4, 0.22), 1.0, 0.3, 0.05), 40)
        dm.cyl(st, "Kappe%d" % r, 0.07, 0.012, (mx, y, 0.166), steel, 40)
        dm.annulus(st, "Status%d" % r, mx, y, 0.1725, 0.03, 0.05,
                   dm.glow("bernstein", 2.6) if open_ else led.mat("StatusAus", (0.08, 0.06, 0.03), 0.0, 0.4, 0.3), 40)
        cs.boxes(st, "Arm%d" % r, [((X1 - 0.07 + mx) * 0.5, y, 0.07, mx - X1 + 0.05, 0.035, 0.02)], steel)
        gx, _, gz = to_world(GATE_S + GATE_T * 0.5, -TR + GATE_H + dz, y)
        dm.beam(st, "Stoessel%d" % r, (X1 - 0.07, y, 0.07), (X1 - 0.07, y, gz + 0.02), 0.012, steel)
    # Übertrag-Lampen zwischen den Rinnen
    for r in range(6):
        y = (rank_y(r) + rank_y(r + 1)) * 0.5
        lx = X1 + 0.29
        lit = state == "carry" and r == 0
        dm.cyl(st, "Lampe%d" % r, 0.045, 0.03, (lx, y, 0.065), m_dim(), 32)
        tri = [(lx - 0.025, y - 0.018), (lx + 0.025, y - 0.018), (lx, y + 0.026)]
        dm.box.decal(st, "Pfeil%d" % r, dm.top(0.081), tri,
                     dm.glow("bernstein", 3.0) if lit else led.mat("PfeilAus", (0.12, 0.09, 0.04), 0.0, 0.4, 0.35))
    bus(st, 0.0, Y0 - fy, (hx0 + 0.42, Y1 + fy + 0.14))
    return (hx0, hx1)


# --- B: BAUTEIL-FEEDER -------------------------------------------------------------------------

def gear(parent, name, x, y, z, rad, material, teeth=14):
    dm.cyl(parent, name, rad, 0.012, (x, y, z), material, 40)
    items = []
    for k in range(teeth):
        t = math.tau * k / teeth
        items.append((x + math.cos(t) * rad, y + math.sin(t) * rad, z, 0.022, 0.022, 0.012))
    cs.boxes(parent, name + "Zahn", items, material)
    dm.cyl(parent, name + "Nabe", rad * 0.3, 0.016, (x, y, z + 0.002), m_black(), 24)


def variant_b(st, counts, state):
    plate = led.mat("Eloxal", (0.42, 0.45, 0.5), 1.0, 0.3, 0.12)
    STEG[0] = led.mat("StegDunkel", (0.05, 0.055, 0.065), 0.8, 0.4, 0.05)
    ground(st, (X0, Y0, X1, Y1))
    gates = base(st, counts, state)
    # je Spur zwei Seitenplatten auf der Fläche, dazwischen die dunkle Fuge zur Nachbarspur
    xa, xb = X0 - 0.62, X1 + 0.32
    plates, holes = [], []
    for k in range(8):
        y = Y0 + PY * k
        for sy in (-1, 1):
            if (k == 0 and sy < 0) or (k == 7 and sy > 0):
                continue
            yy = y + sy * 0.022
            plates.append(((xa + xb) * 0.5, yy, 0.025, xb - xa, 0.03, 0.05))
            if sy < 0:
                holes += [(X0 + 0.06 + j * 0.1, yy, 0.0505, 0.018, 0.018, 0.002) for j in range(int(PW / 0.1))]
    cs.boxes(st, "Seitenplatten", plates, plate)
    cs.boxes(st, "Transportloecher", holes, led.mat("Loch", (0.0, 0.0, 0.0), 0.0, 0.9))
    hx0 = X0 - 0.62
    for r in range(7):
        v = VALUES[r]
        y = rank_y(r)
        g = gates[r]
        # Feeder-Kopf links
        w = PY - 0.04
        led.rounded_box(st, "Kopf%d" % r, (0.66, w, 0.09), (X0 - 0.27, y, 0.045), m_black(), 0.05, 0.01)
        cs.boxes(st, "Kopfplatte%d" % r, [(X0 - 0.27, y + s * (w * 0.5 - 0.01), 0.05, 0.66, 0.02, 0.1)
                                          for s in (-1, 1)], plate)
        gx = X0 - 0.43
        win = 0.12
        dm.cyl(st, "Fenstergrund%d" % r, win, 0.004, (gx, y, 0.092), led.mat("Nacht", (0.002, 0.002, 0.003)), 48)
        dm.annulus(st, "Fensterring%d" % r, gx, y, 0.095, win, win + 0.02, plate, 48)
        turning = state == "carry" and r == 1
        gear(st, "Zahnrad%d" % r, gx, y, 0.1, 0.085,
             led.mat("RadStahl", (0.7, 0.72, 0.76), 1.0, 0.25, 0.25), 14)
        dm.cyl(st, "Glas%d" % r, win, 0.004, (gx, y, 0.11),
               led.mat("Sichtglas", (0.6, 0.8, 1.0), 0.0, 0.03, 0.0, 0.12), 48)
        dm.annulus(st, "Radlicht%d" % r, gx, y, 0.1125, win - 0.012, win,
                   dm.glow("c%d" % v, 2.4 if turning else 0.5), 48)
        # Etikett-Schild in Chipfarbe
        ex = X0 - 0.15
        lab = led.mat("Etikett%d" % v, srgb(CHIP[v][2]), 0.0, 0.5, 0.9)
        led.rounded_box(st, "Etikett%d" % r, (0.24, w - 0.1, 0.006), (ex, y, 0.093), lab, 0.015, 0.0)
        txt(st, LABELS[r], ex, y + 0.01, 0.0965, 0.12 if len(LABELS[r]) < 4 else 0.085,
            led.mat("EtikettSchrift", (0.01, 0.01, 0.015), 0.0, 0.6), "Wert%d" % r)
        cs.boxes(st, "Strichcode%d" % r, [(ex - 0.08 + k * 0.016, y - 0.13, 0.0965, 0.007 if k % 3 else 0.012, 0.04, 0.001)
                                          for k in range(10)], led.mat("EtikettSchrift", (0.01, 0.01, 0.015)))
        # Abnahme-Klappe rechts: hängt an der Achse über der Sperre
        open_ = state == "carry" and r == 0
        hz = -TR + GATE_H
        hinge = cs.root("Klappe%d" % r)
        hinge.parent = g
        hinge.location = (GATE_S, 0, hz)
        hinge.rotation_euler = (0, math.radians(-75) if open_ else 0, 0)
        cs.boxes(hinge, "Klappe", [(GATE_T * 0.5, 0, -GATE_H * 0.5, GATE_T, 2 * R, GATE_H)],
                 led.mat("Klappe", (0.5, 0.52, 0.56), 1.0, 0.3, 0.06))
        cs.boxes(hinge, "Klappenlicht", [(GATE_T + 0.002, 0, -GATE_H * 0.5, 0.003, 2 * R - 0.04, 0.012)],
                 dm.glow("bernstein", 2.6) if open_ else dm.glow("c%d" % v, 0.4))
        dm.cyl(hinge, "Achse", 0.012, 2 * TR + 0.03, (0, 0, 0), plate, 16).rotation_euler = (math.radians(90), 0, 0)
        # Feeder-Nase rechts mit der Abnahme-Klappe obenauf
        led.rounded_box(st, "Nase%d" % r, (0.34, w, 0.07), (X1 + 0.15, y, 0.035), m_black(), 0.05, 0.01)
        cs.boxes(st, "Nasenplatte%d" % r, [(X1 + 0.15, y + s * (w * 0.5 - 0.01), 0.04, 0.34, 0.02, 0.08)
                                           for s in (-1, 1)], plate)
        cs.boxes(st, "Abnahmeschacht%d" % r, [(X1 + 0.15, y, 0.0705, 0.22, w - 0.12, 0.002)], m_dim())
        flap = cs.root("Abnahme%d" % r)
        flap.parent = st
        flap.location = (X1 + 0.27, y, 0.074)
        flap.rotation_euler = (0, math.radians(55) if open_ else 0, 0)
        led.rounded_box(flap, "Deckel", (0.22, w - 0.1, 0.012), (-0.115, 0, 0.006),
                        led.mat("Klappe", (0.5, 0.52, 0.56), 1.0, 0.3, 0.06), 0.012, 0.003)
        cs.boxes(flap, "Deckellicht", [(-0.2, 0, 0.0125, 0.012, w - 0.14, 0.002)],
                 dm.glow("bernstein", 2.8) if open_ else dm.glow("c%d" % v, 0.7))
        dm.cyl(flap, "Scharnier", 0.012, w - 0.08, (0, 0, 0.004), plate, 16).rotation_euler = (math.radians(90), 0, 0)
    # Greifer-Brücke rechts: der Greifer springt beim Übertrag eine Spur höher
    gx = X1 + 0.46
    cs.boxes(st, "Bruecke", [(gx, 0, 0.04, 0.07, PH + 0.1, 0.08)], plate)
    cs.boxes(st, "BrueckeSchiene", [(gx, 0, 0.082, 0.02, PH, 0.004)], m_dim())
    at = 0.5 if state == "carry" else 3.0
    gy = Y0 + PY * (at + 0.5)
    led.rounded_box(st, "Greifer", (0.16, 0.2, 0.06), (gx, gy, 0.11), m_black(), 0.03, 0.01)
    dm.annulus(st, "Greiferlicht", gx, gy, 0.141, 0.035, 0.055,
               dm.glow("bernstein" if state == "carry" else "weiss", 3.0 if state == "carry" else 0.8), 32)
    if state == "carry":
        cs.strips(st, "Sprung", [[(gx - 0.09, rank_y(0)), (gx - 0.09, rank_y(1))]], 0.012, 0.084, dm.glow("bernstein", 2.0))
    cs.boxes(st, "Feederbank", [(X0 - 0.3, 0, 0.002, 0.7, PH + 0.14, 0.004)], led.mat("Bankplatte", (0.03, 0.03, 0.035), 0.6, 0.4, 0.2))
    bus(st, 0.0, Y0 - 0.04, (hx0 + 0.4, Y1 + 0.16))
    return (hx0, gx + 0.1)


# --- C: SPEICHERBANK -------------------------------------------------------------------------

def latch(parent, name, x, y, side, open_, lit=False):
    """Weißer Riegel-Hebel: steht am Ende des Steckplatzes, offen kippt er nach außen."""
    h = cs.root(name)
    h.parent = parent
    h.location = (x, y, 0.0)
    h.rotation_euler = (0, side * math.radians(48) if open_ else 0, 0)
    white = led.mat("Riegelweiss", (0.8, 0.82, 0.86), 0.0, 0.35, 0.55, clearcoat=0.6)
    led.rounded_box(h, "Hebel", (0.07, 0.22, 0.2), (0, 0, 0.1), white, 0.02, 0.01)
    led.rounded_box(h, "Griff", (0.1, 0.22, 0.04), (side * 0.02, 0, 0.21), white, 0.02, 0.012)
    cs.boxes(h, "Nase", [(-side * 0.035, 0, 0.17, 0.02, 0.12, 0.05)], white)
    if lit:
        cs.boxes(h, "Rastlicht", [(0, 0, 0.232, 0.06, 0.18, 0.004)], dm.glow("bernstein", 2.6))


def variant_c(st, counts, state):
    gloss = led.mat("SlotSchwarz", (0.012, 0.012, 0.014), 0.0, 0.18, 0.2, clearcoat=1.0)
    STEG[0] = gloss
    ground(st, (X0, Y0, X1, Y1))
    gates = base(st, counts, state)
    gold = m_gold()
    # die Steckplatz-Wangen liegen auf der Fläche zwischen den Rinnen
    cs.boxes(st, "Wangen", [((X0 + X1 + 0.08) * 0.5, Y0 + PY * k, 0.028, PW + 0.08, 0.078 if 0 < k < 7 else 0.05, 0.056)
                            for k in range(8)], gloss)
    cs.boxes(st, "Wangenkante", [((X0 + X1) * 0.5, Y0 + PY * k + sy * 0.034, 0.0565, PW - 0.1, 0.004, 0.002)
                                 for k in range(8) for sy in (-1, 1) if (0 < k or sy > 0) and (k < 7 or sy < 0)],
             led.mat("Wangenlicht", srgb((0.6, 0.62, 0.7)), 0.0, 0.4, 0.35))
    for r in range(7):
        v = VALUES[r]
        y = rank_y(r)
        g = gates[r]
        # Goldkontakte am Boden der Rinne
        cs.boxes(g, "Kontakte", [(0.2 + k * 0.06, 0, -TR + 0.004, 0.025, 0.06, 0.004)
                                 for k in range(int((L - 0.3) / 0.06))], gold)
        # Kragen links: Prägung des Werts
        cx = X0 - 0.22
        led.rounded_box(st, "Kragen%d" % r, (0.44, PY - 0.03, 0.06), (cx, y, 0.03), gloss, 0.025, 0.008)
        txt(st, LABELS[r], cx - 0.05, y, 0.0605, 0.14 if len(LABELS[r]) < 4 else 0.1,
            led.mat("Praegung%d" % v, srgb(CHIP[v][2]), 0.4, 0.35, 1.3), "Wert%d" % r)
        cs.boxes(st, "Kodierkerbe%d" % r, [(cx - 0.2, y, 0.061, 0.012, PY * 0.4, 0.002)], gold)
        # Füllstands-Leiste: vier LEDs für 5/10/15/20
        n = counts[r]
        lit = min(4, n // 5)
        for k in range(4):
            on = k < lit
            dm.cyl(st, "Led%d_%d" % (r, k), 0.02, 0.012, (X0 - 0.055, y + (k - 1.5) * 0.095, 0.066),
                   dm.glow("c%d" % v, 1.8) if on else led.mat("LedAus", (0.03, 0.03, 0.035), 0.0, 0.2, 0.25), 20)
        # Riegel an beiden Enden
        open_ = state == "carry" and r == 0
        snap = state == "carry" and r == 1
        latch(st, "RiegelL%d" % r, X0 - 0.5, y, -1, False, snap)
        latch(st, "RiegelR%d" % r, X1 + 0.08, y, 1, open_, open_)
        dz = -GATE_H * 0.9 if open_ else 0.0
        cs.boxes(g, "Sperre", [(GATE_S + GATE_T * 0.5, 0, -TR + GATE_H * 0.5 + dz, GATE_T, 2 * R, GATE_H)],
                 led.mat("SperreWeiss", (0.75, 0.77, 0.8), 0.0, 0.4, 0.3))
        txt(st, "CH%d" % r, X1 + 0.3, y, 0.001, 0.06, m_silk(), "Kanal%d" % r)
    # Platinenlage unter der Bank: Lötaugen der Steckplätze
    cs.boxes(st, "Loetaugen", [(x, rank_y(r) + sy * (PY * 0.5 - 0.02), 0.001, 0.03, 0.03, 0.002)
                               for r in range(7) for sy in (-1, 1) for x in (X0 - 0.62, X1 + 0.2)], gold)
    bus(st, 0.0, Y0 - 0.04, (X0 - 0.2, Y1 + 0.17))
    return (X0 - 0.62, X1 + 0.3)


# --- A2: SCHIEBEREGISTER, Runde 2 --------------------------------------------------------------

def variant_a2(st, counts, state):
    """Wie A, dazu: Füllmarken je Rinne, Übertrag als Lichtweg am Kopf, ×n an der 10K-Kappe."""
    out = variant_a(st, counts, state)
    sw = PY - 2 * TR + 0.008
    for r in range(7):
        g = gutter_frame(st, r)
        v = VALUES[r]
        n = min(counts[r], CAP)
        dim, lit, cap = [], [], []
        for mark in (5, 10, 15, 20):
            item = (GATE_S - mark * PITCH, -PY * 0.5, 0.003, 0.014 if mark < 20 else 0.022, sw * 0.9, 0.004)
            (cap if mark == 20 else (lit if n >= mark else dim)).append(item)
        if dim:
            cs.boxes(g, "MarkeAus", dim, led.mat("MarkeAus", (0.3, 0.32, 0.36), 0.0, 0.5, 0.25))
        if lit:
            cs.boxes(g, "MarkeAn", lit, dm.glow("c%d" % v, 2.0))
        cs.boxes(g, "MarkeVoll", cap, dm.glow("bernstein" if counts[r] >= CAP else "weiss",
                                              2.6 if counts[r] >= CAP else 0.7))
        # ruhendes Statuslicht am Riegel: man sieht, wo es hinausgeht
        dm.annulus(st, "Ruhe%d" % r, X1 + 0.13, rank_y(r), 0.1727, 0.052, 0.062, dm.glow("weiss", 0.5), 40)
    if state == "carry":
        tx = X0 - 0.5 + 0.07
        cs.strips(st, "UebertragWeg", [[(tx, rank_y(0)), (tx, rank_y(1)), (X0 - 0.4, rank_y(1))]], 0.03, 0.054,
                  dm.glow("bernstein", 3.0))
        ym = (rank_y(0) + rank_y(1)) * 0.5
        dm.box.decal(st, "UebertragPfeil", dm.top(0.056), [(tx - 0.04, ym - 0.03), (tx + 0.04, ym - 0.03),
                                                           (tx, ym + 0.04)], dm.glow("bernstein", 3.0))
    if counts[6] > 5:
        txt(st, "×%d" % counts[6], X0 - 0.2, rank_y(6) - 0.15, 0.0935, 0.1, dm.glow("weiss", 2.2), "Mal")
    return out


VARIANTS = {"a": ("A · SCHIEBEREGISTER", variant_a), "b": ("B · BAUTEIL-FEEDER", variant_b),
            "c": ("C · SPEICHERBANK", variant_c), "a2": ("A2 · SCHIEBEREGISTER", variant_a2)}
STATES = [("LEER", 0, None), ("$137", 137, None), ("$4.860", 4860, None), ("ÜBERTRAG", 4860, "carry"), ("$182.000", 182000, None)]


def station(key, money, state, at=(0, 0)):
    st = cs.root("Station_" + key)
    counts = belegung(money)
    if state == "carry":
        counts[0] = 21
    VARIANTS[key][1](st, counts, state)
    st.location = (at[0], at[1], 0)
    return st


# --- Ansichten -----------------------------------------------------------------------------

def tilt_cam(cam, aim, target, dist, lens=50, tilt=15):
    aim.location = target
    t = math.radians(tilt)
    cam.location = Vector(target) + Vector((0, -math.sin(t), math.cos(t))) * dist
    cam.data.lens = lens


def view_single(key, kind):
    if kind == "zustaende":
        for i, (name, money, state) in enumerate(STATES):
            x = (i - (len(STATES) - 1) * 0.5) * 2 * TILE
            station(key, money, state, (x, 0))
            ms.label(name, x, -3.0, 0.26)
        return [("tilt", (0, -0.55, 0), 25.0 * len(STATES) / 4.0, 50)]
    GROUND[0] = 9.0
    # die Nahsicht zeigt den Übertrag: Sperre offen, Einlauf aus dem Tisch, Übertrag-Anzeige
    station(key, 4860, "carry" if kind == "detail" else None)
    if kind == "schraeg":
        return [("tilt", (0.0, -0.15, 0), 11.0, 50)]
    if kind == "oben":
        return [("tilt", (0.0, -0.15, 0), 11.0, 50, 0.01)]
    return [("free", (-0.15, -0.85, -0.15), (0.45, -3.9, 2.5), 32)]


def view_vergleich():
    for i, key in enumerate("abc"):
        x = (i - 1) * 2 * TILE
        station(key, 4860, None, (x, 0))
        ms.label(VARIANTS[key][0], x, -3.0, 0.24)
    return [("tilt", (0, -0.55, 0), 19.5, 50)]


def render(name, shots):
    cam, aim = CAM
    scene = bpy.context.scene
    for k, shot in enumerate(shots):
        if shot[0] == "tilt":
            tilt_cam(cam, aim, shot[1], shot[2], shot[3], shot[4] if len(shot) > 4 else 15)
        else:
            aim.location, cam.location, cam.data.lens = shot[1], shot[2], shot[3]
        scene.render.filepath = os.path.join(OUT, name + ".png")
        bpy.ops.render.render(write_still=True)


def stage():
    cam, aim = dm.empty_stage()
    for o in bpy.data.objects:
        mats = getattr(o.data, "materials", None) if o.data is not None else None
        if mats and mats[0] is not None and mats[0].name.startswith("Softbox"):
            o.location.z += 30.0
        if mats and mats[0] is not None and mats[0].name == "Filz":
            o.location.z = -1.5
            o.data.materials[0] = m_board()
        if o.type == "LIGHT":
            o.data.energy = 140
            o.location = (-3, 4, 9)
    scene = bpy.context.scene
    scene.eevee.taa_render_samples = 48
    scene.eevee.bloom_threshold = 1.0
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    cam.data.clip_end = 200
    return cam, aim


CAM = [None, None]
VIEWS = {}
for _k in ("a", "b", "c", "a2"):
    for _kind in ("schraeg", "oben", "detail", "zustaende"):
        VIEWS["%s_%s" % (_k, _kind)] = (lambda k=_k, kind=_kind: view_single(k, kind))
VIEWS["vergleich"] = view_vergleich

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    argv = sys.argv[sys.argv.index("--") + 1:]
    only = argv[1].split(",") if len(argv) > 1 else []
    for name, fn in VIEWS.items():
        if only and name not in only:
            continue
        CAM[0], CAM[1] = stage()
        GROUND[0] = TILE
        render(name, fn())
    print("ok")
