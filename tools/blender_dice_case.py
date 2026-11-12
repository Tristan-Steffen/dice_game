"""Fumble: die WÜRFEL-SCHATULLE, der Körper eines Würfel-Pakets (Spieler-Wahl 2026-11-10,
Vorlage E:/Generated Images/Fumble/paket_konzepte_2026-11-10/schatulle_2.png).

Aufruf (kopflos):
  blender -b -P tools/blender_dice_case.py -- assets/models/hardware

Gebaut in ROH-Maß der DataCellView (CardPackView skaliert den Körper mit CASSETTE_SCALE),
Blender-Achsen: X = Kartenbreite, Y = Kartenlänge, Z = Höhe; Ursprung = Mitte der Unterseite.
CardPackView dreht den Knoten um +90° um X, dann liegen die Achsen wie in der Zelle.

Die NAHT zwischen Deckel und Boden ist ein eigenes Objekt "Naht": Godot ersetzt ihr
Material durch die Sortenfarbe des Pakets.

Boden und Deckel sind HOHL (Innenraum mit Samt, Material "Samt"); der Deckel hängt samt
Augen und Lasche unter dem Leer-Objekt "Scharnier", dessen Ursprung auf der
Scharnierachse liegt (Langseite +X, gegenüber der Schließe). Positive Drehung um
Blender-Y öffnet ihn.
"""
import bpy, math, sys, os

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/models/hardware"
os.makedirs(OUT, exist_ok=True)

# Spiegelt CardPackView: FOOT_ROOM 1,04 × Karte (WIDTH 1,08, HEIGHT 1,62), Höhe 3,2 × DEPTH.
W = 1.08 * 1.04
L = 1.62 * 1.04
H = 0.1512 * 3.2
BODY_H = H * 0.50
GAP = H * 0.05
LID_H = H - BODY_H - GAP
CORNER = W * 0.16
# Der INNENRAUM (spiegelt CardPackView.CASE_WALL/CASE_FLOOR/CASE_LID_TOP).
WALL = 0.05
FLOOR = 0.03
LID_TOP = 0.04


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


def rounded_slab(name, size, z0, material, corner, edge_round):
    """Kissenform: große Rundung der senkrechten Kanten, kleinere an Ober- und Unterkante."""
    sx, sy, sz = size
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, z0 + sz * 0.5))
    o = bpy.context.active_object
    o.name = name
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    for e in o.data.edges:
        v0 = o.data.vertices[e.vertices[0]].co
        v1 = o.data.vertices[e.vertices[1]].co
        e.bevel_weight = 1.0 if abs(v0.z - v1.z) > 1e-6 else 0.0
    plan = o.modifiers.new("Grundriss", "BEVEL")
    plan.limit_method = "WEIGHT"
    plan.width = corner
    plan.segments = 10
    rim = o.modifiers.new("Kante", "BEVEL")
    rim.limit_method = "ANGLE"
    rim.angle_limit = math.radians(60)
    rim.width = edge_round
    rim.segments = 6
    bpy.ops.object.shade_smooth()
    o.data.use_auto_smooth = True
    o.data.auto_smooth_angle = math.radians(60)
    return o


def cyl(name, radius, depth, loc, material, rot=(0, 0, 0), verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


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
        mod.segments = 3
        mod.limit_method = "ANGLE"
        bpy.ops.object.shade_smooth()
        o.data.use_auto_smooth = True
        o.data.auto_smooth_angle = math.radians(40)
    return o


def apply_all(o):
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    for mod in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def cutter(name, z0, z1, material):
    """Der Innenraum als Schneidkörper: Grundriß um die Wand eingerückt, Ecken gerundet."""
    o = rounded_slab(name, (W - WALL * 2.0, L - WALL * 2.0, z1 - z0), z0, material,
                     CORNER - WALL, 0.0005)
    apply_all(o)
    return o


def hollow(target, cut, transfer=True):
    """Schneidet den Innenraum aus; die Schnittflächen tragen den Samt des Schneiders."""
    apply_all(target)
    mod = target.modifiers.new("Hohl", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cut
    if transfer:
        mod.material_mode = "TRANSFER"
    apply_all(target)


def build():
    reset()
    lack = mat("Lack", (0.055, 0.055, 0.07), 0.65, 0.22)
    stahl = mat("Stahl", (0.62, 0.63, 0.68), 1.0, 0.2)
    dunkel = mat("Mulde", (0.02, 0.02, 0.03), 0.4, 0.35)
    naht = mat("Naht", (1.0, 0.55, 0.25), 0.0, 0.5, (1.0, 0.55, 0.25), 1.2)
    samt = mat("Samt", (0.035, 0.02, 0.05), 0.0, 1.0)

    boden = rounded_slab("Boden", (W, L, BODY_H), 0.0, lack, CORNER, H * 0.09)
    # Der Deckel wölbt sich: seine Kanten runden kräftiger als die des Bodens.
    deckel = rounded_slab("Deckel", (W, L, LID_H), BODY_H + GAP, lack, CORNER, H * 0.17)
    # Die NAHT steht über die Kante vor - von oben umläuft sie die Schatulle als Leuchtrand.
    inset = -W * 0.03
    nahtring = rounded_slab("Naht", (W - inset * 2.0, L - inset * 2.0, GAP * 1.6),
                            BODY_H - GAP * 0.3, naht, CORNER - inset, GAP * 0.4)
    # Boden, Naht und Deckel sind HOHL: der Samt liegt innen, die Würfel darin.
    cut_body = cutter("SchnittBoden", FLOOR, BODY_H + GAP * 2.0, samt)
    hollow(boden, cut_body)
    hollow(nahtring, cut_body, False)
    cut_lid = cutter("SchnittDeckel", BODY_H - GAP, H - LID_TOP, samt)
    hollow(deckel, cut_lid)
    for o in (cut_body, cut_lid):
        bpy.data.objects.remove(o, do_unlink=True)
    # Die SCHLIESSE an der Langseite (Blender -X): der Riegel am Boden, die Lasche am Deckel.
    face = -W * 0.5
    clasp_w = L * 0.17
    plate_h = BODY_H * 0.62
    plate_z = BODY_H - plate_h * 0.5
    box("Schliesse", (0.035, clasp_w, plate_h), (face - 0.012, 0, plate_z), stahl, 0.012)
    box("SchliesseMulde", (0.02, clasp_w * 0.72, plate_h * 0.5),
        (face - 0.03, 0, plate_z - plate_h * 0.1), dunkel, 0.006)
    cyl("Knopf", clasp_w * 0.17, 0.02, (face - 0.042, 0, plate_z - plate_h * 0.1), stahl,
        (0, math.pi / 2, 0))
    lid_parts = [deckel]
    lid_parts.append(box("Lasche", (0.03, clasp_w * 0.86, H * 0.2),
                         (face - 0.03, 0, BODY_H + GAP * 0.5 + H * 0.02), stahl, 0.01))
    # Die SCHARNIER-ROLLEN gegenüber der Schließe, auf der Achse des Deckels.
    hinge_x = W * 0.5
    hinge_z = BODY_H + GAP * 0.5
    for i, oy in enumerate((-L * 0.3, L * 0.3)):
        cyl("ScharnierRolle%d" % i, GAP * 1.4, L * 0.16, (hinge_x + GAP * 0.4, oy, hinge_z),
            stahl, (math.pi / 2, 0, 0), 16)
    # Fünf AUGEN auf dem Deckel (wie in der Vorlage als Kreuz), je ein Stahlring mit Mulde.
    top = H - 0.002
    step = W * 0.2
    for i, (ox, oy) in enumerate(((0, 0), (step, 0), (-step, 0), (0, step), (0, -step))):
        bpy.ops.mesh.primitive_torus_add(major_radius=W * 0.04, minor_radius=W * 0.012,
                                         major_segments=24, minor_segments=8,
                                         location=(ox, oy, top))
        ring = bpy.context.active_object
        ring.name = "Auge%d" % i
        ring.data.materials.append(stahl)
        bpy.ops.object.shade_smooth()
        lid_parts.append(ring)
        lid_parts.append(cyl("AugeMulde%d" % i, W * 0.034, 0.006, (ox, oy, top - 0.002), dunkel))
    # Das SCHARNIER: sein Ursprung liegt auf der Achse, alles am Deckel hängt darunter.
    hinge = bpy.data.objects.new("Scharnier", None)
    bpy.context.scene.collection.objects.link(hinge)
    hinge.location = (hinge_x, 0.0, hinge_z)
    bpy.context.view_layer.update()
    for part in lid_parts:
        world = part.matrix_world.copy()
        part.parent = hinge
        part.matrix_world = world
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dice_case.glb"), use_selection=True,
                              export_apply=True, export_format="GLB")


build()
print("FERTIG", OUT)
