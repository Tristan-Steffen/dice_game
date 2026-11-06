"""Fumble: der ENERGIE-RING als ZIKKURAT (Spieler-Wahl 2026-11-06 aus fuenf Entwuerfen):
drei Terrassen, aussen flach, innen hoeher, der Kern obenauf.

Aufruf (kopflos):
  blender -b -P tools/blender_energy_ring.py -- assets/models/hardware

energy_ring.glb in eigenen Einheiten (Radius 1,06); EnergyRingView skaliert es in den
Platz. Ursprung = Mitte der Unterseite. glTF: Godot (x, y, z) = Blender (x, -z, y), und
Bild-oben ist Godot +X, Bild-rechts Godot +Z.

Knoten: Gehaeuse, Core (Godot laesst ihn leuchten) und Seg00..Seg49 (Godot faerbt je
Zustand). Seg00..Seg24 liegen aussen, Seg25..Seg49 innen, je im Uhrzeigersinn ab Bild-oben.

Die Zahlen spiegeln EnergyRingView (BASE_RADIUS, CORE_TOP) und GameRun.ENERGY_CAP_LIMIT -
wer sie dort aendert, zieht sie hier nach.
"""
import bpy, bmesh, math, sys, os

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/models/hardware"
os.makedirs(OUT, exist_ok=True)

SEGMENTS = 50
RING_SEGMENTS = SEGMENTS // 2
GROUP_SIZE = 5
GROUP_GAP_DEG = 5.0
SEGMENT_GAP_DEG = 1.4
SEGMENT_STEPS = 4

BASE_RADIUS = 1.06
DRUM_RADIUS = 1.0
OUTER_DECK = 0.20
INNER_DECK = 0.32
CORE_SHOULDER = 0.45
SEGMENT_RISE = 0.025
RIB_RISE = 0.035
OUTER_RING = (0.825, 0.985)
INNER_RING = (0.645, 0.78)
INNER_STEP = 0.80
CORE_STEP = 0.625
CORE_RADIUS = 0.61
CORE_BASE = 0.43
CORE_TOP = 0.49
LATHE_STEPS = 128


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, metal, rough, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


def finish(name, bm, material, smooth=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material)
    if smooth:
        for poly in mesh.polygons:
            poly.use_smooth = True
        mesh.use_auto_smooth = True
        mesh.auto_smooth_angle = math.radians(35.0)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def lathe(name, profile, material):
    """Dreht ein Profil [(radius, hoehe), ...] um die Hochachse."""
    bm = bmesh.new()
    rings = []
    for radius, z in profile:
        rings.append([bm.verts.new((radius * math.cos(a), radius * math.sin(a), z))
                      for a in (2.0 * math.pi * i / LATHE_STEPS for i in range(LATHE_STEPS))])
    for k in range(len(rings) - 1):
        for i in range(LATHE_STEPS):
            j = (i + 1) % LATHE_STEPS
            if rings[k][i].co != rings[k + 1][i].co:
                bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    bm.faces.new(rings[-1])
    bm.faces.new(rings[0])
    return finish(name, bm, material)


def tube(name, inner, outer, z0, z1, material):
    bm = bmesh.new()
    corners = [(inner, z0), (outer, z0), (outer, z1), (inner, z1)]
    rings = [[bm.verts.new((r * math.cos(a), r * math.sin(a), z))
              for a in (2.0 * math.pi * i / LATHE_STEPS for i in range(LATHE_STEPS))]
             for r, z in corners]
    for k in range(4):
        n = (k + 1) % 4
        for i in range(LATHE_STEPS):
            j = (i + 1) % LATHE_STEPS
            bm.faces.new((rings[k][i], rings[k][j], rings[n][j], rings[n][i]))
    return finish(name, bm, material)


def sector(name, radii, center_deg, span_deg, z0, z1, material, z1_outer=None):
    """Ein Ringstueck; center_deg laeuft im Uhrzeigersinn ab Bild-oben. z1_outer neigt die Oberseite."""
    z1_outer = z1 if z1_outer is None else z1_outer
    bm = bmesh.new()
    rows = []
    for step in range(SEGMENT_STEPS + 1):
        deg = center_deg - span_deg * 0.5 + span_deg * step / SEGMENT_STEPS
        a = math.radians(deg)
        # Bild-oben = Godot +X = Blender +X, Bild-rechts = Godot +Z = Blender -Y.
        cx, cy = math.cos(a), -math.sin(a)
        rows.append([bm.verts.new((radii[0] * cx, radii[0] * cy, z0)),
                     bm.verts.new((radii[1] * cx, radii[1] * cy, z0)),
                     bm.verts.new((radii[1] * cx, radii[1] * cy, z1_outer)),
                     bm.verts.new((radii[0] * cx, radii[0] * cy, z1))])
    for s in range(SEGMENT_STEPS):
        for k in range(4):
            n = (k + 1) % 4
            bm.faces.new((rows[s][k], rows[s][n], rows[s + 1][n], rows[s + 1][k]))
    bm.faces.new(rows[0])
    bm.faces.new(rows[-1])
    return finish(name, bm, material, smooth=False)


def segment_angle(ring_index):
    group_span = 360.0 * GROUP_SIZE / RING_SEGMENTS
    span = segment_span()
    group = ring_index // GROUP_SIZE
    slot = ring_index % GROUP_SIZE
    return group * group_span + GROUP_GAP_DEG * 0.5 + span * 0.5 + slot * (span + SEGMENT_GAP_DEG)


def segment_span():
    group_span = 360.0 * GROUP_SIZE / RING_SEGMENTS
    return (group_span - GROUP_GAP_DEG - SEGMENT_GAP_DEG * (GROUP_SIZE - 1)) / GROUP_SIZE


def join(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    return joined


def build():
    reset()
    steel = mat("Gehaeuse", (0.44, 0.47, 0.57), 0.15, 0.5)
    gold = mat("Gold", (1.0, 0.76, 0.33), 1.0, 0.22, (0.92, 0.74, 0.34), 0.35)
    core = mat("Kern", (0.02, 0.03, 0.05), 0.3, 0.2)
    segment = mat("Segment", (0.05, 0.06, 0.08), 0.5, 0.3)

    shell = lathe("Stufen", [
        (0.0, 0.0), (BASE_RADIUS, 0.0), (BASE_RADIUS, 0.05), (DRUM_RADIUS, 0.09),
        (DRUM_RADIUS, OUTER_DECK), (INNER_STEP, OUTER_DECK), (INNER_STEP, INNER_DECK),
        (CORE_STEP, INNER_DECK), (CORE_STEP, CORE_SHOULDER), (0.0, CORE_SHOULDER)], steel)
    parts = [shell]
    # Die Fuenfergruppen trennen Rippen; Streben stuetzen die innere Terrasse auf der aeusseren.
    group_span = 360.0 * GROUP_SIZE / RING_SEGMENTS
    rib_span = GROUP_GAP_DEG * 0.7
    for g in range(RING_SEGMENTS // GROUP_SIZE):
        center = g * group_span
        parts.append(sector("RippeInnen%d" % g, (CORE_STEP, INNER_STEP), center, rib_span,
                            INNER_DECK, INNER_DECK + RIB_RISE, steel))
        parts.append(sector("RippeAussen%d" % g, (0.90, DRUM_RADIUS), center, rib_span,
                            OUTER_DECK, OUTER_DECK + RIB_RISE, steel))
        parts.append(sector("Strebe%d" % g, (INNER_STEP - 0.005, 0.90), center, rib_span,
                            OUTER_DECK, INNER_DECK, steel, OUTER_DECK + RIB_RISE))
    join("Gehaeuse", parts)

    tube("Goldfuss", DRUM_RADIUS, BASE_RADIUS - 0.006, 0.05, 0.056, gold)
    tube("Goldkante1", INNER_STEP, INNER_STEP + 0.015, INNER_DECK - 0.02, INNER_DECK + 0.01, gold)
    tube("Goldkante2", CORE_STEP, CORE_STEP + 0.015, CORE_SHOULDER - 0.02, CORE_SHOULDER + 0.01, gold)
    lathe("Core", [(0.0, CORE_BASE), (CORE_RADIUS, CORE_BASE), (CORE_RADIUS, CORE_TOP - 0.015),
                   (CORE_RADIUS - 0.03, CORE_TOP), (0.0, CORE_TOP)], core)
    span = segment_span()
    for i in range(SEGMENTS):
        radii, deck = (OUTER_RING, OUTER_DECK) if i < RING_SEGMENTS else (INNER_RING, INNER_DECK)
        sector("Seg%02d" % i, radii, segment_angle(i % RING_SEGMENTS), span,
               deck, deck + SEGMENT_RISE, segment)

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "energy_ring.glb"),
                              use_selection=True, export_apply=True, export_format="GLB")


build()
