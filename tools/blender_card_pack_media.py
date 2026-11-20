"""Fumble: KARTEN-PAKETE je SORTE, jedes aus der Welt seines Datenträgers (Spieler-Wunsch
2026-11-20: getrennte Pakete je Kartensorte statt der einen Retail-Schachtel). Je Sorte drei
Entwürfe, alle im Grundriß und in der Dicke des heutigen Pakets:
  ZAHLEN (Lochkarte)     kartenkasten · streifband · lochtasche
  MATERIAL (Kassette)    klappbox · mehrfachpack · kassettenfach
  RUNEN (Tontafel)       fundkiste · tonhuelle · museumskasten
  SONDER (Service-Modul) blister · tray · einschub
Die Kartenzahl steht als Marke im Bild des Mediums (Stanzloch, Spule, Keil, LED), die Güte
als weißer Druck, Silber oder Gold. In den Paketen liegen die echten Träger-Modelle.

Aufruf (kopflos):
  blender -b -P tools/blender_card_pack_media.py -- <ausgabe-ordner> [sorte]
Achsen: X = Breite, Y = Länge (Kopf +Y), Z = Höhe, Ursprung = Mitte unten; im Bild liegt das
Paket quer wie im Laden (Kopf links).
"""
import bpy, math, os, random, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_card_cassette_glass as shape
import blender_card_box as box
import blender_data_media as dm
import blender_data_media_export as em

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
MODELS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets",
                      "models", "hardware")
W, L, H = box.W, box.L, box.H
HW, HL = W * 0.5, L * 0.5
RB = led.rounded_box
PI = math.pi
# Der Export (blender_card_pack_export.py) baut nur die HÜLLE: die Karten legt Godot hinein.
EXPORT = False

led.SORTS["sonder"] = led.lin("#bd93f9")
box.NAMES["sonder"] = "SONDER"
GLB = {"zahl": "data_punch_card", "material": "data_cassette", "rune": "data_clay_tablet",
       "sonder": "data_service_module"}
TOPS = {"zahl": 0.04, "material": 0.126, "rune": 0.128, "sonder": 0.034}
STACK = {"zahl": ((0.74, 0.7, 0.63), (0.4, 0.37, 0.32)),
         "material": ((0.02, 0.02, 0.024), (0.16, 0.16, 0.18)),
         "rune": ((0.5, 0.42, 0.31), (0.24, 0.19, 0.13)),
         "sonder": ((0.02, 0.02, 0.026), (0.3, 0.21, 0.08))}


# --- Materialien ------------------------------------------------------------------------

def greyboard():
    return led.mat("Graupappe", (0.3, 0.29, 0.27), 0.0, 0.92)


def manila():
    return led.mat("Manila", (0.74, 0.68, 0.55), 0.0, 0.85)


def paper():
    return led.mat("Papier", (0.8, 0.77, 0.7), 0.0, 0.8, 0.12)


def plastic():
    return led.mat("Kunststoff", (0.012, 0.012, 0.015), 0.0, 0.32, clearcoat=0.6)


def wood():
    return led.mat("Holz", (0.33, 0.2, 0.1), 0.0, 0.8)


def clay():
    return led.mat("Brandton", (0.4, 0.25, 0.16), 0.0, 0.95)


def clear(name, alpha, tint=(0.85, 0.9, 1.0)):
    """Klarsicht ohne Rauschen (BLEND statt HASHED)."""
    return led.mat("Klar_" + name, tint, 0.0, 0.03, 0.0, alpha, 1.0)


def film():
    return led.mat("Schrumpffolie", (0.85, 0.9, 1.0), 0.0, 0.03, 0.0, 0.06, 1.0)


def glow(sort, e=1.2):
    return led.sort_mat(sort, e)


def foil_on_light(q):
    return box.black_ink() if q == 0 else box.foil(q)


# --- Werkzeuge --------------------------------------------------------------------------

def top(z):
    return box.frame((0, 0, z), (0, -1, 0), (1, 0, 0))


def poly(parent, name, fr, pts, material, lift=box.EPS):
    o, u, v, n = fr
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(o + u * a + v * b + n * lift) for a, b in pts], [],
                     [list(range(len(pts)))])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj.parent = parent
    return obj


def disc(parent, name, fr, a, b, r, material, lift=box.EPS):
    return poly(parent, name, fr, [(a + math.cos(math.tau * i / 28) * r,
                                    b + math.sin(math.tau * i / 28) * r) for i in range(28)],
                material, lift)


def strip(parent, name, fr, a0, a1, b0, b1, material, lift=box.EPS):
    return poly(parent, name, fr, [(a0, b0), (a1, b0), (a1, b1), (a0, b1)], material, lift)


def cyl(parent, name, r, depth, loc, material, rot=(0, 0, 0), verts=40):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc,
                                        rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    o.data.use_auto_smooth = True
    o.data.auto_smooth_angle = math.radians(50)
    o.parent = parent
    return o


def shell(parent, name, size, loc, material, corner, edge, wall):
    """Eine nach unten offene Haube mit dünner Wand."""
    o = RB(parent, name, size, loc, material, corner, edge, 8)
    box.cut(o, RB(parent, "Schnitt" + name, (size[0] - wall * 2, size[1] - wall * 2, size[2]),
                  (loc[0], loc[1], loc[2] - wall), material, max(corner - wall, 0.0), 0.0, 6))
    return o


def band(parent, name, y, width, material, proud=0.006):
    """Eine Banderole rings um das Paket, quer zur Länge."""
    o = RB(parent, name, (W + proud * 2, width, H + proud * 2), (0, y, H * 0.5), material, 0.0,
           0.003, 2)
    box.cut(o, RB(parent, "Schnitt" + name, (W, width + 0.2, H), (0, y, H * 0.5), material, 0.0,
                  0.0, 2))
    return o


def marks(parent, fr, sort, count, a, b, pitch, size, material, along_v=False, name="Zahl"):
    """Die KARTENZAHL im Bild des Mediums: Stanzloch, Spule, Keil, LED."""
    for i in range(count):
        t = (i - (count - 1) * 0.5) * pitch
        ca, cb = (a, b + t) if along_v else (a + t, b)
        tag = "%s%d" % (name, i)
        if sort == "zahl":
            strip(parent, tag, fr, ca - size * 0.24, ca + size * 0.24, cb - size * 0.5,
                  cb + size * 0.5, material)
        elif sort == "material":
            disc(parent, tag, fr, ca, cb, size * 0.5, material)
            disc(parent, tag + "Nabe", fr, ca, cb, size * 0.2, box.black_ink(), box.EPS * 2)
        elif sort == "rune":
            poly(parent, tag, fr, [(ca - size * 0.36, cb + size * 0.5),
                                   (ca, cb + size * 0.08), (ca + size * 0.36, cb + size * 0.5)],
                 material)
            strip(parent, tag + "Stiel", fr, ca - size * 0.07, ca + size * 0.07, cb - size * 0.5,
                  cb + size * 0.2, material)
        else:
            disc(parent, tag, fr, ca, cb, size * 0.36, material)


def label(parent, fr, sort, count, a, b, size, brand, name, mark, mark_sort=None):
    box.text(parent, "FUMBLE", fr, a, b, size, brand, "Marke")
    box.text(parent, box.NAMES[sort], fr, a, b - size * 1.9, size * 0.72, name, "Sorte")
    marks(parent, fr, mark_sort or sort, count, a, b - size * 4.6, size * 1.15, size * 0.95, mark)


def carrier(parent, sort, loc, s, net=True, seed=0):
    """Ein echter Datenträger, liegend, Kopf zum Kopf des Pakets; loc = Mitte seiner Grundfläche."""
    if EXPORT:
        return None
    bpy.ops.object.empty_add(location=loc, rotation=(0, 0, -PI * 0.5))
    holder = bpy.context.active_object
    holder.name = "Traeger"
    holder.scale = (s, s, s)
    holder.parent = parent
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, GLB[sort] + ".glb"))
    for o in list(bpy.context.selected_objects):
        if o.parent is None:
            o.parent = holder
    if net:
        z = TOPS[sort] + 0.003
        dark = led.mat("NetzDunkel", (0.01, 0.01, 0.014), 0.0, 0.5)
        for k, (cx, cy) in enumerate(em.CELLS):
            lit = ((seed * 5 + k * 3) % 7) < 2
            RB(holder, "NetzSaum%d" % k, (em.C, em.C, 0.003), (cx, cy, z), glow(sort, 1.3), 0.02,
               0.0, 3)
            RB(holder, "NetzZelle%d" % k, (em.C * 0.88, em.C * 0.88, 0.003), (cx, cy, z + 0.002),
               glow(sort, 0.7) if lit else dark, 0.015, 0.0, 3)
    return holder


def block(parent, sort, s, cy, z0, z1, pitch=None):
    """Ein Stapel als Klotz mit Fugen - die Karten unter der obersten."""
    if z1 - z0 < 0.004:
        return
    body, seam = STACK[sort]
    size = (1.08 * s, 1.62 * s)
    RB(parent, "Stapel", (size[0], size[1], z1 - z0), (0, cy, (z0 + z1) * 0.5),
       led.mat("Stapel_" + sort, body, 0.0, 0.8), 0.02, 0.0, 3)
    pitch = pitch or TOPS[sort] * s
    z = z1 - pitch
    while z > z0 + 0.002:
        RB(parent, "Fuge", (size[0] + 0.003, size[1] + 0.003, 0.003), (0, cy, z),
           led.mat("Fuge_" + sort, seam, 0.0, 0.8), 0.02, 0.0, 3)
        z -= pitch


def deck(parent, sort, count, cy, z_top, s, step=0.0, floor=None, pitch=None):
    """COUNT Träger als Stapel bis z_top. step > 0 staffelt sie zum Fuß (alle echt), sonst
    liegt nur der oberste echt auf einem Klotz. floor füllt den Klotz bis zum Boden."""
    t = pitch or TOPS[sort] * s
    for i in range(count):
        z = z_top - TOPS[sort] * s - t * (count - 1 - i)
        if step > 0.0 or i == count - 1:
            y = cy - (i - (count - 1) * 0.5) * step
            carrier(parent, sort, (0, y, z), s, i == count - 1, count + i)
    low = z_top - TOPS[sort] * s - t * (count - 1)
    if EXPORT:
        # Nur die Lochtasche trägt einen festen Stapel unter den echten Karten.
        if sort == "zahl" and floor is not None:
            block(parent, sort, s, cy, floor, z_top - t * 5)
        return low
    if step == 0.0:
        block(parent, sort, s, cy, low if floor is None else floor, z_top - TOPS[sort] * s)
    return low


# --- ZAHLEN: die Lochkarte ---------------------------------------------------------------

def kartenkasten(parent, sort, count, quality):
    """Der offene Karton-Kasten eines Kartenstapels, Daumenkerben, Banderole am Fuß."""
    tray = RB(parent, "Kasten", (W, L, H), (0, 0, H * 0.5), greyboard(), 0.012, 0.004, 4)
    box.cut(tray, RB(parent, "SchnittInnen", (W - 0.07, L - 0.07, H), (0, 0, 0.03 + H * 0.5),
                     box.kraft(), 0.006, 0.0, 4), True)
    for s in (-1, 1):
        box.cut(tray, cyl(parent, "SchnittKerbe%d" % s, 0.17, 0.2, (s * HW, 0.2, H), box.kraft(),
                          (0, PI * 0.5, 0)), True)
    deck(parent, sort, count, 0.0, H - 0.03, 0.9, 0.0, 0.03)
    band(parent, "Banderole", -0.63, 0.42, box.ink(sort))
    fr = top(H + 0.006)
    label(parent, fr, sort, count, 0.63, 0.33, 0.07, box.black_ink(), box.black_ink(),
          box.black_ink())
    for k, a in enumerate((0.44, 0.82)):
        strip(parent, "Folie%d" % k, fr, a - 0.007, a + 0.007, -HW - 0.006, HW + 0.006,
              foil_on_light(quality))


def streifband(parent, sort, count, quality):
    """Kein Kasten: der gestaffelte Stapel auf Rückpappe, Streifband am Fuß, Folie darum."""
    back = RB(parent, "Rueckpappe", (W, L, 0.03), (0, 0, 0.015), greyboard(), 0.012, 0.0, 4)
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(-HW, HL, 0), rotation=(0, 0, PI * 0.25))
    corner = bpy.context.active_object
    corner.name = "SchnittEcke"
    corner.parent = parent
    box.cut(back, corner)
    low = deck(parent, sort, count, 0.03, H - 0.012, 0.93, 0.035)
    block(parent, sort, 0.93, 0.03 + 0.035 * (count - 1) * 0.5, 0.03, low)
    band(parent, "Streifband", -0.63, 0.42, box.ink(sort), 0.005)
    RB(parent, "Folie", (W, L, H), (0, 0, H * 0.5), film(), 0.02, 0.012, 4)
    fr = top(H + 0.005)
    label(parent, fr, sort, count, 0.63, 0.33, 0.07, box.black_ink(), box.black_ink(),
          box.black_ink())
    strip(parent, "Folienlinie", fr, 0.435, 0.449, -HW, HW, foil_on_light(quality))
    for i, sf in enumerate(box.spine_frames()):
        side = -1.0 if i == 0 else 1.0
        box.text(parent, box.NAMES[sort], box.frame(sf[0] + sf[3] * 0.001, sf[1], sf[2]),
                 side * -0.63, 0.0, 0.09, box.black_ink(), "Seite%d" % i)


def lochtasche(parent, sort, count, quality):
    """Die Manila-Tasche: schräg aufgeschnitten, die Kartenzahl als ECHTE Stanzlöcher, durch
    die der grüne Grund scheint."""
    body = RB(parent, "Tasche", (W, L, H), (0, 0, H * 0.5), manila(), 0.012, 0.004, 4)
    box.hollow(parent, body, (W - 0.03, L - 0.03, H - 0.03), (0, 0, H * 0.5))
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.25, 0.66, H),
                                    rotation=(0, 0, math.radians(-24)))
    slant = bpy.context.active_object
    slant.name = "SchnittSchraege"
    slant.scale = (2.2, 1.0, 0.2)
    slant.data.materials.append(box.kraft())
    slant.parent = parent
    box.cut(body, slant, True)
    deck(parent, sort, count, 0.0, H - 0.036, 0.9, 0.0, 0.015)
    RB(parent, "Leuchtgrund", (W - 0.06, 0.5, 0.004), (0, -0.56, H - 0.022), glow(sort, 2.6), 0.0,
       0.0, 2)
    for i in range(count):
        a = 0.6 + (i - (count - 1) * 0.5) * 0.085
        box.cut(body, RB(parent, "SchnittLoch%d" % i, (0.13, 0.042, 0.06), (-0.2, -a, H),
                         box.kraft(), 0.0, 0.0, 2), True)
    fr = top(H)
    ink = led.mat("Stempeltinte", (0.05, 0.04, 0.035), 0.0, 0.8)
    box.text(parent, "FUMBLE", fr, 0.6, 0.36, 0.07, ink, "Marke")
    box.text(parent, box.NAMES[sort], fr, 0.6, 0.22, 0.05, ink, "Sorte")
    box.text(parent, "0 1 2 3 4 5 6 7 8 9", fr, 0.6, 0.06, 0.036, ink, "Ziffern")
    box.text(parent, "0 1 2 3 4 5 6 7 8 9", fr, 0.6, -0.4, 0.036, ink, "ZiffernUnten")
    strip(parent, "Sortenband", fr, 0.79, HL - 0.012, -HW + 0.012, HW - 0.012, box.ink(sort))
    strip(parent, "Folienlinie", fr, 0.765, 0.777, -HW + 0.012, HW - 0.012,
          foil_on_light(quality))
    for i, sf in enumerate(box.spine_frames()):
        box.rect(parent, "Seitenband%d" % i, sf, -HL + 0.012, -0.05, HL - 0.012, 0.05,
                 box.ink(sort))


# --- MATERIAL: die Kassette --------------------------------------------------------------

def klappbox(parent, sort, count, quality):
    """Die klare Klappbox mit Einleger: der Kassetten-Stapel liegt offen darin, seine Höhe
    IST die Zahl."""
    RB(parent, "Schale", (W - 0.02, L - 0.02, 0.012), (0, 0, 0.006), plastic(), 0.03, 0.0, 6)
    shell(parent, "Box", (W, L, H), (0, 0, H * 0.5), clear("Klarbox", 0.1), 0.03, 0.012,
          0.008)
    s = 0.72
    deck(parent, sort, count, 0.2, 0.014 + TOPS[sort] * s * count, s, 0.045)
    RB(parent, "Einleger", (W - 0.03, 0.44, 0.004), (0, -0.61, H - 0.012), box.ink(sort), 0.0,
       0.0, 2)
    RB(parent, "EinlegerRuecken", (W - 0.03, 0.004, H - 0.03), (0, -HL + 0.012, H * 0.5),
       box.ink(sort), 0.0, 0.0, 2)
    for s_ in (-1, 1):
        cyl(parent, "Scharnier%d" % s_, 0.022, 0.05, (s_ * (HW - 0.04), HL - 0.02, 0.03),
            clear("Klarbox", 0.1), (0, PI * 0.5, 0), 16)
    fr = top(H)
    label(parent, fr, sort, count, 0.62, 0.33, 0.07, box.black_ink(), box.black_ink(),
          box.black_ink())
    for k, a in enumerate((0.41, 0.815)):
        strip(parent, "Folie%d" % k, fr, a - 0.006, a + 0.006, -HW + 0.02, HW - 0.02,
              foil_on_light(quality))
    ff = box.foot_frame(-HL)
    box.text(parent, "FUMBLE  " + box.NAMES[sort], box.frame(ff[0], (1, 0, 0), (0, 0, 1)), 0.0,
             0.0, 0.1, box.black_ink(), "Ruecken")


def mehrfachpack(parent, sort, count, quality):
    """Der eingeschweißte Mehrfachpack: Kartonhülse mit zwei Spulenfenstern und Schreibfeld,
    an beiden Enden schaut der Stapel heraus."""
    s = 0.72
    deck(parent, sort, count, 0.0, 0.012 + TOPS[sort] * s * count, s, 0.0, 0.012)
    sleeve = RB(parent, "Huelse", (W, 0.86, H), (0, 0, H * 0.5), box.board(), 0.01, 0.004, 4)
    box.cut(sleeve, RB(parent, "SchnittRohr", (W - 0.03, L + 1.0, H - 0.03), (0, 0, H * 0.5),
                       box.kraft(), 0.004, 0.0, 4), True)
    fr = top(H)
    for i, y in enumerate((0.25, -0.25)):
        box.cut(sleeve, cyl(parent, "SchnittSpule%d" % i, 0.15, 0.2, (-0.12, y, H), box.kraft()),
                True)
        ring = cyl(parent, "Spulenring%d" % i, 0.175, 0.004, (-0.12, y, H + 0.002), box.ink(sort))
        box.cut(ring, cyl(parent, "SchnittRing%d" % i, 0.152, 0.1, (-0.12, y, H), box.kraft()))
    strip(parent, "Schreibfeld", fr, -0.39, 0.39, 0.2, 0.47, paper())
    box.text(parent, "FUMBLE · " + box.NAMES[sort], fr, 0.0, 0.385, 0.062, box.black_ink(),
             "Marke")
    for k in range(2):
        strip(parent, "Zeile%d" % k, fr, -0.34, 0.34, 0.262 - k * 0.04, 0.266 - k * 0.04,
              box.black_ink(), box.EPS * 2)
    strip(parent, "Sortenstreif", fr, -0.43, 0.43, -0.4, -0.34, box.ink(sort))
    marks(parent, fr, sort, count, 0.0, -0.47, 0.09, 0.075, box.foil(quality))
    for k, a in enumerate((-0.415, 0.415)):
        strip(parent, "Folie%d" % k, fr, a - 0.006, a + 0.006, -HW, HW, box.foil(quality))
    for i, sf in enumerate(box.spine_frames()):
        box.rect(parent, "Seitenstreif%d" % i, sf, -0.43, -0.07, 0.43, 0.07, box.ink(sort))
        box.text(parent, box.NAMES[sort], sf, 0.0, 0.0, 0.09, box.black_ink(), "Seite%d" % i)
    RB(parent, "Folie", (W - 0.006, L, H - 0.006), (0, 0, H * 0.5), film(), 0.02, 0.012, 4)


def kassettenfach(parent, sort, count, quality):
    """Das Paket ist das Kassettenfach eines Decks: Rauchglas-Klappe über dem Stapel, fünf
    Laufwerkstasten am Fuß - so viele leuchten, wie Kassetten darin sind."""
    body = RB(parent, "Gehaeuse", (W, L, H), (0, 0, H * 0.5), plastic(), 0.05, 0.02, 8)
    pocket = (0.86, 1.22)
    py = 0.17
    box.cut(body, RB(parent, "SchnittFach", (pocket[0], pocket[1], H), (0, py, 0.02 + H * 0.5),
                     plastic(), 0.03, 0.0, 6))
    s = 0.72
    deck(parent, sort, count, py, 0.024 + TOPS[sort] * s * count, s, 0.0, 0.024)
    RB(parent, "Klappe", (pocket[0] + 0.02, pocket[1] + 0.02, 0.01), (0, py, H - 0.007),
       clear("Rauchglas", 0.22, (0.25, 0.25, 0.3)), 0.03, 0.0, 6)
    led.frame_ring(parent, "Rahmen", (pocket[0] + 0.07, pocket[1] + 0.07),
                   (pocket[0] + 0.005, pocket[1] + 0.005), H + 0.002, 0.012, led.metal(quality),
                   0.03, py)
    for i in range(5):
        on = i < count
        RB(parent, "Taste%d" % i, (0.15, 0.2, 0.05), ((i - 2) * 0.185, -0.66, H + 0.004 + (0 if on else 0.012)),
           glow(sort, 1.4) if on else led.mat("TasteAus", (0.05, 0.05, 0.06), 0.3, 0.3,
                                               clearcoat=0.6), 0.02, 0.012, 4)
    RB(parent, "Naht", (W + 0.006, L + 0.006, 0.012), (0, 0, H * 0.42), glow(sort, 1.6), 0.052,
       0.0, 8)
    for i, sf in enumerate(box.spine_frames()):
        box.text(parent, "FUMBLE  " + box.NAMES[sort], box.frame(sf[0] + Vector((0, 0, 0.13)),
                 sf[1], sf[2]), 0.0, 0.0, 0.08, box.foil(quality), "Seite%d" % i)
    fr = top(H)
    box.text(parent, "FUMBLE", fr, -0.36, 0.5, 0.045, box.foil(quality), "Marke")
    box.text(parent, box.NAMES[sort], fr, 0.2, 0.5, 0.045, box.ink(sort), "Sorte")


# --- RUNEN: die Tontafel -----------------------------------------------------------------

def fundkiste(parent, sort, count, quality):
    """Die Fundkiste: Latten, Holzwolle, die oberste Tafel liegt offen; Schablonenschrift."""
    hb = H - 0.03
    crate = RB(parent, "Kiste", (W, L, hb), (0, 0, hb * 0.5), wood(), 0.006, 0.003, 2)
    box.cut(crate, RB(parent, "SchnittInnen", (W - 0.09, L - 0.09, H), (0, 0, 0.04 + H * 0.5),
                      wood(), 0.0, 0.0, 2))
    for k in range(1, 3):
        for s in (-1, 1):
            RB(parent, "Fuge", (0.003, L + 0.002, 0.006), (s * HW, 0, hb * k / 3.0),
               led.mat("Holzfuge", (0.08, 0.045, 0.02), 0.0, 0.9), 0.0, 0.0, 2)
    s_ = 0.72
    z_top = hb - 0.03
    low = deck(parent, sort, count, 0.12, z_top, s_, 0.0)
    bed = max(low + 0.04, 0.1)
    RB(parent, "Wolle", (W - 0.09, L - 0.09, bed - 0.04), (0, 0, 0.04 + (bed - 0.04) * 0.5),
       led.mat("Holzwolle", (0.5, 0.39, 0.19), 0.0, 0.95), 0.0, 0.0, 2)
    rnd = random.Random(count * 7 + quality)
    straw = led.mat("Halm", (0.72, 0.6, 0.33), 0.0, 0.9)
    for i in range(110):
        x, y = rnd.uniform(-HW + 0.1, HW - 0.1), rnd.uniform(-HL + 0.1, HL - 0.1)
        inside = abs(x) < 0.54 * s_ - 0.03 and abs(y - 0.12) < 0.81 * s_ - 0.03
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, (z_top if inside else bed) + 0.008
                                                           + rnd.uniform(0, 0.02)),
                                        rotation=(rnd.uniform(-0.15, 0.15), 0, rnd.uniform(0, PI)))
        h = bpy.context.active_object
        h.name = "Halm"
        h.scale = (rnd.uniform(0.12, 0.3), 0.012, 0.006)
        h.data.materials.append(straw)
        h.parent = parent
        if inside and rnd.random() < 0.8:
            bpy.data.objects.remove(h)
    for name, y, w in (("LatteKopf", 0.735, 0.2), ("LatteFuss", -0.62, 0.44)):
        RB(parent, name, (W, w, 0.03), (0, y, H - 0.015), wood(), 0.004, 0.003, 2)
    fr = top(H)
    burn = led.mat("Brandstempel", (0.05, 0.028, 0.012), 0.0, 0.9)
    label(parent, fr, sort, count, 0.62, 0.3, 0.075, burn, box.ink(sort), box.ink(sort))
    for sx in (-1, 1):
        for y in (0.735, -0.735):
            RB(parent, "Winkel", (0.13, 0.17, 0.008), (sx * (HW - 0.065), y, H + 0.004),
               led.metal(quality), 0.01, 0.002, 2)
            cyl(parent, "Nagel", 0.014, 0.006, (sx * (HW - 0.065), y, H + 0.01), led.CHROME,
                (0, 0, 0), 12)


def jagged(parent, name, cx, cy, rx, ry, z0, z1, seed, n=16):
    rnd = random.Random(seed)
    ring = []
    for i in range(n):
        t, k = math.tau * i / n, rnd.uniform(0.74, 1.0)
        ring.append((cx + math.cos(t) * rx * k, cy + math.sin(t) * ry * k))
    verts = [(x, y, z0) for x, y in ring] + [(x, y, z1) for x, y in ring]
    faces = [list(range(n - 1, -1, -1)), list(range(n, 2 * n))]
    faces += [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(led.mat("Bruch", (0.55, 0.36, 0.24), 0.0, 0.95))
    o.parent = parent
    return o


def tonhuelle(parent, sort, count, quality):
    """Die Tonhülle, in der Tafeln einst versiegelt wurden: aufgebrochen, die Tafel liegt im
    Bruch; die Zahl als leuchtende Keile, die Güte als Siegel."""
    body = RB(parent, "Huelle", (W, L, H), (0, 0, H * 0.5), clay(), 0.16, 0.09, 10)
    box.cut(body, RB(parent, "SchnittHohl", (W - 0.14, L - 0.14, H - 0.1), (0, 0, H * 0.5),
                     clay(), 0.11, 0.05, 8), True)
    box.cut(body, jagged(parent, "SchnittBruch", 0.02, 0.2, 0.44, 0.6, H - 0.2, H + 0.1,
                         count * 3 + 1), True)
    deck(parent, sort, count, 0.2, H - 0.075, 0.72, 0.0, 0.05)
    fr = top(H)
    press = led.mat("Eindruck", (0.16, 0.09, 0.05), 0.0, 0.95)
    box.text(parent, "FUMBLE", fr, 0.58, 0.3, 0.06, press, "Marke")
    box.text(parent, box.NAMES[sort], fr, 0.58, 0.18, 0.045, press, "Sorte")
    marks(parent, fr, sort, count, 0.58, 0.0, 0.075, 0.13, glow(sort, 1.6))
    rnd = random.Random(11)
    for i in range(26):
        a = -0.7 + i * 1.4 / 25
        for b in (-0.45, 0.45):
            if abs(a - 0.58) < 0.3 and b > 0:
                continue
            ang = rnd.choice((0, 1, 2, 3)) * PI * 0.5
            poly(parent, "Keil", fr, [(a + math.cos(ang + d) * r, b + math.sin(ang + d) * r)
                                      for d, r in ((0, 0.022), (2.5, 0.014), (-2.5, 0.014))],
                 press)
    seal = clay() if quality == 0 else led.metal(quality)
    cyl(parent, "Siegel", 0.1, 0.03, (-0.3, -0.58, H + 0.008), seal)
    cyl(parent, "SiegelKern", 0.06, 0.008, (-0.3, -0.58, H + 0.024), press)
    marks(parent, top(H + 0.0285), sort, 1, 0.58, -0.3, 0.0, 0.08, glow(sort, 1.6), name="Siegelkeil")


def museumskasten(parent, sort, count, quality):
    """Der Fundkasten der Sammlung: Schaum mit Ausschnitt, Maßstab, Inventar-Etikett,
    Klarsicht-Deckel."""
    tray = RB(parent, "Kasten", (W, L, H), (0, 0, H * 0.5), box.board(), 0.012, 0.004, 4)
    box.cut(tray, RB(parent, "SchnittInnen", (W - 0.05, L - 0.05, H), (0, 0, 0.03 + H * 0.5),
                     box.kraft(), 0.006, 0.0, 4))
    ft = H - 0.04
    foam = RB(parent, "Schaum", (W - 0.056, L - 0.056, ft - 0.03), (0, 0, (ft + 0.03) * 0.5),
              led.mat("Schaum", (0.045, 0.045, 0.05), 0.0, 1.0), 0.004, 0.0, 2)
    s = 0.72
    py = 0.2
    depth = min(TOPS[sort] * s * count + 0.01, ft - 0.05)
    box.cut(foam, RB(parent, "SchnittMulde", (1.08 * s + 0.05, 1.62 * s + 0.05, depth * 2),
                     (0, py, ft), box.kraft(), 0.05, 0.0, 6))
    box.cut(foam, cyl(parent, "SchnittGriff", 0.11, depth * 2, (0.54 * s + 0.02, py, ft),
                      box.kraft()))
    deck(parent, sort, count, py, ft - 0.012, s, 0.0, ft - depth)
    RB(parent, "Deckel", (W - 0.052, L - 0.052, 0.008), (0, 0, H - 0.004),
       clear("Deckelglas", 0.07), 0.006, 0.0, 4)
    fr = top(ft)
    for i in range(8):
        strip(parent, "Massstab%d" % i, fr, -0.26 + i * 0.1, -0.16 + i * 0.1, -0.5, -0.455,
              box.white() if i % 2 == 0 else box.black_ink())
    strip(parent, "Etikett", fr, 0.47, 0.79, -0.47, 0.47, paper())
    strip(parent, "EtikettBand", fr, 0.47, 0.79, 0.4, 0.47, box.ink(sort), box.EPS * 2)
    ink = box.black_ink()
    box.text(parent, "FUMBLE", fr, 0.63, 0.3, 0.055, ink, "Marke")
    box.text(parent, box.NAMES[sort], fr, 0.63, 0.19, 0.045, ink, "Sorte")
    marks(parent, fr, sort, count, 0.63, 0.0, 0.055, 0.11, ink)
    box.text(parent, "INV. %02d-%d" % (17 + count * 3, quality + 1), fr, 0.63, -0.2, 0.035, ink,
             "Inventar")
    strip(parent, "EtikettFolie", fr, 0.5, 0.76, -0.4, -0.385, foil_on_light(quality),
          box.EPS * 2)
    lid = top(H)
    for sa in (-1, 1):
        for sb in (-1, 1):
            a, b = sa * (HL - 0.03), sb * (HW - 0.03)
            poly(parent, "Ecke", lid, [(a, b), (a - sa * 0.14, b), (a, b - sb * 0.14)],
                 box.foil(quality))
    RB(parent, "Naht", (W + 0.006, L + 0.006, 0.014), (0, 0, H * 0.5), glow(sort, 1.2), 0.014,
       0.0, 4)


# --- SONDERBESTAND: das Service-Modul ----------------------------------------------------

def blister(parent, sort, count, quality):
    """Die Blister-Karte des Ersatzteils: Euro-Loch am Kopf, die Module gestaffelt unter
    der klaren Haube."""
    card = RB(parent, "Karte", (W, L, 0.02), (0, 0, 0.01), box.board(), 0.03, 0.0, 6)
    box.cut(card, RB(parent, "SchnittEuro", (0.2, 0.04, 0.1), (0, 0.775, 0), box.kraft(), 0.019,
                     0.0, 6))
    by, bl = -0.2, 1.26
    RB(parent, "Flansch", (W - 0.03, bl + 0.06, 0.004), (0, by, 0.022),
       clear("Blister", 0.1), 0.06, 0.0, 6)
    shell(parent, "Haube", (W - 0.09, bl, H - 0.02), (0, by, 0.02 + (H - 0.02) * 0.5),
          clear("Blister", 0.1), 0.08, 0.05, 0.006)
    s = 0.72
    low = deck(parent, sort, count, by, 0.14 + 0.055 * (count - 1) + TOPS[sort] * s, s, 0.06,
               None, 0.055)
    RB(parent, "Sockel", (0.5, 0.9, low - 0.02), (0, by, 0.02 + (low - 0.02) * 0.5),
       clear("Blister", 0.1), 0.05, 0.01, 6)
    fr = top(0.02)
    strip(parent, "Kopf", fr, -HL + 0.02, -0.46, -HW + 0.02, HW - 0.02, box.ink(sort))
    box.text(parent, "FUMBLE", fr, -0.665, 0.33, 0.06, box.black_ink(), "Marke")
    box.text(parent, box.NAMES[sort], fr, -0.665, -0.33, 0.06, box.black_ink(), "Sorte")
    marks(parent, fr, sort, count, -0.55, 0.0, 0.09, 0.11, box.black_ink(), True)
    strip(parent, "EuroLoch", fr, -0.795, -0.755, -0.1, 0.1, box.black_ink(), box.EPS * 2)
    strip(parent, "Folienlinie", fr, -0.455, -0.441, -HW + 0.02, HW - 0.02, box.foil(quality))
    for k in range(14):
        strip(parent, "Strichcode%d" % k, fr, 0.72 - (k % 3) * 0.0, 0.8, -0.5 + k * 0.016,
              -0.5 + k * 0.016 + (0.004 if k % 3 else 0.009), box.white())


def tray(parent, sort, count, quality):
    """Das Bauteil-Tray: leitfähiger schwarzer Kunststoff, gekappte Ecke, klare Haube,
    zwei Spannbänder."""
    th = H * 0.6
    base = RB(parent, "Tray", (W, L, th), (0, 0, th * 0.5),
              led.mat("Leitkunststoff", (0.02, 0.02, 0.024), 0.0, 0.55), 0.02, 0.008, 4)
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(-HW, HL, 0), rotation=(0, 0, PI * 0.25))
    corner = bpy.context.active_object
    corner.name = "SchnittEcke"
    corner.scale = (1, 1, 6)
    corner.parent = parent
    box.cut(base, corner)
    s = 0.72
    py = 0.16
    box.cut(base, RB(parent, "SchnittMulde", (1.08 * s + 0.05, 1.62 * s + 0.05, th),
                     (0, py, 0.04 + th * 0.5), base.data.materials[0], 0.03, 0.0, 6))
    low = deck(parent, sort, count, py, 0.06 + 0.045 * (count - 1) + TOPS[sort] * s, s, 0.05,
               None, 0.045)
    for sx in (-1, 1):
        for k in range(11):
            RB(parent, "Rippe", (0.04, 0.05, 0.016), (sx * (HW - 0.05), -0.6 + k * 0.12 + 0.02,
                                                      th + 0.008), base.data.materials[0], 0.0,
               0.003, 2)
    cover = shell(parent, "Haube", (W - 0.006, L - 0.006, H - th), (0, 0, th + (H - th) * 0.5),
                  clear("Haube", 0.09), 0.02, 0.012, 0.006)
    box.cut(cover, corner)
    for i, y in enumerate((0.62, -0.3)):
        band(parent, "Spannband%d" % i, y, 0.07, box.ink(sort), 0.005)
        RB(parent, "Schloss%d" % i, (0.13, 0.1, 0.014), (0.3, y, H + 0.012), led.metal(quality),
           0.01, 0.003, 3)
    fr = top(H)
    strip(parent, "Aufkleber", fr, 0.5, 0.81, -0.47, 0.47, box.ink(sort))
    box.text(parent, "FUMBLE", fr, 0.655, 0.3, 0.055, box.black_ink(), "Marke")
    box.text(parent, box.NAMES[sort], fr, 0.655, 0.19, 0.045, box.black_ink(), "Sorte")
    marks(parent, fr, sort, count, 0.655, 0.02, 0.055, 0.07, box.black_ink())
    poly(parent, "Warndreieck", fr, [(0.59, -0.36), (0.72, -0.36), (0.655, -0.2)],
         box.black_ink(), box.EPS * 2)
    strip(parent, "Folienlinie", fr, 0.52, 0.79, -0.13, -0.118, box.foil(quality), box.EPS * 2)


def einschub(parent, sort, count, quality):
    """Der Einschub eines Baugruppenträgers: Blechkäfig mit Fenster, Frontplatte mit Griff
    im Metall der Güte, fünf LEDs - so viele leuchten, wie Module darin stecken."""
    sheet = led.mat("Blech", (0.05, 0.05, 0.06), 0.7, 0.42, clearcoat=0.2)
    bl = L - 0.1
    cy = 0.05
    cage = RB(parent, "Kaefig", (W - 0.04, bl, H - 0.04), (0, cy, H * 0.5), sheet, 0.008, 0.004,
              3)
    box.cut(cage, RB(parent, "SchnittHohl", (W - 0.07, bl - 0.03, H - 0.07), (0, cy, H * 0.5),
                     sheet, 0.004, 0.0, 3))
    s = 0.72
    wy = 0.2
    box.cut(cage, RB(parent, "SchnittFenster", (1.08 * s + 0.06, 1.62 * s + 0.04, 0.2),
                     (0, wy, H), sheet, 0.02, 0.0, 6))
    zt = H - 0.02
    RB(parent, "Fensterfolie", (1.08 * s + 0.09, 1.62 * s + 0.07, 0.003), (0, wy, zt - 0.016),
       clear("Fensterfolie", 0.07), 0.02, 0.0, 6)
    low = deck(parent, sort, count, wy, zt - 0.03, s, 0.05, None, 0.05)
    RB(parent, "Traegerblech", (0.6, 1.0, low - 0.04), (0, wy, 0.04 + (low - 0.04) * 0.5), sheet,
       0.01, 0.0, 3)
    for sx in (-1, 1):
        RB(parent, "Schiene%d" % sx, (0.012, bl - 0.06, 0.03), (sx * (HW - 0.016), cy, H * 0.5),
           glow(sort, 1.4), 0.0, 0.0, 2)
    plate = led.metal(quality)
    RB(parent, "Frontplatte", (W, 0.035, H), (0, -HL + 0.1 - 0.0175 + 0.0, H * 0.5), plate, 0.004,
       0.003, 2)
    for sx in (-1, 1):
        RB(parent, "Griffstuetze%d" % sx, (0.035, 0.07, 0.05), (sx * 0.26, -HL + 0.05, H * 0.5),
           plate, 0.0, 0.004, 2)
        cyl(parent, "Raendel%d" % sx, 0.032, 0.03, (sx * 0.47, -HL + 0.075, H * 0.5), led.CHROME,
            (PI * 0.5, 0, 0), 20)
    RB(parent, "Griff", (0.6, 0.032, 0.06), (0, -HL + 0.016, H * 0.5), plate, 0.012, 0.01, 4)
    fr = top(zt)
    box.text(parent, "FUMBLE", fr, 0.6, 0.4, 0.05, box.foil(quality), "Marke")
    box.text(parent, box.NAMES[sort], fr, 0.6, 0.3, 0.04, box.ink(sort), "Sorte")
    off = led.mat("LedBlind", (0.05, 0.04, 0.07), 0.0, 0.2, clearcoat=1.0)
    for i in range(5):
        disc(parent, "Led%d" % i, fr, 0.6 + (i - 2) * 0.06, 0.16, 0.02,
             glow(sort, 5.0) if i < count else off)
    for k in range(6):
        strip(parent, "Schlitz%d" % k, fr, 0.47 + k * 0.045, 0.49 + k * 0.045, -0.46, -0.02,
              box.black_ink())


DESIGNS = {
    "zahl": [("A · KARTENKASTEN", "kartenkasten", kartenkasten),
             ("B · STREIFBAND", "streifband", streifband),
             ("C · LOCHTASCHE", "lochtasche", lochtasche)],
    "material": [("A · KLAPPBOX", "klappbox", klappbox),
                 ("B · MEHRFACHPACK", "mehrfachpack", mehrfachpack),
                 ("C · KASSETTENFACH", "kassettenfach", kassettenfach)],
    "rune": [("A · FUNDKISTE", "fundkiste", fundkiste), ("B · TONHÜLLE", "tonhuelle", tonhuelle),
             ("C · MUSEUMSKASTEN", "museumskasten", museumskasten)],
    "sonder": [("A · BLISTER", "blister", blister), ("B · TRAY", "tray", tray),
               ("C · EINSCHUB", "einschub", einschub)],
}
SIZES = [(3, 0, "3er · Standard"), (4, 1, "4er · Edel"), (5, 2, "5er · Royal")]


# --- Bühne ------------------------------------------------------------------------------

def sheet(name, entries, near=False):
    """Pakete nebeneinander, quer wie im Laden. entries = (build, sort, count, quality, text)."""
    cam, aim = dm.empty_stage()
    quer = Matrix.Rotation(PI * 0.5, 4, "Z")
    pitch = L + 0.42
    n = len(entries)
    for i, (build, sort, count, quality, caption) in enumerate(entries):
        bpy.ops.object.empty_add()
        root = bpy.context.active_object
        root.name = "Pack%d" % i
        build(root, sort, count, quality)
        x = (i - (n - 1) * 0.5) * pitch
        root.matrix_world = Matrix.Translation((x, 0, 0.001)) @ quer
        box.text(None, caption, box.frame((x, -0.86, 0.003), (1, 0, 0), (0, 1, 0)), 0.0, 0.0, 0.1,
                 box.white(), "Titel%d" % i)
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = 2200, 940
    scene.eevee.taa_render_samples = 64
    cam.data.lens = 40
    aim.location = (0, -0.12, 0.12)
    cam.location = (0.0, -3.7, 6.9) if not near else (0.0, -4.9, 5.6)
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


def render(only=""):
    os.makedirs(OUT, exist_ok=True)
    for sort, designs in DESIGNS.items():
        if only and only != sort:
            continue
        sheet("%s_uebersicht" % sort, [(b, sort, 4, 1, title) for title, _n, b in designs])
        sheet("%s_schraeg" % sort, [(b, sort, 4, 1, title) for title, _n, b in designs], True)
        for title, name, build in designs:
            sheet("%s_%s" % (sort, name), [(build, sort, c, q, text) for c, q, text in SIZES])
    print("ok")


if __name__ == "__main__":
    render(sys.argv[sys.argv.index("--") + 2] if "--" in sys.argv
           and len(sys.argv) > sys.argv.index("--") + 2 else "")
