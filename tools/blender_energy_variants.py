"""Fumble: drei ENTWÜRFE für die Station ENERGIE als Bauteil der Platine (2026-11-24).
  a - KONDENSATORBANK: je Reihe fünf Becher-Kondensatoren zwischen Kupfer-Stromschienen
  b - SPANNUNGSWANDLER: zehn Phasen aus Ringkern-Spule und Kühlkörper, Controller am Kopf
  c - KLINGEN-RACK: zehn Akku-Klingen hochkant in einer Backplane mit Auswurf-Hebeln
Grundriß 6,2 x 15,0 Welt (1 Blender-Einheit = 1 Welt), zehn Reihen zu fünf Energie.

Aufruf (kopflos):
  blender -b -P tools/blender_energy_variants.py -- <ausgabe-ordner> [ansicht,...]
  Ansichten: a, b, c (je alle vier Blätter), a_schraeg, b_zustaende, ..., vergleich
Achsen: X = Bild-rechts, Y = Bild-oben, Z = Höhe, Tisch Z = 0.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_data_media as dm
import blender_chip_screens as cs

led = dm.led
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["."]
OUT = ARGS[0]

W, H = 6.2, 15.0
ROWS, ACROSS = 10, 5
ROW_PITCH = 1.14
ROW_Y0 = -6.5 + ROW_PITCH * 0.5
TOP_Y = ROW_Y0 + ROW_PITCH * 9.5          # Oberkante der zehnten Reihe
PADS_X = (0.7, 1.5, 2.3)
PAD_Y = -7.0
BUS_Y = (-9.0, -9.3, -9.6)
CYAN = led.lin("#2ee6ff")


def row_y(i):
    return ROW_Y0 + i * ROW_PITCH


# --- Material ------------------------------------------------------------------------------

def m_cyan(e=2.6):
    return led.mat("Cyan_%.2f" % e, CYAN, 0.0, 0.3, e)


def m_ghost():
    return led.mat("Geist", (0.012, 0.04, 0.05), 0.0, 0.4, 0.1)


def m_pcb():
    return led.mat("Masse", (0.008, 0.042, 0.026), 0.0, 0.5, clearcoat=0.4)


def m_mask_copper():
    return led.mat("Zug", (0.012, 0.06, 0.034), 0.2, 0.45, clearcoat=0.4)


def m_silk():
    return led.mat("Druck", (0.55, 0.6, 0.57), 0.0, 0.7, 0.1)


def m_caption():
    return led.mat("Beschriftung", (0.75, 0.78, 0.8), 0.0, 0.6, 0.5)


def m_alu():
    return led.mat("Alu", (0.6, 0.62, 0.66), 1.0, 0.32)


def m_alu_dark():
    return led.mat("AluDunkel", (0.22, 0.23, 0.26), 1.0, 0.42)


def m_copper():
    return led.mat("Kupfer", (0.85, 0.42, 0.24), 0.85, 0.35)


def m_sleeve():
    return led.mat("Schrumpf", (0.012, 0.016, 0.035), 0.0, 0.55, clearcoat=0.1)


def m_glass():
    return led.mat("Rauchglas", (0.01, 0.014, 0.018), 0.0, 0.05, clearcoat=1.0)


def m_black():
    return led.mat("Lack", (0.012, 0.013, 0.016), 0.2, 0.35, clearcoat=0.8)


def m_matte():
    return led.mat("Kappe", (0.03, 0.033, 0.04), 0.0, 0.75)


def m_hole():
    return led.mat("Loch", (0.0, 0.0, 0.0), 0.0, 0.9)


def m_ferrite():
    return led.mat("Ferrit", (0.05, 0.05, 0.055), 0.3, 0.6)


# --- Bühne ---------------------------------------------------------------------------------

_mesh = {}


def stage(res=(1600, 1000)):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    led._mats.clear()
    led.base_materials()
    _mesh.clear()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    ee = scene.eevee
    ee.use_bloom = True
    ee.bloom_threshold = 1.0
    ee.bloom_intensity = 0.03
    ee.bloom_radius = 3.0
    ee.use_ssr = True
    ee.use_gtao = True
    ee.use_soft_shadows = True
    ee.shadow_cascade_size = "4096"
    ee.taa_render_samples = 48
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.view_settings.view_transform = "Standard"
    # Die Kamera sieht einen dunklen Raum, das Metall spiegelt ein gedämpftes Studio.
    world = bpy.data.worlds.new("Welt")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    bg.inputs[0].default_value = (0.003, 0.004, 0.004, 1)
    studio = nt.nodes.new("ShaderNodeBackground")
    grad = nt.nodes.new("ShaderNodeTexGradient")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.01, 0.012, 0.014, 1)
    ramp.color_ramp.elements[1].color = (0.9, 0.92, 0.95, 1)
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Rotation"].default_value = (0, math.radians(-90), 0)
    nt.links.new(coord.outputs["Generated"], mapping.inputs[0])
    nt.links.new(mapping.outputs[0], grad.inputs[0])
    nt.links.new(grad.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], studio.inputs[0])
    path = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(path.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(studio.outputs[0], mix.inputs[1])
    nt.links.new(bg.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], nt.nodes["World Output"].inputs[0])
    scene.world = world
    # Festes Schlüssellicht von vorn links oben.
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(38), math.radians(-14), 0))
    sun = bpy.context.active_object
    sun.data.energy = 1.5
    sun.data.angle = math.radians(6)
    bpy.ops.mesh.primitive_plane_add(size=160)
    bpy.context.active_object.data.materials.append(m_pcb())
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object
    scene.camera = cam
    return cam


def look(cam, eye, target, lens):
    cam.location = eye
    cam.rotation_euler = (Vector(target) - Vector(eye)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    cam.data.clip_end = 400


def shoot(name):
    bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("gerendert", name)


def proto(key, make):
    """Geteiltes Netz je Grundform: einmal bauen, beliebig oft setzen."""
    if key not in _mesh:
        make()
        o = bpy.context.active_object
        bpy.ops.object.shade_smooth()
        m = o.data
        m.materials.append(m_hole())
        m.use_fake_user = True
        bpy.data.objects.remove(o)
        _mesh[key] = m
    return _mesh[key]


def put(parent, name, mesh, loc, material, rot=(0, 0, 0), scale=(1, 1, 1)):
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.material_slots[0].link = "OBJECT"
    o.material_slots[0].material = material
    o.location, o.rotation_euler, o.scale = loc, rot, scale
    o.parent = parent
    return o


def cylinder(parent, name, r, depth, loc, material, rot=(0, 0, 0)):
    mesh = proto("zyl", lambda: bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=1, depth=1))
    return put(parent, name, mesh, loc, material, rot, (r, r, depth))


def torus(parent, name, major, minor, loc, material, rot=(0, 0, 0)):
    key = "torus_%.3f_%.3f" % (major, minor)
    mesh = proto(key, lambda: bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor, major_segments=48, minor_segments=12))
    return put(parent, name, mesh, loc, material, rot)


def root(name, x=0.0, y=0.0):
    r = cs.root(name)
    r.location = (0, 0, 0)
    return r


def silk_text(r, body, x, y, size, material=None):
    return cs.text(r, body, x, y, 0.001, size, material or m_silk())


def caption(r, body, x, y, size):
    return cs.text(r, body, x, y, 0.002, size, m_caption(), "Beschriftung")


# --- Segment-Anzeige -----------------------------------------------------------------------

SEG = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
       "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}


def seg_display(r, s, cx, cy, z, h, on=None, off=None):
    on, off = on or m_cyan(3.0), off or m_ghost()
    w, t, gap, sl = 0.5 * h, 0.12 * h, 0.24 * h, 0.34 * h
    total = sum(sl if ch == "/" else w for ch in s) + gap * (len(s) - 1)
    x = cx - total * 0.5
    lit, dim, slash = [], [], []
    for ch in s:
        if ch == "/":
            slash.append([(x, cy - 0.46 * h), (x + sl, cy + 0.46 * h)])
            x += sl + gap
            continue
        xc = x + w * 0.5
        hl, vl = w - t * 1.3, h * 0.5 - t * 1.3
        segs = {"a": (xc, cy + h * 0.5 - t * 0.5, hl, t), "g": (xc, cy, hl, t),
                "d": (xc, cy - h * 0.5 + t * 0.5, hl, t),
                "f": (x + t * 0.5, cy + h * 0.25, t, vl), "b": (x + w - t * 0.5, cy + h * 0.25, t, vl),
                "e": (x + t * 0.5, cy - h * 0.25, t, vl), "c": (x + w - t * 0.5, cy - h * 0.25, t, vl)}
        for k, (sx, sy, sw, shh) in segs.items():
            (lit if ch in SEG and k in SEG[ch] else dim).append((sx, sy, z, sw, shh, 0.004))
        x += w + gap
    if lit:
        cs.boxes(r, "SegmentAn", lit, on)
    if dim:
        cs.boxes(r, "SegmentAus", dim, off)
    if slash:
        cs.strips(r, "SegmentStrich", slash, t, z + 0.002, on)


# --- Grund: Bestückungsdruck, Pads, Züge zum Bus --------------------------------------------

def ground(r):
    hw, hh, t = W * 0.5, H * 0.5, 0.035
    cs.boxes(r, "Umriss", [(0, hh, 0.001, W, t, 0.002), (0, -hh, 0.001, W, t, 0.002),
                           (hw, 0, 0.001, t, H, 0.002), (-hw, 0, 0.001, t, H, 0.002)], m_silk())
    silk_text(r, "U10  ENERGIE", -1.25, PAD_Y, 0.36)
    # Pin-1-Marke links unten.
    dm.cyl(r, "Pin1", 0.07, 0.002, (-hw + 0.25, -hh + 0.25, 0.001), m_silk(), 24)
    lines, cores = [], []
    for k, px in enumerate(PADS_X):
        pts = [(px, PAD_Y), (px, BUS_Y[k])]
        lines.append(pts)
        cores.append(pts)
    bus = [[(-6.5, y), (6.5, y)] for y in BUS_Y]
    cs.strips(r, "Zuege", lines + bus, 0.15, 0.001, m_mask_copper())
    cs.strips(r, "Licht", cores, 0.04, 0.003, m_cyan(0.9))
    cs.strips(r, "BusLicht", bus, 0.035, 0.003, m_cyan(0.5))
    pads = [(px, PAD_Y, 0.004, 0.36, 0.28, 0.008) for px in PADS_X]
    pads += [(px, BUS_Y[k], 0.004, 0.26, 0.26, 0.008) for k, px in enumerate(PADS_X)]
    cs.boxes(r, "GoldPads", pads, cs.m_gold())


def feed(r, y_from):
    """Kurze Züge vom Körper zu den drei Pads."""
    lines = [[(px, y_from), (px, PAD_Y)] for px in PADS_X]
    cs.strips(r, "Zuleitung", lines, 0.15, 0.001, m_mask_copper())
    cs.strips(r, "ZuleitungLicht", lines, 0.04, 0.003, m_cyan(1.2))


# --- A: KONDENSATORBANK --------------------------------------------------------------------

A_PITCH = 1.06
A_R, A_H = 0.4, 0.92


def a_col(k):
    return (k - 2) * A_PITCH


def capacitor(r, x, y, charged):
    cylinder(r, "Becher", A_R, A_H, (x, y, 0.02 + A_H * 0.5), m_sleeve())
    top = 0.02 + A_H
    cylinder(r, "Kopf", A_R - 0.03, 0.02, (x, y, top), m_alu() if charged else m_alu_dark())
    torus(r, "Ring", A_R - 0.035, 0.04, (x, y, top + 0.005), m_cyan(2.8) if charged else m_alu_dark())
    # Polaritätsstreif an der Bild-unteren Flanke.
    cs.boxes(r, "Streif", [(x, y - A_R + 0.004, 0.02 + A_H * 0.55, 0.16, 0.01, A_H * 0.8)],
             led.mat("Polstreif", (0.3, 0.33, 0.38), 0.0, 0.4))


def var_a(r, stand, cap, insert=False):
    ground(r)
    rows = cap // ACROSS
    cross_on, cross_off, tabs = [], [], []
    for i in range(ROWS):
        y = row_y(i)
        for k in range(ACROSS):
            x, n = a_col(k), i * ACROSS + k
            if i < rows:
                charged = n < stand
                capacitor(r, x, y, charged)
                z = 0.02 + A_H + 0.014
                arm = [(x, y, z, 0.5, 0.06, 0.008), (x, y, z, 0.06, 0.5, 0.008)]
                (cross_on if charged else cross_off).extend(arm)
                tabs += [(x, y + s * (A_R + 0.08), 0.04, 0.16, 0.2, 0.05) for s in (-1, 1)]
            else:
                dm.annulus(r, "Bestueckung", x, y, 0.002, A_R, A_R + 0.035, m_silk(), 48)
                for s in (-1, 1):
                    dm.annulus(r, "Loetauge", x, y + s * 0.22, 0.004, 0.05, 0.11, cs.m_gold(), 24)
                    dm.cyl(r, "Bohrung", 0.05, 0.002, (x, y + s * 0.22, 0.003), m_hole(), 16)
                silk_text(r, "+", x + 0.2, y + 0.22, 0.2)
    if cross_on:
        cs.boxes(r, "KreuzAn", cross_on, m_cyan(3.0))
    if cross_off:
        cs.boxes(r, "KreuzAus", cross_off, led.mat("Kerbe", (0.02, 0.02, 0.025), 0.5, 0.5))
    if tabs:
        cs.boxes(r, "Laschen", tabs, m_copper())
    # Stromschienen zwischen den Reihen, abwechselnd links und rechts gesammelt.
    rails, mounts = [], []
    if rows:
        ys = [row_y(0) - ROW_PITCH * 0.5 + b * ROW_PITCH for b in range(rows + 1)]
        for b, y in enumerate(ys):
            x0, x1 = (-2.95, 2.62) if b % 2 == 0 else (-2.62, 2.95)
            rails.append(((x0 + x1) * 0.5, y, 0.14, x1 - x0, 0.14, 0.16))
            mounts += [(x, y, 0.03, 0.22, 0.22, 0.06) for x in (-2.75, 2.75)]
        for side, sel in ((-1, ys[0::2]), (1, ys[1::2])):
            if len(sel) > 1:
                rails.append((side * 2.88, (sel[0] + sel[-1]) * 0.5, 0.14, 0.14, sel[-1] - sel[0] + 0.14, 0.16))
        cs.boxes(r, "Schienen", rails, m_copper())
        cs.boxes(r, "Stuetzen", mounts, cs.m_steel())
    for b in range(rows + 1 if rows else 0, ROWS + 1):
        y = row_y(0) - ROW_PITCH * 0.5 + b * ROW_PITCH
        for x in (-2.75, 2.75):
            dm.annulus(r, "SchienenAuge", x, y, 0.004, 0.06, 0.13, cs.m_gold(), 24)
    feed(r, row_y(0) - ROW_PITCH * 0.5)
    # Segment-Modul mit Flachband zum Pfostenstecker.
    my = 6.55
    led.rounded_box(r, "Modul", (4.6, 1.35, 0.24), (0.35, my, 0.12), m_black(), 0.12, 0.03, 6)
    led.rounded_box(r, "Fenster", (3.7, 0.95, 0.02), (0.55, my, 0.245), m_glass(), 0.06, 0.0, 6)
    seg_display(r, "%d/%d" % (stand, cap), 0.55, my, 0.26, 0.62)
    cs.boxes(r, "Schrauben", [(0.35 + sx * 2.1, my + sy * 0.48, 0.25, 0.12, 0.12, 0.02)
                              for sx in (-1, 1) for sy in (-1, 1)], cs.m_steel())
    stripes = []
    for j in range(10):
        x = -1.85 + j * 0.045
        stripes.append((x, 5.55, 0.02, 0.04, 0.55, 0.03))
    cs.boxes(r, "Flachband", stripes[1:], led.mat("Band", (0.32, 0.33, 0.36), 0.0, 0.6))
    cs.boxes(r, "Ader1", stripes[:1], led.mat("AderRot", (0.5, 0.03, 0.03), 0.0, 0.6))
    cs.boxes(r, "Stecker", [(-1.65, 5.15, 0.11, 0.8, 0.3, 0.22)], m_black())
    cs.boxes(r, "SteckerPins", [(-1.95 + j * 0.15, 5.15, 0.23, 0.05, 0.05, 0.02) for j in range(5)],
             cs.m_gold())


# --- B: SPANNUNGSWANDLER -------------------------------------------------------------------

B_COIL_X = -1.95
B_SINK = (-1.25, 2.95)


def phase_coil(r, y):
    torus(r, "Kern", 0.3, 0.13, (B_COIL_X, y, 0.16), m_ferrite())
    for k in range(16):
        a = math.tau * k / 16
        torus(r, "Wicklung", 0.15, 0.024,
              (B_COIL_X + math.cos(a) * 0.3, y + math.sin(a) * 0.3, 0.16), m_copper(),
              (math.radians(90), 0, a + math.radians(90)))


def var_b(r, stand, cap, insert=False):
    ground(r)
    rows = cap // ACROSS
    sink, lit, dark, covers, slots, carrier = [], [], [], [], [], []
    x0, x1 = B_SINK
    depth = ROW_PITCH - 0.22
    for i in range(ROWS):
        y = row_y(i)
        if i < rows:
            phase_coil(r, y)
            sink.append(((x0 + x1) * 0.5, y, 0.06, x1 - x0, depth, 0.12))
            # Rippen längs, in der Mittelnut liegt der Lichtbalken.
            for s in (-1, 1):
                for fy in (0.25, 0.345, 0.44):
                    sink.append(((x0 + x1) * 0.5, y + s * fy, 0.12 + 0.23, x1 - x0, 0.045, 0.46))
            carrier.append(((x0 + x1) * 0.5, y, 0.2, x1 - x0 - 0.1, 0.4, 0.17))
            pitch = (x1 - x0 - 0.16) / ACROSS
            for k in range(ACROSS):
                cx = x0 + 0.08 + pitch * (k + 0.5)
                item = (cx, y, 0.29, pitch - 0.2, 0.32, 0.014)
                (lit if i * ACROSS + k < stand else dark).append(item)
        else:
            led.rounded_box(r, "Abdeckkappe", (x1 + 2.45, depth, 0.34),
                            ((x1 - 2.45) * 0.5, y, 0.17), m_matte(), 0.14, 0.05, 6)
            for k in range(7):
                slots.append((-1.6 + k * 0.62, y, 0.341, 0.36, depth * 0.45, 0.004))
            covers += [(sx, y, 0.345, 0.09, 0.09, 0.012) for sx in (-2.25, 2.75)]
    if sink:
        cs.boxes(r, "Kuehlkoerper", sink, m_alu())
        cs.boxes(r, "Balken", carrier, m_black())
    if lit:
        cs.boxes(r, "SegmentAn", lit, m_cyan(2.8))
    if dark:
        cs.boxes(r, "SegmentAus", dark, led.mat("Linse", (0.02, 0.03, 0.035), 0.0, 0.2, clearcoat=1.0))
    if slots:
        cs.boxes(r, "Schlitze", slots, m_hole())
        cs.boxes(r, "KappenSchrauben", covers, cs.m_steel())
    # Zehn feine Züge vom Controller durch die linke Gasse zu den Phasen.
    on, off = [], []
    for i in range(ROWS):
        lx = -2.98 + 0.04 * i
        sx = -1.45 - 0.05 * i
        y = row_y(i)
        pts = [(sx, 5.45), (sx, 5.3), (lx, 5.3 - (sx - lx)), (lx, y), (B_COIL_X - 0.42, y)]
        (on if i < rows else off).append(pts)
    if on:
        cs.strips(r, "PhasenZug", on, 0.022, 0.003, m_cyan(1.4))
    if off:
        cs.strips(r, "PhasenZugAus", off, 0.022, 0.003, m_mask_copper())
    feed(r, row_y(0) - ROW_PITCH * 0.5)
    lines = [[(px, row_y(0) - ROW_PITCH * 0.5), (px, row_y(0) - depth * 0.5)] for px in PADS_X]
    cs.strips(r, "Abgang", lines, 0.15, 0.001, m_mask_copper())
    # Controller-Chip (QFP) mit Segment-Fenster.
    cy, cw, ch = 6.45, 4.2, 1.7
    led.rounded_box(r, "Controller", (cw, ch, 0.22), (0.3, cy, 0.13), cs.m_epoxy(), 0.05, 0.02, 4)
    leads = []
    for j in range(22):
        x = 0.3 - cw * 0.5 + 0.2 + j * (cw - 0.4) / 21
        leads += [(x, cy + s * (ch * 0.5 + 0.09), 0.03, 0.06, 0.2, 0.04) for s in (-1, 1)]
    for j in range(8):
        yy = cy - ch * 0.5 + 0.2 + j * (ch - 0.4) / 7
        leads += [(0.3 + s * (cw * 0.5 + 0.09), yy, 0.03, 0.2, 0.06, 0.04) for s in (-1, 1)]
    cs.boxes(r, "Beinchen", leads, cs.m_steel())
    led.rounded_box(r, "ChipFenster", (3.3, 1.0, 0.02), (0.45, cy + 0.05, 0.245), m_glass(), 0.05, 0.0, 4)
    seg_display(r, "%d/%d" % (stand, cap), 0.45, cy + 0.05, 0.262, 0.64)
    dm.cyl(r, "ChipPunkt", 0.07, 0.004, (0.3 - cw * 0.5 + 0.22, cy - ch * 0.5 + 0.2, 0.242),
           led.mat("Punkt", (0.08, 0.08, 0.09), 0.0, 0.6), 16)


# --- C: KLINGEN-RACK -----------------------------------------------------------------------

C_LEN = 5.5
C_THICK = 0.56
C_TOP = 1.55
C_WIN_PITCH = 0.86
C_WIN_X = -0.55


def blade(r, y, lit_count, lift=0.0):
    z0 = 0.12 + lift
    led.rounded_box(r, "Klinge", (C_LEN, C_THICK, C_TOP - 0.12), (0, y, z0 + (C_TOP - 0.12) * 0.5),
                    m_black(), 0.04, 0.02, 4)
    zt = z0 + C_TOP - 0.12
    cs.boxes(r, "Kopfschiene", [(-0.1, y, zt + 0.02, C_LEN - 0.3, C_THICK - 0.08, 0.04)], m_alu_dark())
    on, off = [], []
    for k in range(ACROSS):
        x = C_WIN_X + (k - 2) * C_WIN_PITCH
        (on if k < lit_count else off).append((x, y, zt + 0.045, 0.64, C_THICK - 0.22, 0.012))
    if on:
        cs.boxes(r, "FensterAn", on, m_cyan(2.8))
    if off:
        cs.boxes(r, "FensterAus", off, led.mat("Linse", (0.02, 0.03, 0.035), 0.0, 0.2, clearcoat=1.0))
    # Auswurf-Hebel rechts: Griff auf der Kante, Haken außen hinab.
    hx = C_LEN * 0.5
    cs.boxes(r, "Hebel", [(hx - 0.5, y, zt + 0.07, 0.72, 0.14, 0.08),
                          (hx - 0.84, y, zt + 0.04, 0.06, 0.3, 0.1),
                          (hx + 0.04, y, zt - 0.32, 0.08, 0.3, 0.86)],
             led.mat("Hebel", (0.75, 0.77, 0.8), 0.6, 0.35))
    cylinder(r, "Drehpunkt", 0.07, C_THICK + 0.02, (hx - 0.12, y, zt + 0.06), cs.m_steel(),
             (math.radians(90), 0, 0))
    # Lichtleiter an der Bild-unteren Flanke zeigt dieselbe Ladung.
    cs.boxes(r, "Flanke", [(0, y - C_THICK * 0.5 - 0.002, z0 + 0.45, C_LEN - 0.4, 0.006, 0.05)],
             m_cyan(1.0) if lit_count else led.mat("FlankeAus", (0.03, 0.04, 0.05), 0.0, 0.4))


def var_c(r, stand, cap, insert=False):
    ground(r)
    rows = cap // ACROSS
    yb, yt = row_y(0) - ROW_PITCH * 0.5 - 0.1, TOP_Y + 0.05
    led.rounded_box(r, "Backplane", (W - 0.2, yt - yb, 0.1), (0, (yb + yt) * 0.5, 0.05),
                    led.mat("Backplane", (0.012, 0.018, 0.028), 0.2, 0.5, clearcoat=0.5), 0.1, 0.02, 4)
    walls = [(s * 2.96, (yb + yt) * 0.5, 0.6, 0.12, yt - yb, 1.1) for s in (-1, 1)]
    guides, contacts, gold = [], [], []
    for i in range(ROWS):
        y = row_y(i)
        for s in (-1, 1):
            guides += [(s * 2.83, y + d * (C_THICK * 0.5 + 0.06), 0.55, 0.14, 0.08, 0.9) for d in (-1, 1)]
        if i < rows and not (insert and i == rows - 1):
            blade(r, y, max(0, min(ACROSS, stand - i * ACROSS)))
        else:
            contacts.append((0, y, 0.16, 4.4, 0.34, 0.12))
            gold += [(-2.0 + j * 0.16, y, 0.225, 0.08, 0.2, 0.01) for j in range(26)]
            if insert and i == rows - 1:
                blade(r, y, 0, 2.2)
    cs.boxes(r, "Wangen", walls, cs.m_steel())
    cs.boxes(r, "Fuehrungen", guides, m_alu_dark())
    if contacts:
        cs.boxes(r, "Kontaktleiste", contacts, m_black())
        cs.boxes(r, "Kontakte", gold, cs.m_gold())
    feed(r, yb)
    # Kopfleiste der Backplane mit Segment-Modul.
    cs.boxes(r, "Kopfleiste", [(0, yt + 0.2, 0.55, W - 0.1, 0.4, 1.1)], cs.m_steel())
    my = 6.55
    led.rounded_box(r, "KopfPlatte", (W - 0.3, 1.5, 0.5), (0, my, 0.25), m_black(), 0.1, 0.03, 4)
    led.rounded_box(r, "Modul", (4.0, 1.12, 0.06), (0.1, my, 0.52), m_glass(), 0.06, 0.0, 4)
    seg_display(r, "%d/%d" % (stand, cap), 0.1, my, 0.556, 0.66)
    cs.boxes(r, "Schrauben", [(sx * 2.65, my, 0.51, 0.14, 0.14, 0.03) for sx in (-1, 1)], cs.m_steel())


# --- C2: KLINGEN-RACK, Runde 2 - versenkt, nur die Oberkanten stehen über dem Tisch -----------------

C2_TOP = 0.42


def blade2(r, y, lit_count, lift=0.0):
    tall = 1.5 if lift else C2_TOP
    z0 = lift
    led.rounded_box(r, "Klinge", (C_LEN, C_THICK, tall), (0, y, z0 + tall * 0.5),
                    led.mat("KlingeMatt", (0.03, 0.033, 0.04), 0.1, 0.7), 0.04, 0.02, 4)
    zt = z0 + tall
    cs.boxes(r, "Kopfschiene", [(-0.1, y, zt + 0.02, C_LEN - 0.3, C_THICK - 0.08, 0.04)], m_alu_dark())
    on, off = [], []
    for k in range(ACROSS):
        x = C_WIN_X + (k - 2) * C_WIN_PITCH
        (on if k < lit_count else off).append((x, y, zt + 0.045, 0.66, C_THICK - 0.2, 0.012))
    if on:
        cs.boxes(r, "FensterAn", on, m_cyan(2.8))
    if off:
        cs.boxes(r, "FensterAus", off, led.mat("Linse", (0.02, 0.03, 0.035), 0.0, 0.2, clearcoat=1.0))
    # Auswurf-Hebel rechts: schmaler Stahlbügel mit Lichtspitze - voll cyan, leer bernstein
    hx = C_LEN * 0.5
    cs.boxes(r, "Hebel", [(hx - 0.42, y, zt + 0.06, 0.6, 0.1, 0.05)], cs.m_steel())
    tip = m_cyan(2.2) if lit_count == ACROSS else (led.mat("TipBernstein", led.lin("#ffb347"), 0.0, 0.3, 1.6)
                                                    if lit_count else led.mat("TipAus", (0.05, 0.06, 0.07), 0.0, 0.4))
    cs.boxes(r, "HebelSpitze", [(hx - 0.2, y, zt + 0.07, 0.16, 0.3, 0.07)], tip)
    if lift:
        cs.boxes(r, "Kontaktkamm", [(-2.0 + j * 0.16, y, z0 - 0.06, 0.08, 0.18, 0.12) for j in range(26)],
                 cs.m_gold())


def var_c2(r, stand, cap, insert=False):
    ground(r)
    rows = cap // ACROSS
    yb, yt = row_y(0) - ROW_PITCH * 0.5 - 0.1, TOP_Y + 0.05
    # Kragen der Grube: flacher Stahlrahmen, innen der dunkle Schacht
    cs.boxes(r, "Schacht", [(0, (yb + yt) * 0.5, 0.01, W - 0.5, yt - yb - 0.1, 0.02)], m_hole())
    cs.boxes(r, "Kragen", cs.ring_items(0, (yb + yt) * 0.5, W - 0.1, yt - yb + 0.3, W - 0.5, yt - yb - 0.1,
                                        0.09, 0.18), cs.m_steel())
    guides, gold, glow_slots, marks = [], [], [], []
    for i in range(ROWS):
        y = row_y(i)
        for s in (-1, 1):
            guides += [(s * 2.78, y + d * (C_THICK * 0.5 + 0.07), 0.12, 0.12, 0.06, 0.22) for d in (-1, 1)]
        silk_text(r, "%02d" % (i + 1), -3.45, y, 0.26)
        if i < rows and not (insert and i == rows - 1):
            blade2(r, y, max(0, min(ACROSS, stand - i * ACROSS)))
        else:
            gold += [(-2.0 + j * 0.16, y, 0.024, 0.08, 0.2, 0.008) for j in range(26)]
            if insert and i == rows - 1:
                blade2(r, y, 0, 1.3)
                glow_slots += cs.ring_items(0, y, C_LEN + 0.1, C_THICK + 0.16, C_LEN, C_THICK + 0.06, 0.024, 0.006)
    cs.boxes(r, "Fuehrungen", guides, m_alu_dark())
    if gold:
        cs.boxes(r, "Kontakte", gold, cs.m_gold())
    if glow_slots:
        cs.boxes(r, "SchachtRuf", glow_slots, m_cyan(1.6))
    feed(r, yb)
    my = 6.55
    led.rounded_box(r, "KopfPlatte", (W - 0.3, 1.5, 0.3), (0, my, 0.15), m_black(), 0.1, 0.03, 4)
    led.rounded_box(r, "Modul", (4.0, 1.12, 0.06), (0.1, my, 0.32), m_glass(), 0.06, 0.0, 4)
    seg_display(r, "%d/%d" % (stand, cap), 0.1, my, 0.356, 0.66)
    cs.boxes(r, "Schrauben", [(sx * 2.65, my, 0.31, 0.14, 0.14, 0.03) for sx in (-1, 1)], cs.m_steel())
    cs.boxes(r, "Flachband", [(0.1, my - 0.95, 0.012, 1.2, 0.5, 0.02)],
             led.mat("Kapton", (0.6, 0.3, 0.04), 0.0, 0.35, 0.35))


VARIANTS = {"a": (var_a, "A · KONDENSATORBANK"), "b": (var_b, "B · SPANNUNGSWANDLER"),
            "c": (var_c, "C · KLINGEN-RACK"), "c2": (var_c2, "C2 · KLINGEN-RACK")}
STATES = [(0, 5, "Start"), (3, 5, "angebrochen"), (12, 15, "mittlerer Lauf"), (50, 50, "voll ausgebaut")]


def build(tag, stand, cap, x=0.0, insert=False):
    r = root("Station_" + tag)
    VARIANTS[tag][0](r, stand, cap, insert)
    r.location = (x, 0, 0)
    return r


# --- Blätter -------------------------------------------------------------------------------

def sheet_single(tag, which):
    cam = stage()
    if which == "detail":
        build(tag, 12, 15, insert=tag.startswith("c"))
        look(cam, (6.0, -15.5, 12.0), (0.2, -3.6, 0.6), 45)
        shoot("%s_detail" % tag)
        return
    build(tag, 12, 15)
    if which == "schraeg":
        look(cam, (0.0, -11.6, 40.0), (0.0, -1.4, 0.0), 50)
    else:
        look(cam, (0.0, -1.4, 41.0), (0.0, -1.4, 0.0), 50)
    shoot("%s_%s" % (tag, which))


def sheet_states(tag):
    cam = stage()
    for k, (stand, cap, word) in enumerate(STATES):
        x = (k - 1.5) * 7.6
        build(tag, stand, cap, x)
        r = root("Text")
        caption(r, "%d/%d" % (stand, cap), x, -10.7, 0.8)
        caption(r, word, x, -11.7, 0.45)
    look(cam, (0.0, -12.0, 44.0), (0.0, -2.0, 0.0), 42)
    shoot("%s_zustaende" % tag)


def sheet_compare():
    cam = stage()
    for k, tag in enumerate("abc"):
        x = (k - 1) * 8.4
        build(tag, 12, 15, x)
        caption(root("Text"), VARIANTS[tag][1], x, -10.7, 0.55)
    look(cam, (0.0, -12.0, 42.0), (0.0, -1.8, 0.0), 42)
    shoot("vergleich")


def jobs():
    out = []
    for tag in VARIANTS:
        for which in ("schraeg", "oben", "detail"):
            out.append(("%s_%s" % (tag, which), lambda t=tag, w=which: sheet_single(t, w)))
        out.append(("%s_zustaende" % tag, lambda t=tag: sheet_states(t)))
    out.append(("vergleich", sheet_compare))
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = ARGS[1].split(",") if len(ARGS) > 1 else []
    for name, fn in jobs():
        if only and not any(name == o or name.startswith(o + "_") for o in only):
            continue
        fn()
    print("ok")
