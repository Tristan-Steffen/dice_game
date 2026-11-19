"""Fumble: die vier DATENTRÄGER näher am ECHTEN Medium, je drei Entwürfe (2026-11-19).
Umriß (1,62 × 1,08) und Netz (liegendes Kreuz, Zelle 0,33) bleiben wie im Spiel.
  lochkarte: manila | acryl | jacquard      kassette: klassik | klarsicht | metall
  tontafel:  keilschrift | kintsugi | ziegel   holo:    linsen | kristall | portal

Aufruf (kopflos):
  blender -b -P tools/blender_data_media_real.py -- <ausgabe-ordner> [ansicht,ansicht]
"""
import bpy, math, os, random, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_data_media_set as ms

led, box = dm.led, dm.box
glow, col, top, seg = dm.glow, dm.col, dm.top, dm.seg
OUT = ms.OUT
L, W, C, POS, FREE = ms.L, ms.W, ms.C, ms.POS, ms.FREE
in_net = ms.in_net


def cutter_mesh(parent, name, verts, faces, material=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    if material:
        o.data.materials.append(material)
    o.parent = parent
    return o


def vtext(parent, body, z, x, y, size, material, name):
    """Schrift, die von unten nach oben liest."""
    return box.text(parent, body, box.frame((0, 0, z), (0, 1, 0), (-1, 0, 0)), y, -x, size,
                    material, name)


def num_net(parent, z, key, vals, shapes):
    """Zahlen-Zellen wie im Spiel; der Wert ist zusätzlich GESTANZT (n Löcher)."""
    navy = led.mat("Zellgrund", (0.0015, 0.003, 0.012), 0.0, 0.45, clearcoat=0.5)
    plates = []
    for i, (x, y) in enumerate(POS):
        plates.append(led.rounded_box(parent, "Zellrand%d" % i, (C * 0.92, C * 0.92, 0.004),
                                      (x, y, z + 0.002), glow(key, 1.4), C * 0.1, 0.0, 4))
        plates.append(led.rounded_box(parent, "Zelle%d" % i, (C * 0.8, C * 0.8, 0.004),
                                      (x, y, z + 0.004), navy, C * 0.08, 0.0, 4))
        if vals[i]:
            box.text(parent, vals[i], top(z + 0.007), x, y + C * 0.08, C * 0.42, glow(key, 2.4),
                     "Wert%d" % i)
            dm.value_holes(shapes, x, y, C, vals[i])
    return plates


def clip_corner(parent, objs, size=0.22):
    bpy.ops.mesh.primitive_cube_add(size=size, location=(-L * 0.5, W * 0.5, 0),
                                    rotation=(0, 0, math.radians(45)))
    corner = bpy.context.active_object
    corner.parent = parent
    corner.scale.z = 4
    for o in objs:
        led.cut(o, corner)
    return size / math.sqrt(2)


# --- ZAHLEN: die Lochkarte ---------------------------------------------------------------------

def punch_layers(parent, key, stock, t, core_gain=5.0):
    """Karton über einer Leuchtsohle: jede Stanzung scheint in Sortenfarbe."""
    lower = led.rounded_box(parent, "Unterlage", (L, W, 0.012), (0, 0, 0.006), stock, 0.02, 0.0)
    core = led.rounded_box(parent, "Leuchtkern", (L - 0.012, W - 0.012, 0.005), (0, 0, 0.0145),
                           glow(key, core_gain), 0.02, 0.0)
    body = led.rounded_box(parent, "Karte", (L, W, t - 0.017), (0, 0, (t + 0.017) * 0.5), stock,
                           0.02, 0.002)
    return lower, core, body


def digit_field(parent, rnd, fr, leg, ink, shapes, size=0.044, lit=None):
    """Die Ziffernreihen 0-9 der 80-Spalten-Karte; etwa jede sechste Stelle ist gestanzt."""
    cols, rows = 34, 10
    for i in range(cols):
        x = -0.765 + i * 1.53 / (cols - 1)
        for d in range(rows):
            y = 0.455 - d * 0.91 / (rows - 1)
            if in_net(x, y, 0.56) or (x + L * 0.5) + (W * 0.5 - y) < leg + 0.07:
                continue
            if rnd.random() < 0.16:
                shapes.append(("rect", x - 0.012, y - 0.031, x + 0.012, y + 0.031))
                if lit:
                    box.rect(parent, "Lochlicht%d_%d" % (i, d), top(0.002), x - 0.012, y - 0.031,
                             x + 0.012, y + 0.031, lit)
            else:
                box.text(parent, str(d), fr, x, y, size, ink, "Z%d_%d" % (i, d))


def punch_out(parent, body, plates, shapes):
    cutter = dm.hole_cutter(parent, "Stanzungen", shapes)
    for o in [body] + plates:
        led.cut(o, cutter)


def punch_manila(parent, seed=1, key="zahl"):
    """MANILA: die 80-Spalten-Karte - Karton, Ziffernreihen, Kopfstreifen, Rechteck-Stanzungen."""
    rnd = random.Random(seed)
    vals = ms.number_vals(rnd, key)
    t = 0.034
    stock = led.mat("Manila", (0.74, 0.62, 0.4), 0.0, 0.9)
    lower, core, body = punch_layers(parent, key, stock, t)
    leg = clip_corner(parent, (lower, core, body))
    ink = led.mat("Druck_" + key, tuple(v * 0.16 for v in col(key)), 0.0, 0.8)
    fr = top(t)
    box.rect(parent, "Kopfstreifen", fr, -L * 0.5 + leg + 0.03, 0.497, L * 0.5 - 0.03, 0.527,
             led.mat("Streifen_" + key, tuple(v * 0.5 for v in col(key)), 0.0, 0.6, 0.5))
    box.text(parent, "FUMBLE   ·   ZAHLEN   ·   80 SPALTEN", top(t + 0.0004), 0.12, 0.512, 0.022,
             led.mat("Streifenschrift", (0.05, 0.05, 0.04), 0.0, 0.7), "Kopf")
    shapes = []
    digit_field(parent, rnd, fr, leg, ink, shapes)
    seg(parent, "Fusslinie", fr, -0.79, -0.51, 0.79, -0.51, 0.004, ink)
    punch_out(parent, body, num_net(parent, t, key, vals, shapes), shapes)


def punch_acryl(parent, seed=1, key="zahl"):
    """ACRYL: die Lochkarte aus getöntem Rauchglas - geätzte Ziffern, leuchtende Kante."""
    rnd = random.Random(seed)
    vals = ms.number_vals(rnd, key)
    t = 0.04
    tint = tuple(0.25 + v * 0.6 for v in col(key))
    pane = led.mat("Acryl_" + key, tint, 0.0, 0.45, 0.12, 0.42)
    body = led.rounded_box(parent, "Scheibe", (L - 0.01, W - 0.01, t), (0, 0, t * 0.5), pane,
                           0.03, 0.004)
    edge = led.frame_ring(parent, "Kante", (L, W), (L - 0.016, W - 0.016), t * 0.5, t * 0.6,
                          glow(key, 2.6), 0.03, y=0)
    leg = clip_corner(parent, (body, edge))
    seg(parent, "Eckkante", top(t), -L * 0.5 + 0.004, W * 0.5 - leg - 0.004,
        -L * 0.5 + leg + 0.004, W * 0.5 - 0.004, 0.01, glow(key, 2.6))
    etch = led.mat("Aetzung_" + key, tuple(0.4 + v * 0.6 for v in col(key)), 0.0, 0.5, 1.1)
    fr = top(t)
    shapes = []
    digit_field(parent, rnd, fr, leg, etch, shapes, 0.04, glow(key, 5.0))
    box.rect(parent, "Kopfband", fr, -L * 0.5 + leg + 0.03, 0.5, L * 0.5 - 0.03, 0.522,
             glow(key, 1.2))
    punch_out(parent, body, num_net(parent, t, key, vals, shapes), shapes)


def punch_jacquard(parent, seed=1, key="zahl"):
    """JACQUARD: die Webstuhl-Karte - steife Pappe, runde Lochreihen, Zapfenlöcher, Schnürung."""
    rnd = random.Random(seed)
    vals = ms.number_vals(rnd, key)
    t = 0.05
    stock = dm.bumpy("Pappe", (0.2, 0.15, 0.1), 0.92, 90.0, 0.12)
    lower, core, body = punch_layers(parent, key, stock, t, 3.0)
    ring = led.mat("Lochmarke", (0.09, 0.065, 0.045), 0.0, 0.9)
    shapes = []
    pitch = 0.066
    for i in range(-10, 11):
        for j in range(-6, 7):
            x, y = i * pitch, j * pitch
            if in_net(x, y, 0.6) or abs(y) > 0.44 or abs(x) > 0.67:
                continue
            if rnd.random() < 0.5:
                shapes.append(("rund", x, y, 0.021))
            else:
                dm.annulus(parent, "Marke%d_%d" % (i, j), x, y, t + 0.0006, 0.015, 0.021, ring, 16)
    brass = led.mat("Messing", (0.75, 0.55, 0.22), 1.0, 0.3)
    for s in (-1, 1):
        shapes.append(("rund", s * 0.745, 0.0, 0.04))
        dm.annulus(parent, "Zapfenoese%d" % s, s * 0.745, 0.0, t + 0.001, 0.04, 0.056, brass, 32)
    # Die SCHNÜRUNG an beiden Langseiten: ein leuchtender Faden durch kleine Ösen.
    cord = glow(key, 3.0)
    for s in (-1, 1):
        y = s * 0.516
        xs = [-0.76 + k * 0.08 for k in range(20)]
        for k, x in enumerate(xs):
            shapes.append(("rund", x, y, 0.009))
            if k % 2 == 0 and k + 1 < len(xs):
                seg(parent, "Faden%d_%d" % (s, k), top(t + 0.002), x, y, xs[k + 1], y, 0.011, cord)
    punch_out(parent, body, num_net(parent, t, key, vals, shapes), shapes)


# --- MATERIAL: die Kassette --------------------------------------------------------------------

CT = 0.126
RX, RY, RR = 0.5, 0.345, 0.148
CORNERS = [(-0.76, 0.49), (0.76, 0.49), (-0.76, -0.49), (0.76, -0.49)]


def material_cells(rnd):
    cells = [("mat", rnd.choice(list(dm.MATERIALS))) for _ in range(6)]
    if rnd.random() < 0.6:
        cells[rnd.randrange(6)] = ("empty", None)
    return cells


def tape_mat():
    return led.mat("Band", (0.2, 0.1, 0.06), 0.3, 0.35, clearcoat=0.4)


def chrome_mat():
    return led.mat("Chrom2", (0.9, 0.9, 0.92), 1.0, 0.05)


def hub(parent, name, x, y, z, r, material, teeth=6):
    """Die Nabe: Ring mit sechs Zähnen nach innen - das Zeichen der Kassette."""
    dm.annulus(parent, name + "Ring", x, y, z, r * 0.62, r, material, 48)
    for k in range(teeth):
        a = k * math.tau / teeth
        seg(parent, "%sZahn%d" % (name, k), top(z), x + math.cos(a) * r * 0.3,
            y + math.sin(a) * r * 0.3, x + math.cos(a) * r * 0.66, y + math.sin(a) * r * 0.66,
            r * 0.2, material)


def trapezoid(parent, name, z, h, material, x_bot=0.66, x_top=0.56, y0=-0.537, y1=-0.2):
    verts = [(-x_bot, y0, z), (x_bot, y0, z), (x_top, y1, z), (-x_top, y1, z)]
    verts += [(x, y, z + h) for x, y, _ in verts]
    faces = [[3, 2, 1, 0], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    return cutter_mesh(parent, name, verts, faces, material)


def cassette_klassik(parent, seed=1, key="material"):
    """KLASSIK: schwarze Schale, Papier-Etikett hinter dem Netz, Sichtfenster mit zwei Naben."""
    rnd = random.Random(seed)
    shell = led.mat("Schale_schwarz", (0.012, 0.012, 0.014), 0.0, 0.42, clearcoat=0.2)
    led.rounded_box(parent, "Gehaeuse", (L, W, CT), (0, 0, CT * 0.5), shell, 0.05, 0.012)
    z = CT
    paper = led.mat("Etikett", (0.8, 0.76, 0.68), 0.0, 0.85)
    led.rounded_box(parent, "Etikett", (1.5, 0.74, 0.003), (0, 0.13, z + 0.0015), paper, 0.04,
                    0.0)
    for k, y in enumerate((-0.2, -0.218)):
        box.rect(parent, "Etikettband%d" % k, top(z + 0.0032), -0.74, y - 0.004, 0.74, y + 0.004,
                 glow(key, 1.2))
    band = led.mat("Band_" + key, tuple(v * 0.6 for v in col(key)), 0.0, 0.6, 0.4)
    for s in (-1, 1):
        box.rect(parent, "Seitenband%d" % s, top(z + 0.0032), s * 0.705 - 0.025, -0.17,
                 s * 0.705 + 0.025, 0.17, band)
    vtext(parent, "A", z + 0.0036, -0.705, 0.0, 0.06, led.DARK, "Seite")
    # Das SICHTFENSTER über die ganze Kopfzeile: Wickel, Naben, dazwischen das Band.
    glass = led.mat("Fenster_dunkel", (0.004, 0.004, 0.006), 0.0, 0.05, clearcoat=1.0)
    led.rounded_box(parent, "Fenster", (1.36, 0.33, 0.004), (0, RY, z + 0.004), glass, 0.06, 0.0)
    white = led.mat("Nabe_weiss", (0.9, 0.9, 0.88), 0.0, 0.4, 0.25)
    fill = rnd.uniform(0.3, 0.7)
    for s, f in ((-1, fill), (1, 1.0 - fill)):
        box.dot(parent, "Wickel%d" % s, top(z + 0.0068), s * RX, RY, RR * (0.75 + 0.33 * f),
                tape_mat())
        hub(parent, "Nabe%d" % s, s * RX, RY, z + 0.0085, RR * 0.62, white)
        dm.annulus(parent, "Fensterring%d" % s, s * RX, RY, z + 0.009, RR * 1.08, RR * 1.16,
                   glow(key, 1.8), 48)
    seg(parent, "Fensterband", top(z + 0.007), -RX, RY - 0.155, RX, RY - 0.155, 0.012,
        tape_mat())
    for k in range(5):
        x = -0.24 + k * 0.03
        seg(parent, "Skala%d" % k, top(z + 0.0065), x, RY - 0.06, x, RY + 0.06 - (k % 2) * 0.04,
            0.004, white)
    # Die KOPFPARTIE: erhabenes Trapez mit Capstan- und Paßlöchern.
    trapezoid(parent, "Kopfpartie", z, 0.005, led.mat("Kopfpartie", (0.03, 0.03, 0.034), 0.0, 0.6))
    hole = led.mat("Loch", (0.0, 0.0, 0.0), 0.0, 0.9)
    for s in (-1, 1):
        box.dot(parent, "Capstan%d" % s, top(z + 0.005), s * 0.47, -0.4, 0.04, hole)
        box.dot(parent, "Passloch%d" % s, top(z + 0.005), s * 0.29, -0.43, 0.026, hole)
        box.rect(parent, "Kerbe%d" % s, top(z + 0.005), s * 0.6 - 0.03, -0.537, s * 0.6 + 0.03,
                 -0.49, hole)
    dm.screws(parent, CORNERS, z)
    dm.printed_net(parent, z + 0.005, key, material_cells(rnd), POS, C)


def cassette_klarsicht(parent, seed=1, key="material"):
    """KLARSICHT: durchsichtige Schale - Wickel, Bandlauf, Rollen und Andruckfilz liegen offen."""
    rnd = random.Random(seed)
    clear = led.mat("Klarschale", (0.5, 0.45, 0.5), 0.0, 0.25, 0.0, 0.07)
    led.rounded_box(parent, "Boden", (L, W, 0.012), (0, 0, 0.006),
                    led.mat("Rauchboden", (0.02, 0.012, 0.02), 0.0, 0.3, clearcoat=0.6), 0.05, 0.0)
    led.rounded_box(parent, "Gehaeuse", (L, W, CT - 0.012), (0, 0, CT * 0.5 + 0.006), clear, 0.05,
                    0.012)
    led.frame_ring(parent, "Naht", (L + 0.002, W + 0.002), (L - 0.02, W - 0.02), CT * 0.5, 0.008,
                   glow(key, 2.2), 0.05, y=0)
    zi = 0.02
    fill = rnd.uniform(0.35, 0.75)
    radii = {-1: 0.115 + 0.07 * fill, 1: 0.115 + 0.07 * (1.1 - fill)}
    for s in (-1, 1):
        dm.cyl(parent, "Wickel%d" % s, radii[s], 0.05, (s * RX, RY, zi + 0.025), tape_mat(), 64)
        dm.cyl(parent, "Kern%d" % s, 0.1, 0.056, (s * RX, RY, zi + 0.028),
               led.mat("Kern", (0.85, 0.85, 0.85), 0.0, 0.4), 48)
        hub(parent, "Nabe%d" % s, s * RX, RY, zi + 0.058, 0.085, glow(key, 1.0))
    path = [(-RX - radii[-1] + 0.02, RY), (-0.74, -0.44), (0.74, -0.44), (RX + radii[1] - 0.02, RY)]
    for k in range(3):
        a, b = path[k], path[k + 1]
        seg(parent, "Bandlauf%d" % k, top(zi + 0.03), a[0], a[1], b[0], b[1], 0.018, tape_mat())
    for s in (-1, 1):
        dm.cyl(parent, "Umlenkrolle%d" % s, 0.04, 0.05, (s * 0.74, -0.45, zi + 0.025),
               chrome_mat(), 24)
        dm.cyl(parent, "Capstanloch%d" % s, 0.035, 0.012, (s * 0.47, -0.39, CT - 0.004),
               led.DARK, 24)
    led.rounded_box(parent, "Andruckfilz", (0.12, 0.03, 0.04), (0.5, -0.47, zi + 0.025),
                    led.mat("Filzpolster", (0.6, 0.5, 0.4), 0.0, 0.95), 0.0, 0.0)
    led.rounded_box(parent, "Feder", (0.3, 0.008, 0.03), (0.5, -0.49, zi + 0.025),
                    led.mat("Federblech", (0.8, 0.6, 0.3), 1.0, 0.25), 0.0, 0.0)
    led.rounded_box(parent, "Schirmblech", (0.32, 0.05, 0.04), (-0.45, -0.47, zi + 0.025),
                    led.mat("Schirmblech", (0.25, 0.26, 0.28), 1.0, 0.45), 0.0, 0.0)
    dm.screws(parent, CORNERS, CT)
    dm.printed_net(parent, CT, key, material_cells(rnd), POS, C)


def cassette_metall(parent, seed=1, key="material"):
    """METALL: gebürstete Alu-Platte, zwei Bullaugen über den Naben, offene Kopfpartie."""
    rnd = random.Random(seed)
    alu = led.mat("Alu", (0.2, 0.205, 0.22), 1.0, 0.5)
    dark = led.mat("Schale_schwarz", (0.012, 0.012, 0.014), 0.0, 0.42, clearcoat=0.2)
    led.rounded_box(parent, "Gehaeuse", (L, W, CT - 0.012), (0, 0, (CT - 0.012) * 0.5), dark, 0.05,
                    0.008)
    plate = led.rounded_box(parent, "Deckplatte", (L - 0.02, W - 0.02, 0.012), (0, 0, CT - 0.006),
                            alu, 0.045, 0.004)
    z = CT
    for s in (-1, 1):
        led.cut(plate, dm.cyl(parent, "Bullauge%d" % s, RR, 0.06, (s * RX, RY, z), None, 64))
    kopf = trapezoid(parent, "Kopfschnitt", z - 0.03, 0.06, None, 0.6, 0.5, -0.6, -0.24)
    led.cut(plate, kopf)
    fill = rnd.uniform(0.3, 0.7)
    for s, f in ((-1, fill), (1, 1.0 - fill)):
        box.dot(parent, "Grund%d" % s, top(z - 0.012), s * RX, RY, RR, led.DARK)
        box.dot(parent, "Wickel%d" % s, top(z - 0.011), s * RX, RY, RR * (0.55 + 0.4 * f),
                tape_mat())
        hub(parent, "Nabe%d" % s, s * RX, RY, z - 0.008, RR * 0.6, glow(key, 2.4))
        dm.annulus(parent, "Bullring%d" % s, s * RX, RY, z + 0.001, RR, RR * 1.12,
                   glow(key, 1.8), 48)
        dm.cyl(parent, "Bullglas%d" % s, RR, 0.003, (s * RX, RY, z - 0.002), led.GLASS, 48)
    # Die offene Kopfpartie: Band, Rollen und Filz liegen frei im Ausschnitt.
    zk = z - 0.011
    box.rect(parent, "Kopfgrund", top(zk - 0.001), -0.6, -0.537, 0.6, -0.24, led.DARK)
    seg(parent, "Kopfband", top(zk), -0.58, -0.5, 0.58, -0.5, 0.016, tape_mat())
    for s in (-1, 1):
        dm.cyl(parent, "Rolle%d" % s, 0.034, 0.008, (s * 0.47, -0.4, zk + 0.004), chrome_mat(), 24)
        dm.cyl(parent, "Stift%d" % s, 0.02, 0.008, (s * 0.29, -0.44, zk + 0.004), chrome_mat(), 16)
    box.rect(parent, "Filz", top(zk + 0.001), -0.36, -0.49, -0.2, -0.455,
             led.mat("Filzpolster", (0.6, 0.5, 0.4), 0.0, 0.95))
    # Das Netz sitzt auf einer dunklen Einlage.
    inlay = led.mat("Einlage", (0.006, 0.006, 0.008), 0.0, 0.3, clearcoat=0.8)
    led.rounded_box(parent, "EinlageArm", (4 * C + 0.03, C + 0.03, 0.002), (0, 0, z + 0.001),
                    inlay, 0.03, 0.0)
    led.rounded_box(parent, "EinlageQuer", (C + 0.03, 3 * C + 0.03, 0.002), (C * 0.5, 0, z + 0.001),
                    inlay, 0.03, 0.0)
    led.frame_ring(parent, "Naht", (L + 0.002, W + 0.002), (L - 0.02, W - 0.02), CT - 0.016, 0.006,
                   glow(key, 2.2), 0.05, y=0)
    for k, (x, y) in enumerate(CORNERS):
        dm.cyl(parent, "Inbus%d" % k, 0.026, 0.004, (x, y, z + 0.001), dark, 6)
    vtext(parent, "TYPE IV · METAL", z + 0.0004, -0.745, 0.0, 0.034, glow(key, 1.0), "Typ")
    dm.printed_net(parent, z + 0.002, key, material_cells(rnd), POS, C)


# --- RUNEN: die Tontafel -----------------------------------------------------------------------

TT = 0.118


def clay(name, a, b, grain=(0.6, 0.52, 0.42)):
    """Ton mit Brandflecken zwischen zwei Farben, Poren und Schamotte."""
    c = ms.clay_mat(1.0).copy()
    c.name = name
    for n in c.node_tree.nodes:
        if n.type == "VALTORGB" and n.color_ramp.elements[1].position > 0.5:
            n.color_ramp.elements[0].color = (*a, 1)
            n.color_ramp.elements[1].color = (*b, 1)
        if n.type == "MIX_RGB":
            n.inputs["Color2"].default_value = (*grain, 1)
    return c


def rune_tiles(parent, rnd, z, key):
    glyphs = [rnd.randrange(len(dm.RUNES)) for _ in range(6)]
    if rnd.random() < 0.4:
        glyphs[rnd.randrange(6)] = None
    glaze = led.mat("Glasur_matt", (0.012, 0.013, 0.02), 0.0, 0.3, clearcoat=0.25)
    void = led.mat("Kachel_leer", (0.01, 0.011, 0.016), 0.0, 0.85)
    for i, (x, y) in enumerate(POS):
        led.rounded_box(parent, "Kachel%d" % i, (C * 0.86, C * 0.86, 0.016), (x, y, z + 0.002),
                        glaze if glyphs[i] is not None else void, C * 0.1, 0.004, 4)
        if glyphs[i] is not None:
            dm.rune_glyph(parent, "Rune%d" % i, top(z + 0.0105), x, y, C * 0.3, glyphs[i],
                          C * 0.06, glow(key, 2.6))


def wedge_rows(rnd, x0, x1, y0, y1, z, row=0.082, step=0.052, size=0.036, skip=0.12, depth=0.012,
               lines=None):
    """Keilschrift in Zeilen; lines sammelt die Zeilen-Rillen."""
    verts, faces = [], []
    y = y1 - row * 0.5
    while y > y0:
        x = x0
        start = None
        while x < x1:
            free = not in_net(x, y, 0.6) and not in_net(x + size, y, 0.6)
            if free:
                start = x if start is None else start
                if rnd.random() > skip:
                    ang = rnd.choice((-math.pi * 0.5, -math.pi * 0.5, 0.0, 0.0, math.pi * 0.75))
                    dy = row * 0.3 if ang < 0 else rnd.uniform(-0.01, 0.01)
                    ms.wedge_prism(verts, faces, x, y + dy, size, ang, z, depth)
            if (not free or x + step >= x1) and start is not None:
                if lines is not None and x - start > 0.1:
                    lines.append(("rect", start - 0.01, y + row * 0.5 - 0.003, x - 0.02,
                                  y + row * 0.5 + 0.003))
                start = None
            x += step
        y -= row
    return verts, faces


def press(parent, body, name, verts, faces, material):
    box.cut(body, cutter_mesh(parent, name, verts, faces, material), transfer=True)


def tablet_keilschrift(parent, seed=1, key="rune"):
    """KEILSCHRIFT: helle Kissen-Tafel, dicht in Zeilen beschrieben, die Runen als Kacheln."""
    rnd = random.Random(seed)
    tan = clay("Ton_hell", (0.34, 0.25, 0.16), (0.56, 0.43, 0.29))
    body = led.rounded_box(parent, "Tafel", (L - 0.012, W - 0.012, TT), (0, 0, TT * 0.5 + 0.002),
                           tan, 0.15, 0.05)
    ms.kneaded(body, 0.008)
    lines = []
    verts, faces = wedge_rows(rnd, -0.7, 0.72, -0.46, 0.47, TT + 0.002, size=0.03, lines=lines)
    mark = led.mat("Keil_hell", (0.1, 0.07, 0.045), 0.0, 0.95)
    press(parent, body, "Keile", verts, faces, mark)
    for k, (_, a0, b0, a1, b1) in enumerate(lines):
        box.rect(parent, "Zeile%d" % k, top(TT + 0.0068), a0, b0, a1, b1, mark)
    rune_tiles(parent, rnd, TT, key)


def crack(parent, name, rnd, z, start, heading, length, key, depth=0):
    x, y = start
    pts = [(x, y)]
    tries = 0
    while length > 0 and tries < 40:
        tries += 1
        heading += rnd.uniform(-0.7, 0.7)
        step = rnd.uniform(0.05, 0.11)
        nx, ny = x + math.cos(heading) * step, y + math.sin(heading) * step
        if abs(nx) > 0.79 or abs(ny) > 0.52:
            break
        if in_net(nx, ny, 0.5):
            heading += 0.9
            continue
        x, y = nx, ny
        pts.append((x, y))
        length -= step
        if depth < 2 and rnd.random() < 0.22:
            crack(parent, "%sA%d" % (name, len(pts)), rnd, z, (x, y),
                  heading + rnd.choice((-1, 1)) * 0.9, length * 0.5, key, depth + 1)
    w = 0.011 - depth * 0.003
    groove = led.mat("Rissgrund", (0.05, 0.035, 0.02), 0.0, 0.95)
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        seg(parent, "%s_%d" % (name, k), top(z + 0.0006), a[0], a[1], b[0], b[1], w + 0.012,
            groove)
        seg(parent, "%sG_%d" % (name, k), top(z + 0.001), a[0], a[1], b[0], b[1], w,
            glow(key, 3.0))
        box.dot(parent, "%sK_%d" % (name, k), top(z + 0.001), b[0], b[1], w * 0.5, glow(key, 3.0))


def tablet_kintsugi(parent, seed=1, key="rune"):
    """KINTSUGI: eine gebrochene Tafel, die Risse mit leuchtendem Gold-Lack gekittet."""
    rnd = random.Random(seed)
    grey = clay("Ton_grau", (0.2, 0.17, 0.14), (0.38, 0.32, 0.26))
    body = led.rounded_box(parent, "Tafel", (L - 0.012, W - 0.012, TT), (0, 0, TT * 0.5 + 0.002),
                           grey, 0.13, 0.04)
    # Abgebrochene Ecken: grobe Keile schneiden den Umriß an.
    for k, (x, y, rot, s) in enumerate(((0.83, 0.56, 28, 0.3), (-0.84, -0.58, 50, 0.26),
                                        (0.3, -0.62, 8, 0.2))):
        bpy.ops.mesh.primitive_cube_add(size=s, location=(x, y, 0.05),
                                        rotation=(0.2, 0.1, math.radians(rot)))
        chip = bpy.context.active_object
        chip.name = "Bruch%d" % k
        chip.parent = parent
        chip.data.materials.append(grey)
        led.cut(body, chip)
    ms.kneaded(body, 0.009)
    verts, faces = wedge_rows(rnd, -0.7, 0.72, -0.46, 0.47, TT + 0.002, row=0.1, step=0.07,
                              skip=0.45)
    press(parent, body, "Keile", verts, faces, led.mat("Keil", (0.03, 0.02, 0.015), 0.0, 0.95))
    z = TT + 0.006
    for k, (start, heading) in enumerate((((-0.79, 0.3), -0.3), ((0.78, -0.25), 2.9),
                                          ((-0.3, -0.52), 1.3), ((0.55, 0.52), -1.9))):
        crack(parent, "Riss%d" % k, rnd, z, start, heading, 0.9, key)
    rune_tiles(parent, rnd, TT, key)


def tablet_ziegel(parent, seed=1, key="rune"):
    """ZIEGEL: roter Terrakotta-Stein mit erhabenem Rahmen, Rollsiegel-Fries und Stempeln."""
    rnd = random.Random(seed)
    red = clay("Terrakotta", (0.2, 0.065, 0.035), (0.42, 0.15, 0.075), (0.6, 0.35, 0.22))
    z = TT - 0.014
    body = led.rounded_box(parent, "Stein", (L - 0.004, W - 0.004, z), (0, 0, z * 0.5), red, 0.05,
                           0.02)
    ms.kneaded(body, 0.005)
    led.frame_ring(parent, "Rahmen", (L - 0.004, W - 0.004), (L - 0.09, W - 0.07), z - 0.002, 0.03,
                   red, 0.05, y=0)
    led.frame_ring(parent, "Glasurlinie", (L - 0.1, W - 0.08), (L - 0.124, W - 0.104), z, 0.004,
                   glow(key, 2.2), 0.03, y=0)
    # Der FRIES: Zickzack-Band eines Rollsiegels in den freien Feldern, dazu runde Stempel.
    dark = led.mat("Eindruck", (0.09, 0.03, 0.018), 0.0, 0.95)
    fr = top(z + 0.0006)
    for k, (x0, x1, y) in enumerate(((-0.69, -0.03, 0.33), (0.36, 0.7, 0.33), (-0.69, -0.03, -0.33),
                                     (0.36, 0.7, -0.33))):
        n = max(2, int((x1 - x0) / 0.075))
        for r, row in enumerate((0.085, -0.13)):
            for j in range(n):
                a = x0 + (x1 - x0) * j / n
                b = x0 + (x1 - x0) * (j + 1) / n
                m = (a + b) * 0.5
                seg(parent, "Fries%d_%d_%d" % (k, j, r), fr, a, y + row, m, y + row + 0.045, 0.012,
                    dark)
                seg(parent, "Fries%d_%d_%db" % (k, j, r), fr, m, y + row + 0.045, b, y + row,
                    0.012, dark)
        m = max(1, n // 2)
        for j in range(m + 1):
            x = x0 + 0.05 + j * (x1 - x0 - 0.1) / m
            box.dot(parent, "Stempel%d_%d" % (k, j), fr, x, y, 0.034, dark)
            dm.annulus(parent, "Stempelring%d_%d" % (k, j), x, y, z + 0.0035, 0.014, 0.022,
                       glow(key, 1.4), 20)
    rune_tiles(parent, rnd, z, key)


# --- SONDERBESTAND: der Holo-Emitter -----------------------------------------------------------

HT = 0.06
FLOAT = 0.2


def projection(parent, z0, zh, key, mode):
    before = set(bpy.data.objects)
    ms.cross_lines(parent, "Netz", zh, key, 1.0, mode == "blank")
    ms.effect_content(parent, zh, key, mode)
    vol = led.mat("Lichtsaeule_" + key, col(key), 0.0, 0.5, 0.15, 0.025)
    for name, sx, sy, x, y in (("Arm", 4 * C, C, 0, 0), ("Oben", C, C, 0.5 * C, C),
                               ("Unten", C, C, 0.5 * C, -C)):
        led.rounded_box(parent, "Saeule" + name, (sx, sy, zh - z0 - 0.002),
                        (x, y, (z0 + zh) * 0.5), vol, 0.0, 0.0)
    ms.mark_projection(before)


def holo_linsen(parent, seed=1, mode="repair", on=False):
    """LINSEN: gefräste Projektor-Platte - je Zelle eine Kuppellinse, Kühlrippen, Kontakte."""
    key = ms.HOLO_MODES[mode][0]
    metal = led.mat("Projektor", (0.09, 0.095, 0.11), 1.0, 0.32)
    led.rounded_box(parent, "Platte", (L, W, HT), (0, 0, HT * 0.5), metal, 0.07, 0.01)
    bed = led.mat("Linsenbett", (0.004, 0.005, 0.008), 0.0, 0.2, clearcoat=1.0)
    led.rounded_box(parent, "BettArm", (4 * C + 0.04, C + 0.04, 0.004), (0, 0, HT + 0.001), bed,
                    0.04, 0.0)
    led.rounded_box(parent, "BettQuer", (C + 0.04, 3 * C + 0.04, 0.004), (C * 0.5, 0, HT + 0.001),
                    bed, 0.04, 0.0)
    lens = led.mat("Kuppellinse", (0.6, 0.75, 0.9), 0.0, 0.02, 0.0, 0.3, clearcoat=1.0)
    mount = led.mat("Fassung", (0.22, 0.225, 0.24), 1.0, 0.4)
    for i, (x, y) in enumerate(POS):
        dm.annulus(parent, "Fassung%d" % i, x, y, HT + 0.0035, C * 0.4, C * 0.46, mount, 48)
        dm.cyl(parent, "Diode%d" % i, C * 0.1, 0.004, (x, y, HT + 0.004),
               glow(key, 2.6 if on else 1.4), 24)
        dm.annulus(parent, "Fresnel%d" % i, x, y, HT + 0.0036, C * 0.22, C * 0.25,
                   glow(key, 1.4 if on else 0.5), 40)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=12, radius=C * 0.4,
                                             location=(x, y, HT + 0.003))
        dome = bpy.context.active_object
        dome.name = "Linse%d" % i
        dome.scale.z = 0.3
        dome.data.materials.append(lens)
        bpy.ops.object.shade_smooth()
        dome.parent = parent
    # KÜHLRIPPEN am Kopf, Kontaktfinger am Steck-Ende, Status-LEDs in den freien Ecken.
    rib = led.mat("Rippe", (0.2, 0.21, 0.23), 1.0, 0.3)
    for k in range(17):
        led.rounded_box(parent, "Rippe%d" % k, (0.1, 0.024, 0.02), (-0.745, (k - 8) * 0.056,
                                                                    HT + 0.01), rib, 0.0, 0.003)
    gold = led.mat("Kontaktgold", (1.0, 0.72, 0.26), 1.0, 0.2)
    for k in range(9):
        y = (k - 4) * 0.085
        box.rect(parent, "Kontakt%d" % k, top(HT), 0.745, y - 0.026, 0.8, y + 0.026, gold)
    for k, (x, y) in enumerate(((-0.62, 0.44), (-0.62, -0.44), (0.62, 0.44), (0.62, -0.44))):
        dm.cyl(parent, "Schraube%d" % k, 0.03, 0.006, (x, y, HT + 0.002), rib, 6)
    for k in range(3):
        box.dot(parent, "Status%d" % k, top(HT), -0.3 + k * 0.07, 0.4, 0.014,
                glow(key, 3.0 if on or k == 0 else 0.3))
    box.text(parent, ms.HOLO_MODES[mode][1] + ms.HOLO_MODES[mode][2], top(HT), -0.28, -0.36, 0.04,
             glow(key, 1.0), "Name")
    led.frame_ring(parent, "Fuge", (L + 0.002, W + 0.002), (L - 0.02, W - 0.02), HT * 0.5, 0.006,
                   glow(key, 2.0), 0.07, y=0)
    if on:
        projection(parent, HT + 0.02, HT + FLOAT, key, mode)


def holo_kristall(parent, seed=1, mode="repair", on=False):
    """KRISTALL: ein Glasblock zwischen zwei Metallkappen, das Netz steht in der Tiefe des Glases."""
    key = ms.HOLO_MODES[mode][0]
    t = 0.11
    glass = led.mat("Kristall_" + key, tuple(0.5 + v * 0.5 for v in col(key)), 0.0, 0.02, 0.0,
                    0.07, clearcoat=1.0)
    led.rounded_box(parent, "Sohle", (L - 0.3, W - 0.03, 0.006), (0, 0, 0.003),
                    led.mat("Dunkelsohle", (0.008, 0.009, 0.012), 0.0, 0.35, clearcoat=0.5), 0.02, 0.0)
    led.rounded_box(parent, "Glasblock", (L - 0.26, W - 0.02, t - 0.006), (0, 0, t * 0.5 + 0.003),
                    glass, 0.02, 0.012)
    cap = led.mat("Kappe", (0.16, 0.165, 0.18), 1.0, 0.45)
    groove = led.mat("Rille", (0.04, 0.04, 0.045), 1.0, 0.5)
    for s in (-1, 1):
        led.rounded_box(parent, "Kappe%d" % s, (0.15, W, t + 0.01),
                        (s * (L * 0.5 - 0.075), 0, (t + 0.01) * 0.5), cap, 0.03, 0.012)
        led.rounded_box(parent, "Kappenlicht%d" % s, (0.012, W - 0.16, 0.004),
                        (s * (L * 0.5 - 0.135), 0, t + 0.011), glow(key, 3.0 if on else 1.2),
                        0.0, 0.0)
        for k in range(4):
            led.rounded_box(parent, "Rille%d_%d" % (s, k), (0.01, W - 0.1, 0.004),
                            (s * (L * 0.5 - 0.03 - k * 0.022), 0, t + 0.011), groove, 0.0, 0.0)
    # Das Netz in drei Tiefen: es scheint im Block zu stehen.
    gain = 1.0 if on else 0.35
    for k, z in enumerate((0.03, 0.058, 0.086)):
        ms.cross_lines(parent, "Tiefe%d" % k, z, key, gain * (0.35 + 0.3 * k), mode == "blank",
                       k == 2)
    ms.effect_content(parent, 0.087, key, mode, 0.9 if on else 0.3)
    if on:
        projection(parent, t + 0.004, t + FLOAT - 0.04, key, mode)


def holo_portal(parent, seed=1, mode="repair", on=False):
    """PORTAL: ein offener Rahmen mit vier Eck-Projektoren - das Netz spannt sich in die Öffnung."""
    key = ms.HOLO_MODES[mode][0]
    t = 0.07
    metal = led.mat("Portalrahmen", (0.05, 0.053, 0.062), 1.0, 0.3)
    led.frame_ring(parent, "Rahmen", (L, W), (L - 0.19, W - 0.07), t * 0.5, t, metal, 0.04, y=0)
    led.frame_ring(parent, "Innenlicht", (L - 0.186, W - 0.066), (L - 0.2, W - 0.08), t * 0.5,
                   t * 0.5, glow(key, 2.6 if on else 1.0), 0.03, y=0)
    pane = led.mat("Portalscheibe", (0.3, 0.4, 0.5), 0.0, 0.02, 0.0, 0.07, clearcoat=1.0)
    led.rounded_box(parent, "Scheibe", (L - 0.2, W - 0.08, 0.006), (0, 0, 0.012), pane, 0.03, 0.0)
    nodes = [(sx * 0.757, sy * 0.47) for sx in (-1, 1) for sy in (-1, 1)]
    for k, (x, y) in enumerate(nodes):
        dm.cyl(parent, "Turm%d" % k, 0.042, 0.06, (x, y, t + 0.03), chrome_mat(), 24)
        dm.cyl(parent, "Auge%d" % k, 0.026, 0.008, (x, y, t + 0.062), glow(key, 5.0 if on else 2.0),
               24)
    for s in (-1, 1):
        led.rounded_box(parent, "Schiene%d" % s, (0.02, 0.8, 0.012), (s * 0.757, 0, t + 0.006),
                        glow(key, 2.4 if on else 0.8), 0.0, 0.0)
    zh = t + 0.07
    if not on:
        ms.cross_lines(parent, "Ruhe", 0.016, key, 0.22, True, False)
        return
    before = set(bpy.data.objects)
    ms.cross_lines(parent, "Netz", zh, key, 1.0, mode == "blank")
    ms.effect_content(parent, zh, key, mode)
    haze = led.mat("Portaldunst_" + key, col(key), 0.0, 0.5, 0.35, 0.02)
    led.rounded_box(parent, "Dunst", (L - 0.22, W - 0.1, 0.002), (0, 0, zh - 0.004), haze, 0.03,
                    0.0)
    ray = led.mat("Strahl_" + key, col(key), 0.0, 0.4, 2.0, 0.5)
    for k, (x, y) in enumerate(nodes):
        dm.beam(parent, "Strahl%d" % k, Vector((x, y, t + 0.066)),
                Vector((math.copysign(2 * C, x), math.copysign(0.5 * C, y), zh)), 0.005, ray)
    ms.mark_projection(before)


# --- Bühne --------------------------------------------------------------------------------------

SETS = {
    "lochkarte": [("JETZT", lambda p: ms.punch_card(p, 4, "zahl")),
                  ("A · MANILA", lambda p: punch_manila(p, 4)),
                  ("B · ACRYL", lambda p: punch_acryl(p, 4)),
                  ("C · JACQUARD", lambda p: punch_jacquard(p, 4))],
    "kassette": [("JETZT", lambda p: ms.cassette(p, 4)),
                 ("A · KLASSIK", lambda p: cassette_klassik(p, 4)),
                 ("B · KLARSICHT", lambda p: cassette_klarsicht(p, 4)),
                 ("C · METALL", lambda p: cassette_metall(p, 4))],
    "tontafel": [("JETZT", lambda p: ms.clay_tablet(p, 4)),
                 ("A · KEILSCHRIFT", lambda p: tablet_keilschrift(p, 4)),
                 ("B · KINTSUGI", lambda p: tablet_kintsugi(p, 4)),
                 ("C · ZIEGEL", lambda p: tablet_ziegel(p, 4))],
    "holo": [("JETZT · AN", lambda p: ms.holo(p, 4, "repair", on=True)),
             ("A · LINSEN · AN", lambda p: holo_linsen(p, 4, "repair", True)),
             ("B · KRISTALL · AN", lambda p: holo_kristall(p, 4, "repair", True)),
             ("C · PORTAL · AN", lambda p: holo_portal(p, 4, "repair", True))],
    "holoaus": [("JETZT · AUS", lambda p: ms.holo(p, 4, "repair")),
                ("A · LINSEN · AUS", lambda p: holo_linsen(p, 4, "repair")),
                ("B · KRISTALL · AUS", lambda p: holo_kristall(p, 4, "repair")),
                ("C · PORTAL · AUS", lambda p: holo_portal(p, 4, "repair"))],
}
SPOTS = [(-1.0, 0.72), (1.0, 0.72), (-1.0, -0.72), (1.0, -0.72)]


def view_set(name, flat):
    cam, aim = dm.empty_stage()
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    for (title, fn), (x, y) in zip(SETS[name], SPOTS):
        dm.build(fn, title, (x, y, 0.001))
        ms.label(title, x, y - 0.64, 0.075)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 4.5
        aim.location = (0, -0.04, 0)
        cam.location = (0, -0.04, 12)
    else:
        aim.location = (0, -0.22, 0.0)
        cam.location = (0.3, -5.6, 4.6)
        cam.data.lens = 50


VIEWS = {}
for _n in SETS:
    VIEWS[_n + "_draufsicht"] = (lambda n=_n: view_set(n, True))
    VIEWS[_n + "_schraeg"] = (lambda n=_n: view_set(n, False))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    argv = sys.argv[sys.argv.index("--") + 1:]
    only = argv[1].split(",") if len(argv) > 1 else []
    for name, build_view in VIEWS.items():
        if only and name not in only:
            continue
        build_view()
        bpy.context.scene.eevee.taa_render_samples = 48
        bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("gerendert", name)
    print("ok")
