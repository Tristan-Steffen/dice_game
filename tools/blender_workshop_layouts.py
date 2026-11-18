"""Fumble: drei ENTWÜRFE für die neue Werkstatt (2026-11-18, zu docs/plan_werkstatt_walze.md).
  walze    - A: EINE liegende Walze aus sechs Scheiben, Karten hochkant, Kammer mit Kabeln
  doppel   - B: ZWEI Walzen zu drei Scheiben, Karten liegend, die Reihe knickt
  revolver - C: die Kammer in der Mitte, sechs Leser im Ring um sie herum
Blockmodelle: Maße in Karten-Einheiten (Karte 1,62 x 1,08), keine fertigen Leser.

Aufruf (kopflos):
  blender -b -P tools/blender_workshop_layouts.py -- <ausgabe-ordner> [variante,...]
Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tischfläche bei Z = 0.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms

led, box = dm.led, dm.box
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
L, W = ms.L, ms.W
DIE = 0.375
CELL = 0.3
SORT_KEYS = ["zahl", "material", "rune", "kuehl"]
SORT_NAMES = ["LOCH", "BAND", "TON", "HOLO"]
# Die Beispiel-Serie: vier Karten gesteckt, zwei Scheiben leer.
SERIES = [("zahl", 0), ("material", 1), ("rune", 2), ("cool", 3), None, None]
CABLES = {"zahl": "zahl", "material": "material", "rune": "rune"}


def root(name):
    bpy.ops.object.empty_add()
    o = bpy.context.active_object
    o.name = name
    return o


def dark(name="Gehaeuse"):
    return led.mat(name, (0.022, 0.022, 0.03), 0.6, 0.35, clearcoat=0.4)


def table(pits):
    """Filzplatte mit Gruben: (x, y, breite, tiefe_y, tiefe_z)."""
    for o in list(bpy.data.objects):
        mats = getattr(o.data, "materials", None) if o.data is not None else None
        if mats and mats[0] is not None and mats[0].name == "Filz":
            bpy.data.objects.remove(o)
    felt = led.mat("Filz", (0.018, 0.011, 0.03), 0.0, 0.9)
    lining = led.mat("Grubenfutter", (0.012, 0.011, 0.018), 0.0, 0.7)
    seam = led.mat("Grubensaum", (0.6, 0.62, 0.75), 0.0, 0.5, 0.5)
    r = root("Tisch")
    slab = led.rounded_box(r, "Filzplatte", (60, 60, 4), (0, 0, -2), felt, 0.0, 0.0)
    for i, (x, y, sx, sy, sz) in enumerate(pits):
        hole = led.rounded_box(r, "Loch%d" % i, (sx, sy, sz * 2), (x, y, 0), felt, 0.03, 0.0)
        led.cut(slab, hole)
        led.rounded_box(r, "Boden%d" % i, (sx, sy, 0.01), (x, y, -sz + 0.005), lining, 0.03, 0.0)
        led.frame_ring(r, "Saum%d" % i, (sx + 0.03, sy + 0.03), (sx, sy), 0.002, 0.004, seam,
                       0.03, y=y).location.x = x
        bpy.data.objects["Saum%dLoch" % i].location.x = x
    return r


def net_panel(name, title, x, y, upright, key, vals):
    """Eine Die-View: dunkle Scheibe, sechs Zellen, Werte in der Farbe."""
    r = root(name)
    cells = dm.CROSS if upright else [(row, col) for col, row in dm.CROSS]
    cols, rows = (3, 4) if upright else (4, 3)
    w, h = cols * CELL + 0.16, rows * CELL + 0.16
    glass = led.mat("Schirm", (0.02, 0.022, 0.05), 0.0, 0.2, clearcoat=1.0)
    led.rounded_box(r, "Scheibe", (w, h, 0.012), (x, y, 0.006), glass, 0.05, 0.0)
    led.frame_ring(r, "Rahmen", (w, h), (w - 0.02, h - 0.02), 0.013, 0.004, dm.glow("kuehl", 1.2),
                   0.05, y=y).location.x = x
    bpy.data.objects["RahmenLoch"].name = name + "Loch"
    bpy.data.objects[name + "Loch"].location.x = x
    tile = led.mat("Zelle", (0.05, 0.045, 0.1), 0.0, 0.4)
    for i, (c, rw) in enumerate(cells):
        cx = x + (c - (cols - 1) * 0.5) * CELL
        cy = y - (rw - (rows - 1) * 0.5) * CELL
        led.rounded_box(r, "Zelle%d" % i, (CELL * 0.9, CELL * 0.9, 0.004), (cx, cy, 0.014), tile,
                        0.03, 0.0)
        if vals[i]:
            box.text(r, vals[i][0], dm.top(0.017), cx, cy, CELL * 0.42, dm.glow(vals[i][1], 2.0),
                     "Wert%d" % i)
    ms.label(title, x, y + h * 0.5 + 0.13, 0.11)
    return w, h


def die(x, y, z):
    r = root("Wuerfel")
    body = led.mat("Wuerfelkoerper", (0.03, 0.03, 0.045), 0.2, 0.25, clearcoat=0.8)
    led.rounded_box(r, "Koerper", (DIE, DIE, DIE), (x, y, z), body, 0.03, 0.03)
    box.text(r, "4", dm.top(z + DIE * 0.5 + 0.001), x, y, DIE * 0.5,
             led.mat("Ziffer", (1, 1, 1), 0.0, 0.3, 2.5), "Auge")
    return Vector((x, y, z))


def cable(parent, name, p0, p1, key, sag=0.18):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.016
    cu.bevel_resolution = 3
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(2)
    p0, p1 = Vector(p0), Vector(p1)
    mid = (p0 + p1) * 0.5 - Vector((0, 0, sag))
    for bp, p in zip(sp.bezier_points, (p0, mid, p1)):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(o)
    cu.materials.append(dm.glow(key, 3.0))
    o.parent = parent
    dm.cyl(parent, name + "Klemme", 0.03, 0.03, p1, led.mat("Klemme", (0.7, 0.72, 0.76), 1.0, 0.25),
           12)
    dm.cyl(parent, name + "Buchse", 0.045, 0.02, p0, dark("Buchse"), 16)


def chamber(x, y, half=0.8, depth=0.9):
    """Die KAMMER: Sockel, schwebender Würfel, Kabel aus den Wänden an die Kanten der Seiten."""
    r = root("Kammer")
    dm.cyl(r, "Sockel", 0.13, depth - 0.02, (x, y, -depth * 0.5 - 0.01), dark("Sockel"), 32)
    dm.cyl(r, "Puck", 0.15, 0.012, (x, y, -0.014), dm.glow("kuehl", 2.5), 32)
    c = die(x, y, 0.3)
    h = DIE * 0.5
    zt = c.z + h
    # Oben: Zahl UND Material teilen die vier Kanten der oberen Seite.
    top_keys = ["zahl", "material", "zahl", "material"]
    dirs = [Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((-1, 0, 0)), Vector((0, -1, 0))]
    for i, (d, key) in enumerate(zip(dirs, top_keys)):
        side = Vector((-d.y, d.x, 0)) * 0.35
        cable(r, "KabelOben%d" % i, Vector((x, y, -0.12)) + d * half + side,
              Vector((c.x, c.y, zt)) + d * (h - 0.03), key, 0.02)
    # Die Seite zur Kamera (-Y) bekommt eine Rune: vier Kabel an ihre vier Kanten.
    yf = c.y - h
    for i, (dx, dz) in enumerate(((-1, 0), (1, 0), (0, -1), (0, 1))):
        p1 = Vector((c.x + dx * (h - 0.03), yf, c.z + dz * (h - 0.03)))
        p0 = Vector((x + (dx * 0.5 + (0.22 if dz else 0) * dz), y - half, -0.3))
        cable(r, "KabelVorn%d" % i, p0, p1, "rune", 0.1)
    # Kabelköpfe, die noch warten: sie schauen nur aus ihren Buchsen.
    for i, sx in enumerate((-1, 1)):
        for j, yy in enumerate((-0.5, 0.5)):
            p = Vector((x + sx * half, y + yy, -0.25))
            dm.cyl(r, "Wartend%d%d" % (i, j), 0.045, 0.02, p, dark("Buchse"), 16)
    return r


def button(x, y, w=1.3):
    r = root("Knopf")
    led.rounded_box(r, "Taste", (w, 0.34, 0.05), (x, y, 0.025), dm.glow("rune", 1.6), 0.08, 0.01)
    box.text(r, "PRÄGEN 4/6", dm.top(0.051), x, y, 0.13, led.mat("Tinte", (0.02, 0.02, 0.02)),
             "Aufschrift")


def bus(points, key="kuehl"):
    r = root("Bus")
    for i in range(len(points) - 1):
        a, b = Vector((*points[i], 0.004)), Vector((*points[i + 1], 0.004))
        dm.beam(r, "Ader%d" % i, a, b, 0.012, dm.glow(key, 2.2))


def slice_body(x, y, thick, side, face, upright_card):
    """Eine SCHEIBE: Vierkant um die X-Achse, jede Seite trägt den Saum eines Lesers.
    face = 0..3 liegt oben, None = die Scheibe steht auf Kante."""
    r = root("Scheibe")
    led.rounded_box(r, "Vierkant", (thick, side, side), (0, 0, 0), dark("Walze"), 0.0, 0.012)
    for k in range(4):
        sub = root("Seite%d" % k)
        z = side * 0.5
        g = dm.glow(SORT_KEYS[k], 1.4)
        for s in (-1, 1):
            led.rounded_box(sub, "Saum%d" % s, (thick - 0.12, 0.02, 0.006),
                            (0, s * (side * 0.5 - 0.035), z + 0.002), g, 0.0, 0.0)
        box.text(sub, SORT_NAMES[k], dm.top(z + 0.001), 0, 0, 0.13 if upright_card else 0.16,
                 dm.glow(SORT_KEYS[k], 0.7), "Name")
        sub.rotation_euler = (k * math.pi * 0.5, 0, 0)
        sub.parent = r
    r.location = (x, y, -side * 0.5)
    r.rotation_euler = (math.radians(45) if face is None else -face * math.pi * 0.5, 0, 0)
    return r


def drum(x0, y, entries, upright_card, first=1):
    """Eine WALZE aus Scheiben ab x0 nach +X. Gibt (rechte Kante, Graben) zurück."""
    thick = (W if upright_card else L) + 0.07
    side = (L if upright_card else W) + 0.1
    pitch = thick + 0.02
    for i, e in enumerate(entries):
        x = x0 + pitch * (i + 0.5)
        slice_body(x, y, thick, side, e[1] if e else None, upright_card)
        if e:
            dm.build(ms.make(e[0], 21 + i + first, on=True) if e[0] in ms.HOLO_MODES
                     else ms.make(e[0], 21 + i + first), "Karte%d" % (i + first), (x, y, 0.002),
                     (0, 0, math.pi * 0.5 if upright_card else 0))
        ms.label(str(i + first), x, y - side * 0.72 - 0.12, 0.13)
    length = pitch * len(entries)
    return x0 + length, (x0 + length * 0.5, y, length + 0.06, side * 1.42 + 0.04, side * 0.5 + 0.45)


def magazine(x, y, cols=4):
    """Das MAGAZIN: ein Tablett Lochkarten, zwei Lanes."""
    gap = 0.12
    w, h = cols * (L + gap) + gap, 2 * (W + gap) + gap
    kinds = ["zahl", "faktor", "zahl", None, "zahl", "zahl", "faktor", None]
    for i in range(cols * 2):
        k = kinds[i % len(kinds)]
        if not k:
            continue
        cx = x - w * 0.5 + gap + L * 0.5 + (i // 2) * (L + gap)
        cy = y + (0.5 - i % 2) * (W + gap)
        dm.build(ms.make(k, 40 + i), "Magazinkarte%d" % i, (cx, cy, -0.22))
    ms.label("MAGAZIN · ZAHLEN", x, y - h * 0.5 - 0.16, 0.12)
    return (x, y, w, h, 0.24)


def info(x, y):
    r = root("Info")
    glass = led.mat("Schirm", (0.02, 0.022, 0.05), 0.0, 0.2, clearcoat=1.0)
    led.rounded_box(r, "Scheibe", (2.6, 0.62, 0.012), (x, y, 0.006), glass, 0.06, 0.0)
    ink = led.mat("Schrift", (0.85, 0.86, 0.9), 0.0, 0.5, 0.8)
    box.text(r, "Werkstatt", dm.top(0.013), x - 0.75, y + 0.14, 0.13, ink, "Titel")
    box.text(r, "Ziel: Würfel 4 · vier Karten gesteckt", dm.top(0.013), x, y - 0.1, 0.085, ink,
             "Zeile")


BEFORE = [("3", "weiss"), ("1", "weiss"), ("4", "weiss"), ("6", "weiss"), ("2", "weiss"),
          ("5", "weiss")]
AFTER = [("3", "weiss"), ("1", "weiss"), ("7", "zahl"), ("6", "rune"), ("2", "weiss"),
         ("5", "weiss")]
dm.HEX["weiss"] = "#d8dae6"


def layout_walze():
    """A: VORHER | sechs Scheiben, Karten hochkant | KAMMER | NACHHER, darunter das Magazin."""
    y = 0.0
    pw = 3 * CELL + 0.16
    xl = -5.6
    x_end, trench = drum(xl + pw + 0.3, y, SERIES, True)
    xc = x_end + 0.3 + 0.8
    xa = xc + 0.8 + 0.3 + pw * 0.5
    mag = magazine(xl + 3.6, -2.75)
    table([trench, (xc, y, 1.6, 1.6, 0.9), mag])
    net_panel("Vorher", "VORHER", xl + pw * 0.5, y, True, "kuehl", BEFORE)
    net_panel("Nachher", "NACHHER", xa, y, True, "kuehl", AFTER)
    chamber(xc, y)
    button(xc, y - 1.1)
    yb = y - trench[3] * 0.5 - 0.05
    bus([(xl + pw * 0.5, y - 0.75), (xl + pw * 0.5, yb), (xc - 0.9, yb), (xc - 0.9, y - 0.4),
         (xc - 0.8, y - 0.4)])
    info(xl + 1.3, 1.95)
    return Vector((0.2, -0.75, 0)), 13.2


def layout_doppel():
    """B: zwei Walzen zu drei, Karten liegend; alle Netze bleiben quer."""
    pw = 4 * CELL + 0.16
    xl = -5.1
    x0 = xl + pw + 0.3
    x_end, t0 = drum(x0, 0.95, SERIES[:3], False)
    _, t1 = drum(x0, -0.95, SERIES[3:], False, 4)
    xc = x_end + 0.3 + 0.8
    xa = xc + 0.8 + 0.3 + pw * 0.5
    mag = magazine(xl + 3.6, -3.75)
    table([t0, t1, (xc, 0, 1.6, 1.6, 0.9), mag])
    net_panel("Vorher", "VORHER", xl + pw * 0.5, 0, False, "kuehl", BEFORE)
    net_panel("Nachher", "NACHHER", xa, 0, False, "kuehl", AFTER)
    chamber(xc, 0)
    button(xc, -1.1)
    bus([(xl + pw * 0.5, 0.55), (xl + pw * 0.5, 0.95), (x0, 0.95)])
    bus([(x_end + 0.05, 0.95), (x_end + 0.18, 0.95), (x_end + 0.18, 0.02), (x0 - 0.15, 0.02),
         (x0 - 0.15, -0.95), (x0, -0.95)])
    bus([(x_end + 0.05, -0.95), (xc - 0.95, -0.95), (xc - 0.95, 0), (xc - 0.8, 0)])
    info(xl + 1.3, 2.35)
    return Vector((0.2, -1.1, 0)), 13.6


def layout_revolver():
    """C: die Kammer in der Mitte, sechs Leser im Ring; die Reihenfolge läuft im Uhrzeigersinn."""
    rad = 2.25
    pads = []
    r = root("Ring")
    for i, e in enumerate(SERIES):
        a = math.radians(150 - i * 60)
        x, y = math.cos(a) * rad, math.sin(a) * rad
        key = SORT_KEYS[e[1]] if e else None
        pad = root("Leser%d" % i)
        led.rounded_box(pad, "Wiege", (L + 0.12, W + 0.12, 0.05), (0, 0, 0.0), dark("Wiege"), 0.08,
                        0.01)
        if key:
            led.rounded_box(pad, "Wiegensaum", (L + 0.17, W + 0.17, 0.02), (0, 0, 0.0),
                            dm.glow(key, 1.6), 0.1, 0.0)
        pad.location = (x, y, 0.0)
        pad.rotation_euler = (0, 0, a + math.pi)
        if e:
            dm.build(ms.make(e[0], 61 + i, on=True) if e[0] in ms.HOLO_MODES
                     else ms.make(e[0], 61 + i), "Karte%d" % i, (x, y, 0.027), (0, 0, a + math.pi))
            dm.beam(r, "Speiche%d" % i, (math.cos(a) * 1.38, math.sin(a) * 1.38, 0.004),
                    (math.cos(a) * 0.84, math.sin(a) * 0.84, 0.004), 0.014, dm.glow(key, 2.4))
        ms.label(str(i + 1), math.cos(a) * (rad + 1.05), math.sin(a) * (rad + 1.05), 0.15)
        pads.append((x, y))
    bpy.ops.mesh.primitive_torus_add(major_radius=1.18, minor_radius=0.012, major_segments=96,
                                     location=(0, 0, 0.004))
    ring = bpy.context.active_object
    ring.data.materials.append(dm.glow("kuehl", 1.6))
    ring.parent = r
    pw = 4 * CELL + 0.16
    mag = magazine(0, -4.75)
    table([(0, 0, 1.6, 1.6, 0.9), mag])
    net_panel("Vorher", "VORHER", -4.6, 0, False, "kuehl", BEFORE)
    net_panel("Nachher", "NACHHER", 4.6, 0, False, "kuehl", AFTER)
    chamber(0, 0)
    button(4.6, -1.0)
    info(-4.3, 2.9)
    return Vector((0, -1.3, 0)), 15.6


def slice_upright(x, y, thick, side, face):
    """Eine SCHEIBE der SENKRECHTEN Walze: Vierkant um die Y-Achse, Karte liegt quer darauf."""
    r = root("Scheibe")
    led.rounded_box(r, "Vierkant", (side, thick, side), (0, 0, 0), dark("Walze"), 0.0, 0.012)
    for k in range(4):
        sub = root("Seite%d" % k)
        z = side * 0.5
        g = dm.glow(SORT_KEYS[k], 1.4)
        for s in (-1, 1):
            led.rounded_box(sub, "Saum%d" % s, (0.02, thick - 0.12, 0.006),
                            (s * (side * 0.5 - 0.035), 0, z + 0.002), g, 0.0, 0.0)
        box.text(sub, SORT_NAMES[k], dm.top(z + 0.001), 0, 0, 0.16, dm.glow(SORT_KEYS[k], 0.7),
                 "Name")
        sub.rotation_euler = (0, k * math.pi * 0.5, 0)
        sub.parent = r
    r.location = (x, y, -side * 0.5)
    r.rotation_euler = (0, math.radians(45) if face is None else -face * math.pi * 0.5, 0)
    return r


def layout_v1():
    """V1: Pool, darunter die Paket-Öffnung; Walze SENKRECHT mit VORHER darüber und NACHHER
    darunter; das Magazin als vier Sorten-Reihen, der Info-Schirm über der Zahlen-Reihe."""
    pool = (-3.06, 1.57, 4.875, 4.06, 0.5)
    side, pitch = L + 0.1, W + 0.09
    wx, top_y = 0.84, 2.42
    trench = (wx, top_y - pitch * 3, side * 1.42 + 0.04, pitch * 6 + 0.06, side * 0.5 + 0.45)
    for i, e in enumerate(SERIES):
        y = top_y - pitch * (i + 0.5)
        slice_upright(wx, y, W + 0.07, side, e[1] if e else None)
        if e:
            dm.build(ms.make(e[0], 81 + i, on=True) if e[0] in ms.HOLO_MODES
                     else ms.make(e[0], 81 + i), "Karte%d" % i, (wx, y, 0.002))
        ms.label(str(i + 1), wx - side * 0.71 - 0.16, y, 0.15)
    gap = 0.12
    mw, mh = 2 * (L + gap) + gap, 4 * (W + gap) + gap
    mx = 2.3 + mw * 0.5
    my = top_y - mh * 0.5
    rows = [("ZAHLEN", ["zahl", "faktor"]), ("MATERIAL", ["material", "material"]),
            ("RUNEN", ["rune", "rune"]), ("SONDER", ["repair", "cool"])]
    for i, (name, kinds) in enumerate(rows):
        cy = top_y - gap - W * 0.5 - i * (W + gap)
        for j, k in enumerate(kinds):
            dm.build(ms.make(k, 90 + i * 2 + j), "Magazinkarte%d%d" % (i, j),
                     (2.3 + gap + L * 0.5 + j * (L + gap), cy, -0.22))
        ms.label(name, 2.3 + mw + 0.55, cy, 0.12)
    kx, ky = 3.1, top_y - mh - 0.2 - 0.8
    table([pool, trench, (kx, ky, 1.6, 1.6, 0.9), (mx, my, mw, mh, 0.24)])
    net_panel("Vorher", "", wx, 3.07, False, "kuehl", BEFORE)
    net_panel("Nachher", "", wx, top_y - pitch * 6 - 0.12 - 0.53, False, "kuehl", AFTER)
    ms.label("VORHER", wx + 1.2, 3.07, 0.11)
    ms.label("NACHHER", wx + 1.25, top_y - pitch * 6 - 0.65, 0.11)
    chamber(kx, ky)
    button(kx + 1.75, ky)
    bus([(wx + 0.3, top_y - pitch * 6 - 0.03), (wx + 0.3, ky), (kx - 0.8, ky)])
    info(2.3 + 1.3, 3.07)
    # Der VORRAT: zwölf schwebende Würfel über ihrer Vertiefung.
    for c in range(4):
        for r_ in range(3):
            die(pool[0] + (c - 1.5) * 1.1, pool[1] + (1 - r_) * 1.2, 0.2)
    ms.label("WÜRFEL-POOL", pool[0], pool[1] + pool[3] * 0.5 + 0.15, 0.12)
    # Die PAKET-ÖFFNUNG unter dem Pool, genau so breit: fünf Optionen auf der Schiene.
    oh = 5.1
    oy = pool[1] - pool[3] * 0.5 - 0.2 - oh * 0.5
    o = root("Oeffnung")
    led.frame_ring(o, "Oeffnungsrand", (pool[2], oh), (pool[2] - 0.03, oh - 0.03), 0.003, 0.004,
                   dm.glow("rune", 0.9), 0.06, y=oy).location.x = pool[0]
    bpy.data.objects["OeffnungsrandLoch"].location.x = pool[0]
    for n in range(5):
        tx = pool[0] + (-1.19 if n < 3 else 1.19)
        ty = oy + 1.3 - (n % 3) * 1.3
        die(tx - 0.9, ty, 0.2)
        net_panel("Opt%d" % n, "", tx + 0.25, ty, False, "kuehl", BEFORE)
    ms.label("PAKET-ÖFFNUNG · WÜRFEL-PAKET", pool[0], oy - oh * 0.5 + 0.2, 0.12)
    return Vector((0.6, -1.1, 0)), 17.0


def layout_a_unten():
    """A (2026-11-18): Werkstatt wieder UNTER dem Pool. Podest mit eigener Die-View rechts am
    Pool, liegende Walze, Kammer an ihrem Ende, Magazin in vier Sorten-Spalten, darunter rechts
    die Gleichung Original + Upgrades = Ergebnis."""
    pool = (-4.56, 2.47, 4.875, 4.06, 0.5)
    thick, side = L + 0.07, W + 0.1
    pitch = thick + 0.02
    x0, dy = -7.0, -0.8
    for i, e in enumerate(SERIES):
        x = x0 + pitch * (i + 0.5)
        slice_body(x, dy, thick, side, e[1] if e else None, False)
        if e:
            dm.build(ms.make(e[0], 121 + i, on=True) if e[0] in ms.HOLO_MODES
                     else ms.make(e[0], 121 + i), "Karte%d" % i, (x, dy, 0.002))
        ms.label(str(i + 1), x, dy + side * 0.71 + 0.14, 0.13)
    length = pitch * 6
    trench = (x0 + length * 0.5, dy, length + 0.06, side * 1.42 + 0.04, side * 0.5 + 0.45)
    kx = x0 + length + 0.2 + 0.8
    mw, mh = 8.0, 3.08
    mx, my = x0 + mw * 0.5, -3.38
    cols = [("ZAHLEN", ["zahl", "faktor"]), ("MATERIAL", ["material", "material"]),
            ("RUNEN", ["rune", "rune"]), ("SONDER", ["repair", "cool"])]
    for i, (name, kinds) in enumerate(cols):
        cx = x0 + 1.0 + i * 2.0
        for j, k in enumerate(kinds):
            dm.build(ms.make(k, 140 + i * 2 + j), "Magazinkarte%d%d" % (i, j),
                     (cx, my + 0.71 - j * 1.42, -0.22))
        ms.label(name, cx, my - mh * 0.5 - 0.16, 0.12)
    table([pool, trench, (kx, dy, 1.6, 1.6, 0.9), (mx, my, mw, mh, 0.24)])
    # Die KAMMER: der Würfel ist hier, sobald die erste Karte steckt.
    c = root("Kammer")
    dm.cyl(c, "Sockel", 0.13, 0.88, (kx, dy, -0.45), dark("Sockel"), 32)
    dm.cyl(c, "Puck", 0.15, 0.012, (kx, dy, -0.014), dm.glow("kuehl", 2.5), 32)
    die(kx, dy, 0.3)
    ms.label("KAMMER", kx, dy + 0.98, 0.11)
    button(kx + 1.75, dy)
    bus([(x0, dy - side * 0.71 - 0.05), (kx - 0.9, dy - side * 0.71 - 0.05), (kx - 0.9, dy - 0.3),
         (kx - 0.8, dy - 0.3)])
    # Das PODEST: nur zum Ansehen, mit eigener Die-View darunter.
    px = -0.03
    pd = root("Podest")
    led.rounded_box(pd, "Platte", (1.6, 1.6, 0.02), (px, 3.67, 0.01), dark("Podestplatte"), 0.08,
                    0.0)
    dm.cyl(pd, "Puck", 0.15, 0.012, (px, 3.67, 0.026), dm.glow("kuehl", 2.5), 32)
    ms.label("PODEST", px, 4.62, 0.11)
    net_panel("Ansicht", "", px, 2.08, False, "kuehl", [None] * 6)
    # Die GLEICHUNG rechts neben dem Magazin.
    ey = -3.18
    net_panel("Original", "ORIGINAL", 2.14, ey, False, "kuehl", BEFORE)
    net_panel("Upgrades", "UPGRADES", 4.44, ey, False, "kuehl",
              [None, None, ("+3", "zahl"), ("ᚱ", "rune"), None, None])
    net_panel("Ergebnis", "ERGEBNIS", 6.74, ey, False, "kuehl", AFTER)
    ms.label("+", 3.29, ey, 0.34)
    ms.label("=", 5.59, ey, 0.34)
    for c_ in range(4):
        for r_ in range(3):
            if (c_, r_) != (1, 1):
                die(pool[0] + (c_ - 1.5) * 1.1, pool[1] + (1 - r_) * 1.2, 0.2)
    ms.label("WÜRFEL-POOL", pool[0], pool[1] + pool[3] * 0.5 + 0.15, 0.12)
    ow, oh, ox = 5.33, 4.06, 3.88
    o = root("Oeffnung")
    led.frame_ring(o, "Oeffnungsrand", (ow, oh), (ow - 0.03, oh - 0.03), 0.003, 0.004,
                   dm.glow("rune", 0.9), 0.06, y=pool[1]).location.x = ox
    bpy.data.objects["OeffnungsrandLoch"].location.x = ox
    ms.label("PAKET-ÖFFNUNG", ox, pool[1], 0.16)
    return Vector((0.4, -0.4, 0)), 17.5


LAYOUTS = {"a_unten": layout_a_unten, "v1": layout_v1, "walze": layout_walze, "doppel": layout_doppel, "revolver": layout_revolver}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    argv = sys.argv[sys.argv.index("--") + 1:]
    only = argv[1].split(",") if len(argv) > 1 else []
    for name, fn in LAYOUTS.items():
        if only and name not in only:
            continue
        cam, aim = dm.empty_stage()
        for o in bpy.data.objects:
            mats = getattr(o.data, "materials", None) if o.data is not None else None
            if mats and mats[0] is not None and mats[0].name.startswith("Softbox"):
                o.location.z += 30.0
        target, width = fn()
        scene = bpy.context.scene
        scene.eevee.taa_render_samples = 48
        scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
        ms.station(cam, aim, target, width * 50 / 36 * 1.02)
        scene.render.filepath = os.path.join(OUT, name + "_station.png")
        bpy.ops.render.render(write_still=True)
        aim.location = target + Vector((0.3, 0.2, 0))
        cam.location = target + Vector((4.5, -11.5, 9.0))
        cam.data.lens = 34
        scene.render.filepath = os.path.join(OUT, name + "_schraeg.png")
        bpy.ops.render.render(write_still=True)
    print("ok")
