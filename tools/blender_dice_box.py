"""Fumble: das WÜRFEL-PAKET als BULLAUGEN-Schachtel (Spieler-Wunsch 2026-11-16) - dieselbe
Pappschachtel wie das Karten-Paket, aber die Front trägt je Würfel ein quadratisches
Fenster, angeordnet wie die Augen einer Würfelseite: die Schachtel IST die Würfelzahl.
Hinter jedem Fenster liegt ein echter Würfel in seiner Sorte im Klarsicht-Einsatz.
  Sorte  - der Ring um alle vier Seiten und die Kopfplatte am Fuß samt Symbol
  Güte   - Prägefolie: Marke, Haarlinie, Fensterringe und Ringsäume (weiß/Silber/Gold)
  Zahl   - die Fenster (vorn) und die Augen auf dem Kopf (im Lager)

Aufruf (kopflos):
  blender -b -P tools/blender_dice_box.py -- <ausgabe-ordner>
Achsen wie die Karten-Schachtel: X = Breite, Y = Länge (Kopf +Y), Z = Höhe.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_card_box as box

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
W, L, H, WALL = box.W, box.L, box.H, box.WALL
TAB = 0.13
LB = L - TAB
CY = -TAB * 0.5
HEAD = CY + LB * 0.5
FOOT = CY - LB * 0.5
# Würfelkante im Roh-Maß: 1,2 Welt / CASSETTE_SCALE 3,2.
EDGE = 0.36
PITCH = (0.35, 0.40)
PORT = 0.29
WIN_Y = HEAD - 0.04 - PITCH[1] - PORT * 0.5 - 0.02
DIE_TOP = H - WALL - 0.022
PANEL_A = 0.47
NAMES = {"normal": "WÜRFEL", "soul": "SEELE", "material": "MATERIAL", "rune": "RUNEN"}
COLORS = {"normal": led.lin("#d6dbe6"), "soul": led.lin("#a66bff"),
          "material": led.SORTS["material"], "rune": led.SORTS["rune"]}
VALUES = [4, 2, 6, 1, 5, 3]
MATERIALS = [("Rubin", "#e0115f", 0.6), ("Gold", "#f2c14e", 0.4), ("Glas", "#9fdcff", 0.5),
             ("Bernstein", "#ffa20a", 0.6), ("Kupfer", "#d07a3c", 0.3), ("Knochen", "#e6dcc2", 0.0)]
RUNES = [("ring", "#ffffff"), ("dreieck", "#ffc23a"), ("quadrat", "#ff7a1f"),
         ("stern", "#35e8ff"), ("raute", "#b77bff"), ("ring", "#ffffff")]


def pip_spots(n):
    """Die Fenster wie die Augen einer Würfelseite: (Spalte quer, Reihe längs)."""
    return {2: [(-1, 1), (1, -1)], 3: [(-1, 1), (0, 0), (1, -1)],
            4: [(-1, -1), (-1, 1), (1, -1), (1, 1)],
            5: [(-1, -1), (-1, 1), (0, 0), (1, -1), (1, 1)],
            6: [(-1, -1), (-1, 0), (-1, 1), (1, -1), (1, 0), (1, 1)]}[n]


def spot_xy(spot):
    return spot[0] * PITCH[0], WIN_Y + spot[1] * PITCH[1]


# --- Materialien --------------------------------------------------------------------

def ink(sort):
    return led.mat("Tinte_" + sort, COLORS[sort], 0.0, 0.45, 0.35)


def die_body():
    return led.mat("WuerfelKoerper", (0.012, 0.012, 0.018), 0.1, 0.32, clearcoat=0.6)


def glow(name, hex_color, energy):
    return led.mat("Glut_%s_%.1f" % (name, energy), led.lin(hex_color), 0.0, 0.3, energy)


# --- Zeichnen -----------------------------------------------------------------------

def poly(parent, name, fr, pts, material, lift):
    o, u, v, n = fr
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(o + u * a + v * b + n * lift) for a, b in pts], [],
                     [list(range(len(pts)))])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj.parent = parent
    return obj


def ngon(count, radius, turn=0.0, a=0.0, b=0.0):
    return [(a + math.cos(turn + math.tau * i / count) * radius,
             b + math.sin(turn + math.tau * i / count) * radius) for i in range(count)]


def star(radius, inner):
    pts = []
    for i in range(12):
        r = radius if i % 2 == 0 else radius * inner
        t = math.pi * 0.5 + math.tau * i / 12
        pts.append((math.cos(t) * r, math.sin(t) * r))
    return pts


def outline(parent, name, fr, outer, inner, material, back):
    """Eine Kontur: Fläche in der Farbe, darüber die Innenfläche im Grund."""
    poly(parent, name, fr, outer, material, 0.0015)
    poly(parent, name + "Innen", fr, inner, back, 0.002)


def square_ring(parent, name, fr, a, b, half, width, material, lift=0.0015):
    for k, (a0, b0, a1, b1) in enumerate([(-half, -half, half, -half + width),
                                          (-half, half - width, half, half),
                                          (-half, -half, -half + width, half),
                                          (half - width, -half, half, half)]):
        poly(parent, "%s%d" % (name, k), fr,
             [(a + a0, b + b0), (a + a1, b + b0), (a + a1, b + b1), (a + a0, b + b1)],
             material, lift)


def rune_glyph(parent, fr, shape, material, back):
    r = 0.115
    if shape == "ring":
        outline(parent, "Rune", fr, ngon(32, r), ngon(32, r - 0.02), material, back)
    elif shape == "dreieck":
        outline(parent, "Rune", fr, ngon(3, r, -math.pi * 0.5), ngon(3, r - 0.04, -math.pi * 0.5),
                material, back)
    elif shape == "quadrat":
        square_ring(parent, "Rune", fr, 0, 0, r * 0.82, 0.02, material)
    elif shape == "stern":
        outline(parent, "Rune", fr, star(r, 0.5), star(r - 0.03, 0.42), material, back)
    else:
        outline(parent, "Rune", fr, ngon(4, r, math.pi * 0.5), ngon(4, r - 0.028, math.pi * 0.5),
                material, back)


def die(parent, sort, k, x, y, top=DIE_TOP):
    """Ein echter Würfel: dunkler Körper, die obere Seite in der Sprache der Sorte."""
    z0 = top - EDGE
    led.rounded_box(parent, "Wuerfel%d" % k, (EDGE, EDGE, EDGE), (x, y, z0 + EDGE * 0.5),
                    die_body(), 0.035, 0.03, 6)
    fr = box.frame((x, y, top), (0, -1, 0), (1, 0, 0))
    back = die_body()
    digit = led.mat("Ziffer", (1.0, 0.97, 0.92), 0.0, 0.3, 2.2)
    half = EDGE * 0.5 - 0.055
    if sort == "normal":
        square_ring(parent, "Kante%d" % k, fr, 0, 0, half, 0.012, glow("weiss", "#cfe6ff", 1.2))
    elif sort == "soul":
        square_ring(parent, "Kante%d" % k, fr, 0, 0, half, 0.02, glow("seele", "#b47bff", 4.0))
        digit = led.mat("ZifferSeele", led.lin("#e7d6ff"), 0.0, 0.3, 2.6)
    elif sort == "material":
        name, color, energy = MATERIALS[k % len(MATERIALS)]
        face = led.mat("Material_" + name, led.lin(color), 0.2, 0.35, energy, clearcoat=0.5)
        poly(parent, "Seite%d" % k, fr, [(-half - 0.03, -half - 0.03), (half + 0.03, -half - 0.03),
                                         (half + 0.03, half + 0.03), (-half - 0.03, half + 0.03)],
             face, 0.0015)
        box.dot(parent, "Hof%d" % k, fr, 0, 0, 0.075, back)
    else:
        shape, color = RUNES[k % len(RUNES)]
        rune_glyph(parent, fr, shape, glow("rune_" + color, color, 3.0), back)
    t = box.text(parent, str(VALUES[k % len(VALUES)]), fr, 0.0, 0.0, 0.15, digit, "Ziffer%d" % k)
    # Die Ziffer liegt immer vor Hof und Rune.
    t.location += fr[3] * 0.003


def sort_symbol(parent, fr, sort, a, b, size):
    blk = box.black_ink()
    back = ink(sort)
    if sort == "soul":
        poly(parent, "Symbol", fr, ngon(4, size, math.pi * 0.5, a, b), blk, 0.0025)
    elif sort == "material":
        poly(parent, "Symbol", fr, ngon(6, size, math.pi * 0.5, a, b), blk, 0.0025)
    elif sort == "rune":
        poly(parent, "Symbol", fr, ngon(40, size, 0, a, b), blk, 0.0025)
        poly(parent, "SymbolInnen", fr, ngon(40, size * 0.8, 0, a, b), back, 0.003)
        poly(parent, "SymbolDreieck", fr, ngon(3, size * 0.62, math.pi * 0.5, a, b), blk, 0.0035)
    else:
        # Das normale Paket: eine Würfelseite mit einem Auge.
        s = size * 0.8
        poly(parent, "Symbol", fr, [(a - s, b - s), (a + s, b - s), (a + s, b + s), (a - s, b + s)],
             blk, 0.0025)
        poly(parent, "SymbolAuge", fr, ngon(24, s * 0.3, 0, a, b), back, 0.003)


# --- Die Schachtel ------------------------------------------------------------------

def bullauge(parent, sort, count, quality):
    count = max(2, min(6, count))
    foil = box.foil(quality)
    body = led.rounded_box(parent, "Karton", (W, LB, H), (0, CY, H * 0.5), box.board(), 0.012,
                           0.006, 4)
    box.hollow(parent, body, (W - WALL * 2, LB - WALL * 2, H - WALL * 2), (0, CY, H * 0.5))
    spots = pip_spots(count)
    for i, spot in enumerate(spots):
        x, y = spot_xy(spot)
        hole = led.rounded_box(parent, "SchnittFenster%d" % i, (PORT, PORT, WALL * 4), (0 + x, y, H),
                               box.kraft(), 0.05, 0.0, 8)
        box.cut(body, hole, True)
    # EINE Folie unter der ganzen Front - wie in einer echten Schachtel eingeklebt.
    span_y = PITCH[1] * 2 + PORT + 0.06
    led.rounded_box(parent, "Folie", (PITCH[0] * 2 + PORT + 0.06, span_y, 0.003),
                    (0, WIN_Y, H - WALL - 0.002), box.film(), 0.02, 0.0, 6)
    # Der Klarsicht-Einsatz: eine Platte mit einer Mulde je Würfel.
    seat = DIE_TOP - EDGE
    plate_top = seat + 0.1
    insert = led.rounded_box(parent, "Einsatz", (W - WALL * 2 - 0.01, LB - WALL * 2 - 0.01,
                                                 plate_top - WALL),
                             (0, CY, WALL + (plate_top - WALL) * 0.5), box.blister(), 0.02, 0.004,
                             4)
    for i, spot in enumerate(spots):
        x, y = spot_xy(spot)
        pocket = led.rounded_box(parent, "SchnittMulde%d" % i, (EDGE + 0.02, EDGE + 0.02, 0.2),
                                 (x, y, seat + 0.1), box.blister(), 0.04, 0.0, 6)
        box.cut(insert, pocket)
        die(parent, sort, i, x, y)
    # Die Euro-Lasche wie beim Karten-Paket.
    lug = led.rounded_box(parent, "Lasche", (W * 0.46, TAB + 0.04, 0.012),
                          (0, L * 0.5 - (TAB + 0.04) * 0.5, 0.006), box.board(), 0.03, 0.003, 6)
    slot = led.rounded_box(parent, "SchnittLasche", (0.17, 0.036, 0.1), (0, L * 0.5 - TAB * 0.48, 0),
                           box.kraft(), 0.017, 0.0, 6)
    box.cut(lug, slot)
    fr = box.front_frame()
    half = W * 0.5
    foot = -FOOT
    # Je Fenster ein Folienring der Güte.
    for i, spot in enumerate(spots):
        x, y = spot_xy(spot)
        square_ring(parent, "FensterRing%d" % i, fr, -y, x, PORT * 0.5 + 0.016, 0.01, foil)
    # Die KOPFPLATTE am Fuß in der Sortenfarbe: Marke, Name, Symbol.
    box.rect(parent, "Platte", fr, PANEL_A, -half, foot, half, ink(sort))
    box.rect(parent, "Haarlinie", fr, PANEL_A - 0.03, -half, PANEL_A - 0.018, half, foil)
    mid = (PANEL_A + foot) * 0.5
    box.text(parent, "FUMBLE", fr, mid, 0.4, 0.075, box.black_ink(), "Marke")
    box.text(parent, NAMES[sort], fr, mid, 0.28, 0.058, box.black_ink(), "Sorte")
    sort_symbol(parent, fr, sort, mid, -0.12, 0.11)
    box.rect(parent, "PlatteFolie", fr, PANEL_A + 0.03, -0.39, foot - 0.03, -0.375, foil)
    # Der RING in der Sortenfarbe um alle vier Seiten, gesäumt von der Folie.
    ring, seam = 0.08, 0.095
    hf, ff = box.head_frame(HEAD), box.foot_frame(FOOT)
    for name, ef in (("Kopf", hf), ("Fuss", ff)):
        box.rect(parent, "Ring" + name, ef, -ring, -half, ring, half, ink(sort))
        for k, edge in enumerate((-1, 1)):
            box.rect(parent, "RingSaum%s%d" % (name, k), ef, edge * seam - 0.006, -half,
                     edge * seam + 0.006, half, foil)
    box.pips(parent, hf, count, 0.0, 0.0, 0.15, 0.045, box.black_ink(), True, "KopfAuge")
    for i, sf in enumerate(box.spine_frames(CY)):
        box.rect(parent, "RingRuecken%d" % i, sf, -LB * 0.5, -ring, LB * 0.5, ring, ink(sort))
        for k, edge in enumerate((-1, 1)):
            box.rect(parent, "RingSaumRuecken%d%d" % (i, k), sf, -LB * 0.5, edge * seam - 0.006,
                     LB * 0.5, edge * seam + 0.006, foil)
        box.text(parent, NAMES[sort], sf, -0.25, 0.0, 0.1, box.black_ink(), "RueckenText%d" % i)


# Laden: je Sorte eine; Lager: dazu weitere Zahlen und Güten.
led.PACKS = [("normal", 2, 0), ("soul", 4, 1), ("material", 5, 2), ("rune", 6, 0)]
box.LAGER = led.PACKS + [("rune", 3, 2), ("normal", 6, 1), ("soul", 5, 2), ("material", 3, 0)]


def render():
    os.makedirs(OUT, exist_ok=True)
    for view in ("laden", "lager", "lager_nah", "nah"):
        box.show(bullauge, view)
        bpy.context.scene.render.filepath = os.path.join(OUT, "bullauge_%s.png" % view)
        bpy.ops.render.render(write_still=True)
    print("ok")


if __name__ == "__main__":
    render()
