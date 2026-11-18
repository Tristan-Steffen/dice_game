"""Fumble: Entwurf der Charm-DISKETTE und des LAUFWERKS (Spieler-Wunsch 2026-11-18).

Die Diskette: 3,5"-Format, Schieber oben, Etikett unten - oben auf dem Etikett das Bild des
Charms (gerendert aus seinem .glb), darunter Name, Beschreibung und der Raritäts-Streifen.
Das Laufwerk: Einschub vorn, oben ein Projektor, der den Charm als Hologramm zeigt; der
Neon-Saum leuchtet in der Rarität der eingelegten Diskette.

Aufruf (kopflos):
  blender -b -P tools/blender_floppy_charm.py -- <ausgabe-ordner>
Achsen: X = Breite, Y = Länge (Schieber/Einschub +Y), Z = Höhe.
"""
import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import blender_card_cassette_led as led

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.makedirs(OUT, exist_ok=True)

RARITY = {
    "common": ("GEWÖHNLICH", (0.85, 0.9, 1.0)),
    "uncommon": ("UNGEWÖHNLICH", (0.3, 1.0, 0.5)),
    "rare": ("SELTEN", (0.25, 0.55, 1.0)),
    "legendary": ("LEGENDÄR", (0.75, 0.35, 1.0)),
}
CHARMS = [
    ("phoenix_feather", "Phönixfeder", "Erster Fumble der Runde: die Hand geht unter den "
     "Nachziehstapel statt in die Ablage.", "legendary"),
    ("four_leaf_clover", "Vierblättriges Kleeblatt", "Jede 4: +1 Auslösung.", "common"),
    ("anchor", "Anker", "Erster Neuwurf jeder Hand kann nicht fumblen.", "rare"),
    ("piggy_bank", "Sparschwein", "Übrige Würfel zahlen $1 mehr.", "uncommon"),
    ("grandfather_clock", "Standuhr", "Fumble: Rundenpunkte verdoppeln sich.", "rare"),
    ("fox_tail", "Fuchsschwanz", "Jede 3 zählt als 4.", "common"),
]
HOLO = (0.25, 0.9, 1.0)

DW, DL, DT = 0.9, 0.94, 0.033          # Diskette
RW, RL, RH = 1.12, 0.8, 0.30            # Laufwerk
INSERT = 0.56                           # so tief steckt sie: Schieber und Bild, nie der Text
LOADED_Y = -RL * 0.5 + INSERT - DL * 0.5
SLOT_Z = 0.17
BANNER = (0.74, 0.2)                    # Bildfeld auf dem Etikett
BOLD_FONT = "C:/Windows/Fonts/segoeuib.ttf"
BODY_FONT = "C:/Windows/Fonts/seguisb.ttf"


def srgb(c):
    return tuple(x ** 2.2 for x in c)


# --- Werkzeuge ----------------------------------------------------------------------------

def import_charm(cid, size):
    """Lädt das Charm-Modell, mittig auf den Ursprung, größte Ausdehnung = size."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(REPO, "assets", "models", cid + ".glb"))
    objs = [o for o in bpy.data.objects if o not in before]
    lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    bpy.context.view_layer.update()
    for o in objs:
        if o.type == "MESH":
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
    root = bpy.data.objects.new("Charm_" + cid, None)
    bpy.context.collection.objects.link(root)
    for o in objs:
        if o.parent is None:
            o.parent = root
    s = size / max(hi - lo)
    root.scale = (s, s, s)
    root.location = -(lo + hi) * 0.5 * s
    holder = bpy.data.objects.new("Halter_" + cid, None)
    bpy.context.collection.objects.link(holder)
    root.parent = holder
    return holder, [o for o in objs if o.type == "MESH"]


def charm_image(mesh_objs):
    for o in mesh_objs:
        for slot in o.material_slots:
            if slot.material and slot.material.use_nodes:
                for n in slot.material.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image:
                        return n.image
    return None


def holo_material(image):
    m = bpy.data.materials.new("Hologramm")
    m.use_nodes = True
    m.blend_method = "BLEND"
    m.shadow_method = "NONE"
    m.show_transparent_back = False
    nt = m.node_tree
    nodes, link = nt.nodes, nt.links.new
    nodes.remove(nodes["Principled BSDF"])
    out = nodes["Material Output"]
    col = nodes.new("ShaderNodeMixRGB")
    col.inputs[0].default_value = 0.45
    col.inputs[2].default_value = (*HOLO, 1)
    if image:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        link(tex.outputs[0], col.inputs[1])
    else:
        col.inputs[1].default_value = (*HOLO, 1)
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Strength"].default_value = 2.2
    link(col.outputs[0], emit.inputs[0])
    lw = nodes.new("ShaderNodeLayerWeight")
    lw.inputs[0].default_value = 0.35
    # Deckkraft: Kern halb, Ränder voll; Scanlinien in Welt-Z.
    core = nodes.new("ShaderNodeMath")
    core.operation = "MULTIPLY_ADD"
    link(lw.outputs["Facing"], core.inputs[0])
    core.inputs[1].default_value = 0.5
    core.inputs[2].default_value = 0.45
    geo = nodes.new("ShaderNodeNewGeometry")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    link(geo.outputs["Position"], sep.inputs[0])
    freq = nodes.new("ShaderNodeMath")
    freq.operation = "MULTIPLY"
    freq.inputs[1].default_value = 260.0
    link(sep.outputs[2], freq.inputs[0])
    sine = nodes.new("ShaderNodeMath")
    sine.operation = "SINE"
    link(freq.outputs[0], sine.inputs[0])
    scan = nodes.new("ShaderNodeMapRange")
    scan.inputs["From Min"].default_value = -1
    scan.inputs["To Min"].default_value = 0.55
    link(sine.outputs[0], scan.inputs[0])
    alpha = nodes.new("ShaderNodeMath")
    alpha.operation = "MULTIPLY"
    alpha.use_clamp = True
    link(core.outputs[0], alpha.inputs[0])
    link(scan.outputs[0], alpha.inputs[1])
    tr = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    link(alpha.outputs[0], mix.inputs[0])
    link(tr.outputs[0], mix.inputs[1])
    link(emit.outputs[0], mix.inputs[2])
    link(mix.outputs[0], out.inputs[0])
    return m


def beam_material():
    """Additiver Lichtkegel, nach oben ausgeblendet."""
    m = bpy.data.materials.new("Lichtkegel")
    m.use_nodes = True
    m.blend_method = "BLEND"
    m.shadow_method = "NONE"
    m.use_backface_culling = False
    nt = m.node_tree
    nodes, link = nt.nodes, nt.links.new
    nodes.remove(nodes["Principled BSDF"])
    tc = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    link(tc.outputs["Generated"], sep.inputs[0])
    fade = nodes.new("ShaderNodeMath")
    fade.operation = "SUBTRACT"
    fade.inputs[0].default_value = 1.0
    link(sep.outputs[2], fade.inputs[1])
    pw = nodes.new("ShaderNodeMath")
    pw.operation = "POWER"
    pw.inputs[1].default_value = 1.6
    link(fade.outputs[0], pw.inputs[0])
    st = nodes.new("ShaderNodeMath")
    st.operation = "MULTIPLY"
    st.inputs[1].default_value = 0.9
    link(pw.outputs[0], st.inputs[0])
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs[0].default_value = (*HOLO, 1)
    link(st.outputs[0], emit.inputs["Strength"])
    add = nodes.new("ShaderNodeAddShader")
    link(nodes.new("ShaderNodeBsdfTransparent").outputs[0], add.inputs[0])
    link(emit.outputs[0], add.inputs[1])
    link(add.outputs[0], nodes["Material Output"].inputs[0])
    return m


def label_material(path, rarity_col):
    """Bildfeld: Charm-Render (mit Alpha) über einem dunklen Verlauf in der Raritätsfarbe."""
    m = bpy.data.materials.new("Etikettbild")
    m.use_nodes = True
    nt = m.node_tree
    nodes, link = nt.nodes, nt.links.new
    p = nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.45
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path)
    tex.extension = "CLIP"
    tc = nodes.new("ShaderNodeTexCoord")
    grad = nodes.new("ShaderNodeTexGradient")
    grad.gradient_type = "SPHERICAL"
    mp = nodes.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = (0.5, 0.5, 0)
    mp.inputs["Scale"].default_value = (0.5, 1.4, 1)
    link(tc.outputs["UV"], mp.inputs[0])
    # Mapping verschiebt vor dem Skalieren - die Mitte des Verlaufs liegt so auf der Bildmitte.
    mp.vector_type = "TEXTURE"
    link(mp.outputs[0], grad.inputs[0])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.012, 0.008, 0.025, 1)
    ramp.color_ramp.elements[1].color = (*[c * 0.35 for c in srgb(rarity_col)], 1)
    link(grad.outputs[1], ramp.inputs[0])
    mix = nodes.new("ShaderNodeMixRGB")
    link(tex.outputs["Alpha"], mix.inputs[0])
    link(ramp.outputs[0], mix.inputs[1])
    link(tex.outputs[0], mix.inputs[2])
    link(mix.outputs[0], p.inputs["Base Color"])
    return m


def text(parent, body, loc, size, material, rot=(0, 0, 0), width=0.0, name="Text", bold=False):
    bpy.ops.object.text_add(location=loc, rotation=rot)
    t = bpy.context.active_object
    t.name = name
    t.data.body = body
    t.data.size = size
    t.data.align_x = "CENTER"
    t.data.align_y = "TOP" if width else "CENTER"
    if width:
        t.data.text_boxes[0].width = width
        t.data.text_boxes[0].x = -width * 0.5
    t.data.extrude = 0.0002
    t.data.font = bpy.data.fonts.load(BOLD_FONT if bold else BODY_FONT, check_existing=True)
    t.data.space_line = 0.92
    t.data.materials.append(material)
    t.parent = parent
    return t


def box(parent, name, size, loc, material):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(material)
    o.parent = parent
    return o


def cyl(parent, name, r, depth, loc, material, rot=(0, 0, 0), verts=64):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc,
                                        rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    o.parent = parent
    return o


def empty(name, loc=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = loc
    return o


# --- Etikett-Bild -------------------------------------------------------------------------

def render_banner(cid):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 64
    scene.eevee.use_gtao = True
    scene.render.film_transparent = True
    scene.render.resolution_x = 1024
    scene.render.resolution_y = int(1024 * BANNER[1] / BANNER[0])
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Welt")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.33, 0.4, 1)
    scene.world = world
    holder, _ = import_charm(cid, 0.8)
    holder.rotation_euler = (0, 0, math.radians(-20))
    bpy.ops.object.light_add(type="AREA", location=(-1.5, -2, 2.5))
    k = bpy.context.active_object
    k.data.energy = 220
    k.data.size = 2
    k.rotation_euler = (math.radians(45), 0, math.radians(-35))
    bpy.ops.object.light_add(type="AREA", location=(1.8, 1.5, 1.2))
    r = bpy.context.active_object
    r.data.energy = 160
    r.data.color = (0.75, 0.6, 1.0)
    r.rotation_euler = (math.radians(-60), 0, math.radians(130))
    aim = empty("Ziel")
    bpy.ops.object.camera_add(location=(0, -4.2, 1.6))
    cam = bpy.context.active_object
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.9
    t = cam.constraints.new("TRACK_TO")
    t.target = aim
    t.track_axis = "TRACK_NEGATIVE_Z"
    t.up_axis = "UP_Y"
    scene.camera = cam
    path = os.path.join(OUT, "etikett_%s.png" % cid)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def fit_text(parent, body, top, bottom, z, material, width=0.76, biggest=0.1):
    """Beschreibung so groß wie das freie Feld erlaubt - kurze Texte werden größer."""
    size = biggest
    while True:
        t = text(parent, body, (0, top, z), size, material, width=width, name="Beschreibung")
        bpy.context.view_layer.update()
        low = min((t.matrix_world @ Vector(c)).y for c in t.bound_box)
        wide = max(abs((t.matrix_world @ Vector(c)).x - t.matrix_world.translation.x)
                   for c in t.bound_box)
        if low >= bottom and wide <= width * 0.5 + 0.005 or size < 0.03:
            return t
        bpy.data.objects.remove(t)
        size *= 0.94


# --- Die DISKETTE -------------------------------------------------------------------------

def floppy(parent, charm, banner):
    cid, name, desc, rarity = charm
    rname, rcol = RARITY[rarity]
    plastic = led.mat("Kunststoff", srgb((0.86, 0.85, 0.82)), 0.0, 0.42, clearcoat=0.15)
    alu = led.mat("Alu", (0.8, 0.81, 0.83), 1.0, 0.3)
    dark = led.mat("Scheibe", (0.03, 0.022, 0.018), 0.2, 0.35)
    paper = led.mat("Papier", (0.8, 0.8, 0.78), 0.0, 0.85)
    ink = led.mat("Tinte", (0.002, 0.002, 0.004), 0.0, 0.95)
    stripe = led.mat("Streifen_" + rarity, srgb(rcol), 0.0, 0.4, 0.6)
    zt = DT * 0.5
    body = led.rounded_box(parent, "Gehaeuse", (DW, DL, DT), (0, 0, 0), plastic, 0.012, 0.003, 6)
    bpy.ops.mesh.primitive_cube_add(size=0.07, location=(DW * 0.5, DL * 0.5, 0),
                                    rotation=(0, 0, math.radians(45)))
    corner = bpy.context.active_object
    corner.parent = parent
    led.cut(body, corner)
    # Schieber, über beide Seiten gefalzt; das Fenster zeigt die Magnetscheibe.
    led.rounded_box(parent, "Schieber", (0.4, 0.3, DT + 0.007), (-0.03, DL * 0.5 - 0.15, 0), alu,
                    0.006, 0.0015, 4)
    box(parent, "Fenster", (0.11, 0.2, DT + 0.0075), (0.04, DL * 0.5 - 0.145, 0), dark)
    for sx in (-1, 1):
        box(parent, "Loch%d" % sx, (0.03, 0.03, DT + 0.001), (sx * 0.418, -DL * 0.5 + 0.04, 0),
            ink)
    # Das Etikett: Bild oben, Text darunter, Raritäts-Streifen am Fuß.
    top, bot = DL * 0.5 - INSERT + 0.21, -DL * 0.5 + 0.015
    led.rounded_box(parent, "Etikett", (0.78, top - bot, 0.0008),
                    (0, (top + bot) * 0.5, zt + 0.0004), paper, 0.01, 0.0, 4)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, top - 0.018 - BANNER[1] * 0.5, zt + 0.0009))
    img = bpy.context.active_object
    img.name = "Bildfeld"
    img.scale = (BANNER[0], BANNER[1], 1)
    img.data.materials.append(label_material(banner, rcol))
    img.parent = parent
    # Was draußen bleibt (unter DL/2 - INSERT), ist allein der Text - auf Distanz lesbar.
    y = DL * 0.5 - INSERT - 0.045
    text(parent, name.upper(), (0, y, zt + 0.0009), 0.078, ink, name="Name", bold=True)
    sb = bot + 0.04
    fit_text(parent, desc, y - 0.05, sb + 0.04, zt + 0.0009, ink)
    box(parent, "Streifen", (0.76, 0.046, 0.0006), (0, sb, zt + 0.0009), stripe)
    lum = sum(rcol) / 3
    on_stripe = ink if lum > 0.7 else led.mat("Weiss", (0.95, 0.95, 0.95), 0.0, 0.5, 0.4)
    text(parent, rname, (0, sb, zt + 0.0013), 0.034, on_stripe, name="Raritaet", bold=True)
    # Rückseite: die Nabe.
    cyl(parent, "Nabe", 0.1, 0.003, (0, 0.03, -zt - 0.0005), alu)
    return parent


# --- Das LAUFWERK -------------------------------------------------------------------------

def reader(parent, rarity=None, charm=None):
    gun = led.mat("Gussgrau", (0.05, 0.05, 0.06), 0.9, 0.32, clearcoat=0.4)
    black = led.mat("Front", (0.006, 0.006, 0.008), 0.0, 0.08, clearcoat=1.0)
    chrome = led.mat("Chrom", (0.85, 0.86, 0.88), 1.0, 0.08)
    accent_col = srgb(RARITY[rarity][1]) if rarity else (0.08, 0.1, 0.12)
    accent = led.mat("Saum_%s" % rarity, accent_col, 0.0, 0.3, 5.0 if rarity else 0.0)
    holo_on = charm is not None
    lens_mat = (led.mat("LinseAn", HOLO, 0.0, 0.05, 8.0) if holo_on
                else led.mat("LinseAus", (0.02, 0.04, 0.05), 0.0, 0.03, clearcoat=1.0))
    ring_mat = led.mat("RingAn", HOLO, 0.0, 0.2, 6.0) if holo_on else led.mat("RingAus", (0.03, 0.05, 0.06), 0.0, 0.3)

    body = led.rounded_box(parent, "Gehaeuse", (RW, RL, RH), (0, 0, RH * 0.5), gun, 0.05, 0.02, 8)
    fy = -RL * 0.5
    bezel = led.rounded_box(parent, "Blende", (RW - 0.06, 0.04, RH - 0.06), (0, fy - 0.0, RH * 0.5),
                            black, 0.02, 0.006, 6)
    deep = INSERT + 0.06
    slot = box(parent, "SchnittSchlitz", (DW + 0.06, deep, 0.05), (0, fy + deep * 0.5 - 0.04, SLOT_Z),
               black)
    led.cut(body, slot)
    led.cut(bezel, slot)
    box(parent, "Schlitzgrund", (DW + 0.06, 0.01, 0.05), (0, fy + deep - 0.045, SLOT_Z), black)
    box(parent, "Lippe", (DW + 0.06, 0.006, 0.007), (0, fy - 0.021, SLOT_Z - 0.04), accent)
    box(parent, "Kopfsaum", (RW - 0.12, 0.012, 0.005), (0, fy + 0.035, RH + 0.001), accent)
    led.rounded_box(parent, "Auswurf", (0.13, 0.02, 0.036), (0.38, fy - 0.02, 0.075), gun, 0.008,
                    0.003, 4)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.012, location=(-0.44, fy - 0.02, 0.075))
    lamp = bpy.context.active_object
    lamp.data.materials.append(led.mat("LampeAn", (0.2, 1.0, 0.4), 0.0, 0.2, 8.0) if rarity
                               else led.mat("LampeAus", (0.03, 0.05, 0.03), 0.0, 0.2))
    lamp.parent = parent
    white = led.mat("Druck", (0.6, 0.62, 0.66), 0.0, 0.5, 0.2)
    text(parent, "FUMBLE  ·  HOLO-DRIVE", (-0.12, fy - 0.0205, 0.075), 0.03, white,
         rot=(math.radians(90), 0, 0), name="Aufdruck")
    # Lüftungsrillen hinten auf dem Deckel.
    for i in range(5):
        for sx in (-1, 1):
            box(parent, "Rille%d" % i, (0.016, 0.4, 0.004), (sx * (0.4 + i * 0.03), 0.05, RH + 0.0005),
                black)
    # Der PROJEKTOR.
    pc = Vector((0, 0.04, RH))
    cyl(parent, "Sockel", 0.3, 0.03, pc + Vector((0, 0, 0.015)), chrome)
    cyl(parent, "Topf", 0.24, 0.05, pc + Vector((0, 0, 0.04)), gun)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.009,
                                     location=pc + Vector((0, 0, 0.066)))
    t = bpy.context.active_object
    t.data.materials.append(ring_mat)
    bpy.ops.object.shade_smooth()
    t.parent = parent
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.13, location=pc + Vector((0, 0, 0.062)),
                                         segments=48, ring_count=24)
    lens = bpy.context.active_object
    lens.scale = (1, 1, 0.4)
    lens.data.materials.append(lens_mat)
    bpy.ops.object.shade_smooth()
    lens.parent = parent
    tip_mat = ring_mat
    for k in range(3):
        a = math.radians(90 + k * 120)
        r = 0.27
        base = pc + Vector((math.cos(a) * r, math.sin(a) * r, 0.03))
        tilt = math.radians(28)
        dirv = Vector((-math.cos(a) * math.sin(tilt), -math.sin(a) * math.sin(tilt), math.cos(tilt)))
        ln = 0.2
        mid = base + dirv * ln * 0.5
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.012, depth=ln, location=mid)
        pr = bpy.context.active_object
        pr.rotation_mode = "QUATERNION"
        pr.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(dirv)
        pr.data.materials.append(chrome)
        bpy.ops.object.shade_smooth()
        pr.parent = parent
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.02, location=base + dirv * ln)
        tip = bpy.context.active_object
        tip.data.materials.append(tip_mat)
        bpy.ops.object.shade_smooth()
        tip.parent = parent
    if holo_on:
        h = 1.0
        bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=0.12, radius2=0.42, depth=h,
                                        end_fill_type="NOTHING",
                                        location=pc + Vector((0, 0, 0.08 + h * 0.5)))
        cone = bpy.context.active_object
        cone.name = "Lichtkegel"
        cone.data.materials.append(beam_material())
        bpy.ops.object.shade_smooth()
        cone.parent = parent
        holder, meshes = import_charm(charm[0], 0.6)
        mat = holo_material(charm_image(meshes))
        for o in meshes:
            o.data.materials.clear()
            o.data.materials.append(mat)
        holder.location = pc + Vector((0, 0, 0.72))
        holder.rotation_euler = (0, 0, math.radians(-25))
        holder.parent = parent
        bpy.ops.object.light_add(type="POINT", location=pc + Vector((0, 0, 0.5)))
        lt = bpy.context.active_object
        lt.data.energy = 40
        lt.data.color = HOLO
        lt.data.shadow_soft_size = 0.3
        lt.parent = parent
    return parent


# --- Bühne --------------------------------------------------------------------------------

def stage(res=(1600, 1000)):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    led._mats.clear()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    ee = scene.eevee
    ee.use_bloom = True
    ee.bloom_intensity = 0.04
    ee.use_ssr = True
    ee.use_gtao = True
    ee.use_soft_shadows = True
    ee.taa_render_samples = 96
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.view_settings.view_transform = "Filmic"
    scene.view_settings.look = "Medium High Contrast"
    world = bpy.data.worlds.new("Welt")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    bg.inputs[0].default_value = (0.012, 0.009, 0.022, 1)
    studio = nt.nodes.new("ShaderNodeBackground")
    studio.inputs[0].default_value = (0.5, 0.5, 0.56, 1)
    path = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(path.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(studio.outputs[0], mix.inputs[1])
    nt.links.new(bg.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], nt.nodes["World Output"].inputs[0])
    scene.world = world
    bpy.ops.mesh.primitive_plane_add(size=60)
    bpy.context.active_object.data.materials.append(led.mat("Filz", (0.03, 0.012, 0.06), 0.0, 0.9))
    led.softbox((-3, -2, 6), (math.radians(30), math.radians(-25), 0), (6, 3), 5.0)
    led.softbox((4, 3, 5), (math.radians(-40), math.radians(35), 0), (5, 2), 2.5)
    bpy.ops.object.light_add(type="AREA", location=(-1.5, -3, 5))
    key = bpy.context.active_object
    key.data.energy = 600
    key.data.size = 5
    key.rotation_euler = (math.radians(30), 0, math.radians(-20))
    bpy.ops.object.light_add(type="AREA", location=(3, 3, 2.5))
    rim = bpy.context.active_object
    rim.data.energy = 250
    rim.data.size = 3
    rim.data.color = (0.7, 0.55, 1.0)
    rim.rotation_euler = (math.radians(-55), 0, math.radians(135))


def camera(loc, target, lens=50):
    aim = empty("Ziel", target)
    bpy.ops.object.camera_add(location=loc)
    cam = bpy.context.active_object
    c = cam.constraints.new("TRACK_TO")
    c.target = aim
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"
    cam.data.lens = lens
    bpy.context.scene.camera = cam


def shoot(name, save_blend=False):
    bpy.context.scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    if save_blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, name + ".blend"))


def main():
    banners = {c[0]: render_banner(c[0]) for c in CHARMS}
    hero = CHARMS[0]

    # 1. Die Diskette, schräg aufgestellt wie im Vorbild.
    stage()
    d = floppy(empty("Diskette"), hero, banners[hero[0]])
    d.location = (0, 0, 0.4)
    d.rotation_euler = (math.radians(58), math.radians(-8), math.radians(-14))
    camera((0.55, -2.6, 1.1), (0, 0, 0.4), 55)
    shoot("1_diskette_schraeg", True)

    # 2. Draufsicht: das Etikett zum Lesen.
    stage((1200, 1200))
    floppy(empty("Diskette"), hero, banners[hero[0]]).location = (0, 0, DT * 0.5 + 0.001)
    camera((0, -0.25, 2.1), (0, -0.02, 0), 60)
    shoot("2_diskette_draufsicht")

    # 3. Laufwerk leer, die Diskette halb eingeschoben.
    stage()
    reader(empty("Laufwerk"))
    d = floppy(empty("Diskette"), hero, banners[hero[0]])
    d.location = (0, -RL * 0.5 + 0.22 - DL * 0.5, SLOT_Z)
    camera((1.5, -3.0, 1.7), (0, -0.45, 0.25), 50)
    shoot("3_laufwerk_einschub")

    # 4. Eingelegt: der Projektor zeigt das Hologramm.
    stage()
    reader(empty("Laufwerk"), hero[3], hero)
    d = floppy(empty("Diskette"), hero, banners[hero[0]])
    d.location = (0, LOADED_Y, SLOT_Z)
    camera((1.7, -3.3, 2.0), (0, -0.25, 0.55), 45)
    shoot("4_laufwerk_hologramm", True)

    # 5./6. Die Reihe: sechs Laufwerke statt sechs Charm-Slots - schräg und aus Spielferne.
    stage((2000, 1000))
    pitch = RW + 0.25
    for i, charm in enumerate(CHARMS):
        x = (i - 2.5) * pitch
        reader(empty("Laufwerk%d" % i), charm[3], charm).location = (x, 0, 0)
        floppy(empty("Diskette%d" % i), charm, banners[charm[0]]).location = (x, LOADED_Y, SLOT_Z)
    camera((0, -8.5, 4.6), (0, -0.4, 0.45), 40)
    shoot("5_reihe")
    for o in bpy.data.objects:
        if o.type == "MESH" and o.data.materials and o.data.materials[0].name.startswith("Softbox"):
            o.hide_render = True
    camera((0, -4.2, 8.0), (0, -0.4, 0.3), 40)
    shoot("6_reihe_spielferne")
    print("ok")


if __name__ == "__main__":
    main()
