"""Fumble: die LED-Leisten-Kassette in drei EDLEN Varianten (Spieler-Wunsch 2026-11-15).

Gemeinsam: Fenster mit der ersten Karte (Sortenfarbe, leeres Netz), fünf LED-Plätze unter
dem Fenster und auf dem Rücken - so viele leuchten, wie Karten im Paket sind; das Gehäuse
trägt das Metall der Güte.
  tresor     - gefaste Kanten, gestufte Chromlünette ums Fenster, LED-Kuppeln in Chromringen,
               vier Schrauben
  juwelier   - weiches Kissen-Gehäuse, schmale Lünette, facettierte Steine als LEDs in einer
               Rinne, eingelegte Zierlinie
  schwarzglas - Metallrahmen mit eingelassener schwarzer Glasfront; Karte und LEDs leuchten
               durch das Glas

Aufruf (kopflos):
  blender -b -P tools/blender_card_cassette_led.py -- <ausgabe-ordner>
Achsen wie die Schatulle: X = Breite, Y = Länge (Kopf +Y), Z = Höhe, Ursprung = Mitte unten.
"""
import bpy, bmesh, math, sys, os

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(OUT, exist_ok=True)

W = 1.08 * 1.04
L = 1.62 * 1.04
H = 0.1512 * 2.35
WIN = (W * 0.7, L * 0.54)
WIN_Y = L * 0.12
LED_Y = -L * 0.335


def lin(hex_color):
    h = hex_color.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4))


SORTS = {"zahl": lin("#50fa7b"), "material": lin("#ff79c6"), "rune": lin("#ffd319")}
MIX = ["zahl", "material", "rune"]
QUALITY = [(lin("#5a5a60"), 0.8, 0.34), (lin("#e4e5ea"), 0.9, 0.16), (lin("#efc56f"), 0.9, 0.2)]
PACKS = [("zahl", 3, 0), ("material", 4, 1), ("rune", 5, 2), ("misch", 4, 0)]

_mats = {}


def mat(name, color, metal=0.0, rough=0.5, emit=0.0, alpha=1.0, clearcoat=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    p.inputs["Clearcoat"].default_value = clearcoat
    if emit > 0.0:
        p.inputs["Emission"].default_value = (*color, 1)
        p.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
        m.shadow_method = "NONE"
        m.use_screen_refraction = False
    _mats[name] = m
    return m


def metal(q):
    c, m, r = QUALITY[q]
    return mat("Metall%d" % q, c, m, r, clearcoat=0.3)


def sort_mat(sort, emit=1.0):
    return mat("Sorte_%s_%.2f" % (sort, emit), SORTS[sort], 0.0, 0.3, emit)


CHROME = DARK = GLASS = LED_OFF = LED_ON = BLACK_GLASS = None


def base_materials():
    global CHROME, DARK, GLASS, LED_OFF, LED_ON, BLACK_GLASS
    CHROME = mat("Chrom", (0.85, 0.86, 0.88), 1.0, 0.06)
    DARK = mat("Dunkel", (0.008, 0.008, 0.01), 0.0, 0.45)
    GLASS = mat("Glas", (0.9, 0.93, 1.0), 0.0, 0.02, 0.0, 0.1)
    LED_OFF = mat("LedAus", (0.02, 0.02, 0.025), 0.0, 0.15, clearcoat=1.0)
    LED_ON = mat("LedAn", (1.0, 0.96, 0.88), 0.0, 0.1, 6.0)
    BLACK_GLASS = mat("Schwarzglas", (0.004, 0.004, 0.006), 0.0, 0.04, clearcoat=1.0)


def rounded_box(parent, name, size, loc, material, corner, edge, segs=10):
    """Gerundetes Rechteck in der Draufsicht (corner) mit gerundeten Ober-/Unterkanten (edge)."""
    sx, sy, sz = size
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    for e in o.data.edges:
        v0 = o.data.vertices[e.vertices[0]].co
        v1 = o.data.vertices[e.vertices[1]].co
        e.bevel_weight = 1.0 if abs(v0.z - v1.z) > 1e-6 else 0.0
    if corner > 0.0:
        m = o.modifiers.new("Grundriss", "BEVEL")
        m.limit_method = "WEIGHT"
        m.width = corner
        m.segments = segs
    if edge > 0.0:
        m = o.modifiers.new("Kante", "BEVEL")
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(60)
        m.width = edge
        m.segments = max(2, segs // 2)
    bpy.ops.object.shade_smooth()
    o.data.use_auto_smooth = True
    o.data.auto_smooth_angle = math.radians(50)
    o.parent = parent
    return o


def chamfer_box(parent, name, size, loc, material, corner, chamfer):
    """Gefast: gerundete Ecken in der Draufsicht, eine scharfe Fase an der Oberkante."""
    o = rounded_box(parent, name, size, loc, material, corner, 0.0)
    m = o.modifiers.new("Fase", "BEVEL")
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(60)
    m.width = chamfer
    m.segments = 1
    return o


def cut(target, cutter):
    mod = target.modifiers.new("Schnitt", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    mod.solver = "EXACT"
    cutter.hide_render = True
    cutter.display_type = "WIRE"


def frame_ring(parent, name, outer, inner, z, height, material, corner, y=WIN_Y):
    ring = rounded_box(parent, name, (outer[0], outer[1], height), (0, y, z), material,
                       corner + (outer[0] - inner[0]) * 0.5, 0.004, 8)
    hole = rounded_box(parent, name + "Loch", (inner[0], inner[1], height * 3), (0, y, z),
                       DARK, corner, 0.0, 8)
    cut(ring, hole)
    return ring


def card(parent, sort, size, z):
    cw, cl = size
    if sort == "misch":
        stripe = cw / 3.0
        for i, s in enumerate(MIX):
            rounded_box(parent, "Karte%d" % i, (stripe, cl, 0.008),
                        (-cw * 0.5 + stripe * (i + 0.5), WIN_Y, z), sort_mat(s, 0.8), 0.0, 0.0)
    else:
        rounded_box(parent, "Karte", (cw, cl, 0.008), (0, WIN_Y, z), sort_mat(sort, 0.8),
                    0.025, 0.0, 6)
    cell = min(cw / 4.8, cl / 3.8)
    for i, (cx, cy) in enumerate([(-1.5, 0), (-0.5, 0), (0.5, 0), (1.5, 0), (-0.5, 1), (-0.5, -1)]):
        rounded_box(parent, "Netzzelle%d" % i, (cell * 0.84, cell * 0.84, 0.004),
                    (cx * cell, WIN_Y + cy * cell, z + 0.006), DARK, cell * 0.12, 0.0, 4)


def seam(parent, sort, z_share=0.4):
    tint = sort_mat(sort, 2.0) if sort != "misch" else mat("NahtMisch", lin("#d6dcec"), 0.0,
                                                            0.3, 1.5)
    rounded_box(parent, "Naht", (W + 0.008, L + 0.008, H * 0.035), (0, 0, H * z_share), tint,
                0.09, 0.0)


def leds_head(parent, count, radius, gem=False):
    for i in range(5):
        x = (i - 2) * W * 0.13
        led(parent, "Kopf%d" % i, i < count, radius * 0.85, (x, L * 0.5, H * 0.62),
            (math.radians(-90), 0, 0), gem)


def led(parent, name, lit, radius, loc, rot=(0, 0, 0), gem=False):
    material = LED_ON if lit else LED_OFF
    if gem:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=radius, location=loc,
                                              rotation=rot)
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=radius,
                                             location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = "Led" + name
    o.scale = (1, 1, 0.45)
    o.data.materials.append(material)
    if not gem:
        bpy.ops.object.shade_smooth()
    o.parent = parent
    bpy.ops.mesh.primitive_torus_add(major_radius=radius * 1.15, minor_radius=radius * 0.2,
                                     location=loc, rotation=rot, major_segments=32,
                                     minor_segments=10)
    t = bpy.context.active_object
    t.name = "Ring" + name
    t.data.materials.append(CHROME)
    bpy.ops.object.shade_smooth()
    t.parent = parent


# --- Die drei Varianten --------------------------------------------------------------

def tresor(parent, sort, count, quality):
    body = chamfer_box(parent, "Gehaeuse", (W, L, H), (0, 0, H * 0.5), metal(quality), 0.07, 0.045)
    recess = rounded_box(parent, "Mulde", (WIN[0] + 0.05, WIN[1] + 0.05, 0.08),
                         (0, WIN_Y, H), DARK, 0.04, 0.0, 8)
    channel = rounded_box(parent, "Rinne", (W * 0.66, W * 0.13, 0.06), (0, LED_Y, H), DARK,
                          W * 0.065, 0.0, 10)
    cut(body, recess)
    cut(body, channel)
    rounded_box(parent, "MuldeBoden", (WIN[0] + 0.05, WIN[1] + 0.05, 0.01),
                (0, WIN_Y, H - 0.035), DARK, 0.04, 0.0)
    card(parent, sort, WIN, H - 0.026)
    frame_ring(parent, "Luenette", (WIN[0] + 0.1, WIN[1] + 0.1), (WIN[0] + 0.03, WIN[1] + 0.03),
               H + 0.004, 0.016, CHROME, 0.035)
    rounded_box(parent, "Scheibe", (WIN[0] + 0.04, WIN[1] + 0.04, 0.004), (0, WIN_Y, H - 0.006),
                GLASS, 0.035, 0.0)
    rounded_box(parent, "RinneBoden", (W * 0.66, W * 0.13, 0.01), (0, LED_Y, H - 0.022), DARK,
                W * 0.065, 0.0, 10)
    for i in range(5):
        led(parent, str(i), i < count, W * 0.034, ((i - 2) * W * 0.13, LED_Y, H - 0.012))
    for sx in (-1, 1):
        for sy in (-1, 1):
            loc = (sx * (W * 0.5 - 0.075), sy * (L * 0.5 - 0.075), H + 0.002)
            bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.022, depth=0.01, location=loc)
            s = bpy.context.active_object
            s.data.materials.append(CHROME)
            bpy.ops.object.shade_smooth()
            s.parent = parent
            bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0], loc[1], loc[2] + 0.004))
            slot = bpy.context.active_object
            slot.scale = (0.032, 0.006, 0.004)
            slot.data.materials.append(DARK)
            slot.rotation_euler = (0, 0, math.radians(45 * sx * sy))
            slot.parent = parent
    seam(parent, sort)
    leds_head(parent, count, W * 0.034)


def juwelier(parent, sort, count, quality):
    body = rounded_box(parent, "Gehaeuse", (W, L, H), (0, 0, H * 0.5), metal(quality), 0.13,
                       0.07, 14)
    recess = rounded_box(parent, "Mulde", (WIN[0], WIN[1], 0.08), (0, WIN_Y, H), DARK, 0.06,
                         0.0, 12)
    channel = rounded_box(parent, "Rinne", (W * 0.7, W * 0.1, 0.05), (0, LED_Y, H), DARK,
                          W * 0.05, 0.0, 12)
    cut(body, recess)
    cut(body, channel)
    card(parent, sort, (WIN[0] - 0.02, WIN[1] - 0.02), H - 0.024)
    frame_ring(parent, "Luenette", (WIN[0] + 0.035, WIN[1] + 0.035), (WIN[0] - 0.004, WIN[1] - 0.004),
               H + 0.001, 0.012, CHROME, 0.06)
    rounded_box(parent, "Scheibe", (WIN[0], WIN[1], 0.004), (0, WIN_Y, H - 0.008), GLASS, 0.06,
                0.0, 12)
    rounded_box(parent, "RinneBoden", (W * 0.7, W * 0.1, 0.01), (0, LED_Y, H - 0.02), DARK,
                W * 0.05, 0.0, 12)
    for i in range(5):
        led(parent, str(i), i < count, W * 0.03, ((i - 2) * W * 0.13, LED_Y, H - 0.012), gem=True)
    # Die eingelegte Zierlinie in der Sortenfarbe, eine Spur innerhalb der Kante.
    inlay = sort_mat(sort if sort != "misch" else "material", 1.4)
    frame_ring(parent, "Zierlinie", (W - 0.2, L - 0.2), (W - 0.214, L - 0.214), H - 0.003,
               0.006, inlay, 0.05, 0.0)
    leds_head(parent, count, W * 0.03, gem=True)


def schwarzglas(parent, sort, count, quality):
    body = rounded_box(parent, "Gehaeuse", (W, L, H), (0, 0, H * 0.5), metal(quality), 0.1,
                       0.012, 12)
    panel_size = (W - 0.13, L - 0.13)
    pocket = rounded_box(parent, "Tasche", (panel_size[0], panel_size[1], 0.08), (0, 0, H), DARK,
                         0.07, 0.0, 12)
    cut(body, pocket)
    card(parent, sort, WIN, H - 0.03)
    # Die Glasfront: schwarz, nur das Fenster ist klar; die LEDs leuchten von unten durch.
    front = rounded_box(parent, "Front", (panel_size[0], panel_size[1], 0.02), (0, 0, H - 0.01),
                        BLACK_GLASS, 0.07, 0.006, 12)
    hole = rounded_box(parent, "FrontFenster", (WIN[0], WIN[1], 0.1), (0, WIN_Y, H), DARK, 0.03,
                       0.0, 10)
    cut(front, hole)
    rounded_box(parent, "Scheibe", (WIN[0], WIN[1], 0.004), (0, WIN_Y, H - 0.004), GLASS, 0.03,
                0.0)
    for i in range(5):
        x = (i - 2) * W * 0.12
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=W * 0.028, depth=0.004,
                                            location=(x, LED_Y, H + 0.0005))
        d = bpy.context.active_object
        d.data.materials.append(LED_ON if i < count else mat("LedGlas", (0.03, 0.03, 0.035),
                                                              0.0, 0.05, clearcoat=1.0))
        bpy.ops.object.shade_smooth()
        d.parent = parent
    # Haarlinie in der Sortenfarbe um die Glasfront.
    hair = sort_mat(sort if sort != "misch" else "material", 2.0)
    frame_ring(parent, "Haarlinie", (panel_size[0] + 0.012, panel_size[1] + 0.012), panel_size,
               H - 0.005, 0.008, hair, 0.07, 0.0)
    for i in range(5):
        x = (i - 2) * W * 0.13
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=W * 0.026, depth=0.006,
                                            location=(x, L * 0.5 + 0.001, H * 0.6),
                                            rotation=(math.radians(90), 0, 0))
        d = bpy.context.active_object
        d.data.materials.append(LED_ON if i < count else LED_OFF)
        bpy.ops.object.shade_smooth()
        d.parent = parent


VARIANTS = [("tresor", tresor), ("juwelier", juwelier), ("schwarzglas", schwarzglas)]


def softbox(loc, rot, size, strength):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = (size[0], size[1], 1)
    m = bpy.data.materials.new("Softbox")
    m.use_nodes = True
    nodes = m.node_tree.nodes
    nodes.remove(nodes["Principled BSDF"])
    e = nodes.new("ShaderNodeEmission")
    e.inputs["Strength"].default_value = strength
    m.node_tree.links.new(e.outputs[0], nodes["Material Output"].inputs[0])
    o.data.materials.append(m)
    o.visible_camera = False
    o.visible_shadow = False


def stage(build, standing, hero=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    base_materials()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    ee = scene.eevee
    ee.use_bloom = True
    ee.bloom_intensity = 0.035
    ee.use_ssr = True
    ee.use_gtao = True
    ee.use_soft_shadows = True
    ee.taa_render_samples = 96
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 760
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Welt")
    world.use_nodes = True
    # Die Kamera sieht den dunklen Raum, die Spiegelungen ein helles Studio - sonst liest
    # poliertes Metall schwarz, und Silber wäre von Graphit nicht zu unterscheiden.
    nt = world.node_tree
    bg = nt.nodes["Background"]
    bg.inputs[0].default_value = (0.02, 0.016, 0.03, 1)
    studio = nt.nodes.new("ShaderNodeBackground")
    grad = nt.nodes.new("ShaderNodeTexGradient")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.02, 0.02, 0.025, 1)
    ramp.color_ramp.elements[1].color = (0.9, 0.9, 0.95, 1)
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
    felt = mat("Filz", (0.018, 0.011, 0.03), 0.0, 0.9)
    bpy.ops.mesh.primitive_plane_add(size=40)
    bpy.context.active_object.data.materials.append(felt)
    spacing = W + 0.6
    packs = [("material", 4, 1)] if hero else PACKS
    for i, (sort, count, quality) in enumerate(packs):
        bpy.ops.object.empty_add(location=(0, 0, 0))
        root = bpy.context.active_object
        root.name = "Paket%d" % i
        build(root, sort, count, quality)
        x = 0.0 if hero else (i - 1.5) * spacing
        if standing:
            root.rotation_euler = (math.radians(90), 0, 0)
            root.location = (x, 0, L * 0.5 + 0.01)
        else:
            root.location = (x, 0, 0.001)
    # Softboxen: sie geben dem Metall etwas zum Spiegeln.
    softbox((-3, -2, 6), (math.radians(30), math.radians(-25), 0), (6, 3), 6.0)
    softbox((4, 3, 5), (math.radians(-40), math.radians(35), 0), (5, 2), 3.0)
    softbox((0, 6, 3), (math.radians(-70), 0, 0), (10, 1.5), 4.0)
    bpy.ops.object.light_add(type="AREA", location=(0, -3, 7))
    key = bpy.context.active_object
    key.data.energy = 500
    key.data.size = 8
    bpy.ops.object.empty_add(location=(0, 0, L * 0.45 if standing else 0.1))
    aim = bpy.context.active_object
    if hero:
        bpy.ops.object.camera_add(location=(1.6, -2.3, 2.0))
    else:
        bpy.ops.object.camera_add(location=(3.2, -8.0, 7.2) if standing else (3.0, -6.4, 7.6))
    cam = bpy.context.active_object
    track = cam.constraints.new("TRACK_TO")
    track.target = aim
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"
    cam.data.lens = 42
    scene.camera = cam


def render_all(variants):
    only = sys.argv[sys.argv.index("--") + 2]         if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else ""
    for name, build in variants:
        if only and name != only:
            continue
        for view in ("liegend", "stehend", "nah"):
            stage(build, view == "stehend", view == "nah")
            bpy.context.scene.render.filepath = os.path.join(OUT, "%s_%s.png" % (name, view))
            bpy.ops.render.render(write_still=True)
    print("ok")


# Als Modul (blender_card_cassette_glass.py) liefert es nur die Werkzeuge.
if __name__ == "__main__":
    render_all(VARIANTS)
