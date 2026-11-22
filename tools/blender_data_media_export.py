"""Fumble: exportiert die HÜLLEN der vier Datenträger (Welle 3, 2026-11-18) nach
assets/models/hardware/ - data_punch_card.glb, data_cassette.glb, data_clay_tablet.glb,
data_service_module.glb. Vorbild ist tools/blender_data_media_set.py (Kassette KLASSIK und Tontafel KEILSCHRIFT seit dem
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
         "Kerbe", "Bahn", "Pad", "Keramik", "Schrift")
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
        "Bahn": led.mat("Bahn", (0.3, 0.21, 0.08), 0.3, 0.5),
        "Pad": led.mat("Pad", (0.5, 0.36, 0.13), 0.5, 0.4),
        "Keramik": led.mat("Keramik", (0.2, 0.16, 0.24), 0.0, 0.5),
        "Schrift": led.mat("Schrift", (0.3, 0.3, 0.33), 0.0, 0.7),
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
    """Die KLASSIK (Spieler-Wahl 2026-11-20, tools/blender_punch_card_variants.py "C1"): eine
    stumpfe Karton-Karte mit gekappter Ecke, jede Lochposition trägt ihre Ziffer, gestanzt ist
    ein echtes Loch durch die ganze Karte. Sie leuchtet NICHT - kein Kern, kein Saum; hell ist
    allein das Netz, und Licht bekommt sie später vom Grund, auf dem sie liegt."""
    m = mats("zahl")
    stock = led.mat("Karton", (0.78, 0.74, 0.68), 0.0, 0.85)
    card = box("Koerper", (L, W, PT), (0, 0, PT * 0.5), stock, 0.02)
    led.cut(card, corner_cutter(CORNER_CUT))
    leg = CORNER_CUT / math.sqrt(2.0)
    rnd = random.Random(5)
    shapes = []
    cols = 14
    for i in range(cols):
        x = -0.72 + i * 1.46 / (cols - 1)
        for d in range(10):
            y = 0.42 - d * 0.86 / 9
            if in_net(x, y, 0.03) or (x + L * 0.5) + (W * 0.5 - y) < leg + 0.07:
                continue
            if rnd.random() < 0.3:
                shapes.append(("rect", x - 0.02, y - 0.033, x + 0.02, y + 0.033))
            else:
                glyph("Dunkel%d_%d" % (i, d), str(d), x, y, PT + LIFT, 0.042, m["Dunkel"])
    led.cut(card, dm.hole_cutter(None, "SchnittStanzungen", shapes, -0.1, 0.1))
    line("DunkelKopfzeile", PT, -0.74, 0.5, 0.74, 0.5, 0.008, m["Dunkel"])


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


PLATE_PAD = 0.03


def net_cross(name, z, pad, material, corner):
    """Das Kreuz des Netzes als zwei flache Platten: Arm und Querbalken."""
    box(name + "Arm", (3 * P + C + 2 * pad, C + 2 * pad, 0.0004), ((ARM[0] + ARM[3]) * 0.5, 0, z),
        material, corner)
    box(name + "Quer", (C + 2 * pad, 2 * P + C + 2 * pad, 0.0004), (ARM[1], 0, z), material,
        corner)


def cassette():
    """PAPIER (Spieler-Wahl 2026-11-22, tools/blender_cassette_calm_variants.py "D"): schwarze
    Schale, Papier-Etikett, Sichtfenster mit zwei Naben, Kopfpartie als Trapez - und unter dem
    Netz eine dunkle PLATTE in Kreuzform mit Saum, damit das Netz zuerst liest. Im Netz-Feld
    bleibt alles unter CT + 0,004."""
    m = mats("material")
    shell = led.mat("Kassettenschale", (0.02, 0.02, 0.024), 0.0, 0.42, clearcoat=0.2)
    box("Koerper", (L - 0.008, W - 0.008, CT), (0, 0, CT * 0.5), shell, 0.05, 0.01, 3)
    seam = box("KernNaht", (L, W, 0.01), (0, 0, CT * 0.5), m["Kern"], 0.054)
    led.cut(seam, box("SchnittNaht", (L - 0.03, W - 0.03, 0.05), (0, 0, CT * 0.5), m["Dunkel"],
                      0.04))
    bpy.data.objects["SchnittNaht"].display_type = "WIRE"
    z = CT
    box("HellEtikett", (1.5, 0.74, 0.0012), (0, 0.13, z + 0.0006), m["Hell"], 0.04)
    line("SaumEtikett", z + 0.0012, -0.74, -0.2, 0.74, -0.2, 0.01, m["Saum"], 0.0004)
    # Das SICHTFENSTER: Wickel, Naben mit sechs Zähnen, dazwischen das Band.
    box("GlanzFenster", (1.38, 0.33, 0.0008), (0, P, z + 0.0018), m["Glanz"], 0.06)
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
    edge = C * 0.5 + PLATE_PAD + 0.02
    for k, (a, b) in enumerate(((-RX, ARM[1] - edge), (ARM[1] + edge, RX))):
        line("BandFenster%d" % k, zw, a, P - 0.135, b, P - 0.135, 0.012, m["Band"], 0.0008)
    # Die KOPFPARTIE: erhabenes Trapez mit Capstan-Löchern.
    trap = [(-0.66, -0.536), (0.66, -0.536), (0.56, -0.2), (-0.56, -0.2)]
    quad_prism("KoerperKopfpartie", trap, z - 0.001, z + 0.002, shell)
    for k, (x, y, r) in enumerate(((-0.47, -0.4, 0.04), (0.47, -0.4, 0.04))):
        if not in_net(x, y, r + PLATE_PAD + 0.01):
            dm.cyl(None, "DunkelLoch%d" % k, r, 0.001, (x, y, z + 0.0026), m["Dunkel"], 18)
    for k, (x, y) in enumerate(((0.76, 0.49), (0.76, -0.49), (-0.76, 0.49), (-0.76, -0.49))):
        dm.cyl(None, "MetallSchraube%d" % k, 0.024, 0.006, (x, y, z + 0.003), m["Metall"], 10)
    # Die NETZPLATTE: Saum außen, dunkle Platte darauf - über Etikett, Fenster und Trapez.
    net_cross("SaumPlatte", z + 0.0027, PLATE_PAD, m["Saum"], 0.05)
    net_cross("DunkelPlatte", z + 0.0033, PLATE_PAD - 0.01, m["Dunkel"], 0.042)


# --- RUNEN: die Tontafel (KEILSCHRIFT, 2026-11-19) ---------------------------------------------

TT = 0.128


def nail(x, y, length, width, ang):
    """Ein Keil der Keilschrift: dreieckiger Kopf bei (x, y), der Schaft läuft nach ang aus."""
    ca, sa = math.cos(ang), math.sin(ang)

    def at(u, v):
        return (x + u * ca - v * sa, y + u * sa + v * ca)

    return [[at(0, width * 0.5), at(0, -width * 0.5), at(width * 0.75, 0)],
            [at(width * 0.2, width * 0.2), at(width * 0.2, -width * 0.2), at(length, 0)]]


def hook(x, y, size):
    """Ein Winkelhaken: die Spitze zeigt zum Kopf der Zeile."""
    return [[(x + size * 0.8, y + size * 0.5), (x, y), (x + size * 0.8, y - size * 0.5)]]


def sign(rnd, x, top, width, high):
    """Ein Zeichen: zwei bis vier Keile in einer der fünf Fügungen der Inschrift."""
    down = -math.pi * 0.5
    kind = rnd.randrange(5)
    out = []
    if kind == 0:
        n = 2 if width < 0.095 else 3
        for i in range(n):
            out += nail(x + width * (i + 0.5) / n, top, high, 0.044, down)
    elif kind == 1:
        n = rnd.choice((2, 3))
        for j in range(n):
            out += nail(x, top - high * (j + 0.5) / n, width, 0.04, 0.0)
    elif kind == 2:
        out += nail(x + width - 0.016, top, high, 0.044, down)
        for j in range(2):
            out += hook(x, top - high * (0.28 + j * 0.44), 0.05)
    elif kind == 3:
        out += nail(x, top - 0.014, width, 0.038, 0.0)
        for i in range(2):
            out += nail(x + width * (0.3 + i * 0.42), top - 0.034, high - 0.034, 0.038, down)
    else:
        out += nail(x + width * 0.5, top, high, 0.044, down)
        out += nail(x, top - high * 0.55, width, 0.038, 0.0)
    return out


def clay_tablet():
    """Helle Kissen-Tafel, in sieben gezogenen Zeilen mit Keilschrift beschrieben: Köpfe und
    Schäfte wie auf einer assyrischen Inschrift, das Netz bleibt frei."""
    m = mats("rune")
    clay = led.mat("Ton_hell", (0.45, 0.34, 0.22), 0.0, 0.95)
    box("Koerper", (L - 0.012, W - 0.012, TT), (0, 0, TT * 0.5), clay, 0.15, 0.05, 6)
    rnd = random.Random(11)
    rows, row = 7, 0.125
    y0 = rows * row * 0.5
    marks = []
    for r in range(rows + 1):
        y = y0 - r * row
        edge = r in (0, rows)
        x0, x1 = (-0.66, 0.68) if edge else (-0.74, 0.76)
        x, start, n = x0, None, 0
        while x <= x1 + 1e-6:
            free = not in_net(x, y, 0.025)
            if free and start is None:
                start = x
            if (not free or x + 0.02 > x1) and start is not None:
                if x - start > 0.06:
                    line("%sZeile%d_%d" % ("Kern" if edge else "Kerbe", r, n), TT, start, y, x, y,
                         0.008 if edge else 0.006, m["Kern"] if edge else m["Kerbe"])
                    n += 1
                start = None
            x += 0.02
    for r in range(rows):
        top = y0 - r * row - 0.02
        high = row - 0.04
        x0, x1 = (-0.62, 0.64) if r in (0, rows - 1) else (-0.71, 0.73)
        x = x0
        while x < x1 - 0.07:
            width = rnd.uniform(0.075, 0.115)
            box_pts = [(x - 0.01, top), (x + width + 0.01, top), (x - 0.01, top - high),
                       (x + width + 0.01, top - high), (x + width * 0.5, top - high * 0.5)]
            if x + width <= x1 and not any(in_net(px, py, 0.03) for px, py in box_pts):
                marks += sign(rnd, x, top, width, high)
            x += width + 0.022
    prism("KerbeKeile", marks, TT - 0.002, TT + LIFT, m["Kerbe"])
    rim = box("SaumFuss", (L - 0.004, W - 0.004, 0.008), (0, 0, TT * 0.5), m["Saum"], 0.154)
    led.cut(rim, box("SchnittFuss", (L - 0.03, W - 0.03, 0.05), (0, 0, TT * 0.5), m["Dunkel"],
                     0.14))
    bpy.data.objects["SchnittFuss"].display_type = "WIRE"


# --- SONDERBESTAND: das Service-Modul (2026-11-19) ---------------------------------------------

MT = 0.034


def trace(name, pts, w=0.006, vias=None, m=None):
    """Eine Leiterbahn als Linienzug; ihr Ende sammelt sich als Via."""
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        line("%s_%d" % (name, k), MT, a[0], a[1], b[0], b[1], w, m)
    if vias is not None:
        vias.append((pts[-1][0], pts[-1][1], MT + 0.001))


def service_module():
    """Mattschwarze Platine: feine matte Leiterbahnen, EPROM mit Fenster, QFP, Pad-Feld,
    SMD-Reihen, Kontaktleiste am Fuß. Nichts davon leuchtet - hell ist allein das Netz."""
    m = mats("gold")
    black = led.mat("Mattschwarz", (0.012, 0.012, 0.014), 0.0, 0.6, clearcoat=0.2)
    box("Koerper", (L - 0.006, W - 0.006, MT), (0, 0, MT * 0.5), black, 0.05, 0.004, 3)
    ring = box("SaumRand", (L, W, 0.006), (0, 0, MT * 0.5), m["Saum"], 0.053)
    led.cut(ring, box("SchnittRand", (L - 0.02, W - 0.02, 0.05), (0, 0, MT * 0.5), m["Dunkel"],
                      0.04))
    bpy.data.objects["SchnittRand"].display_type = "WIRE"
    bahn, pad = m["Bahn"], m["Pad"]
    vias = []
    for k in range(11):
        y = (k - 5) * 0.085
        slab("PadKontakt%d" % k, 0.725, y - 0.028, 0.802, y + 0.028, MT, MT + 0.002, pad)
    e = 0.025
    rim = [(-L * 0.5 + e, -W * 0.5 + e), (0.705, -W * 0.5 + e), (0.705, W * 0.5 - e),
           (-L * 0.5 + e, W * 0.5 - e)]
    for k in range(4):
        a, b = rim[k], rim[(k + 1) % 4]
        line("BahnRand%d" % k, MT, a[0], a[1], b[0], b[1], 0.006, bahn)
    arm_r = ARM[3] + C * 0.5
    arm_l = ARM[0] - C * 0.5
    edge = C * 0.5 + 0.02
    # Von den Kontakten zum Netz und in die Fuß-Felder.
    for k in range(11):
        y = (k - 5) * 0.085
        d = abs(k - 5)
        if d <= 1:
            pts = [(0.725, y), (arm_r + 0.02, y)]
        else:
            s = 1 if k > 5 else -1
            x_turn = 0.7 - d * 0.014
            ty = s * (edge + (5 - d) * 0.022)
            pts = [(0.725, y), (x_turn, y), (x_turn - abs(y - ty), ty), (0.05 + (5 - d) * 0.05, ty)]
        trace("BahnKontakt%d" % k, pts, vias=vias, m=bahn)
    # Der EPROM im Fuß-Feld über dem Netz, seine Beine laufen zum Arm.
    cx, cy, cw, ch = 0.3, 0.375, 0.48, 0.17
    for k in range(12):
        x = cx - cw * 0.42 + k * cw * 0.84 / 11
        for s in (-1, 1):
            slab("PadBein%d_%d" % (k, s + 1), x - 0.011, cy + s * (ch * 0.5 + 0.012) - 0.028,
                 x + 0.011, cy + s * (ch * 0.5 + 0.012) + 0.028, MT, MT + 0.004, pad)
        bend = 0.235 - (k % 4) * 0.01
        trace("BahnChip%d" % k, [(x, cy - ch * 0.5 - 0.04), (x, bend), (x - 0.02, bend - 0.02),
                                 (x - 0.02, edge + 0.115 if k % 3 else edge + 0.13)], vias=vias,
              m=bahn)
    box("KeramikChip", (cw, ch, 0.04), (cx, cy, MT + 0.02), m["Keramik"], 0.012, 0.005, 2)
    zc = MT + 0.04
    dm.cyl(None, "DunkelChipkerbe", 0.02, 0.002, (cx - cw * 0.46, cy, zc + 0.001), m["Dunkel"], 12)
    dm.annulus(None, "PadFassung", cx, cy, zc + 0.0012, 0.065, 0.08, pad, 28)
    dm.cyl(None, "DunkelFenster", 0.065, 0.001, (cx, cy, zc + 0.0006), m["Dunkel"], 28)
    slab("KernDie", cx - 0.028, cy - 0.028, cx + 0.028, cy + 0.028, zc + 0.0012, zc + 0.002,
         m["Kern"])
    for k in range(8):
        a = k * math.tau / 8
        line("PadBond%d" % k, zc + 0.0005, cx + math.cos(a) * 0.036, cy + math.sin(a) * 0.036,
             cx + math.cos(a) * 0.062, cy + math.sin(a) * 0.062, 0.003, pad)
    # Das Fuß-Feld unter dem Netz: ein Bündel zum Rand, darüber eine SMD-Reihe.
    for k in range(0, 14, 2):
        x = -0.02 + k * 0.042
        y_out = -0.3 - k * 0.012
        trace("BahnFuss%d" % k, [(x, -edge), (x, y_out + 0.04), (x + 0.04, y_out), (0.7, y_out)],
              vias=vias, m=bahn)
    # Das Kopf-Feld: QFP oben, Pad-Feld unten, Bahnen am Kopfrand.
    qx, qy = -0.6, 0.37
    slab("DunkelQFP", qx - 0.065, qy - 0.065, qx + 0.065, qy + 0.065, MT, MT + 0.014, m["Dunkel"])
    for k in range(8):
        o = (k - 3.5) * 0.015
        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            ax, ay = qx + dx * 0.075 + (o if dx == 0 else 0), qy + dy * 0.075 + (o if dy == 0 else
                                                                                0)
            hx, hy = (0.004, 0.012) if dx == 0 else (0.012, 0.004)
            slab("PadQFP%d_%d_%d" % (k, dx + 1, dy + 1), ax - hx, ay - hy, ax + hx, ay + hy, MT,
                 MT + 0.003, pad)
    dm.cyl(None, "PadQFPMarke", 0.008, 0.001, (qx - 0.045, qy + 0.045, MT + 0.0146), pad, 10)
    for k in range(6):
        y = qy - 0.05 + k * 0.02
        trace("BahnQFP%d" % k, [(qx + 0.087, y), (qx + 0.13 + k * 0.012, y),
                                (qx + 0.13 + k * 0.012, edge + 0.01 + (5 - k) * 0.004)], 0.005,
              vias, bahn)
    for k in range(5):
        y = -0.1 + k * 0.05
        trace("BahnKopf%d" % k, [(arm_l - 0.02, y), (-0.72 - k * 0.012, y),
                                 (-0.72 - k * 0.012, 0.2 + k * 0.012)], vias=vias, m=bahn)
    dm.dots(None, "PadVias", vias, 0.01, pad)
    # Das Schild: ein freies Feld im Bündel, darin die matte Schrift.
    slab("KoerperSchild", 0.03, -0.49, 0.6, -0.41, MT, MT + 0.0012, black)
    glyph("SchriftSchild", "FUMBLE SERVICE  ·  REV C", 0.315, -0.45, MT + 0.0026, 0.034,
          m["Schrift"])


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
            ("data_clay_tablet", clay_tablet), ("data_service_module", service_module)]


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
