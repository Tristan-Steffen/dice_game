"""Fumble: fünf Entwürfe für den Charm-PROJEKTOR mit USB-Kabel und die USB-LEISTE im Tisch
(Spieler-Wunsch 2026-11-21).

Jeder Entwurf behält die Schnittstelle des Laufwerks (Grundriß, Schlitz, Display, Auswurf) und
bekommt hinten ein USB-Kabel in einen der zehn Ports der Leiste. Jeder zeigt anders, daß er
läuft: halo = Bodensaum, saeule = Plasmaröhre, bogen = Lichtarme, lotus = offene Blätter,
konsole = Pegelbalken.

Aufruf (kopflos):
  blender -b -P tools/blender_projector_variants.py -- <ausgabe-ordner> [bilder-ordner]
Achsen: X = Breite, Y = Länge (Schlitz -Y, Kabel +Y), Z = Höhe.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_floppy_charm as fc
import blender_floppy_layouts as fl

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
OUT = ARGS[0]
ART = ARGS[1] if len(ARGS) > 1 else "E:/Generated Images/Fumble/floppy_terminal"

DW, DL, DT = fc.DW, fc.DL, fc.DT
RW, RL, RH = fc.RW, fc.RL, fc.RH
INSERT = 0.34                       # nur der Schieber steckt (CharmDiskView.INSERT)
LOADED_Y = -RL * 0.5 + INSERT - DL * 0.5
SLOT_Z = fc.SLOT_Z
FY = -RL * 0.5
PITCH = 9.0 / 7.1                   # CharmRowView.LINE_SPACING in Blender-Einheiten
PORT_Y = RL * 0.5 + 0.36
PLUG_Z = 0.14                       # Höhe des Wand-Ports (CharmReaderView.PORT.y)
PORTS = 10
HOLO = fc.HOLO
OFF = (0.03, 0.04, 0.05)


class Look:
    """Materialien eines Projektors: aus = dunkel, an = Rarität und Holo-Cyan."""

    def __init__(self, rarity):
        self.on = rarity is not None
        col = fc.srgb(fc.RARITY[rarity][1]) if self.on else OFF
        tag = rarity if self.on else "aus"
        self.gun = led.mat("Gussgrau", (0.05, 0.05, 0.06), 0.9, 0.32, clearcoat=0.4)
        self.black = led.mat("Schwarzlack", (0.006, 0.006, 0.008), 0.0, 0.08, clearcoat=1.0)
        self.chrome = led.mat("Chrom", (0.85, 0.86, 0.88), 1.0, 0.08)
        self.steel = led.mat("Stahl", (0.32, 0.33, 0.36), 1.0, 0.3)
        self.glass = led.mat("Klarglas", (0.8, 0.9, 1.0), 0.0, 0.03, 0.0, 0.16)
        self.glow = led.mat("Saum_" + tag, col, 0.0, 0.3, 5.0 if self.on else 0.0)
        self.soft = led.mat("Schein_" + tag, col, 0.0, 0.3, 2.0 if self.on else 0.0)
        self.lens = (led.mat("LinseAn", HOLO, 0.0, 0.05, 8.0) if self.on
                     else led.mat("LinseAus", (0.02, 0.04, 0.05), 0.0, 0.03, clearcoat=1.0))
        self.holo = (led.mat("HoloAn", HOLO, 0.0, 0.2, 5.0) if self.on
                     else led.mat("HoloAus", OFF, 0.0, 0.3))
        self.standby = led.mat("Bereit", (1.0, 0.45, 0.08), 0.0, 0.3, 2.5)


# --- Werkzeuge ----------------------------------------------------------------------------

def torus(parent, name, major, minor, loc, material):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc,
                                     major_segments=64, minor_segments=12)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    o.parent = parent
    return o


def dome(parent, name, radius, flat, loc, material):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc, segments=48, ring_count=24)
    o = bpy.context.active_object
    o.name = name
    o.scale = (1, 1, flat)
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    o.parent = parent
    return o


def bezier(p0, p1, p2, p3, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(p0 * (1 - t) ** 3 + p1 * 3 * t * (1 - t) ** 2 + p2 * 3 * t * t * (1 - t)
                   + p3 * t ** 3)
    return out


def tube(parent, name, points, radius, material):
    data = bpy.data.curves.new(name, "CURVE")
    data.dimensions = "3D"
    data.bevel_depth = radius
    data.bevel_resolution = 4
    data.use_fill_caps = True
    spline = data.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for sp, p in zip(spline.points, points):
        sp.co = (p.x, p.y, p.z, 1)
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    o.data.materials.append(material)
    o.parent = parent
    return o


def front(parent, look, body, top=RH):
    """Was jeder Entwurf vorn trägt: Schlitz, Lippe, Display, Auswurf-Taste."""
    deep = INSERT + 0.06
    slot = fc.box(parent, "SchnittSchlitz", (DW + 0.06, deep, 0.05),
                  (0, FY + deep * 0.5 - 0.04, SLOT_Z), look.black)
    led.cut(body, slot)
    fc.box(parent, "Schlitzgrund", (DW + 0.06, 0.01, 0.05), (0, FY + deep - 0.045, SLOT_Z),
           look.black)
    fc.box(parent, "Lippe", (DW + 0.06, 0.008, 0.008), (0, FY - 0.004, SLOT_Z - 0.036), look.glow)
    fc.box(parent, "Display", (0.64, 0.07, 0.004), (-0.12, FY + 0.09, top + 0.002),
           led.mat("Displayglas", (0.004, 0.009, 0.012), 0.0, 0.3, clearcoat=0.5))
    if look.on:
        fl_txt = fc.text(parent, "x3", (-0.12, FY + 0.09, top + 0.0045), 0.05,
                         led.mat("Displayschrift", (1.0, 0.8, 0.1), 0.0, 0.4, 3.0), name="Zaehler",
                         bold=True)
        fl_txt.data.extrude = 0.0
    led.rounded_box(parent, "Auswurf", (0.15, 0.075, 0.024), (0.38, FY + 0.09, top + 0.012),
                    look.gun, 0.012, 0.004, 4)
    return slot


def cable(parent, look, start, port):
    """USB-Kabel von der Rückwand zum geraden Stecker im WAND-Port (port.y = Wandebene, PLUG_Z hoch)."""
    wall = port.y
    led.rounded_box(parent, "Stecker", (0.12, 0.16, 0.05), (port.x, wall - 0.09, PLUG_Z), look.black,
                    0.02, 0.008, 4)
    fc.box(parent, "Steckerzunge", (0.1, 0.03, 0.02), (port.x, wall - 0.012, PLUG_Z), look.chrome)
    fc.box(parent, "Steckerlicht", (0.012, 0.09, 0.004), (port.x, wall - 0.09, PLUG_Z + 0.027),
           look.glow)
    fc.cyl(parent, "Knickschutz", 0.022, 0.06, (port.x, wall - 0.195, PLUG_Z), look.black,
           rot=(math.radians(90), 0, 0), verts=16)
    end = Vector((port.x, wall - 0.22, PLUG_Z))
    s = Vector(start)
    fc.cyl(parent, "Buchse", 0.03, 0.03, (s.x, s.y + 0.01, s.z), look.black,
           rot=(math.radians(90), 0, 0), verts=16)
    pts = bezier(s, s + Vector((0, 0.13, -0.07)), end + Vector((0, -0.13, -0.07)), end)
    for p in pts:
        p.z = max(p.z, 0.016)
    tube(parent, "Kabel", pts, 0.016, led.mat("Kabelmantel", (0.012, 0.012, 0.016), 0.0, 0.55))
    # Die Datenader: ein dünner Lichtfaden obenauf - er läuft, solange projiziert wird.
    tube(parent, "Kabellicht", [p + Vector((0, 0, 0.013)) for p in pts], 0.005, look.soft)


def port(parent, index, x, y, lit_col=None):
    """Ein USB-Port der Leiste; Godot stellt ihn senkrecht an die Wand."""
    steel = led.mat("Portstahl", (0.2, 0.21, 0.24), 1.0, 0.28)
    dark = led.mat("Portgrund", (0.004, 0.004, 0.006), 0.0, 0.4)
    led.rounded_box(parent, "Port%02d" % index, (0.36, 0.24, 0.012), (x, y, 0.004), steel,
                    0.03, 0.003, 4)
    fc.box(parent, "Portloch%02d" % index, (0.15, 0.062, 0.004), (x, y, 0.0095), dark)
    fc.box(parent, "Portzunge%02d" % index, (0.12, 0.022, 0.003), (x, y + 0.012, 0.0105),
           led.mat("Zungenblau", (0.05, 0.25, 0.9), 0.0, 0.4, 0.6))
    mat = (led.mat("PortAn_%d" % index, lit_col, 0.0, 0.3, 5.0) if lit_col
           else led.mat("PortAus", OFF, 0.0, 0.3))
    fc.box(parent, "Portlicht%02d" % index, (0.3, 0.012, 0.003), (x, y - 0.1, 0.0105), mat)
    n = fc.text(parent, "%02d" % index, (x, y + 0.085, 0.0105), 0.045,
                led.mat("Portziffer", (0.55, 0.58, 0.64), 0.0, 0.5, 0.3), name="Ziffer", bold=True)
    n.data.extrude = 0.0


def rail(parent, count, first_x, lit):
    """Die USB-LEISTE: eine schmale Schiene im Tisch mit `count` Ports; lit = {Index: Farbe}."""
    width = PITCH * (count - 1) + 0.6
    cx = first_x + PITCH * (count - 1) * 0.5
    led.rounded_box(parent, "Leiste", (width, 0.34, 0.006), (cx, PORT_Y, 0.001),
                    led.mat("Leistengrund", (0.015, 0.015, 0.02), 0.6, 0.35, clearcoat=0.6),
                    0.05, 0.002, 4)
    fc.box(parent, "Leistenlinie", (width - 0.2, 0.006, 0.002), (cx, PORT_Y + 0.15, 0.0045),
           led.mat("Leistenlicht", (0.2, 0.75, 0.9), 0.0, 0.3, 1.2))
    for i in range(count):
        port(parent, i + 1, first_x + i * PITCH, PORT_Y, lit.get(i))


def hologram(parent, look, charm, lens, height=0.72):
    if not look.on:
        return
    h = 0.9
    bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=0.12, radius2=0.4, depth=h,
                                    end_fill_type="NOTHING", location=lens + Vector((0, 0, h * 0.5)))
    cone = bpy.context.active_object
    cone.name = "Lichtkegel"
    cone.data.materials.append(fc.beam_material())
    bpy.ops.object.shade_smooth()
    cone.parent = parent
    holder, meshes = fc.import_charm(charm[0], 0.56)
    holder.location = lens + Vector((0, 0, height - 0.3))
    holder.rotation_euler = (0, 0, math.radians(-25))
    holder.parent = parent
    for o in meshes:
        for slot in o.material_slots:
            if slot.material and slot.material.use_nodes:
                p = slot.material.node_tree.nodes.get("Principled BSDF")
                if p:
                    p.inputs["Emission Strength"].default_value = 0.0
    bpy.ops.object.light_add(type="POINT", location=lens + Vector((0, -0.5, 1.2)))
    lt = bpy.context.active_object
    lt.data.energy = 60
    lt.data.shadow_soft_size = 0.4
    lt.parent = parent
    bpy.ops.object.light_add(type="POINT", location=lens + Vector((0, 0, 0.12)))
    lt = bpy.context.active_object
    lt.data.energy = 12
    lt.data.color = HOLO
    lt.parent = parent


# --- A: HALO - flacher Block, versenkte Schale, Lichtsaum rund um den Fuß -----------------

def halo(parent, look):
    body = led.rounded_box(parent, "Gehaeuse", (RW, RL, RH), (0, 0, RH * 0.5), look.gun,
                           0.09, 0.03, 8)
    front(parent, look, body)
    # Bodensaum: ein Lichtband unter dem Gehäuse, das auf den Filz fällt.
    led.rounded_box(parent, "Bodensaum", (RW + 0.05, RL + 0.05, 0.014), (0, 0, 0.007), look.glow,
                    0.11, 0.0, 8)
    led.rounded_box(parent, "Sockelblende", (RW + 0.012, RL + 0.012, 0.03), (0, 0, 0.03),
                    look.black, 0.095, 0.004, 8)
    pc = Vector((0, 0.08, RH))
    dish = fc.cyl(parent, "SchnittSchale", 0.3, 0.09, pc, look.black)
    led.cut(body, dish)
    fc.cyl(parent, "Schalengrund", 0.3, 0.004, pc + Vector((0, 0, -0.043)), look.black)
    torus(parent, "Schalenrand", 0.305, 0.012, pc + Vector((0, 0, 0.002)), look.chrome)
    for k, r in enumerate((0.25, 0.185)):
        torus(parent, "Ring%d" % k, r, 0.008, pc + Vector((0, 0, -0.036)), look.glow)
    dome(parent, "Linse", 0.11, 0.42, pc + Vector((0, 0, -0.04)), look.lens)
    for sx in (-1, 1):
        fc.box(parent, "Kante%d" % sx, (0.008, 0.46, 0.004), (sx * 0.5, 0.08, RH + 0.001),
               look.soft)
    return pc + Vector((0, 0, 0.01)), (0.3, RL * 0.5, 0.09)


# --- B: SÄULE - Plasmaröhre unter dem Emitterkopf ----------------------------------------

def saeule(parent, look):
    body = led.rounded_box(parent, "Gehaeuse", (RW, RL, RH), (0, 0, RH * 0.5), look.black,
                           0.04, 0.012, 6)
    front(parent, look, body)
    led.rounded_box(parent, "Deckplatte", (RW - 0.1, 0.5, 0.012), (0, 0.11, RH + 0.006),
                    look.steel, 0.03, 0.004, 4)
    pc = Vector((0, 0.1, RH))
    fc.cyl(parent, "Fuss", 0.26, 0.04, pc + Vector((0, 0, 0.03)), look.gun)
    torus(parent, "Fussring", 0.265, 0.01, pc + Vector((0, 0, 0.052)), look.glow)
    tube_h = 0.24
    fc.cyl(parent, "Glasrohr", 0.17, tube_h, pc + Vector((0, 0, 0.05 + tube_h * 0.5)), look.glass)
    fc.cyl(parent, "Plasma", 0.055, tube_h, pc + Vector((0, 0, 0.05 + tube_h * 0.5)), look.glow)
    for k in range(4):
        a = math.radians(45 + k * 90)
        fc.cyl(parent, "Strebe%d" % k, 0.012, tube_h,
               pc + Vector((math.cos(a) * 0.185, math.sin(a) * 0.185, 0.05 + tube_h * 0.5)),
               look.chrome, verts=12)
    top = pc + Vector((0, 0, 0.05 + tube_h))
    fc.cyl(parent, "Kopf", 0.23, 0.05, top + Vector((0, 0, 0.025)), look.gun)
    torus(parent, "Kopfring", 0.19, 0.009, top + Vector((0, 0, 0.052)), look.holo)
    dome(parent, "Linse", 0.13, 0.4, top + Vector((0, 0, 0.05)), look.lens)
    return top + Vector((0, 0, 0.1)), (0.35, RL * 0.5, 0.1)


# --- C: BOGEN - zwei Lichtarme greifen um das Hologramm -----------------------------------

def bogen(parent, look):
    body = led.rounded_box(parent, "Gehaeuse", (RW, RL, RH), (0, 0, RH * 0.5), look.gun,
                           0.05, 0.02, 8)
    front(parent, look, body)
    led.rounded_box(parent, "Glasdeck", (0.78, 0.52, 0.008), (0, 0.11, RH + 0.004), look.black,
                    0.04, 0.003, 4)
    pc = Vector((0, 0.1, RH))
    torus(parent, "Ring", 0.2, 0.009, pc + Vector((0, 0, 0.012)), look.holo)
    dome(parent, "Linse", 0.12, 0.35, pc + Vector((0, 0, 0.008)), look.lens)
    for sx in (-1, 1):
        base = Vector((sx * 0.48, 0.1, RH))
        tip = Vector((sx * 0.3, 0.1, RH + 0.78))
        pts = bezier(base, base + Vector((sx * 0.12, 0, 0.42)), tip + Vector((sx * 0.22, 0, -0.12)),
                     tip, 28)
        fc.cyl(parent, "Armfuss%d" % sx, 0.06, 0.03, base + Vector((0, 0, 0.015)), look.chrome)
        tube(parent, "Arm%d" % sx, pts, 0.03, look.gun)
        inner = [p + Vector((-sx * 0.026, 0, 0)) for p in pts[2:-1]]
        tube(parent, "Armlicht%d" % sx, inner, 0.009, look.glow)
        dome(parent, "Spitze%d" % sx, 0.04, 1.0, tip, look.holo)
    return pc + Vector((0, 0, 0.05)), (-0.3, RL * 0.5, 0.09)


# --- D: LOTUS - sechs Blätter, geschlossen im Leerlauf, offen im Betrieb -------------------

def petal(parent, name, look, radius, angle, tilt):
    hinge = bpy.data.objects.new(name + "Gelenk", None)
    bpy.context.collection.objects.link(hinge)
    hinge.parent = parent
    hinge.location = (math.cos(angle) * radius, math.sin(angle) * radius, RH + 0.03)
    hinge.rotation_euler = (0, tilt, angle)
    half = radius * math.sin(math.radians(30)) * 0.96
    length = radius * 0.94
    verts = [(0, -half, 0), (0, half, 0), (-length * 0.55, half * 0.62, 0), (-length, 0, 0),
             (-length * 0.55, -half * 0.62, 0)]
    for tag, grow, lift, material in (("", 1.0, 0.0, look.gun), ("Licht", 0.8, 0.009, look.glow)):
        mesh = bpy.data.meshes.new(name + tag)
        mesh.from_pydata([(v[0] * grow - (1 - grow) * length * 0.1, v[1] * grow, lift)
                          for v in verts], [], [(0, 1, 2, 3, 4)])
        o = bpy.data.objects.new(name + tag, mesh)
        bpy.context.collection.objects.link(o)
        o.parent = hinge
        mod = o.modifiers.new("Dicke", "SOLIDIFY")
        mod.thickness = 0.016 if tag == "" else 0.004
        mod.offset = 0.0
        o.data.materials.append(material)


def lotus(parent, look):
    body = led.rounded_box(parent, "Gehaeuse", (RW, RL, RH), (0, 0, RH * 0.5), look.gun,
                           0.14, 0.03, 8)
    front(parent, look, body)
    pc = Vector((0, 0.09, RH))
    fc.cyl(parent, "Kelch", 0.31, 0.03, pc + Vector((0, 0, 0.015)), look.chrome)
    fc.cyl(parent, "Kelchgrund", 0.28, 0.006, pc + Vector((0, 0, 0.032)), look.black)
    torus(parent, "Ring", 0.17, 0.009, pc + Vector((0, 0, 0.036)), look.holo)
    dome(parent, "Linse", 0.12, 0.4, pc + Vector((0, 0, 0.032)), look.lens)
    tilt = math.radians(62) if look.on else math.radians(3)
    blatt = bpy.data.objects.new("Blaetter", None)
    bpy.context.collection.objects.link(blatt)
    blatt.parent = parent
    blatt.location = (pc.x, pc.y, 0)
    for k in range(6):
        petal(blatt, "Blatt%d" % k, look, 0.29, math.radians(30 + k * 60), tilt)
    return pc + Vector((0, 0, 0.07)), (0.3, RL * 0.5, 0.09)


# --- E: KONSOLE - Wabenfeld und Pegelbalken ----------------------------------------------

def konsole(parent, look, level=5):
    body = led.rounded_box(parent, "Gehaeuse", (RW, RL, RH), (0, 0, RH * 0.5), look.black,
                           0.03, 0.01, 6)
    front(parent, look, body)
    hump = led.chamfer_box(parent, "Buckel", (RW - 0.08, 0.52, 0.1), (0, 0.12, RH + 0.05),
                           look.gun, 0.03, 0.035)
    pc = Vector((0, 0.12, RH + 0.1))
    led.rounded_box(parent, "Wabengrund", (0.62, 0.4, 0.004), pc + Vector((0, 0, 0.001)),
                    look.black, 0.03, 0.0, 4)
    r = 0.085
    cells = [(0, 0)] + [(math.cos(math.radians(a)) * r * 1.85, math.sin(math.radians(a)) * r * 1.85)
                        for a in range(0, 360, 60)]
    for k, (cx, cy) in enumerate(cells):
        fc.cyl(parent, "Wabe%d" % k, r, 0.012, pc + Vector((cx, cy, 0.006)), look.chrome,
               rot=(0, 0, math.radians(30)), verts=6)
        fc.cyl(parent, "Wabenlinse%d" % k, r * 0.78, 0.014, pc + Vector((cx, cy, 0.008)),
               look.lens if k == 0 else look.holo, rot=(0, 0, math.radians(30)), verts=6)
    # Pegelbalken vorn auf dem Deck: voll = es wird projiziert, ein Segment bernstein = bereit.
    for k in range(5):
        if look.on:
            material = look.glow if k < level else led.mat("SegmentAus", OFF, 0.0, 0.3)
        else:
            material = look.standby if k == 0 else led.mat("SegmentAus", OFF, 0.0, 0.3)
        fc.box(parent, "Segment%d" % k, (0.11, 0.035, 0.006), (-0.28 + k * 0.14, FY + 0.2,
                                                               RH + 0.003), material)
    for sx in (-1, 1):
        fc.box(parent, "Lichtleiter%d" % sx, (0.01, 0.44, 0.012),
               (sx * (RW * 0.5 - 0.075), 0.12, RH + 0.1), look.soft)
    return pc + Vector((0, 0, 0.02)), (-0.3, RL * 0.5, 0.09)


VARIANTS = [("A_halo", halo), ("B_saeule", saeule), ("C_bogen", bogen), ("D_lotus", lotus),
            ("E_konsole", konsole)]


# --- Bühne --------------------------------------------------------------------------------

def art_path(cid):
    path = os.path.join(ART, "bild_B_terminal_%s.png" % cid)
    return path if os.path.exists(path) else None


def unit(build, x, charm, port_x=None):
    """Ein Projektor samt Kabel; charm = None heißt leer (angeschlossen, aber aus)."""
    look = Look(charm[3] if charm else None)
    root = fc.empty("Projektor")
    root.location = (x, 0, 0)
    lens, plug = build(root, look)
    px = 0.0 if port_x is None else port_x - x
    cable(root, look, plug, Vector((px, PORT_Y, 0)))
    if charm:
        hologram(root, look, charm, lens)
        art = art_path(charm[0])
        if art:
            disk = fc.empty("Diskette")
            fl.terminal(disk, charm, art)
            disk.location = (x, LOADED_Y, SLOT_Z)
    return look


def hide_softboxes():
    for o in bpy.data.objects:
        if o.type == "MESH" and o.data.materials and o.data.materials[0].name.startswith("Softbox"):
            o.hide_render = True


def render_variant(tag, build, charm):
    for view in ("held", "spiel"):
        fc.stage((1600, 1000))
        first = -PITCH * 0.5
        unit(build, first, None)
        unit(build, first + PITCH, charm)
        rail(None, 2, first, {1: fc.srgb(fc.RARITY[charm[3]][1])})
        if view == "held":
            fc.camera((2.3, -3.0, 3.1), (0.05, -0.05, 0.3), 50)
        else:
            hide_softboxes()
            fc.camera((0, -1.7, 5.6), (0, 0.15, 0.25), 55)
        fc.shoot("%s_%s" % (tag, view), view == "held")


def render_row():
    """Alle fünf an einer Zehner-Leiste: Ports 1-5 belegt, 6-10 frei."""
    fc.stage((2400, 1000))
    first = -PITCH * (PORTS - 1) * 0.5
    lit = {}
    for i, (tag, build) in enumerate(VARIANTS):
        charm = fc.CHARMS[i]
        unit(build, first + i * PITCH, charm)
        lit[i] = fc.srgb(fc.RARITY[charm[3]][1])
    rail(None, PORTS, first, lit)
    hide_softboxes()
    fc.camera((0, -8.5, 11.0), (0, 0.1, 0.3), 26)
    fc.shoot("0_leiste_alle_fuenf")
    # Von hinten: Stecker, Kabel und freie Ports aus der Nähe.
    fc.camera((first + PITCH * 4.6, 3.4, 2.2), (first + PITCH * 4.2, 0.5, 0.1), 50)
    fc.shoot("0_leiste_usb_nah")


def main():
    os.makedirs(OUT, exist_ok=True)
    fc.OUT = OUT
    only = ARGS[2] if len(ARGS) > 2 else ""
    for i, (tag, build) in enumerate(VARIANTS):
        if only in ("", tag):
            render_variant(tag, build, fc.CHARMS[i])
    if only in ("", "leiste"):
        render_row()
    print("ok")


if __name__ == "__main__":
    main()
