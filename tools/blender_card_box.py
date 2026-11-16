"""Fumble: das KARTEN-PAKET als bedruckte Pappschachtel wie die Verpackung eines RAM-Riegels
(Spieler-Wunsch 2026-11-16): ein Fenster mit Klarsichtfolie, dahinter die Data-Cards im
Blister. Drei Entwürfe:
  retail    - schwarze Faltschachtel mit Euro-Lasche, Sortenband schräg am Fuß, Folienprägung
              der Güte, Augen der Kartenzahl auf Front und Kopf
  schuber   - Schuber in der Sortenfarbe mit Grifflöchern, darin die Innenschachtel im Finish
              der Güte; der Kopf zeigt sie samt Augen-Etikett
  panorama  - das Fenster läuft über die Kopfkante: im Lager sieht man die Kartenkanten,
              Sortenkappe am Fuß, ein Güte-Siegel auf der Front

Aufruf (kopflos):
  blender -b -P tools/blender_card_box.py -- <ausgabe-ordner> [entwurf]
Achsen wie die Kassette: X = Breite, Y = Länge (Kopf +Y), Z = Höhe, Ursprung = Mitte unten.
Im Laden liegt das Paket quer: Bild-rechts ist der Fuß (-Y), Bild-oben ist +X.
"""
import bpy, math, os, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_card_cassette_glass as shape

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."

W, L = led.W, led.L
H = shape.SHELL_H
WALL = 0.015
EPS = 0.0015
CARD = (W * 0.56, 0.72)
STEP = 0.05
NAMES = {"zahl": "ZAHLEN", "material": "MATERIAL", "rune": "RUNEN", "misch": "MISCH"}


# --- Materialien --------------------------------------------------------------------

def board():
    """Schwarz bedruckter Karton, leicht laminiert."""
    return led.mat("Karton", (0.016, 0.016, 0.02), 0.0, 0.42, clearcoat=0.35)


def kraft():
    return led.mat("Kraft", led.lin("#a88f6c"), 0.0, 0.9)


def ink(sort):
    if sort == "misch":
        return led.mat("TinteWeiss", (0.82, 0.82, 0.84), 0.0, 0.45, 0.2)
    return led.mat("Tinte_" + sort, led.SORTS[sort], 0.0, 0.45, 0.35)


def black_ink():
    return led.mat("TinteSchwarz", (0.012, 0.012, 0.014), 0.0, 0.5)


def white():
    return led.mat("Weiss", (0.92, 0.92, 0.92), 0.0, 0.5, 0.3)


def foil(q):
    """Die GÜTE als Prägefolie: Standard weißer Druck, Edel Silber, Royal Gold."""
    if q == 0:
        return white()
    return led.mat("Folie%d" % q, led.QUALITY[q][0], 0.7, 0.22, 0.15, clearcoat=0.5)


def finish(q):
    """Die Innenschachtel des Schubers: Graphit-Karton, Silber- oder Goldkaschierung."""
    if q == 0:
        return led.mat("Graphit", (0.07, 0.07, 0.08), 0.2, 0.45, 0.05, clearcoat=0.3)
    c = led.QUALITY[q][0]
    return led.mat("Kaschierung%d" % q, c, 0.85, 0.24, clearcoat=0.4)


def film():
    return shape.glass("Folie", 0.07, (0.85, 0.9, 1.0))


def blister():
    return shape.glass("Blister", 0.1, (0.8, 0.88, 1.0))


# --- Werkzeuge ----------------------------------------------------------------------

def cut(target, cutter, transfer=False):
    led.cut(target, cutter)
    if transfer:
        target.modifiers[-1].material_mode = "TRANSFER"


def frame(origin, u, v):
    """Eine Druckfläche: Ursprung, Lese-Richtung u, Oben v; die Normale ist u × v."""
    u, v = Vector(u), Vector(v)
    return (Vector(origin), u, v, u.cross(v))


def place(obj, fr, a, b, lift=0.0):
    o, u, v, n = fr
    basis = Matrix((u, v, n)).transposed().to_4x4()
    obj.matrix_world = Matrix.Translation(o + u * a + v * b + n * lift) @ basis


def decal(parent, name, fr, pts, material):
    o, u, v, n = fr
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(o + u * a + v * b + n * EPS) for a, b in pts], [],
                     [list(range(len(pts)))])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj.parent = parent
    return obj


def rect(parent, name, fr, a0, b0, a1, b1, material):
    return decal(parent, name, fr, [(a0, b0), (a1, b0), (a1, b1), (a0, b1)], material)


def text(parent, body, fr, a, b, size, material, name="Text"):
    bpy.ops.object.text_add()
    t = bpy.context.active_object
    t.name = name
    t.data.body = body
    t.data.size = size
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    t.data.extrude = 0.0006
    t.data.materials.append(material)
    place(t, fr, a, b, EPS * 2)
    t.parent = parent
    return t


def dot(parent, name, fr, a, b, radius, material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=0.003)
    d = bpy.context.active_object
    d.name = name
    d.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    place(d, fr, a, b, EPS)
    d.parent = parent
    return d


def pips(parent, fr, count, a, b, pitch, radius, material, along_v=False, name="Auge"):
    """Die KARTENZAHL: eine Reihe Augen, feste Teilung - die kurze Reihe ist das kleine Paket."""
    for i in range(count):
        t = (i - (count - 1) * 0.5) * pitch
        dot(parent, "%s%d" % (name, i), fr, a + (0 if along_v else t), b + (t if along_v else 0),
            radius, material)


def hollow(parent, body, size, loc):
    """Ein geschlossener Hohlraum - innen roher Karton."""
    c = led.rounded_box(parent, "Hohlraum", size, loc, kraft(), 0.006, 0.0, 4)
    cut(body, c, True)


def contents(parent, sort, count, center_y, floor, top, head_first=True):
    """Die TREPPE echter Data-Cards, vom Klarsicht-Blister bis dicht unter die Folie gehoben."""
    cw, cl = CARD
    span = cl + STEP * (count - 1)
    pitch = 0.034
    lowest = top - 0.012 - shape.CT * 0.5 - pitch * (count - 1)
    pedestal = lowest - shape.CT * 0.5 - floor
    led.rounded_box(parent, "Blister", (cw + 0.06, span + 0.06, pedestal),
                    (0, center_y, floor + pedestal * 0.5), blister(), 0.03, 0.006, 6)
    for i in range(count):
        off = span * 0.5 - cl * 0.5 - STEP * i
        y = center_y + (off if head_first else -off)
        z = lowest + pitch * i
        shape.game_card(parent, shape.card_sort(sort, i), CARD, (0, y, z), "Karte%d" % i,
                        i + count)


def front_frame(cy=0.0):
    return frame((0, cy, H), (0, -1, 0), (1, 0, 0))


def head_frame(y):
    return frame((0, y, H * 0.5), (0, 0, 1), (1, 0, 0))


def foot_frame(y):
    return frame((0, y, H * 0.5), (0, 0, -1), (1, 0, 0))


def spine_frames(cy=0.0):
    """Die beiden Langseiten: im Laden aufrecht, im Lager wie ein Buchrücken von oben nach unten."""
    return (frame((-W * 0.5, cy, H * 0.5), (0, -1, 0), (0, 0, 1)),
            frame((W * 0.5, cy, H * 0.5), (0, 1, 0), (0, 0, 1)))


def mixed_stripes(parent, fr, a0, a1, b0, b1, name):
    """Misch: die drei Sortenfarben als schräge Streifen nebeneinander."""
    width = (a1 - a0) / 3.0
    for i, s in enumerate(led.MIX):
        x0 = a0 + width * i
        rect(parent, "%s%d" % (name, i), fr, x0, b0, x0 + width, b1, ink(s))


# --- Die drei Entwürfe ---------------------------------------------------------------

def retail(parent, sort, count, quality):
    tab = 0.13
    lb = L - tab
    cy = -tab * 0.5
    body = led.rounded_box(parent, "Karton", (W, lb, H), (0, cy, H * 0.5), board(), 0.012,
                           0.006, 4)
    hollow(parent, body, (W - WALL * 2, lb - WALL * 2, H - WALL * 2), (0, cy, H * 0.5))
    win = (0.74, 0.9)
    wy = cy + lb * 0.5 - 0.06 - win[1] * 0.5
    hole = led.rounded_box(parent, "SchnittFenster", (win[0], win[1], WALL * 4), (0, wy, H),
                           kraft(), 0.03, 0.0, 8)
    cut(body, hole, True)
    led.rounded_box(parent, "Folie", (win[0] + 0.03, win[1] + 0.03, 0.003),
                    (0, wy, H - WALL - 0.002), film(), 0.03, 0.0, 8)
    contents(parent, sort, count, wy, WALL, H - WALL, head_first=False)
    # Die Euro-Lasche verlängert die Rückwand über den Kopf.
    lug = led.rounded_box(parent, "Lasche", (W * 0.46, tab + 0.04, 0.012),
                          (0, L * 0.5 - (tab + 0.04) * 0.5, 0.006), board(), 0.03, 0.003, 6)
    slot = led.rounded_box(parent, "SchnittLasche", (0.17, 0.036, 0.1), (0, L * 0.5 - tab * 0.48, 0),
                           kraft(), 0.017, 0.0, 6)
    cut(lug, slot)
    fr = front_frame()
    foot = lb * 0.5 - cy
    half = W * 0.5
    # Das SORTENBAND schräg am Fuß, darüber eine Haarlinie in der Folie der Güte.
    band = [(0.68, -half), (foot, -half), (foot, half), (0.8, half)]
    if sort == "misch":
        mixed_stripes(parent, fr, 0.68, foot, -half, half, "Band")
    else:
        decal(parent, "Band", fr, band, ink(sort))
    decal(parent, "Haarlinie", fr, [(0.64, -half), (0.655, -half), (0.775, half), (0.76, half)],
          foil(quality))
    text(parent, "FUMBLE", fr, 0.44, 0.36, 0.085, foil(quality), "Marke")
    text(parent, NAMES[sort], fr, 0.44, 0.2, 0.06, ink(sort), "Sorte")
    pips(parent, fr, count, 0.44, 0.02, 0.065, 0.022, white())
    # KOPF (liest im Lager): Rahmen in der Sortenfarbe, die Augen als Säule.
    hf = head_frame(cy + lb * 0.5)
    line = ink(sort if sort != "misch" else "material")
    for name, box in [("RahmenL", (-0.2, -0.5, -0.18, 0.5)), ("RahmenR", (0.18, -0.5, 0.2, 0.5)),
                      ("RahmenO", (-0.2, 0.48, 0.2, 0.5)), ("RahmenU", (-0.2, -0.5, 0.2, -0.48))]:
        rect(parent, "Kopf" + name, hf, *box, line)
    pips(parent, hf, count, 0.0, 0.0, 0.15, 0.04, white(), True, "KopfAuge")
    for i, sf in enumerate(spine_frames(cy)):
        if sort == "misch":
            mixed_stripes(parent, sf, -lb * 0.5, lb * 0.5, -0.07, 0.07, "Ruecken%d" % i)
        else:
            rect(parent, "Ruecken%d" % i, sf, -lb * 0.5, -0.07, lb * 0.5, 0.07, ink(sort))
        for edge in (-1, 1):
            rect(parent, "RueckenFolie%d%d" % (i, edge), sf, -lb * 0.5, edge * 0.085 - 0.006,
                 lb * 0.5, edge * 0.085 + 0.006, foil(quality))
        text(parent, NAMES[sort], sf, -0.25, 0.0, 0.09, black_ink(), "RueckenText%d" % i)


def schuber(parent, sort, count, quality):
    inner = led.rounded_box(parent, "Innenbox", (W - 0.026, L, H - 0.026), (0, 0, H * 0.5),
                            finish(quality), 0.008, 0.004, 4)
    hollow(parent, inner, (W - 0.026 - WALL * 2, L - WALL * 2, H - 0.026 - WALL * 2),
           (0, 0, H * 0.5))
    ls = L - 0.12
    sleeve = led.rounded_box(parent, "Schuber", (W, ls, H), (0, 0, H * 0.5), ink(sort), 0.008,
                             0.004, 4)
    tube = led.rounded_box(parent, "SchnittRohr", (W - 0.024, L + 1.0, H - 0.024), (0, 0, H * 0.5),
                           kraft(), 0.004, 0.0, 4)
    cut(sleeve, tube, True)
    for end in (-1, 1):
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.09, depth=0.05,
                                            location=(0, end * ls * 0.5, H))
        notch = bpy.context.active_object
        notch.name = "SchnittGriff%d" % end
        notch.data.materials.append(kraft())
        notch.parent = parent
        cut(sleeve, notch, True)
    win = (0.74, 0.9)
    wy = 0.2
    hole = led.rounded_box(parent, "SchnittFenster", (win[0], win[1], 0.06), (0, wy, H), kraft(),
                           0.03, 0.0, 8)
    cut(sleeve, hole, True)
    cut(inner, hole, True)
    led.rounded_box(parent, "Folie", (win[0] + 0.03, win[1] + 0.03, 0.003),
                    (0, wy, H - 0.013 - WALL - 0.002), film(), 0.03, 0.0, 8)
    contents(parent, sort, count, wy, 0.013 + WALL, H - 0.013 - WALL, head_first=False)
    fr = front_frame()
    half = W * 0.5
    if sort == "misch":
        mixed_stripes(parent, fr, 0.62, ls * 0.5 - 0.1, -half, -0.3, "Streifen")
    text(parent, "FUMBLE", fr, 0.47, 0.33, 0.085, black_ink(), "Marke")
    text(parent, NAMES[sort], fr, 0.47, 0.17, 0.06, black_ink(), "Sorte")
    rect(parent, "Etikett", fr, 0.3, -0.08, 0.64, 0.04, black_ink())
    pips(parent, fr, count, 0.47, -0.02, 0.065, 0.022, white())
    if quality > 0:
        rect(parent, "Guetestreifen", fr, 0.3, -0.16, 0.64, -0.13, foil(quality))
    # KOPF: die Innenschachtel im Finish der Güte, darauf das schwarze Augen-Etikett.
    hf = head_frame(L * 0.5)
    rect(parent, "KopfEtikett", hf, -0.07, -0.36, 0.07, 0.36, black_ink())
    pips(parent, hf, count, 0.0, 0.0, 0.14, 0.04, white(), True, "KopfAuge")
    for i, sf in enumerate(spine_frames()):
        text(parent, NAMES[sort], sf, 0.0, 0.0, 0.1, black_ink(), "RueckenText%d" % i)


def panorama(parent, sort, count, quality):
    body = led.rounded_box(parent, "Karton", (W, L, H), (0, 0, H * 0.5), board(), 0.012, 0.006, 4)
    hollow(parent, body, (W - WALL * 2, L - WALL * 2, H - WALL * 2), (0, 0, H * 0.5))
    ww, wl, sill = 0.74, 0.95, 0.08
    # Das Fenster läuft über die Kopfkante: Front und Kopf in einem Schnitt.
    hole = led.rounded_box(parent, "SchnittFenster", (ww, wl + 0.1, H),
                           (0, L * 0.5 - wl + (wl + 0.1) * 0.5, sill + H * 0.5), kraft(), 0.03,
                           0.0, 8)
    cut(body, hole, True)
    led.rounded_box(parent, "Folie", (ww + 0.03, wl, 0.003),
                    (0, L * 0.5 - wl * 0.5 - WALL, H - WALL - 0.002), film(), 0.0, 0.0)
    led.rounded_box(parent, "FolieKopf", (ww + 0.03, 0.003, H - sill),
                    (0, L * 0.5 - WALL - 0.002, sill + (H - sill) * 0.5 - WALL * 0.5), film(), 0.0, 0.0)
    contents(parent, sort, count, L * 0.5 - WALL - 0.04 - (CARD[1] + STEP * (count - 1)) * 0.5,
             WALL, H - WALL, head_first=True)
    fr = front_frame()
    half = W * 0.5
    cap = L * 0.5 - 0.36
    if sort == "misch":
        mixed_stripes(parent, fr, cap, L * 0.5, -half, half, "Kappe")
    else:
        rect(parent, "Kappe", fr, cap, -half, L * 0.5, half, ink(sort))
    rect(parent, "Haarlinie", fr, cap - 0.03, -half, cap - 0.015, half, foil(quality))
    text(parent, "FUMBLE", fr, 0.28, 0.36, 0.07, foil(quality), "Marke")
    text(parent, NAMES[sort], fr, 0.28, 0.22, 0.05, ink(sort), "Sorte")
    # Das SIEGEL der Güte: weißes Papier, Silber- oder Goldfolie, die Augen im Kreis.
    dot(parent, "Siegel", fr, 0.28, -0.2, 0.12, foil(quality))
    seal = led.mat("SiegelSchrift", (0.02, 0.02, 0.025), 0.0, 0.5)
    for i in range(count):
        angle = math.tau * i / count + math.pi * 0.5
        dot(parent, "SiegelAuge%d" % i, fr, 0.28 + math.cos(angle) * 0.065,
            -0.2 + math.sin(angle) * 0.065, 0.018, seal).location.z += 0.0015
    hf = head_frame(L * 0.5)
    stripe = ink(sort if sort != "misch" else "material")
    rect(parent, "KopfSeiteL", hf, -H * 0.5, -half, H * 0.5, -0.4, stripe)
    rect(parent, "KopfSeiteR", hf, -H * 0.5, 0.4, H * 0.5, half, stripe)
    pips(parent, hf, count, -H * 0.5 + sill * 0.5, 0.0, 0.12, 0.024, white(), True, "KopfAuge")
    for i, sf in enumerate(spine_frames()):
        # Der Fuß liegt auf der linken Langseite bei +a, auf der rechten bei -a.
        side = 1.0 if i == 0 else -1.0
        a0, a1 = sorted((side * L * 0.5, side * (L * 0.5 - 0.36)))
        if sort == "misch":
            mixed_stripes(parent, sf, a0, a1, -H * 0.5, H * 0.5, "RueckenKappe%d" % i)
        else:
            rect(parent, "RueckenKappe%d" % i, sf, a0, -H * 0.5, a1, H * 0.5, ink(sort))
        b0, b1 = sorted((-side * L * 0.5, side * (L * 0.5 - 0.36)))
        rect(parent, "RueckenLinie%d" % i, sf, b0, -0.01, b1, 0.01, stripe)
    rect(parent, "FussKappe", foot_frame(-L * 0.5), -H * 0.5, -half, H * 0.5, half,
         ink(sort if sort != "misch" else "material"))


DESIGNS = [("retail", retail), ("schuber", schuber), ("panorama", panorama)]
LAGER = led.PACKS + [("rune", 3, 0), ("zahl", 5, 2), ("misch", 3, 1), ("material", 5, 0)]


# --- Bühnen ---------------------------------------------------------------------------

def show(build, view):
    led.stage(build, False, view == "nah")
    roots = sorted([o for o in bpy.data.objects if o.name.startswith("Paket")],
                   key=lambda o: o.name)
    cam = bpy.context.scene.camera
    aim = cam.constraints[0].target
    quer = Matrix.Rotation(math.pi * 0.5, 4, "Z")
    if view == "laden":
        # Quer wie im Laden: Kopf links, Fuß rechts, zwei mal zwei.
        for i, root in enumerate(roots):
            at = Vector(((i % 2 - 0.5) * (L + 0.35), (0.5 - i // 2) * (W + 0.35), 0.001))
            root.matrix_world = Matrix.Translation(at) @ quer
        cam.location = (0.0, -4.6, 6.4)
    elif view == "nah":
        roots[0].matrix_world = quer
    else:
        # Das LAGER: hochkant in der Rinne, Kopf oben, die Fläche nach Bild-rechts; die
        # Kamera sieht wie die Lager-Station von oben und etwas von der Langseite.
        for i, (sort, count, quality) in enumerate(LAGER[len(roots):]):
            bpy.ops.object.empty_add()
            root = bpy.context.active_object
            root.name = "Paket%d" % (len(roots) + i)
            build(root, sort, count, quality)
            roots.append(root)
        stand = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, L * 0.5), (0, 0, 0, 1)))
        pitch = H + 0.09
        for i, root in enumerate(roots):
            x = (i - (len(roots) - 1) * 0.5) * pitch - H * 0.5
            root.matrix_world = Matrix.Translation((x, 0, 0)) @ stand
        # Eevee zeigt die Softboxen der Kamera: hoch über sie damit.
        for o in bpy.data.objects:
            if o.data is not None and getattr(o.data, "materials", None)                     and o.data.materials[0] is not None and o.data.materials[0].name.startswith("Softbox"):
                o.location.z += 8.0
        aim.location = (0, 0, L * 0.8)
        direction = Vector((0, -0.44, 0.9)).normalized()
        cam.location = aim.location + direction * (8.5 if view == "lager" else 4.2)
        if view == "lager_nah":
            aim.location.x = roots[1].matrix_world.translation.x + H * 0.5


def render(only=""):
    os.makedirs(OUT, exist_ok=True)
    for name, build in DESIGNS:
        if only and name != only:
            continue
        for view in ("laden", "lager", "lager_nah", "nah"):
            show(build, view)
            bpy.context.scene.render.filepath = os.path.join(OUT, "%s_%s.png" % (name, view))
            bpy.ops.render.render(write_still=True)
    print("ok")


# Als Modul (blender_card_box_export.py) liefert es nur die Werkzeuge.
if __name__ == "__main__":
    render(sys.argv[sys.argv.index("--") + 2] if "--" in sys.argv
           and len(sys.argv) > sys.argv.index("--") + 2 else "")
