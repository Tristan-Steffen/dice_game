"""Fumble: prozedurale Regal-Mulde ("Pit") der Werkbank-Ablage (Blender).

Exakter Nachbau der Konzept-Mulde als REINE FORM - ohne Sortenfarbe, ohne
Inhalt: aussen ein Rundstab an der Oberkante, dann die leicht nach innen
geneigte Auflageflaeche der Lippe (Aschenbecher-Optik) mit je Seite einer
mittig eingeschliffenen Ablage-KERBE, innen eine kleine Rundung, die in die
steile Muldenwand kippt, unten Bodenkehle und die feine Zierlinie im Boden.
Ein einziges Metall-Material ("Pit_Metall").

Aufbau: EIN Kantenprofil (aussen -> innen) wird um Rundeck-Ringe gelegt; der
Eckradius laeuft von CORNER_RADIUS (aussen) nach FLOOR_RADIUS (Boden), damit
der Muldenboden runde Ecken behaelt. Die Kerben senken die Lippen-Stationen
lokal ab: jeder Profilpunkt traegt ein Kerbengewicht, entlang der Seite
laeuft ein weicher Kosinus-Auslauf - dafuer sind die geraden Seiten fein
unterteilt (STRAIGHT_SEGMENTS).

Alles ueber die Parameter unten steuerbar; das Objekt landet in der
Collection "Fumble_PitBay", erneutes Ausfuehren ersetzt den alten Stand.
Nutzung: Blender -> Scripting-Tab -> Datei oeffnen -> Run Script
(oder headless: blender -b -P tools/make_pit_bay.py).

Koordinaten: Mulde liegt in XY um den Ursprung, Standflaeche auf Z=0.
1 Einheit = 1 Godot-Einheit (glTF-Export mit +Y up).
"""
import math

import bpy
import bmesh

# --- Hauptmasse (alles in Welt-Einheiten) --------------------------------------
SIZE = 1.0              # Aussenkante (X = Y)
LIP_HEIGHT = 0.185      # Oberkante der Lippe ueber der Standflaeche
WELL_DEPTH = 0.155      # Muldentiefe ab Lippen-Oberkante (Boden bleibt ueber Z=0)

CORNER_RADIUS = 0.12    # Eckradius aussen
FLOOR_RADIUS = 0.08     # Eckradius am Muldenboden
CORNER_SEGMENTS = 12    # Aufloesung je Viertelkreis-Ecke
STRAIGHT_SEGMENTS = 48  # Unterteilung der geraden Seiten (traegt die Kerben)

# --- Lippen-/Kantenprofil, von aussen nach innen -------------------------------
BEAD_R = 0.012          # Rundstab-Kante aussen (das umlaufende Glanzlicht, schmal)
BEAD_SEGMENTS = 5
LIP_FACE_W = 0.085      # Auflageflaeche der Lippe
LIP_TILT = 0.01         # Neigung der Auflage nach innen unten
INNER_R = 0.015         # Rundung Auflage -> Muldenwand (der innere Lichtsaum)
INNER_SEGMENTS = 5
WALL_SLOPE_DEG = 76.0   # Neigung der Muldenwand gegen die Horizontale (fast senkrecht)
WALL_SEGMENTS = 5       # Zwischenstationen der Wand (Auslauf der Kerben)
FLOOR_FILLET = 0.02     # Kehle Muldenwand -> Boden
FILLET_SEGMENTS = 6

# --- Ablage-Kerben (Aschenbecher-Element, mittig auf jeder Seite) --------------
NOTCHES = True
NOTCH_WIDTH = 0.13      # volle Breite je Kerbe entlang der Seite
NOTCH_DEPTH = 0.05      # Absenkung in der Kerbenmitte
NOTCH_PLATEAU = 0.35    # Anteil flacher Rinnenboden - macht die Kerbe "geschnitten"

# --- Zierlinie im Boden --------------------------------------------------------
FLOOR_GROOVE = True
GROOVE_INSET = 0.05     # Abstand der Linie vom Kehlenende
GROOVE_W = 0.02
GROOVE_DEPTH = 0.007

METAL_COLOR = (0.05, 0.052, 0.06, 1.0)

COLLECTION_NAME = "Fumble_PitBay"
OBJECT_NAME = "PitBay"


def profile_points():
    """Kantenprofil als Liste (Einwaertsversatz, Z, Kerbengewicht, harte Kante)."""
    th = math.radians(WALL_SLOPE_DEG)
    lip = LIP_HEIGHT
    pts = [(0.0, 0.0, 0.0, True)]                  # Standkante
    for i in range(BEAD_SEGMENTS + 1):             # Rundstab: senkrecht -> waagerecht
        a = 0.5 * math.pi * i / BEAD_SEGMENTS
        w = 0.3 + 0.7 * i / BEAD_SEGMENTS          # Kerbe schneidet auch die Aussenkante an
        pts.append((BEAD_R * (1.0 - math.cos(a)),
                    lip - BEAD_R + BEAD_R * math.sin(a), w, False))
    o_face = BEAD_R + LIP_FACE_W
    z_face = lip - LIP_TILT
    pts.append((o_face, z_face, 1.0, False))       # Auflage, leicht nach innen geneigt
    phi = math.atan2(LIP_TILT, LIP_FACE_W)
    cx = o_face - INNER_R * math.sin(phi)
    cz = z_face - INNER_R * math.cos(phi)
    for i in range(1, INNER_SEGMENTS + 1):         # Innenrundung kippt in die Wand
        t = phi + (th - phi) * i / INNER_SEGMENTS
        w = 1.0 - 0.15 * i / INNER_SEGMENTS
        pts.append((cx + INNER_R * math.sin(t), cz + INNER_R * math.cos(t), w, False))
    o_wall, z_wall = pts[-1][0], pts[-1][1]
    z_floor = lip - WELL_DEPTH
    z_end = z_floor + FLOOR_FILLET * (1.0 - math.cos(th))
    drop = z_wall - z_end
    if drop <= 0.0:
        raise ValueError("WELL_DEPTH zu klein fuer Lippe + Kehle")
    o_end = o_wall + drop / math.tan(th)
    for i in range(1, WALL_SEGMENTS + 1):          # Wand; Kerben laufen oben aus
        f = i / WALL_SEGMENTS
        w = 0.85 * max(0.0, 1.0 - f / 0.7)
        pts.append((o_wall + (o_end - o_wall) * f, z_wall - drop * f, w, False))
    co = o_end + FLOOR_FILLET * math.sin(th)       # Kehlen-Mittelpunkt
    czf = z_floor + FLOOR_FILLET
    for i in range(1, FILLET_SEGMENTS + 1):
        t = th * (1.0 - i / FILLET_SEGMENTS)
        pts.append((co - FLOOR_FILLET * math.sin(t),
                    czf - FLOOR_FILLET * math.cos(t), 0.0, False))
    if FLOOR_GROOVE:
        g0 = co + GROOVE_INSET
        pts.append((g0, z_floor, 0.0, False))
        pts.append((g0 + GROOVE_W * 0.5, z_floor - GROOVE_DEPTH, 0.0, False))
        pts.append((g0 + GROOVE_W, z_floor, 0.0, False))
    return pts


def _ring2d(offset, offset_end):
    """Rundeck-Ring beim Einwaertsversatz `offset`, Seiten fein unterteilt."""
    half = SIZE * 0.5 - offset
    t = offset / offset_end if offset_end > 0.0 else 0.0
    r = CORNER_RADIUS + (FLOOR_RADIUS - CORNER_RADIUS) * t
    r = min(r, half - 1e-4)
    c = half - r
    corners = []
    for k in range(4):
        cx = c if k in (0, 3) else -c
        cy = c if k in (0, 1) else -c
        arc = []
        for i in range(CORNER_SEGMENTS + 1):
            a = math.pi * 0.5 * (k + i / CORNER_SEGMENTS)
            arc.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        corners.append(arc)
    pts = []
    for k in range(4):
        pts.extend(corners[k])
        a, b = corners[k][-1], corners[(k + 1) % 4][0]
        for i in range(1, STRAIGHT_SEGMENTS):
            f = i / STRAIGHT_SEGMENTS
            pts.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
    return pts


def _notch_drop(x, y):
    """Absenkung durch die Ablage-Kerben an den vier Seitenmitten."""
    if not NOTCHES:
        return 0.0
    hw = NOTCH_WIDTH * 0.5
    best = 0.0
    for along, across in ((x, y), (y, x)):  # (+-Y-Seiten entlang X, +-X-Seiten entlang Y)
        t = abs(along) / hw
        if t < 1.0 and abs(across) > abs(along):
            # flacher Rinnenboden, dann Kosinus-Flanke: liest sich geschnitten
            tt = max(0.0, (t - NOTCH_PLATEAU) / (1.0 - NOTCH_PLATEAU))
            best = max(best, 0.5 * (1.0 + math.cos(math.pi * tt)))
    return NOTCH_DEPTH * best


def _material(name, color, metallic, roughness):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bsdf is None:
        bsdf = mat.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    mat.diffuse_color = color
    return mat


def _replace_collection():
    coll = bpy.data.collections.get(COLLECTION_NAME)
    if coll is not None:
        for obj in list(coll.objects):
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if data is not None and data.users == 0:
                bpy.data.meshes.remove(data)
        bpy.data.collections.remove(coll)
    coll = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(coll)
    return coll


def build():
    pts = profile_points()
    o_end = pts[-1][0]
    if o_end + FLOOR_RADIUS >= SIZE * 0.5:
        raise ValueError("Profil zu tief fuer SIZE: fuer den Boden bleibt kein Platz")

    bm = bmesh.new()
    rings = []
    for o, z, weight, _sharp in pts:
        ring = []
        for x, y in _ring2d(o, o_end):
            ring.append(bm.verts.new((x, y, z - weight * _notch_drop(x, y))))
        rings.append(ring)
    n = len(rings[0])
    for s in range(len(rings) - 1):
        a, b = rings[s], rings[s + 1]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i])).smooth = True
    bm.faces.new(tuple(reversed(rings[0])))        # Standflaeche
    bm.faces.new(tuple(rings[-1])).smooth = True   # Muldenboden
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for s, (_o, _z, _w, sharp) in enumerate(pts):  # harte Ringe (nur die Standkante)
        if not sharp:
            continue
        ring = rings[s]
        for i in range(n):
            edge = bm.edges.get((ring[i], ring[(i + 1) % n]))
            if edge is not None:
                edge.smooth = False

    mesh = bpy.data.meshes.new(OBJECT_NAME)
    bm.to_mesh(mesh)
    bm.free()
    if hasattr(mesh, "use_auto_smooth"):  # bis 4.0; ab 4.1 gelten scharfe Kanten immer
        mesh.use_auto_smooth = True
        mesh.auto_smooth_angle = math.pi
    mesh.materials.append(_material("Pit_Metall", METAL_COLOR, 1.0, 0.4))

    obj = bpy.data.objects.new(OBJECT_NAME, mesh)
    _replace_collection().objects.link(obj)

    print("PitBay: %d Verts, Boden %.0f%% der Kante, Oeffnung %.0f%%, %s" % (
        len(mesh.vertices),
        200.0 * (SIZE * 0.5 - o_end) / SIZE,
        200.0 * (SIZE * 0.5 - BEAD_R - LIP_FACE_W) / SIZE,
        "4 Ablage-Kerben" if NOTCHES else "ohne Kerben"))
    return obj


if __name__ == "__main__":
    build()
