"""Fumble: drei Fassungen des Projektors „Halo“ mit EINGEMALTEM Licht (Spieler-Wunsch 2026-11-22:
im Spiel las er als grauer Klecks - am Tisch beleuchtet ihn nichts).

Jede Fassung: scharfe Fasen statt Rundungen, zwei Materialien mit echtem Kontrast, ein Sockel-
Absatz, eine gestufte Schale und der UMRISS - ein Lichtband, das auch leer glimmt. Das Licht der
Hülle steckt als Vertexfarbe im Netz `Korpus` (wie bei den Modul-Pins), Godot zeigt es unbeleuchtet.
  stahldeck - schwarzer Lack, helle Stahlplatte, breiter Chromring
  messing   - Graphit und Schwarzglas, Messing-Saum und Messingring
  achteck   - flacher Lackkörper, achteckiger Stahl-Turm

Aufruf (kopflos):
  blender -b -P tools/blender_projector_baked.py -- <ausgabe-ordner>
Schreibt projektor_<fassung>.glb. Schnittstelle wie charm_reader.glb (Lippe, Bodensaum, Ring,
Linse, Kabellicht, Steckerlicht, Display, Auswurf, LinseMitte), neu Korpus und Umriss.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_floppy_charm as fc
import blender_projector_variants as pv

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
RW, RL, RH = pv.RW, pv.RL, pv.RH
FY = pv.FY

LIGHT = Vector((-0.35, 0.45, 0.82)).normalized()
VIEW = Vector((-0.1, -0.25, 0.96)).normalized()
HALF = (LIGHT + VIEW).normalized()
## Blender-Material -> (Art, Grundfarbe) des eingemalten Lichts.
BAKED = {
    "Gussgrau": ("matt", (0.2, 0.2, 0.24)),
    "Graphit": ("matt", (0.1, 0.1, 0.125)),
    "Schwarzlack": ("gloss", (0.03, 0.03, 0.04)),
    "Chrom": ("metal", (0.82, 0.84, 0.88)),
    "Stahl": ("metal", (0.56, 0.58, 0.63)),
    "Messing": ("metal", (0.92, 0.68, 0.3)),
    "Kabelmantel": ("matt", (0.07, 0.07, 0.085)),
}
## So tief steckt die Diskette (CharmDiskView.INSERT): Schieber UND die frühere Namenszeile.
INSERT = 0.43
## Das Namens-Display vorn auf dem Deck: Mitte x, Abstand zur Vorderkante, Breite, Tiefe
## (CharmReaderView.DISPLAY_CENTER/DISPLAY_SIZE), rechts daneben die Auswurf-Taste.
DISPLAY = (-0.085, 0.105, 0.8, 0.115)
EJECT_X = 0.41
## Mitte x, Mitte y, Oberkante, Radius der Schale - darin wird es dunkler.
DISH = [0.0, 0.1, RH, 0.25]
## Kontaktschatten am Tisch; flache Dinge (Disketten) schalten ihn ab.
CONTACT_SHADOW = True


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def shade(kind, base, n):
    n = n.normalized()
    ndl = max(0.0, n.dot(LIGHT))
    spec = max(0.0, n.dot(HALF))
    fres = 1.0 - abs(n.dot(VIEW))
    r = 2.0 * n.dot(VIEW) * n - VIEW
    if kind == "metal":
        env = 0.28 + 0.74 * smooth(0.05, 0.8, r.z) + 0.5 * smooth(0.96, 0.995, r.dot(LIGHT))
        col = [c * env for c in base]
        add = spec ** 60 * 0.7
    elif kind == "gloss":
        col = [c * (0.7 + 0.9 * ndl) for c in base]
        add = spec ** 40 * 0.5 + fres ** 3 * 0.12
    else:
        col = [c * (0.55 + 0.75 * ndl) for c in base]
        add = spec ** 12 * 0.1
    return [min(1.5, c + add) for c in col]


def paint(obj, kind, base):
    mesh = obj.data
    mesh.calc_normals_split()
    attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    world = obj.matrix_world
    rot = world.to_3x3()
    cx, cy, top, radius = DISH
    for loop in mesh.loops:
        co = world @ mesh.vertices[loop.vertex_index].co
        c = shade(kind, base, rot @ Vector(loop.normal))
        ao = 0.55 + 0.45 * smooth(-0.005, 0.07, co.z) if CONTACT_SHADOW else 1.0
        if (co.x - cx) ** 2 + (co.y - cy) ** 2 < (radius * 1.02) ** 2 and co.z < top - 0.004:
            ao *= 0.42 + 0.58 * smooth(top - 0.07, top, co.z)
        attr.data[loop.index].color = (c[0] * ao, c[1] * ao, c[2] * ao, 1.0)
    mesh.color_attributes.active_color = attr


def mat(name):
    """Platzhalter-Material; die Farbe kommt aus BAKED."""
    return led.mat(name, BAKED[name][1], 0.0, 0.5)


def glow(name="Saum_aus"):
    return led.mat(name, pv.OFF, 0.0, 0.3)


def front(parent, look, body):
    """Schlitz, Lippe, Namens-Display und Auswurf-Taste."""
    deep = INSERT + 0.06
    slot = fc.box(parent, "SchnittSchlitz", (pv.DW + 0.06, deep, 0.05),
                  (0, FY + deep * 0.5 - 0.04, pv.SLOT_Z), look.black)
    led.cut(body, slot)
    fc.box(parent, "Schlitzgrund", (pv.DW + 0.06, 0.01, 0.05), (0, FY + deep - 0.045, pv.SLOT_Z),
           look.black)
    fc.box(parent, "Lippe", (pv.DW + 0.06, 0.008, 0.008), (0, FY - 0.004, pv.SLOT_Z - 0.036),
           look.glow)
    cx, off, wide, deep_d = DISPLAY
    fc.box(parent, "Display", (wide, deep_d, 0.004), (cx, FY + off, RH + 0.002),
           led.mat("Displayglas", (0.004, 0.009, 0.012), 0.0, 0.3, clearcoat=0.5))
    led.rounded_box(parent, "Auswurf", (0.13, 0.085, 0.024), (EJECT_X, FY + off, RH + 0.012),
                    look.gun, 0.012, 0.004, 4)


def ring_frame(parent, name, outer, inner, z, height, material, corner):
    """Flacher Rahmen: Außenmaß minus Innenmaß."""
    o = led.rounded_box(parent, name, (outer[0], outer[1], height), (outer[2], outer[3], z),
                        material, corner, 0.0, 4)
    cutter = fc.box(parent, "Schnitt" + name, (inner[0], inner[1], height * 3.0),
                    (outer[2], outer[3], z), material)
    led.cut(o, cutter)
    return o


def dish(parent, body_parts, center, radius, look, ring_mat, floor_mat, rim_minor=0.024):
    """Gestufte Schale: Schnitt durch die Deckteile, dunkler Grund, Stufe, zwei Lichtringe, Linse."""
    DISH[0], DISH[1], DISH[2], DISH[3] = center.x, center.y, center.z, radius
    cutter = fc.cyl(parent, "SchnittSchale", radius, 0.1, center, floor_mat)
    for part in body_parts:
        led.cut(part, cutter)
    floor = center.z - 0.05
    fc.cyl(parent, "Schalengrund", radius, 0.006, Vector((center.x, center.y, floor + 0.003)),
           floor_mat)
    fc.cyl(parent, "Schalenstufe", radius * 0.72, 0.016, Vector((center.x, center.y, floor + 0.012)),
           floor_mat)
    pv.torus(parent, "Ring0", radius * 0.86, 0.009, Vector((center.x, center.y, floor + 0.01)),
             look.glow)
    pv.torus(parent, "Ring1", radius * 0.6, 0.008, Vector((center.x, center.y, floor + 0.024)),
             look.glow)
    rim = pv.torus(parent, "Schalenrand", radius + rim_minor * 0.5, rim_minor,
                   Vector((center.x, center.y, center.z + 0.002)), ring_mat)
    rim.scale = (1, 1, 0.55)
    pv.dome(parent, "Linse", radius * 0.42, 0.42, Vector((center.x, center.y, floor + 0.02)),
            look.lens)
    fc.empty("LinseMitte", Vector((center.x, center.y, floor + 0.02 + radius * 0.42 * 0.42)))


def base_step(parent, look, material, corner):
    """Sockel-Absatz mit dem Lichtband darunter."""
    led.chamfer_box(parent, "Sockel", (RW + 0.045, RL + 0.045, 0.05), (0, 0, 0.027), material,
                    corner + 0.02, 0.012)
    led.rounded_box(parent, "Bodensaum", (RW + 0.085, RL + 0.085, 0.012), (0, 0, 0.006), look.glow,
                    corner + 0.04, 0.0, 6)


def screws(parent, material, xs, ys, z):
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            fc.cyl(parent, "Schraube%d%d" % (i, j), 0.016, 0.008, (x, y, z), material, verts=12)


# --- 1: STAHLDECK ---------------------------------------------------------------------------

def stahldeck(root, look):
    lack, stahl, chrom, graphit = mat("Schwarzlack"), mat("Stahl"), mat("Chrom"), mat("Graphit")
    body = led.chamfer_box(root, "Gehaeuse", (RW, RL, RH), (0, 0, RH * 0.5), lack, 0.03, 0.014)
    front(root, look, body)
    base_step(root, look, graphit, 0.03)
    top = RH + 0.016
    plate = led.chamfer_box(root, "Deckplatte", (RW - 0.12, 0.56, 0.016), (0, 0.1, RH + 0.008),
                            stahl, 0.03, 0.005)
    # Der Umriss: ein Lichtband, das unter der Platte hervorschaut.
    rim = led.rounded_box(root, "Umriss", (RW - 0.085, 0.595, 0.006), (0, 0.1, RH + 0.003),
                          glow(), 0.045, 0.0, 4)
    dish(root, [body, plate, rim], Vector((0, 0.1, top)), 0.25, look, chrom, graphit)
    screws(root, chrom, (-0.45, 0.45), (-0.14, 0.34), top + 0.003)
    return (0.3, RL * 0.5, 0.1)


# --- 2: MESSING -----------------------------------------------------------------------------

def messing(root, look):
    lack, brass, graphit = mat("Schwarzlack"), mat("Messing"), mat("Graphit")
    body = led.chamfer_box(root, "Gehaeuse", (RW, RL, RH), (0, 0, RH * 0.5), mat("Gussgrau"),
                           0.03, 0.014)
    pv.front(root, look, body, RH + 0.014)
    base_step(root, look, graphit, 0.03)
    # Messing-Saum rundum: eine Messingplatte schaut unter dem Schwarzglas hervor.
    trim = led.rounded_box(root, "Messingsaum", (RW - 0.03, RL - 0.03, 0.006), (0, 0, RH + 0.003),
                           brass, 0.03, 0.0, 4)
    plate = led.chamfer_box(root, "Deckglas", (RW - 0.085, RL - 0.085, 0.01), (0, 0, RH + 0.011),
                            lack, 0.02, 0.003)
    top = RH + 0.016
    dish(root, [body, trim, plate], Vector((0, 0.1, top)), 0.25, look, brass, graphit)
    pv.torus(root, "Umriss", 0.305, 0.008, Vector((0, 0.1, top + 0.002)), glow())
    screws(root, brass, (-0.46, 0.46), (-0.16, 0.31), top + 0.003)
    for i in range(4):
        for sx in (-1, 1):
            fc.box(root, "Rippe%d_%d" % (i, sx), (0.012, 0.3, 0.008),
                   (sx * (0.36 + i * 0.03), 0.1, top + 0.003), graphit)
    return (0.3, RL * 0.5, 0.1)


# --- 3: ACHTECK -----------------------------------------------------------------------------

def achteck(root, look):
    lack, stahl, chrom, graphit = mat("Schwarzlack"), mat("Stahl"), mat("Chrom"), mat("Graphit")
    body = led.chamfer_box(root, "Gehaeuse", (RW, RL, RH), (0, 0, RH * 0.5), lack, 0.03, 0.014)
    pv.front(root, look, body)
    base_step(root, look, graphit, 0.03)
    cy, r, rise = 0.075, 0.33, 0.09
    turn = (0, 0, math.radians(22.5))
    fc.cyl(root, "Umriss", r + 0.03, 0.012, (0, cy, RH + 0.006), glow(), rot=turn, verts=8)
    tower = fc.cyl(root, "Turm", r, rise, (0, cy, RH + rise * 0.5), stahl, rot=turn, verts=8)
    bpy.ops.object.shade_flat()
    bevel = tower.modifiers.new("Fase", "BEVEL")
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(60)
    bevel.width = 0.018
    bevel.segments = 1
    top = RH + rise
    dish(root, [body, tower], Vector((0, cy, top)), 0.22, look, chrom, graphit)
    for k in range(8):
        a = math.radians(22.5 + k * 45)
        fc.cyl(root, "Niete%d" % k, 0.012, 0.006,
               (math.cos(a) * (r - 0.045), cy + math.sin(a) * (r - 0.045), top + 0.002), chrom,
               verts=10)
    for sx in (-1, 1):
        fc.box(root, "Flanke%d" % sx, (0.03, 0.42, 0.012), (sx * 0.5, 0.08, RH + 0.006), stahl)
    return (0.3, RL * 0.5, 0.1)


# --- Die BRÜCKE des Ladens: derselbe Stil über dem Schieber der Laden-Diskette ---------------

def bruecke(root, look):
    """Maße wie CharmProjectorView (Welt / 7,1): Wangen, Rückwand, Deck; darauf Stahlplatte mit
    Schale, vorn das Namens-Display, rechts das Preisfeld."""
    lack, stahl, chrom, graphit = mat("Schwarzlack"), mat("Stahl"), mat("Chrom"), mat("Graphit")
    s = 7.1
    depth = INSERT + 0.12 / s
    wide = pv.DW + 0.48 / s
    under, deck, cheek, back, plate = 0.4 / s, 0.38 / s, 0.2 / s, 0.12 / s, 0.012
    for sx in (-1, 1):
        fc.box(root, "Wange%d" % sx, (cheek, depth, under), (sx * (wide - cheek) * 0.5, 0, under * 0.5),
               lack)
    fc.box(root, "Rueckwand", (wide - cheek * 2, back, under), (0, (depth - back) * 0.5, under * 0.5),
           lack)
    deck_o = led.chamfer_box(root, "Deck", (wide, depth, deck), (0, 0, under + deck * 0.5), lack,
                             0.0, 0.008)
    top = under + deck + plate
    plate_d = depth - 0.125
    cy = depth * 0.5 - 0.012 - plate_d * 0.5
    plate_o = led.chamfer_box(root, "Deckplatte", (wide - 0.07, plate_d, plate),
                              (0, cy, under + deck + plate * 0.5), stahl, 0.02, 0.004)
    rim = led.rounded_box(root, "Umriss", (wide - 0.04, plate_d + 0.03, 0.005),
                          (0, cy, under + deck + 0.0025), glow(), 0.03, 0.0, 4)
    glass = led.mat("Displayglas", (0.004, 0.009, 0.012), 0.0, 0.3, clearcoat=0.5)
    fc.box(root, "Display", (wide - 0.08, 0.088, 0.004),
           (0, -depth * 0.5 + 0.056, under + deck + 0.002), glass)
    fc.box(root, "Preisfeld", (0.22, 0.13, 0.004), (0.317, cy, top + 0.002), glass)
    dish(root, [deck_o, plate_o, rim], Vector((0, cy, top)), 0.12, look, chrom, graphit, 0.014)
    fc.box(root, "Lippe", (wide - 0.1, 0.007, 0.01), (0, -depth * 0.5 - 0.002, under + 0.012),
           look.glow)
    screws(root, chrom, (-(wide * 0.5 - 0.065), wide * 0.5 - 0.065),
           (cy - plate_d * 0.5 + 0.03, cy + plate_d * 0.5 - 0.03), top + 0.003)
    for i in range(4):
        fc.box(root, "Rippe%d" % i, (0.012, 0.16, 0.006), (-0.25 - i * 0.03, cy, top + 0.002),
               graphit)
    return None


VARIANTS = [("stahldeck", stahldeck), ("messing", messing), ("achteck", achteck)]


def bake_and_join():
    """Schnitte anwenden, Hülle einmalen und zu EINEM Netz `Korpus` verbinden."""
    for o in list(bpy.data.objects):
        if o.type != "MESH" or o.display_type == "WIRE":
            continue
        bpy.context.view_layer.objects.active = o
        for mod in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    for o in list(bpy.data.objects):
        if o.display_type == "WIRE":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.view_layer.update()
    baked = bpy.data.materials.new("Gebacken")
    parts = []
    for o in bpy.data.objects:
        if o.type != "MESH" or not o.data.materials or o.name == "Auswurf":
            continue
        look = BAKED.get(o.data.materials[0].name)
        if look is None:
            continue
        paint(o, look[0], look[1])
        o.data.materials.clear()
        o.data.materials.append(baked)
        parts.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    parts[0].name = "Korpus"
    for name in ("Ring",):
        group = [o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(name)]
        if len(group) < 2:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in group:
            o.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
        group[0].name = name


def meshify():
    for o in list(bpy.data.objects):
        if o.type == "FONT":
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.type == "CURVE":
            bpy.ops.object.select_all(action="DESELECT")
            o.select_set(True)
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.convert(target="MESH")
            bpy.ops.object.shade_smooth()


def export(tag, build, path=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    led._mats.clear()
    root = fc.empty("Projektor")
    look = pv.Look(None)
    plug = build(root, look)
    if plug is not None:
        pv.cable(root, look, plug, Vector((0, pv.PORT_Y, 0)))
    meshify()
    bake_and_join()
    bpy.ops.export_scene.gltf(filepath=path or os.path.join(OUT, "projektor_%s.glb" % tag),
                              export_format="GLB", export_apply=True, export_colors=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for tag, build in VARIANTS:
        export(tag, build)
    print("ok")


if __name__ == "__main__":
    main()
