"""Fumble: exportiert die Charm-DISKETTE und das LAUFWERK (Terminal-Layout, Spieler-Wahl
2026-11-18) als assets/models/hardware/charm_disk.glb und charm_reader.glb.

Aufruf (kopflos):
  blender -b -P tools/blender_floppy_export.py -- assets/models/hardware

charm_disk.glb - NUR die Hülle, Fassung „Stahl“: Korpus (Stahlschale, Chrom-Schieber mit breitem
  Fenster, Nabe, Kerben - Licht eingemalt), Loch*, Glasfront und Rar100Streifen (Godot tönt ihn in
  der Rarität). Text, Bild, Rahmen und LEDs setzt Godot je Charm (CharmDiskView). Ursprung = Mitte
  der Unterseite.
charm_reader.glb - der Projektor „Stahldeck“: die Hülle als EIN Netz Korpus mit eingemaltem
  Licht, die eigenen, benannten Leuchtteile Lippe, Bodensaum, Ring, Linse, Kabellicht, Umriss,
  Steckerlicht, dazu Display (trägt den Charm-Namen) und Auswurf (Godot tönt sie). Ursprung = Mitte unten, Schlitz nach -Y
  (glTF +Z), das Leer-Objekt LinseMitte sitzt auf der Linse.
usb_port.glb - ein Port der USB-Leiste (Platte, Loch, Zunge, Portlicht).
charm_bridge.glb - die Brücke des Laden-Projektors im selben Stil (Korpus eingemalt, Lippe, Ring,
  Linse, Umriss, Display für den Namen, Preisfeld).
Maße in Blender-Einheiten; skaliert wird in Godot (CharmDiskView.BLENDER_SCALE).
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_floppy_charm as fc
import blender_floppy_layouts as fl
import blender_projector_variants as pv
import blender_projector_baked as pb
import blender_floppy_variants as fv

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
    """Die Diskette „Stahl“ (Spieler-Wahl 2026-11-22, tools/blender_floppy_variants.py)."""
    fv.export("stahl", fv.stahl, os.path.join(OUT, "charm_disk.glb"))


def meshify():
    """Kurven (Kabel) und Schrift werden Netze bzw. fallen weg."""
    for o in list(bpy.data.objects):
        if o.type == "FONT":
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.type == "CURVE":
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.convert(target="MESH")
            bpy.ops.object.shade_smooth()


def reader():
    """Der PROJEKTOR „Stahldeck“ (Spieler-Wahl 2026-11-22, tools/blender_projector_baked.py):
    Licht eingemalt, samt USB-Kabel und geradem Stecker; der Wand-Port sitzt bei (0, pv.PORT_Y, pv.PLUG_Z)."""
    pb.export("stahldeck", pb.stahldeck, os.path.join(OUT, "charm_reader.glb"))


def port():
    """Ein Port der USB-LEISTE, Mitte im Ursprung; Ziffer und Schiene setzt Godot."""
    reset()
    pv.port(None, 0, 0.0, 0.0)
    meshify()
    finish(os.path.join(OUT, "usb_port.glb"))


disk()
reader()
port()
pb.export("bruecke", pb.bruecke, os.path.join(OUT, "charm_bridge.glb"))
print("ok")
