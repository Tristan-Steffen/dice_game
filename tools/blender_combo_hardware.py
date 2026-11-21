"""Fumble: der Kombinations-Chip als .glb.

Aufruf (kopflos):
  blender -b -P tools/blender_combo_hardware.py -- assets/models/hardware

  chip_wide.glb (in assets/models/) - der Kombinations-Chip (2026-11-21): chip.glb ohne
      Die-Fenster, in X auf WIDE_LENGTH verlängert ohne Verzerrung. ComboChipView staucht
      seine Gehäuse-Mitte im Spiel auf BODY_COMPACT; rechts stehen die Modul-Pins
      (tools/blender_pin_models.py). Glb-Achsen: Godot (x, y, z) = Blender (x, -z, y).

Modul-Gehäuse, Buchse und chip_socketed.glb sind gestorben (2026-11-21, nur noch Pins).
"""
import bpy, math, sys, os

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = next((a for a in ARGS if a != "wide"), "assets/models/hardware")
os.makedirs(OUT, exist_ok=True)
CHIP_IN = os.path.join(os.path.dirname(os.path.abspath(OUT)), "chip.glb")
CHIP_WIDE_OUT = os.path.join(os.path.dirname(os.path.abspath(OUT)), "chip_wide.glb")
# ComboChipView.MODEL_LENGTH: Pin-Spitze zu Pin-Spitze bei GLEICHER Skala in X und Z
# (TableScreen.CELL_SIZE 133 x 31 x 1,4 x 3, FIT 0,86 -> 14,896 x 0,86 / 0,142187).
WIDE_LENGTH = 90.1

# --- ComboChipView (Modell-Einheiten) ---
BODY_TOP = 9.0


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, metal, rough, emit=None, strength=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


def box(name, size, loc, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if material:
        o.data.materials.append(material)
    if bevel > 0.0:
        mod = o.modifiers.new("Fase", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        apply_mods(o)
    return o


def cyl(name, radius, depth, loc, material, verts=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    if material:
        o.data.materials.append(material)
    return o


def apply_mods(o):
    bpy.context.view_layer.objects.active = o
    for mod in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def cut(target, cutter):
    mod = target.modifiers.new("Schnitt", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    apply_mods(target)
    bpy.data.objects.remove(cutter, do_unlink=True)


def join(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    return o


def chip_wide():
    """chip.glb ohne Buchsen und Die-Fenster, in X verlängert OHNE Verzerrung: alles rechts der
    Mitte rückt um den halben Zuwachs nach rechts, alles links nach links - Pins, Ecken und
    Frontband behalten ihre Form."""
    reset()
    bpy.ops.import_scene.gltf(filepath=CHIP_IN)
    for name in ("Die", "PinOneDot"):
        o = bpy.data.objects.get(name)
        if o is not None:
            bpy.data.objects.remove(o, do_unlink=True)
    body = bpy.data.objects["Body"]
    fill = box("Fuellung", (32.0, 16.0, 1.6), (0, 0, BODY_TOP - 0.8 - 0.001), None)
    mod = body.modifiers.new("Fuellen", "BOOLEAN")
    mod.operation = "UNION"
    mod.solver = "EXACT"
    mod.object = fill
    apply_mods(body)
    bpy.data.objects.remove(fill, do_unlink=True)
    grow = (WIDE_LENGTH - 42.4) * 0.5
    for name in ("Body", "Pins", "Display"):
        o = bpy.data.objects[name]
        for v in o.data.vertices:
            world_x = (o.matrix_world @ v.co).x
            if abs(world_x) > 1e-4:
                v.co.x += grow if world_x > 0.0 else -grow
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=CHIP_WIDE_OUT, use_selection=True, export_apply=True,
                              export_format="GLB")


chip_wide()
print("FERTIG", CHIP_WIDE_OUT)
