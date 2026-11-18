"""Fumble: die BUCHSE der Magazin-Mulden als .glb (Spieler-Entscheid 2026-10-27; der STECKER
der Karte ist mit den Datenträgern der Welle 3 gestorben).

Aufruf (kopflos):
  blender -b -P tools/blender_hardware.py -- assets/models/hardware

Mit Godot-Achsen gedacht (glTF: Godot (x, y, z) = Blender (x, -z, y) umgestellt - hier
wird direkt in Blender-Achsen gebaut):

  card_socket.glb - in WELT-Maß (Karte bei CASSETTE_SCALE 3,2). Ursprung = Mitte des
      MUNDES auf Stifthöhe; der Körper reicht nach Godot +Z (weg von der Karte).

Die Zahlen spiegeln DataCellView (WIDTH 1,08 / DEPTH 0,1512) - wer sie dort ändert,
zieht sie hier nach.
"""
import bpy, math, sys, os

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/models/hardware"
os.makedirs(OUT, exist_ok=True)

SCALE = 3.2
W = 1.08                  # DataCellView.WIDTH
D = 0.1512                # DataCellView.DEPTH
PINS = 8
SPREAD = W * 0.74
PIN_R = 0.016             # roh; in Welt 0,051
SOCKET_DEPTH = 0.15       # Welt
HOLE_DEPTH = 0.13
LIP = 0.05                # Welt: Rand der Buchse über und unter der Karte


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
    o.data.materials.append(material)
    if bevel > 0.0:
        mod = o.modifiers.new("Fase", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    return o


def cyl(name, radius, depth, loc, material, rot=(0, 0, 0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


def pin_xs(spread):
    return [-spread * 0.5 + spread * i / (PINS - 1) for i in range(PINS)]


def export(path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=True,
                              export_format="GLB")


def socket():
    reset()
    gold = mat("Gold", (1.0, 0.76, 0.33), 1.0, 0.22, (0.92, 0.74, 0.34), 0.35)
    body_mat = mat("Buchse", (0.08, 0.08, 0.11), 0.3, 0.4)
    hole_mat = mat("Lochung", (0.005, 0.005, 0.01), 0.0, 0.9)
    width = W * SCALE * 0.92
    height = D * SCALE + LIP * 2.0
    spread = SPREAD * SCALE
    hole_r = PIN_R * SCALE * 1.35
    # Mund bei Blender y = 0 (Godot z = 0), Körper nach Blender -y (Godot +z).
    body = box("Koerper", (width, SOCKET_DEPTH, height), (0, -SOCKET_DEPTH * 0.5, 0), body_mat)
    for x in pin_xs(spread):
        cutter = cyl("Schnitt", hole_r, HOLE_DEPTH * 2.0, (x, 0, 0), hole_mat,
                     (math.pi / 2, 0, 0))
        mod = body.modifiers.new("Loch", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.object = cutter
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
    fase = body.modifiers.new("Fase", "BEVEL")
    fase.width = 0.012
    fase.segments = 1
    fase.limit_method = "ANGLE"
    for i, x in enumerate(pin_xs(spread)):
        bpy.ops.mesh.primitive_torus_add(major_radius=hole_r, minor_radius=0.012,
                                         major_segments=20, minor_segments=6,
                                         location=(x, 0.002, 0), rotation=(math.pi / 2, 0, 0))
        ring = bpy.context.active_object
        ring.name = "Feder%d" % i
        ring.data.materials.append(gold)
        cyl("Kontakt%d" % i, hole_r * 0.8, 0.01, (x, -HOLE_DEPTH + 0.005, 0), gold,
            (math.pi / 2, 0, 0))
    # Eine Goldkante am Mund oben und unten - so liest der Mund auch von schräg oben.
    for s in (-1, 1):
        box("Lippe", (width * 0.96, 0.012, 0.018), (0, -0.004, s * (height * 0.5 - 0.02)), gold)
    export(os.path.join(OUT, "card_socket.glb"))


socket()
print("FERTIG", OUT)
