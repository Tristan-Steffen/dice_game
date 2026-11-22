"""Fumble: fünf Entwürfe für die Charm-DISKETTE (Spieler-Wunsch 2026-11-22: die schwarze Karte
hat keine Persönlichkeit). Maße, Schieber, Fenster und das schwarze Textfeld bleiben, wie
CharmDiskView sie erwartet - neu sind Schale, Rahmen und Schmuck.

  stahl   - gebürstete Stahlschale, Raritäts-Streifen links, Griffkerben
  neon    - schwarzer Lack, dicker Lichtrahmen und eine leuchtende Außenkante
  casino  - schwarzer Lack mit Messing-Einlage, Eckstufen und einem Raritäts-Stein
  farbe   - die ganze Schale in der Raritätsfarbe, Stahl-Schieber
  platine - Leiterplatte mit Goldkontakten und Leiterbahnen in der Rarität

Das Licht der Schale ist als Vertexfarbe ins Netz `Korpus` eingemalt. Netze `Rar<nnn>…` tönt
Godot in der Rarität des Charms (nnn = Energie in Prozent).

Aufruf (kopflos):
  blender -b -P tools/blender_floppy_variants.py -- <ausgabe-ordner>
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_floppy_charm as fc
import blender_floppy_layouts as fl
import blender_projector_baked as pb

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
DW, DL, DT = fc.DW, fc.DL, fc.DT
ZT = DT * 0.5
## Dieselben Zahlen wie CharmDiskView.WINDOW und GLASS.
WINDOW = (-0.03, 0.314, 0.33, 0.225)
GX0, GX1, GY0, GY1 = -0.405, 0.405, -0.455, 0.15
LIFT = ZT + 0.0030

pb.BAKED.update({
    "Platine": ("matt", (0.03, 0.11, 0.08)),
    "Lackrot": ("gloss", (0.03, 0.03, 0.04)),
})


def rar(energy, name):
    return "Rar%03d%s" % (energy, name), led.mat("Rar%03d" % energy, (0.2, 0.2, 0.25), 0.0, 0.4)


def deco(root, name, x0, y0, x1, y1, material, lift=LIFT):
    return fc.box(root, name, (x1 - x0, y1 - y0, 0.0006), ((x0 + x1) * 0.5, (y0 + y1) * 0.5, lift),
                  material)


def glow(root, energy, name, x0, y0, x1, y1):
    full, material = rar(energy, name)
    return deco(root, full, x0, y0, x1, y1, material)


def frame(root, energy, name, wide, x0=GX0, y0=GY0, x1=GX1, y1=GY1, material=None):
    """Vier Leisten rund um ein Rechteck; material = None heißt Raritäts-Licht."""
    bars = ((x0, y1 - wide, x1, y1), (x0, y0, x1, y0 + wide), (x0, y0, x0 + wide, y1),
            (x1 - wide, y0, x1, y1))
    for i, (a, b, c, d) in enumerate(bars):
        if material is None:
            glow(root, energy, "%s%d" % (name, i), a, b, c, d)
        else:
            deco(root, "%s%d" % (name, i), a, b, c, d, material)


def shell(root, body_mat, shutter_mat):
    """Gehäuse, Schieber mit Fenster, Löcher, Nabe und das schwarze Textfeld."""
    fl.shell(root, body_mat, shutter_mat)
    bpy.data.objects.remove(bpy.data.objects["Fenster"], do_unlink=True)
    wx, wy, ww, wh = WINDOW
    cutter = fc.box(root, "SchnittFenster", (ww, wh, 0.01), (wx, wy, ZT + 0.0035),
                    led.mat("Loch", (0.004, 0.004, 0.006), 0.0, 0.5))
    led.cut(bpy.data.objects["Schieber"], cutter)
    led.rounded_box(root, "Glasfront", (GX1 - GX0, GY1 - GY0, 0.003),
                    (0, (GY0 + GY1) * 0.5, ZT + 0.0012),
                    led.mat("Glasfront", (0.004, 0.009, 0.012), 0.0, 0.35, 0.0, clearcoat=0.25),
                    0.015, 0.0008, 4)


def stahl(root):
    shell(root, pb.mat("Stahl"), pb.mat("Chrom"))
    glow(root, 100, "Streifen", GX0, GY0, GX0 + 0.022, GY1)
    deco(root, "Fussleiste", GX0 + 0.03, -0.392, GX1 - 0.012, -0.388, pb.mat("Stahl"))
    for sx in (-1, 1):
        for i in range(4):
            y = -0.34 + i * 0.035
            deco(root, "Kerbe%d_%d" % (sx, i), sx * 0.43 - 0.012, y, sx * 0.43 + 0.012, y + 0.012,
                 pb.mat("Graphit"))
    for sx in (-1, 1):
        fc.cyl(root, "Niete%d" % sx, 0.012, 0.002, (sx * 0.428, GY1 + 0.02, ZT + 0.001),
               pb.mat("Chrom"), verts=12)


def neon(root):
    shell(root, pb.mat("Schwarzlack"), pb.mat("Graphit"))
    frame(root, 100, "Rahmen", 0.02)
    full, material = rar(100, "Kante")
    led.rounded_box(root, full, (DW + 0.03, DL + 0.03, 0.005), (0, 0, -ZT + 0.0025), material,
                    0.02, 0.0, 6)
    for sx in (-1, 1):
        glow(root, 60, "Ecke%d" % sx, sx * 0.405 - 0.03, GY0 + 0.02, sx * 0.405 + 0.03, GY0 + 0.026)


def casino(root):
    brass = pb.mat("Messing")
    shell(root, pb.mat("Schwarzlack"), brass)
    frame(root, 0, "Einlage", 0.012, GX0 - 0.012, GY0 - 0.004, GX1 + 0.012, GY1 + 0.012, brass)
    for sx in (-1, 1):
        for sy, y in ((-1, GY0), (1, GY1)):
            deco(root, "Eckstufe%d_%d" % (sx, sy), sx * 0.405 - 0.03, y - 0.03, sx * 0.405 + 0.03,
                 y + 0.03, brass)
            deco(root, "Eckkern%d_%d" % (sx, sy), sx * 0.405 - 0.016, y - 0.016, sx * 0.405 + 0.016,
                 y + 0.016, pb.mat("Schwarzlack"), LIFT + 0.0003)
    deco(root, "Fussleiste", GX0 + 0.04, -0.39, GX1 - 0.04, -0.386, brass)
    # Raute = Zylinder mit vier Ecken (eine gedrehte Box wanderte beim Export um den Ursprung).
    full, material = rar(110, "Stein")
    fc.cyl(root, full, 0.024, 0.0008, (0, -0.418, LIFT + 0.0003), material, verts=4)
    bpy.ops.object.shade_flat()
    fc.cyl(root, "Steinfassung", 0.034, 0.0006, (0, -0.418, LIFT), brass, verts=4)
    bpy.ops.object.shade_flat()


def farbe(root):
    shell(root, pb.mat("Schwarzlack"), pb.mat("Stahl"))
    body = bpy.data.objects["Gehaeuse"]
    full, material = rar(45, "Gehaeuse")
    body.name = full
    body.data.materials.clear()
    body.data.materials.append(material)
    glow(root, 100, "Fuss", GX0, GY0, GX1, GY0 + 0.014)
    for sx in (-1, 1):
        for i in range(5):
            y = -0.3 + i * 0.07
            deco(root, "Schraffur%d_%d" % (sx, i), sx * 0.43 - 0.014, y, sx * 0.43 + 0.014, y + 0.03,
                 pb.mat("Schwarzlack"))


def platine(root):
    gold = pb.mat("Messing")
    shell(root, pb.mat("Platine"), gold)
    for x in (-0.4, -0.34, -0.28, 0.22, 0.28, 0.34, 0.4):
        deco(root, "Kontakt%d" % round(x * 100), x - 0.02, DL * 0.5 - 0.075, x + 0.02,
             DL * 0.5 - 0.008, gold, ZT + 0.0003)
    for i, x in enumerate((0.374, 0.384)):
        glow(root, 40, "BahnR%d" % i, x - 0.002, GY0 + 0.07 + i * 0.02, x + 0.002, GY1 - 0.02)
        glow(root, 40, "BahnQ%d" % i, 0.12, GY0 + 0.07 + i * 0.02 - 0.002, x + 0.002,
             GY0 + 0.07 + i * 0.02 + 0.002)
        deco(root, "Pad%d" % i, 0.1, GY0 + 0.06 + i * 0.02, 0.12, GY0 + 0.08 + i * 0.02, gold)
    for sx in (-1, 1):
        for y in (GY0 + 0.01, -0.15, GY1 + 0.01):
            fc.cyl(root, "Via%d_%d" % (sx, round(y * 100)), 0.011, 0.001,
                   (sx * 0.428, y, ZT + 0.0005), gold, verts=10)
    deco(root, "Fussleiste", GX0 + 0.03, -0.392, 0.08, -0.389, gold)


VARIANTS = [("stahl", stahl), ("neon", neon), ("casino", casino), ("farbe", farbe),
            ("platine", platine)]


def export(tag, build, path=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    led._mats.clear()
    pb.DISH[3] = 0.0
    pb.CONTACT_SHADOW = False
    root = fc.empty("Diskette", (0, 0, ZT))
    build(root)
    pb.bake_and_join()
    bpy.ops.export_scene.gltf(filepath=path or os.path.join(OUT, "diskette_%s.glb" % tag),
                              export_format="GLB", export_apply=True, export_colors=True)
    pb.CONTACT_SHADOW = True


def main():
    os.makedirs(OUT, exist_ok=True)
    for tag, build in VARIANTS:
        export(tag, build)
    print("ok")


if __name__ == "__main__":
    main()
