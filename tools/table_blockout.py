"""Fumble: Blender-Blockout der Tisch-Constraints.

Baut alle Masse, die der neue Tisch einhalten muss, als Referenzgeometrie in
eine eigene Collection "Fumble_Blockout": Grubenellipse (Boden/Tischkante/
Wandoberkante), Grubenboden-Flaeche (= Bildschirm-Kandidat), 20 Emitter-Marker
(exakt auf den Wandsegment-Mitten aus dice_tray.gd), 6 Charm-Untersetzer,
Empties fuer Trays/Becher/Heft, die 6 Wurf-Startpositionen und ein 2x2x2-
Referenzwuerfel. Alle Zahlen stammen 1:1 aus dem Repo (Quelle je Konstante im
Kommentar) - Aenderungen dort bitte hier nachziehen.

Nutzung: Blender -> Scripting-Tab -> Datei oeffnen -> Run Script. Laeuft
mehrfach: eine vorhandene Blockout-Collection wird vorher geloescht. Die
Collection ist reine Referenz - vor dem glTF-Export des fertigen Tischs
ausblenden/loeschen. Koordinaten: 1 Blender-Einheit = 1 Godot-Einheit,
Blender-Z-hoch; der glTF-Export (+Y up, Standard) macht daraus Godot-Y-hoch.
"""
import math

import bpy

# --- Godot-Konstanten (Quelle im Kommentar) -----------------------------------
ELLIPSE_SEMI_X = 10.5     # dice_tray.gd ELLIPSE_SEMI_X (Welt-X)
ELLIPSE_SEMI_Z = 9.5      # dice_tray.gd ELLIPSE_SEMI_Z (Welt-Z)
WALL_SEGMENTS = 20        # dice_tray.gd WALL_SEGMENTS
PIT_FLOOR_TOP_Y = -7.23   # dice_tray.gd FLOOR_Y -8.23 + FLOOR_SIZE.y/2
WALL_TOP_Y = 12.77        # dice_tray.gd WALL_CENTER_Y 2.77 + WALL_HEIGHT/2
TABLETOP_Y = -2.675       # charm_row_view.gd SPOT_Y ("Hoehe der Tischoberflaeche")
FIELD_TOP_SUGGESTION_Y = TABLETOP_Y + 7.0  # Vorschlag sichtbare Feldhoehe (Design offen)

CHARM_ANGLES_DEG = [-62.5, -37.5, -12.5, 12.5, 37.5, 62.5]  # charm_row_view.gd SPOT_ANGLES_DEG (um +X, symmetrisch zu Z=0)
CHARM_RADIUS = 26.0       # charm_row_view.gd SPOT_RADIUS
COASTER_RADIUS = 3.6      # charm_row_view.gd COASTER_RADIUS
COASTER_HEIGHT = 0.3      # charm_row_view.gd COASTER_HEIGHT

DIE_SIZE = 2.0            # die_builder.gd HALF_EXTENT * 2 (Kantenbalken ragen +0.16 heraus)

# scene_root.tscn: Parkplaetze der Trays (Godot x, y, z)
TRAY_POSITIONS = [
    ("Tray_A", (-25.1, -3.4, 12.0)),
    ("Tray_B", (-26.0, -3.4, -12.0)),
    ("Tray_C", (-19.3, -3.4, 12.0)),
    ("Tray_D", (-6.0, -3.4, 20.0)),
]
BOOKLET_POSITION = (11.536, -3.783, -26.109)  # scene_root.tscn Shop-Heft
CUP_CANDIDATES = [
    ("CupDock_A", (-22.195, -3.9, -0.811)),   # scene_root.tscn (Becher-Umfeld)
    ("CupDock_B", (-23.325, -3.942, 0.0)),
]
DICE_START_POSITIONS = [  # scene_root.gd DICE_START_POSITIONS (Einflugschneise)
    (6.5458, 13.695267, 7.7658),
    (3.2886, 13.695267, 6.7886),
    (0.0314, 13.695267, 5.8115),
    (-3.2258, 13.695267, 4.8343),
    (-6.4830, 13.695267, 3.8572),
    (-9.7402, 13.695267, 2.8800),
]

COLLECTION_NAME = "Fumble_Blockout"


def g2b(gx: float, gy: float, gz: float) -> tuple:
    """Godot (X, Y hoch, Z) -> Blender (X, Y, Z hoch) passend zum glTF-Export."""
    return (gx, -gz, gy)


def _activate_collection() -> None:
    """Loescht eine alte Blockout-Collection und macht eine frische aktiv."""
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


def _name_last(name: str, wire: bool = False):
    obj = bpy.context.active_object
    obj.name = name
    if wire:
        obj.display_type = "WIRE"
    return obj


def _ellipse_ring(name: str, godot_y: float) -> None:
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=1.0, location=(0, 0, godot_y))
    ring = _name_last(name, wire=True)
    ring.scale = (ELLIPSE_SEMI_X, ELLIPSE_SEMI_Z, 1.0)


def build() -> None:
    _activate_collection()

    # Grubenellipse auf drei Hoehen: Boden, Tischkante, Oberkante der
    # (unsichtbaren) Kollisionswand. Der sichtbare Energiefeld-Rand darf
    # niedriger enden - siehe FieldTop-Ring als Diskussionsvorschlag.
    _ellipse_ring("PitEllipse_Floor", PIT_FLOOR_TOP_Y)
    _ellipse_ring("PitEllipse_Tabletop", TABLETOP_Y)
    _ellipse_ring("PitEllipse_WallTop_Collision", WALL_TOP_Y)
    _ellipse_ring("PitEllipse_FieldTop_Suggestion", FIELD_TOP_SUGGESTION_Y)

    # Grubenboden als gefuellte Flaeche - der Bildschirm-Kandidat. Muss als
    # eigenes, perfekt planes Mesh mit sauberem 0-1-UV in den finalen Tisch.
    bpy.ops.mesh.primitive_circle_add(
        vertices=64, radius=1.0, fill_type="NGON", location=(0, 0, PIT_FLOOR_TOP_Y)
    )
    floor = _name_last("ScreenPit_Guide")
    floor.scale = (ELLIPSE_SEMI_X, ELLIPSE_SEMI_Z, 1.0)

    # Tischplatten-Referenz: ~56x56 noetig, damit Trays/Charms/Heft Platz haben.
    bpy.ops.mesh.primitive_plane_add(size=60.0, location=(0, 0, TABLETOP_Y))
    _name_last("Tabletop_Guide", wire=True)

    # 20 Emitter-Marker exakt auf den Sehnen-Mitten der Wandsegmente
    # (gleiche Formel wie dice_tray.gd _ready) - Boss-Effekte je Segment
    # sollen spaeter auf sichtbare Hardware zeigen koennen.
    for i in range(WALL_SEGMENTS):
        theta = math.tau * i / WALL_SEGMENTS
        theta_next = math.tau * (i + 1) / WALL_SEGMENTS
        gx = (ELLIPSE_SEMI_X * math.cos(theta) + ELLIPSE_SEMI_X * math.cos(theta_next)) / 2.0
        gz = (ELLIPSE_SEMI_Z * math.sin(theta) + ELLIPSE_SEMI_Z * math.sin(theta_next)) / 2.0
        bpy.ops.mesh.primitive_cube_add(size=0.8, location=g2b(gx, TABLETOP_Y, gz))
        _name_last("Emitter_%02d" % i)

    # 6 Charm-Untersetzer auf dem Bogen am hinteren Tischrand (+X).
    for index, angle_deg in enumerate(CHARM_ANGLES_DEG):
        angle = math.radians(angle_deg)
        gx = math.cos(angle) * CHARM_RADIUS
        gz = math.sin(angle) * CHARM_RADIUS
        bx, by, bz = g2b(gx, TABLETOP_Y, gz)
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=32,
            radius=COASTER_RADIUS,
            depth=COASTER_HEIGHT,
            location=(bx, by, bz + COASTER_HEIGHT / 2.0),
        )
        _name_last("CharmCoaster_%d" % index)

    # Funktionszonen als Empties: Trays, Shop-Heft, Becher-Kandidaten.
    zones = TRAY_POSITIONS + [("ShopBooklet", BOOKLET_POSITION)] + CUP_CANDIDATES
    for zone_name, godot_pos in zones:
        bpy.ops.object.empty_add(type="PLAIN_AXES", radius=2.0, location=g2b(*godot_pos))
        _name_last(zone_name)

    # Einflugschneise der Wuerfel (Startpositionen hoch ueber dem Tisch, Wurf
    # Richtung Grubenzentrum) - kein Tischteil darf in dieser Bahn haengen.
    for index, godot_pos in enumerate(DICE_START_POSITIONS):
        bpy.ops.object.empty_add(type="SPHERE", radius=1.0, location=g2b(*godot_pos))
        _name_last("DiceStart_%d" % index)

    # Referenzwuerfel (2x2x2, Kantenbalken ragen real +0.16 heraus): steht im
    # Grubenboden - jede Rille/Kante des Tischs an dieser Groesse messen.
    bpy.ops.mesh.primitive_cube_add(
        size=DIE_SIZE, location=g2b(4.0, PIT_FLOOR_TOP_Y + DIE_SIZE / 2.0, 0.0)
    )
    _name_last("ReferenceDie")

    print("Fumble-Blockout gebaut: Collection '%s'" % COLLECTION_NAME)


build()
