"""Fumble: exportiert die HÜLLEN der vier Datenträger (Welle 3, 2026-11-18) nach
assets/models/hardware/ - data_punch_card.glb, data_cassette.glb, data_clay_tablet.glb,
data_holo_emitter.glb. Vorbild ist tools/blender_data_media_set.py (Kassette KLASSIK und Tontafel KEILSCHRIFT seit dem
2026-11-19 nach tools/blender_data_media_real.py); dies ist die Fassung OHNE
Inhalt: kein Netz, keine Werte, keine Runen, kein Text. Das Netz backt Godot (StampNetOven).

Aufruf (kopflos):
  blender -b -P tools/blender_data_media_export.py -- <ausgabe-ordner> [render <bild-ordner>]

Achsen: X = Länge (Kopf -X, Fuß +X), Y = Breite, Z = Höhe, Ursprung = Mitte der Grundfläche.
Der Umriß ist der der liegenden Karte (1,62 x 1,08), das Netz-Feld liegt GENAU wie im Spiel
(DataCellView: Mitte 0,0486 zum Kopf, Zelle 0,2924, Teilung 0,3216, Querbalken in Reihe 2
vom Kopf). Jedes Objekt heißt nach seiner ROLLE (Koerper, Kern, Saum, Druck, Metall, Dunkel,
Glanz, Ton, Hell, Band, Kerbe); je Rolle wird EIN Netz exportiert, Godot gibt die Materialien nach dem Namen.
"""
import bpy, bmesh, math, os, random, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_data_media as dm

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/hardware"
RENDER = ARGS[2] if len(ARGS) > 2 and ARGS[1] == "render" else ""

L, W = 1.62, 1.08
C = 1.08 * (1.0 - 2.0 * 0.0668) / 3.2   # Zelle wie DataCellView.net_size()
P = C * 1.1                              # Teilung samt Fuge
NX = -1.62 * (0.135 - 0.075) * 0.5       # Netz-Mitte, zum Kopf verschoben
ARM = [NX - (1.5 - k) * P for k in range(4)]
CELLS = [(x, 0.0) for x in ARM] + [(ARM[1], P), (ARM[1], -P)]
FREE = [(ARM[0], P), (ARM[0], -P), (ARM[2], P), (ARM[2], -P), (ARM[3], P), (ARM[3], -P)]
NET_HX, NET_HY = 2.15 * C, 1.6 * C
ROLES = ("Koerper", "Kern", "Saum", "Druck", "Metall", "Dunkel", "Glanz", "Ton", "Hell", "Band",
         "Kerbe")
LIFT = 0.0015


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    led._mats.clear()
    led.base_materials()


def mats(key):
    """Vorschau-Materialien je Rolle; Godot ersetzt sie alle."""
    glow = dm.col(key)
    return {
        "Kern": led.mat("Kern_" + key, glow, 0.0, 0.3, 2.4),
        "Saum": led.mat("Saum_" + key, glow, 0.0, 0.3, 1.5),
        "Druck": led.mat("Druck_" + key, glow, 0.0, 0.6, 0.12),
        "Metall": led.mat("Metall", (0.62, 0.64, 0.68), 0.9, 0.25),
        "Dunkel": led.mat("Dunkel", (0.006, 0.006, 0.008), 0.0, 0.6),
        "Glanz": led.mat("Glanz", (0.02, 0.035, 0.05), 0.0, 0.05, clearcoat=1.0),
        "Ton": led.mat("Ton", (0.29, 0.22, 0.16), 0.0, 0.92),
        "Hell": led.mat("Hell", (0.78, 0.74, 0.68), 0.0, 0.8),
        "Band": led.mat("Band", (0.2, 0.1, 0.06), 0.3, 0.35),
        "Kerbe": led.mat("Kerbe", (0.1, 0.07, 0.045), 0.0, 0.95),
    }


def box(name, size, loc, material, corner=0.0, edge=0.0, segs=3):
    return led.rounded_box(None, name, size, loc, material, corner, edge, segs)


def slab(name, x0, y0, x1, y1, z0, z1, material):
    return box(name, (abs(x1 - x0), abs(y1 - y0), z1 - z0),
               ((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), material)


def line(name, z, a0, b0, a1, b1, w, material, lift=LIFT):
    """Ein flacher Streifen, Normale nach OBEN (Godot kappt Rückseiten)."""
    d = Vector((a1 - a0, b1 - b0))
    p = Vector((-d.y, d.x)).normalized() * w * 0.5
    zz = z + lift
    pts = [(a0 - p.x, b0 - p.y, zz), (a1 - p.x, b1 - p.y, zz), (a1 + p.x, b1 + p.y, zz),
           (a0 + p.x, b0 + p.y, zz)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(pts, [], [[0, 1, 2, 3]])
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def prism(name, tris, z0, z1, material):
    """Flache Dreiecks-Prismen in EINEM Netz (Keile, Kerben)."""
    verts, faces = [], []
    for tri in tris:
        k = len(verts)
        verts += [(x, y, z0) for x, y in tri] + [(x, y, z1) for x, y in tri]
        faces += [[k + 2, k + 1, k], [k + 3, k + 4, k + 5], [k, k + 1, k + 4, k + 3],
                  [k + 1, k + 2, k + 5, k + 4], [k + 2, k, k + 3, k + 5]]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def wedge(x, y, s, ang):
    ca, sa = math.cos(ang), math.sin(ang)
    return [(x + a * ca - b * sa, y + a * sa + b * ca)
            for a, b in ((0.0, s * 0.5), (0.0, -s * 0.5), (s, 0.0))]


def in_net(x, y, pad):
    """Liegt der Punkt in einer Netz-Zelle (samt Rand)?"""
    half = C * 0.5 + pad
    return any(abs(x - cx) < half and abs(y - cy) < half for cx, cy in CELLS)


def in_field(x, y, pad=0.0):
    return abs(x - NX) < NET_HX + pad and abs(y) < NET_HY + pad


def corner_cutter(size):
    bpy.ops.mesh.primitive_cube_add(size=size, location=(-L * 0.5, W * 0.5, 0.0),
                                    rotation=(0, 0, math.radians(45)))
    o = bpy.context.active_object
    o.name = "SchnittEcke"
    return o


# --- ZAHLEN: die Lochkarte ------------------------------------------------------------------

PT, PLAYER, PCORE = 0.04, 0.017, 0.006
CORNER_CUT = 0.22


def punch_card():
    m = mats("zahl")
    black = led.mat("Neonkarton", (0.03, 0.03, 0.036), 0.0, 0.55, clearcoat=0.3)
    lower = box("KoerperUnterlage", (L, W, PLAYER), (0, 0, PLAYER * 0.5), black, 0.02)
    core = box("KernSchicht", (L - 0.004, W - 0.004, PCORE), (0, 0, PLAYER + PCORE * 0.5),
               m["Kern"], 0.02)
    top = box("KoerperKarte", (L, W, PT - PLAYER - PCORE),
              (0, 0, (PT + PLAYER + PCORE) * 0.5), black, 0.02)
    cutter = corner_cutter(CORNER_CUT)
    for o in (lower, core, top):
        led.cut(o, cutter)
    leg = CORNER_CUT / math.sqrt(2.0)
    # Die STANZUNGEN gehen nur durch die obere Lage: der Kern scheint hindurch.
    shapes = []
    y = -0.47
    while (W * 0.5 - y) > leg + 0.05:
        shapes.append(("rect", -0.797, y - 0.017, -0.769, y + 0.017))
        y += 0.06
    rnd = random.Random(7)
    for i in range(20):
        x = -0.72 + i * 1.49 / 19
        for d in range(10):
            yy = 0.44 - d * 0.88 / 9
            if in_net(x, yy, 0.03) or (in_field(x, yy) and not any(
                    abs(x - fx) < C * 0.5 and abs(yy - fy) < C * 0.5 for fx, fy in FREE)):
                continue
            if (x + L * 0.5) + (W * 0.5 - yy) < leg + 0.06 or yy > 0.46:
                continue
            if rnd.random() < 0.16:
                shapes.append(("rect", x - 0.011, yy - 0.022, x + 0.011, yy + 0.022))
            else:
                glyph("Druck%d_%d" % (i, d), str(d), x, yy, PT + LIFT, 0.04, m["Druck"])
    led.cut(top, dm.hole_cutter(None, "SchnittStanzungen", shapes, PLAYER + PCORE * 0.5, 0.1))
    e = 0.014
    rim = [(-L * 0.5 + e, W * 0.5 - leg - e * 0.4), (-L * 0.5 + leg + e * 0.4, W * 0.5 - e),
           (L * 0.5 - e, W * 0.5 - e), (L * 0.5 - e, -W * 0.5 + e), (-L * 0.5 + e, -W * 0.5 + e),
           (-L * 0.5 + e, W * 0.5 - leg - e * 0.4)]
    for k in range(len(rim) - 1):
        a, b = rim[k], rim[k + 1]
        line("Saum%d" % k, PT, a[0], a[1], b[0], b[1], 0.006, m["Saum"])
    line("KernStreifen", PT, -L * 0.5 + leg + 0.02, 0.503, L * 0.5 - 0.03, 0.503, 0.026, m["Kern"])
    # Die Spalten-Teilung als feine Haarlinien im Fuß - der Rhythmus der Karte.
    for i in range(12):
        x = 0.06 + i * 0.045
        line("Dunkel%d" % i, PT, x, -0.52, x, -0.49, 0.004, m["Dunkel"])


def glyph(name, body, x, y, z, size, material):
    """Ein Schriftzeichen als flaches Netz (Normale nach oben)."""
    bpy.ops.object.text_add(location=(x, y, z))
    t = bpy.context.active_object
    t.data.body = body
    t.data.size = size
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    bpy.ops.object.convert(target="MESH")
    t = bpy.context.active_object
    t.name = name
    t.data.materials.append(material)
    return t


def quad_prism(name, pts, z0, z1, material):
    n = len(pts)
    verts = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    faces = [list(range(n - 1, -1, -1)), list(range(n, 2 * n))]
    faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    return o


# --- MATERIAL: die Kassette (KLASSIK, 2026-11-19) ---------------------------------------------

CT = 0.126
RX, RR = 0.52, 0.135


def cassette():
    """Schwarze Schale, Papier-Etikett hinter dem Netz, Sichtfenster mit zwei Naben am Kopf der
    Langseite, darunter die Kopfpartie als Trapez. Im Netz-Feld bleibt alles unter CT + 0,004."""
    m = mats("material")
    shell = led.mat("Kassettenschale", (0.02, 0.02, 0.024), 0.0, 0.42, clearcoat=0.2)
    box("Koerper", (L - 0.008, W - 0.008, CT), (0, 0, CT * 0.5), shell, 0.05, 0.01, 3)
    seam = box("KernNaht", (L, W, 0.01), (0, 0, CT * 0.5), m["Kern"], 0.054)
    led.cut(seam, box("SchnittNaht", (L - 0.03, W - 0.03, 0.05), (0, 0, CT * 0.5), m["Dunkel"],
                      0.04))
    bpy.data.objects["SchnittNaht"].display_type = "WIRE"
    z = CT
    box("HellEtikett", (1.5, 0.74, 0.0015), (0, 0.13, z + 0.00075), m["Hell"], 0.04)
    for k, y in enumerate((-0.2, -0.218)):
        line("SaumEtikett%d" % k, z + 0.0015, -0.74, y, 0.74, y, 0.008, m["Saum"], 0.0006)
    for s in (-1, 1):
        line("DruckSeitenband%d" % (s + 1), z + 0.0015, s * 0.705, -0.17, s * 0.705, 0.17, 0.05,
             m["Druck"], 0.0006)
    glyph("DunkelSeite", "A", -0.705, 0.0, z + 0.0026, 0.06, m["Dunkel"])
    # Das SICHTFENSTER: Wickel, Naben mit sechs Zähnen, dazwischen das Band.
    box("GlanzFenster", (1.38, 0.33, 0.0015), (0, P, z + 0.00225), m["Glanz"], 0.06)
    zw = z + 0.003
    for s, f in ((-1, 0.75), (1, 0.3)):
        x = s * RX
        dm.cyl(None, "BandWickel%d" % (s + 1), RR * (0.72 + 0.34 * f), 0.002, (x, P, zw + 0.001),
               m["Band"], 28)
        dm.annulus(None, "HellNabe%d" % (s + 1), x, P, zw + 0.0035, RR * 0.38, RR * 0.62,
                   m["Hell"], 24)
        for k in range(6):
            a = k * math.tau / 6
            line("HellZahn%d_%d" % (s + 1, k), zw + 0.0035, x + math.cos(a) * RR * 0.18, P +
                 math.sin(a) * RR * 0.18, x + math.cos(a) * RR * 0.4, P + math.sin(a) * RR * 0.4,
                 RR * 0.12, m["Hell"], 0.0)
        dm.annulus(None, "SaumFensterring%d" % (s + 1), x, P, zw + 0.004, RR * 1.08, RR * 1.17,
                   m["Saum"], 28)
    for k, (a, b) in enumerate(((-RX, ARM[1] - C * 0.5 - 0.02), (ARM[1] + C * 0.5 + 0.02, RX))):
        line("BandFenster%d" % k, zw, a, P - 0.135, b, P - 0.135, 0.012, m["Band"], 0.0008)
    for k in range(5):
        x = 0.06 + k * 0.03
        line("HellSkala%d" % k, zw, x, P - 0.055, x, P + 0.055 - (k % 2) * 0.04, 0.004, m["Hell"],
             0.0008)
    # Die KOPFPARTIE: erhabenes Trapez mit Capstan- und Paßlöchern, an der Kante zwei Kerben.
    trap = [(-0.66, -0.536), (0.66, -0.536), (0.56, -0.2), (-0.56, -0.2)]
    quad_prism("KoerperKopfpartie", trap, z - 0.001, z + 0.003, shell)
    for k in range(1, 4):
        a, b = trap[k], trap[(k + 1) % 4]
        line("DunkelKopfkante%d" % k, z + 0.003, a[0], a[1], b[0], b[1], 0.008, m["Dunkel"],
             0.0006)
    for k, (x, y, r) in enumerate(((-0.47, -0.4, 0.04), (0.47, -0.4, 0.04), (-0.29, -0.43, 0.026),
                                   (0.29, -0.43, 0.026))):
        if not in_net(x, y, r + 0.01):
            dm.cyl(None, "DunkelLoch%d" % k, r, 0.001, (x, y, z + 0.0041), m["Dunkel"], 18)
    for s in (-1, 1):
        slab("DunkelKerbe%d" % (s + 1), s * 0.6 - 0.03, -0.536, s * 0.6 + 0.03, -0.49, z + 0.003,
             z + 0.0042, m["Dunkel"])
    for k, (x, y) in enumerate(((0.76, 0.49), (0.76, -0.49), (-0.76, 0.49), (-0.76, -0.49))):
        dm.cyl(None, "MetallSchraube%d" % k, 0.024, 0.006, (x, y, z + 0.003), m["Metall"], 10)
        line("DunkelSchlitz%d" % k, z + 0.006, x - 0.016, y, x + 0.016, y, 0.005, m["Dunkel"],
             0.0006)


# --- RUNEN: die Tontafel (KEILSCHRIFT, 2026-11-19) ---------------------------------------------

TT = 0.128


def clay_tablet():
    """Helle Kissen-Tafel, dicht in Zeilen beschrieben: Keile und Zeilen-Rillen rings ums Netz."""
    m = mats("rune")
    clay = led.mat("Ton_hell", (0.45, 0.34, 0.22), 0.0, 0.95)
    box("Koerper", (L - 0.012, W - 0.012, TT), (0, 0, TT * 0.5), clay, 0.15, 0.05, 6)
    rnd = random.Random(11)
    marks = []
    row, step, size = 0.082, 0.052, 0.03
    y = 0.47 - row * 0.5
    r = 0
    while y > -0.46:
        x = -0.69
        start = None
        while x < 0.72:
            free = not in_net(x, y, 0.04) and not in_net(x + size, y, 0.04)
            if free:
                start = x if start is None else start
                if rnd.random() > 0.12:
                    ang = rnd.choice((-math.pi * 0.5, -math.pi * 0.5, 0.0, 0.0, math.pi * 0.75))
                    dy = row * 0.3 if ang < 0 else rnd.uniform(-0.01, 0.01)
                    marks.append(wedge(x, y + dy, size, ang))
            if (not free or x + step >= 0.72) and start is not None:
                if x - start > 0.1 and not in_net((start + x) * 0.5, y + row * 0.5, 0.02):
                    line("KerbeZeile%d_%d" % (r, len(marks)), TT, start - 0.01, y + row * 0.5,
                         x - 0.02, y + row * 0.5, 0.006, m["Kerbe"])
                start = None
            x += step
        y -= row
        r += 1
    prism("KerbeKeile", marks, TT - 0.002, TT + LIFT, m["Kerbe"])
    # Was GLÜHT (Griff, Aufflammen): eine Spalte glasierter Keile am Kopf, ein Glasur-Saum am Fuß.
    seal = []
    y = -0.4
    while y < 0.41:
        seal.append(wedge(-0.765, y, 0.03, 0.0))
        y += 0.066
    prism("KernSiegelkeile", seal, TT - 0.002, TT + LIFT, m["Kern"])
    rim = box("SaumFuss", (L - 0.004, W - 0.004, 0.008), (0, 0, TT * 0.5), m["Saum"], 0.154)
    led.cut(rim, box("SchnittFuss", (L - 0.03, W - 0.03, 0.05), (0, 0, TT * 0.5), m["Dunkel"],
                     0.14))
    bpy.data.objects["SchnittFuss"].display_type = "WIRE"


# --- SONDERBESTAND: der Holo-Emitter ---------------------------------------------------------

HT = 0.06


def cross_outline():
    """Der Umriß des Netz-Kreuzes, wie es im Spiel liegt (Querbalken in Reihe 2 vom Kopf)."""
    h = P * 0.5
    a0, a3 = ARM[0] - h, ARM[3] + h
    b0, b1 = ARM[1] - h, ARM[1] + h
    return [(a0, -h), (b0, -h), (b0, -3 * h), (b1, -3 * h), (b1, -h), (a3, -h), (a3, h),
            (b1, h), (b1, 3 * h), (b0, 3 * h), (b0, h), (a0, h)]


def holo_emitter():
    m = mats("gold")
    base = led.mat("Emitter", (0.025, 0.028, 0.035), 0.6, 0.25, clearcoat=0.8)
    box("Koerper", (L - 0.006, W - 0.006, HT), (0, 0, HT * 0.5), base, 0.08, 0.008, 3)
    ring = box("SaumRand", (L, W, 0.008), (0, 0, HT * 0.5), m["Saum"], 0.083)
    led.cut(ring, box("SchnittRand", (L - 0.02, W - 0.02, 0.05), (0, 0, HT * 0.5), m["Dunkel"],
                      0.075))
    bpy.data.objects["SchnittRand"].display_type = "WIRE"
    box("GlanzLinse", (1.36, 1.02, 0.003), (NX, 0, HT + 0.0015), m["Glanz"], 0.05)
    zl = HT + 0.003
    pts = cross_outline()
    for k in range(len(pts)):
        a, b = pts[k], pts[(k + 1) % len(pts)]
        line("KernUmriss%d" % k, zl, a[0], a[1], b[0], b[1], 0.010, m["Kern"])
    h = P * 0.5
    for k, (a0, b0, a1, b1) in enumerate((
            (ARM[0] + h, -h, ARM[0] + h, h), (ARM[1] + h, -h, ARM[1] + h, h),
            (ARM[2] + h, -h, ARM[2] + h, h), (ARM[1] - h, h, ARM[1] + h, h),
            (ARM[1] - h, -h, ARM[1] + h, -h))):
        line("SaumTeiler%d" % k, zl, a0, b0, a1, b1, 0.004, m["Saum"], LIFT * 0.6)
    dots = []
    for x, y in CELLS:
        for i in range(3):
            for j in range(3):
                dots.append((x + (i - 1) * C * 0.28, y + (j - 1) * C * 0.28, zl + 0.002))
    dm.dots(None, "KernPunkte", dots, 0.0055, m["Kern"])
    for k, (x, y) in enumerate([(sx, sy * 0.44) for sx in (-0.768, 0.735) for sy in (-1, 1)]):
        dm.cyl(None, "MetallKnotenfuss%d" % k, 0.04, 0.006, (x, y, HT + 0.003), m["Metall"], 14)
        dm.cyl(None, "KernKnoten%d" % k, 0.03, 0.01, (x, y, HT + 0.005), m["Kern"], 14)
    box("KernKopfbalken", (0.016, 0.8, 0.004), (-0.785, 0, HT + 0.002), m["Kern"])
    box("KernStirnbalken", (0.004, 0.8, 0.022), (-0.8075, 0, HT * 0.5), m["Kern"])


# --- Abschluß ------------------------------------------------------------------------------

def bake_down():
    """Schnitte anwenden, Schnittkörper fort, je ROLLE ein Netz."""
    for o in list(bpy.data.objects):
        if o.type != "MESH" or o.display_type == "WIRE":
            continue
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    for o in list(bpy.data.objects):
        if o.type == "MESH" and (o.display_type == "WIRE" or o.name.startswith("Schnitt")):
            bpy.data.objects.remove(o, do_unlink=True)
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    for role in ROLES:
        parts = [o for o in bpy.data.objects if o.name.startswith(role)]
        if not parts:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        if len(parts) > 1:
            bpy.ops.object.join()
        parts[0].name = role
        parts[0].data.name = role
    stray = [o.name for o in bpy.data.objects if o.name not in ROLES]
    assert not stray, "ohne Rolle: %s" % stray


def report(name):
    dg = bpy.context.evaluated_depsgraph_get()
    total = 0
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in bpy.data.objects:
        bm = bmesh.new()
        bm.from_object(o, dg)
        bm.transform(o.matrix_world)
        tris = len(bm.calc_loop_triangles())
        total += tris
        for v in bm.verts:
            lo = Vector(min(a, b) for a, b in zip(lo, v.co))
            hi = Vector(max(a, b) for a, b in zip(hi, v.co))
        bm.free()
        print("  %-8s %5d Dreiecke" % (o.name, tris))
    print("TRAEGER %-18s %5d Dreiecke  X %.4f..%.4f  Y %.4f..%.4f  Z %.4f..%.4f" %
          (name, total, lo.x, hi.x, lo.y, hi.y, lo.z, hi.z))


CARRIERS = [("data_punch_card", punch_card), ("data_cassette", cassette),
            ("data_clay_tablet", clay_tablet), ("data_holo_emitter", holo_emitter)]


def export_all():
    os.makedirs(OUT, exist_ok=True)
    for name, build in CARRIERS:
        reset()
        build()
        bake_down()
        report(name)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                                  export_apply=True)


def render_all():
    """Die exportierten Hüllen nebeneinander, zum Vergleich mit dem Entwurf."""
    os.makedirs(RENDER, exist_ok=True)
    for view, flat in (("huellen_draufsicht", True), ("huellen_schraeg", False)):
        cam, aim = dm.empty_stage()
        for i, (name, _build) in enumerate(CARRIERS):
            bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, name + ".glb"))
            for o in bpy.context.selected_objects:
                if o.parent is None:
                    o.location.x += -3.45 + i * 2.3
        aim.location = (0, 0, 0)
        if flat:
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = 9.4
            cam.location = (0, 0, 13)
        else:
            aim.location = (0, 0.1, 0.05)
            cam.location = (0.8, -7.2, 4.4)
            cam.data.lens = 40
        bpy.context.scene.eevee.taa_render_samples = 48
        bpy.context.scene.render.filepath = os.path.join(RENDER, view + ".png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    export_all()
    if RENDER:
        render_all()
    print("ok")
