"""Fumble: das STANGENMAGAZIN - die Hülle des Modul-Pakets (2026-11-23, Spieler-Wahl „B4 ·
Karton-Endkappen“ aus tools/blender_module_tube_variants.py). EIN Modell für jede Größe und Stufe:
assets/models/hardware/module_tubes.glb. Godot zeigt die passenden Teile und gibt die Materialien
nach Objektnamen (CardPackView._dress_case_part):
  Rohr<r>, Rohrkante<r>, Schiene<r>   - drei antistatische Röhren
  Endkappe0, Kappenband0, Schrift      - die linke Karton-Kappe mit dem Namen
  Kappe (leer) > Endkappe1, Kappenband1, Auge<i>, CodeFeld, Code - die rechte Kappe; sie zieht ab
  Modul<k>, ModulGlas<k>, ModulLicht<k>, Bein<k> - sechs Plätze, gezeigt die ersten n

Aufruf (kopflos):
  blender -b -P tools/blender_module_tubes_export.py -- assets/models/hardware
Roh-Maß der Zelle; gebaut quer (X = Bild-rechts, Y = Bild-oben) und um -90° um Z gedreht, so
liegt Bild-oben auf Zelle +x wie bei jeder Hülle.
"""
import bpy, math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_chip_screens as cs
import blender_combo_module_variants as cv
import blender_combo_bay_variants as bv

led = dm.led
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = ARGS[0] if ARGS else "assets/models/hardware"
PW, PD = 1.62 * 1.04, 1.08 * 1.04
CAP, CAP_H, TUBE_H = 0.36, 0.4, 0.34
MS = 0.85


def mat(name):
    return led.mat(name, (0.5, 0.5, 0.5))


def one(r, name, item):
    return cs.boxes(r, name, [item], mat(name))


def module(parent, k):
    r = cs.root("Platz%d" % k)
    r.parent = parent
    led.rounded_box(r, "Modul%d" % k, (bv.ML, bv.MD, bv.MH), (0, 0, bv.MH * 0.5), mat("Modul"), 0.025, 0.012)
    led.rounded_box(r, "ModulGlas%d" % k, (bv.ML - 0.2, bv.MD - 0.09, 0.008), (0.04, 0, bv.MH), mat("ModulGlas"), 0.02, 0.0)
    cs.boxes(r, "ModulLicht%d" % k, [(-bv.ML * 0.5 + 0.045, 0, bv.MH + 0.003, 0.03, bv.MD - 0.08, 0.006),
                                     (bv.ML * 0.5 + 0.035, 0, 0.173, 0.03, 0.11, 0.006)], mat("ModulLicht"))
    bv.leg(r, "Bein%d" % k, bv.ML * 0.5, 0, 0.0, 0.16, mat("Bein"))
    r.location = ((k % 2 - 0.5) * 0.56 - 0.07, (1 - k // 2) * 0.35, 0.03)
    r.scale = (0.66, MS, MS)


def cap(parent, index, x):
    """Eine Karton-Kappe um die Rohrenden; x = ihre Mitte, das Band liegt an der Innenkante."""
    s = -1 if index == 0 else 1
    led.rounded_box(parent, "Endkappe%d" % index, (CAP, PD, CAP_H), (x, 0, CAP_H * 0.5), mat("Endkappe"), 0.02, 0.008)
    cs.boxes(parent, "Kappenband%d" % index, [(x - s * (CAP * 0.5 - 0.02), 0, CAP_H + 0.002, 0.035, PD - 0.004, 0.004),
                                              (x - s * (CAP * 0.5 - 0.02), -PD * 0.5 - 0.002, CAP_H * 0.5, 0.035, 0.004, CAP_H - 0.01),
                                              (x - s * (CAP * 0.5 - 0.02), PD * 0.5 + 0.002, CAP_H * 0.5, 0.035, 0.004, CAP_H - 0.01)],
             mat("Kappenband"))


def build():
    led.stage(lambda *a: None, False, True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    r = cs.root("Magazin")
    length = PW - 0.1
    for row in range(3):
        y = (1 - row) * 0.35
        led.rounded_box(r, "Rohr%d" % row, (length, 0.32, TUBE_H), (0, y, 0.18), mat("Rohr"), 0.03, 0.03)
        cs.boxes(r, "Rohrkante%d" % row, [(0, y + s * 0.148, 0.347, length - 0.02, 0.012, 0.01) for s in (-1, 1)],
                 mat("Rohrkante"))
        one(r, "Schiene%d" % row, (0, y, 0.022, length - 0.04, 0.16, 0.014))
    for k in range(6):
        module(r, k)
    left = -PW * 0.5 + CAP * 0.5
    cap(r, 0, left)
    t = cv.txt(r, "MODULE", left - 0.02, -0.17, CAP_H + 0.004, 0.1, "name", 1.0, "CENTER")
    t.name = "Schrift"
    t.rotation_euler = (0, 0, math.radians(90))
    # die rechte Kappe hängt an einem eigenen Knoten: beim Öffnen zieht sie nach rechts ab
    right = PW * 0.5 - CAP * 0.5
    lid = cs.root("Kappe")
    lid.parent = r
    lid.location = (right, 0, 0)
    cap(lid, 1, 0.0)
    for i in range(6):
        one(lid, "Auge%d" % i, (0.09, 0.3 - i * 0.1, CAP_H + 0.004, 0.065, 0.065, 0.004))
    one(lid, "CodeFeld", (-0.04, -0.33, CAP_H + 0.002, 0.2, 0.2, 0.003))
    rnd = random.Random(7)
    bars, at = [], -0.04 - 0.08
    while at < -0.04 + 0.075:
        bw = rnd.choice((0.006, 0.01, 0.016))
        bars.append((at + bw * 0.5, -0.33, CAP_H + 0.005, bw, 0.16, 0.003))
        at += bw + rnd.choice((0.006, 0.01))
    cs.boxes(lid, "Code", bars, mat("Code"))
    r.rotation_euler = (0, 0, math.radians(-90))
    for o in list(bpy.data.objects):
        if o.type == "FONT":
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.convert(target="MESH")


build()
os.makedirs(OUT, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "module_tubes.glb"), export_format="GLB",
                          export_apply=True, use_selection=True)
print("ok")
