"""Fumble: drei ENTWÜRFE der Karten-Kassette mit Sichtfenster (Spieler-Wunsch 2026-11-15).

Das Fenster zeigt die erste Karte des Pakets: ihre Sortenfarbe, das Netzfeld bleibt leer.
Die Kartenzahl liest sich ohne Ziffer:
  1 kantenschlitz - ein Schlitz an Langseite und Rücken zeigt die gestapelten Kartenkanten
  2 led_leiste    - fünf LED-Plätze unter dem Fenster und auf dem Rücken, so viele leuchten
  3 schuber       - ein offener Schuber, die Kartenköpfe ragen gestaffelt heraus

Aufruf (kopflos):
  blender -b -P tools/blender_card_cassette_concepts.py -- <ausgabe-ordner>
Rendert je Entwurf eine liegende und eine stehende Ansicht nach <ausgabe-ordner>.
Blender-Achsen wie die Schatulle: X = Breite, Y = Länge (Kopf +Y), Z = Höhe, Ursprung =
Mitte der Unterseite.
"""
import bpy, math, sys, os

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(OUT, exist_ok=True)

W = 1.08 * 1.04
L = 1.62 * 1.04
H = 0.1512 * 2.35


def lin(hex_color):
    h = hex_color.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4))


SORTS = {"zahl": lin("#50fa7b"), "material": lin("#ff79c6"), "rune": lin("#ffd319")}
MIX = ["zahl", "material", "rune"]
QUALITY = [  # Farbe, Metall, Rauheit, Eigenlicht
    (lin("#525256"), 0.3, 0.45, 0.25),
    (lin("#e6e6eb"), 0.45, 0.25, 0.25),
    (lin("#f5c466"), 0.45, 0.3, 0.3),
]
PACKS = [("zahl", 3, 0), ("material", 4, 1), ("rune", 5, 2), ("misch", 4, 0)]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


_mats = {}


def mat(name, color, metal=0.0, rough=0.5, emit=0.0, alpha=1.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if emit > 0.0:
        p.inputs["Emission"].default_value = (*color, 1)
        p.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
        m.shadow_method = "NONE"
    _mats[name] = m
    return m


def box(parent, name, size, loc, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    if bevel > 0.0:
        mod = o.modifiers.new("Fase", "BEVEL")
        mod.width = bevel
        mod.segments = 4
        bpy.ops.object.shade_smooth()
        o.data.use_auto_smooth = True
        o.data.auto_smooth_angle = math.radians(40)
    o.parent = parent
    return o


def cyl(parent, name, radius, depth, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=radius, depth=depth,
                                        location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    o.parent = parent
    return o


def metal(quality):
    color, m, r, e = QUALITY[quality]
    return mat("Metall%d" % quality, color, m, r, e)


def sort_mat(sort, emit=1.2):
    return mat("Sorte_%s_%.1f" % (sort, emit), SORTS[sort], 0.0, 0.35, emit)


DARK = None
GLASS = None
STEEL = None
LED_OFF = None
LED_ON = None


def materials():
    global DARK, GLASS, STEEL, LED_OFF, LED_ON
    DARK = mat("Dunkel", (0.01, 0.01, 0.012), 0.0, 0.6)
    GLASS = mat("Glas", (0.7, 0.75, 0.8), 0.0, 0.05, 0.0, 0.12)
    STEEL = mat("Stahl", lin("#8a8e98"), 0.6, 0.3, 0.15)
    LED_OFF = mat("LedAus", (0.03, 0.03, 0.035), 0.0, 0.4)
    LED_ON = mat("LedAn", (1.0, 0.95, 0.85), 0.0, 0.3, 4.0)


def card_face(parent, sort, size, center, z):
    """Die erste Karte im Fenster: getönt in ihrer Sorte, das Netzfeld LEER (dunkel)."""
    cw, cl = size
    if sort == "misch":
        stripe = cw / 3.0
        for i, s in enumerate(MIX):
            box(parent, "Karte%d" % i, (stripe, cl, 0.006),
                (center[0] - cw * 0.5 + stripe * (i + 0.5), center[1], z), sort_mat(s, 0.9))
    else:
        box(parent, "Karte", (cw, cl, 0.006), (center[0], center[1], z), sort_mat(sort, 0.9))
    net_cross(parent, min(cw / 4.6, cl / 3.6), (center[0], center[1]), z + 0.004)


def net_cross(parent, cell, center, z):
    """Das Netz der Karte - LEER: sechs dunkle Zellen im Kreuz, ohne Inhalt."""
    for i, (cx, cy) in enumerate([(-1.5, 0), (-0.5, 0), (0.5, 0), (1.5, 0), (-0.5, 1), (-0.5, -1)]):
        box(parent, "Netzzelle%d" % i, (cell * 0.86, cell * 0.86, 0.004),
            (center[0] + cx * cell, center[1] + cy * cell, z), DARK, 0.004)


def window(parent, sort, size, center, frame, frame_mat, frame_h=0.012):
    wx, wy = size
    card_face(parent, sort, (wx, wy), center, H + 0.002)
    cx, cy = center
    for name, s, loc in [
            ("RahmenL", (frame, wy + frame * 2, frame_h), (cx - (wx + frame) * 0.5, cy)),
            ("RahmenR", (frame, wy + frame * 2, frame_h), (cx + (wx + frame) * 0.5, cy)),
            ("RahmenO", (wx, frame, frame_h), (cx, cy + (wy + frame) * 0.5)),
            ("RahmenU", (wx, frame, frame_h), (cx, cy - (wy + frame) * 0.5))]:
        box(parent, name, s, (loc[0], loc[1], H + frame_h * 0.5), frame_mat)
    box(parent, "Scheibe", (wx, wy, 0.003), (cx, cy, H + frame_h - 0.002), GLASS)


def shell(parent, quality, length=L, y0=0.0):
    box(parent, "Gehaeuse", (W, length, H), (0, y0, H * 0.5), metal(quality), 0.03)


def seam(parent, sort, length=L, y0=0.0):
    tint = "material" if sort == "misch" else sort
    box(parent, "Naht", (W + 0.012, length + 0.012 if y0 == 0.0 else length, H * 0.06),
        (0, y0, H * 0.42), sort_mat(tint, 1.6) if sort != "misch" else mat("NahtMisch",
        lin("#c9d2e6"), 0.0, 0.4, 1.2))


def kantenschlitz(parent, sort, count, quality):
    shell(parent, quality)
    window(parent, sort, (W * 0.74, L * 0.62), (0, L * 0.06), 0.035, DARK)
    seam(parent, sort)
    edge = sort_mat("material" if sort == "misch" else sort, 2.0)
    pitch = H * 0.13
    span = pitch * (count - 1)
    # Langseite +X: ein Schlitz über die Länge, darin die Kartenkanten übereinander.
    box(parent, "SchlitzSeite", (0.02, L * 0.7, H * 0.72), (W * 0.5 - 0.004, 0, H * 0.5), DARK)
    box(parent, "SchlitzKopf", (W * 0.7, 0.02, H * 0.72), (0, L * 0.5 - 0.004, H * 0.5), DARK)
    for i in range(count):
        z = H * 0.5 - span * 0.5 + pitch * i
        tint = sort_mat(MIX[i % 3], 2.0) if sort == "misch" else edge
        box(parent, "KanteSeite%d" % i, (0.022, L * 0.66, H * 0.05), (W * 0.5 - 0.002, 0, z), tint)
        box(parent, "KanteKopf%d" % i, (W * 0.66, 0.022, H * 0.05), (0, L * 0.5 - 0.002, z), tint)


def led_leiste(parent, sort, count, quality):
    shell(parent, quality)
    window(parent, sort, (W * 0.7, L * 0.56), (0, L * 0.12), 0.05, STEEL, 0.02)
    seam(parent, sort)
    radius = W * 0.045
    step = W * 0.14
    for i in range(5):
        x = (i - 2) * step
        lit = LED_ON if i < count else LED_OFF
        box(parent, "LedSockel%d" % i, (radius * 2.6, radius * 2.6, 0.01),
            (x, -L * 0.34, H + 0.005), DARK, 0.004)
        cyl(parent, "Led%d" % i, radius, 0.016, (x, -L * 0.34, H + 0.012), lit)
        # Dieselben fünf Plätze auf dem Rücken (Kopf +Y).
        cyl(parent, "LedKopf%d" % i, radius * 0.9, 0.016, (x, L * 0.5 + 0.004, H * 0.5), lit,
            (math.radians(90), 0, 0))


def schuber(parent, sort, count, quality):
    sleeve = L * 0.84
    y0 = -L * 0.5 + sleeve * 0.5
    wall = 0.035
    m = metal(quality)
    # Der Schuber: Boden, Deckel mit Fensterausschnitt, zwei Wangen, oben offen.
    box(parent, "Boden", (W, sleeve, wall), (0, y0, wall * 0.5), m, 0.015)
    box(parent, "WangeL", (wall, sleeve, H), (-W * 0.5 + wall * 0.5, y0, H * 0.5), m, 0.015)
    box(parent, "WangeR", (wall, sleeve, H), (W * 0.5 - wall * 0.5, y0, H * 0.5), m, 0.015)
    win = (W * 0.7, sleeve * 0.6)
    win_y = y0 + sleeve * 0.08
    lid_z = H - wall * 0.5
    box(parent, "DeckelL", ((W - win[0]) * 0.5, sleeve, wall),
        (-(W + win[0]) * 0.25, y0, lid_z), m, 0.01)
    box(parent, "DeckelR", ((W - win[0]) * 0.5, sleeve, wall),
        ((W + win[0]) * 0.25, y0, lid_z), m, 0.01)
    box(parent, "DeckelO", (win[0], y0 + sleeve * 0.5 - (win_y + win[1] * 0.5), wall),
        (0, (y0 + sleeve * 0.5 + win_y + win[1] * 0.5) * 0.5, lid_z), m)
    box(parent, "DeckelU", (win[0], (win_y - win[1] * 0.5) - (y0 - sleeve * 0.5), wall),
        (0, (win_y - win[1] * 0.5 + y0 - sleeve * 0.5) * 0.5, lid_z), m)
    box(parent, "Naht", (W + 0.01, sleeve, H * 0.06), (0, y0, H * 0.42),
        sort_mat("material" if sort == "misch" else sort, 1.6))
    # Die Karten: gestapelt, jede ragt eine Stufe weiter aus dem Kopf.
    inner = H - wall * 2
    card_t = inner / 6.0
    for i in range(count):
        s = MIX[i % 3] if sort == "misch" else sort
        z = wall + inner - card_t * (i + 0.5) - 0.004
        poke = L * (0.05 + 0.035 * (count - 1 - i))
        card_len = L * 0.9
        cy = -L * 0.5 + 0.03 + card_len * 0.5 + poke
        box(parent, "Karte%d" % i, (W - wall * 2.4, card_len, card_t * 0.8), (0, cy, z),
            sort_mat(s, 0.7), 0.004)
    # Die oberste Karte zeigt im Fenster ihr leeres Netz.
    net_cross(parent, min(win[0] / 4.6, win[1] / 3.6), (0, win_y),
              wall + inner - card_t * 0.1 - 0.002)


VARIANTS = [("kantenschlitz", kantenschlitz), ("led_leiste", led_leiste),
            ("schuber", schuber)]


def stage(build, standing):
    reset()
    materials()
    _mats.clear()
    materials()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.use_bloom = True
    scene.eevee.bloom_intensity = 0.04
    scene.eevee.taa_render_samples = 64
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 760
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Welt")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.009, 0.02, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world
    felt = mat("Filz", (0.02, 0.012, 0.035), 0.0, 0.9)
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    bpy.context.active_object.data.materials.append(felt)
    spacing = W + 0.55
    for i, (sort, count, quality) in enumerate(PACKS):
        bpy.ops.object.empty_add(location=(0, 0, 0))
        root = bpy.context.active_object
        root.name = "Paket%d" % i
        build(root, sort, count, quality)
        x = (i - 1.5) * spacing
        if standing:
            root.rotation_euler = (math.radians(90), 0, 0)
            root.location = (x, 0, L * 0.5 + 0.01)
        else:
            root.location = (x, 0, 0.001)
    bpy.ops.object.light_add(type="AREA", location=(0, -3, 7))
    key = bpy.context.active_object
    key.data.energy = 900
    key.data.size = 8
    key.rotation_euler = (math.radians(20), 0, 0)
    bpy.ops.object.light_add(type="AREA", location=(5, 4, 4))
    fill = bpy.context.active_object
    fill.data.energy = 250
    fill.data.size = 5
    fill.rotation_euler = (math.radians(-45), math.radians(45), 0)
    bpy.ops.object.empty_add(location=(0, 0, L * 0.45 if standing else 0.1))
    aim = bpy.context.active_object
    if standing:
        bpy.ops.object.camera_add(location=(3.2, -8.0, 7.2))
    else:
        bpy.ops.object.camera_add(location=(3.0, -6.4, 7.6))
    cam = bpy.context.active_object
    track = cam.constraints.new("TRACK_TO")
    track.target = aim
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"
    cam.data.lens = 42
    scene.camera = cam


for name, build in VARIANTS:
    for standing in (False, True):
        stage(build, standing)
        bpy.context.scene.render.filepath = os.path.join(
            OUT, "%s_%s.png" % (name, "stehend" if standing else "liegend"))
        bpy.ops.render.render(write_still=True)
print("ok")
