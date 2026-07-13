"""Fumble: prozeduraler Poker-Tischplatten-Generator (Blender).

Baut eine Stadion-foermige Tischplatte nach Vorbild eines LED-Pokertischs:
gepolsterte Leder-Railwulst, blau leuchtende LED-Rinne, Chrom-Zierring an der
Kante zur Spielflaeche, die gesamte Innenflaeche als BILDSCHIRM ("Screen",
mit planaren UVs und eigenem Material - Godot ueberschreibt es mit einer
ViewportTexture), goldener Emitter-Ring in den Massen der Wuerfelgrube
(dice_tray.gd) und ein magentafarbener Underglow-Streifen an der Zargen-
Unterkante. Nur die Platte - keine Beine, keine Becherhalter, kein Chiptray.

Alles ist ueber die Parameter unten steuerbar (Gesamtmass, Wulststaerke,
Bandbreiten ...) und landet in der Collection "Fumble_PokerTable"; erneutes
Ausfuehren ersetzt den alten Stand komplett.
Nutzung: Blender -> Scripting-Tab -> Datei oeffnen -> Run Script.

Koordinaten: Platte liegt in XY um den Ursprung, Filz-Oberflaeche nahe Z=0.
1 Einheit = 1 Godot-Einheit (glTF-Export mit +Y up macht aus Blender-Z-hoch
automatisch Godot-Y-hoch).
"""
import math

import bpy

# --- Hauptmasse (alles in Welt-Einheiten) --------------------------------------
TOTAL_LENGTH = 40.0   # Gesamtlaenge (X) inkl. Rail
TOTAL_WIDTH = 30.0    # Gesamttiefe (Y) inkl. Rail
RAIL_RADIUS = 1.7     # Radius der gepolsterten Railwulst (Rundprofil)
RAIL_CENTER_Z = 0.8   # Hoehe der Wulst-Mittellinie ueber Filz-Null

LED_OUTER_INSET = 3.2  # LED-Rinne: aeusserer Rand (unter der Wulst-Innenkante)
LED_INNER_INSET = 4.4  # LED-Rinne: innerer Rand (= Filzkante)
LED_OUTER_Z = 0.85     # aussen hoch, innen tief -> schraege Leuchtrinne
LED_INNER_Z = 0.12

FELT_Z = 0.1            # Oberkante Spielfilz
TRIM_RADIUS = 0.09      # Chrom-Zierring auf der Filzkante (LED_INNER_INSET)

# Goldener Emitter-Ring um die kuenftige Wuerfelgrube: ein FACETTIERTER
# Polygonzug (Kaefig-Optik, jede Kante = ein Feldsegment/Emitter), deutlich
# kleiner als die Filzflaeche. 20 Seiten passen zu dice_tray.gd WALL_SEGMENTS;
# 12 geht genauso - nur diese Zahl aendern.
PIT_RING_SIDES = 20
PIT_RING_SEMI_X = 2.1   # ~1/5 der frueheren Grubenellipse (10.5 x 9.5)
PIT_RING_SEMI_Z = 1.9
PIT_RING_RADIUS = 0.12

UNDERGLOW_TOP_Z = -2.35    # Underglow-Streifen an der Zargen-Unterkante
UNDERGLOW_BOTTOM_Z = -2.7
UNDERGLOW_INSET = 0.28     # leicht VOR der Zarge (Inset 0.35), damit er sichtbar ist

SKIRT_BOTTOM_Z = -3.0  # Unterkante der Zarge (Plattenkorpus unter der Wulst)

ARC_SEGMENTS = 48      # Aufloesung je Halbkreis-Ende
STRAIGHT_SEGMENTS = 24 # Aufloesung je gerader Seite

COLLECTION_NAME = "Fumble_PokerTable"

_HALF_STRAIGHT = (TOTAL_LENGTH - TOTAL_WIDTH) / 2.0  # halbe Laenge der Geraden


# --- Grundgeruest ----------------------------------------------------------------

def _activate_collection() -> None:
    old = bpy.data.collections.get(COLLECTION_NAME)
    if old is not None:
        for obj in list(old.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(old)
    collection = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(collection)

    def find_layer(layer, target):
        if layer.collection is target:
            return layer
        for child in layer.children:
            hit = find_layer(child, target)
            if hit is not None:
                return hit
        return None

    bpy.context.view_layer.active_layer_collection = find_layer(
        bpy.context.view_layer.layer_collection, collection
    )


def _material(name, color, metallic=0.0, rough=0.5, emission=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission is not None:
        for key in ("Emission Color", "Emission"):  # Blender 4.x / 3.x
            if key in bsdf.inputs:
                bsdf.inputs[key].default_value = (*emission, 1.0)
                break
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = strength
    return mat


def _stadium_outline(inset, z):
    """Stadion-Umriss (Rechteck + Halbkreis-Enden), CCW von oben gesehen."""
    r = TOTAL_WIDTH / 2.0 - inset
    l = _HALF_STRAIGHT
    pts = []
    for i in range(ARC_SEGMENTS):  # rechter Bogen -90 -> +90 Grad
        t = -math.pi / 2.0 + math.pi * i / ARC_SEGMENTS
        pts.append((l + r * math.cos(t), r * math.sin(t), z))
    for i in range(STRAIGHT_SEGMENTS):  # obere Gerade +X -> -X
        pts.append((l - 2.0 * l * i / STRAIGHT_SEGMENTS, r, z))
    for i in range(ARC_SEGMENTS):  # linker Bogen +90 -> +270 Grad
        t = math.pi / 2.0 + math.pi * i / ARC_SEGMENTS
        pts.append((-l + r * math.cos(t), r * math.sin(t), z))
    for i in range(STRAIGHT_SEGMENTS):  # untere Gerade -X -> +X
        pts.append((-l + 2.0 * l * i / STRAIGHT_SEGMENTS, -r, z))
    return pts


def _mesh_object(name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def _band(name, outer_pts, inner_pts, mat):
    """Ringband zwischen zwei gleich langen Umriss-Ringen (Normale nach oben)."""
    n = len(outer_pts)
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return _mesh_object(name, list(outer_pts) + list(inner_pts), faces, mat)


def _vertical_band(name, top_pts, bottom_pts, mat):
    """Senkrechtes Ringband (Normale nach aussen), z. B. Zarge und Underglow."""
    n = len(top_pts)
    faces = [(n + i, n + (i + 1) % n, (i + 1) % n, i) for i in range(n)]
    return _mesh_object(name, list(top_pts) + list(bottom_pts), faces, mat)


def _shade_smooth(obj) -> None:
    for poly in obj.data.polygons:
        poly.use_smooth = True


def _tube_from_outline(name, pts, radius, mat):
    """Geschlossene Wulst: Umriss-Kurve mit Rundprofil, zu Mesh konvertiert."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    spline = curve.splines.new("POLY")
    spline.points.add(len(pts) - 1)
    for point, (x, y, z) in zip(spline.points, pts):
        point.co = (x, y, z, 1.0)
    spline.use_cyclic_u = True
    curve.bevel_depth = radius
    curve.bevel_resolution = 8
    curve.materials.append(mat)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    _shade_smooth(obj)
    return obj


# --- Aufbau ------------------------------------------------------------------------

def build() -> None:
    _activate_collection()

    leather = _material("Fumble_Leather", (0.02, 0.02, 0.022), rough=0.55)
    led = _material("Fumble_LED", (0.0, 0.02, 0.05), rough=0.4,
                    emission=(0.05, 0.3, 1.0), strength=10.0)
    gold = _material("Fumble_Gold", (0.8, 0.6, 0.2), metallic=1.0, rough=0.35)
    chrome = _material("Fumble_Chrome", (0.9, 0.9, 0.92), metallic=1.0, rough=0.15)
    underglow = _material("Fumble_Underglow", (0.05, 0.0, 0.03), rough=0.4,
                          emission=(1.0, 0.1, 0.5), strength=6.0)

    # Railwulst: Rundprofil entlang des um RAIL_RADIUS eingerueckten Umrisses,
    # damit die Aussenkante der Wulst genau auf TOTAL_LENGTH/WIDTH endet.
    _tube_from_outline("Rail", _stadium_outline(RAIL_RADIUS, RAIL_CENTER_Z),
                       RAIL_RADIUS, leather)

    # Zarge: senkrechtes Band unter der Wulst plus Bodendeckel.
    _vertical_band("Skirt",
                   _stadium_outline(0.35, RAIL_CENTER_Z),
                   _stadium_outline(0.35, SKIRT_BOTTOM_Z), leather)
    cap_ring = _stadium_outline(0.35, SKIRT_BOTTOM_Z)
    _mesh_object("SkirtBottom", cap_ring, [tuple(reversed(range(len(cap_ring))))], leather)

    # Underglow: schmaler Magenta-Leuchtstreifen knapp vor der Zarge - der
    # Tisch scheint im dunklen Raum ueber seinem eigenen Lichtsaum zu schweben.
    _vertical_band("Underglow",
                   _stadium_outline(UNDERGLOW_INSET, UNDERGLOW_TOP_Z),
                   _stadium_outline(UNDERGLOW_INSET, UNDERGLOW_BOTTOM_Z), underglow)

    # LED-Rinne: schraeges Leuchtband von der Wulst-Innenkante zur Filzkante.
    _band("LEDStrip",
          _stadium_outline(LED_OUTER_INSET, LED_OUTER_Z),
          _stadium_outline(LED_INNER_INSET, LED_INNER_Z), led)

    # Chrom-Zierring genau auf der Kante LED-Rinne/Filz: liest sich wie die
    # Metallfassung einer Glasflaeche und trennt Leuchtband und Filz sauber.
    _tube_from_outline("ChromeTrim",
                       _stadium_outline(LED_INNER_INSET, FELT_Z + 0.05),
                       TRIM_RADIUS, chrome)

    # Bildschirmflaeche: die komplette Ebene innerhalb der LED-Rinne ist ein
    # Display (ehemals "Felt"). Eigener Name + eigenes Material, damit Godot
    # den Slot gezielt findet und mit einer ViewportTexture ueberschreiben
    # kann (siehe Fumble-Repo). Planare UVs ueber die Bounding-Box: u laeuft
    # entlang der langen Achse (lokal X), v entlang der kurzen (lokal Y) -
    # ohne UVs kann keine Textur abgebildet werden.
    screen = _material("Fumble_Screen", (0.005, 0.008, 0.012), rough=0.35)
    screen_ring = _stadium_outline(LED_INNER_INSET, FELT_Z)
    screen_obj = _mesh_object("Screen", screen_ring, [tuple(range(len(screen_ring)))], screen)
    xs = [p[0] for p in screen_ring]
    ys = [p[1] for p in screen_ring]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    uv_layer = screen_obj.data.uv_layers.new(name="UVMap")
    for loop in screen_obj.data.loops:
        co = screen_obj.data.vertices[loop.vertex_index].co
        uv_layer.data[loop.index].uv = (
            (co.x - min_x) / (max_x - min_x),
            (co.y - min_y) / (max_y - min_y),
        )

    # Goldener Emitter-Ring: flacher Polygonzug (PIT_RING_SIDES Ecken, POLY-
    # Spline = harte Kanten statt runder Ellipse), halb in den Filz eingelassen.
    # Die sichtbare "Kaefig"-Hardware, aus deren Kanten spaeter je ein Segment
    # des Energiefelds aufsteigt.
    pit_ring = [
        (PIT_RING_SEMI_X * math.cos(math.tau * i / PIT_RING_SIDES),
         PIT_RING_SEMI_Z * math.sin(math.tau * i / PIT_RING_SIDES),
         FELT_Z + 0.06)
        for i in range(PIT_RING_SIDES)
    ]
    _tube_from_outline("PitEmitterRing", pit_ring, PIT_RING_RADIUS, gold)

    # Skalierungen einbrennen, damit der glTF-Export sauber ist.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.collection.objects:
        obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    print("Fumble-Pokertisch gebaut: Collection '%s'" % COLLECTION_NAME)


build()
