"""Fumble: exportiert die RETAIL-Schachtel des Karten-Pakets (Spieler-Wahl 2026-11-16 aus
tools/blender_card_box.py) als assets/models/hardware/card_box.glb.

Aufruf (kopflos):
  blender -b -P tools/blender_card_box_export.py -- assets/models/hardware

Die Datei trägt ALLE Spielarten zugleich; CardPackView zeigt je Paket die passenden und gibt
die Materialien nach Objektnamen:
  Karton (Flächen Karton/Kraft), Lasche  - Karton, innen roher Karton
  Folie                                  - Klarsichtfolie des Fensters
  Druck*                                 - Druck in der Sortenfarbe (DruckSorte_<sorte> je Sorte)
  Streifen<j>*                           - die drei Sortenfarben des Misch-Pakets
  Praegung*                              - die Folie der Güte
  Schwarz*_<sorte>                       - schwarzer Druck je Sorte
  AugeFront<n>_<k>, AugeKopf<n>_<k>      - die Augen der Kartenzahl n
Keine Karten: die echten Data-Cards baut Godot.
"""
import bpy, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_card_box as box

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/models/hardware"
os.makedirs(OUT, exist_ok=True)
W, L, H, WALL = box.W, box.L, box.H, box.WALL
SORTS = ["zahl", "material", "rune", "misch"]


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    led._mats.clear()
    led.base_materials()
    tab = 0.13
    lb = L - tab
    cy = -tab * 0.5
    body = led.rounded_box(None, "Karton", (W, lb, H), (0, cy, H * 0.5), box.board(), 0.012,
                           0.006, 4)
    box.hollow(None, body, (W - WALL * 2, lb - WALL * 2, H - WALL * 2), (0, cy, H * 0.5))
    win = (0.74, 0.9)
    wy = cy + lb * 0.5 - 0.06 - win[1] * 0.5
    hole = led.rounded_box(None, "SchnittFenster", (win[0], win[1], WALL * 4), (0, wy, H),
                           box.kraft(), 0.03, 0.0, 8)
    box.cut(body, hole, True)
    led.rounded_box(None, "Folie", (win[0] + 0.03, win[1] + 0.03, 0.003),
                    (0, wy, H - WALL - 0.002), box.film(), 0.03, 0.0, 8)
    lug = led.rounded_box(None, "Lasche", (W * 0.46, tab + 0.04, 0.012),
                          (0, L * 0.5 - (tab + 0.04) * 0.5, 0.006), box.board(), 0.03, 0.003, 6)
    slot = led.rounded_box(None, "SchnittLasche", (0.17, 0.036, 0.1),
                           (0, L * 0.5 - tab * 0.48, 0), box.kraft(), 0.017, 0.0, 6)
    box.cut(lug, slot)
    ink = box.ink("zahl")
    foil = box.foil(1)
    fr = box.front_frame()
    foot = lb * 0.5 - cy
    half = W * 0.5
    box.decal(None, "DruckBand", fr, [(0.68, -half), (foot, -half), (foot, half), (0.8, half)], ink)
    third = (foot - 0.68) / 3.0
    for j in range(3):
        box.rect(None, "Streifen%dBand" % j, fr, 0.68 + third * j, -half, 0.68 + third * (j + 1),
                 half, box.ink(led.MIX[j]))
    box.decal(None, "PraegungLinie", fr,
              [(0.64, -half), (0.655, -half), (0.775, half), (0.76, half)], foil)
    box.text(None, "FUMBLE", fr, 0.44, 0.36, 0.085, foil, "PraegungMarke")
    for sort in SORTS:
        box.text(None, box.NAMES[sort], fr, 0.44, 0.2, 0.06, ink, "DruckSorte_" + sort)
    hf = box.head_frame(cy + lb * 0.5)
    ff = box.foot_frame(cy - lb * 0.5)
    for count in (3, 4, 5):
        box.pips(None, fr, count, 0.44, 0.02, 0.065, 0.022, box.white(), False,
                 "AugeFront%d_" % count)
        # Am Kopf sitzen die Augen dunkel AUF dem Ring - dort liest das Lager.
        box.pips(None, hf, count, 0.0, 0.0, 0.15, 0.045, box.black_ink(), True,
                 "AugeKopf%d_" % count)
    # Der RING in der Sortenfarbe läuft um alle vier Seiten, gesäumt von der Folie der Güte.
    ring, seam = 0.08, 0.095
    ends = [("Kopf", hf), ("Fuss", ff)]
    for name, ef in ends:
        box.rect(None, "DruckRuecken_" + name, ef, -ring, -half, ring, half, ink)
        third = W / 3.0
        for j in range(3):
            box.rect(None, "Streifen%dRuecken%s" % (j, name), ef, -ring, -half + third * j, ring,
                     -half + third * (j + 1), box.ink(led.MIX[j]))
        for k, edge in enumerate((-1, 1)):
            box.rect(None, "PraegungRuecken%s%d" % (name, k), ef, edge * seam - 0.006, -half,
                     edge * seam + 0.006, half, foil)
    for i, sf in enumerate(box.spine_frames(cy)):
        box.rect(None, "DruckRuecken%d" % i, sf, -lb * 0.5, -ring, lb * 0.5, ring, ink)
        span = lb / 3.0
        for j in range(3):
            box.rect(None, "Streifen%dRuecken%d" % (j, i), sf, -lb * 0.5 + span * j, -ring,
                     -lb * 0.5 + span * (j + 1), ring, box.ink(led.MIX[j]))
        for k, edge in enumerate((-1, 1)):
            box.rect(None, "PraegungRuecken%d%d" % (i, k), sf, -lb * 0.5, edge * seam - 0.006,
                     lb * 0.5, edge * seam + 0.006, foil)
        for sort in SORTS:
            box.text(None, box.NAMES[sort], sf, -0.25, 0.0, 0.1, box.black_ink(),
                     "SchwarzRuecken%d_%s" % (i, sort))
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


build()
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "card_box.glb"), export_format="GLB",
                          export_apply=True)
print("ok")
