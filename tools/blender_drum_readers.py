"""Fumble: die LESER der Walze, je Datenträger drei Entwürfe (2026-11-19). Jede Kachel ist die
Oberseite EINER Scheibe (Karte samt Luft); oben leer, unten mit aufgelegter Karte.
  lochkarte: buersten | lichttisch | stiftfeld     kassette: deck | klappe | kopfschlitten
  tontafel:  taster | lichtschnitt | rollsiegel    modul:    kontaktleiste | nadelbett | brenner
  lochneu1/2 (zweite Runde): lichtvorhang | fuehlhebel | sternraeder | lesekopf | saugleiste

Aufruf (kopflos):
  blender -b -P tools/blender_drum_readers.py -- <ausgabe-ordner> [ansicht,ansicht]
"""
import bpy, math, os, random, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media_real as rm

dm, ms, led, box = rm.dm, rm.ms, rm.led, rm.box
glow, col, top, seg = rm.glow, rm.col, rm.top, rm.seg
L, W, C = rm.L, rm.W, rm.C
OUT = rm.OUT
SL, SW = L * 1.11, W * 1.13
HALF_PI = math.pi * 0.5


def steel():
    return led.mat("Walzenstahl", (0.045, 0.048, 0.056), 0.6, 0.45)


def dark_metal():
    return led.mat("Lesermetall", (0.1, 0.105, 0.12), 0.8, 0.4)


def chrome():
    return led.mat("Chrom2", (0.9, 0.9, 0.92), 1.0, 0.05)


def brass():
    return led.mat("Messing", (0.75, 0.55, 0.22), 1.0, 0.3)


def plate(parent, key):
    """Die Scheiben-Oberseite: Stahl mit feiner Leuchtfuge in der Sortenfarbe."""
    led.rounded_box(parent, "Scheibe", (SL, SW, 0.1), (0, 0, -0.05), steel(), 0.03, 0.006)
    hx, hy = SL * 0.5 - 0.02, SW * 0.5 - 0.02
    for k, (a, b) in enumerate((((-hx, -hy), (hx, -hy)), ((hx, -hy), (hx, hy)),
                                ((hx, hy), (-hx, hy)), ((-hx, hy), (-hx, -hy)))):
        seg(parent, "Fuge%d" % k, top(0.0002), a[0], a[1], b[0], b[1], 0.008, glow(key, 0.9))


def rod(parent, name, r, length, loc, material, along="y", verts=20):
    o = dm.cyl(parent, name, r, length, loc, material, verts)
    o.rotation_euler = (HALF_PI, 0, 0) if along == "y" else (0, HALF_PI, 0)
    return o


def card_on(parent, fn, lift):
    bpy.ops.object.empty_add(location=(0, 0, lift))
    sub = bpy.context.active_object
    sub.parent = parent
    fn(sub)


def rails(parent, material, h=0.03, y=None):
    y = (W * 0.5 + 0.02) if y is None else y
    for s in (-1, 1):
        led.rounded_box(parent, "Schiene%d" % s, (L + 0.06, 0.03, h), (0, s * y, h * 0.5),
                        material, 0.0, 0.004)


# --- LOCHKARTE ---------------------------------------------------------------------------------

def punch_card(p):
    ms.punch_card(p, 4, "zahl")


def punch_buersten(parent, loaded):
    """BÜRSTEN: Kontaktwalze im Bett, darüber eine Brücke mit einer Reihe Abtast-Bürsten."""
    key = "zahl"
    plate(parent, key)
    rails(parent, dark_metal(), 0.05)
    led.rounded_box(parent, "Bett", (L, W, 0.008), (0, 0, 0.004), led.DARK, 0.02, 0.0)
    rod(parent, "Kontaktwalze", 0.03, W - 0.04, (-0.7, 0, 0.012), brass())
    for k, x in enumerate((0.45, 0.7)):
        rod(parent, "Vorschub%d" % k, 0.022, W - 0.04, (x, 0, 0.012),
            led.mat("Gummi", (0.02, 0.02, 0.022), 0.0, 0.8))
    led.rounded_box(parent, "Bruecke", (0.07, SW - 0.04, 0.03), (-0.7, 0, 0.115), dark_metal(),
                    0.008, 0.006)
    for s in (-1, 1):
        led.rounded_box(parent, "Pfeiler%d" % s, (0.07, 0.035, 0.1), (-0.7, s * (SW * 0.5 - 0.04),
                                                                      0.05), dark_metal(), 0.006,
                        0.004)
    for k in range(12):
        y = (k - 5.5) * 0.08
        dm.cyl(parent, "Buerste%d" % k, 0.006, 0.06, (-0.7, y, 0.075), brass(), 8)
        box.dot(parent, "Lampe%d" % k, top(0.1305), -0.7, y, 0.009, glow(key, 2.2 if loaded else
                                                                         0.5))
    if loaded:
        card_on(parent, punch_card, 0.016)


def punch_lichttisch(parent, loaded):
    """LICHTTISCH: das Bett leuchtet und scheint durch die Stanzungen; ein Paßklotz an der
    gekappten Ecke läßt die Karte nur richtig herum hinein."""
    key = "zahl"
    plate(parent, key)
    led.rounded_box(parent, "Tischrahmen", (L + 0.07, W + 0.07, 0.03), (0, 0, 0.015),
                    dark_metal(), 0.03, 0.006)
    led.rounded_box(parent, "Leuchtfeld", (L - 0.02, W - 0.02, 0.004), (0, 0, 0.031),
                    glow(key, 1.4 if loaded else 0.7), 0.02, 0.0)
    pts = [(-0.74 + i * 0.078, -0.44 + j * 0.098, 0.034) for i in range(20) for j in range(10)]
    dm.dots(parent, "Fotozellen", pts, 0.008, led.DARK)
    led.rounded_box(parent, "Passklotz", (0.16, 0.16, 0.05), (-L * 0.5 - 0.005, W * 0.5 + 0.005,
                                                              0.055), dark_metal(), 0.0, 0.004
                    ).rotation_euler = (0, 0, math.radians(45))
    for k, (x, y) in enumerate(((0.83, 0.3), (0.83, -0.3), (0.0, -0.56), (-0.4, 0.56))):
        dm.cyl(parent, "Anschlag%d" % k, 0.02, 0.05, (x, y, 0.055), chrome(), 16)
    if loaded:
        card_on(parent, punch_card, 0.034)


def punch_stiftfeld(parent, loaded):
    """STIFTFELD: je Lochposition ein gefederter Fühlstift; zwei Federklammern halten die Karte."""
    key = "zahl"
    plate(parent, key)
    led.rounded_box(parent, "Bett", (L + 0.04, W + 0.04, 0.02), (0, 0, 0.01), dark_metal(), 0.02,
                    0.004)
    pts = [(-0.74 + i * 0.078, -0.44 + j * 0.098, 0.026) for i in range(20) for j in range(10)]
    dm.dots(parent, "Fuehlstifte", pts, 0.016, led.mat("Stiftmessing", (0.75, 0.55, 0.22), 0.3, 0.4, 0.5))
    for i in range(20):
        seg(parent, "Spaltenleiter%d" % i, top(0.0203), -0.74 + i * 0.078, -0.5, -0.74 + i * 0.078,
            0.5, 0.004, glow(key, 0.9 if loaded else 0.3))
    for s in (-1, 1):
        led.rounded_box(parent, "Klammerfuss%d" % s, (0.1, 0.3, 0.05), (s * (L * 0.5 + 0.03), 0,
                                                                        0.025), dark_metal(), 0.01,
                        0.004)
        led.rounded_box(parent, "Klammer%d" % s, (0.12, 0.26, 0.012),
                        (s * (L * 0.5 - (0.02 if loaded else -0.03)), 0, 0.08), chrome(), 0.02,
                        0.004)
    if loaded:
        card_on(parent, punch_card, 0.034)


# --- KASSETTE ----------------------------------------------------------------------------------

RX, RY = 0.5, 0.345


def cassette_card(p):
    rm.cassette_klassik(p, 4)


def spindles(parent, key, loaded, z=0.0, h=0.07):
    for s in (-1, 1):
        dm.cyl(parent, "Teller%d" % s, 0.11, 0.008, (s * RX, RY, z + 0.004), dark_metal(), 32)
        dm.cyl(parent, "Dorn%d" % s, 0.034, h, (s * RX, RY, z + h * 0.5), chrome(), 20)
        for k in range(3):
            a = k * math.tau / 3
            led.rounded_box(parent, "Mitnehmer%d_%d" % (s, k), (0.03, 0.012, h * 0.8),
                            (s * RX + math.cos(a) * 0.04, RY + math.sin(a) * 0.04,
                             z + h * 0.45), chrome(), 0.0, 0.002).rotation_euler = (0, 0, a)
        dm.annulus(parent, "Tellerlicht%d" % s, s * RX, RY, z + 0.009, 0.085, 0.1,
                   glow(key, 1.8 if loaded else 0.5), 32)


def head_block(parent, key, loaded, y, z=0.0):
    """Tonkopf zwischen zwei Andruckrollen und Capstan-Wellen an der Kopfpartie der Kassette."""
    led.rounded_box(parent, "Kopftraeger", (0.9, 0.11, 0.05), (0, y, z + 0.025), dark_metal(), 0.02,
                    0.004)
    led.rounded_box(parent, "Tonkopf", (0.11, 0.07, 0.07), (0, y + 0.03, z + 0.06), chrome(), 0.012,
                    0.01)
    box.rect(parent, "Kopfspalt", box.frame((0, y + 0.0655, z + 0.06), (1, 0, 0), (0, 0, 1)),
             -0.004, -0.02, 0.004, 0.02, glow(key, 3.0 if loaded else 0.6))
    for s in (-1, 1):
        dm.cyl(parent, "Andruckrolle%d" % s, 0.04, 0.06, (s * 0.3, y + 0.02, z + 0.07),
               led.mat("Gummi", (0.02, 0.02, 0.022), 0.0, 0.8), 24)
        dm.cyl(parent, "Capstan%d" % s, 0.012, 0.1, (s * 0.47, y + 0.14, z + 0.05), chrome(), 12)


def cassette_deck(parent, loaded):
    """DECK: eine Mulde mit zwei Mitnehmer-Dornen, Capstan-Wellen und festem Tonkopf."""
    key = "material"
    plate(parent, key)
    led.frame_ring(parent, "Mulde", (L + 0.08, W + 0.08), (L + 0.016, W + 0.016), 0.03, 0.06,
                   dark_metal(), 0.05, y=0)
    led.rounded_box(parent, "Muldenboden", (L, W, 0.006), (0, 0, 0.003), led.DARK, 0.05, 0.0)
    spindles(parent, key, loaded)
    head_block(parent, key, loaded, -W * 0.5 - 0.02)
    if loaded:
        card_on(parent, cassette_card, 0.008)


def cassette_klappe(parent, loaded):
    """KLAPPE: das Deck unter einer Klarsicht-Klappe; ihr Rahmen leuchtet, sobald sie zu ist."""
    key = "material"
    plate(parent, key)
    led.rounded_box(parent, "Muldenboden", (L, W, 0.006), (0, 0, 0.003), led.DARK, 0.05, 0.0)
    spindles(parent, key, loaded)
    head_block(parent, key, loaded, -W * 0.5 - 0.02)
    rod(parent, "Scharnier", 0.022, W + 0.08, (-L * 0.5 - 0.045, 0, 0.03), chrome())
    bpy.ops.object.empty_add(location=(-L * 0.5 - 0.045, 0, 0.03))
    lid = bpy.context.active_object
    lid.parent = parent
    zl = 0.13
    led.frame_ring(lid, "Klappenrahmen", (L + 0.07, W + 0.07), (L - 0.02, W - 0.02), zl, 0.014,
                   glow(key, 2.0 if loaded else 0.5), 0.05, y=0)
    for o in lid.children:
        o.location.x += L * 0.5 + 0.045
    glass = led.rounded_box(lid, "Klappenglas", (L, W, 0.004), (L * 0.5 + 0.045, 0, zl),
                            led.mat("Klappenglas", (0.7, 0.75, 0.85), 0.0, 0.03, 0.0, 0.06,
                                    clearcoat=1.0), 0.05, 0.0)
    led.rounded_box(lid, "Griff", (0.05, 0.3, 0.02), (L + 0.09, 0, zl), chrome(), 0.01, 0.006)
    if not loaded:
        lid.rotation_euler = (0, math.radians(-32), 0)
    if loaded:
        card_on(parent, cassette_card, 0.008)


def cassette_schlitten(parent, loaded):
    """KOPFSCHLITTEN: nur zwei Dorne und zwei Paßstifte; der Tonkopf fährt auf einem Schlitten
    an die Kassette heran, sobald sie liegt."""
    key = "material"
    plate(parent, key)
    led.rounded_box(parent, "Auflage", (L, W, 0.006), (0, 0, 0.003), led.DARK, 0.05, 0.0)
    spindles(parent, key, loaded)
    for s in (-1, 1):
        dm.cyl(parent, "Passstift%d" % s, 0.022, 0.07, (s * 0.6, -0.43, 0.035), chrome(), 16)
        led.rounded_box(parent, "Fuehrung%d" % s, (0.03, 0.26, 0.016), (s * 0.5, -W * 0.5 - 0.04,
                                                                        0.008), chrome(), 0.0, 0.004)
    back = -W * 0.5 - (0.02 if loaded else 0.085)
    led.rounded_box(parent, "Schlitten", (1.1, 0.1, 0.03), (0, back, 0.03), dark_metal(), 0.02,
                    0.006)
    led.rounded_box(parent, "Tonkopf", (0.11, 0.07, 0.07), (0, back + 0.03, 0.07), chrome(), 0.012,
                    0.01)
    for s in (-1, 1):
        dm.cyl(parent, "Andruckrolle%d" % s, 0.04, 0.06, (s * 0.3, back + 0.02, 0.075),
               led.mat("Gummi", (0.02, 0.02, 0.022), 0.0, 0.8), 24)
        box.dot(parent, "Schlittenlicht%d" % s, top(0.0455), s * 0.5, back, 0.014,
                glow(key, 3.0 if loaded else 0.5))
    if loaded:
        card_on(parent, cassette_card, 0.008)


# --- TONTAFEL ----------------------------------------------------------------------------------

def clay_card(p):
    rm.tablet_keilschrift(p, 4)


def cradle(parent, material, h=0.04):
    for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1))):
        led.rounded_box(parent, "Eckklotz%d" % k, (0.2, 0.16, h), (sx * (L * 0.5 - 0.06),
                                                                   sy * (W * 0.5 - 0.04), h * 0.5),
                        material, 0.03, 0.01)


def clay_taster(parent, loaded):
    """TASTER: eine Brücke fährt auf zwei Schienen über die Tafel, ihre Nadeln fühlen die Keile."""
    key = "rune"
    plate(parent, key)
    stone = dm.bumpy("Leserstein", (0.16, 0.14, 0.12), 0.9, 60.0, 0.2)
    led.rounded_box(parent, "Sandbett", (L, W, 0.012), (0, 0, 0.006),
                    dm.bumpy("Sand", (0.32, 0.26, 0.17), 0.95, 220.0, 0.3), 0.12, 0.0)
    cradle(parent, stone, 0.03)
    for s in (-1, 1):
        rod(parent, "Laufschiene%d" % s, 0.014, L + 0.1, (0, s * (SW * 0.5 - 0.035), 0.19),
            chrome(), "x", 12)
        for x in (-1, 1):
            led.rounded_box(parent, "Stuetze%d_%d" % (s, x), (0.04, 0.04, 0.19),
                            (x * (L * 0.5 + 0.03), s * (SW * 0.5 - 0.035), 0.095), dark_metal(),
                            0.006, 0.004)
    gx = -0.3 if loaded else -0.72
    led.rounded_box(parent, "Bruecke", (0.06, SW - 0.02, 0.03), (gx, 0, 0.19), dark_metal(), 0.008,
                    0.006)
    for k in range(15):
        y = (k - 7) * 0.065
        dm.cyl(parent, "Nadel%d" % k, 0.004, 0.05, (gx, y, 0.155), chrome(), 6)
        box.dot(parent, "Nadellicht%d" % k, top(0.2055), gx, y, 0.008, glow(key, 2.4 if loaded
                                                                           else 0.5))
    if loaded:
        card_on(parent, clay_card, 0.012)


def clay_lichtschnitt(parent, loaded):
    """LICHTSCHNITT: zwei Pfosten spannen eine Lichtlinie über die Tafel, die das Relief abtastet."""
    key = "rune"
    plate(parent, key)
    stone = dm.bumpy("Leserstein", (0.16, 0.14, 0.12), 0.9, 60.0, 0.2)
    led.rounded_box(parent, "Steinwiege", (L + 0.06, W + 0.06, 0.02), (0, 0, 0.01), stone, 0.12,
                    0.006)
    cradle(parent, stone, 0.045)
    lx = -0.35 if loaded else -0.76
    for s in (-1, 1):
        y = s * (SW * 0.5 - 0.03)
        led.rounded_box(parent, "Pfosten%d" % s, (0.05, 0.04, 0.2), (lx, y, 0.1), dark_metal(),
                        0.008, 0.004)
        box.rect(parent, "Auge%d" % s, box.frame((lx, y - s * 0.021, 0.17), (1, 0, 0), (0, 0, 1)),
                 -0.012, -0.012, 0.012, 0.012, glow(key, 4.0))
        rod(parent, "Schlittenstange%d" % s, 0.01, L + 0.06, (0, y, 0.01), chrome(), "x", 10)
    gain = 1.0 if loaded else 0.35
    led.rounded_box(parent, "Lichtebene", (0.003, SW - 0.1, 0.16), (lx, 0, 0.1),
                    led.mat("Lichtebene_" + key, col(key), 0.0, 0.5, 0.8 * gain, 0.1), 0.0, 0.0)
    seg(parent, "Lichtlinie", top((0.012 + 0.122) if loaded else 0.021), lx, -W * 0.5 + 0.03, lx,
        W * 0.5 - 0.03, 0.01, glow(key, 4.0 * gain))
    if loaded:
        card_on(parent, clay_card, 0.02)


def clay_rollsiegel(parent, loaded):
    """ROLLSIEGEL: eine gravierte Walze rollt auf zwei Schienen über die Tafel und liest im Rollen."""
    key = "rune"
    plate(parent, key)
    stone = dm.bumpy("Leserstein", (0.16, 0.14, 0.12), 0.9, 60.0, 0.2)
    led.rounded_box(parent, "Trog", (L + 0.06, W + 0.06, 0.02), (0, 0, 0.01), stone, 0.12, 0.006)
    rails(parent, brass(), 0.17, SW * 0.5 - 0.03)
    rx = -0.25 if loaded else -0.72
    zr = 0.012 + 0.12 + 0.062 if loaded else 0.19
    roller = rod(parent, "Siegelwalze", 0.06, W - 0.02, (rx, 0, zr),
                 dm.bumpy("Siegelstein", (0.1, 0.085, 0.075), 0.6, 30.0, 0.5), "y", 40)
    rod(parent, "Achse", 0.014, SW - 0.02, (rx, 0, zr), chrome())
    for k in range(9):
        y = (k - 4) * 0.11
        rod(parent, "Siegelband%d" % k, 0.0615, 0.012, (rx, y, zr), glow(key, 2.2 if loaded else
                                                                         0.5), "y", 40)
    if loaded:
        card_on(parent, clay_card, 0.02)


# --- SERVICE-MODUL -----------------------------------------------------------------------------

def module_card(p):
    rm.modul_deko_fein(p, 4, "repair", True, "bestueckt")


def standoffs(parent, h):
    for k, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1))):
        dm.cyl(parent, "Abstand%d" % k, 0.03, h, (sx * 0.7, sy * 0.46, h * 0.5), brass(), 6)


def edge_socket(parent, key, loaded, z, x=None, width=None):
    """Die Steckleiste am Fuß: ein Schlitz mit Federkontakten, in den die Kontaktleiste greift."""
    x = (L * 0.5 + 0.035) if x is None else x
    width = (W - 0.08) if width is None else width
    led.rounded_box(parent, "Leiste", (0.11, width, z + 0.05), (x, 0, (z + 0.05) * 0.5),
                    led.mat("Leistenkunststoff", (0.02, 0.022, 0.03), 0.0, 0.5), 0.01, 0.004)
    for k in range(11):
        y = (k - 5) * 0.085
        box.rect(parent, "Feder%d" % k, top(z + 0.0505), x - 0.05, y - 0.02, x + 0.0, y + 0.02,
                 rm.gold_mat())
    seg(parent, "Leistenlicht", top(z + 0.0508), x + 0.035, -width * 0.5 + 0.03, x + 0.035,
        width * 0.5 - 0.03, 0.01, glow(key, 3.0 if loaded else 0.5))


def module_kontaktleiste(parent, loaded):
    """KONTAKTLEISTE: das Modul steckt mit seiner Goldkante in einer Leiste; zwei Auswerfer-Hebel
    rasten an den Ecken ein."""
    key = "gold"
    plate(parent, key)
    standoffs(parent, 0.04)
    rails(parent, dark_metal(), 0.06)
    edge_socket(parent, key, loaded, 0.04)
    for s in (-1, 1):
        lever = led.rounded_box(parent, "Hebel%d" % s, (0.16, 0.035, 0.035),
                                (L * 0.5 + 0.0, s * (W * 0.5 + 0.02), 0.1), chrome(), 0.01, 0.006)
        lever.rotation_euler = (0, 0, 0 if loaded else s * math.radians(-40))
    if loaded:
        card_on(parent, module_card, 0.04)


def module_nadelbett(parent, loaded):
    """NADELBETT: ein Prüfadapter - gefederte Nadeln unter der Platine, zwei Spannhebel halten sie."""
    key = "gold"
    plate(parent, key)
    led.rounded_box(parent, "Adapter", (L + 0.05, W + 0.05, 0.03), (0, 0, 0.015), dark_metal(),
                    0.04, 0.006)
    rnd = random.Random(3)
    pts = [(-0.74 + i * 0.062, -0.47 + j * 0.062, 0.04) for i in range(25) for j in range(16)
           if rnd.random() < 0.55]
    dm.dots(parent, "Nadeln", pts, 0.014, led.mat("Stiftmessing", (0.75, 0.55, 0.22), 0.3, 0.4, 0.5))
    for k in range(16):
        seg(parent, "Nadelzeile%d" % k, top(0.0303), -0.76, -0.47 + k * 0.062, 0.76,
            -0.47 + k * 0.062, 0.003, glow(key, 0.8 if loaded else 0.25))
    for s in (-1, 1):
        led.rounded_box(parent, "Spannbock%d" % s, (0.34, 0.05, 0.07), (0, s * (W * 0.5 + 0.035),
                                                                        0.035), dark_metal(), 0.01,
                        0.004)
        arm = led.rounded_box(parent, "Spannhebel%d" % s, (0.28, 0.1, 0.014),
                              (0, s * (W * 0.5 - (0.0 if loaded else -0.06)), 0.085), chrome(),
                              0.02, 0.004)
        box.dot(parent, "Spannlicht%d" % s, top(0.0925), 0, s * (W * 0.5 + 0.035), 0.014,
                glow(key, 3.0 if loaded else 0.5))
    if loaded:
        card_on(parent, module_card, 0.045)


def module_brenner(parent, loaded):
    """BRENNER: schmale Steckleiste und ein Schwenkarm, dessen Linse über dem Chip-Fenster steht."""
    key = "gold"
    plate(parent, key)
    standoffs(parent, 0.04)
    edge_socket(parent, key, loaded, 0.04)
    cx, cy = -0.4, 0.37
    dm.cyl(parent, "Armfuss", 0.05, 0.16, (cx, SW * 0.5 - 0.05, 0.08), dark_metal(), 24)
    bpy.ops.object.empty_add(location=(cx, SW * 0.5 - 0.05, 0.17))
    arm = bpy.context.active_object
    arm.parent = parent
    reach = (SW * 0.5 - 0.05) - cy
    led.rounded_box(arm, "Arm", (0.05, reach + 0.06, 0.024), (0, -reach * 0.5, 0), chrome(), 0.012,
                    0.006)
    dm.cyl(arm, "Kopf", 0.075, 0.04, (0, -reach, -0.005), dark_metal(), 28)
    dm.cyl(arm, "Linse", 0.05, 0.006, (0, -reach, -0.028), glow(key, 4.0 if loaded else 0.6), 24)
    dm.annulus(arm, "Kopfring", 0, -reach, 0.0155, 0.05, 0.065, glow(key, 2.4 if loaded else 0.5),
               28)
    if not loaded:
        arm.rotation_euler = (0, 0, math.radians(-70))
    else:
        cone = led.mat("Brennkegel", col(key), 0.0, 0.5, 0.6, 0.12)
        dm.cyl(parent, "Strahl", 0.045, 0.05, (cx, cy, 0.115), cone, 20)
    if loaded:
        card_on(parent, module_card, 0.04)


# --- Bühne --------------------------------------------------------------------------------------

READERS = {
    "lochkarte": [("L1 · BÜRSTEN", punch_buersten), ("L2 · LICHTTISCH", punch_lichttisch),
                  ("L3 · STIFTFELD", punch_stiftfeld)],
    "kassette": [("K1 · DECK", cassette_deck), ("K2 · KLAPPE", cassette_klappe),
                 ("K3 · KOPFSCHLITTEN", cassette_schlitten)],
    "tontafel": [("T1 · TASTER", clay_taster), ("T2 · LICHTSCHNITT", clay_lichtschnitt),
                 ("T3 · ROLLSIEGEL", clay_rollsiegel)],
    "modul": [("M1 · KONTAKTLEISTE", module_kontaktleiste), ("M2 · NADELBETT", module_nadelbett),
              ("M3 · BRENNER", module_brenner)],
}
# --- LOCHKARTE, zweite Runde: man soll SEHEN, wie gelesen wird (2026-11-19) --------------------

ROWS = [0.44 - d * 0.88 / 9 for d in range(10)]
CARD_TOP = 0.016 + 0.04


def hits(seed=7, n=4):
    """Welche der zehn Zeilen gerade ein Loch unter sich haben (für die Probe gewürfelt)."""
    return set(random.Random(seed).sample(range(10), n))


def gantry(parent, gx, z, width=0.07, h=0.03):
    """Brücke auf zwei Laufschienen über die Karte; geparkt steht sie am Kopf."""
    for s in (-1, 1):
        y = s * (SW * 0.5 - 0.035)
        rod(parent, "Laufschiene%d" % s, 0.012, L + 0.1, (0, y, z), chrome(), "x", 12)
        for x in (-1, 1):
            led.rounded_box(parent, "Stuetze%d_%d" % (s, x), (0.035, 0.035, z),
                            (x * (L * 0.5 + 0.03), y, z * 0.5), dark_metal(), 0.006, 0.004)
    led.rounded_box(parent, "Bruecke", (width, SW - 0.02, h), (gx, 0, z), dark_metal(), 0.008,
                    0.006)


def progress(parent, key, gx, z):
    """Die Lese-Spur: was die Brücke schon überfahren hat, leuchtet an beiden Schienen."""
    for s in (-1, 1):
        y = s * (SW * 0.5 - 0.07)
        seg(parent, "SpurAus%d" % s, top(z), -0.78, y, 0.78, y, 0.012, glow(key, 0.25))
        if gx > -0.7:
            seg(parent, "SpurAn%d" % s, top(z + 0.0004), -0.78, y, gx, y, 0.012, glow(key, 3.0))


def punch_lichtvorhang(parent, loaded):
    """LICHTVORHANG: die Brücke schickt je Zeile einen Lichtstrahl nach unten. Trifft er ein
    Loch, fällt er hindurch und seine Lampe geht an; sonst endet er als Punkt auf dem Karton."""
    key = "zahl"
    plate(parent, key)
    led.rounded_box(parent, "Bett", (L, W, 0.008), (0, 0, 0.004), led.DARK, 0.02, 0.0)
    gx = -0.28 if loaded else -0.74
    gantry(parent, gx, 0.24)
    progress(parent, key, gx, 0.0005)
    lit = hits() if loaded else set(range(10))
    for k, y in enumerate(ROWS):
        on = k in lit
        z_end = 0.01 if (on or not loaded) else CARD_TOP
        dm.beam(parent, "Strahl%d" % k, Vector((gx, y, 0.225)), Vector((gx, y, z_end)), 0.005,
                glow(key, 3.5 if on else 1.2))
        if loaded and not on:
            box.dot(parent, "Fleck%d" % k, top(CARD_TOP + 0.001), gx, y, 0.012, glow(key, 1.6))
        dm.cyl(parent, "Optik%d" % k, 0.016, 0.02, (gx, y, 0.222), chrome(), 12)
        box.dot(parent, "Lampe%d" % k, top(0.2555), gx, y, 0.014,
                glow(key, 4.0 if (on and loaded) else 0.35))
    if loaded:
        card_on(parent, punch_card, 0.016)


def punch_fuehlhebel(parent, loaded):
    """FÜHLHEBEL: zehn gefederte Finger liegen auf der Karte. Wer ein Loch findet, fällt hinein,
    sein Hebel kippt, und seine Lampe am Balken geht an."""
    key = "zahl"
    plate(parent, key)
    led.rounded_box(parent, "Bett", (L, W, 0.008), (0, 0, 0.004), led.DARK, 0.02, 0.0)
    bx, bz = -0.78, 0.12
    led.rounded_box(parent, "Balken", (0.09, SW - 0.02, 0.05), (bx, 0, bz), dark_metal(), 0.01,
                    0.006)
    for s in (-1, 1):
        led.rounded_box(parent, "Pfeiler%d" % s, (0.09, 0.04, bz), (bx, s * (SW * 0.5 - 0.03),
                                                                    bz * 0.5), dark_metal(), 0.006,
                        0.004)
    rod(parent, "Hebelachse", 0.01, SW - 0.06, (bx + 0.03, 0, bz), chrome())
    lit = hits() if loaded else set(range(10))
    rest = CARD_TOP + 0.012 if loaded else 0.02
    for k, y in enumerate(ROWS):
        on = k in lit
        tip_z = (CARD_TOP - 0.03 if loaded else 0.02) if on else rest
        tip = Vector((-0.42 + (k % 2) * 0.05, y, tip_z + 0.012))
        dm.beam(parent, "Finger%d" % k, Vector((bx + 0.03, y, bz)), tip, 0.008, chrome())
        dm.cyl(parent, "Taster%d" % k, 0.012, 0.03, (tip.x, y, tip_z + 0.004), brass(), 10)
        box.dot(parent, "Lampe%d" % k, top(bz + 0.0255), bx - 0.01, y, 0.016,
                glow(key, 4.0 if (on and loaded) else 0.35))
    if loaded:
        card_on(parent, punch_card, 0.016)


def punch_sternraeder(parent, loaded):
    """STERNRÄDER: eine Achse mit zehn Zahnrädchen rollt über die Karte. Greift ein Zahn in ein
    Loch, leuchtet die Nabe dieses Rads."""
    key = "zahl"
    plate(parent, key)
    led.rounded_box(parent, "Bett", (L, W, 0.008), (0, 0, 0.004), led.DARK, 0.02, 0.0)
    gx = -0.28 if loaded else -0.74
    za = (CARD_TOP if loaded else 0.012) + 0.05
    for s in (-1, 1):
        y = s * (SW * 0.5 - 0.035)
        led.rounded_box(parent, "Zahnschiene%d" % s, (L + 0.1, 0.03, za - 0.02), (0, y,
                                                                                  (za - 0.02) * 0.5),
                        dark_metal(), 0.0, 0.004)
        led.rounded_box(parent, "Lager%d" % s, (0.08, 0.05, 0.06), (gx, y, za), dark_metal(), 0.01,
                        0.006)
    rod(parent, "Achse", 0.012, SW - 0.04, (gx, 0, za), chrome())
    progress(parent, key, gx, 0.0005)
    lit = hits() if loaded else set()
    for k, y in enumerate(ROWS):
        wheel = rod(parent, "Sternrad%d" % k, 0.05, 0.014, (gx, y, za), brass(), "y", 8)
        wheel.rotation_euler = (HALF_PI, k * 0.4, 0)
        rod(parent, "Nabe%d" % k, 0.02, 0.03, (gx, y, za), glow(key, 4.0 if k in lit else 0.4),
            "y", 12)
    if loaded:
        card_on(parent, punch_card, 0.016)


def punch_lesekopf(parent, loaded):
    """LESEKOPF: ein Schlitten mit Leuchtspalt fährt über die Karte; auf seinem Rücken zeigt eine
    Lampenspalte das Lochmuster der Spalte, über der er gerade steht."""
    key = "zahl"
    plate(parent, key)
    led.rounded_box(parent, "Bett", (L, W, 0.008), (0, 0, 0.004), led.DARK, 0.02, 0.0)
    rails(parent, dark_metal(), 0.07)
    gx = -0.28 if loaded else -0.74
    z = 0.1
    progress(parent, key, gx, 0.0005)
    led.rounded_box(parent, "Schlitten", (0.16, SW - 0.01, 0.045), (gx, 0, z), dark_metal(), 0.02,
                    0.008)
    led.rounded_box(parent, "Sichtfenster", (0.03, W - 0.06, 0.05), (gx - 0.05, 0, z),
                    led.mat("Kopfglas", (0.6, 0.9, 0.7), 0.0, 0.03, 0.0, 0.12, clearcoat=1.0), 0.0,
                    0.0)
    seg(parent, "Leuchtspalt", top(z + 0.026), gx - 0.05, -W * 0.5 + 0.04, gx - 0.05,
        W * 0.5 - 0.04, 0.008, glow(key, 4.0 if loaded else 0.8))
    lit = hits() if loaded else set()
    for k, y in enumerate(ROWS):
        led.rounded_box(parent, "Melder%d" % k, (0.06, 0.05, 0.006), (gx + 0.03, y, z + 0.0255),
                        glow(key, 4.0) if k in lit else led.DARK, 0.008, 0.0)
    box.text(parent, "SPALTE 07" if loaded else "BEREIT", box.frame((gx + 0.03, -W * 0.5 - 0.0,
                                                                    z + 0.024), (0, 1, 0),
                                                                   (-1, 0, 0)), 0.0, 0.0, 0.0001,
             glow(key, 1.0), "Anzeige")
    if loaded:
        card_on(parent, punch_card, 0.016)


def punch_saugleiste(parent, loaded):
    """SAUGLEISTE: wie am Selbstspiel-Klavier - eine Messingleiste mit zehn Düsen liegt auf der
    Karte, Schläuche führen zu einem Verteiler. Durch ein Loch strömt Luft, sein Ventil leuchtet."""
    key = "zahl"
    plate(parent, key)
    led.rounded_box(parent, "Bett", (L, W, 0.008), (0, 0, 0.004), led.DARK, 0.02, 0.0)
    gx = -0.5
    zb = (CARD_TOP if loaded else 0.012) + 0.018
    led.rounded_box(parent, "Duesenleiste", (0.06, W - 0.02, 0.036), (gx, 0, zb), brass(), 0.008,
                    0.008)
    mx = -SL * 0.5 + 0.04
    led.rounded_box(parent, "Verteiler", (0.07, SW - 0.04, 0.11), (mx, 0, 0.055), dark_metal(),
                    0.01, 0.006)
    hose = led.mat("Schlauch", (0.025, 0.025, 0.03), 0.0, 0.5, clearcoat=0.4)
    lit = hits() if loaded else set()
    for k, y in enumerate(ROWS):
        a = Vector((gx, y, zb + 0.018))
        b = Vector(((gx + mx) * 0.5, y, zb + 0.09))
        c = Vector((mx, y, 0.11))
        dm.beam(parent, "SchlauchA%d" % k, a, b, 0.012, hose)
        dm.beam(parent, "SchlauchB%d" % k, b, c, 0.012, hose)
        dm.cyl(parent, "Tuelle%d" % k, 0.016, 0.012, (gx, y, zb + 0.022), chrome(), 10)
        dm.cyl(parent, "Ventil%d" % k, 0.022, 0.012, (mx, y, 0.116),
               glow(key, 4.0) if k in lit else led.mat("Ventil_aus", (0.05, 0.12, 0.07), 0.0, 0.4,
                                                       0.25), 14)
    for s in (-1, 1):
        dm.beam(parent, "Halter%d" % s, Vector((gx, s * (W * 0.5 + 0.03), zb)),
                Vector((gx, s * (W * 0.5 + 0.03), 0.0)), 0.012, chrome())
    if loaded:
        card_on(parent, punch_card, 0.016)


READERS["lochneu1"] = [("N1 · LICHTVORHANG", punch_lichtvorhang),
                       ("N2 · FÜHLHEBEL", punch_fuehlhebel),
                       ("N3 · STERNRÄDER", punch_sternraeder)]
READERS["lochneu2"] = [("N4 · LESEKOPF", punch_lesekopf), ("N5 · SAUGLEISTE", punch_saugleiste)]

COLUMNS = (-2.05, 0.0, 2.05)


def view(name, flat):
    cam, aim = dm.empty_stage()
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = 2100, 1100
    items = [(t + " · leer", fn, False) for t, fn in READERS[name]]
    items += [(t + " · belegt", fn, True) for t, fn in READERS[name]]
    n = len(READERS[name])
    spots = [(COLUMNS[i] + (1.0 if n == 2 else 0.0), y) for y in (0.78, -0.78) for i in range(n)]
    for (title, fn, loaded), (x, y) in zip(items, spots):
        if not flat:
            y *= 1.35
        dm.build(lambda p, fn=fn, loaded=loaded: fn(p, loaded), title, (x, y, 0.101))
        ms.label(title, x, y - 0.74, 0.075)
    if flat:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 6.5
        aim.location = (0, -0.05, 0)
        cam.location = (0, -0.05, 12)
    else:
        aim.location = (0, -0.2, 0.0)
        cam.location = (0.0, -6.0, 6.6)
        cam.data.lens = 44


VIEWS = {}
for _n in READERS:
    VIEWS[_n + "_draufsicht"] = (lambda n=_n: view(n, True))
    VIEWS[_n + "_schraeg"] = (lambda n=_n: view(n, False))


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
        print("gerendert", name, flush=True)
    print("ok")
