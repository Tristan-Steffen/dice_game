"""Fumble: die SEITEN der Walze, je Datenträger drei Entwürfe nach Epoche und Sortenfarbe
(2026-11-19). Jede Kachel ist die Oberseite EINER Scheibe samt gewähltem Leser; oben leer,
unten mit Karte.
  flaeche_loch:     tabellierer | bakelit | werkbank      (1930er/40er, Grün)
  flaeche_kassette: walkman | boombox | hifi              (1990er, Pink)
  flaeche_ton:      lehmziegel | glasur | sandstein       (Mesopotamien, Gelb)
  flaeche_modul:    esd-matte | lochraster | backplane    (Labor 1980er bis heute, Lila)

Aufruf (kopflos):
  blender -b -P tools/blender_drum_faces.py -- <ausgabe-ordner> [ansicht,ansicht]
"""
import bpy, math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_drum_readers as rd

dm, led, box = rd.dm, rd.led, rd.box
glow, col = rd.glow, rd.col
L, W, SL, SW = rd.L, rd.W, rd.SL, rd.SW
HX, HY = L * 0.5, W * 0.5
MX = HX + (SL - L) * 0.25
Z1, Z2, Z3, Z4 = 0.001, 0.002, 0.003, 0.004
# Der Sonderbestand trägt im Spiel Lila.
dm.HEX["gold"] = "#bd93f9"
lin = led.lin
INK = (0.015, 0.015, 0.015)


def m(name, color, metal=0.0, rough=0.5, emit=0.0, cc=0.0):
    return led.mat("F_" + name, color, metal, rough, emit, 1.0, cc)


def bumpy(name, color, rough, scale, strength, metal=0.0, cc=0.0):
    return dm.bumpy("F_" + name, color, rough, scale, strength, metal, cc)


def flats(parent, name, polys, z, material):
    verts, faces = [], []
    for poly in polys:
        k = len(verts)
        verts += [(x, y, z) for x, y in poly]
        faces.append(list(range(k, k + len(poly))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = parent
    return o


def rect(x, y, w, h):
    return [(x - w / 2, y - h / 2), (x + w / 2, y - h / 2), (x + w / 2, y + h / 2),
            (x - w / 2, y + h / 2)]


def rrect(x, y, w, h, r, n=6):
    pts = []
    for cx, cy, a0 in ((x + w / 2 - r, y - h / 2 + r, -90), (x + w / 2 - r, y + h / 2 - r, 0),
                       (x - w / 2 + r, y + h / 2 - r, 90), (x - w / 2 + r, y - h / 2 + r, 180)):
        for i in range(n + 1):
            a = math.radians(a0 + 90.0 * i / n)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def disc(x, y, r, n=14):
    return [(x + math.cos(math.tau * i / n) * r, y + math.sin(math.tau * i / n) * r)
            for i in range(n)]


def line(x0, y0, x1, y1, w):
    dx, dy = x1 - x0, y1 - y0
    d = math.hypot(dx, dy)
    px, py = -dy / d * w / 2, dx / d * w / 2
    return [(x0 + px, y0 + py), (x0 - px, y0 - py), (x1 - px, y1 - py), (x1 + px, y1 + py)]


def ring(x, y, w, h, t):
    return [rect(x, y - h / 2, w + t, t), rect(x, y + h / 2, w + t, t),
            rect(x - w / 2, y, t, h + t), rect(x + w / 2, y, t, h + t)]


def star(x, y, r0, r1, points, turn=0.0):
    return [(x + math.cos(turn + math.pi * i / points) * (r0 if i % 2 == 0 else r1),
             y + math.sin(turn + math.pi * i / points) * (r0 if i % 2 == 0 else r1))
            for i in range(points * 2)]


def rosette(x, y, r):
    return [disc(x + math.cos(math.tau * k / 8) * r * 0.62, y + math.sin(math.tau * k / 8) * r
                 * 0.62, r * 0.3, 10) for k in range(8)]


def tri(x, y, s, flip=1):
    pts = [(x - s * 0.5 * flip, y - s * 0.55), (x + s * 0.5 * flip, y),
           (x - s * 0.5 * flip, y + s * 0.55)]
    return pts if flip > 0 else pts[::-1]


def base(parent, material):
    led.rounded_box(parent, "Scheibe", (SL, SW, 0.1), (0, 0, -0.05), material, 0.03, 0.006)


def slab(parent, name, sx, sy, h, x, y, z0, material, corner=0.0, edge=0.002):
    return led.rounded_box(parent, name, (sx, sy, h), (x, y, z0 + h * 0.5), material, corner, edge)


# --- LOCHKARTE: 1930er/40er, Grün ---------------------------------------------------------------

def loch_tabellierer(p):
    """Schrumpflack, Messing, grünes Email: das Feld einer Tabelliermaschine von 1934."""
    base(p, bumpy("Schrumpflack", (0.012, 0.012, 0.014), 0.35, 160.0, 0.5, 0.0, 0.6))
    brass = rd.brass()
    flats(p, "Messingrahmen", [rect(0, 0, L + 0.05, W + 0.05)], Z1, brass)
    flats(p, "Emailfeld", [rect(0, 0, L, W)], Z2, m("Emailgruen", (0.012, 0.1, 0.04), 0.0, 0.2,
                                                    0.0, 1.0))
    flats(p, "Spalten", [rect(-HX + (i + 0.5) * L / 20, 0.05, 0.006, W - 0.22) for i in range(20)],
          Z3, brass)
    flats(p, "Skala", [rect(0, -HY + 0.07, L - 0.06, 0.08)], Z3, m("Elfenbein", lin("#e6d9b0"),
                                                                 0.0, 0.5))
    flats(p, "Teilung", [rect(-HX + 0.03 + (i + 0.5) * (L - 0.06) / 40, -HY + 0.07, 0.004,
                              0.06 if i % 5 == 0 else 0.03) for i in range(40)], Z4,
          m("Tusche", INK, 0.0, 0.6))
    for k, y in enumerate((-0.36, 0.0, 0.36)):
        dm.cyl(p, "Lampenring%d" % k, 0.04, 0.016, (MX, y, 0.008), brass, 24)
        dm.cyl(p, "Juwel%d" % k, 0.027, 0.03, (MX, y, 0.015), glow("zahl", 2.2 if k == 1 else
                                                                  0.5), 8)
    for k, y in enumerate((-0.18, 0.18)):
        dm.cyl(p, "Schraube%d" % k, 0.022, 0.01, (MX, y, 0.005), brass, 20)
        flats(p, "Schlitz%d" % k, [line(MX - 0.016, y - 0.008, MX + 0.016, y + 0.008, 0.005)],
              0.0105, m("Tusche", INK, 0.0, 0.6))


def loch_bakelit(p):
    """Braunes Bakelit mit Rippen, Elfenbein-Einlage, Chrom-Stufen und ein grünes Magisches Auge."""
    bak = bumpy("Bakelit", (0.075, 0.024, 0.012), 0.16, 7.0, 0.1, 0.0, 1.0)
    base(p, bak)
    flats(p, "Einlage", [rect(0, 0, L + 0.04, W + 0.04)], Z1, m("Elfenbein", lin("#e6d9b0"), 0.0,
                                                               0.5))
    flats(p, "Grund", [rect(0, 0, L - 0.02, W - 0.02)], Z2, m("Bakelitgrund", (0.03, 0.01, 0.006),
                                                             0.0, 0.25, 0.0, 1.0))
    for i in range(13):
        slab(p, "Rippe%d" % i, L - 0.42, 0.036, 0.006, -0.14, (i - 6) * 0.074, Z2, bak, 0.016)
    chrome = rd.chrome()
    flats(p, "Stufen", [rect(0.6 + k * 0.045, 0, 0.016, W - 0.16 - k * 0.2) for k in range(4)], Z3,
          chrome)
    dm.cyl(p, "Augenfassung", 0.046, 0.014, (MX, 0, 0.007), chrome, 28)
    dm.annulus(p, "MagischesAuge", MX, 0, 0.0145, 0.012, 0.036, glow("zahl", 2.4), 28)
    flats(p, "Augenschatten", [[(MX, 0)] + [(MX + math.cos(math.radians(a)) * 0.036,
                                             math.sin(math.radians(a)) * 0.036)
                                            for a in range(-25, 26, 10)]], 0.015,
          m("Tusche", INK, 0.0, 0.6))
    for k, y in enumerate((-0.4, 0.4)):
        dm.cyl(p, "Knopf%d" % k, 0.034, 0.014, (MX, y, 0.007), bak, 24)
        dm.cyl(p, "Knopfkern%d" % k, 0.014, 0.016, (MX, y, 0.008), chrome, 16)


def loch_werkbank(p):
    """Hammerschlag-Lack im Maschinengrün, Billardfilz, vernietete Nickelleisten: Lochsaal 1942."""
    base(p, bumpy("Hammerschlag", (0.05, 0.19, 0.1), 0.38, 45.0, 0.7, 0.4, 0.3))
    flats(p, "Filz", [rect(0, 0, L, W)], Z1, bumpy("Filz", (0.012, 0.12, 0.045), 1.0, 300.0, 0.3))
    nickel = m("Nickel", (0.62, 0.6, 0.55), 1.0, 0.28)
    flats(p, "Leisten", ring(0, 0, L + 0.01, W + 0.01, 0.04), Z2, nickel)
    flats(p, "Gleitbahnen", [rect(0, s * 0.22, L - 0.08, 0.05) for s in (-1, 1)], Z2,
          m("Blankstahl", (0.5, 0.5, 0.52), 1.0, 0.2))
    k = 0
    for i in range(9):
        for s in (-1, 1):
            dm.cyl(p, "Niet%d" % k, 0.012, 0.008, ((i - 4) * 0.2, s * (HY + 0.005), 0.004), nickel,
                   10)
            k += 1
    flats(p, "Schild", [rect(MX, 0, 0.07, 0.62)], Z1, m("Emailweiss", lin("#ece4c8"), 0.0, 0.2,
                                                        0.0, 1.0))
    flats(p, "Schildrand", ring(MX, 0, 0.052, 0.6, 0.006), Z2, m("Schildgruen", (0.02, 0.2, 0.08),
                                                                 0.0, 0.3))
    flats(p, "Schildzeilen", [rect(MX, (i - 4.5) * 0.055, 0.03, 0.012) for i in range(10)], Z2,
          m("Tusche", INK, 0.0, 0.6))
    for k, y in enumerate((-0.42, 0.42)):
        dm.cyl(p, "Kontrolle%d" % k, 0.024, 0.02, (MX, y, 0.01), glow("zahl", 1.6), 12)


# --- KASSETTE: 1990er, Pink --------------------------------------------------------------------

def kass_walkman(p):
    """Gebürstetes Alu, pink eloxiertes Band, aufgedruckte Laufwerks-Zeichen: der Walkman von 1992."""
    alu = m("Alu", (0.72, 0.73, 0.76), 1.0, 0.26)
    base(p, alu)
    flats(p, "Schacht", [rrect(0, 0, L, W, 0.09)], Z1, m("Schachtplastik", (0.035, 0.035, 0.042),
                                                         0.0, 0.35))
    pink = m("Pinkeloxal", col("material"), 1.0, 0.3, 0.25)
    flats(p, "Band", [rect(0, 0.4, L - 0.2, 0.05), rect(0, 0.34, L - 0.2, 0.012)], Z2, pink)
    icons = [tri(-0.5, -0.4, 0.09, -1), tri(-0.42, -0.4, 0.09, -1), tri(-0.2, -0.4, 0.1),
             rect(0.03, -0.4, 0.085, 0.085), rect(0.22, -0.4, 0.03, 0.09),
             rect(0.28, -0.4, 0.03, 0.09), tri(0.46, -0.4, 0.09), tri(0.54, -0.4, 0.09)]
    flats(p, "Zeichen", icons, Z2, glow("material", 1.1))
    flats(p, "Rillen", [rect(0.6 + i * 0.026, 0.02, 0.01, 0.5) for i in range(7)], Z2, alu)
    flats(p, "Schlitzfeld", [rect(MX, 0.25 + i * 0.03, 0.06, 0.012) for i in range(8)], Z1,
          m("Tusche", INK, 0.0, 0.6))
    dm.cyl(p, "Batterielicht", 0.016, 0.012, (MX, -0.3, 0.006), glow("material", 2.6), 12)
    slab(p, "Schieber", 0.05, 0.16, 0.014, MX, -0.05, 0.0, pink, 0.01)


def kass_boombox(p):
    """Schwarzes Plastik, Lautsprecher-Lochblech, pinke Ringe und Memphis-Zacken: Ghettoblaster."""
    base(p, bumpy("Plastik", (0.012, 0.012, 0.015), 0.5, 240.0, 0.25))
    holes = []
    for j in range(25):
        for i in range(37):
            x, y = -HX + 0.03 + i * 0.043 + (0.0215 if j % 2 else 0.0), -HY + 0.03 + j * 0.0425
            if abs(x) < HX - 0.02 and abs(y) < HY - 0.02:
                holes.append(disc(x, y, 0.013, 8))
    flats(p, "Lochblech", holes, Z1, m("Blechloch", (0.2, 0.2, 0.23), 1.0, 0.32))
    for s in (-1, 1):
        cx = s * rd.RX
        dm.annulus(p, "Chromring%d" % s, cx, rd.RY, Z2, 0.21, 0.24, rd.chrome(), 48)
        dm.annulus(p, "Pinkring%d" % s, cx, rd.RY, Z3, 0.15, 0.2, glow("material", 1.0), 48)
        dm.annulus(p, "Membran%d" % s, cx, rd.RY, Z2, 0.11, 0.15, m("Membran", (0.02, 0.02, 0.025),
                                                                    0.0, 0.6), 48)
    zig = [line(-0.7 + i * 0.1, -0.42 + (0.06 if i % 2 else 0.0), -0.6 + i * 0.1,
                -0.42 + (0.0 if i % 2 else 0.06), 0.022) for i in range(8)]
    flats(p, "Zacken", zig, Z3, glow("material", 1.3))
    white = m("Druckweiss", (0.85, 0.85, 0.88), 0.0, 0.5, 0.3)
    flats(p, "Konfetti", [tri(0.3, -0.4, 0.09), rect(0.45, -0.37, 0.06, 0.06),
                          disc(0.6, -0.42, 0.035), line(0.02, 0.44, 0.2, 0.4, 0.018),
                          line(-0.3, 0.4, -0.2, 0.46, 0.018), disc(-0.62, 0.42, 0.03),
                          tri(0.55, 0.42, 0.08, -1)], Z3, white)
    flats(p, "Regler", [rect(MX, 0, 0.012, 0.8)], Z1, m("Tusche", INK, 0.0, 0.6))
    for k, y in enumerate((-0.25, 0.05, 0.3)):
        slab(p, "Schieber%d" % k, 0.07, 0.05, 0.016, MX, y, 0.0, glow("material", 0.9) if k == 1
             else rd.chrome(), 0.008)


def kass_hifi(p):
    """Anthrazit-Front, hinterleuchtetes Fenster, Pegel-Ketten, Zählwerk, Tasten: das Hi-Fi-Deck."""
    base(p, m("Anthrazit", (0.045, 0.045, 0.05), 0.9, 0.3))
    flats(p, "Fenster", [rrect(0, 0, L, W, 0.05)], Z1, m("Rauchglas", (0.008, 0.008, 0.01), 0.0,
                                                         0.06, 0.0, 1.0))
    flats(p, "Leuchtfeld", [rrect(0, 0.12, L - 0.16, W - 0.5, 0.04)], Z2,
          m("Rosalicht", col("material"), 0.0, 0.5, 0.45))
    flats(p, "Skalenstriche", [rect(-HX + 0.12 + i * 0.04, 0.12 + (0.2 if i % 5 else 0.17), 0.006,
                                    0.06 if i % 5 else 0.12) for i in range(35)], Z3,
          m("Tusche", INK, 0.0, 0.6))
    for row, y in enumerate((-0.33, -0.39)):
        level = 11 if row == 0 else 8
        lit, dim, peak = [], [], []
        for i in range(16):
            (peak if i >= 13 else lit if i < level else dim).append(
                rect(-0.7 + i * 0.056, y, 0.042, 0.035))
        flats(p, "PegelAn%d" % row, lit, Z2, glow("material", 2.2))
        flats(p, "PegelAus%d" % row, dim, Z2, glow("material", 0.25))
        flats(p, "PegelSpitze%d" % row, peak, Z2, m("Pegelweiss", (0.9, 0.9, 0.9), 0.0, 0.4, 0.4))
    flats(p, "Zaehlfenster", [rect(0.52, -0.36, 0.3, 0.11)], Z2, m("Tusche", INK, 0.0, 0.6))
    flats(p, "Zaehlrollen", [rect(0.43 + i * 0.09, -0.36, 0.075, 0.085) for i in range(3)], Z3,
          m("Rollenweiss", (0.8, 0.8, 0.76), 0.0, 0.5))
    box.text(p, "0 4 7", rd.top(Z4), 0.52, -0.39, 0.075, m("Tusche", INK, 0.0, 0.6), "Zaehler")
    for k in range(5):
        slab(p, "Taste%d" % k, 0.06, 0.19, 0.02, MX, (k - 2) * 0.22, 0.0,
             glow("material", 0.9) if k == 2 else m("Tastensilber", (0.6, 0.6, 0.63), 1.0, 0.3),
             0.012, 0.004)


# --- TONTAFEL: Mesopotamien, Gelb --------------------------------------------------------------

def joints(length, width, course, brick, t):
    out = []
    rows = int(round(width / course))
    for j in range(rows + 1):
        out.append(rect(0, -width / 2 + j * course, length, t))
    for j in range(rows):
        shift = brick * 0.5 if j % 2 else 0.0
        x = -length / 2 + shift
        while x < length / 2 - 0.01:
            if x > -length / 2 + 0.01:
                out.append(rect(x, -width / 2 + (j + 0.5) * course, t, course))
            x += brick
    return out


def ton_lehmziegel(p):
    """Luftgetrocknete Lehmziegel mit Bitumen-Fugen, ein ockergelb bemalter Fries mit Rosetten."""
    base(p, bumpy("Lehm", (0.3, 0.2, 0.11), 0.95, 35.0, 0.9))
    flats(p, "Ziegel", [rect(0, 0, L, W)], Z1, bumpy("Lehmhell", (0.42, 0.3, 0.17), 0.95, 70.0,
                                                    0.7))
    flats(p, "Fries", [rect(0, 0, L, 0.27)], Z2, bumpy("Ocker", (0.78, 0.56, 0.06), 0.8, 90.0,
                                                      0.4))
    flats(p, "Bitumen", joints(L, W, 0.27, 0.41, 0.016), Z3, m("Bitumen", (0.02, 0.016, 0.012),
                                                             0.0, 0.5))
    petals = []
    for i in range(6):
        petals += rosette((i - 2.5) * 0.27, 0.0, 0.085)
    flats(p, "Rosetten", petals, Z3, m("Kalkweiss", (0.9, 0.84, 0.62), 0.0, 0.8))
    flats(p, "Rosettenkerne", [disc((i - 2.5) * 0.27, 0.0, 0.022) for i in range(6)], Z4,
          glow("rune", 1.2))
    flats(p, "Randfries", [rect(MX, 0, 0.06, SW - 0.14)], Z1, bumpy("Ocker", (0.78, 0.56, 0.06),
                                                                    0.8, 90.0, 0.4))
    flats(p, "Randzacken", [tri(MX, (i - 6.5) * 0.075, 0.05) for i in range(14)], Z2,
          m("Bitumen", (0.02, 0.016, 0.012), 0.0, 0.5))


def ton_glasur(p):
    """Glasierte Ziegel wie am Ischtar-Tor: gelbes Feld, lapisblauer Rahmen, Rosetten, ein Stern."""
    lapis = m("Lapisglasur", (0.01, 0.04, 0.22), 0.0, 0.12, 0.0, 1.0)
    yellow = m("Gelbglasur", (0.8, 0.5, 0.03), 0.0, 0.12, 0.15, 1.0)
    base(p, lapis)
    flats(p, "Feld", [rect(0, 0, L, W)], Z1, yellow)
    flats(p, "Fugen", joints(L, W, 0.108, 0.27, 0.007), Z2, m("Glasurfuge", (0.3, 0.17, 0.02), 0.0,
                                                             0.6))
    flats(p, "Rahmen", ring(0, 0, L - 0.12, W - 0.12, 0.11), Z3, lapis)
    petals, cores = [], []
    for i in range(8):
        for s in (-1, 1):
            x, y = (i - 3.5) * 0.19, s * (HY - 0.06)
            petals += rosette(x, y, 0.045)
            cores.append(disc(x, y, 0.012))
    for i in range(4):
        for s in (-1, 1):
            x, y = s * (HX - 0.06), (i - 1.5) * 0.19
            petals += rosette(x, y, 0.045)
            cores.append(disc(x, y, 0.012))
    flats(p, "Rosetten", petals, Z4, m("Glasurweiss", (0.9, 0.86, 0.7), 0.0, 0.15, 0.0, 1.0))
    flats(p, "Rosettenkerne", cores, 0.005, yellow)
    flats(p, "Rund", [disc(0, 0, 0.24, 40)], Z3, lapis)
    flats(p, "Stern", [star(0, 0, 0.21, 0.08, 8)], Z4, glow("rune", 1.0))
    flats(p, "Sternkern", [disc(0, 0, 0.05, 20)], 0.005, lapis)
    flats(p, "Randband", [rect(MX, 0, 0.05, SW - 0.14)], Z1, yellow)


def wedge(x, y, s, a):
    c, d = math.cos(a), math.sin(a)
    pts = [(-0.5 * s, 0.32 * s), (-0.5 * s, -0.32 * s), (0.9 * s, 0.0)]
    return [(x + px * c - py * d, y + px * d + py * c) for px, py in pts]


def ton_sandstein(p):
    """Heller Sandstein mit gemeißeltem Trog, Gold-Einlagen in den Rillen und Keilschrift-Friesen."""
    base(p, bumpy("Sandstein", (0.5, 0.4, 0.27), 0.9, 70.0, 0.55))
    flats(p, "Trog", [rrect(0, 0, L, W, 0.1)], Z1, bumpy("Sandsteintief", (0.27, 0.2, 0.13), 0.95,
                                                        90.0, 0.5))
    gold = m("Blattgold", (1.0, 0.72, 0.16), 1.0, 0.22, 0.25)
    flats(p, "Einlagen", ring(0, 0, L - 0.1, W - 0.1, 0.014) + ring(0, 0, L - 0.62, W - 0.36,
                                                                  0.014), Z2, gold)
    rng = random.Random(11)
    marks = []
    for s in (-1, 1):
        for i in range(4):
            for j in range(11):
                marks.append(wedge(s * (0.56 + (i - 1.5) * 0.055), (j - 5) * 0.062, 0.03,
                                   rng.choice((0.0, -1.57, -0.78, 0.0))))
    flats(p, "Keile", marks, Z2, m("Keilschatten", (0.09, 0.06, 0.035), 0.0, 0.9))
    flats(p, "Sonne", [star(0, 0, 0.2, 0.09, 4), star(0, 0, 0.14, 0.07, 4, math.pi / 4)], Z2, gold)
    flats(p, "Sonnenscheibe", [disc(0, 0, 0.06, 24)], Z3, glow("rune", 1.4))
    for k, y in enumerate((-0.4, 0.0, 0.4)):
        flats(p, "Randsiegel%d" % k, [disc(MX, y, 0.03, 20)], Z1, gold)


# --- SERVICE-MODUL: Labor, Lila ----------------------------------------------------------------

def modul_esd(p):
    """Die lila ESD-Matte des Service-Platzes: Rasterdruck, Lineal, Erdungsknopf, Warnzeichen."""
    base(p, bumpy("Gummimatte", (0.11, 0.07, 0.22), 0.85, 400.0, 0.15))
    fine = m("Rasterlila", (0.26, 0.2, 0.46), 0.0, 0.7)
    lines = [rect(i * 0.09, 0, 0.004 if i % 5 else 0.009, SW - 0.08) for i in range(-9, 10)]
    lines += [rect(0, j * 0.09, SL - 0.08, 0.004 if j % 5 else 0.009) for j in range(-6, 7)]
    flats(p, "Raster", lines, Z1, fine)
    white = m("Mattendruck", (0.8, 0.78, 0.9), 0.0, 0.6, 0.2)
    flats(p, "Lineal", [rect(-HX + 0.04 + i * 0.03, -HY + 0.03 + (0.02 if i % 5 == 0 else 0.0),
                             0.004, 0.07 if i % 5 == 0 else 0.03) for i in range(52)], Z2, white)
    corners = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            corners += [rect(sx * (HX - 0.08), sy * (HY - 0.02), 0.16, 0.012),
                        rect(sx * (HX - 0.006), sy * (HY - 0.09), 0.012, 0.16)]
    flats(p, "Lagewinkel", corners, Z2, glow("gold", 1.2))
    cx, cy = -0.2, 0.0
    tri_pts = [(cx - 0.16, cy - 0.12), (cx + 0.16, cy - 0.12), (cx, cy + 0.15)]
    flats(p, "Warndreieck", [line(*tri_pts[i], *tri_pts[(i + 1) % 3], 0.022) for i in range(3)],
          Z2, glow("gold", 0.9))
    flats(p, "Warnblitz", [[(cx + 0.02, cy + 0.08), (cx - 0.05, cy - 0.01), (cx - 0.005, cy - 0.01),
                            (cx - 0.02, cy - 0.09), (cx + 0.05, cy + 0.01), (cx + 0.005, cy + 0.01)]],
          Z2, glow("gold", 0.9))
    ex, ey = 0.42, -0.3
    flats(p, "Erdzeichen", [rect(ex, ey + 0.06, 0.008, 0.08), rect(ex, ey + 0.02, 0.12, 0.01),
                            rect(ex, ey - 0.01, 0.08, 0.01), rect(ex, ey - 0.04, 0.04, 0.01)], Z2,
          white)
    dm.cyl(p, "Erdknopf", 0.04, 0.012, (ex + 0.16, ey, 0.006), rd.chrome(), 24)
    dm.cyl(p, "Erdnippel", 0.018, 0.022, (ex + 0.16, ey, 0.011), rd.chrome(), 16)


def modul_lochraster(p):
    """Reinraum: eloxierte Lochraster-Platte, lila eloxierte Anschlagwinkel, Lichtfugen."""
    base(p, m("Eloxal", (0.7, 0.7, 0.74), 1.0, 0.34))
    holes, rims = [], []
    for i in range(-6, 7):
        for j in range(-4, 5):
            if abs(i) == 5 and abs(j) == 3:
                continue
            holes.append(disc(i * 0.135, j * 0.135, 0.02, 12))
            rims.append(disc(i * 0.135, j * 0.135, 0.03, 12))
    flats(p, "Senkungen", rims, Z1, m("Senkung", (0.4, 0.4, 0.43), 1.0, 0.25))
    flats(p, "Gewinde", holes, Z2, m("Tusche", INK, 0.0, 0.6))
    violet = m("Violetteloxal", col("gold"), 1.0, 0.3, 0.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (HX - 0.14), sy * (HY - 0.14)
            slab(p, "WinkelX%d%d" % (sx, sy), 0.24, 0.05, 0.014, x + sx * 0.04, y + sy * 0.1, 0.0,
                 violet, 0.01)
            slab(p, "WinkelY%d%d" % (sx, sy), 0.05, 0.24, 0.014, x + sx * 0.135, y + sy * 0.005,
                 0.0, violet, 0.01)
    flats(p, "Lichtfugen", [rect(0, s * 0.2025, L - 0.5, 0.014) for s in (-1, 1)], Z2,
          glow("gold", 1.8))
    flats(p, "Gravur", [rect(-HX + 0.05 + i * 0.027, -HY + 0.02, 0.003, 0.03 if i % 5 else 0.05)
                        for i in range(57)], Z1, m("Gravur", (0.25, 0.25, 0.28), 1.0, 0.4))


def modul_backplane(p):
    """Die Rückwand-Platine eines Großrechners: lila Lötstopplack, goldene Bus-Bahnen, Sockel."""
    base(p, m("Loetstopp", (0.07, 0.015, 0.19), 0.0, 0.2, 0.0, 1.0))
    gold = m("Leitergold", (0.9, 0.62, 0.18), 1.0, 0.3, 0.12)
    traces, pads = [], []
    for i in range(16):
        y0 = (i - 7.5) * 0.034 + 0.1
        y1 = (i - 7.5) * 0.058 + 0.1
        xk = -0.1 + abs(i - 7.5) * 0.02
        traces += [line(-0.74, y0, xk, y0, 0.012), line(xk, y0, xk + abs(y1 - y0), y1, 0.012),
                   line(xk + abs(y1 - y0), y1, 0.62, y1, 0.012)]
        pads += [disc(-0.74, y0, 0.014, 10), disc(0.62, y1, 0.02, 10)]
    flats(p, "Bus", traces, Z1, gold)
    flats(p, "Augen", pads, Z2, gold)
    flats(p, "Bohrungen", [disc(0.62, (i - 7.5) * 0.058 + 0.1, 0.008, 8) for i in range(16)], Z3,
          m("Tusche", INK, 0.0, 0.6))
    silk = m("Bestueckungsdruck", (0.85, 0.83, 0.92), 0.0, 0.6, 0.15)
    sx, sy = -0.25, -0.41
    flats(p, "Sockelumriss", ring(sx, sy, 0.86, 0.16, 0.008) + [disc(sx - 0.43, sy, 0.025, 12)], Z1,
          silk)
    flats(p, "Sockelaugen", [disc(sx - 0.38 + i * 0.069, sy + s * 0.05, 0.014, 10)
                             for i in range(12) for s in (-1, 1)], Z2, gold)
    rng = random.Random(4)
    flats(p, "Durchsteiger", [disc(rng.uniform(0.2, 0.74), rng.uniform(-0.5, -0.3), 0.009, 8)
                              for _ in range(26)], Z2, gold)
    flats(p, "Druckzeilen", [rect(0.45, -0.25, 0.3, 0.008), rect(-0.6, 0.47, 0.22, 0.008),
                             rect(0.3, 0.47, 0.4, 0.008)], Z1, silk)
    for kx in (-1, 1):
        for ky in (-1, 1):
            dm.annulus(p, "Befestigung%d%d" % (kx, ky), kx * (HX - 0.05), ky * (HY - 0.05), Z2,
                       0.02, 0.04, gold, 20)
    flats(p, "Lichtbahn", [line(-0.74, 0.44, -0.2, 0.44, 0.012)], Z2, glow("gold", 2.0))


# --- Bühne -------------------------------------------------------------------------------------

SKIP = {"Bett", "Muldenboden", "Trog"}


def face(design, reader):
    def fn(parent, loaded):
        design(parent)
        plate, rounded = rd.plate, led.rounded_box

        def filtered(parent_, name, *args, **kwargs):
            if name in SKIP:
                return None
            return rounded(parent_, name, *args, **kwargs)

        rd.plate = lambda *a, **k: None
        led.rounded_box = filtered
        try:
            reader(parent, loaded)
        finally:
            rd.plate, led.rounded_box = plate, rounded
    return fn


rd.READERS.clear()
rd.READERS["flaeche_loch"] = [("L1 · TABELLIERER 1934", face(loch_tabellierer, rd.punch_fuehlhebel)),
                              ("L2 · BAKELIT", face(loch_bakelit, rd.punch_fuehlhebel)),
                              ("L3 · WERKBANK 1942", face(loch_werkbank, rd.punch_fuehlhebel))]
rd.READERS["flaeche_kassette"] = [("K1 · WALKMAN", face(kass_walkman, rd.cassette_klappe)),
                                  ("K2 · BOOMBOX", face(kass_boombox, rd.cassette_klappe)),
                                  ("K3 · HI-FI-DECK", face(kass_hifi, rd.cassette_klappe))]
rd.READERS["flaeche_ton"] = [("T1 · LEHMZIEGEL", face(ton_lehmziegel, rd.clay_rollsiegel)),
                             ("T2 · GLASUR", face(ton_glasur, rd.clay_rollsiegel)),
                             ("T3 · SANDSTEIN & GOLD", face(ton_sandstein, rd.clay_rollsiegel))]
rd.READERS["flaeche_modul"] = [("M1 · ESD-MATTE", face(modul_esd, rd.module_brenner)),
                               ("M2 · LOCHRASTER", face(modul_lochraster, rd.module_brenner)),
                               ("M3 · BACKPLANE", face(modul_backplane, rd.module_brenner))]


# --- Zweite Runde: die MULDE - die Karte sinkt in ihre Seite, die Fläche ist ruhiger ------------

def bezel(p, h, material, key, energy=1.4):
    """Der Rand der Mulde: so hoch, daß die Karte ein Stück in der Seite versinkt."""
    gx, gy = (SL - L - 0.03) * 0.5, (SW - W - 0.03) * 0.5
    for s in (-1, 1):
        slab(p, "RandLang%d" % s, SL, gy, h, 0, s * (SW * 0.5 - gy * 0.5), 0.0, material, 0.0,
             0.004)
        slab(p, "RandKurz%d" % s, gx, SW - gy * 2.0, h, s * (SL * 0.5 - gx * 0.5), 0, 0.0,
             material, 0.0, 0.004)
    flats(p, "Lippe", ring(0, 0, L + 0.045, W + 0.045, 0.014), h + 0.0006, glow(key, energy))


def mulde_loch(p):
    """Lochkarte: schwarzer Lack, grünes Email am Muldenboden, die Elfenbein-Skala am Fuß."""
    lack = bumpy("Schrumpflack", (0.012, 0.012, 0.014), 0.35, 160.0, 0.5, 0.0, 0.6)
    base(p, lack)
    flats(p, "Emailfeld", [rect(0, 0, L + 0.03, W + 0.03)], Z1,
          m("Emailgruen", (0.012, 0.1, 0.04), 0.0, 0.2, 0.0, 1.0))
    flats(p, "Skala", [rect(0, -HY + 0.07, L - 0.06, 0.08)], Z2, m("Elfenbein", lin("#e6d9b0"),
                                                                 0.0, 0.5))
    flats(p, "Teilung", [rect(-HX + 0.03 + (i + 0.5) * (L - 0.06) / 20, -HY + 0.07, 0.005,
                              0.06 if i % 5 == 0 else 0.03) for i in range(20)], Z3,
          m("Tusche", INK, 0.0, 0.6))
    bezel(p, 0.05, lack, "zahl")
    dm.cyl(p, "Juwel", 0.022, 0.02, (SL * 0.5 - 0.037, 0, 0.055), glow("zahl", 2.2), 8)


def mulde_kassette(p):
    """Kassette: Alu-Rand, dunkler Schacht, darin nur die pinken Laufwerks-Zeichen."""
    alu = m("Alu", (0.72, 0.73, 0.76), 1.0, 0.26)
    base(p, alu)
    flats(p, "Schacht", [rect(0, 0, L + 0.03, W + 0.03)], Z1,
          m("Schachtplastik", (0.035, 0.035, 0.042), 0.0, 0.35))
    icons = [tri(-0.5, -0.38, 0.1, -1), tri(-0.41, -0.38, 0.1, -1), tri(-0.2, -0.38, 0.11),
             rect(0.03, -0.38, 0.095, 0.095), rect(0.22, -0.38, 0.034, 0.1),
             rect(0.285, -0.38, 0.034, 0.1), tri(0.46, -0.38, 0.1), tri(0.55, -0.38, 0.1)]
    flats(p, "Zeichen", icons, Z2, glow("material", 1.1))
    bezel(p, 0.075, alu, "material")


def mulde_ton(p):
    """Tontafel: ein Lehmziegel-Rand, der Muldenboden ein ockergelber Fries mit vier Rosetten."""
    lehm = bumpy("Lehm", (0.3, 0.2, 0.11), 0.95, 35.0, 0.9)
    base(p, lehm)
    flats(p, "Boden", [rect(0, 0, L + 0.03, W + 0.03)], Z1,
          bumpy("Lehmhell", (0.42, 0.3, 0.17), 0.95, 70.0, 0.7))
    flats(p, "Fries", [rect(0, 0, L + 0.03, 0.3)], Z2, bumpy("Ocker", (0.78, 0.56, 0.06), 0.8,
                                                           90.0, 0.4))
    petals = []
    for i in range(4):
        petals += rosette((i - 1.5) * 0.4, 0.0, 0.1)
    flats(p, "Rosetten", petals, Z3, m("Kalkweiss", (0.9, 0.84, 0.62), 0.0, 0.8))
    flats(p, "Rosettenkerne", [disc((i - 1.5) * 0.4, 0.0, 0.026) for i in range(4)], Z4,
          glow("rune", 1.2))
    bezel(p, 0.085, lehm, "rune")


def mulde_modul(p):
    """Service-Modul: lila Matte als Rand, am Boden ein grobes Raster, Lagewinkel, ein Warnzeichen."""
    matte = bumpy("Gummimatte", (0.11, 0.07, 0.22), 0.85, 400.0, 0.15)
    base(p, matte)
    flats(p, "Boden", [rect(0, 0, L + 0.03, W + 0.03)], Z1, m("Mattendunkel", (0.05, 0.03, 0.11),
                                                             0.0, 0.8))
    lines = [rect(i * 0.18, 0, 0.006, W) for i in range(-4, 5)]
    lines += [rect(0, j * 0.18, L, 0.006) for j in range(-2, 3)]
    flats(p, "Raster", lines, Z2, m("Rasterlila", (0.26, 0.2, 0.46), 0.0, 0.7))
    corners = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            corners += [rect(sx * (HX - 0.1), sy * (HY - 0.03), 0.16, 0.014),
                        rect(sx * (HX - 0.027), sy * (HY - 0.1), 0.014, 0.16)]
    flats(p, "Lagewinkel", corners, Z3, glow("gold", 1.2))
    cx, cy = 0.0, 0.0
    pts = [(cx - 0.17, cy - 0.13), (cx + 0.17, cy - 0.13), (cx, cy + 0.16)]
    flats(p, "Warndreieck", [line(*pts[i], *pts[(i + 1) % 3], 0.024) for i in range(3)], Z3,
          glow("gold", 0.9))
    flats(p, "Warnblitz", [[(cx + 0.02, cy + 0.07), (cx - 0.05, cy - 0.02), (cx - 0.005, cy - 0.02),
                            (cx + 0.005, cy)], [(cx - 0.005, cy - 0.02), (cx - 0.02, cy - 0.1),
                                                (cx + 0.05, cy), (cx + 0.005, cy)]], Z3,
          glow("gold", 0.9))
    bezel(p, 0.07, matte, "gold")


MULDEN = [("LOCHKARTE", face(mulde_loch, rd.punch_fuehlhebel)),
          ("KASSETTE", face(mulde_kassette, rd.cassette_klappe)),
          ("TONTAFEL", face(mulde_ton, rd.clay_rollsiegel)),
          ("SERVICE-MODUL", face(mulde_modul, rd.module_brenner))]
MULDEN_X = (-3.15, -1.05, 1.05, 3.15)


def view_mulden(flat, readers=True):
    cam, aim = dm.empty_stage()
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = 2600, 1100
    spread = 0.78 if flat else 1.1
    for row, loaded in enumerate((False, True)):
        y = spread if row == 0 else -spread
        for (title, fn), x in zip(MULDEN, MULDEN_X):
            text = title + (" · belegt" if loaded else " · leer")
            dm.build(lambda p, fn=fn, loaded=loaded: fn(p, loaded), text, (x, y, 0.101))
            rd.ms.label(text, x, y - 0.74, 0.075)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 8.6
        aim.location = (0, -0.05, 0)
        cam.location = (0, -0.05, 12)
    else:
        aim.location = (0, -0.25, 0.0)
        cam.location = (0.0, -6.4, 5.4)
        cam.data.lens = 31


if __name__ == "__main__":
    os.makedirs(rd.OUT, exist_ok=True)
    argv = sys.argv[sys.argv.index("--") + 1:]
    only = argv[1].split(",") if len(argv) > 1 else []
    for name, flat in (("mulde_draufsicht", True), ("mulde_schraeg", False)):
        if only and name not in only:
            continue
        view_mulden(flat)
        bpy.context.scene.eevee.taa_render_samples = 48
        bpy.context.scene.render.filepath = os.path.join(rd.OUT, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("gerendert", name, flush=True)
    for name in rd.READERS:
        for suffix, flat in (("_draufsicht", True), ("_schraeg", False)):
            if only and name + suffix not in only:
                continue
            rd.view(name, flat)
            bpy.context.scene.eevee.taa_render_samples = 48
            bpy.context.scene.render.filepath = os.path.join(rd.OUT, name + suffix + ".png")
            bpy.ops.render.render(write_still=True)
            print("gerendert", name + suffix, flush=True)
    print("ok")
