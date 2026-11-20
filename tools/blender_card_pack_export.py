"""Fumble: exportiert die vier gewählten KARTEN-PAKETE (Spieler-Wahl 2026-11-20 aus
tools/blender_card_pack_media.py) nach assets/models/hardware/card_pack_<sorte>_<n>.glb:
  number   - LOCHTASCHE     material - KASSETTENFACH
  rune     - TONHÜLLE       special  - BLISTER
Je Sorte und Kartenzahl (3/4/5) EIN Netz "Pack"; Godot gibt die Materialien nach ihrem
NAMEN (CardPackView._dress_pack_part): Tinte_<sorte> = Sortendruck, Sorte_* = Sortenlicht,
Praegung / MetallGuete = die Güte, Klar_* = Klarsicht. Die Karten legt Godot hinein.

Aufruf (kopflos):
  blender -b -P tools/blender_card_pack_export.py -- <ausgabe-ordner>
"""
import bpy, math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_card_box as box
import blender_card_pack_media as pm

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/models/hardware"
PACKS = [("number", "zahl", pm.lochtasche), ("material", "material", pm.kassettenfach),
         ("rune", "rune", pm.tonhuelle), ("special", "sonder", pm.blister)]


def quality_foil(_q):
    return led.mat("Praegung", (0.9, 0.9, 0.92), 0.7, 0.22)


def quality_metal(_q):
    return led.mat("MetallGuete", (0.8, 0.8, 0.84), 0.9, 0.2)


def build(sort, fn, count):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    led._mats.clear()
    led.base_materials()
    bpy.ops.object.empty_add()
    root = bpy.context.active_object
    fn(root, sort, count, 1)
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
        if o.type != "MESH" or o.display_type == "WIRE" or o.name.startswith("Schnitt"):
            bpy.data.objects.remove(o, do_unlink=True)
    parts = list(bpy.data.objects)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.parent = None
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    pack = bpy.context.active_object
    pack.name = "Pack"
    pack.data.name = "Pack"
    pack.data.use_auto_smooth = True
    pack.data.auto_smooth_angle = math.radians(50)
    print("PAKET %s %d: %d Dreiecke, %d Materialien" % (
        sort, count, sum(len(p.vertices) - 2 for p in pack.data.polygons),
        len(pack.data.materials)))


if __name__ == "__main__":
    pm.EXPORT = True
    box.foil = quality_foil
    pm.foil_on_light = quality_foil
    led.metal = quality_metal
    os.makedirs(OUT, exist_ok=True)
    for key, sort, fn in PACKS:
        for count in (3, 4, 5):
            build(sort, fn, count)
            bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "card_pack_%s_%d.glb" % (key, count)),
                                      export_format="GLB", export_apply=True)
    print("ok")
