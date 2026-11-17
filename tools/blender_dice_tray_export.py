"""Fumble: exportiert die SCHALE des Würfel-Pakets (Spieler-Wahl 2026-11-16 aus
tools/blender_dice_box_variants.py, Entwurf "schale") als assets/models/hardware/dice_tray.glb.

Aufruf (kopflos):
  blender -b -P tools/blender_dice_tray_export.py -- assets/models/hardware

Roh-Maß wie die Karten-Schachtel (X Breite, Y Länge mit dem Kopf bei +Y, Z Höhe, Ursprung Mitte
unten). Die Datei trägt ALLE Spielarten zugleich; CardPackView zeigt je Paket die passenden und
gibt die Materialien nach Objektnamen:
  Boden                         - schwarzer Karton mit sechs Mulden
  Schale, Muldenboden<i>        - die Schale in der Sortenfarbe
  Haube                         - die Klarsicht-Haube
  Banderole*                    - der Karton der Banderole
  Druck*                        - Druck in der Sortenfarbe
  Praegung*                     - die Folie der Güte
  SchwarzMarke, SchwarzSorte_<sorte> - schwarzer Druck
  AugeBand<n>_<k>, AugeKopf<n>_<k>   - die Würfelzahl n
  Wuerfel<k>, Ziffer<k>         - der Würfel in Mulde k
  Deko<k>_<sorte>_<rolle>       - seine obere Seite in der Sprache der Sorte
Unter dem Leer-Objekt "Scharnier" (Achse an der Langseite +X) hängen Haube und die obere Hälfte
der Banderole samt Druck; positive Drehung um Blender-Y öffnet.
"""
import bpy, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_card_box as box
import blender_dice_box as dbx

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/models/hardware"
os.makedirs(OUT, exist_ok=True)
W, L, H = box.W, box.L, box.H
# Würfelkante im Roh-Maß: 1,2 Welt / CASSETTE_SCALE 3,2.
EDGE = 0.375
TRAY_TOP = 0.3
WELL = EDGE + 0.03
WELL_FLOOR = 0.04
DIE_BOTTOM = WELL_FLOOR + 0.005
WELLS = [(x * 0.23, 0.15 + y * 0.44) for y in (1, 0, -1) for x in (-1, 1)]
BAND_Y, BAND_W = -0.66, 0.32
SPLIT = 0.291
SORTS = ["normal", "soul", "material", "rune"]
RUNE_SHAPES = ["ring", "dreieck", "quadrat", "stern", "raute", "ring"]
MAT = None


def disc(name, fr, a, b, radius, lift=0.0015):
    return dbx.poly(None, name, fr, dbx.ngon(32, radius, 0.0, a, b), MAT, lift)


def pips(fr, count, b0, pitch, radius, name, lift=0.0015):
    for k in range(count):
        t = (k - (count - 1) * 0.5) * pitch
        disc("%s%d_%d" % (name, count, k), fr, 0.0, b0 + t, radius, lift)


def outline(name, fr, outer, inner):
    """Kontur: die Fläche in der Farbe, eine Spur darüber die Innenfläche im Grund."""
    dbx.poly(None, name, fr, outer, MAT, 0.0015)
    dbx.poly(None, name + "Innen", fr, inner, MAT, 0.003)


def rune(k, fr):
    name = "Deko%d_rune_Rune" % k
    shape = RUNE_SHAPES[k]
    r = 0.12
    if shape == "ring":
        outline(name, fr, dbx.ngon(32, r), dbx.ngon(32, r - 0.022))
    elif shape == "dreieck":
        outline(name, fr, dbx.ngon(3, r, -math.pi * 0.5), dbx.ngon(3, r - 0.045, -math.pi * 0.5))
    elif shape == "quadrat":
        dbx.square_ring(None, name, fr, 0, 0, r * 0.82, 0.022, MAT)
    elif shape == "stern":
        outline(name, fr, dbx.star(r, 0.5), dbx.star(r - 0.032, 0.42))
    else:
        outline(name, fr, dbx.ngon(4, r, math.pi * 0.5), dbx.ngon(4, r - 0.03, math.pi * 0.5))


def die(k, x, y):
    top = DIE_BOTTOM + EDGE
    led.rounded_box(None, "Wuerfel%d" % k, (EDGE, EDGE, EDGE), (x, y, DIE_BOTTOM + EDGE * 0.5), MAT,
                    0.036, 0.03, 6)
    fr = box.frame((x, y, top), (0, -1, 0), (1, 0, 0))
    half = EDGE * 0.5 - 0.055
    dbx.square_ring(None, "Deko%d_normal_Kante" % k, fr, 0, 0, half, 0.013, MAT)
    dbx.square_ring(None, "Deko%d_soul_Kante" % k, fr, 0, 0, half, 0.022, MAT)
    side = half + 0.03
    dbx.poly(None, "Deko%d_material_Seite" % k, fr,
             [(-side, -side), (side, -side), (side, side), (-side, side)], MAT, 0.0015)
    disc("Deko%d_material_Hof" % k, fr, 0, 0, 0.08, 0.0022)
    rune(k, fr)
    t = box.text(None, str(dbx.VALUES[k]), fr, 0.0, 0.0, 0.16, MAT, "Ziffer%d" % k)
    t.location += fr[3] * 0.003


def ring_box(name, size, z0, z1, inner):
    """Ein Kasten ohne Boden und Innenraum: zwei Wangen und (falls oben) ein Deckel."""
    body = led.rounded_box(None, name, (size[0], size[1], z1 - z0), (0, BAND_Y, (z0 + z1) * 0.5),
                           MAT, 0.004, 0.002, 4)
    cut = led.rounded_box(None, "Schnitt" + name, (inner[0], size[1] + 0.2, inner[2] - inner[1]),
                          (0, BAND_Y, (inner[1] + inner[2]) * 0.5), MAT, 0.0, 0.0)
    box.cut(body, cut)
    return body


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    led._mats.clear()
    led.base_materials()
    # Godot setzt jedes Material selbst - im Modell trägt alles denselben Platzhalter.
    global MAT
    MAT = led.mat("Platzhalter", (0.5, 0.5, 0.5), 0.0, 0.5)
    lid = []
    base = led.rounded_box(None, "Boden", (W, L, TRAY_TOP), (0, 0, TRAY_TOP * 0.5), MAT, 0.03,
                           0.006, 4)
    tray = led.rounded_box(None, "Schale", (W - 0.04, L - 0.04, 0.06),
                           (0, 0, TRAY_TOP - 0.028), MAT, 0.02, 0.01, 4)
    for i, (x, y) in enumerate(WELLS):
        cutter = led.rounded_box(None, "SchnittMulde%d" % i, (WELL, WELL, 0.4),
                                 (x, y, WELL_FLOOR + 0.2), MAT, 0.05, 0.0, 6)
        box.cut(base, cutter)
        box.cut(tray, cutter)
        led.rounded_box(None, "Muldenboden%d" % i, (WELL - 0.004, WELL - 0.004, 0.01),
                        (x, y, WELL_FLOOR - 0.003), MAT, 0.048, 0.0, 6)
        die(i, x, y)
    # Die Klarsicht-Haube sitzt auf dem Rand des Bodens.
    dome_h = H - TRAY_TOP - 0.001
    dome = led.rounded_box(None, "Haube", (W, L, dome_h), (0, 0, TRAY_TOP + 0.001 + dome_h * 0.5),
                           MAT, 0.03, 0.03, 6)
    box.cut(dome, led.rounded_box(None, "SchnittHaube", (W - 0.012, L - 0.012, dome_h),
                                  (0, 0, TRAY_TOP + 0.001 + dome_h * 0.5 - 0.006), MAT, 0.03, 0.0,
                                  4))
    lid.append(dome.name)
    # Die BANDEROLE am Fuß: unten zwei Wangen am Boden, oben der Rücken mit dem Druck am Deckel.
    outer = (W + 0.02, BAND_W)
    ring_box("BanderoleBoden", outer, 0.0, SPLIT - 0.001, (W + 0.002, -0.1, SPLIT + 0.1))
    lid.append(ring_box("BanderoleDeckel", outer, SPLIT, H + 0.01,
                        (W + 0.002, SPLIT - 0.1, H + 0.002)).name)
    fr = box.frame((0, BAND_Y, H + 0.01), (0, -1, 0), (1, 0, 0))
    half = W * 0.5 + 0.01
    top = []
    top.append(box.rect(None, "DruckBand", fr, -BAND_W * 0.5, -half, BAND_W * 0.5, half, MAT))
    for name, a in (("A", -BAND_W * 0.5 + 0.02), ("B", BAND_W * 0.5 - 0.032)):
        top.append(dbx.poly(None, "PraegungBand" + name, fr,
                            [(a, -half), (a + 0.012, -half), (a + 0.012, half), (a, half)], MAT,
                            0.0025))
    top.append(box.text(None, "FUMBLE", fr, 0.0, 0.36, 0.065, MAT, "SchwarzMarke"))
    for sort in SORTS:
        top.append(box.text(None, dbx.NAMES[sort], fr, 0.0, 0.22, 0.052, MAT, "SchwarzSorte_" + sort))
    names_before = set(o.name for o in bpy.data.objects)
    for count in range(2, 7):
        # Die Augen liegen eine Spur ÜBER dem Farbdruck - in derselben Ebene stritten sie.
        pips(fr, count, -0.17, 0.065, 0.024, "AugeBand", 0.003)
    top += [o for o in bpy.data.objects if o.name not in names_before]
    lid += [o.name for o in top]
    for i, sx in enumerate((-1, 1)):
        sf = box.frame((sx * half, BAND_Y, SPLIT * 0.5), (0, sx, 0), (0, 0, 1))
        box.rect(None, "DruckBandSeite%d" % i, sf, -BAND_W * 0.5, -0.09, BAND_W * 0.5, 0.09, MAT)
    # Der KOPF liest im Lager: die Würfelzahl in der Sortenfarbe.
    hf = box.frame((0, L * 0.5, TRAY_TOP * 0.5), (0, 0, 1), (1, 0, 0))
    for count in range(2, 7):
        pips(hf, count, 0.0, 0.15, 0.04, "AugeKopf")
    # Schrift zu Netzen, Schnitte anwenden, Schnittkörper fort.
    for o in list(bpy.data.objects):
        if o.type == "FONT":
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.convert(target="MESH")
    for o in list(bpy.data.objects):
        if o.type != "MESH" or o.display_type == "WIRE":
            continue
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    for o in list(bpy.data.objects):
        if o.display_type == "WIRE":
            bpy.data.objects.remove(o, do_unlink=True)
    hinge = bpy.data.objects.new("Scharnier", None)
    bpy.context.scene.collection.objects.link(hinge)
    hinge.location = (W * 0.5 + 0.01, 0.0, SPLIT)
    bpy.context.view_layer.update()
    for name in lid:
        part = bpy.data.objects[name]
        world = part.matrix_world.copy()
        part.parent = hinge
        part.matrix_world = world


build()
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dice_tray.glb"), export_format="GLB",
                          export_apply=True)
print("ok")
