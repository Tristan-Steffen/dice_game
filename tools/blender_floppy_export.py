"""Fumble: exportiert die Charm-DISKETTE und das LAUFWERK (Terminal-Layout, Spieler-Wahl
2026-11-18) als assets/models/hardware/charm_disk.glb und charm_reader.glb.

Aufruf (kopflos):
  blender -b -P tools/blender_floppy_export.py -- assets/models/hardware

charm_disk.glb - NUR die Hülle: Gehaeuse, Schieber (mit breitem Fenster), Loch*, Nabe, Glasfront. Text, Bild,
  Rahmen und LEDs setzt Godot je Charm (CharmDiskView). Ursprung = Mitte der Unterseite.
charm_reader.glb - Gehaeuse, Blende mit Schlitz, Schlitzgrund, Rillen, Sockel, Topf, Stangen und
  die eigenen, benannten Leuchtteile Lippe, Kopfsaum, Ring, Linse, Spitzen, Lampe, Display,
  Auswurf (Godot tönt sie). Ursprung = Mitte unten, Schlitz nach -Y (glTF +Z), das Leer-Objekt
  LinseMitte sitzt auf der Linse.
Maße in Blender-Einheiten; skaliert wird in Godot (CharmDiskView.BLENDER_SCALE).
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_floppy_charm as fc
import blender_floppy_layouts as fl

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/models/hardware"
os.makedirs(OUT, exist_ok=True)
DW, DL, DT = fc.DW, fc.DL, fc.DT
RW, RL, RH = fc.RW, fc.RL, fc.RH
ZT = DT * 0.5
## Mitte x, Mitte y, Breite, Höhe - dieselben Zahlen wie CharmDiskView.WINDOW.
WINDOW = (-0.03, 0.314, 0.33, 0.225)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    led._mats.clear()


def finish(path, joins=()):
    """Schnitte anwenden, Schnittkörper fort, Gruppen zu je einem Netz, exportieren."""
    for o in list(bpy.data.objects):
        if o.type != "MESH" or o.display_type == "WIRE":
            continue
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    for o in list(bpy.data.objects):
        if o.display_type == "WIRE":
            bpy.data.objects.remove(o, do_unlink=True)
    for name in joins:
        parts = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(name)]
        if len(parts) < 2:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in parts:
            o.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        parts[0].name = name
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True)


def disk():
    reset()
    root = fc.empty("Diskette", (0, 0, ZT))
    fl.shell(root, led.mat("Schwarzlack", (0.008, 0.008, 0.011), 0.0, 0.12, clearcoat=1.0),
             led.mat("Schwarzchrom", (0.12, 0.12, 0.14), 1.0, 0.18))
    # Das breite Holo-Fenster (Spieler-Wahl 2026-11-18, tools/blender_floppy_picture.py „fenster“):
    # in den Schieber geschnitten, darunter legt Godot die Holo-Scheibe samt Glas (WINDOW).
    bpy.data.objects.remove(bpy.data.objects["Fenster"], do_unlink=True)
    wx, wy, ww, wh = WINDOW
    cutter = fc.box(root, "SchnittFenster", (ww, wh, 0.01), (wx, wy, ZT + 0.0035),
                    led.mat("Loch", (0.004, 0.004, 0.006), 0.0, 0.5))
    led.cut(bpy.data.objects["Schieber"], cutter)
    x0, x1, y0, y1 = -0.405, 0.405, -DL * 0.5 + 0.015, DL * 0.5 - 0.32
    led.rounded_box(root, "Glasfront", (x1 - x0, y1 - y0, 0.003), (0, (y0 + y1) * 0.5, ZT + 0.0012),
                    led.mat("Glasfront", (0.004, 0.009, 0.012), 0.0, 0.35, 0.0, clearcoat=0.25),
                    0.015, 0.0008, 4)
    finish(os.path.join(OUT, "charm_disk.glb"))


def reader():
    reset()
    gun = led.mat("Gussgrau", (0.05, 0.05, 0.06), 0.9, 0.32, clearcoat=0.4)
    black = led.mat("Front", (0.006, 0.006, 0.008), 0.0, 0.08, clearcoat=1.0)
    chrome = led.mat("Chrom", (0.85, 0.86, 0.88), 1.0, 0.08)
    glow = led.mat("Saum", (0.08, 0.1, 0.12), 0.0, 0.3)
    glass = led.mat("Displayglas", (0.004, 0.009, 0.012), 0.0, 0.3, clearcoat=0.5)
    body = led.rounded_box(None, "Gehaeuse", (RW, RL, RH), (0, 0, RH * 0.5), gun, 0.05, 0.02, 8)
    fy = -RL * 0.5
    bezel = led.rounded_box(None, "Blende", (RW - 0.06, 0.04, RH - 0.06), (0, fy, RH * 0.5),
                            black, 0.02, 0.006, 6)
    deep = fc.INSERT + 0.06
    slot = fc.box(None, "SchnittSchlitz", (DW + 0.06, deep, 0.05),
                  (0, fy + deep * 0.5 - 0.04, fc.SLOT_Z), black)
    led.cut(body, slot)
    led.cut(bezel, slot)
    fc.box(None, "Schlitzgrund", (DW + 0.06, 0.01, 0.05), (0, fy + deep - 0.045, fc.SLOT_Z), black)
    fc.box(None, "Lippe", (DW + 0.06, 0.006, 0.007), (0, fy - 0.021, fc.SLOT_Z - 0.04), glow)
    fc.box(None, "Kopfsaum", (RW - 0.12, 0.012, 0.005), (0, fy + 0.035, RH + 0.001), glow)
    # Display, Taste und Lampe liegen OBEN: die Front sieht die Tischkamera kaum.
    fc.box(None, "Display", (0.64, 0.07, 0.004), (-0.12, fy + 0.09, RH + 0.002), glass)
    led.rounded_box(None, "Auswurf", (0.15, 0.075, 0.024), (0.38, fy + 0.09, RH + 0.012), gun,
                    0.012, 0.004, 4)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.012, location=(-0.48, fy + 0.09, RH + 0.004))
    lamp = bpy.context.active_object
    lamp.name = "Lampe"
    lamp.scale = (1, 1, 0.5)
    lamp.data.materials.append(glow)
    for i in range(5):
        for sx in (-1, 1):
            fc.box(None, "Rillen%d_%d" % (i, sx), (0.016, 0.4, 0.004),
                   (sx * (0.4 + i * 0.03), 0.05, RH + 0.0005), black)
    pc = Vector((0, 0.04, RH))
    fc.cyl(None, "Sockel", 0.3, 0.03, pc + Vector((0, 0, 0.015)), chrome)
    fc.cyl(None, "Topf", 0.24, 0.05, pc + Vector((0, 0, 0.04)), gun)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.009,
                                     location=pc + Vector((0, 0, 0.066)))
    ring = bpy.context.active_object
    ring.name = "Ring"
    ring.data.materials.append(glow)
    bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.13, location=pc + Vector((0, 0, 0.062)),
                                         segments=32, ring_count=16)
    lens = bpy.context.active_object
    lens.name = "Linse"
    lens.scale = (1, 1, 0.4)
    lens.data.materials.append(glow)
    bpy.ops.object.shade_smooth()
    fc.empty("LinseMitte", pc + Vector((0, 0, 0.062 + 0.13 * 0.4)))
    for k in range(3):
        a = math.radians(90 + k * 120)
        base = pc + Vector((math.cos(a) * 0.27, math.sin(a) * 0.27, 0.03))
        tilt = math.radians(28)
        dirv = Vector((-math.cos(a) * math.sin(tilt), -math.sin(a) * math.sin(tilt), math.cos(tilt)))
        ln = 0.2
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.012, depth=ln,
                                            location=base + dirv * ln * 0.5)
        rod = bpy.context.active_object
        rod.name = "Stangen%d" % k
        rod.rotation_mode = "QUATERNION"
        rod.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(dirv)
        rod.data.materials.append(chrome)
        bpy.ops.object.shade_smooth()
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.02, location=base + dirv * ln,
                                             segments=16, ring_count=8)
        tip = bpy.context.active_object
        tip.name = "Spitzen%d" % k
        tip.data.materials.append(glow)
        bpy.ops.object.shade_smooth()
    finish(os.path.join(OUT, "charm_reader.glb"), ("Rillen", "Stangen", "Spitzen"))


disk()
reader()
print("ok")
