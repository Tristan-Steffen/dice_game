"""Fumble: vier weitere Entwürfe des WÜRFEL-Pakets (Spieler-Wunsch 2026-11-16 - die Bullaugen-
Schachtel las zu sehr wie das Karten-Paket):
  stuelpdeckel - Stülpdeckel-Schachtel: der Deckel ganz in der Sortenfarbe, darunter der
                 schwarze Boden; eckige Fenster im Augen-Muster
  riesenwuerfel - die Schachtel ist eine RIESIGE Würfelseite: gerundet, ganz in der
                 Sortenfarbe, die runden Fenster sind die Augen
  schale       - Klarsicht-Haube über einer Schale mit sechs Mulden in der Sortenfarbe; leere
                 Mulden bleiben sichtbar, eine Banderole am Fuß sagt Sorte und Zahl
  roehre       - Klarsicht-Röhre mit den Würfeln in einer Reihe unter einer Kopfkarte mit
                 Euro-Lasche (sprengt den gemeinsamen Grundriß: ein 6er ist ~2,8 lang)

Aufruf (kopflos):
  blender -b -P tools/blender_dice_box_variants.py -- <ausgabe-ordner> [entwurf]
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_card_cassette_glass as shape
import blender_card_box as box
import blender_dice_box as dbx

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
W, L, H, WALL = box.W, box.L, box.H, box.WALL
EDGE = dbx.EDGE


def sort_board(sort, name="Farbkarton"):
    """Karton ganz in der Sortenfarbe, mit etwas Eigenlicht für den dunklen Tisch."""
    return led.mat("%s_%s" % (name, sort), dbx.COLORS[sort], 0.0, 0.4, 0.12, clearcoat=0.4)


def sort_plastic(sort):
    return led.mat("Kunststoff_" + sort, dbx.COLORS[sort], 0.0, 0.18, 0.2, clearcoat=1.0)


def annulus(parent, name, fr, a, b, r0, r1, material, lift=0.0015, segs=48):
    o, u, v, n = fr
    verts, faces = [], []
    for i in range(segs):
        t = math.tau * i / segs
        for r in (r0, r1):
            verts.append(tuple(o + u * (a + math.cos(t) * r) + v * (b + math.sin(t) * r) + n * lift))
    for i in range(segs):
        j = (i + 1) % segs
        faces.append([i * 2, i * 2 + 1, j * 2 + 1, j * 2])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj.parent = parent
    return obj


def insert_with_dice(parent, sort, spots_xy, floor, top, size_xy, center_y, corner=0.02):
    """Klarsicht-Einsatz mit einer Mulde je Würfel; die Würfel liegen darin."""
    seat = top - EDGE
    plate_top = seat + 0.1
    insert = led.rounded_box(parent, "Einsatz", (size_xy[0], size_xy[1], plate_top - floor),
                             (0, center_y, floor + (plate_top - floor) * 0.5), box.blister(), corner,
                             0.004, 8)
    for i, (x, y) in enumerate(spots_xy):
        pocket = led.rounded_box(parent, "SchnittMulde%d" % i, (EDGE + 0.02, EDGE + 0.02, 0.2),
                                 (x, y, seat + 0.1), box.blister(), 0.04, 0.0, 6)
        box.cut(insert, pocket)
        dbx.die(parent, sort, i, x, y, top)


def side_frame(i, z, cy=0.0):
    return (box.frame((-W * 0.5, cy, z), (0, -1, 0), (0, 0, 1)),
            box.frame((W * 0.5, cy, z), (0, 1, 0), (0, 0, 1)))[i]


# --- 1. Stülpdeckel ---------------------------------------------------------------------

def stuelpdeckel(parent, sort, count, quality):
    foil = box.foil(quality)
    lid_h = H * 0.42
    base_h = H - 0.012
    base = led.rounded_box(parent, "Boden", (W - 0.03, L - 0.03, base_h), (0, 0, base_h * 0.5),
                           box.board(), 0.015, 0.004, 4)
    box.cut(base, led.rounded_box(parent, "SchnittBoden", (W - 0.03 - WALL * 2,
                                                          L - 0.03 - WALL * 2, H),
                                  (0, 0, WALL + H * 0.5), box.kraft(), 0.01, 0.0, 4), True)
    lid = led.rounded_box(parent, "Deckel", (W, L, lid_h), (0, 0, H - lid_h * 0.5),
                          sort_board(sort), 0.02, 0.006, 4)
    box.cut(lid, led.rounded_box(parent, "SchnittDeckel", (W - WALL * 2, L - WALL * 2, lid_h),
                                 (0, 0, H - lid_h * 0.5 - WALL), box.kraft(), 0.01, 0.0, 4), True)
    grid_y = 0.16
    spots = [(s[0] * dbx.PITCH[0], grid_y + s[1] * dbx.PITCH[1]) for s in dbx.pip_spots(count)]
    for i, (x, y) in enumerate(spots):
        box.cut(lid, led.rounded_box(parent, "SchnittFenster%d" % i, (dbx.PORT, dbx.PORT, 0.1),
                                     (x, y, H), box.kraft(), 0.05, 0.0, 8), True)
    led.rounded_box(parent, "Folie", (W - WALL * 2 - 0.01, L - WALL * 2 - 0.01, 0.003),
                    (0, 0, H - WALL - 0.002), box.film(), 0.01, 0.0, 4)
    insert_with_dice(parent, sort, spots, WALL, H - WALL - 0.022,
                     (W - 0.03 - WALL * 2 - 0.01, L - 0.03 - WALL * 2 - 0.01), 0.0)
    fr = box.front_frame()
    for i, (x, y) in enumerate(spots):
        dbx.square_ring(parent, "FensterRing%d" % i, fr, -y, x, dbx.PORT * 0.5 + 0.016, 0.012, foil)
    # Am Fuß quer: Marke in Folie, Name schwarz - keine Platte, der Deckel IST die Farbe.
    box.text(parent, "FUMBLE", fr, 0.66, 0.0, 0.11, box.black_ink(), "Marke")
    box.text(parent, dbx.NAMES[sort], fr, 0.66, -0.16, 0.06, box.black_ink(), "Sorte")
    # Die Deckelkante: ringsum eine Folienlinie, auf den Langseiten der Name, am Kopf die Augen.
    rim = H - lid_h * 0.5
    for i in range(2):
        sf = side_frame(i, rim)
        box.text(parent, dbx.NAMES[sort], sf, 0.0, 0.0, 0.085, box.black_ink(), "RandText%d" % i)
        box.rect(parent, "RandFolie%d" % i, sf, -L * 0.5, -lid_h * 0.5 + 0.012, L * 0.5,
                 -lid_h * 0.5 + 0.024, foil)
    for name, y, u in (("Kopf", L * 0.5, (0, 0, 1)), ("Fuss", -L * 0.5, (0, 0, -1))):
        ef = box.frame((0, y, rim), u, (1, 0, 0))
        box.rect(parent, "RandFolie" + name, ef, (-1 if u[2] > 0 else 1) * (lid_h * 0.5 - 0.018)
                 - 0.006, -W * 0.5, (-1 if u[2] > 0 else 1) * (lid_h * 0.5 - 0.018) + 0.006,
                 W * 0.5, foil)
    box.pips(parent, box.frame((0, L * 0.5, rim + 0.01), (0, 0, 1), (1, 0, 0)), count, 0.0, 0.0,
             0.15, 0.045, box.black_ink(), True, "KopfAuge")


# --- 2. Riesenwürfel ------------------------------------------------------------------

def riesenwuerfel(parent, sort, count, quality):
    foil = box.foil(quality)
    body = led.rounded_box(parent, "Koerper", (W, L, H), (0, 0, H * 0.5), sort_plastic(sort),
                           0.24, 0.08, 12)
    # Der Hohlraum folgt der Rundung, sonst bräche er an den Ecken durch.
    box.cut(body, led.rounded_box(parent, "Hohlraum", (W - WALL * 4, L - WALL * 4, H - WALL * 2),
                                  (0, 0, H * 0.5), box.kraft(), 0.2, 0.0, 12), True)
    pitch = (0.36, 0.48)
    spots = [(s[0] * pitch[0], s[1] * pitch[1]) for s in dbx.pip_spots(count)]
    radius = 0.155
    for i, (x, y) in enumerate(spots):
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radius, depth=0.2,
                                            location=(x, y, H))
        c = bpy.context.active_object
        c.name = "SchnittAuge%d" % i
        c.data.materials.append(box.kraft())
        c.parent = parent
        box.cut(body, c, True)
    led.rounded_box(parent, "Folie", (W - WALL * 4 - 0.01, L - WALL * 4 - 0.01, 0.003),
                    (0, 0, H - WALL - 0.002), box.film(), 0.2, 0.0, 8)
    insert_with_dice(parent, sort, spots, WALL, H - WALL - 0.03,
                     (W - WALL * 4 - 0.03, L - WALL * 4 - 0.03), 0.0, 0.19)
    fr = box.front_frame()
    for i, (x, y) in enumerate(spots):
        annulus(parent, "AugenRing%d" % i, fr, -y, x, radius + 0.004, radius + 0.022, foil)
    # Keine Platte, kein Ring: nur die Marke klein in der Ecke, der Name auf den Flanken.
    for i in range(2):
        box.text(parent, "FUMBLE  " + dbx.NAMES[sort], side_frame(i, H * 0.5), 0.0, 0.0, 0.08,
                 box.black_ink(), "FlankenText%d" % i)
    box.pips(parent, box.head_frame(L * 0.5), count, 0.0, 0.0, 0.13, 0.04, box.black_ink(), True,
             "KopfAuge")


# --- 3. Schale ------------------------------------------------------------------------

def schale(parent, sort, count, quality):
    foil = box.foil(quality)
    tray_top = 0.3
    base = led.rounded_box(parent, "Boden", (W, L, tray_top), (0, 0, tray_top * 0.5), box.board(),
                           0.03, 0.006, 4)
    tray = led.rounded_box(parent, "Schale", (W - 0.04, L - 0.04, 0.06),
                           (0, 0, tray_top - 0.03 + 0.002), sort_plastic(sort), 0.02, 0.01, 4)
    wells = [(x * 0.22, 0.17 + y * 0.42) for y in (1, 0, -1) for x in (-1, 1)]
    for i, (x, y) in enumerate(wells):
        cutter = led.rounded_box(parent, "SchnittMulde%d" % i, (EDGE + 0.04, EDGE + 0.04, 0.4),
                                 (x, y, tray_top - 0.26 + 0.2), sort_plastic(sort), 0.05, 0.0, 6)
        box.cut(base, cutter)
        box.cut(tray, cutter)
        # Der Muldenboden in der Sortenfarbe - eine leere Mulde liest als leerer Platz.
        led.rounded_box(parent, "Muldenboden%d" % i, (EDGE + 0.04, EDGE + 0.04, 0.01),
                        (x, y, tray_top - 0.26 - 0.005), sort_plastic(sort), 0.05, 0.0, 6)
        if i < count:
            dbx.die(parent, sort, i, x, y, tray_top - 0.26 + EDGE)
    # Die Klarsicht-Haube.
    dome_h = H - tray_top + 0.02
    dome = led.rounded_box(parent, "Haube", (W, L, dome_h), (0, 0, tray_top - 0.02 + dome_h * 0.5),
                           shape.glass("Haube", 0.09, (0.85, 0.9, 1.0)), 0.03, 0.03, 6)
    box.cut(dome, led.rounded_box(parent, "SchnittHaube", (W - 0.012, L - 0.012, dome_h),
                                  (0, 0, tray_top - 0.02 + dome_h * 0.5 - 0.006), box.kraft(), 0.03,
                                  0.0, 4))
    # Die BANDEROLE am Fuß: rundum, schwarz mit der Sortenfarbe obenauf.
    by, bw = -0.6, 0.38
    band = led.rounded_box(parent, "Banderole", (W + 0.02, bw, H + 0.02), (0, by, (H + 0.02) * 0.5 - 0.01),
                           box.board(), 0.01, 0.003, 4)
    box.cut(band, led.rounded_box(parent, "SchnittBanderole", (W - 0.004, bw + 0.2, H - 0.004),
                                  (0, by, H * 0.5), box.kraft(), 0.03, 0.0, 4))
    fr = box.frame((0, by, H + 0.01), (0, -1, 0), (1, 0, 0))
    half = W * 0.5 + 0.01
    box.rect(parent, "BandFarbe", fr, -bw * 0.5, -half, bw * 0.5, half, dbx.ink(sort))
    box.rect(parent, "BandFolieA", fr, -bw * 0.5 + 0.02, -half, -bw * 0.5 + 0.032, half, foil)
    box.rect(parent, "BandFolieB", fr, bw * 0.5 - 0.032, -half, bw * 0.5 - 0.02, half, foil)
    box.text(parent, "FUMBLE", fr, 0.0, 0.36, 0.07, box.black_ink(), "Marke")
    box.text(parent, dbx.NAMES[sort], fr, 0.0, 0.22, 0.055, box.black_ink(), "Sorte")
    box.pips(parent, fr, count, 0.0, -0.17, 0.065, 0.024, box.black_ink(), True, "BandAuge")
    for i in range(2):
        sf = box.frame(((-1 if i == 0 else 1) * (W * 0.5 + 0.01), by, H * 0.5),
                       (0, -1 if i == 0 else 1, 0), (0, 0, 1))
        box.rect(parent, "BandSeite%d" % i, sf, -bw * 0.5, -0.07, bw * 0.5, 0.07, dbx.ink(sort))
    box.pips(parent, box.head_frame(L * 0.5), count, 0.0, 0.0, 0.15, 0.04, dbx.ink(sort), True,
             "KopfAuge")


# --- 4. Röhre mit Kopfkarte -----------------------------------------------------------

TUBE_R = 0.27
HEADER = 0.42


def tube_length(count):
    return count * 0.38 + 0.1


def roehre(parent, sort, count, quality):
    foil = box.foil(quality)
    tube = tube_length(count)
    total = HEADER + tube
    head_y = total * 0.5
    zc = TUBE_R + 0.01
    # Die Röhre steckt mit einem Stück in der Kopfkarte.
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=TUBE_R, depth=tube + 0.25,
                                        location=(0, head_y - HEADER - tube * 0.5 + 0.125, zc),
                                        rotation=(math.radians(90), 0, 0))
    t = bpy.context.active_object
    t.name = "Roehre"
    t.data.materials.append(shape.glass("Roehre", 0.1, (0.85, 0.92, 1.0)))
    bpy.ops.object.shade_smooth()
    t.parent = parent
    # Der Stopfen am Fuß in der Folie der Güte.
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=TUBE_R + 0.012, depth=0.07,
                                        location=(0, head_y - total + 0.035, zc),
                                        rotation=(math.radians(90), 0, 0))
    cap = bpy.context.active_object
    cap.name = "Stopfen"
    cap.data.materials.append(foil if quality else box.black_ink())
    bpy.ops.object.shade_smooth()
    cap.parent = parent
    for k in range(count):
        y = head_y - HEADER - 0.05 - 0.19 - k * 0.38
        dbx.die(parent, sort, k, 0, y, zc + EDGE * 0.5)
    # Die KOPFKARTE: gefalzter Karton in der Sortenfarbe, darüber die Euro-Lasche.
    ch = TUBE_R * 2 + 0.06
    card = led.rounded_box(parent, "Kopfkarte", (W, HEADER, ch), (0, head_y - HEADER * 0.5, ch * 0.5),
                           sort_board(sort, "Kopfkarte"), 0.02, 0.006, 4)
    lug = led.rounded_box(parent, "Lasche", (W * 0.46, 0.2, 0.012),
                          (0, head_y + 0.08, ch - 0.006), sort_board(sort, "Kopfkarte"), 0.03,
                          0.003, 6)
    box.cut(lug, led.rounded_box(parent, "SchnittLasche", (0.17, 0.036, 0.1),
                                 (0, head_y + 0.1, ch), box.kraft(), 0.017, 0.0, 6))
    fr = box.frame((0, head_y - HEADER * 0.5, ch), (0, -1, 0), (1, 0, 0))
    box.text(parent, "FUMBLE", fr, 0.0, 0.36, 0.075, box.black_ink(), "Marke")
    box.text(parent, dbx.NAMES[sort], fr, 0.0, 0.24, 0.05, box.black_ink(), "Sorte")
    dbx.sort_symbol(parent, fr, sort, 0.0, -0.02, 0.09)
    box.rect(parent, "Folienlinie", fr, -HEADER * 0.5, -0.2, HEADER * 0.5, -0.188, foil)
    box.pips(parent, fr, count, 0.0, -0.33, 0.065, 0.024, box.black_ink(), True, "KarteAuge")
    hf = box.frame((0, head_y, ch * 0.5), (0, 0, 1), (1, 0, 0))
    box.pips(parent, hf, count, 0.0, 0.0, 0.15, 0.04, box.black_ink(), True, "KopfAuge")
    for i in range(2):
        sf = box.frame(((-1 if i == 0 else 1) * W * 0.5, head_y - HEADER * 0.5, ch * 0.5),
                       (0, -1 if i == 0 else 1, 0), (0, 0, 1))
        box.text(parent, dbx.NAMES[sort], sf, 0.0, 0.0, 0.06, box.black_ink(), "Seite%d" % i)


DESIGNS = [("stuelpdeckel", stuelpdeckel), ("riesenwuerfel", riesenwuerfel), ("schale", schale),
           ("roehre", roehre)]


def render(only=""):
    os.makedirs(OUT, exist_ok=True)
    base_l = box.L
    for name, build in DESIGNS:
        if only and name != only:
            continue
        # Die Röhre ist länger als der Grundriß: Laden-Abstand und Lager-Stand messen an ihr.
        box.L = HEADER + tube_length(6) if name == "roehre" else base_l
        for view in ("laden", "lager", "lager_nah", "nah"):
            box.show(build, view)
            bpy.context.scene.render.filepath = os.path.join(OUT, "%s_%s.png" % (name, view))
            bpy.ops.render.render(write_still=True)
    box.L = base_l
    print("ok")


if __name__ == "__main__":
    render(sys.argv[sys.argv.index("--") + 2] if "--" in sys.argv
           and len(sys.argv) > sys.argv.index("--") + 2 else "")
