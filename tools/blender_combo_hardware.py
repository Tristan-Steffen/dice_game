"""Fumble: MODUL, seine BUCHSE und der Chip mit eingeformten Buchsen als .glb
(Spieler-Wunsch 2026-11-02 - Stecker und Buchse als passendes Paar wie bei der Datenkarte).

Aufruf (kopflos):
  blender -b -P tools/blender_combo_hardware.py -- assets/models/hardware

Drei Modelle (die Platine baut blender_part_models.py), alle in Blender-Achsen gebaut (glTF: Godot (x, y, z) = Blender (x, -z, y)):

  part_module.glb - das EINE Modul-Gehäuse in WELT-Maß. Ursprung = Mitte der
      Gehäuse-UNTERSEITE; darunter ragt der STECKER (3 x 3 Goldstifte), oben liegt das
      FENSTER, das Godot in der Phasen-Tönung leuchten läßt. Knoten: Gehaeuse, Fenster,
      Stecker.
  part_socket.glb - die BUCHSE in WELT-Maß. Ursprung = Mitte des MUNDES auf der
      Deckelfläche; die Wanne reicht nach unten. Knoten: Wanne, Kontakte, Mund.
  chip_socketed.glb (in assets/models/) - assets/models/chip.glb mit gefülltem
      Die-Fenster und drei Buchsen-Löchern im Deckel, in MODELL-Einheiten (die
      Godot-Seite streckt den Chip in X stärker als in Z - darum sind die Löcher in X
      um NOMINAL_SX / NOMINAL_SZ schmaler geschnitten).

Die Zahlen spiegeln ComboPartBody (SIDE, HEIGHT, WELL, CLEARANCE, WALL, FLOOR, PIN_*,
RISER_*) und ComboChipView (MOLDED_X, MOLDED_Z, BODY_TOP) - wer sie dort ändert, zieht
sie hier nach. NOMINAL_SX/SZ sind die Skalen, die ComboChipView.setup aus
TableScreen.CELL_SIZE (98 x 31 x CLUSTER_SCALE 1,4, SUPERSAMPLE 3, 37,5 px je Welt) und FIT_* rechnet.
"""
import bpy, math, sys, os

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/models/hardware"
os.makedirs(OUT, exist_ok=True)
CHIP_IN = os.path.join(os.path.dirname(os.path.abspath(OUT)), "chip.glb")
CHIP_OUT = os.path.join(os.path.dirname(os.path.abspath(OUT)), "chip_socketed.glb")

# --- ComboPartBody (Welt) ---
SIDE = 0.8                # Gehäuse-Kante
HEIGHT = 0.32             # Gehäuse-Höhe
WELL = 0.19               # so tief sinkt das Gehäuse in die Buchse
CLEARANCE = 0.014         # Luft zwischen Gehäuse und Mund
WALL = 0.02               # Wandstärke der Wanne
FLOOR = 0.11              # Boden der Wanne (die Stifte enden darin)
PIN_R = 0.03
PIN_LEN = 0.095
PIN_PITCH = SIDE * 0.26
WINDOW = SIDE * 0.66
MOUTH = SIDE + 2 * CLEARANCE
OUTER = MOUTH + 2 * WALL

# --- ComboChipView (Modell-Einheiten) ---
BODY_TOP = 9.0
MOLDED_X = [4.5, 8.85, 13.2]
MOLDED_Z = 2.6            # Godot-Z (nach vorn); Blender-Y = -Z
NOMINAL_SX = 0.22262642   # TableScreen.CLUSTER_SCALE 1,4
NOMINAL_SZ = 0.14218667


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


def pin_grid():
    return [(PIN_PITCH * i, PIN_PITCH * j) for i in (-1, 0, 1) for j in (-1, 0, 1)]


def export(path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=True,
                              export_format="GLB")


def materials():
    return {
        "gold": mat("Gold", (1.0, 0.76, 0.33), 1.0, 0.22, (0.92, 0.74, 0.34), 0.35),
        "housing": mat("Modulgehaeuse", (0.07, 0.07, 0.09), 0.2, 0.45),
        "window": mat("Fenster", (0.8, 0.8, 0.8), 0.0, 0.3, (1, 1, 1), 1.0),
        "board": mat("Platine", (0.05, 0.08, 0.07), 0.1, 0.6),
        "trace": mat("Bahn", (0.6, 0.65, 0.74), 0.3, 0.4, (0.6, 0.65, 0.74), 0.8),
        "well": mat("Wanne", (0.02, 0.02, 0.03), 0.1, 0.8),
        "lip": mat("Mund", (0.3, 0.34, 0.45), 0.4, 0.4, (0.3, 0.34, 0.45), 0.4),
    }


def housing_and_plug(m):
    """Gehäuse samt Stecker - in Modul und Platine byteweise gleich."""
    body = box("Gehaeuse", (SIDE, SIDE, HEIGHT), (0, 0, HEIGHT * 0.5), m["housing"], 0.01)
    parts = []
    collar = box("Kragen", (SIDE * 0.84, SIDE * 0.84, 0.008), (0, 0, -0.004), m["gold"])
    parts.append(collar)
    for x, y in pin_grid():
        parts.append(cyl("Stift", PIN_R, PIN_LEN, (x, y, -PIN_LEN * 0.5), m["gold"]))
        parts.append(cyl("Spitze", PIN_R * 0.6, 0.006, (x, y, -PIN_LEN - 0.003), m["gold"]))
    plug = join("Stecker", parts)
    return body, plug


def module():
    reset()
    m = materials()
    body, _plug = housing_and_plug(m)
    # Eine flache Fase rings um das Fenster: der Rahmen ist Gehäuse, das Licht liegt darin.
    bezel = box("Blende", (WINDOW + 0.04, WINDOW + 0.04, 0.008),
                (0, 0, HEIGHT + 0.004), m["housing"])
    join("Gehaeuse", [body, bezel])
    box("Fenster", (WINDOW, WINDOW, 0.01), (0, 0, HEIGHT + 0.006), m["window"])
    export(os.path.join(OUT, "part_module.glb"))


def socket():
    reset()
    m = materials()
    depth = WELL + FLOOR
    wall_parts = []
    for s in (-1, 1):
        wall_parts.append(box("Wand", (OUTER, WALL, WELL), (0, s * (MOUTH + WALL) * 0.5, -WELL * 0.5),
                              m["well"]))
        wall_parts.append(box("Wand", (WALL, MOUTH, WELL), (s * (MOUTH + WALL) * 0.5, 0, -WELL * 0.5),
                              m["well"]))
    floor = box("Boden", (OUTER, OUTER, FLOOR), (0, 0, -WELL - FLOOR * 0.5), m["well"])
    for x, y in pin_grid():
        cut(floor, cyl("Loch", PIN_R * 1.5, FLOOR * 1.6, (x, y, -WELL), None))
    join("Wanne", wall_parts + [floor])
    contacts = []
    for x, y in pin_grid():
        bpy.ops.mesh.primitive_torus_add(major_radius=PIN_R * 1.5, minor_radius=0.008,
                                         major_segments=16, minor_segments=5,
                                         location=(x, y, -WELL + 0.002))
        ring = bpy.context.active_object
        ring.data.materials.append(m["gold"])
        contacts.append(ring)
        contacts.append(cyl("Kontakt", PIN_R * 1.2, 0.006, (x, y, -WELL - PIN_LEN), m["gold"]))
    join("Kontakte", contacts)
    # Der MUND: ein flacher Rahmen bündig auf dem Deckel - er trägt die Zustände.
    lip_w = WALL + 0.012
    lip = []
    for s in (-1, 1):
        lip.append(box("Lippe", (OUTER + 0.024, lip_w, 0.005),
                       (0, s * (MOUTH + lip_w) * 0.5, 0.0035), m["lip"]))
        lip.append(box("Lippe", (lip_w, MOUTH, 0.005),
                       (s * (MOUTH + lip_w) * 0.5, 0, 0.0035), m["lip"]))
    join("Mund", lip)
    export(os.path.join(OUT, "part_socket.glb"))
    return depth


def chip(depth):
    reset()
    bpy.ops.import_scene.gltf(filepath=CHIP_IN)
    for name in ("Die", "PinOneDot"):
        o = bpy.data.objects.get(name)
        if o is not None:
            bpy.data.objects.remove(o, do_unlink=True)
    body = bpy.data.objects["Body"]
    # Die-Fenster und Pin-1-Punkt zuschütten: der Deckel ist ganz Display-Fläche.
    fill = box("Fuellung", (32.0, 16.0, 1.6), (0, 0, BODY_TOP - 0.8 - 0.001), None)
    mod = body.modifiers.new("Fuellen", "BOOLEAN")
    mod.operation = "UNION"
    mod.solver = "EXACT"
    mod.object = fill
    apply_mods(body)
    bpy.data.objects.remove(fill, do_unlink=True)
    hole_x = OUTER / NOMINAL_SX
    hole_y = OUTER / NOMINAL_SZ
    hole_z = (depth + 0.01) / NOMINAL_SZ
    for x in MOLDED_X:
        cutter = box("Buchse", (hole_x, hole_y, hole_z * 2.0), (x, -MOLDED_Z, BODY_TOP), None)
        cut(body, cutter)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=CHIP_OUT, use_selection=True, export_apply=True,
                              export_format="GLB")


module()
chip(socket())
print("FERTIG", OUT, CHIP_OUT)
