"""Fumble: drei grundverschiedene Etikett-Layouts der Charm-Diskette (Spieler-Wunsch 2026-11-18).

Für alle gilt: nur Schieber und Bild stecken im Laufwerk (INSERT), der Text bleibt draußen
und füllt sein Feld so groß wie möglich.
  vollbild  - dunkles Gehäuse, das Charm-Bild randlos über die ganze Front, weißer Text auf
              einem Verlauf ins Schwarze; Rarität als leuchtender Rahmen
  terminal  - schwarze Glasfront wie ein Bildschirm, leuchtende Monospace-Schrift,
              Rarität als Reihe von LEDs
  farbe     - das Gehäuse selbst trägt die Raritätsfarbe, das Bild ist ein runder Aufkleber,
              der Text steht auf einem Papier-Etikett mit schwarzem Namensbalken

Aufruf (kopflos):
  blender -b -P tools/blender_floppy_layouts.py -- <ausgabe-ordner>
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led
import blender_floppy_charm as fc

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
FONTS = "C:/Windows/Fonts/"
# Die Terminal-Schrift liegt im Repo (OFL) - dieselbe, mit der Godot die Diskette beschriftet.
MONO = os.path.join(fc.REPO, "assets", "fonts", "AnonymousPro-Bold.ttf")
DW, DL, DT = fc.DW, fc.DL, fc.DT
OUTSIDE = DL * 0.5 - fc.INSERT          # alles unterhalb bleibt vor dem Schlitz
ZT = DT * 0.5
TIER = {"common": 1, "uncommon": 2, "rare": 3, "legendary": 4}
PHOENIX, FOX, ANCHOR = fc.CHARMS[0], fc.CHARMS[5], fc.CHARMS[2]


# --- Werkzeuge ----------------------------------------------------------------------------

def txt(parent, body, x, y, size, material, font, align="CENTER", width=0.0, name="Text"):
    bpy.ops.object.text_add(location=(x, y, ZT + 0.0012))
    t = bpy.context.active_object
    t.name = name
    t.data.body = body
    t.data.size = size
    t.data.font = bpy.data.fonts.load(font if os.path.isabs(font) else FONTS + font,
                                    check_existing=True)
    t.data.align_x = align
    t.data.align_y = "TOP" if width else "CENTER"
    t.data.space_line = 0.9
    if width:
        t.data.text_boxes[0].width = width
        t.data.text_boxes[0].x = -width * 0.5 if align == "CENTER" else 0.0
    t.data.extrude = 0.0002
    t.data.materials.append(material)
    t.parent = parent
    return t


def fit(parent, body, x, top, bottom, material, font, width, align="CENTER", biggest=0.1,
        name="Beschreibung"):
    """So groß, wie das Feld zwischen top und bottom und die Breite es erlauben."""
    size = biggest
    while True:
        t = txt(parent, body, x, top, size, material, font, align, width, name)
        bpy.context.view_layer.update()
        pts = [t.matrix_world @ Vector(c) for c in t.bound_box]
        left = x - width * 0.5 if align == "CENTER" else x
        if (min(p.y for p in pts) >= bottom and min(p.x for p in pts) >= left - 0.005
                and max(p.x for p in pts) <= left + width + 0.005) or size < 0.025:
            return t
        bpy.data.objects.remove(t)
        size *= 0.95


def fit_line(parent, body, x, y, material, font, width, align="CENTER", biggest=0.09, name="Name"):
    """Eine Zeile, so groß wie die Breite erlaubt."""
    size = biggest
    while True:
        t = txt(parent, body, x, y, size, material, font, align, 0.0, name)
        bpy.context.view_layer.update()
        if t.dimensions.x <= width or size < 0.025:
            return t
        bpy.data.objects.remove(t)
        size *= 0.95


def plane(parent, name, x0, y0, x1, y1, material, lift=0.0009):
    bpy.ops.mesh.primitive_plane_add(size=1, location=((x0 + x1) * 0.5, (y0 + y1) * 0.5, ZT + lift))
    o = bpy.context.active_object
    o.name = name
    o.scale = (x1 - x0, y1 - y0, 1)
    o.data.materials.append(material)
    o.parent = parent
    return o


def render_art(cid, aspect, fill, center_v, tag):
    """Charm-Render mit Alpha: fill = Anteil der Bildhöhe, center_v = Höhe der Mitte (0..1)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 64
    scene.eevee.use_gtao = True
    scene.render.film_transparent = True
    scene.render.resolution_x = 1024 if aspect >= 1 else int(1024 * aspect)
    scene.render.resolution_y = int(1024 / aspect) if aspect >= 1 else 1024
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Welt")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.33, 0.4, 1)
    scene.world = world
    holder, _ = fc.import_charm(cid, 1.0)
    holder.rotation_euler = (0, 0, math.radians(-20))
    for loc, rot, e, col in (((-1.5, -2, 2.5), (45, 0, -35), 220, (1, 1, 1)),
                             ((1.8, 1.5, 1.2), (-60, 0, 130), 160, (0.75, 0.6, 1.0))):
        bpy.ops.object.light_add(type="AREA", location=loc)
        l = bpy.context.active_object
        l.data.energy = e
        l.data.size = 2
        l.data.color = col
        l.rotation_euler = tuple(math.radians(a) for a in rot)
    frame_h = 1.0 / fill
    aim = fc.empty("Ziel", (0, 0, -(center_v - 0.5) * frame_h))
    bpy.ops.object.camera_add(location=(0, -4.2, 1.6 + aim.location.z))
    cam = bpy.context.active_object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = frame_h * max(aspect, 1.0)
    c = cam.constraints.new("TRACK_TO")
    c.target = aim
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"
    scene.camera = cam
    path = os.path.join(OUT, "bild_%s_%s.png" % (tag, cid))
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def art_mat(name, path, inner, outer, fade=None, circle=False, emit=0.0):
    """Bild über einem runden Verlauf; fade=(unten, oben) dunkelt den Fuß ab, circle schneidet rund."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nodes, link = nt.nodes, nt.links.new
    p = nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.4
    tc = nodes.new("ShaderNodeTexCoord")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path)
    tex.extension = "CLIP"
    mp = nodes.new("ShaderNodeMapping")
    mp.vector_type = "TEXTURE"
    mp.inputs["Location"].default_value = (0.5, 0.5, 0)
    mp.inputs["Scale"].default_value = (0.6, 0.6, 1)
    link(tc.outputs["UV"], mp.inputs[0])
    grad = nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    link(mp.outputs[0], grad.inputs[0])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*outer, 1)
    ramp.color_ramp.elements[1].color = (*inner, 1)
    link(grad.outputs[1], ramp.inputs[0])
    mix = nodes.new("ShaderNodeMixRGB")
    link(tex.outputs["Alpha"], mix.inputs[0])
    link(ramp.outputs[0], mix.inputs[1])
    link(tex.outputs[0], mix.inputs[2])
    col = mix.outputs[0]
    if fade:
        sep = nodes.new("ShaderNodeSeparateXYZ")
        link(tc.outputs["UV"], sep.inputs[0])
        mr = nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = fade[0]
        mr.inputs["From Max"].default_value = fade[1]
        mr.inputs["To Min"].default_value = 0.96
        mr.inputs["To Max"].default_value = 0.0
        link(sep.outputs[1], mr.inputs[0])
        dark = nodes.new("ShaderNodeMixRGB")
        dark.inputs[2].default_value = (0.004, 0.003, 0.008, 1)
        link(mr.outputs[0], dark.inputs[0])
        link(col, dark.inputs[1])
        col = dark.outputs[0]
    link(col, p.inputs["Base Color"])
    if emit:
        link(col, p.inputs["Emission"])
        p.inputs["Emission Strength"].default_value = emit
    if circle:
        d = nodes.new("ShaderNodeVectorMath")
        d.operation = "DISTANCE"
        d.inputs[1].default_value = (0.5, 0.5, 0)
        link(tc.outputs["UV"], d.inputs[0])
        lt = nodes.new("ShaderNodeMath")
        lt.operation = "LESS_THAN"
        lt.inputs[1].default_value = 0.5
        link(d.outputs["Value"], lt.inputs[0])
        link(lt.outputs[0], p.inputs["Alpha"])
        m.blend_method = "CLIP"
        m.shadow_method = "CLIP"
    return m


def shell(parent, body_mat, shutter_mat):
    """Gehäuse, Schieber, Fenster, Löcher - für alle drei gleich."""
    body = led.rounded_box(parent, "Gehaeuse", (DW, DL, DT), (0, 0, 0), body_mat, 0.012, 0.003, 6)
    bpy.ops.mesh.primitive_cube_add(size=0.07, location=(DW * 0.5, DL * 0.5, 0),
                                    rotation=(0, 0, math.radians(45)))
    corner = bpy.context.active_object
    corner.parent = parent
    led.cut(body, corner)
    led.rounded_box(parent, "Schieber", (0.4, 0.3, DT + 0.007), (-0.03, DL * 0.5 - 0.15, 0),
                    shutter_mat, 0.006, 0.0015, 4)
    fc.box(parent, "Fenster", (0.11, 0.2, DT + 0.0075), (0.04, DL * 0.5 - 0.145, 0),
           led.mat("Scheibe", (0.03, 0.022, 0.018), 0.2, 0.35))
    for sx in (-1, 1):
        fc.box(parent, "Loch%d" % sx, (0.03, 0.03, DT + 0.001), (sx * 0.418, -DL * 0.5 + 0.04, 0),
               led.mat("Loch", (0.004, 0.004, 0.006), 0.0, 0.5))
    fc.cyl(parent, "Nabe", 0.1, 0.003, (0, 0.03, -ZT - 0.0005), shutter_mat)


def emissive(name, color, strength):
    return led.mat(name, color, 0.0, 0.4, strength)


# --- A: VOLLBILD --------------------------------------------------------------------------

def vollbild(parent, charm, art):
    cid, name, desc, rarity = charm
    rname, rcol = fc.RARITY[rarity]
    rc = fc.srgb(rcol)
    shell(parent, led.mat("Graphit", (0.03, 0.03, 0.035), 0.3, 0.45, clearcoat=0.5),
          led.mat("Alu", (0.8, 0.81, 0.83), 1.0, 0.3))
    x0, x1, y0, y1 = -0.4, 0.4, -DL * 0.5 + 0.02, DL * 0.5 - 0.31
    fade_hi = (OUTSIDE - 0.01 - y0) / (y1 - y0)
    plane(parent, "Vollbild", x0, y0, x1, y1,
          art_mat("Vollbild_" + cid, art, [c * 0.45 for c in rc], (0.01, 0.008, 0.02),
                  fade=(fade_hi - 0.12, fade_hi + 0.04)))
    glow = emissive("Rahmen_" + rarity, rc, 3.0)
    t = 0.008
    for (a, b, c, d) in ((x0 - t, y1, x1 + t, y1 + t), (x0 - t, y0 - t, x1 + t, y0),
                         (x0 - t, y0, x0, y1), (x1, y0, x1 + t, y1)):
        plane(parent, "Rahmen", a, b, c, d, glow, 0.0011)
    white = emissive("Weiss", (0.95, 0.95, 0.97), 0.15)
    ny = OUTSIDE - 0.055
    fit_line(parent, name.upper(), 0, ny, white, "seguibl.ttf", 0.72, biggest=0.085)
    fit(parent, desc, 0, ny - 0.055, y0 + 0.055, white, "seguisb.ttf", 0.72, biggest=0.09)
    txt(parent, rname, 0, y0 + 0.028, 0.03, glow, "segoeuib.ttf", name="Raritaet")


# --- B: TERMINAL --------------------------------------------------------------------------

def terminal(parent, charm, art):
    cid, name, desc, rarity = charm
    rname, rcol = fc.RARITY[rarity]
    rc = fc.srgb(rcol)
    shell(parent, led.mat("Schwarzlack", (0.008, 0.008, 0.011), 0.0, 0.12, clearcoat=1.0),
          led.mat("Schwarzchrom", (0.12, 0.12, 0.14), 1.0, 0.18))
    x0, x1, y0, y1 = -0.405, 0.405, -DL * 0.5 + 0.015, DL * 0.5 - 0.32
    led.rounded_box(parent, "Glasfront", (x1 - x0, y1 - y0, 0.003), (0, (y0 + y1) * 0.5, ZT + 0.0012),
                    led.mat("Glasfront", (0.004, 0.009, 0.012), 0.0, 0.35, 1.2, clearcoat=0.25), 0.015,
                    0.0008, 4)
    zt_glass = 0.0029
    screen = (0.55, 0.95, 1.0)
    cyan = emissive("Bildschirm", screen, 1.6)
    dim = emissive("BildschirmDunkel", [c * 0.35 for c in screen], 1.0)
    name_mat = emissive("Name_" + rarity, rc, 3.0)
    # Drinnen: das Symbol und eine Kopfzeile wie ein Ladebildschirm.
    plane(parent, "Symbol", -0.37, OUTSIDE + 0.02, -0.15, y1 - 0.02,
          art_mat("Symbol_" + cid, art, [c * 0.3 for c in rc], (0.0, 0.0, 0.0), emit=0.6), zt_glass)
    txt(parent, "LOAD  %s.DSK" % cid.upper()[:10], -0.12, y1 - 0.06, 0.032, dim, MONO,
        "LEFT", name="Kopf").location.z = ZT + zt_glass
    plane(parent, "Ladebahn", -0.12, y1 - 0.122, 0.36, y1 - 0.108, dim, zt_glass)
    plane(parent, "Ladestand", -0.12, y1 - 0.122, 0.26, y1 - 0.108, cyan, zt_glass + 0.0002)
    # Ein dünner Rahmen in der Raritätsfarbe - auch aus der Ferne die Stufe.
    t = 0.006
    for (a, b, c, e) in ((x0 + 0.012, y1 - 0.012 - t, x1 - 0.012, y1 - 0.012),
                         (x0 + 0.012, y0 + 0.012, x1 - 0.012, y0 + 0.012 + t),
                         (x0 + 0.012, y0 + 0.012, x0 + 0.012 + t, y1 - 0.012),
                         (x1 - 0.012 - t, y0 + 0.012, x1 - 0.012, y1 - 0.012)):
        plane(parent, "Rahmen", a, b, c, e, name_mat, zt_glass)
    # Draußen: Name in der Raritätsfarbe, Text in Bildschirm-Cyan.
    left = x0 + 0.04
    ny = OUTSIDE - 0.055
    n = fit_line(parent, "> " + name.upper(), left, ny, name_mat, MONO, 0.73, "LEFT", 0.09)
    n.location.z = ZT + zt_glass
    d = fit(parent, desc, left, ny - 0.058, y0 + 0.07, cyan, MONO, 0.73, "LEFT", 0.085)
    d.location.z = ZT + zt_glass
    # Rarität: vier LEDs, so viele leuchten wie die Stufe.
    off = led.mat("LedAus", (0.02, 0.02, 0.025), 0.0, 0.15, clearcoat=1.0)
    for k in range(4):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.014, location=(x1 - 0.045 - (3 - k) * 0.042,
                                                                     y0 + 0.04, ZT + zt_glass))
        o = bpy.context.active_object
        o.scale = (1, 1, 0.4)
        o.data.materials.append(name_mat if k < TIER[rarity] else off)
        o.parent = parent
    r = txt(parent, rname, left, y0 + 0.04, 0.03, dim, MONO, "LEFT", name="Raritaet")
    r.location.z = ZT + zt_glass


# --- C: FARBE -----------------------------------------------------------------------------

def farbe(parent, charm, art):
    cid, name, desc, rarity = charm
    rname, rcol = fc.RARITY[rarity]
    rc = fc.srgb(rcol)
    shell(parent, led.mat("Farbkunststoff_" + rarity, [c * 0.75 for c in rc], 0.0, 0.22,
                          clearcoat=1.0),
          led.mat("Alu", (0.8, 0.81, 0.83), 1.0, 0.3))
    # Drinnen: das Bild als runder Aufkleber unter dem Schieber.
    r = 0.115
    cy = DL * 0.5 - 0.31 - r - 0.005
    fc.cyl(parent, "Aufkleberrand", r + 0.012, 0.0008, (0, cy, ZT + 0.0004),
           led.mat("Papier", (0.85, 0.85, 0.83), 0.0, 0.8))
    plane(parent, "Aufkleber", -r, cy - r, r, cy + r,
          art_mat("Rund_" + cid, art, [c * 0.45 for c in rc], (0.01, 0.008, 0.02), circle=True))
    # Draußen: Papier-Etikett mit schwarzem Namensbalken.
    x0, x1, y0, y1 = -0.395, 0.395, -DL * 0.5 + 0.012, OUTSIDE - 0.008
    led.rounded_box(parent, "Etikett", (x1 - x0, y1 - y0, 0.0008), (0, (y0 + y1) * 0.5, ZT + 0.0004),
                    led.mat("Papier", (0.85, 0.85, 0.83), 0.0, 0.8), 0.01, 0.0, 4)
    bar = 0.095
    plane(parent, "Namensbalken", x0, y1 - bar, x1, y1, led.mat("Balken", (0.006, 0.006, 0.008), 0.0, 0.6))
    fit_line(parent, name.upper(), 0, y1 - bar * 0.5, led.mat("Weiss", (0.95, 0.95, 0.95), 0.0, 0.5, 0.2),
             "impact.ttf", 0.74, biggest=0.08)
    fit(parent, desc, 0, y1 - bar - 0.02, y0 + 0.018,
        led.mat("Tinte", (0.002, 0.002, 0.004), 0.0, 0.95), "verdanab.ttf", 0.74, biggest=0.09)


LAYOUTS = [("A_vollbild", vollbild, (1.31, 0.42, 0.74)),
           ("B_terminal", terminal, (1.0, 0.82, 0.5)),
           ("C_farbe", farbe, (1.0, 0.78, 0.5))]


def main():
    arts = {}
    for tag, _, (aspect, fill, center) in LAYOUTS:
        for charm in (PHOENIX, FOX, ANCHOR):
            arts[(tag, charm[0])] = render_art(charm[0], aspect, fill, center, tag)

    for tag, build, _ in LAYOUTS:
        # Draufsicht zum Lesen.
        fc.stage((1200, 1200))
        root = fc.empty("Diskette")
        build(root, PHOENIX, arts[(tag, PHOENIX[0])])
        root.location = (0, 0, ZT + 0.001)
        fc.camera((0, -0.25, 2.1), (0, -0.02, 0), 60)
        fc.shoot("%s_1_draufsicht" % tag, True)
        # Eingelegt, mit Hologramm.
        fc.stage()
        fc.reader(fc.empty("Laufwerk"), ANCHOR[3], ANCHOR)
        root = fc.empty("Diskette")
        build(root, ANCHOR, arts[(tag, ANCHOR[0])])
        root.location = (0, fc.LOADED_Y, fc.SLOT_Z)
        fc.camera((1.7, -3.3, 2.0), (0, -0.25, 0.55), 45)
        fc.shoot("%s_2_eingelegt" % tag)

    # Vergleich aus Spielferne: je Layout ein langer und ein kurzer Text.
    fc.stage((2200, 1000))
    pitch = fc.RW + 0.2
    i = 0
    for tag, build, _ in LAYOUTS:
        for charm in (PHOENIX, FOX):
            x = (i - 2.5) * pitch + (i // 2 - 1) * 0.35
            fc.reader(fc.empty("Laufwerk%d" % i), charm[3], charm).location = (x, 0, 0)
            root = fc.empty("Diskette%d" % i)
            build(root, charm, arts[(tag, charm[0])])
            root.location = (x, fc.LOADED_Y, fc.SLOT_Z)
            i += 1
    for o in bpy.data.objects:
        if o.type == "MESH" and o.data.materials and o.data.materials[0].name.startswith("Softbox"):
            o.hide_render = True
    fc.camera((0, -4.6, 9.0), (0, -0.4, 0.3), 36)
    fc.shoot("vergleich_spielferne")
    print("ok")


def final():
    """Das gewählte Terminal-Layout: vier Raritäten, eingelegt, die Reihe aus Spielferne."""
    tag = "B_terminal"
    picks = [fc.CHARMS[0], fc.CHARMS[2], fc.CHARMS[3], fc.CHARMS[5]]
    arts = {c[0]: render_art(c[0], 1.0, 0.82, 0.5, tag) for c in fc.CHARMS}
    fc.stage((1800, 1800))
    for i, charm in enumerate(picks):
        root = fc.empty("Diskette%d" % i)
        terminal(root, charm, arts[charm[0]])
        root.location = ((i % 2 - 0.5) * (DW + 0.12), (0.5 - i // 2) * (DL + 0.12), ZT + 0.001)
    fc.camera((0, -0.35, 3.6), (0, -0.03, 0), 50)
    fc.shoot("final_1_raritaeten", True)
    fc.stage()
    fc.reader(fc.empty("Laufwerk"), PHOENIX[3], PHOENIX)
    root = fc.empty("Diskette")
    terminal(root, PHOENIX, arts[PHOENIX[0]])
    root.location = (0, fc.LOADED_Y, fc.SLOT_Z)
    fc.camera((1.7, -3.3, 2.0), (0, -0.25, 0.55), 45)
    fc.shoot("final_2_eingelegt", True)
    fc.stage((2200, 1000))
    pitch = fc.RW + 0.25
    for i, charm in enumerate(fc.CHARMS):
        x = (i - 2.5) * pitch
        fc.reader(fc.empty("Laufwerk%d" % i), charm[3], charm).location = (x, 0, 0)
        root = fc.empty("Diskette%d" % i)
        terminal(root, charm, arts[charm[0]])
        root.location = (x, fc.LOADED_Y, fc.SLOT_Z)
    for o in bpy.data.objects:
        if o.type == "MESH" and o.data.materials and o.data.materials[0].name.startswith("Softbox"):
            o.hide_render = True
    fc.camera((0, -4.6, 9.0), (0, -0.4, 0.3), 36)
    fc.shoot("final_3_spielferne")
    print("ok")


if __name__ == "__main__":
    final() if "final" in sys.argv else main()
