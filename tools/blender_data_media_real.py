"""Fumble: die vier DATENTRÄGER näher am ECHTEN Medium, je drei Entwürfe (2026-11-19).
Umriß (1,62 × 1,08) und Netz (liegendes Kreuz, Zelle 0,33) bleiben wie im Spiel.
  lochkarte: manila | acryl | jacquard      kassette: klassik | klarsicht | metall
  tontafel:  keilschrift | kintsugi | ziegel   holo:    linsen | kristall | portal
  sonder (Kandidaten statt des Holo-Emitters): service-modul | mikrofiche | kernspeicher

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
# --- SONDERBESTAND: drei Kandidaten (2026-11-19) -----------------------------------------------

def cell_plates(parent, z, key, mode, gain, plate):
    """Die sechs Netz-Zellen als dunkle Plättchen mit Saum, darauf die Wirkung."""
    for i, (x, y) in enumerate(POS):
        led.rounded_box(parent, "Zellplatte%d" % i, (C * 0.9, C * 0.9, 0.004), (x, y, z + 0.002),
                        plate, C * 0.06, 0.0, 4)
        dm.box_outline(parent, "Zellsaum%d_" % i, top(z + 0.0045), x, y, C * 0.45, 0.009,
                       glow(key, 2.0 * gain))
    ms.effect_content(parent, z + 0.005, key, mode, gain)


def sonder_modul(parent, seed=1, mode="repair", on=False, board=None, trace_gain=1.5):
    """SERVICE-MODUL: eine Platine mit gebranntem EPROM - Quarzfenster, Leiterbahnen zu jeder
    Zelle, Gold-Kontakte am Steck-Ende."""
    rnd = random.Random(seed)
    key = ms.HOLO_MODES[mode][0]
    t = 0.034
    gain = 1.0 if on else 0.45
    mask = board or led.mat("Loetstopp_" + key, tuple(0.008 + v * 0.045 for v in col(key)), 0.0,
                            0.35, clearcoat=0.6)
    led.rounded_box(parent, "Platine", (L, W, t), (0, 0, t * 0.5), mask, 0.03, 0.004)
    gold = led.mat("Kontaktgold", (1.0, 0.72, 0.26), 1.0, 0.2)
    fr = top(t)
    for k in range(11):
        y = (k - 5) * 0.085
        box.rect(parent, "Kontakt%d" % k, fr, 0.725, y - 0.028, 0.802, y + 0.028, gold)
    # Der EPROM im freien Kopf-Feld: Keramik, Beinchen, rundes Quarzfenster.
    cx, cy = -0.36, 0.345
    ceramic = led.mat("Keramik", (0.2, 0.16, 0.24), 0.0, 0.5, clearcoat=0.3)
    for k in range(10):
        x = cx - 0.225 + k * 0.05
        for s in (-1, 1):
            box.rect(parent, "Bein%d_%d" % (k, s), fr, x - 0.012, cy + s * 0.105 - 0.03,
                     x + 0.012, cy + s * 0.105 + 0.03, gold)
    led.rounded_box(parent, "Chip", (0.54, 0.19, 0.04), (cx, cy, t + 0.02), ceramic, 0.012, 0.006)
    dm.cyl(parent, "Chipkerbe", 0.022, 0.004, (cx - 0.25, cy, t + 0.0405), led.DARK, 16)
    dm.annulus(parent, "Fensterfassung", cx, cy, t + 0.041, 0.07, 0.085, gold, 32)
    dm.cyl(parent, "Fenstergrund", 0.07, 0.003, (cx, cy, t + 0.039), led.DARK, 32)
    burned = mode != "blank"
    if burned:
        box.rect(parent, "Die", top(t + 0.041), cx - 0.03, cy - 0.03, cx + 0.03, cy + 0.03,
                 glow(key, 4.0 * gain))
        for k in range(8):
            a = k * math.tau / 8
            seg(parent, "Bond%d" % k, top(t + 0.041), cx + math.cos(a) * 0.035,
                cy + math.sin(a) * 0.035, cx + math.cos(a) * 0.066, cy + math.sin(a) * 0.066,
                0.003, gold)
    dm.cyl(parent, "Quarz", 0.07, 0.004, (cx, cy, t + 0.043), led.GLASS, 32)
    # LEITERBAHNEN vom Chip zu jeder Zelle, mit 45-Grad-Knicken und Durchkontaktierungen.
    trace = glow(key, trace_gain * gain)
    zt = top(t + 0.0004)
    routes = []
    for i, (x, y) in enumerate(POS):
        sx = cx - 0.2 + i * 0.08
        bus = 0.2 - i * 0.008
        if y > 0.1:
            routes.append([(sx, cy - 0.14), (sx, bus), (x - C * 0.6, bus), (x - C * 0.6, y),
                           (x - C * 0.46, y)])
        elif y < -0.1:
            routes.append([(sx, cy - 0.14), (sx, bus), (0.0, bus), (0.0, y), (x - C * 0.46, y)])
        else:
            tx = x - C * 0.3 + i * 0.03
            routes.append([(sx, cy - 0.14), (sx, bus), (tx, bus), (tx, y + C * 0.46)])
    # Vom Netz zu den Kontakten und ein Bündel Busleitungen am Fuß.
    for k in range(5):
        y = (k - 2) * 0.05
        routes.append([(0.495 + C * 0.46, y), (0.69, y * 3.4), (0.725, y * 3.4)])
    for k in range(4):
        y = -0.455 - k * 0.016
        routes.append([(-0.66, y), (0.3 - k * 0.02, y), (0.36 - k * 0.02, y + 0.06)])
    for i, pts in enumerate(routes):
        for k in range(len(pts) - 1):
            a, b = pts[k], pts[k + 1]
            seg(parent, "Bahn%d_%d" % (i, k), zt, a[0], a[1], b[0], b[1], 0.007, trace)
            box.dot(parent, "Knick%d_%d" % (i, k), zt, b[0], b[1], 0.0035, trace)
        box.dot(parent, "Via%d" % i, top(t + 0.0006), pts[-1][0], pts[-1][1], 0.011, gold)
    # Bestückung in den übrigen freien Feldern: Kondensatoren, Widerstände, Siebdruck.
    can = led.mat("Becher", (0.55, 0.56, 0.6), 1.0, 0.3)
    for k, (x, y) in enumerate(((0.5, 0.39), (0.63, 0.39))):
        dm.cyl(parent, "Elko%d" % k, 0.05, 0.05, (x, y, t + 0.025), can, 24)
        box.rect(parent, "Elkomarke%d" % k, top(t + 0.0505), x - 0.05, y - 0.012, x + 0.05,
                 y + 0.012, led.DARK)
    part = led.mat("SMD", (0.03, 0.03, 0.035), 0.0, 0.5)
    for k in range(6):
        x = -0.62 + k * 0.1
        led.rounded_box(parent, "Widerstand%d" % k, (0.05, 0.026, 0.012), (x, -0.4, t + 0.006),
                        part, 0.0, 0.002)
        for s in (-1, 1):
            box.rect(parent, "Pad%d_%d" % (k, s), fr, x + s * 0.03 - 0.008, -0.413,
                     x + s * 0.03 + 0.008, -0.387, gold)
    silk = led.mat("Siebdruck", (0.75, 0.76, 0.78), 0.0, 0.7, 0.25)
    w0, w1 = ms.HOLO_MODES[mode][1], ms.HOLO_MODES[mode][2]
    box.text(parent, w0 + w1, top(t), -0.37, -0.3, 0.04, silk, "Name")
    box.text(parent, "SB-%02d  REV C" % rnd.randint(1, 99), top(t), 0.56, -0.3, 0.032, silk,
             "Serie")
    for k in range(5):
        box.dot(parent, "Pruefpunkt%d" % k, fr, 0.44 + k * 0.06, -0.41, 0.014, gold)
    for sy in (-1, 1):
        dm.annulus(parent, "Bohrung%d" % sy, -0.755, sy * 0.47, t + 0.0006, 0.022, 0.04, gold, 24)
        box.dot(parent, "Loch%d" % sy, top(t + 0.0008), -0.755, sy * 0.47, 0.022, led.DARK)
    vtext(parent, "FUMBLE SERVICE", t, -0.75, 0.0, 0.034, silk, "Rand")
    plate = led.mat("Zellgrund", (0.0015, 0.003, 0.012), 0.0, 0.45, clearcoat=0.5)
    cell_plates(parent, t, key, mode, gain, plate)


def sonder_fiche(parent, seed=1, mode="repair", on=False):
    """MIKROFICHE: ein Filmblatt im Rahmen - Reihen winziger Bilder, das Netz als große Bilder;
    auf dem Leser leuchtet der Leuchttisch darunter."""
    rnd = random.Random(seed)
    key = ms.HOLO_MODES[mode][0]
    t = 0.03
    gain = 1.0 if on else 0.22
    led.rounded_box(parent, "Traeger", (L, W, 0.012), (0, 0, 0.006),
                    led.mat("Fichetraeger", (0.01, 0.01, 0.012), 0.0, 0.4), 0.03, 0.0)
    led.rounded_box(parent, "Leuchttisch", (L - 0.05, W - 0.05, 0.004), (0, 0, 0.014),
                    glow(key, 0.35 * gain), 0.02, 0.0)
    film = led.mat("Film_" + key, (0.004, 0.004, 0.006), 0.0, 0.08, 0.0, 0.8, clearcoat=1.0)
    led.rounded_box(parent, "Film", (L - 0.05, W - 0.05, 0.004), (0, 0, 0.019), film, 0.02, 0.0)
    led.frame_ring(parent, "Rahmen", (L, W), (L - 0.05, W - 0.05), t * 0.5, t,
                   led.mat("Ficherahmen", (0.09, 0.095, 0.11), 1.0, 0.35), 0.03, y=0)
    z = 0.0215
    fr = top(z)
    # Der TITELSTREIFEN am Kopf: mit bloßem Auge lesbar, alles andere braucht den Leser.
    box.rect(parent, "Titelstreifen", fr, -0.775, -0.5, -0.69, 0.5, glow(key, 1.6 * max(gain,
                                                                                     0.55)))
    vtext(parent, "SONDERBESTAND   SB-%02d" % rnd.randint(1, 99), z + 0.0004, -0.732, 0.0, 0.04,
          led.DARK, "Titel")
    frame_mat = glow(key, 0.6 * gain)
    ink = led.mat("Filmschrift", (0.0, 0.0, 0.0), 0.0, 0.9)
    fw, fh, px, py = 0.066, 0.05, 0.082, 0.066
    for i in range(18):
        for j in range(15):
            x, y = -0.64 + i * px, -0.462 + j * py
            if x > 0.76 or in_net(x, y, 0.62):
                continue
            box.rect(parent, "Bild%d_%d" % (i, j), fr, x - fw * 0.5, y - fh * 0.5, x + fw * 0.5,
                     y + fh * 0.5, frame_mat)
            for k in range(rnd.randint(2, 4)):
                yy = y + fh * 0.32 - k * 0.011
                box.rect(parent, "Zeile%d_%d_%d" % (i, j, k), top(z + 0.0004), x - fw * 0.4,
                         yy - 0.002, x - fw * 0.4 + rnd.uniform(0.02, 0.05), yy + 0.002, ink)
    # Das Netz: sechs GROSSE Bilder im selben Film.
    for i, (x, y) in enumerate(POS):
        box.rect(parent, "Grossbild%d" % i, top(z + 0.0002), x - C * 0.45, y - C * 0.45,
                 x + C * 0.45, y + C * 0.45, glow(key, 0.75 * gain))
        dm.box_outline(parent, "Bildrand%d_" % i, top(z + 0.0006), x, y, C * 0.45, 0.008,
                       glow(key, 2.2 * max(gain, 0.5)))
    before = set(bpy.data.objects)
    ms.effect_content(parent, z + 0.001, key, mode, 1.0)
    for o in set(bpy.data.objects) - before:
        if o.data and o.data.materials:
            o.data.materials[0] = led.DARK if on else glow(key, 1.2)
    led.rounded_box(parent, "Deckglas", (L - 0.05, W - 0.05, 0.004), (0, 0, t - 0.003),
                    led.mat("Ficheglas", (0.8, 0.85, 0.9), 0.0, 0.03, 0.0, 0.05, clearcoat=1.0),
                    0.02, 0.0)


def sonder_kern(parent, seed=1, mode="repair", on=False):
    """KERNSPEICHER: ein Rahmen mit gewebtem Golddraht und Ferritringen - je Zelle ein dichtes
    Feld, dessen gesetzte Kerne leuchten."""
    rnd = random.Random(seed)
    key = ms.HOLO_MODES[mode][0]
    t = 0.07
    gain = 1.0 if on else 0.4
    bake = led.mat("Bakelit", (0.035, 0.02, 0.014), 0.0, 0.45, clearcoat=0.3)
    led.rounded_box(parent, "Grundplatte", (L - 0.02, W - 0.02, 0.012), (0, 0, 0.006),
                    led.mat("Kerngrund", (0.006, 0.006, 0.008), 0.0, 0.5), 0.03, 0.0)
    led.frame_ring(parent, "Rahmen", (L, W), (L - 0.14, W - 0.1), t * 0.5, t, bake, 0.03, y=0)
    gold = led.mat("Golddraht", (0.8, 0.55, 0.2), 1.0, 0.35)
    zw = 0.04
    x0, x1, y0, y1 = -0.735, 0.735, -0.488, 0.488
    pitch = 0.049
    nx, ny = int((x1 - x0) / pitch), int((y1 - y0) / pitch)
    xs = [x0 + (i + 0.5) * (x1 - x0) / nx for i in range(nx)]
    ys = [y0 + (j + 0.5) * (y1 - y0) / ny for j in range(ny)]
    for i, x in enumerate(xs):
        seg(parent, "DrahtY%d" % i, top(zw), x, y0, x, y1, 0.004, gold)
        for s in (-1, 1):
            box.rect(parent, "LoetY%d_%d" % (i, s), top(t), x - 0.008, s * 0.515 - 0.012,
                     x + 0.008, s * 0.515 + 0.012, gold)
    for j, y in enumerate(ys):
        seg(parent, "DrahtX%d" % j, top(zw + 0.001), x0, y, x1, y, 0.004, gold)
        for s in (-1, 1):
            box.rect(parent, "LoetX%d_%d" % (j, s), top(t), s * 0.775 - 0.014, y - 0.008,
                     s * 0.775 + 0.014, y + 0.008, gold)
    ferrite, lit = [], []
    for x in xs:
        for y in ys:
            if in_net(x, y, 0.5):
                (lit if rnd.random() < 0.55 else ferrite).append((x, y, zw + 0.004))
            else:
                ferrite.append((x, y, zw + 0.004))
    dm.dots(parent, "Kerne", ferrite, 0.014, led.mat("Ferrit", (0.05, 0.05, 0.06), 0.3, 0.4))
    dm.dots(parent, "Kerne_gesetzt", lit, 0.015, glow(key, 2.6 * gain))
    # Der LESEDRAHT läuft diagonal durch jedes Zellfeld.
    for i, (x, y) in enumerate(POS):
        h = C * 0.46
        seg(parent, "Lesedraht%d" % i, top(zw + 0.006), x - h, y - h, x + h, y + h, 0.005,
            glow(key, 1.8 * gain))
        dm.box_outline(parent, "Feldrand%d_" % i, top(zw + 0.007), x, y, h, 0.01,
                       glow(key, 2.2 * max(gain, 0.5)))
    before = set(bpy.data.objects)
    ms.effect_content(parent, zw + 0.02, key, mode, max(gain, 0.6))
    for o in set(bpy.data.objects) - before:
        o["proj"] = 1
    for i, (x, y) in enumerate(POS):
        led.rounded_box(parent, "Schild%d" % i, (C * 0.74, C * 0.5, 0.002), (x, y, zw + 0.018),
                        led.mat("Kernschild", (0.004, 0.004, 0.006), 0.0, 0.3, 0.0, 0.72), C * 0.05,
                        0.0, 4)
    for k, (x, y) in enumerate(((-0.775, 0.5), (0.775, 0.5), (-0.775, -0.5), (0.775, -0.5))):
        dm.cyl(parent, "Niete%d" % k, 0.02, 0.006, (x, y, t + 0.002),
               led.mat("Niete", (0.6, 0.62, 0.66), 1.0, 0.3), 12)


SETS["sonder"] = [("JETZT · HOLO", lambda p: ms.holo(p, 4, "repair", on=True)),
                  ("A · SERVICE-MODUL", lambda p: sonder_modul(p, 4, "repair", True)),
                  ("B · MIKROFICHE", lambda p: sonder_fiche(p, 4, "repair", True)),
                  ("C · KERNSPEICHER", lambda p: sonder_kern(p, 4, "repair", True))]
SETS["sonderaus"] = [("JETZT · HOLO · MAGAZIN", lambda p: ms.holo(p, 4, "cool")),
                     ("A · SERVICE-MODUL · MAGAZIN", lambda p: sonder_modul(p, 4, "cool")),
                     ("B · MIKROFICHE · MAGAZIN", lambda p: sonder_fiche(p, 4, "cool")),
                     ("C · KERNSPEICHER · MAGAZIN", lambda p: sonder_kern(p, 4, "cool"))]
SETS["sonderroh"] = [("JETZT · ROHLING", lambda p: ms.holo(p, 4, "blank", on=True)),
                     ("A · ROHLING", lambda p: sonder_modul(p, 4, "blank", True)),
                     ("B · ROHLING", lambda p: sonder_fiche(p, 4, "blank", True)),
                     ("C · ROHLING", lambda p: sonder_kern(p, 4, "blank", True))]

# --- SERVICE-MODUL: fünf Spielarten (2026-11-19) ------------------------------------------------

def gold_mat():
    return led.mat("Kontaktgold", (1.0, 0.72, 0.26), 1.0, 0.2)


def navy_plate():
    return led.mat("Zellgrund", (0.0015, 0.003, 0.012), 0.0, 0.45, clearcoat=0.5)


def eprom(parent, cx, cy, z, key, gain, burned, w=0.54, h=0.19, win=0.07, pins=10, metal=None):
    """Der EPROM: Keramik, Beinchen an beiden Langseiten, rundes Quarzfenster über dem Die."""
    gold = metal or gold_mat()
    ceramic = led.mat("Keramik", (0.2, 0.16, 0.24), 0.0, 0.5, clearcoat=0.3)
    for k in range(pins):
        x = cx - w * 0.42 + k * w * 0.84 / (pins - 1)
        for s in (-1, 1):
            box.rect(parent, "Bein%d_%d" % (k, s), top(z), x - 0.012, cy + s * (h * 0.5 + 0.01) - 0.03,
                     x + 0.012, cy + s * (h * 0.5 + 0.01) + 0.03, gold)
    led.rounded_box(parent, "Chip", (w, h, 0.04), (cx, cy, z + 0.02), ceramic, 0.012, 0.006)
    dm.cyl(parent, "Chipkerbe", 0.022, 0.004, (cx - w * 0.46, cy, z + 0.0405), led.DARK, 16)
    dm.annulus(parent, "Fensterfassung", cx, cy, z + 0.041, win, win * 1.2, gold, 32)
    dm.cyl(parent, "Fenstergrund", win, 0.003, (cx, cy, z + 0.039), led.DARK, 32)
    if burned:
        d = win * 0.43
        box.rect(parent, "Die", top(z + 0.041), cx - d, cy - d, cx + d, cy + d,
                 glow(key, 4.0 * gain))
        for k in range(8):
            a = k * math.tau / 8
            seg(parent, "Bond%d" % k, top(z + 0.041), cx + math.cos(a) * win * 0.5,
                cy + math.sin(a) * win * 0.5, cx + math.cos(a) * win * 0.94,
                cy + math.sin(a) * win * 0.94, 0.003, gold)
    dm.cyl(parent, "Quarz", win, 0.004, (cx, cy, z + 0.043), led.GLASS, 32)


def fingers(parent, z, x0=0.725, x1=0.802, n=11):
    for k in range(n):
        y = (k - (n - 1) * 0.5) * 0.085
        box.rect(parent, "Kontakt%d" % k, top(z), x0, y - 0.028, x1, y + 0.028, gold_mat())


def modul_kassette(parent, seed=1, mode="repair", on=False):
    """STECKMODUL: die Platine steckt in einer Kunststoff-Schale - Griffrippen, Etikett hinter
    dem Netz, Chip hinter einem Sichtfenster, am Steck-Ende schaut die Kontaktleiste heraus."""
    rnd = random.Random(seed)
    key = ms.HOLO_MODES[mode][0]
    gain = 1.0 if on else 0.45
    t = 0.09
    board = led.mat("Loetstopp_" + key, tuple(0.008 + v * 0.045 for v in col(key)), 0.0, 0.35,
                    clearcoat=0.6)
    led.rounded_box(parent, "Platine", (0.3, W - 0.2, 0.03), (0.66, 0, 0.045), board, 0.01, 0.0)
    fingers(parent, 0.06)
    shell = led.mat("Modulschale", (0.07, 0.072, 0.08), 0.0, 0.5, clearcoat=0.15)
    led.rounded_box(parent, "Schale", (1.5, W, t), (-0.06, 0, t * 0.5), shell, 0.05, 0.014)
    led.frame_ring(parent, "Naht", (1.502, W + 0.002), (1.48, W - 0.02), t * 0.5, 0.006,
                   glow(key, 1.8 * gain), 0.05, y=0).location.x = -0.06
    bpy.data.objects["NahtLoch"].location.x = -0.06
    rib = led.mat("Modulrippe", (0.035, 0.036, 0.04), 0.0, 0.6)
    for k in range(13):
        led.rounded_box(parent, "Rippe%d" % k, (0.07, 0.03, 0.008), (-0.75, (k - 6) * 0.07,
                                                                     t + 0.004), rib, 0.0, 0.003)
    sticker = led.mat("Etikett_" + key, tuple(0.02 + v * 0.16 for v in col(key)), 0.0, 0.6, 0.15)
    led.rounded_box(parent, "Etikett", (1.36, 0.42, 0.002), (-0.03, 0.0, t + 0.001), sticker, 0.03,
                    0.0)
    led.rounded_box(parent, "EtikettQuer", (0.42, 1.02, 0.002), (C * 0.5, 0.0, t + 0.001), sticker,
                    0.03, 0.0)
    led.rounded_box(parent, "Sichtfenster", (0.6, 0.3, 0.003), (-0.37, 0.345, t + 0.0015),
                    led.mat("Fenster_dunkel", (0.004, 0.004, 0.006), 0.0, 0.05, clearcoat=1.0),
                    0.04, 0.0)
    eprom(parent, -0.37, 0.345, t - 0.036, key, gain, mode != "blank", 0.46, 0.16, 0.06, 9)
    silk = led.mat("Siebdruck", (0.75, 0.76, 0.78), 0.0, 0.7, 0.25)
    w0, w1 = ms.HOLO_MODES[mode][1], ms.HOLO_MODES[mode][2]
    box.text(parent, w0 + w1, top(t + 0.0004), -0.37, -0.31, 0.042, silk, "Name")
    box.text(parent, "SB-%02d" % rnd.randint(1, 99), top(t + 0.0004), -0.37, -0.39, 0.034, silk,
             "Serie")
    for k in range(3):
        seg(parent, "Pfeil%d" % k, top(t + 0.0004), 0.5 + k * 0.05, -0.39, 0.53 + k * 0.05, -0.36,
            0.008, glow(key, 1.4 * gain))
        seg(parent, "Pfeilb%d" % k, top(t + 0.0004), 0.5 + k * 0.05, -0.33, 0.53 + k * 0.05, -0.36,
            0.008, glow(key, 1.4 * gain))
    dm.screws(parent, [(0.6, 0.47), (0.6, -0.47)], t)
    cell_plates(parent, t + 0.002, key, mode, gain, navy_plate())


def modul_chip(parent, seed=1, mode="repair", on=False):
    """RIESEN-CHIP: die Karte IST der Baustein - Keramik mit Beinchen an beiden Langseiten, das
    Netz ist der Die hinter einem kreuzförmigen Quarzfenster, Bonddrähte laufen zu den Beinen."""
    rnd = random.Random(seed)
    key = ms.HOLO_MODES[mode][0]
    gain = 1.0 if on else 0.45
    t = 0.07
    gold = gold_mat()
    ceramic = led.mat("Keramik_gross", (0.13, 0.1, 0.16), 0.0, 0.55, clearcoat=0.25)
    led.rounded_box(parent, "Keramik", (L - 0.06, W - 0.16, t), (0, 0, t * 0.5), ceramic, 0.04,
                    0.01)
    n = 16
    for k in range(n):
        x = -0.72 + k * 1.44 / (n - 1)
        for s in (-1, 1):
            led.rounded_box(parent, "Bein%d_%d" % (k, s), (0.05, 0.1, 0.02),
                            (x, s * (W * 0.5 - 0.045), 0.012), gold, 0.0, 0.004)
    dm.cyl(parent, "Kerbe", 0.05, 0.006, (-0.78, 0.0, t), led.DARK, 24)
    # Der Fenster-Rahmen und der Die im Kreuz.
    for name, size, loc in (("Arm", (4 * C + 0.08, C + 0.08), (0, 0)),
                            ("Quer", (C + 0.08, 3 * C - 0.02), (C * 0.5, 0))):
        led.rounded_box(parent, "Goldrahmen" + name, (size[0], min(size[1], W - 0.2), 0.004),
                        (loc[0], loc[1], t + 0.001), gold, 0.03, 0.0)
        led.rounded_box(parent, "Schacht" + name, (size[0] - 0.035, min(size[1], W - 0.2) - 0.035,
                                                   0.004), (loc[0], loc[1], t + 0.002),
                        led.mat("Die_grund", (0.01, 0.012, 0.02), 0.6, 0.15, clearcoat=1.0), 0.02,
                        0.0)
    for k in range(n):
        x = -0.72 + k * 1.44 / (n - 1)
        for s in (-1, 1):
            ex = max(-2 * C, min(2 * C, x * 0.86))
            ey = s * (C * 0.5 + 0.03)
            if abs(ex - C * 0.5) < C * 0.5 + 0.05:
                continue
            seg(parent, "Bond%d_%d" % (k, s), top(t + 0.0004), ex, ey, x, s * (W * 0.5 - 0.1),
                0.004, gold)
    etch = led.mat("Gravurdruck", (0.6, 0.6, 0.64), 0.0, 0.6, 0.2)
    w0, w1 = ms.HOLO_MODES[mode][1], ms.HOLO_MODES[mode][2]
    for k, (x, y, w, h) in enumerate(((-0.4, 0.34, 0.3, 0.13), (-0.4, -0.34, 0.5, 0.07),
                                      (0.57, -0.34, 0.16, 0.07))):
        led.rounded_box(parent, "Druckfeld%d" % k, (w, h, 0.002), (x, y, t + 0.0016), ceramic,
                        0.015, 0.0)
    zt = top(t + 0.0028)
    box.text(parent, "FUMBLE", zt, -0.4, 0.365, 0.05, etch, "Marke")
    box.text(parent, "SB-%02d" % rnd.randint(1, 99), zt, -0.4, 0.305, 0.036, etch, "Serie")
    box.text(parent, w0 + w1, zt, -0.4, -0.34, 0.036, etch, "Name")
    box.text(parent, "8826", zt, 0.57, -0.34, 0.036, etch, "Datum")
    cell_plates(parent, t + 0.004, key, mode, gain, navy_plate())
    for name, size, loc in (("Arm", (4 * C + 0.045, C + 0.045), (0, 0)),
                            ("Quer", (C + 0.045, 3 * C - 0.055), (C * 0.5, 0))):
        led.rounded_box(parent, "Quarz" + name, (size[0], size[1], 0.004),
                        (loc[0], loc[1], t + 0.016), led.GLASS, 0.02, 0.0)


def modul_deko(parent, seed=1, mode="repair", on=False):
    """GOLD-DEKO: mattschwarze Platine, die Leiterbahnen als breite Gold-Ornamente in Stufen um
    das Netz - das Luxus-Modul eines Casinos."""
    rnd = random.Random(seed)
    key = ms.HOLO_MODES[mode][0]
    gain = 1.0 if on else 0.45
    t = 0.034
    black = led.mat("Mattschwarz", (0.012, 0.012, 0.014), 0.0, 0.6, clearcoat=0.2)
    led.rounded_box(parent, "Platine", (L, W, t), (0, 0, t * 0.5), black, 0.05, 0.004)
    gold = led.mat("Deko_gold", (1.0, 0.72, 0.26), 1.0, 0.25, 0.12)
    fr = top(t)
    fingers(parent, t)
    e = 0.03
    rim = [(-L * 0.5 + e, -W * 0.5 + e), (0.7, -W * 0.5 + e), (0.7, W * 0.5 - e),
           (-L * 0.5 + e, W * 0.5 - e)]
    for k in range(4):
        a, b = rim[k], rim[(k + 1) % 4]
        seg(parent, "Rand%d" % k, fr, a[0], a[1], b[0], b[1], 0.01, gold)
    # Gestufte Winkel in den vier freien Ecken des Kreuzes.
    for q, (cx, cy, sx, sy, depth) in enumerate(((0.0, C * 0.5, -1, 1, 6), (C, C * 0.5, 1, 1, 4),
                                                 (0.0, -C * 0.5, -1, -1, 6),
                                                 (C, -C * 0.5, 1, -1, 4))):
        for k in range(depth):
            o = 0.03 + k * 0.04
            x_end = -0.72 if sx < 0 else 0.66
            y_end = sy * 0.48
            px, py = cx + sx * o, cy + sy * o
            if (sx > 0 and px > x_end) or (sx < 0 and px < x_end):
                continue
            if abs(py) > 0.48:
                continue
            seg(parent, "Stufe%d_%da" % (q, k), fr, px, py, x_end, py, 0.012, gold)
            seg(parent, "Stufe%d_%db" % (q, k), fr, px, py, px, y_end, 0.012, gold)
            box.dot(parent, "Stufenpunkt%d_%d" % (q, k), fr, px, py, 0.012, gold)
    led.rounded_box(parent, "Chipfeld", (0.54, 0.25, 0.003), (-0.4, 0.345, t + 0.0015), black, 0.03,
                    0.0)
    eprom(parent, -0.4, 0.345, t + 0.003, key, gain, mode != "blank", 0.48, 0.17, 0.065, 9)
    silk = led.mat("Golddruck", (0.9, 0.68, 0.3), 0.6, 0.4, 0.2)
    led.rounded_box(parent, "Schildfeld", (0.5, 0.15, 0.003), (-0.4, -0.365, t + 0.0015), black,
                    0.03, 0.0)
    w0, w1 = ms.HOLO_MODES[mode][1], ms.HOLO_MODES[mode][2]
    box.text(parent, w0 + w1, top(t + 0.003), -0.4, -0.33, 0.04, silk, "Name")
    box.text(parent, "No. %02d" % rnd.randint(1, 99), top(t + 0.003), -0.4, -0.4, 0.032, silk,
             "Serie")
    cell_plates(parent, t, key, mode, gain, navy_plate())


def modul_bastel(parent, seed=1, mode="repair", on=False):
    """SCHWARZMARKT: dasselbe Modul, von Hand umgebaut - Fädeldrähte, Lötkleckse, ein
    beschrifteter Aufkleber und ein gebrochenes Garantiesiegel."""
    rnd = random.Random(seed)
    key = ms.HOLO_MODES[mode][0]
    sonder_modul(parent, seed, mode, on)
    t = 0.034
    z = t + 0.002
    solder = led.mat("Lot", (0.8, 0.82, 0.85), 1.0, 0.25)
    wires = (("#ff5c8a", [(-0.52, 0.2), (-0.6, 0.05), (-0.7, -0.2), (-0.56, -0.36)]),
             ("#5ce1ff", [(-0.2, 0.2), (0.34, 0.26), (0.5, 0.2), (0.7, 0.3)]),
             ("#ffe45c", [(-0.36, 0.2), (-0.1, -0.2), (0.3, -0.24), (0.42, -0.4)]))
    for i, (hexc, pts) in enumerate(wires):
        m = led.mat("Faedeldraht%d" % i, led.lin(hexc), 0.0, 0.4, 0.25, clearcoat=0.6)
        for k in range(len(pts) - 1):
            a, b = pts[k], pts[k + 1]
            seg(parent, "Draht%d_%d" % (i, k), top(z + i * 0.0006), a[0], a[1], b[0], b[1], 0.011,
                m)
            box.dot(parent, "Drahtknick%d_%d" % (i, k), top(z + i * 0.0006), b[0], b[1], 0.0055, m)
        for p in (pts[0], pts[-1]):
            dm.cyl(parent, "Lotklecks%d_%.2f" % (i, p[0]), 0.02, 0.008, (p[0], p[1], z + 0.004),
                   solder, 12)
    paper = led.mat("Aufkleber", (0.82, 0.8, 0.7), 0.0, 0.85, 0.12)
    fr = box.frame((0.52, -0.33, z + 0.003), (0.995, 0.1, 0), (-0.1, 0.995, 0))
    box.rect(parent, "Aufkleber", fr, -0.22, -0.085, 0.22, 0.085, paper)
    ink = led.mat("Filzstift", (0.03, 0.03, 0.12), 0.0, 0.7)
    fr2 = box.frame((0.52, -0.33, z + 0.0036), (0.995, 0.1, 0), (-0.1, 0.995, 0))
    box.text(parent, "SB-%02d läuft!" % rnd.randint(1, 99), fr2, 0.0, 0.02, 0.05, ink, "Notiz")
    seg(parent, "Unterstrich", fr2, -0.16, -0.04, 0.15, -0.045, 0.006, ink)
    red = led.mat("Siegel", (0.6, 0.05, 0.04), 0.0, 0.5, 0.15)
    fr3 = box.frame((-0.02, 0.4, z + 0.045), (0.94, -0.34, 0), (0.34, 0.94, 0))
    box.rect(parent, "SiegelA", fr3, -0.13, -0.03, -0.012, 0.03, red)
    box.decal(parent, "SiegelB", fr3, [(0.012, -0.03), (0.13, -0.03), (0.13, 0.03), (0.03, 0.03)],
              red)
    led.rounded_box(parent, "Heisskleber", (0.14, 0.09, 0.02), (0.57, 0.3, z + 0.006),
                    led.mat("Heisskleber", (0.8, 0.75, 0.6), 0.0, 0.2, 0.0, 0.5, clearcoat=1.0),
                    0.04, 0.01)


def modul_glas(parent, seed=1, mode="repair", on=False):
    """GLAS-PLATINE: klares Substrat mit leuchtender Kante, die Leiterbahnen als Lichtleiter."""
    key = ms.HOLO_MODES[mode][0]
    gain = 1.0 if on else 0.45
    glass = led.mat("Glasplatine_" + key, tuple(0.3 + v * 0.3 for v in col(key)), 0.0, 0.03, 0.0,
                    0.1, clearcoat=1.0)
    led.rounded_box(parent, "Unterlage", (L - 0.02, W - 0.02, 0.004), (0, 0, 0.002),
                    led.mat("Glasgrund", (0.004, 0.005, 0.008), 0.0, 0.25, clearcoat=0.8), 0.03, 0.0)
    led.frame_ring(parent, "Lichtkante", (L + 0.002, W + 0.002), (L - 0.016, W - 0.016), 0.017,
                   0.03, glow(key, 2.4 * gain), 0.03, y=0)
    sonder_modul(parent, seed, mode, on, glass, 2.6)


SETS["modul"] = [("A · SERVICE-MODUL (bisher)", lambda p: sonder_modul(p, 4, "repair", True)),
                 ("A1 · STECKMODUL", lambda p: modul_kassette(p, 4, "repair", True)),
                 ("A2 · RIESEN-CHIP", lambda p: modul_chip(p, 4, "repair", True)),
                 ("A3 · GOLD-DEKO", lambda p: modul_deko(p, 4, "repair", True)),
                 ("A4 · SCHWARZMARKT", lambda p: modul_bastel(p, 4, "repair", True)),
                 ("A5 · GLAS-PLATINE", lambda p: modul_glas(p, 4, "repair", True))]
SETS["modulaus"] = [("A · MAGAZIN", lambda p: sonder_modul(p, 4, "cool")),
                    ("A1 · MAGAZIN", lambda p: modul_kassette(p, 4, "cool")),
                    ("A2 · MAGAZIN", lambda p: modul_chip(p, 4, "cool")),
                    ("A3 · MAGAZIN", lambda p: modul_deko(p, 4, "cool")),
                    ("A4 · MAGAZIN", lambda p: modul_bastel(p, 4, "cool")),
                    ("A5 · MAGAZIN", lambda p: modul_glas(p, 4, "cool"))]
# --- GOLD-DEKO, gedämpft: nur das Netz leuchtet (2026-11-19) ------------------------------------

VIAS = []


def polyline(parent, name, fr, pts, w, material, via=None):
    """Ein Linienzug; die Vias sammeln sich in VIAS (EIN Netz statt hunderter Objekte)."""
    for k in range(len(pts) - 1):
        a, b = pts[k], pts[k + 1]
        seg(parent, "%s_%d" % (name, k), fr, a[0], a[1], b[0], b[1], w, material)
    if via:
        VIAS.append(pts[-1])


def deko_steps(parent, fr, line, via, pitch=0.024, w=0.007):
    """Feine gestufte Winkel in den vier freien Ecken des Kreuzes, jede Bahn endet in einem Via."""
    for q, (cx, cy, sx, sy) in enumerate(((0.0, C * 0.5, -1, 1), (C, C * 0.5, 1, 1),
                                          (0.0, -C * 0.5, -1, -1), (C, -C * 0.5, 1, -1))):
        x_end = -0.74 if sx < 0 else 0.68
        k = 0
        while True:
            o = 0.03 + k * pitch
            px, py = cx + sx * o, cy + sy * o
            if abs(py) > 0.485 or (sx > 0 and px > x_end - 0.03) or (sx < 0 and px < x_end + 0.03):
                break
            stop = x_end - sx * (k % 3) * 0.03
            polyline(parent, "Stufe%d_%d" % (q, k), fr, [(stop, py), (px, py),
                                                         (px, sy * (0.487 - (k % 2) * 0.03))], w,
                     line, via)
            VIAS.append((stop, py))
            k += 1


def deko_fan(parent, fr, line, via, w=0.006):
    """Leiterbahn-Bündel mit 45-Grad-Knicken: vom Netz zu den Kontakten, zum Chip, zum Rand."""
    for k in range(11):
        y = (k - 5) * 0.085
        d = abs(k - 5)
        if d <= 1:
            pts = [(0.725, y), (2 * C + 0.02, y)]
        else:
            s = 1 if k > 5 else -1
            x_turn = 0.69 - d * 0.016
            ty = s * (C * 0.5 + 0.03 + (5 - d) * 0.024)
            pts = [(0.725, y), (x_turn, y), (x_turn - abs(y - ty), ty), (C + 0.05 + (5 - d) * 0.02,
                                                                        ty)]
            pts.append((pts[-1][0], s * (C * 0.5 + 0.4 - d * 0.06)))
        polyline(parent, "Kontaktbahn%d" % k, fr, pts, w, line, via)
    for k in range(12):
        x = -0.62 + k * 0.047
        bend = 0.2 + (k % 4) * 0.012
        polyline(parent, "Chipbahn%d" % k, fr, [(x, 0.24), (x, bend), (x + 0.03, bend - 0.03),
                                                (x + 0.03, C * 0.5 + 0.02)], w, line, via)
    for k in range(14):
        x = -0.6 + k * 0.04
        y_out = -0.28 - k * 0.014
        polyline(parent, "Fussbahn%d" % k, fr, [(x, -C * 0.5 - 0.02), (x, y_out + 0.04),
                                                (x - 0.04, y_out), (-0.74, y_out)], w, line, via)
    for k in range(5):
        y = -0.1 + k * 0.05
        polyline(parent, "Kopfbahn%d" % k, fr, [(-2 * C - 0.02, y), (-0.7 - k * 0.012, y),
                                                (-0.7 - k * 0.012, 0.3 + k * 0.03)], w, line, via)


def deko_parts(parent, rnd, t, pad, refdes):
    """Feine Bestückung: SMD-Reihen, ein QFP, ein BGA-Feld, Prüfpunkte, Bauteil-Namen."""
    dark = led.mat("SMD", (0.03, 0.03, 0.035), 0.0, 0.5)
    tan = led.mat("Kerko", (0.16, 0.12, 0.08), 0.0, 0.6)
    fr = top(t + 0.0008)
    n = 0
    for x0, x1, y0, y1 in ((0.39, 0.67, 0.2, 0.3), (0.39, 0.67, -0.3, -0.2), (-0.7, -0.08, -0.27,
                                                                             -0.21)):
        x = x0
        while x < x1:
            y = y0
            while y < y1:
                if rnd.random() < 0.75:
                    m = dark if rnd.random() < 0.6 else tan
                    led.rounded_box(parent, "Teil%d" % n, (0.036, 0.02, 0.01), (x, y, t + 0.006), m,
                                    0.0, 0.002)
                    for s in (-1, 1):
                        box.rect(parent, "Teilpad%d_%d" % (n, s), fr, x + s * 0.022 - 0.006,
                                 y - 0.011, x + s * 0.022 + 0.006, y + 0.011, pad)
                    n += 1
                y += 0.04
            x += 0.07
    # QFP oben rechts, BGA-Feld unten rechts.
    qx, qy = 0.53, 0.4
    led.rounded_box(parent, "QFP", (0.13, 0.13, 0.014), (qx, qy, t + 0.008), dark, 0.006, 0.002)
    for k in range(8):
        o = (k - 3.5) * 0.015
        for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            a = (qx + dx * 0.075 + (o if dx == 0 else 0), qy + dy * 0.075 + (o if dy == 0 else 0))
            box.rect(parent, "QFPBein%d_%d_%d" % (k, dx, dy), fr, a[0] - (0.004 if dx == 0 else
                                                                         0.012),
                     a[1] - (0.012 if dx == 0 else 0.004), a[0] + (0.004 if dx == 0 else 0.012),
                     a[1] + (0.012 if dx == 0 else 0.004), pad)
    box.dot(parent, "QFPMarke", top(t + 0.0152), qx - 0.045, qy + 0.045, 0.008, pad)
    pts = [(0.45 + i * 0.022, -0.46 + j * 0.022, t + 0.002) for i in range(8) for j in range(6)]
    dm.dots(parent, "BGA", pts, 0.006, pad)
    for k in range(7):
        box.dot(parent, "Pruefpunkt%d" % k, fr, -0.7 + k * 0.045, 0.2, 0.009, pad)
    for k, (name, x, y) in enumerate((("U2", 0.53, 0.3), ("C1-C8", 0.53, 0.17), ("R1-R9", -0.39,
                                                                                -0.185),
                                      ("TP1", -0.745, 0.165), ("J1", 0.69, 0.5))):
        box.text(parent, name, top(t + 0.0004), x, y, 0.018, refdes, "Name%d" % k)


def modul_deko_fein(parent, seed=1, mode="repair", on=False, style="stufen"):
    """GOLD-DEKO gedämpft: feine, matte Leiterbahnen und Bauteile - es leuchtet NUR das Netz."""
    rnd = random.Random(seed)
    key = ms.HOLO_MODES[mode][0]
    gain = 1.0 if on else 0.45
    t = 0.034
    black = led.mat("Mattschwarz", (0.012, 0.012, 0.014), 0.0, 0.6, clearcoat=0.2)
    led.rounded_box(parent, "Platine", (L, W, t), (0, 0, t * 0.5), black, 0.05, 0.004)
    dull = led.mat("Mattgold", (0.3, 0.21, 0.08), 0.3, 0.5)
    pad = led.mat("Padgold", (0.5, 0.36, 0.13), 0.5, 0.4)
    if style == "tonal":
        tone = tuple(0.03 + v * 0.035 for v in col(key))
        line = led.mat("Tonbahn_" + key, tone, 0.0, 0.3, clearcoat=0.8)
        via = led.mat("Tonvia_" + key, tuple(v * 1.8 for v in tone), 0.0, 0.3, clearcoat=0.8)
    else:
        line, via = dull, pad
    fr = top(t)
    for k in range(11):
        y = (k - 5) * 0.085
        box.rect(parent, "Kontakt%d" % k, fr, 0.725, y - 0.028, 0.802, y + 0.028, pad)
    e = 0.025
    rim = [(-L * 0.5 + e, -W * 0.5 + e), (0.705, -W * 0.5 + e), (0.705, W * 0.5 - e),
           (-L * 0.5 + e, W * 0.5 - e)]
    for k in range(4):
        a, b = rim[k], rim[(k + 1) % 4]
        seg(parent, "Rand%d" % k, fr, a[0], a[1], b[0], b[1], 0.006, line)
    if style in ("stufen", "tonal"):
        deko_steps(parent, fr, line, via)
    if style in ("faecher", "bestueckt", "tonal"):
        deko_fan(parent, top(t + 0.0002), line, via)
    dm.dots(parent, "Vias", [(x, y, t + 0.001) for x, y in VIAS], 0.011, via)
    del VIAS[:]
    if style in ("bestueckt", "tonal"):
        deko_parts(parent, rnd, t, pad, led.mat("Refdes", (0.22, 0.22, 0.24), 0.0, 0.7))
    led.rounded_box(parent, "Chipfeld", (0.54, 0.25, 0.003), (-0.4, 0.37, t + 0.0015), black, 0.03,
                    0.0)
    eprom(parent, -0.4, 0.37, t + 0.003, key, 0.1, mode != "blank", 0.48, 0.17, 0.065, 12, pad)
    led.rounded_box(parent, "Schildfeld", (0.5, 0.11, 0.003), (-0.4, -0.44, t + 0.0015), black,
                    0.03, 0.0)
    silk = led.mat("Mattdruck", (0.42, 0.33, 0.16), 0.2, 0.5)
    w0, w1 = ms.HOLO_MODES[mode][1], ms.HOLO_MODES[mode][2]
    box.text(parent, w0 + w1 + "  ·  No. %02d" % rnd.randint(1, 99), top(t + 0.0036), -0.4, -0.44,
             0.034, silk, "Name")
    cell_plates(parent, t, key, mode, gain, navy_plate())


def _deko(style, mode, on):
    return lambda p: modul_deko_fein(p, 4, mode, on, style)


SETS["deko"] = [("A3 · GOLD-DEKO (bisher)", lambda p: modul_deko(p, 4, "repair", True)),
                ("D1 · STUFEN", _deko("stufen", "repair", True)),
                ("D2 · FÄCHER", _deko("faecher", "repair", True)),
                ("D3 · BESTÜCKT", _deko("bestueckt", "repair", True)),
                ("D4 · TON IN TON", _deko("tonal", "repair", True)),
                ("D4 · TON IN TON · KÜHL", _deko("tonal", "cool", True))]
SETS["dekoaus"] = [("A3 · MAGAZIN (bisher)", lambda p: modul_deko(p, 4, "cool")),
                   ("D1 · MAGAZIN", _deko("stufen", "cool", False)),
                   ("D2 · MAGAZIN", _deko("faecher", "cool", False)),
                   ("D3 · MAGAZIN", _deko("bestueckt", "cool", False)),
                   ("D4 · MAGAZIN", _deko("tonal", "cool", False)),
                   ("D3 · ROHLING", _deko("bestueckt", "blank", True))]

SPOTS6 = [(x, y) for y in (0.72, -0.72) for x in (-2.0, 0.0, 2.0)]

SPOTS = [(-1.0, 0.72), (1.0, 0.72), (-1.0, -0.72), (1.0, -0.72)]


def view_set(name, flat):
    cam, aim = dm.empty_stage()
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    six = len(SETS[name]) > 4
    if six:
        scene.render.resolution_x = 2100
    for (title, fn), (x, y) in zip(SETS[name], SPOTS6 if six else SPOTS):
        dm.build(fn, title, (x, y, 0.001))
        ms.label(title, x, y - 0.64, 0.075)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 6.3 if six else 4.5
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
