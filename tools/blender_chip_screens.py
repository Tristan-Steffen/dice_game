"""Fumble: drei ENTWÜRFE "Schirm als Prozessor" samt versenkter Wurfgrube (2026-11-20).
  a_sockel  - Hub mit Heatspreader-Deckel auf schwarzer Platine, Grube als LGA-Sockel
  b_qfp     - Hub als Epoxid-Gehäuse mit Beinchen auf Gold-Pads, Grube als leerer Footprint
  c_keramik - Hub als Chip auf Keramik-Träger mit Bonddrähten, Grube als gestufte Kavität
  d_modul   - Hub als Service-Modul-Platine mit Kontaktleiste, Grube als Platinen-Wanne
  e_kuehler - Hub im Rippen-Kühlkörper mit Heatpipes, Grube als Kupfer-Kühlplatte
  f_dieshot - Hub als Silizium mit Die-Shot-Rand, Grube mit Die-Shot-Boden und Lichtwand
Blockmodelle im Maßstab Welt / 10: Grube 2,856 x 1,52, Hub 2,85 x 3,0, Würfel 0,18.

Aufruf (kopflos):
  blender -b -P tools/blender_chip_screens.py -- <ausgabe-ordner> [variante,...]
Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tischfläche bei Z = 0.
"""
import bpy, math, os, random, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms

led, box = dm.led, dm.box
OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
DIE = 0.18
PIT = (-1.95, -0.35, 2.856, 1.52)
SCORE = (-1.95, 1.3, 2.4, 0.42)
HUB = (2.05, 0.15, 2.85, 3.0)
dm.HEX["weiss"] = "#d8dae6"


def root(name):
    bpy.ops.object.empty_add()
    o = bpy.context.active_object
    o.name = name
    return o


def m_board():
    return led.mat("Platine", (0.011, 0.012, 0.015), 0.0, 0.75)


def m_trace():
    return led.mat("Bahn", (0.06, 0.052, 0.04), 0.4, 0.55)


def m_gold():
    return led.mat("Gold", (0.83, 0.6, 0.22), 1.0, 0.32)


def m_steel():
    return led.mat("Stahl", (0.62, 0.64, 0.68), 1.0, 0.3)


def m_epoxy():
    return led.mat("Epoxid", (0.018, 0.018, 0.022), 0.0, 0.45, clearcoat=0.3)


def m_ceramic():
    return led.mat("Keramik", (0.075, 0.066, 0.1), 0.0, 0.5)


def m_etch():
    return led.mat("Laser", (0.3, 0.3, 0.33), 0.0, 0.7)


def boxes(parent, name, items, material):
    """Viele achsparallele Quader (cx, cy, cz, sx, sy, sz) als EIN Mesh."""
    verts, faces = [], []
    for cx, cy, cz, sx, sy, sz in items:
        n = len(verts)
        hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
        for dz in (-hz, hz):
            for dx, dy in ((-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)):
                verts.append((cx + dx, cy + dy, cz + dz))
        faces += [[n, n + 3, n + 2, n + 1], [n + 4, n + 5, n + 6, n + 7]]
        faces += [[n + i, n + (i + 1) % 4, n + 4 + (i + 1) % 4, n + 4 + i] for i in range(4)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = parent
    return o


def strips(parent, name, lines, w, z, material):
    """Flache Bahnen: je Linienzug ein Band der Breite w auf Höhe z."""
    verts, faces = [], []
    for pts in lines:
        for i in range(len(pts) - 1):
            a, b = Vector(pts[i]), Vector(pts[i + 1])
            d = (b - a).normalized()
            a, b = a - d * w * 0.5, b + d * w * 0.5
            nrm = Vector((-d.y, d.x)) * w * 0.5
            n = len(verts)
            for p in (a - nrm, b - nrm, b + nrm, a + nrm):
                verts.append((p.x, p.y, z))
            faces.append([n, n + 1, n + 2, n + 3])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = parent
    return o


def ring_items(x, y, ox, oy, ix, iy, zc, h):
    tx, ty = (ox - ix) * 0.5, (oy - iy) * 0.5
    return [(x, y + (oy - ty) * 0.5, zc, ox, ty, h), (x, y - (oy - ty) * 0.5, zc, ox, ty, h),
            (x - (ox - tx) * 0.5, y, zc, tx, iy, h), (x + (ox - tx) * 0.5, y, zc, tx, iy, h)]


def rim_points(x, y, w, h, pitch, skip=None):
    """Punkte rund um ein Rechteck: (px, py, nx, ny), die Normale zeigt nach außen."""
    out = []
    for length, fixed, horiz in ((w, h * 0.5, True), (h, w * 0.5, False)):
        n = max(1, int((length - 0.08) / pitch))
        for i in range(n):
            t = (i - (n - 1) * 0.5) * pitch
            for s in (-1, 1):
                p = (x + t, y + s * fixed, 0, s) if horiz else (x + s * fixed, y + t, s, 0)
                if skip is None or not skip(p):
                    out.append(p)
    return out


def text(r, body, x, y, z, size, material, name="Text"):
    return box.text(r, body, dm.top(z), x, y, size, material, name)


def felt_table(holes):
    for o in list(bpy.data.objects):
        mats = getattr(o.data, "materials", None) if o.data is not None else None
        if mats and mats[0] is not None and mats[0].name == "Filz":
            bpy.data.objects.remove(o)
    felt = led.mat("Filz", (0.018, 0.011, 0.03), 0.0, 0.9)
    r = root("Tisch")
    slab = led.rounded_box(r, "Filzplatte", (60, 60, 4), (0, 0, -2), felt, 0.0, 0.0)
    for i, (x, y, sx, sy, sz) in enumerate(holes):
        hole = led.rounded_box(r, "Loch%d" % i, (sx, sy, sz * 2), (x, y, 0), felt, 0.0, 0.0)
        led.cut(slab, hole)


def die(x, y, floor, rot, digit):
    r = root("Wuerfel")
    body = led.mat("Wuerfelkoerper", (0.7, 0.71, 0.76), 0.0, 0.3, clearcoat=0.6)
    led.rounded_box(r, "Koerper", (DIE, DIE, DIE), (0, 0, DIE * 0.5), body, 0.02, 0.02)
    face = led.mat("Wuerfelseite", (0.02, 0.02, 0.03), 0.0, 0.3)
    boxes(r, "Seite", [(0, 0, DIE + 0.0005, DIE * 0.74, DIE * 0.74, 0.001)], face)
    text(r, digit, 0, 0, DIE + 0.0015, DIE * 0.5, led.mat("Ziffer", (1, 1, 1), 0.0, 0.3, 2.5), "Auge")
    r.location = (x, y, floor)
    r.rotation_euler = (0, 0, math.radians(rot))


def dice(floor):
    x, y = PIT[0], PIT[1]
    for dx, dy, rot, d in ((-0.7, 0.2, 14, "4"), (-0.25, -0.25, -22, "4"), (0.2, 0.3, 37, "6"),
                           (0.62, -0.1, 8, "2"), (1.0, 0.35, -40, "5")):
        die(x + dx, y + dy, floor, rot, d)


def screen(r, x, y, w, h, z, kind):
    """Der ruhige Schirm: dunkles Glas, dünner Cyan-Saum, Inhalt nur als Platzhalter."""
    glass = led.mat("Schirm", (0.02, 0.022, 0.05), 0.0, 0.2, clearcoat=1.0)
    led.rounded_box(r, "Glas", (w, h, 0.008), (x, y, z + 0.004), glass, 0.04, 0.0)
    boxes(r, "Saum", ring_items(x, y, w - 0.05, h - 0.05, w - 0.066, h - 0.066, z + 0.0085, 0.001),
          dm.glow("kuehl", 1.3))
    ink = led.mat("Schrift", (0.85, 0.86, 0.9), 0.0, 0.5, 0.9)
    zt = z + 0.009
    if kind == "score":
        text(r, "310 / 450", x - w * 0.25, y, zt, 0.17, dm.glow("rune", 1.8), "Ziel")
        text(r, "24 × 6", x + w * 0.27, y, zt, 0.17, dm.glow("kuehl", 1.8), "Wertung")
        return
    text(r, "LADEN", x - w * 0.5 + 0.48, y + h * 0.5 - 0.26, zt, 0.19, ink, "Titel")
    text(r, "RUNDE 4 · BLIND 310", x + w * 0.5 - 0.72, y + h * 0.5 - 0.26, zt, 0.075, ink, "Kopf")
    tile = led.mat("Kachel", (0.05, 0.045, 0.1), 0.0, 0.4)
    tw = (w - 0.4) / 3.0
    items = []
    for c in range(3):
        for k, ty in enumerate((0.5, -0.42)):
            cx = x + (c - 1) * tw
            items.append((cx, y + ty, zt, tw - 0.08, 0.8, 0.001))
            text(r, str((7, 12, 4, 9, 15, 6)[c * 2 + k]), cx, y + ty - 0.27, zt + 0.001, 0.1,
                 dm.glow("rune", 1.6), "Preis")
    boxes(r, "Kacheln", items, tile)
    led.rounded_box(r, "Knopf", (1.1, 0.26, 0.004), (x, y - h * 0.5 + 0.3, zt + 0.002),
                    dm.glow("rune", 1.4), 0.06, 0.0)
    text(r, "FERTIG", x, y - h * 0.5 + 0.3, zt + 0.0045, 0.11, led.mat("Tinte", (0.02, 0.02, 0.02)),
         "Knopftext")


def smd(r, name, spots, along_x=True):
    body, cap = [], []
    for cx, cy in spots:
        sx, sy = (0.05, 0.026) if along_x else (0.026, 0.05)
        body.append((cx, cy, 0.015, sx * 0.55, sy, 0.018))
        for s in (-1, 1):
            ox, oy = (s * sx * 0.39, 0) if along_x else (0, s * sy * 0.39)
            cap.append((cx + ox, cy + oy, 0.015, sx * 0.22 if along_x else sx,
                        sy if along_x else sy * 0.22, 0.019))
    boxes(r, name, body, led.mat("Kondensator", (0.2, 0.15, 0.1), 0.0, 0.5))
    boxes(r, name + "Kappe", cap, m_steel())


# --- A: Heatspreader und LGA-Sockel -------------------------------------------------------

def chip_a(tag, x, y, w, h, kind, mark):
    r = root("Chip" + tag)
    led.rounded_box(r, "Platine" + tag, (w + 0.44, h + 0.44, 0.006), (x, y, 0.003), m_board(),
                    0.03, 0.0)
    pts = rim_points(x, y, w + 0.22, h + 0.22, 0.045)
    strips(r, "Faecher", [[(px, py), (px + nx * 0.09, py + ny * 0.09)] for px, py, nx, ny in pts],
           0.008, 0.0065, m_trace())
    smd(r, "Smd", [(x - w * 0.5 + 0.2 + i * 0.09, y + h * 0.5 + 0.165) for i in range(5)], False)
    smd(r, "Smd2", [(x + w * 0.5 + 0.165, y - h * 0.5 + 0.12 + i * 0.09) for i in range(3)], True)
    boxes(r, "Pin1", [(x - w * 0.5 - 0.17, y - h * 0.5 - 0.17, 0.007, 0.05, 0.05, 0.002)], m_gold())
    led.rounded_box(r, "Flansch" + tag, (w + 0.22, h + 0.22, 0.016), (x, y, 0.014), m_steel(), 0.05,
                    0.004)
    led.rounded_box(r, "Deckel" + tag, (w + 0.1, h + 0.1, 0.05), (x, y, 0.047), m_steel(), 0.06,
                    0.012)
    screen(r, x, y, w - 0.07, h - 0.07, 0.072, kind)
    text(r, mark, x, y - h * 0.5 - 0.008, 0.0725, 0.03, led.mat("Gravur", (0.2, 0.2, 0.23), 1.0, 0.5),
         "Marke")
    return 0.22


def pit_a(x, y, w, h):
    d = 0.09
    r = root("Sockel")
    boxes(r, "Boden", [(x, y, -d - 0.005, w, h, 0.01)], m_board())
    pads, pitch = [], 0.068
    nx, ny = int((w - 0.1) / pitch), int((h - 0.1) / pitch)
    for i in range(nx):
        for j in range(ny):
            px, py = (i - (nx - 1) * 0.5) * pitch, (j - (ny - 1) * 0.5) * pitch
            if abs(px) < 0.5 and abs(py) < 0.26:
                continue
            pads.append((x + px, y + py, -d + 0.001, 0.03, 0.03, 0.002))
    boxes(r, "Landeraster", pads, m_gold())
    smd(r, "SockelSmd", [(x - 0.32 + i * 0.16, y + s * 0.11) for i in range(5) for s in (-1, 1)])
    for o in (bpy.data.objects["SockelSmd"], bpy.data.objects["SockelSmdKappe"]):
        o.location.z = -d - 0.004
    boxes(r, "Wand", ring_items(x, y, w, h, w - 0.02, h - 0.02, -d * 0.5, d), m_epoxy())
    boxes(r, "Lippe", ring_items(x, y, w - 0.02, h - 0.02, w - 0.034, h - 0.034, -0.006, 0.004),
          dm.glow("kuehl", 1.6))
    ring = led.frame_ring(r, "Halterahmen", (w + 0.3, h + 0.3), (w + 0.02, h + 0.02), 0.012, 0.024,
                          m_steel(), 0.04, y=y)
    ring.location.x = x
    bpy.data.objects["HalterahmenLoch"].location.x = x
    yb = y - h * 0.5 - 0.2
    dm.beam(r, "Hebel", (x - w * 0.5 - 0.05, yb, 0.022), (x + w * 0.5 + 0.2, yb, 0.022), 0.011,
            m_steel())
    dm.beam(r, "Griff", (x + w * 0.5 + 0.2, yb, 0.022), (x + w * 0.5 + 0.2, yb + 0.3, 0.022), 0.011,
            m_steel())
    boxes(r, "Lager", [(x - w * 0.5 + 0.2, yb, 0.015, 0.1, 0.05, 0.03),
                       (x + w * 0.5 - 0.2, yb, 0.015, 0.1, 0.05, 0.03)], m_epoxy())
    boxes(r, "Pin1", [(x - w * 0.5 - 0.09, y + h * 0.5 + 0.09, 0.0245, 0.04, 0.04, 0.001)], m_gold())
    dice(-d)
    return 0.26, "A · HEATSPREADER + LGA-SOCKEL   (Grube 0,5 Würfelkanten tief)"


# --- B: QFP mit Beinchen und leerer Footprint ----------------------------------------------

def chip_b(tag, x, y, w, h, kind, mark):
    r = root("Chip" + tag)
    led.rounded_box(r, "Platine" + tag, (w + 0.6, h + 0.6, 0.006), (x, y, 0.003), m_board(), 0.03,
                    0.0)
    led.chamfer_box(r, "Gehaeuse" + tag, (w + 0.1, h + 0.1, 0.07), (x, y, 0.047), m_epoxy(), 0.03,
                    0.014)
    legs, pads, stubs = [], [], []
    for px, py, nx, ny in rim_points(x, y, w + 0.1, h + 0.1, 0.07):
        lw = 0.03
        sx = lambda a: abs(nx) * a + abs(ny) * lw
        sy = lambda a: abs(ny) * a + abs(nx) * lw
        legs.append((px + nx * 0.03, py + ny * 0.03, 0.05, sx(0.07), sy(0.07), 0.012))
        legs.append((px + nx * 0.066, py + ny * 0.066, 0.031, sx(0.012), sy(0.012), 0.05))
        legs.append((px + nx * 0.1, py + ny * 0.1, 0.012, sx(0.07), sy(0.07), 0.012))
        pads.append((px + nx * 0.11, py + ny * 0.11, 0.007, sx(0.11), sy(0.11), 0.002))
        stubs.append([(px + nx * 0.16, py + ny * 0.16), (px + nx * 0.25, py + ny * 0.25)])
    boxes(r, "Beinchen", legs, m_steel())
    boxes(r, "Pads", pads, m_gold())
    strips(r, "Stummel", stubs, 0.008, 0.0065, m_trace())
    screen(r, x, y, w - 0.1, h - 0.1, 0.082, kind)
    dm.cyl(r, "Pin1" + tag, 0.02, 0.002, (x - w * 0.5 - 0.012, y + h * 0.5 + 0.012, 0.0825),
           led.mat("Mulde", (0.08, 0.08, 0.09), 0.0, 0.3), 24)
    text(r, mark, x, y - h * 0.5 - 0.008, 0.0825, 0.03, m_etch(), "Marke")
    return 0.3


def pit_b(x, y, w, h):
    d, c = 0.06, 0.06
    r = root("Footprint")
    boxes(r, "Boden", [(x, y, -d - 0.005, w, h, 0.01)], m_board())
    hw, hh = w * 0.5, h * 0.5
    verts = [(x + sx * hw, y + sy * hh, 0.0) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    verts += [(x + sx * (hw - c), y + sy * (hh - c), -d) for sx, sy in ((-1, -1), (1, -1), (1, 1),
                                                                         (-1, 1))]
    mesh = bpy.data.meshes.new("Fase")
    mesh.from_pydata(verts, [], [[i, (i + 1) % 4, 4 + (i + 1) % 4, 4 + i] for i in range(4)])
    o = bpy.data.objects.new("Fase", mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(m_epoxy())
    o.parent = r
    lines = [[(x + i * 0.17, y - hh + c + 0.03), (x + i * 0.17, y + hh - c - 0.03)]
             for i in range(-7, 8)]
    lines += [[(x - hw + c + 0.03, y + j * 0.17), (x + hw - c - 0.03, y + j * 0.17)]
              for j in range(-3, 4)]
    strips(r, "Raster", lines, 0.005, -d + 0.0006, m_trace())
    boxes(r, "Thermalpad", ring_items(x, y, 1.02, 0.68, 0.99, 0.65, -d + 0.001, 0.001), m_gold())
    boxes(r, "Rand", ring_items(x, y, w + 0.5, h + 0.5, w, h, 0.002, 0.004), m_board())
    pads = []
    for px, py, nx, ny in rim_points(x, y, w, h, 0.07):
        pads.append((px + nx * 0.105, py + ny * 0.105, 0.0045,
                     abs(nx) * 0.11 + abs(ny) * 0.034, abs(ny) * 0.11 + abs(nx) * 0.034, 0.002))
    boxes(r, "Pads", pads, m_gold())
    boxes(r, "Lippe", ring_items(x, y, w + 0.03, h + 0.03, w, h, 0.005, 0.003),
          dm.glow("kuehl", 1.8))
    dm.cyl(r, "Pin1", 0.03, 0.002, (x - hw - 0.19, y + hh + 0.19, 0.005), m_gold(), 24)
    dice(-d)
    return 0.25, "B · QFP MIT BEINCHEN + LEERER FOOTPRINT   (Grube 0,33 Kanten, gefast)"


# --- C: Chip auf Keramik und gestufte Kavität ----------------------------------------------

def chip_c(tag, x, y, w, h, kind, mark):
    r = root("Chip" + tag)
    led.rounded_box(r, "Traeger" + tag, (w + 0.56, h + 0.56, 0.03), (x, y, 0.015), m_ceramic(), 0.02,
                    0.003)
    boxes(r, "Siegel", ring_items(x, y, w + 0.5, h + 0.5, w + 0.474, h + 0.474, 0.0312, 0.002),
          m_gold())
    silicon = led.mat("Silizium", (0.03, 0.03, 0.045), 0.7, 0.2)
    led.rounded_box(r, "Chip" + tag, (w + 0.02, h + 0.02, 0.03), (x, y, 0.045), silicon, 0.004, 0.002)
    screen(r, x, y, w, h, 0.06, kind)
    gap = lambda p: p[3] < 0 and abs(p[0] - x) < 0.5
    fingers, casts = [], []
    wire = led.mat("Bonddraht", (0.83, 0.6, 0.22), 1.0, 0.25)
    for i, (px, py, nx, ny) in enumerate(rim_points(x, y, w + 0.02, h + 0.02, 0.06, gap)):
        fingers.append((px + nx * 0.135, py + ny * 0.135, 0.031,
                        abs(nx) * 0.09 + abs(ny) * 0.026, abs(ny) * 0.09 + abs(nx) * 0.026, 0.002))
        dm.beam(r, "Draht", (px - nx * 0.02, py - ny * 0.02, 0.0605),
                (px + nx * 0.1, py + ny * 0.1, 0.0325), 0.0035, wire)
    boxes(r, "Finger", fingers, m_gold())
    for px, py, nx, ny in rim_points(x, y, w + 0.56, h + 0.56, 0.14):
        casts.append((px, py, 0.015, abs(nx) * 0.012 + abs(ny) * 0.06,
                      abs(ny) * 0.012 + abs(nx) * 0.06, 0.031))
    boxes(r, "Kastellen", casts, m_gold())
    text(r, mark, x, y - h * 0.5 - 0.125, 0.0305, 0.04, m_gold(), "Marke")
    return 0.28


def pit_c(x, y, w, h):
    d, s, sw = 0.11, 0.035, 0.1
    r = root("Kavitaet")
    boxes(r, "Boden", [(x, y, -d - 0.005, w, h, 0.01)],
          led.mat("Kavitaetsboden", (0.016, 0.016, 0.024), 0.0, 0.4))
    boxes(r, "Stufe", ring_items(x, y, w, h, w - sw * 2, h - sw * 2, -(d + s) * 0.5, d - s),
          m_ceramic())
    boxes(r, "Wand", ring_items(x, y, w + 0.004, h + 0.004, w, h, -s * 0.5, s), m_ceramic())
    fingers = []
    for px, py, nx, ny in rim_points(x, y, w - sw * 2, h - sw * 2, 0.06):
        fingers.append((px + nx * 0.05, py + ny * 0.05, -s + 0.001,
                        abs(nx) * 0.07 + abs(ny) * 0.026, abs(ny) * 0.07 + abs(nx) * 0.026, 0.002))
    boxes(r, "Finger", fingers, m_gold())
    iw, ih = w - sw * 2 - 0.08, h - sw * 2 - 0.08
    boxes(r, "Bodenlinie", ring_items(x, y, iw, ih, iw - 0.012, ih - 0.012, -d + 0.001, 0.001),
          m_gold())
    marks = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = x + sx * (iw * 0.5 - 0.12), y + sy * (ih * 0.5 - 0.12)
            marks += [(cx, cy, -d + 0.001, 0.09, 0.008, 0.001), (cx, cy, -d + 0.001, 0.008, 0.09,
                                                                 0.001)]
    boxes(r, "Passkreuze", marks, m_gold())
    boxes(r, "Kragen", ring_items(x, y, w + 0.36, h + 0.36, w, h, 0.004, 0.008), m_ceramic())
    boxes(r, "Siegel", ring_items(x, y, w + 0.26, h + 0.26, w + 0.23, h + 0.23, 0.0085, 0.002),
          m_gold())
    casts = []
    for px, py, nx, ny in rim_points(x, y, w + 0.36, h + 0.36, 0.14):
        casts.append((px, py, 0.004, abs(nx) * 0.012 + abs(ny) * 0.06,
                      abs(ny) * 0.012 + abs(nx) * 0.06, 0.009))
    boxes(r, "Kastellen", casts, m_gold())
    dice(-d)
    return 0.18, "C · CHIP AUF KERAMIK + GESTUFTE KAVITÄT   (Grube 0,6 Kanten, eine Stufe)"


# --- D: Service-Modul-Platine und Platinen-Wanne --------------------------------------------

def chip_d(tag, x, y, w, h, kind, mark):
    r = root("Chip" + tag)
    bx, by, bw, bh = x + 0.185, y - 0.07, w + 0.73, h + 0.5
    led.rounded_box(r, "Platine" + tag, (bw, bh, 0.008), (bx, by, 0.004), m_board(), 0.04, 0.0)
    led.rounded_box(r, "Blende" + tag, (w + 0.05, h + 0.05, 0.03), (x, y, 0.023), m_epoxy(), 0.03,
                    0.004)
    screen(r, x, y, w, h, 0.038, kind)
    y0 = by - bh * 0.5
    fingers, lines = [], []
    n = int((w - 0.1) / 0.07)
    for i in range(n):
        fx = x + (i - (n - 1) * 0.5) * 0.07
        fingers.append((fx, y0 + 0.075, 0.009, 0.04, 0.11, 0.002))
        lines.append([(fx, y0 + 0.14), (fx, y0 + 0.18), (fx + 0.025, y0 + 0.205),
                      (fx + 0.025, y - h * 0.5 - 0.03)])
    boxes(r, "Kontaktleiste", fingers, m_gold())
    sx = x + w * 0.5 + 0.3
    k = int((h - 0.16) / 0.06)
    for i in range(k):
        yy = y + (i - (k - 1) * 0.5) * 0.06
        lines.append([(x + w * 0.5 + 0.03, yy), (x + w * 0.5 + 0.13, yy)])
    strips(r, "Bahnen", lines, 0.008, 0.0085, m_trace())
    pads = []
    if h > 1.0:
        ey = y + h * 0.5 - 0.45
        boxes(r, "Eprom", [(sx, ey, 0.03, 0.2, 0.5, 0.04)],
              led.mat("Epromkeramik", (0.16, 0.13, 0.2), 0.0, 0.45))
        dm.cyl(r, "Fenster" + tag, 0.055, 0.002, (sx, ey + 0.1, 0.051),
               led.mat("Quarz", (0.6, 0.45, 0.2), 0.8, 0.15), 32)
        boxes(r, "Eprombeine", [(sx + s * 0.115, ey + (i - 3.5) * 0.06, 0.016, 0.04, 0.022, 0.016)
                                for i in range(8) for s in (-1, 1)], m_steel())
        boxes(r, "Qfp", [(sx, y, 0.02, 0.24, 0.24, 0.025)], m_epoxy())
        boxes(r, "Qfpbeine", [(px + nx * 0.012, py + ny * 0.012, 0.013,
                               abs(nx) * 0.03 + abs(ny) * 0.012, abs(ny) * 0.03 + abs(nx) * 0.012,
                               0.008) for px, py, nx, ny in rim_points(sx, y, 0.24, 0.24, 0.028)],
              m_steel())
        smd(r, "Smd" + tag, [(sx - 0.08 + i * 0.08, y - 0.3) for i in range(3)], False)
        pads = [(sx + (i - 2) * 0.04, y - h * 0.5 + 0.5 + (j - 2.5) * 0.04, 0.0088, 0.018, 0.018,
                 0.001) for i in range(5) for j in range(6)]
    else:
        pads = [(sx + (i - 2) * 0.04, y + (j - 1.5) * 0.04, 0.0088, 0.018, 0.018, 0.001)
                for i in range(5) for j in range(4)]
    boxes(r, "Padfeld", pads, m_gold())
    for sxn in (-1, 1):
        for syn in (-1, 1):
            if syn < 0 and sxn < 0:
                continue
            dm.cyl(r, "Bolzen" + tag, 0.035, 0.012,
                   (bx + sxn * (bw * 0.5 - 0.07), by + syn * (bh * 0.5 - 0.07), 0.014), m_steel(), 24)
    text(r, mark.split("  ·")[0], sx - 0.02, y0 + 0.2, 0.0085, 0.028, m_etch(), "Marke")
    return 0.18


def pit_d(x, y, w, h):
    d = 0.09
    hw, hh = w * 0.5, h * 0.5
    r = root("Wanne")
    boxes(r, "Boden", [(x, y, -d - 0.005, w, h, 0.01)], m_board())
    lines = []
    for b in range(3):
        base, xj = y + (b - 1) * 0.42 - 0.12, x + (b - 1) * 0.6
        for k in range(5):
            yy = base + k * 0.022
            lines.append([(x - hw + 0.06, yy), (xj - k * 0.022, yy),
                          (xj - k * 0.022 + 0.15, yy + 0.15), (x + hw - 0.06, yy + 0.15)])
    strips(r, "Bus", lines, 0.006, -d + 0.0006, m_trace())
    boxes(r, "Padfeld", [(x + hw - 0.5 + i * 0.045, y - hh + 0.12 + j * 0.045, -d + 0.001, 0.02,
                          0.02, 0.001) for i in range(8) for j in range(4)], m_gold())
    boxes(r, "Wand", ring_items(x, y, w, h, w - 0.02, h - 0.02, -d * 0.5, d), m_epoxy())
    boxes(r, "Rand", ring_items(x, y, w + 0.44, h + 0.44, w, h, 0.003, 0.006), m_board())
    boxes(r, "Vias", [(px + nx * 0.06, py + ny * 0.06, 0.0065, 0.016, 0.016, 0.001)
                      for px, py, nx, ny in rim_points(x, y, w, h, 0.05)], m_gold())
    n = int((w - 0.3) / 0.07)
    boxes(r, "Kontaktleiste", [(x + (i - (n - 1) * 0.5) * 0.07, y - hh - 0.15, 0.007, 0.04, 0.09,
                                0.002) for i in range(n)], m_gold())
    boxes(r, "Lippe", ring_items(x, y, w + 0.024, h + 0.024, w, h, 0.0065, 0.002),
          dm.glow("kuehl", 1.8))
    for sx in (-1, 1):
        for sy in (-1, 1):
            dm.cyl(r, "Bolzen", 0.035, 0.012, (x + sx * (hw + 0.15), y + sy * (hh + 0.15), 0.012),
                   m_steel(), 24)
    dice(-d)
    return 0.24, "D · SERVICE-MODUL-PLATINE + PLATINEN-WANNE   (Grube 0,5 Kanten)"


# --- E: Kühlkörper und Kupfer-Kühlplatte ----------------------------------------------------

def m_anod():
    return led.mat("Eloxal", (0.025, 0.025, 0.03), 0.8, 0.4)


def m_copper(dim=False):
    if dim:
        return led.mat("KupferMatt", (0.42, 0.18, 0.1), 1.0, 0.45)
    return led.mat("Kupfer", (0.85, 0.42, 0.25), 1.0, 0.3)


def chip_e(tag, x, y, w, h, kind, mark):
    r = root("Chip" + tag)
    led.rounded_box(r, "Sockel" + tag, (w + 0.46, h + 0.46, 0.02), (x, y, 0.01), m_anod(), 0.03, 0.0)
    fins = []
    for px, py, nx, ny in rim_points(x, y, w + 0.06, h + 0.06, 0.035):
        fins.append((px + nx * 0.105, py + ny * 0.105, 0.055, abs(nx) * 0.17 + abs(ny) * 0.012,
                     abs(ny) * 0.17 + abs(nx) * 0.012, 0.07))
    boxes(r, "Rippen", fins, m_anod())
    blocks = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = x + sx * (w * 0.5 + 0.13), y + sy * (h * 0.5 + 0.13)
            blocks.append((cx, cy, 0.045, 0.18, 0.18, 0.05))
            dm.cyl(r, "Schraube" + tag, 0.04, 0.012, (cx, cy, 0.074), m_steel(), 24)
    boxes(r, "Ecken", blocks, m_anod())
    for s in (-1, 1):
        yy = y + s * (h * 0.5 + 0.13)
        dm.beam(r, "Heatpipe", (x - w * 0.5 + 0.02, yy, 0.078), (x + w * 0.5 - 0.02, yy, 0.078),
                0.02, m_copper())
    led.rounded_box(r, "Blende" + tag, (w + 0.06, h + 0.06, 0.08), (x, y, 0.05), m_anod(), 0.03,
                    0.008)
    screen(r, x, y, w - 0.03, h - 0.03, 0.09, kind)
    return 0.23


def pit_e(x, y, w, h):
    d = 0.09
    hw, hh = w * 0.5, h * 0.5
    r = root("Kuehlplatte")
    boxes(r, "Boden", [(x, y, -d - 0.005, w, h, 0.01)], m_copper(True))
    strips(r, "Rillen", [[(x - hw + 0.08, y + j * 0.1), (x + hw - 0.08, y + j * 0.1)]
                         for j in range(-6, 7)], 0.004, -d + 0.0006,
           led.mat("Rille", (0.2, 0.08, 0.045), 1.0, 0.5))
    fins = []
    for px, py, nx, ny in rim_points(x, y, w, h, 0.035):
        fins.append((px - nx * 0.016, py - ny * 0.016, -d * 0.5, abs(nx) * 0.032 + abs(ny) * 0.012,
                     abs(ny) * 0.032 + abs(nx) * 0.012, d))
    boxes(r, "Rippenwand", fins, m_anod())
    boxes(r, "Rahmen", ring_items(x, y, w + 0.24, h + 0.24, w, h, 0.006, 0.012), m_anod())
    boxes(r, "Lippe", ring_items(x, y, w + 0.02, h + 0.02, w, h, 0.0125, 0.002),
          dm.glow("kuehl", 1.8))
    for sx in (-1, 1):
        for sy in (-1, 1):
            dm.cyl(r, "Schraube", 0.035, 0.008, (x + sx * (hw + 0.06), y + sy * (hh + 0.06), 0.014),
                   m_steel(), 24)
            dm.cyl(r, "Bodenschraube", 0.03, 0.004,
                   (x + sx * (hw - 0.14), y + sy * (hh - 0.14), -d + 0.002), m_steel(), 24)
    dice(-d)
    return 0.14, "E · KÜHLKÖRPER + KUPFER-KÜHLPLATTE   (Grube 0,5 Kanten, Rippenwand)"


# --- F: Die-Shot und Silizium-Grube ---------------------------------------------------------

TONES = [(0.03, 0.035, 0.085), (0.018, 0.06, 0.07), (0.075, 0.05, 0.032), (0.05, 0.03, 0.075),
         (0.025, 0.025, 0.035)]


def bsp(rect, rnd, out, limit, depth=0):
    x0, y0, x1, y1 = rect
    w, h = x1 - x0, y1 - y0
    if depth >= 7 or (w < limit and h < limit) or (depth > 2 and rnd.random() < 0.15):
        out.append(rect)
        return
    t = rnd.uniform(0.35, 0.65)
    if w > h:
        bsp((x0, y0, x0 + w * t, y1), rnd, out, limit, depth + 1)
        bsp((x0 + w * t, y0, x1, y1), rnd, out, limit, depth + 1)
    else:
        bsp((x0, y0, x1, y0 + h * t), rnd, out, limit, depth + 1)
        bsp((x0, y0 + h * t, x1, y1), rnd, out, limit, depth + 1)


def floorplan(r, name, rects, z, seed, limit):
    """Der Die-Shot: Funktionsblöcke in fünf dunklen Tönen, manche als Speicherfeld schraffiert."""
    rnd = random.Random(seed)
    cells = []
    for rect in rects:
        bsp(rect, rnd, cells, limit)
    groups, hatch = [[] for _ in TONES], []
    for x0, y0, x1, y1 in cells:
        g = 0.006
        groups[rnd.randrange(len(TONES))].append(((x0 + x1) * 0.5, (y0 + y1) * 0.5, z,
                                                  x1 - x0 - g * 2, y1 - y0 - g * 2, 0.001))
        if rnd.random() < 0.35:
            yy = y0 + g + 0.016
            while yy < y1 - g - 0.01:
                hatch.append([(x0 + g + 0.012, yy), (x1 - g - 0.012, yy)])
                yy += 0.022
    for i, items in enumerate(groups):
        if items:
            boxes(r, "%s%d" % (name, i), items, led.mat("Block%d" % i, TONES[i], 0.7, 0.3))
    if hatch:
        strips(r, name + "Feld", hatch, 0.005, z + 0.0008,
               led.mat("Speicherfeld", (0.09, 0.1, 0.16), 0.7, 0.3))


def chip_f(tag, x, y, w, h, kind, mark):
    r = root("Chip" + tag)
    silicon = led.mat("Silizium", (0.02, 0.02, 0.03), 0.6, 0.25)
    led.rounded_box(r, "Traeger" + tag, (w + 0.5, h + 0.5, 0.02), (x, y, 0.01), silicon, 0.01, 0.0)
    hw, hh, a, b = w * 0.5, h * 0.5, 0.02, 0.19
    rects = [(x - hw - b, y + hh + a, x + hw + b, y + hh + b),
             (x - hw - b, y - hh - b, x + hw + b, y - hh - a),
             (x - hw - b, y - hh - a, x - hw - a, y + hh + a),
             (x + hw + a, y - hh - a, x + hw + b, y + hh + a)]
    floorplan(r, "Plan", rects, 0.0205, len(tag), 0.36)
    boxes(r, "Bondpads", [(px, py, 0.0205, 0.026, 0.026, 0.001)
                          for px, py, nx, ny in rim_points(x, y, w + 0.43, h + 0.43, 0.07)], m_gold())
    boxes(r, "Schutzring", ring_items(x, y, w + 0.49, h + 0.49, w + 0.476, h + 0.476, 0.0205, 0.001),
          m_gold())
    screen(r, x, y, w, h, 0.02, kind)
    return 0.25


def pit_f(x, y, w, h):
    d = 0.11
    hw, hh = w * 0.5, h * 0.5
    r = root("Siliziumgrube")
    boxes(r, "Boden", [(x, y, -d - 0.005, w, h, 0.01)],
          led.mat("Silizium", (0.02, 0.02, 0.03), 0.6, 0.25))
    floorplan(r, "Plan", [(x - hw + 0.03, y - hh + 0.03, x + hw - 0.03, y + hh - 0.03)], -d + 0.0005,
              11, 0.4)
    boxes(r, "Lichtwand", ring_items(x, y, w, h, w - 0.012, h - 0.012, -d * 0.5, d),
          dm.glow("kuehl", 0.45))
    boxes(r, "Kragen", ring_items(x, y, w + 0.3, h + 0.3, w, h, 0.003, 0.006),
          led.mat("Silizium", (0.02, 0.02, 0.03), 0.6, 0.25))
    boxes(r, "Schutzring", ring_items(x, y, w + 0.26, h + 0.26, w + 0.246, h + 0.246, 0.0065, 0.001),
          m_gold())
    boxes(r, "Bondpads", [(px + nx * 0.07, py + ny * 0.07, 0.0065, 0.03, 0.03, 0.001)
                          for px, py, nx, ny in rim_points(x, y, w, h, 0.14)], m_gold())
    dice(-d)
    return 0.15, "F · DIE-SHOT + SILIZIUM-GRUBE   (Grube 0,6 Kanten, Lichtwand)"


def veins(hub_margin, pit_margin, score_margin):
    """Die LED-Adern: sie beginnen an den Kontakten des Hubs."""
    r = root("Adern")
    x0 = HUB[0] - HUB[2] * 0.5 - hub_margin
    x1 = PIT[0] + PIT[2] * 0.5 + pit_margin
    xs = SCORE[0] + SCORE[2] * 0.5 + score_margin
    lines = []
    for k in range(4):
        ya, yb = -0.1 - k * 0.07, PIT[1] + 0.25 - k * 0.07
        xm = x0 - 0.12 - k * 0.07
        lines.append([(x0, ya), (xm, ya), (xm - (ya - yb), yb), (x1, yb)])
    for k in range(2):
        y = SCORE[1] + 0.07 - k * 0.07
        lines.append([(x0, y), (xs, y)])
    strips(r, "Adern", lines, 0.012, 0.0015, dm.glow("kuehl", 2.2))


VARIANTS = {"a_sockel": (chip_a, pit_a), "b_qfp": (chip_b, pit_b), "c_keramik": (chip_c, pit_c),
            "d_modul": (chip_d, pit_d), "e_kuehler": (chip_e, pit_e), "f_dieshot": (chip_f, pit_f)}
DEPTHS = {"a_sockel": 0.09, "b_qfp": 0.06, "c_keramik": 0.11, "d_modul": 0.09, "e_kuehler": 0.09,
          "f_dieshot": 0.11}


def build(name):
    chip, pit = VARIANTS[name]
    felt_table([(PIT[0], PIT[1], PIT[2], PIT[3], DEPTHS[name] + 0.02)])
    pm, title = pit(*PIT)
    hm = chip("Hub", HUB[0], HUB[1], HUB[2], HUB[3], "hub", "FUMBLE  FX-6  HUB  ·  L0420B117")
    sm = chip("Wertung", SCORE[0], SCORE[1], SCORE[2], SCORE[3], "score", "FUMBLE  FX-2  ·  B117")
    veins(hm, pm, sm)
    ms.label("U1 · HUB", HUB[0] - HUB[2] * 0.5 + 0.1, HUB[1] + HUB[3] * 0.5 + hm + 0.1, 0.085)
    ms.label("U2 · WERTUNG", SCORE[0] - SCORE[2] * 0.5 + 0.2, SCORE[1] + SCORE[3] * 0.5 + sm + 0.1,
             0.085)
    ms.label("J1 · WURFGRUBE", PIT[0] - PIT[2] * 0.5 + 0.25, PIT[1] - PIT[3] * 0.5 - pm - 0.12,
             0.085)
    ms.label(title, 0.05, -2.05, 0.13)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    argv = sys.argv[sys.argv.index("--") + 1:]
    only = argv[1].split(",") if len(argv) > 1 else []
    for name in VARIANTS:
        if only and name not in only:
            continue
        cam, aim = dm.empty_stage()
        for o in bpy.data.objects:
            mats = getattr(o.data, "materials", None) if o.data is not None else None
            if mats and mats[0] is not None and mats[0].name.startswith("Softbox"):
                o.location.z += 30.0
        build(name)
        scene = bpy.context.scene
        scene.eevee.taa_render_samples = 48
        scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
        ms.station(cam, aim, Vector((0.05, 0.0, 0)), 8.2 * 50 / 36 * 1.02)
        scene.render.filepath = os.path.join(OUT, name + "_station.png")
        bpy.ops.render.render(write_still=True)
        aim.location = (-0.7, -0.45, 0)
        cam.location = (0.9, -3.6, 1.7)
        cam.data.lens = 40
        scene.render.filepath = os.path.join(OUT, name + "_naht.png")
        bpy.ops.render.render(write_still=True)
        aim.location = (-1.75, -0.3, -0.03)
        cam.location = (-2.9, -2.5, 0.95)
        cam.data.lens = 38
        scene.render.filepath = os.path.join(OUT, name + "_grube.png")
        bpy.ops.render.render(write_still=True)
    print("ok")
